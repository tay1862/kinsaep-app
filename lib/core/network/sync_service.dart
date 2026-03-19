import 'dart:convert';

import 'package:kinsaep_pos/core/database/database_helper.dart';
import 'package:kinsaep_pos/core/network/api_client.dart';
import 'package:kinsaep_pos/core/network/cloud_state.dart';
import 'package:sqflite/sqflite.dart';

class SyncException implements Exception {
  final String message;
  final bool isSubscriptionLocked;

  SyncException(this.message, {this.isSubscriptionLocked = false});

  @override
  String toString() => message;
}

class SyncService {
  static const String _epochIso = '1970-01-01T00:00:00.000Z';

  static Future<void> syncNow() async {
    final settings = await DatabaseHelper.instance.getSettings();
    await _ensureSyncIsAllowed(settings);

    final isInitialSync = (settings['lastSyncAt'] as String?)?.isEmpty != false;
    if (isInitialSync) {
      final remoteSnapshot = await _fetchRemoteData(since: _epochIso);
      final remoteHasBusinessData = _hasRemoteBusinessData(remoteSnapshot);

      if (!remoteHasBusinessData &&
          await DatabaseHelper.instance.hasLocalBusinessData()) {
        await _pushPendingData();
        final refreshedSnapshot = await _fetchRemoteData(since: _epochIso);
        await _applyRemoteData(refreshedSnapshot);
        return;
      }

      await _applyRemoteData(remoteSnapshot);
      return;
    }

    await _pushPendingData();
    final remoteSnapshot = await _fetchRemoteData(
      since: settings['lastSyncAt'] as String? ?? _epochIso,
    );
    await _applyRemoteData(remoteSnapshot);
  }

  static Future<void> pushData() async => _pushPendingData();

  static Future<void> pullData() async {
    final settings = await DatabaseHelper.instance.getSettings();
    await _ensureSyncIsAllowed(settings);
    final data = await _fetchRemoteData(
      since: settings['lastSyncAt'] as String? ?? _epochIso,
    );
    await _applyRemoteData(data);
  }

  static Future<void> _ensureSyncIsAllowed(
    Map<String, dynamic> settings,
  ) async {
    final serverUrl = (settings['serverUrl'] as String?)?.trim();
    final syncEnabled = settings['syncEnabled'] == 1;
    final subscriptionStatus =
        (settings['subscriptionStatus'] as String?) ??
        CloudSubscriptionStatus.none;

    if (serverUrl == null || serverUrl.isEmpty) {
      throw SyncException('Set your server URL before using cloud sync.');
    }

    if (!syncEnabled) {
      throw SyncException('Cloud sync is turned off on this device.');
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
      throw SyncException('Log in to your cloud store before syncing.');
    }
  }

