import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinsaep_pos/app/theme.dart';
import 'package:kinsaep_pos/core/database/database_helper.dart';
import 'package:kinsaep_pos/core/network/api_client.dart';
import 'package:kinsaep_pos/core/network/cloud_state.dart';
import 'package:kinsaep_pos/core/providers/app_providers.dart';
import 'package:kinsaep_pos/features/kitchen/screens/kitchen_console_screen.dart';

class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(storeSettingsProvider);
    final devicesAsync = ref.watch(devicesProvider);

    return Scaffold(
      backgroundColor: KinsaepTheme.surface,
      appBar: AppBar(
        title: const Text(
          'Devices',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
      ),
      body: settingsAsync.when(
        data:
            (settings) => devicesAsync.when(
              data: (devices) {
                final deviceId = settings['deviceId'] as String?;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: KinsaepTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Current Device',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            settings['deviceName'] as String? ?? 'This Device',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${settings['deviceType']} • ${settings['scannerMode']} • ${settings['syncProfile']}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _deviceAction(
                      icon: Icons.edit_rounded,
                      title: 'Configure Current Device',
                      subtitle:
                          'Rename, select device mode, scanner mode, and sync profile',
                      onTap: () => _editCurrentDevice(settings),
                    ),
                    if ((settings['deviceType'] as String?) ==
                        DeviceTypeState.kitchen)
                      _deviceAction(
                        icon: Icons.soup_kitchen_rounded,
                        title: 'Open Kitchen Console',
                        subtitle:
                            'Preview the dedicated kitchen mode for this device',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const KitchenConsoleScreen(),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 8),
                    const Text(
                      'Known Devices',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...devices.map(
                      (device) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: KinsaepTheme.cardShadow,
                        ),
                        child: ListTile(
                          leading: Icon(
                            _deviceIcon(device['type'] as String?),
                            color: KinsaepTheme.primary,
                          ),
                          title: Text(
                            device['name'] as String? ?? '-',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${device['type']} • ${device['status']} • ${device['scannerMode']}',
                          ),
                          trailing:
                              device['id'] == deviceId
                                  ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: KinsaepTheme.primary.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'This device',
                                      style: TextStyle(
                                        color: KinsaepTheme.primary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  )
                                  : null,
                        ),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
            ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _deviceAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: KinsaepTheme.cardShadow,
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: KinsaepTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: KinsaepTheme.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }

  Future<void> _editCurrentDevice(Map<String, dynamic> settings) async {
    final nameController = TextEditingController(
      text: settings['deviceName'] as String? ?? 'This Device',
    );
    String deviceType =
        (settings['deviceType'] as String?) ?? DeviceTypeState.pos;
    String scannerMode =
        (settings['scannerMode'] as String?) ?? ScannerModeState.auto;
    String syncProfile =
        (settings['syncProfile'] as String?) ?? SyncProfileState.light;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (sheetContext) => StatefulBuilder(
            builder:
                (sheetContext, setSheetState) => Container(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 20,
                    bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Configure Current Device',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Device Name',
                        ),
                        autofocus: true,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: deviceType,
                        items: const [
                          DropdownMenuItem(value: 'POS', child: Text('POS')),
                          DropdownMenuItem(
                            value: 'KITCHEN',
                            child: Text('KITCHEN'),
                          ),
                          DropdownMenuItem(
                            value: 'MANAGER',
                            child: Text('MANAGER'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setSheetState(() => deviceType = value);
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Device Type',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: scannerMode,
                        items: const [
                          DropdownMenuItem(value: 'AUTO', child: Text('AUTO')),
                          DropdownMenuItem(
                            value: 'CAMERA',
                            child: Text('CAMERA'),
                          ),
                          DropdownMenuItem(value: 'HID', child: Text('HID')),
                          DropdownMenuItem(
                            value: 'SUNMI',
                            child: Text('SUNMI'),
                          ),
                          DropdownMenuItem(
                            value: 'ZEBRA',
                            child: Text('ZEBRA'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setSheetState(() => scannerMode = value);
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Scanner Mode',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: syncProfile,
                        items: const [
                          DropdownMenuItem(value: 'OFF', child: Text('OFF')),
                          DropdownMenuItem(
                            value: 'LIGHT',
                            child: Text('LIGHT'),
                          ),
                          DropdownMenuItem(value: 'FULL', child: Text('FULL')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setSheetState(() => syncProfile = value);
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Sync Profile',
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () async {
                            try {
                              await _saveCurrentDevice(
                                settings: settings,
                                name: nameController.text.trim(),
                                type: deviceType,
                                scannerMode: scannerMode,
                                syncProfile: syncProfile,
                              );
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                              ref.invalidate(storeSettingsProvider);
                              ref.invalidate(devicesProvider);
                            } catch (error) {
                              _showMessage('$error');
                            }
                          },
                          child: const Text('Save Device'),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  Future<void> _saveCurrentDevice({
    required Map<String, dynamic> settings,
    required String name,
    required String type,
    required String scannerMode,
    required String syncProfile,
  }) async {
    final deviceId = await DatabaseHelper.instance.getOrCreateDeviceId();
    final now = DateTime.now().toIso8601String();
    final payload = {
      'id': deviceId,
      'name': name.isEmpty ? 'This Device' : name,
      'type': type,
      'platform': Platform.isIOS ? 'IOS' : 'ANDROID',
      'scannerMode': scannerMode,
      'syncProfile': syncProfile,
    };

    await DatabaseHelper.instance.updateSettings({
      'deviceName': payload['name'],
      'deviceType': type,
      'scannerMode': scannerMode,
      'syncProfile': syncProfile,
      'deviceId': deviceId,
    });
    await DatabaseHelper.instance.upsertDevice({
      ...payload,
      'status': 'ONLINE',
      'isActive': 1,
      'lastSeenAt': now,
      'createdAt': now,
      'updatedAt': now,
    });

    if (await _canWriteCloud(settings)) {
      final patchResponse = await ApiClient.patch('/devices/$deviceId', {
        'name': payload['name'],
        'type': type,
        'platform': payload['platform'],
        'scannerMode': scannerMode,
        'syncProfile': syncProfile,
        'status': 'ONLINE',
      });

      if (patchResponse.statusCode != 200) {
        final createResponse = await ApiClient.post('/devices', payload);
        if (createResponse.statusCode != 201) {
          final body = _decodeResponse(
            createResponse.statusCode >= 400
                ? createResponse.body
                : patchResponse.body,
          );
          throw Exception(body['error'] ?? 'Failed to register device.');
        }
      }
    }
  }

  static Future<bool> _canWriteCloud(Map<String, dynamic> settings) async {
    final hasSession = await ApiClient.hasSession();
    return hasSession &&
        ((settings['serverUrl'] as String?)?.isNotEmpty ?? false) &&
        (settings['syncEnabled'] == 1) &&
        ((settings['subscriptionStatus'] as String?) ==
            CloudSubscriptionStatus.active);
  }

  static Map<String, dynamic> _decodeResponse(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{'error': body};
    }
  }

  static IconData _deviceIcon(String? type) {
    switch (type) {
      case DeviceTypeState.kitchen:
        return Icons.soup_kitchen_rounded;
      case DeviceTypeState.manager:
        return Icons.manage_accounts_rounded;
      default:
        return Icons.point_of_sale_rounded;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
