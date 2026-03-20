import 'dart:convert';
import 'dart:io';

import 'package:kinsaep_pos/core/database/database_helper.dart';
import 'package:kinsaep_pos/core/network/api_client.dart';
import 'package:kinsaep_pos/core/network/cloud_state.dart';
import 'package:sqflite/sqflite.dart';

class SyncException implements Exception {
  final String message;
  final bool isSubscriptionLocked;

  const SyncException(this.message, {this.isSubscriptionLocked = false});

  @override
  String toString() => message;
}

class SyncService {
  static const String _epochIso = '1970-01-01T00:00:00.000Z';

  static Future<void> syncNow({List<String>? scopes}) async {
    final settings = await DatabaseHelper.instance.getSettings();
    await _ensureSyncIsAllowed(settings);
    final syncProfile =
        (settings['syncProfile'] as String?) ?? SyncProfileState.light;
    final effectiveScopes = _resolveScopes(syncProfile, requested: scopes);
    final localJobId = 'local-sync-${DateTime.now().millisecondsSinceEpoch}';

    await _saveLocalJob(
      id: localJobId,
      direction: SyncDirectionState.pull,
      status: SyncJobState.queued,
      progress: 0,
      scopes: effectiveScopes,
    );

    try {
      await DatabaseHelper.instance.updateSyncState(
        status: SyncJobState.running,
        progress: 5,
        error: null,
      );
      await _saveLocalJob(
        id: localJobId,
        direction: SyncDirectionState.pull,
        status: SyncJobState.running,
        progress: 10,
        scopes: effectiveScopes,
      );

      final isInitialSync =
          ((settings['lastSyncAt'] as String?)?.isEmpty ?? true) ||
          settings['lastSyncAt'] == null;
      if (isInitialSync) {
        final remoteSnapshot = await _fetchRemoteData(
          since: _epochIso,
          scopes: effectiveScopes,
          syncProfile: syncProfile,
        );
        final remoteHasBusinessData = _hasRemoteBusinessData(remoteSnapshot);
        if (!remoteHasBusinessData &&
            await DatabaseHelper.instance.hasLocalBusinessData()) {
          await _pushPendingData(
            scopes: effectiveScopes,
            syncProfile: syncProfile,
          );
          final refreshedSnapshot = await _fetchRemoteData(
            since: _epochIso,
            scopes: effectiveScopes,
            syncProfile: syncProfile,
          );
          await _applyRemoteData(refreshedSnapshot);
        } else {
          await _applyRemoteData(remoteSnapshot);
        }
      } else {
        await _pushPendingData(
          scopes: effectiveScopes,
          syncProfile: syncProfile,
        );
        final remoteSnapshot = await _fetchRemoteData(
          since: settings['lastSyncAt'] as String? ?? _epochIso,
          scopes: effectiveScopes,
          syncProfile: syncProfile,
        );
        await _applyRemoteData(remoteSnapshot);
      }

      await refreshSyncStatus();
      await refreshSyncJobs();
      await DatabaseHelper.instance.updateSyncState(
        status: SyncJobState.succeeded,
        progress: 100,
        error: null,
      );
      await _saveLocalJob(
        id: localJobId,
        direction: SyncDirectionState.pull,
        status: SyncJobState.succeeded,
        progress: 100,
        scopes: effectiveScopes,
      );
    } catch (error) {
      final message = error is SyncException ? error.message : '$error';
      await DatabaseHelper.instance.updateSyncState(
        status: SyncJobState.failed,
        progress: 0,
        error: message,
      );
      await _saveLocalJob(
        id: localJobId,
        direction: SyncDirectionState.pull,
        status: SyncJobState.failed,
        progress: 0,
        scopes: effectiveScopes,
        error: message,
      );
      rethrow;
    }
  }

  static Future<void> pushData({List<String>? scopes}) async {
    final settings = await DatabaseHelper.instance.getSettings();
    await _ensureSyncIsAllowed(settings);
    await _pushPendingData(
      scopes: _resolveScopes(
        (settings['syncProfile'] as String?) ?? SyncProfileState.light,
        requested: scopes,
      ),
      syncProfile:
          (settings['syncProfile'] as String?) ?? SyncProfileState.light,
    );
  }