  static Future<Map<String, dynamic>> _fetchRemoteData({
    required String since,
  }) async {
    try {
      final response = await ApiClient.get(
        '/sync/pull?since=${Uri.encodeQueryComponent(since)}',
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      if (response.statusCode == 403) {
        final body = _decodeBody(response.body);
        await _setBlockedState(body['subscriptionStatus'] as String?);
        throw SyncException(
          'Store subscription is locked.',
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

  static Future<void> _pushPendingData() async {
    final db = await DatabaseHelper.instance.database;
    final settings = await DatabaseHelper.instance.getSettings();

    final pendingCategories = await db.query(
      'categories',
      where: "syncStatus = 'PENDING'",
    );
    final pendingItems = await db.query(
      'items',
      where: "syncStatus = 'PENDING'",
    );
    final pendingSales = await db.query(
      'sales',
      where: "syncStatus = 'PENDING'",
    );
    final pendingShifts = await db.query(
      'shifts',
      where: "syncStatus = 'PENDING'",
    );

    List<Map<String, dynamic>> pendingSaleItems = [];
    if (pendingSales.isNotEmpty) {
      final saleIds = pendingSales.map((sale) => sale['id']).toList();
      pendingSaleItems = await _querySaleItems(db, saleIds);
    }

    if (pendingCategories.isEmpty &&
        pendingItems.isEmpty &&
        pendingSales.isEmpty &&
        pendingShifts.isEmpty &&
        !(await DatabaseHelper.instance.hasLocalBusinessData())) {
      return;
    }

    final payload = {
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
      'categories': pendingCategories,
      'items': pendingItems,
      'sales': pendingSales,
      'saleItems': pendingSaleItems,
      'shifts': pendingShifts,
    };

    try {
      final response = await ApiClient.post('/sync/push', payload);

      if (response.statusCode == 200) {
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
        await DatabaseHelper.instance.updateSettings({
          'cloudMode': CloudMode.active,
          'subscriptionStatus': CloudSubscriptionStatus.active,
        });
        return;
      }

      if (response.statusCode == 403) {
        final body = _decodeBody(response.body);
        await _setBlockedState(body['subscriptionStatus'] as String?);
        throw SyncException(
          'Store subscription is locked.',
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

  static bool _hasRemoteBusinessData(Map<String, dynamic> data) {
    bool hasItems(String key) {
      final value = data[key];
      return value is List && value.isNotEmpty;
    }

    return hasItems('categories') ||
        hasItems('items') ||
        hasItems('sales') ||
        hasItems('shifts');
  }

  static Future<void> _applyRemoteData(Map<String, dynamic> data) async {
    final db = await DatabaseHelper.instance.database;
    final batch = db.batch();
    final store = _toMap(data['store']);
    final serverTime = data['serverTime'] as String?;

    if (store != null) {
      batch.update(
        'store_settings',
        {
          if (store['name'] != null) 'storeName': store['name'],
          if (store['address'] != null) 'storeAddress': store['address'],
          if (store['phone'] != null) 'storePhone': store['phone'],
          if (store['businessType'] != null)
            'businessType': store['businessType'],
          if (store['currency'] != null) 'currency': store['currency'],
          if (store['locale'] != null) 'locale': store['locale'],
          if (store['taxEnabled'] != null)
            'taxEnabled': _boolToInt(store['taxEnabled']),
          if (store['taxRate'] != null) 'taxRate': store['taxRate'],
          'receiptHeader': store['receiptHeader'],
          'receiptFooter': store['receiptFooter'],
          'remoteStoreId': store['id'],
          'cloudMode': CloudMode.active,
          'subscriptionStatus': CloudSubscriptionStatus.active,
          if (serverTime != null) 'lastSyncAt': serverTime,
        },
        where: 'id = ?',
        whereArgs: [1],
      );
    }

    for (final category in _toList(data['categories'])) {
      batch.insert('categories', {
        ...category,
        'syncStatus': 'SYNCED',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    for (final item in _toList(data['items'])) {
      batch.insert('items', {
        ...item,
        'trackStock': _boolToInt(item['trackStock']),
        'isActive': _boolToInt(item['isActive']),
        'syncStatus': 'SYNCED',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    for (final staff in _toList(data['staff'])) {
      batch.insert('staff', {
        'id': staff['id'],
        'name': staff['name'],
        'pin': staff['pinHash'],
        'role': staff['role'],
        'isActive': _boolToInt(staff['isActive']),
        'createdAt': staff['createdAt'],
        'updatedAt': staff['updatedAt'],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    final sales = _toList(data['sales']);
    if (sales.isNotEmpty) {
      final saleIds =
          sales
              .map((sale) => sale['id'])
              .where((saleId) => saleId != null)
              .toList();
      final placeholders = List.filled(saleIds.length, '?').join(',');
      if (placeholders.isNotEmpty) {
        batch.delete(
          'sale_items',
          where: 'saleId IN ($placeholders)',
          whereArgs: saleIds,
        );
      }
    }

    for (final sale in sales) {
      batch.insert('sales', {
        ...sale,
        'syncStatus': 'SYNCED',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    for (final saleItem in _toList(data['saleItems'])) {
      batch.insert(
        'sale_items',
        saleItem,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    for (final shift in _toList(data['shifts'])) {
      batch.insert('shifts', {
        ...shift,
        'syncStatus': 'SYNCED',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
  }

  static int _boolToInt(dynamic value) {
    if (value is bool) {
      return value ? 1 : 0;
    }
    if (value is num) {
      return value.toInt();
    }
    return 0;
  }

  static List<Map<String, dynamic>> _toList(dynamic value) {
    if (value is! List) {
      return [];
    }

    return value
        .whereType<Map>()
        .map(
          (row) => row.map(
            (key, dynamic rowValue) => MapEntry(key.toString(), rowValue),
          ),
        )
        .toList();
  }

  static Map<String, dynamic>? _toMap(dynamic value) {
    if (value is! Map) {
      return null;
    }

    return value.map(
      (key, dynamic rowValue) => MapEntry(key.toString(), rowValue),
    );
  }

  static Map<String, dynamic> _decodeBody(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return const {};
    }
  }

  static Future<void> _setBlockedState(String? status) async {
    final normalizedStatus =
        status == CloudSubscriptionStatus.expired
            ? CloudSubscriptionStatus.expired
            : CloudSubscriptionStatus.blocked;

    await DatabaseHelper.instance.updateSettings({
      'cloudMode': CloudMode.blocked,
      'subscriptionStatus': normalizedStatus,
      'syncEnabled': 0,
    });
  }
}
