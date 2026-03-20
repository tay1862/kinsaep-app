import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinsaep_pos/app/theme.dart';
import 'package:kinsaep_pos/core/database/database_helper.dart';
import 'package:kinsaep_pos/core/network/api_client.dart';
import 'package:kinsaep_pos/core/network/cloud_state.dart';
import 'package:kinsaep_pos/core/providers/app_providers.dart';
import 'package:kinsaep_pos/core/utils/pin_security.dart';
import 'package:uuid/uuid.dart';

class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(staffProvider);
    final settingsAsync = ref.watch(storeSettingsProvider);

    return Scaffold(
      backgroundColor: KinsaepTheme.surface,
      appBar: AppBar(
        title: const Text(
          'Staff',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
      ),
      body: settingsAsync.when(
        data:
            (settings) => staffAsync.when(
              data:
                  (staff) => ListView(
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
                              'Staff Overview',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${staff.length} active staff',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _cloudNote(settings),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.88),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      ...staff.map(
                        (member) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: KinsaepTheme.cardShadow,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: KinsaepTheme.primary.withValues(
                                alpha: 0.1,
                              ),
                              child: Text(
                                (member['name'] as String)
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: const TextStyle(
                                  color: KinsaepTheme.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            title: Text(
                              member['name'] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              member['role'] as String? ?? 'CASHIER',
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _showStaffForm(
                                    context,
                                    ref,
                                    settings,
                                    initial: member,
                                  );
                                } else if (value == 'delete') {
                                  _deleteStaff(context, ref, settings, member);
                                }
                              },
                              itemBuilder:
                                  (context) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Deactivate'),
                                    ),
                                  ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
            ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final settings = await ref.read(storeSettingsProvider.future);
          if (context.mounted) {
            _showStaffForm(context, ref, settings);
          }
        },
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add Staff'),
      ),
    );
  }

  Future<void> _showStaffForm(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> settings, {
    Map<String, dynamic>? initial,
  }) async {
    final nameController = TextEditingController(
      text: initial?['name'] as String?,
    );
    final pinController = TextEditingController();
    String role = initial?['role'] as String? ?? 'CASHIER';

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
                          Text(
                            initial == null ? 'Add Staff' : 'Edit Staff',
                            style: const TextStyle(
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
                        decoration: const InputDecoration(labelText: 'Name'),
                        autofocus: true,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: role,
                        items: const [
                          DropdownMenuItem(
                            value: 'OWNER',
                            child: Text('OWNER'),
                          ),
                          DropdownMenuItem(
                            value: 'MANAGER',
                            child: Text('MANAGER'),
                          ),
                          DropdownMenuItem(
                            value: 'CASHIER',
                            child: Text('CASHIER'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setSheetState(() => role = value);
                          }
                        },
                        decoration: const InputDecoration(labelText: 'Role'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: pinController,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 6,
                        decoration: InputDecoration(
                          labelText:
                              initial == null
                                  ? 'PIN (4-6 digits)'
                                  : 'New PIN (optional)',
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () async {
                            final name = nameController.text.trim();
                            final pin = pinController.text.trim();
                            if (name.isEmpty) {
                              _showMessage(context, 'Staff name is required.');
                              return;
                            }
                            if (initial == null &&
                                (pin.length < 4 || pin.length > 6)) {
                              _showMessage(context, 'PIN must be 4-6 digits.');
                              return;
                            }
                            if (initial != null &&
                                pin.isNotEmpty &&
                                (pin.length < 4 || pin.length > 6)) {
                              _showMessage(context, 'PIN must be 4-6 digits.');
                              return;
                            }

                            try {
                              await _saveStaff(
                                settings: settings,
                                initial: initial,
                                name: name,
                                role: role,
                                pin: pin,
                              );
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                              ref.invalidate(staffProvider);
                            } catch (error) {
                              if (!context.mounted) {
                                return;
                              }
                              _showMessage(context, '$error');
                            }
                          },
                          child: Text(
                            initial == null ? 'Create Staff' : 'Save Changes',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  Future<void> _saveStaff({
    required Map<String, dynamic> settings,
    required Map<String, dynamic>? initial,
    required String name,
    required String role,
    required String pin,
  }) async {
    final canWriteCloud = await _canWriteCloud(settings);
    final now = DateTime.now().toIso8601String();
    String staffId = initial?['id'] as String? ?? const Uuid().v4();
    final localPinHash =
        pin.isNotEmpty
            ? PinSecurity.hashPin(pin)
            : (initial?['pin'] as String? ?? '');

    if (canWriteCloud) {
      if (initial == null) {
        final response = await ApiClient.post('/staff', {
          'name': name,
          'pin': pin,
          'role': role,
        });
        if (response.statusCode == 201) {
          final body = ApiClientResponse.decode(response.body);
          staffId = body['id'] as String? ?? staffId;
        } else {
          final body = ApiClientResponse.decode(response.body);
          throw Exception(body['error'] ?? 'Failed to create staff.');
        }
      } else {
        final response = await ApiClient.patch('/staff/$staffId', {
          'name': name,
          'role': role,
          if (pin.isNotEmpty) 'pin': pin,
        });
        if (response.statusCode != 200) {
          final body = ApiClientResponse.decode(response.body);
          throw Exception(body['error'] ?? 'Failed to update staff.');
        }
      }
    }

    await DatabaseHelper.instance.upsertStaffMember({
      'id': staffId,
      'name': name,
      'pin': localPinHash,
      'role': role,
      'isActive': 1,
      'createdAt': initial?['createdAt'] ?? now,
      'updatedAt': now,
    });
  }

  Future<void> _deleteStaff(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> settings,
    Map<String, dynamic> member,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Deactivate Staff'),
            content: Text('Deactivate ${member['name']}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Deactivate'),
              ),
            ],
          ),
    );

    if (confirmed != true) {
      return;
    }

    final canWriteCloud = await _canWriteCloud(settings);
    final staffId = member['id'] as String;
    if (canWriteCloud) {
      final response = await ApiClient.delete('/staff/$staffId');
      if (response.statusCode != 200) {
        if (!context.mounted) {
          return;
        }
        final body = ApiClientResponse.decode(response.body);
        _showMessage(context, body['error'] as String? ?? 'Delete failed.');
        return;
      }
    } else {
      await DatabaseHelper.instance.createTombstone('STAFF', staffId);
    }

    await DatabaseHelper.instance.updateStaffMember(staffId, {
      'isActive': 0,
      'updatedAt': DateTime.now().toIso8601String(),
    });
    ref.invalidate(staffProvider);
  }

  static Future<bool> _canWriteCloud(Map<String, dynamic> settings) async {
    final hasSession = await ApiClient.hasSession();
    return hasSession &&
        ((settings['serverUrl'] as String?)?.isNotEmpty ?? false) &&
        (settings['syncEnabled'] == 1) &&
        ((settings['subscriptionStatus'] as String?) ==
            CloudSubscriptionStatus.active);
  }

  static String _cloudNote(Map<String, dynamic> settings) {
    if ((settings['syncEnabled'] == 1) &&
        ((settings['subscriptionStatus'] as String?) ==
            CloudSubscriptionStatus.active)) {
      return 'Cloud write is active on this device.';
    }
    return 'This screen works offline-first. Cloud updates resume when sync is active.';
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class ApiClientResponse {
  static Map<String, dynamic> decode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{'error': body};
    }
  }
}
