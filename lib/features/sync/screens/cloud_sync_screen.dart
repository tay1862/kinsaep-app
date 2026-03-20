import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinsaep_pos/app/theme.dart';
import 'package:kinsaep_pos/core/database/database_helper.dart';
import 'package:kinsaep_pos/core/network/api_client.dart';
import 'package:kinsaep_pos/core/network/cloud_state.dart';
import 'package:kinsaep_pos/core/network/sync_service.dart';
import 'package:kinsaep_pos/core/providers/app_providers.dart';
import 'package:kinsaep_pos/core/services/store_realtime_client.dart';
import 'package:kinsaep_pos/features/auth/providers/auth_provider.dart';
import 'package:kinsaep_pos/features/auth/screens/login_screen.dart';
import 'package:kinsaep_pos/features/auth/screens/register_screen.dart';

class CloudSyncScreen extends ConsumerStatefulWidget {
  const CloudSyncScreen({super.key});

  @override
  ConsumerState<CloudSyncScreen> createState() => _CloudSyncScreenState();
}

class _CloudSyncScreenState extends ConsumerState<CloudSyncScreen> {
  final StoreRealtimeClient _realtimeClient = StoreRealtimeClient();
  String? _realtimeKey;

  @override
  void dispose() {
    _realtimeClient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(storeSettingsProvider);
    final authState = ref.watch(authProvider);
    final jobsAsync = ref.watch(syncJobsProvider);

    return Scaffold(
      backgroundColor: KinsaepTheme.surface,
      appBar: AppBar(
        title: const Text(
          'Cloud & Sync',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
      ),
      body: settingsAsync.when(
        data: (settings) {
          _bindRealtime(settings);
          final serverUrl = (settings['serverUrl'] as String?)?.trim() ?? '';
          final subscriptionStatus =
              (settings['subscriptionStatus'] as String?) ??
              CloudSubscriptionStatus.none;
          final syncEnabled = settings['syncEnabled'] == 1;
          final cloudMode =
              (settings['cloudMode'] as String?) ?? CloudMode.offlineOnly;
          final syncProfile =
              (settings['syncProfile'] as String?) ?? SyncProfileState.light;
          final currentSyncStatus =
              (settings['currentSyncStatus'] as String?) ?? SyncJobState.idle;
          final lastSyncProgress = (settings['lastSyncProgress'] as int?) ?? 0;
          final lastSyncError = settings['lastSyncError'] as String?;
          final lastSyncAt = settings['lastSyncAt'] as String?;
          final remoteStoreId = settings['remoteStoreId'] as String?;

          final hasCloudSession =
              authState.isAuthenticated &&
              (remoteStoreId?.isNotEmpty ?? false) &&
              serverUrl.isNotEmpty;

          return RefreshIndicator(
            onRefresh: () async {
              if (hasCloudSession) {
                await SyncService.refreshSyncStatus();
                await SyncService.refreshSyncJobs();
              }
              ref.invalidate(storeSettingsProvider);
              ref.invalidate(syncJobsProvider);
            },
            child: ListView(
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
                        'Cloud State',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_modeLabel(cloudMode)} • ${subscriptionStatus.toUpperCase()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        serverUrl.isEmpty ? 'Server URL not set' : serverUrl,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _ActionCard(
                  icon: Icons.dns_rounded,
                  title: 'Server URL',
                  subtitle: serverUrl.isEmpty ? 'Not configured' : serverUrl,
                  onTap: () => _editServerUrl(serverUrl),
                ),
                _ActionCard(
                  icon: Icons.tune_rounded,
                  title: 'Sync Profile',
                  subtitle: syncProfile,
                  onTap: () => _selectSyncProfile(syncProfile),
                ),
                SwitchListTile(
                  title: const Text(
                    'Sync on this device',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'Current status: $currentSyncStatus • ${lastSyncProgress.toString()}%',
                  ),
                  value: syncEnabled,
                  activeColor: KinsaepTheme.primary,
                  onChanged: (value) => _toggleSync(settings, value),
                ),
                if (!hasCloudSession) ...[
                  _ActionCard(
                    icon: Icons.login_rounded,
                    title: 'Log In',
                    subtitle: 'Connect this device to an existing store',
                    onTap: () => _openAuth(const LoginScreen(cloudFlow: true)),
                  ),
                  _ActionCard(
                    icon: Icons.app_registration_rounded,
                    title: 'Create Cloud Store',
                    subtitle:
                        'Create a store account and wait for admin activation',
                    onTap:
                        () => _openAuth(const RegisterScreen(cloudFlow: true)),
                  ),
                ] else ...[
                  _ActionCard(
                    icon: Icons.sync_rounded,
                    title: 'Sync Now',
                    subtitle:
                        'Push local changes and pull the latest cloud state',
                    onTap: _runSyncNow,
                  ),
                  _ActionCard(
                    icon: Icons.refresh_rounded,
                    title: 'Refresh Cloud Status',
                    subtitle:
                        'Reload entitlement and the latest remote sync jobs',
                    onTap: _refreshCloud,
                  ),
                  _ActionCard(
                    icon: Icons.logout_rounded,
                    title: 'Disconnect Cloud',
                    subtitle: 'Keep the POS offline on this device',
                    onTap: _disconnectCloud,
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: KinsaepTheme.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Diagnostics',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _diagRow('Remote Store', remoteStoreId ?? '-'),
                      _diagRow('Profile', syncProfile),
                      _diagRow(
                        'Last Sync',
                        lastSyncAt == null || lastSyncAt.isEmpty
                            ? '-'
                            : lastSyncAt,
                      ),
                      _diagRow('Progress', '$lastSyncProgress%'),
                      _diagRow(
                        'Last Error',
                        lastSyncError?.isNotEmpty == true
                            ? lastSyncError!
                            : '-',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Sync Jobs',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                jobsAsync.when(
                  data: (jobs) {
                    if (jobs.isEmpty) {
                      return _emptyPanel('No sync jobs yet.');
                    }
                    return Column(children: jobs.map(_buildJobCard).toList());
                  },
                  loading:
                      () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                  error:
                      (error, _) => _emptyPanel('Error loading jobs: $error'),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Future<void> _bindRealtime(Map<String, dynamic> settings) async {
    final remoteStoreId = settings['remoteStoreId'] as String?;
    final wsUrl = await ApiClient.getWebSocketUrl();
    if (remoteStoreId == null || remoteStoreId.isEmpty || wsUrl == null) {
      return;
    }
    final key = '$wsUrl::$remoteStoreId';
    if (_realtimeKey == key) {
      return;
    }
    _realtimeKey = key;
    await _realtimeClient.connect(wsUrl: wsUrl, storeId: remoteStoreId);
    _realtimeClient.events.listen((event) async {
      if (event.event.startsWith('sync.job')) {
        await SyncService.refreshSyncJobs();
        if (mounted) {
          ref.invalidate(syncJobsProvider);
          ref.invalidate(storeSettingsProvider);
        }
      }
    });
  }

  Future<void> _editServerUrl(String currentValue) async {
    final controller = TextEditingController(text: currentValue);
    final result = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Server URL'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'https://kanghan.site',
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed:
                    () => Navigator.pop(dialogContext, controller.text.trim()),
                child: const Text('Save'),
              ),
            ],
          ),
    );

    if (result == null) {
      return;
    }
    await DatabaseHelper.instance.updateSettings({'serverUrl': result});
    ref.invalidate(storeSettingsProvider);
  }

  Future<void> _selectSyncProfile(String currentProfile) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _profileTile(
                  currentProfile,
                  SyncProfileState.off,
                  'Offline only',
                ),
                _profileTile(
                  currentProfile,
                  SyncProfileState.light,
                  'Catalog, staff, kitchen, media thumbs, and summary',
                ),
                _profileTile(
                  currentProfile,
                  SyncProfileState.full,
                  'Everything in LIGHT plus raw sales and shifts',
                ),
              ],
            ),
          ),
    );

    if (result == null) {
      return;
    }
    await DatabaseHelper.instance.updateSettings({'syncProfile': result});
    ref.invalidate(storeSettingsProvider);
  }

  Widget _profileTile(String current, String value, String subtitle) {
    return ListTile(
      leading: Icon(
        current == value ? Icons.radio_button_checked : Icons.radio_button_off,
      ),
      title: Text(value),
      subtitle: Text(subtitle),
      onTap: () => Navigator.pop(context, value),
    );
  }

  Future<void> _toggleSync(Map<String, dynamic> settings, bool enabled) async {
    final serverUrl = (settings['serverUrl'] as String?)?.trim() ?? '';
    final remoteStoreId = (settings['remoteStoreId'] as String?)?.trim() ?? '';
    final subscriptionStatus =
        (settings['subscriptionStatus'] as String?) ??
        CloudSubscriptionStatus.none;

    if (enabled) {
      if (serverUrl.isEmpty) {
        _showMessage('Set your server URL first.');
        return;
      }
      if (remoteStoreId.isEmpty) {
        _showMessage('Connect to a cloud store first.');
        return;
      }
      if (subscriptionStatus != CloudSubscriptionStatus.active) {
        _showMessage(
          'This store is $subscriptionStatus, so sync cannot be enabled.',
        );
        return;
      }
    }

    await DatabaseHelper.instance.updateSettings({
      'syncEnabled': enabled ? 1 : 0,
    });
    ref.invalidate(storeSettingsProvider);
  }

  Future<void> _runSyncNow() async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Expanded(child: Text('Syncing with your cloud server...')),
              ],
            ),
          ),
    );
    try {
      await SyncService.syncNow();
      if (!mounted) {
        return;
      }
      Navigator.pop(context);
      ref.invalidate(storeSettingsProvider);
      ref.invalidate(syncJobsProvider);
      ref.invalidate(staffProvider);
      ref.invalidate(devicesProvider);
      ref.invalidate(categoriesProvider);
      ref.invalidate(itemsProvider);
      ref.invalidate(kitchenTicketsProvider);
      _showMessage('Cloud sync completed.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      Navigator.pop(context);
      _showMessage('$error');
      ref.invalidate(storeSettingsProvider);
      ref.invalidate(syncJobsProvider);
    }
  }

  Future<void> _refreshCloud() async {
    try {
      await SyncService.refreshSyncStatus();
      await SyncService.refreshSyncJobs();
      ref.invalidate(storeSettingsProvider);
      ref.invalidate(syncJobsProvider);
      _showMessage('Cloud status refreshed.');
    } catch (error) {
      _showMessage('$error');
    }
  }

  Future<void> _disconnectCloud() async {
    await ref.read(authProvider.notifier).logout();
    ref.invalidate(storeSettingsProvider);
    ref.invalidate(syncJobsProvider);
    _showMessage('Cloud session removed from this device.');
  }

  Future<void> _openAuth(Widget screen) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    if (result == true && mounted) {
      await SyncService.refreshSyncStatus();
      await SyncService.refreshSyncJobs();
      ref.invalidate(authProvider);
      ref.invalidate(storeSettingsProvider);
      ref.invalidate(syncJobsProvider);
    }
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    final scopes = _parseScopes(job['scopes']);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: KinsaepTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${job['direction']} • ${job['status']}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text('${job['progress'] ?? 0}%'),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: ((job['progress'] as num?)?.toDouble() ?? 0) / 100,
            backgroundColor: KinsaepTheme.border,
            color: KinsaepTheme.primary,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children:
                scopes
                    .map(
                      (scope) => Chip(
                        label: Text(scope),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
          ),
          if ((job['error'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              job['error'] as String,
              style: const TextStyle(color: KinsaepTheme.error),
            ),
          ],
        ],
      ),
    );
  }

  List<String> _parseScopes(dynamic scopesValue) {
    if (scopesValue is String && scopesValue.isNotEmpty) {
      try {
        return (jsonDecode(scopesValue) as List<dynamic>).cast<String>();
      } catch (_) {
        return scopesValue.split(',').map((scope) => scope.trim()).toList();
      }
    }
    return const <String>[];
  }

  Widget _emptyPanel(String text) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: KinsaepTheme.cardShadow,
      ),
      child: Text(
        text,
        style: const TextStyle(color: KinsaepTheme.textSecondary),
      ),
    );
  }

  Widget _diagRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: KinsaepTheme.textSecondary,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static String _modeLabel(String mode) {
    switch (mode) {
      case CloudMode.active:
        return 'Active';
      case CloudMode.blocked:
        return 'Blocked';
      default:
        return 'Offline Only';
    }
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
}