  static Future<void> pullData({List<String>? scopes}) async {
    final settings = await DatabaseHelper.instance.getSettings();
    await _ensureSyncIsAllowed(settings);
    final syncProfile =
        (settings['syncProfile'] as String?) ?? SyncProfileState.light;
    final data = await _fetchRemoteData(
      since: settings['lastSyncAt'] as String? ?? _epochIso,
      scopes: _resolveScopes(syncProfile, requested: scopes),
      syncProfile: syncProfile,
    );
    await _applyRemoteData(data);
  }

  static Future<Map<String, dynamic>> refreshSyncStatus() async {
    final settings = await DatabaseHelper.instance.getSettings();
    try {
      final response = await ApiClient.get('/sync/status');
      if (response.statusCode != 200) {
        throw SyncException('Failed to load sync status.');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await _applyEntitlementState(
        accessMode: data['accessMode'] as String?,
        entitlement: data['entitlement'] as Map<String, dynamic>?,
        serverTime: data['serverTime'] as String?,
        fallbackSettings: settings,
      );

      final lastJob = data['lastJob'] as Map<String, dynamic>?;
      if (lastJob != null) {
        await _saveServerJob(lastJob);
      }
      return data;
    } on ApiClientException catch (error) {
      throw SyncException(error.message);
    }
  }

  static Future<List<Map<String, dynamic>>> refreshSyncJobs() async {
    try {
      final response = await ApiClient.get('/sync/jobs');
      if (response.statusCode != 200) {
        throw SyncException('Failed to load sync jobs.');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final jobs =
          (data['jobs'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      for (final job in jobs) {
        await _saveServerJob(job);
      }
      return jobs;
    } on ApiClientException catch (error) {
      throw SyncException(error.message);
    }
  }

  static Future<void> _ensureSyncIsAllowed(
    Map<String, dynamic> settings,
  ) async {
    final serverUrl = (settings['serverUrl'] as String?)?.trim();
    final syncEnabled = settings['syncEnabled'] == 1;
    final subscriptionStatus =
        (settings['subscriptionStatus'] as String?) ??
        CloudSubscriptionStatus.none;
    final syncProfile =
        (settings['syncProfile'] as String?) ?? SyncProfileState.light;

    if (serverUrl == null || serverUrl.isEmpty) {
      throw const SyncException('Set your server URL before using cloud sync.');
    }

    if (!syncEnabled || syncProfile == SyncProfileState.off) {
      throw const SyncException('Cloud sync is turned off on this device.');
    }

    if (subscriptionStatus != CloudSubscriptionStatus.active) {
      throw SyncException(
        'Cloud sync is unavailable because the store subscription is $subscriptionStatus.',
        isSubscriptionLocked:
            subscriptionStatus == CloudSubscriptionStatus.blocked ||
            subscriptionStatus == CloudSubscriptionStatus.expired,
      );
    }

    if (!await ApiClient.hasSession()) {
      throw const SyncException('Log in to your cloud store before syncing.');
    }
  }

  static Future<Map<String, dynamic>> _fetchRemoteData({
    required String since,
    required List<String> scopes,
    required String syncProfile,
  }) async {
    try {
      final response = await ApiClient.get(
        '/sync/pull?since=${Uri.encodeQueryComponent(since)}'
        '&syncProfile=$syncProfile'
        '&deviceId=${Uri.encodeQueryComponent(await DatabaseHelper.instance.getOrCreateDeviceId())}'
        '&scopes=${Uri.encodeQueryComponent(scopes.join(","))}',
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      if (response.statusCode == 403) {
        final body = _decodeBody(response.body);
        await _applyEntitlementState(
          accessMode: body['accessMode'] as String?,
          entitlement: body['entitlement'] as Map<String, dynamic>?,
          fallbackSettings: await DatabaseHelper.instance.getSettings(),
        );
        throw SyncException(
          body['error'] as String? ?? 'Store subscription is locked.',
          isSubscriptionLocked: true,
        );
      }

      throw SyncException('Failed to pull cloud data: ${response.body}');
    } on ApiClientException catch (error) {
      throw SyncException(error.message);
    } catch (error) {
      if (error is SyncException) {
        rethrow;
      }
      throw SyncException('Network error during pull: $error');
    }
  }

  static Future<void> _pushPendingData({
    required List<String> scopes,
    required String syncProfile,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final settings = await DatabaseHelper.instance.getSettings();
    final currentDevice = await _ensureLocalDevice(settings);

    await DatabaseHelper.instance.updateSyncState(
      status: SyncJobState.running,
      progress: 20,
      error: null,
    );

    final pendingCategories =
        scopes.contains('catalog')
            ? await db.query('categories', where: "syncStatus = 'PENDING'")
            : <Map<String, dynamic>>[];
    final pendingItems =
        scopes.contains('catalog')
            ? await db.query(
              'items',
              where: "syncStatus = 'PENDING' OR imageUrl IS NULL",
            )
            : <Map<String, dynamic>>[];
    final pendingSales =
        scopes.contains('rawSales')
            ? await db.query('sales', where: "syncStatus = 'PENDING'")
            : <Map<String, dynamic>>[];
    final pendingShifts =
        scopes.contains('rawSales')
            ? await db.query('shifts', where: "syncStatus = 'PENDING'")
            : <Map<String, dynamic>>[];
    final pendingTombstones =
        scopes.contains('tombstones')
            ? await DatabaseHelper.instance.getPendingTombstones()
            : <Map<String, dynamic>>[];
    final pendingKitchenTickets =
        scopes.contains('kitchen')
            ? await DatabaseHelper.instance.getPendingKitchenTickets()
            : <Map<String, dynamic>>[];
    final staff =
        scopes.contains('staff')
            ? await DatabaseHelper.instance.getActiveStaff()
            : <Map<String, dynamic>>[];
    final salesSummaries =
        scopes.contains('summary')
            ? await _buildLocalSalesSummaries(db)
            : <Map<String, dynamic>>[];
    final pendingMediaAssets =
        scopes.contains('media')
            ? await DatabaseHelper.instance.getPendingMediaAssets()
            : <Map<String, dynamic>>[];

    List<Map<String, dynamic>> pendingSaleItems = [];
    if (pendingSales.isNotEmpty) {
      final saleIds = pendingSales.map((sale) => sale['id']).toList();
      pendingSaleItems = await _querySaleItems(db, saleIds);
    }

    final nothingToSync =
        pendingCategories.isEmpty &&
        pendingItems.isEmpty &&
        pendingSales.isEmpty &&
        pendingShifts.isEmpty &&
        pendingTombstones.isEmpty &&
        pendingKitchenTickets.isEmpty &&
        pendingMediaAssets.isEmpty &&
        (staff.isEmpty || !scopes.contains('staff')) &&
        salesSummaries.isEmpty &&
        !(await DatabaseHelper.instance.hasLocalBusinessData());
    if (nothingToSync) {
      return;
    }

    final payload = <String, dynamic>{
      'deviceId': currentDevice['id'],
      'deviceName': currentDevice['name'],
      'deviceType': currentDevice['type'],
      'platform': currentDevice['platform'],
      'scannerMode': currentDevice['scannerMode'],
      'syncProfile': syncProfile,
      'scopes': scopes,
      'store': {
        'name': settings['storeName'],
        'address': settings['storeAddress'],
        'phone': settings['storePhone'],
        'businessType': settings['businessType'],
        'currency': settings['currency'],
        'locale': settings['locale'],
        'taxEnabled': settings['taxEnabled'] == 1,
        'taxRate': settings['taxRate'],
        'receiptHeader': settings['receiptHeader'],
        'receiptFooter': settings['receiptFooter'],
      },
      if (scopes.contains('catalog'))
        'categories':
            pendingCategories
                .map((category) => {...category, 'color': category['color']})
                .toList(),
      if (scopes.contains('catalog'))
        'items':
            pendingItems
                .map(
                  (item) => {
                    ...item,
                    'trackStock': item['trackStock'] == 1,
                    'isActive': item['isActive'] == 1,
                  },
                )
                .toList(),
      if (scopes.contains('staff'))
        'staff':
            staff
                .map(
                  (member) => {
                    'id': member['id'],
                    'name': member['name'],
                    'role': member['role'],
                    'pinHash': member['pin'],
                    'isActive': member['isActive'] == 1,
                    'createdAt': member['createdAt'],
                    'updatedAt': member['updatedAt'],
                  },
                )
                .toList(),
      if (scopes.contains('summary')) 'salesSummaries': salesSummaries,
      if (scopes.contains('rawSales')) 'sales': pendingSales,
      if (scopes.contains('rawSales')) 'saleItems': pendingSaleItems,
      if (scopes.contains('rawSales')) 'shifts': pendingShifts,
      if (scopes.contains('kitchen'))
        'kitchenTickets':
            pendingKitchenTickets
                .map(
                  (ticket) => {
                    ...ticket,
                    'saleId':
                        scopes.contains('rawSales') ? ticket['saleId'] : null,
                  },
                )
                .toList(),
      if (scopes.contains('tombstones')) 'tombstones': pendingTombstones,
    };

    try {
      final response = await ApiClient.post('/sync/push', payload);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final batch = db.batch();
        for (final category in pendingCategories) {
          batch.update(
            'categories',
            {'syncStatus': 'SYNCED'},
            where: 'id = ?',
            whereArgs: [category['id']],
          );
        }
        for (final item in pendingItems) {
          batch.update(
            'items',
            {'syncStatus': 'SYNCED'},
            where: 'id = ?',
            whereArgs: [item['id']],
          );
        }
        for (final sale in pendingSales) {
          batch.update(
            'sales',
            {'syncStatus': 'SYNCED'},
            where: 'id = ?',
            whereArgs: [sale['id']],
          );
        }
        for (final shift in pendingShifts) {
          batch.update(
            'shifts',
            {'syncStatus': 'SYNCED'},
            where: 'id = ?',
            whereArgs: [shift['id']],
          );
        }
        await batch.commit(noResult: true);
        await DatabaseHelper.instance.markKitchenTicketsSynced(
          pendingKitchenTickets.map((ticket) => ticket['id']).toList(),
        );
        await DatabaseHelper.instance.markTombstonesSynced(
          pendingTombstones.map((stone) => stone['id']).toList(),
        );

        await _applyEntitlementState(
          accessMode: body['accessMode'] as String?,
          entitlement: body['entitlement'] as Map<String, dynamic>?,
          serverTime: body['serverTime'] as String?,
          fallbackSettings: settings,
        );

        final jobId = body['jobId'] as String?;
        if (jobId != null && jobId.isNotEmpty) {
          await refreshSyncJobs();
        }
        await DatabaseHelper.instance.updateSyncState(
          status: SyncJobState.running,
          progress: pendingMediaAssets.isNotEmpty ? 70 : 60,
          error: null,
          lastSyncAt: body['serverTime'] as String?,
        );

        if (pendingMediaAssets.isNotEmpty) {
          await _uploadPendingMedia(
            pendingMediaAssets: pendingMediaAssets,
            deviceId: currentDevice['id'] as String,
          );
          await DatabaseHelper.instance.updateSyncState(
            status: SyncJobState.running,
            progress: 85,
            error: null,
            lastSyncAt: body['serverTime'] as String?,
          );
        }
        return;
      }

      if (response.statusCode == 403) {
        final body = _decodeBody(response.body);
        await _applyEntitlementState(
          accessMode: body['accessMode'] as String?,
          entitlement: body['entitlement'] as Map<String, dynamic>?,
          fallbackSettings: settings,
        );
        throw SyncException(
          body['error'] as String? ?? 'Store subscription is locked.',
          isSubscriptionLocked: true,
        );
      }

      throw SyncException('Failed to push cloud data: ${response.body}');
    } on ApiClientException catch (error) {
      throw SyncException(error.message);
    } catch (error) {
      if (error is SyncException) {
        rethrow;
      }
      throw SyncException('Network error during push: $error');
    }
  }

  static Future<List<Map<String, dynamic>>> _querySaleItems(
    Database db,
    List<Object?> saleIds,
  ) async {
    if (saleIds.isEmpty) {
      return [];
    }

    final placeholders = List.filled(saleIds.length, '?').join(',');
    return db.query(
      'sale_items',
      where: 'saleId IN ($placeholders)',
      whereArgs: saleIds,
    );
  }

  static Future<void> _uploadPendingMedia({
    required List<Map<String, dynamic>> pendingMediaAssets,
    required String deviceId,
  }) async {
    for (final media in pendingMediaAssets) {
      final response = await ApiClient.post('/media', {
        'itemId': media['itemId'],
        'deviceId': deviceId,
        'fileName': media['fileName'],
        'mimeType': media['mimeType'],
        'thumbnailData': media['thumbnailBase64'],
      });

      if (response.statusCode == 201) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        await DatabaseHelper.instance.markMediaAssetSynced(
          media['id'] as String,
          remoteUrl: body['thumbnailPath'] as String?,
        );
        if (media['itemId'] != null) {
          await DatabaseHelper.instance.updateItemSilently(
            media['itemId'] as String,
            {'imageUrl': body['thumbnailPath'], 'syncStatus': 'SYNCED'},
          );
        }
      } else if (response.statusCode == 403) {
        throw const SyncException('This package does not allow media upload.');
      } else {
        throw SyncException('Failed to upload product image.');
      }
    }
  }

  static Future<Map<String, dynamic>> _ensureLocalDevice(
    Map<String, dynamic> settings,
  ) async {
    final deviceId = await DatabaseHelper.instance.getOrCreateDeviceId();
    final device = <String, dynamic>{
      'id': deviceId,
      'name': settings['deviceName'] ?? 'This Device',
      'type': settings['deviceType'] ?? DeviceTypeState.pos,
      'platform': Platform.isIOS ? 'IOS' : 'ANDROID',
      'scannerMode': settings['scannerMode'] ?? ScannerModeState.auto,
      'syncProfile': settings['syncProfile'] ?? SyncProfileState.light,
      'status': 'ONLINE',
      'isActive': 1,
      'lastSeenAt': DateTime.now().toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
    await DatabaseHelper.instance.upsertDevice(device);
    return device;
  }

  static Future<List<Map<String, dynamic>>> _buildLocalSalesSummaries(
    Database db,
  ) async {
    final rows = await db.rawQuery('''
      SELECT 
        substr(createdAt, 1, 10) AS businessDay,
        COUNT(*) as totalOrders,
        COALESCE(SUM(totalAmount), 0) as totalSales,
        COALESCE(SUM(CASE WHEN paymentMethod = 'cash' THEN totalAmount ELSE 0 END), 0) as cashTotal,
        COALESCE(SUM(CASE WHEN paymentMethod != 'cash' THEN totalAmount ELSE 0 END), 0) as otherTotal
      FROM sales
      WHERE status = 'completed'
      GROUP BY substr(createdAt, 1, 10)
      ORDER BY businessDay DESC
      LIMIT 30
    ''');

    final summaries =
        rows
            .map(
              (row) => {
                'id': 'summary-${row['businessDay']}',
                'businessDay': row['businessDay'],
                'totalOrders': row['totalOrders'],
                'totalSales': row['totalSales'],
                'cashTotal': row['cashTotal'],
                'otherTotal': row['otherTotal'],
                'updatedAt': DateTime.now().toIso8601String(),
              },
            )
            .toList();

    if (summaries.isNotEmpty) {
      await DatabaseHelper.instance.replaceSalesSummaries(summaries);
    }
    return summaries;
  }

  static bool _hasRemoteBusinessData(Map<String, dynamic> data) {
    bool hasItems(String key) {
      final value = data[key];
      return value is List && value.isNotEmpty;
    }

    return hasItems('categories') ||
        hasItems('items') ||
        hasItems('sales') ||
        hasItems('shifts') ||
        hasItems('staff') ||
        hasItems('kitchenTickets');
  }

  static Future<void> _applyRemoteData(Map<String, dynamic> data) async {
    final settings = await DatabaseHelper.instance.getSettings();
    await _applyEntitlementState(
      accessMode: data['accessMode'] as String?,
      entitlement: data['entitlement'] as Map<String, dynamic>?,
      serverTime: data['serverTime'] as String?,
      fallbackSettings: settings,
    );

    final store = data['store'] as Map<String, dynamic>?;
    if (store != null) {
      await DatabaseHelper.instance.updateSettings({
        if (store['name'] != null) 'storeName': store['name'],
        'storeAddress': store['address'],
        'storePhone': store['phone'],
        if (store['businessType'] != null)
          'businessType': store['businessType'],
        if (store['currency'] != null) 'currency': store['currency'],
        if (store['locale'] != null) 'locale': store['locale'],
        'taxEnabled': store['taxEnabled'] == true ? 1 : 0,
        'taxRate': store['taxRate'] ?? 0,
        'receiptHeader': store['receiptHeader'],
        'receiptFooter': store['receiptFooter'],
      });
    }

    final categories =
        (data['categories'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
    for (final category in categories) {
      await DatabaseHelper.instance.upsertCategoryRemote({
        'id': category['id'],
        'name': category['name'],
        'color': category['color'],
        'sortOrder': category['sortOrder'] ?? 0,
        'createdAt': category['createdAt'] ?? DateTime.now().toIso8601String(),
        'updatedAt': category['updatedAt'] ?? DateTime.now().toIso8601String(),
        'syncStatus': 'SYNCED',
      });
    }

    final items =
        (data['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    for (final item in items) {
      await DatabaseHelper.instance.upsertItemRemote({
        'id': item['id'],
        'name': item['name'],
        'price': item['price'],
        'cost': item['cost'],
        'categoryId': item['categoryId'],
        'barcode': item['barcode'],
        'sku': item['sku'],
        'imagePath': null,
        'imageUrl': item['imageUrl'],
        'kitchenStationId': item['kitchenStationId'],
        'trackStock': item['trackStock'] == true ? 1 : 0,
        'stockQuantity': item['stockQuantity'] ?? 0,
        'lowStockThreshold': item['lowStockThreshold'] ?? 5,
        'isActive': item['isActive'] == false ? 0 : 1,
        'sortOrder': item['sortOrder'] ?? 0,
        'modifiers': jsonEncode(item['modifiers'] ?? []),
        'createdAt': item['createdAt'] ?? DateTime.now().toIso8601String(),
        'updatedAt': item['updatedAt'] ?? DateTime.now().toIso8601String(),
        'syncStatus': 'SYNCED',
      });
    }

    final staff =
        (data['staff'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    for (final member in staff) {
      await DatabaseHelper.instance.upsertStaffMember({
        'id': member['id'],
        'name': member['name'],
        'pin': member['pinHash'] ?? '',
        'role': member['role'],
        'isActive': member['isActive'] == false ? 0 : 1,
        'createdAt': member['createdAt'] ?? DateTime.now().toIso8601String(),
        'updatedAt': member['updatedAt'] ?? DateTime.now().toIso8601String(),
      });
    }

    final devices =
        (data['devices'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    for (final device in devices) {
      await DatabaseHelper.instance.upsertDevice({
        'id': device['id'],
        'name': device['name'],
        'type': device['type'],
        'platform': device['platform'],
        'scannerMode': device['scannerMode'],
        'syncProfile': device['syncProfile'],
        'status': device['status'],
        'isActive': device['isActive'] == false ? 0 : 1,
        'lastSeenAt': device['lastSeenAt'],
        'createdAt': device['createdAt'] ?? DateTime.now().toIso8601String(),
        'updatedAt': device['updatedAt'] ?? DateTime.now().toIso8601String(),
      });
    }

    final kitchenStations =
        (data['kitchenStations'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
    final kitchenScreens =
        (data['kitchenScreens'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
    final kitchenTickets =
        (data['kitchenTickets'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
    await DatabaseHelper.instance.replaceKitchenSnapshot(
      stations:
          kitchenStations
              .map(
                (station) => {
                  'id': station['id'],
                  'name': station['name'],
                  'type': station['type'],
                  'isActive': station['isActive'] == false ? 0 : 1,
                  'createdAt':
                      station['createdAt'] ?? DateTime.now().toIso8601String(),
                  'updatedAt':
                      station['updatedAt'] ?? DateTime.now().toIso8601String(),
                },
              )
              .toList(),
      screens:
          kitchenScreens
              .map(
                (screen) => {
                  'id': screen['id'],
                  'stationId': screen['stationId'],
                  'deviceId': screen['deviceId'],
                  'label': screen['label'],
                  'isActive': screen['isActive'] == false ? 0 : 1,
                  'createdAt':
                      screen['createdAt'] ?? DateTime.now().toIso8601String(),
                  'updatedAt':
                      screen['updatedAt'] ?? DateTime.now().toIso8601String(),
                },
              )
              .toList(),
      tickets:
          kitchenTickets
              .map(
                (ticket) => {
                  'id': ticket['id'],
                  'saleId': ticket['saleId'],
                  'sourceDeviceId': ticket['sourceDeviceId'],
                  'status': ticket['status'] ?? 'NEW',
                  'note': ticket['note'],
                  'createdAt':
                      ticket['createdAt'] ?? DateTime.now().toIso8601String(),
                  'updatedAt':
                      ticket['updatedAt'] ?? DateTime.now().toIso8601String(),
                  'syncStatus': 'SYNCED',
                  'items':
                      (ticket['items'] as List<dynamic>? ?? [])
                          .cast<Map<String, dynamic>>()
                          .map(
                            (item) => {
                              'id': item['id'],
                              'ticketId': ticket['id'],
                              'itemId': item['itemId'],
                              'stationId': item['stationId'],
                              'itemName': item['itemName'],
                              'quantity': item['quantity'],
                              'status': item['status'] ?? 'NEW',
                              'note': item['note'],
                              'createdAt':
                                  item['createdAt'] ??
                                  DateTime.now().toIso8601String(),
                              'updatedAt':
                                  item['updatedAt'] ??
                                  DateTime.now().toIso8601String(),
                            },
                          )
                          .toList(),
                },
              )
              .toList(),
    );

    final mediaAssets =
        (data['mediaAssets'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
    for (final media in mediaAssets) {
      await DatabaseHelper.instance.saveMediaAsset({
        'id': media['id'],
        'itemId': media['itemId'],
        'fileName': media['fileName'],
        'mimeType': media['mimeType'],
        'imagePath': null,
        'thumbnailBase64': null,
        'remoteUrl': media['thumbnailPath'],
        'syncStatus': 'SYNCED',
        'createdAt': media['createdAt'] ?? DateTime.now().toIso8601String(),
        'updatedAt': media['updatedAt'] ?? DateTime.now().toIso8601String(),
      });
      if (media['itemId'] != null && media['thumbnailPath'] != null) {
        await DatabaseHelper.instance.updateItemSilently(
          media['itemId'] as String,
          {'imageUrl': media['thumbnailPath'], 'syncStatus': 'SYNCED'},
        );
      }
    }

    final summaries =
        (data['salesSummaries'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
    if (summaries.isNotEmpty) {
      await DatabaseHelper.instance.replaceSalesSummaries(
        summaries
            .map(
              (summary) => {
                'id': summary['id'] ?? 'summary-${summary['businessDay']}',
                'businessDay': summary['businessDay'],
                'totalOrders': summary['totalOrders'],
                'totalSales': summary['totalSales'],
                'cashTotal': summary['cashTotal'],
                'otherTotal': summary['otherTotal'],
                'updatedAt':
                    summary['updatedAt'] ?? DateTime.now().toIso8601String(),
              },
            )
            .toList(),
      );
    }

    final sales =
        (data['sales'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final saleItems =
        (data['saleItems'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
    for (final sale in sales) {
      await DatabaseHelper.instance.upsertSaleRemote({
        'id': sale['id'],
        'receiptNumber': sale['receiptNumber'],
        'subtotal': sale['subtotal'],
        'discountAmount': sale['discountAmount'],
        'discountPercent': sale['discountPercent'],
        'taxAmount': sale['taxAmount'],
        'totalAmount': sale['totalAmount'],
        'amountPaid': sale['amountPaid'],
        'changeAmount': sale['changeAmount'],
        'paymentMethod': sale['paymentMethod'],
        'status': sale['status'],
        'ticketName': sale['ticketName'],
        'createdAt': sale['createdAt'],
        'updatedAt': sale['updatedAt'],
        'syncStatus': 'SYNCED',
      });
      await DatabaseHelper.instance.replaceSaleItemsForSale(
        sale['id'] as String,
        saleItems
            .where((item) => item['saleId'] == sale['id'])
            .map(
              (item) => {
                'id': item['id'],
                'saleId': item['saleId'],
                'itemId': item['itemId'],
                'itemName': item['itemName'],
                'quantity': item['quantity'],
                'unitPrice': item['unitPrice'],
                'totalPrice': item['totalPrice'],
                'note': item['note'],
              },
            )
            .toList(),
      );
    }

    final shifts =
        (data['shifts'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    for (final shift in shifts) {
      await DatabaseHelper.instance.upsertShiftRemote({
        'id': shift['id'],
        'openedAt': shift['openedAt'],
        'closedAt': shift['closedAt'],
        'startingCash': shift['startingCash'] ?? 0,
        'cashAdded': shift['cashAdded'] ?? 0,
        'cashRemoved': shift['cashRemoved'] ?? 0,
        'expectedCash': shift['expectedCash'],
        'actualCash': shift['actualCash'],
        'difference': shift['difference'],
        'status': shift['status'] ?? 'open',
        'syncStatus': 'SYNCED',
      });
    }

    final tombstones =
        (data['tombstones'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
    for (final tombstone in tombstones) {
      await DatabaseHelper.instance.applyTombstone({
        'id': tombstone['id'],
        'entityType': tombstone['entityType'],
        'entityId': tombstone['entityId'],
        'payload':
            tombstone['payload'] != null
                ? jsonEncode(tombstone['payload'])
                : null,
        'deletedAt': tombstone['deletedAt'] ?? DateTime.now().toIso8601String(),
        'syncStatus': 'SYNCED',
      });
    }

    await refreshSyncJobs();
    await DatabaseHelper.instance.updateSyncState(
      status: SyncJobState.succeeded,
      progress: 100,
      error: null,
      lastSyncAt: data['serverTime'] as String?,
    );
  }

  static Future<void> _applyEntitlementState({
    required String? accessMode,
    required Map<String, dynamic>? entitlement,
    String? serverTime,
    required Map<String, dynamic> fallbackSettings,
  }) async {
    final resolvedAccessMode =
        accessMode ??
        (fallbackSettings['cloudMode'] as String?) ??
        CloudMode.offlineOnly;
    final subscriptionStatus = _subscriptionStatusFromAccessMode(
      resolvedAccessMode,
    );

    await DatabaseHelper.instance.updateSettings({
      'cloudMode': _cloudModeFromAccessMode(resolvedAccessMode),
      'subscriptionStatus': subscriptionStatus,
      if (entitlement?['packageCode'] != null &&
          entitlement?['maxSyncProfile'] != null)
        'syncProfile': _boundedSyncProfile(
          current:
              (fallbackSettings['syncProfile'] as String?) ??
              SyncProfileState.light,
          allowed: entitlement?['maxSyncProfile'] as String,
        ),
      if (resolvedAccessMode != CloudAccessMode.active) 'syncEnabled': 0,
      if (serverTime != null) 'lastSyncAt': serverTime,
    });
  }

  static String _cloudModeFromAccessMode(String accessMode) {
    switch (accessMode) {
      case CloudAccessMode.active:
        return CloudMode.active;
      case CloudAccessMode.blocked:
      case CloudAccessMode.expired:
        return CloudMode.blocked;
      default:
        return CloudMode.offlineOnly;
    }
  }

  static String _subscriptionStatusFromAccessMode(String accessMode) {
    switch (accessMode) {
      case CloudAccessMode.active:
        return CloudSubscriptionStatus.active;
      case CloudAccessMode.blocked:
        return CloudSubscriptionStatus.blocked;
      case CloudAccessMode.expired:
        return CloudSubscriptionStatus.expired;
      default:
        return CloudSubscriptionStatus.none;
    }
  }

  static String _boundedSyncProfile({
    required String current,
    required String allowed,
  }) {
    if (allowed == SyncProfileState.off) {
      return SyncProfileState.off;
    }
    if (allowed == SyncProfileState.light && current == SyncProfileState.full) {
      return SyncProfileState.light;
    }
    return current;
  }

  static List<String> _resolveScopes(
    String syncProfile, {
    List<String>? requested,
  }) {
    if (requested != null && requested.isNotEmpty) {
      return requested;
    }
    switch (syncProfile) {
      case SyncProfileState.full:
        return [
          'store',
          'catalog',
          'staff',
          'devices',
          'kitchen',
          'media',
          'summary',
          'rawSales',
          'tombstones',
        ];
      case SyncProfileState.off:
        return [];
      default:
        return [
          'store',
          'catalog',
          'staff',
          'devices',
          'kitchen',
          'media',
          'summary',
          'tombstones',
        ];
    }
  }

  static Map<String, dynamic> _decodeBody(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{'error': body};
    }
  }

  static Future<void> _saveLocalJob({
    required String id,
    required String direction,
    required String status,
    required int progress,
    required List<String> scopes,
    String? error,
  }) async {
    final now = DateTime.now().toIso8601String();
    await DatabaseHelper.instance.saveSyncJob({
      'id': id,
      'direction': direction,
      'status': status,
      'progress': progress,
      'scopes': jsonEncode(scopes),
      'error': error,
      'createdAt': now,
      'updatedAt': now,
    });
  }

  static Future<void> _saveServerJob(Map<String, dynamic> job) async {
    await DatabaseHelper.instance.saveSyncJob({
      'id': job['id'],
      'direction': job['direction'],
      'status': job['status'],
      'progress': job['progress'] ?? 0,
      'scopes': jsonEncode(job['scopes'] ?? const []),
      'error': job['error'],
      'createdAt': job['createdAt'] ?? DateTime.now().toIso8601String(),
      'updatedAt': job['updatedAt'] ?? DateTime.now().toIso8601String(),
    });
  }
}
