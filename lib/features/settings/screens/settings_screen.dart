import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kinsaep_pos/app/theme.dart';
import 'package:kinsaep_pos/core/database/database_helper.dart';
import 'package:kinsaep_pos/core/network/cloud_state.dart';
import 'package:kinsaep_pos/core/network/sync_service.dart';
import 'package:kinsaep_pos/core/providers/app_providers.dart';
import 'package:kinsaep_pos/features/auth/providers/auth_provider.dart';
import 'package:kinsaep_pos/features/auth/screens/login_screen.dart';
import 'package:kinsaep_pos/features/auth/screens/register_screen.dart';
import 'package:kinsaep_pos/features/reports/screens/shifts_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(storeSettingsProvider);
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: KinsaepTheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: KinsaepTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.settings_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      l10n.settings,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              settings.when(
                data:
                    (data) => Column(
                      children: [
                        _SectionHeader(title: l10n.storeName),
                        _SettingsCard(
                          children: [
                            _SettingsTile(
                              icon: Icons.store_rounded,
                              title: l10n.storeName,
                              subtitle: data['storeName'] as String,
                              onTap:
                                  () => _editSetting(
                                    context,
                                    l10n.storeName,
                                    data['storeName'] as String,
                                    'storeName',
                                  ),
                            ),
                            _SettingsTile(
                              icon: Icons.location_on_rounded,
                              title: l10n.storeAddress,
                              subtitle:
                                  (data['storeAddress'] as String?) ?? '-',
                              onTap:
                                  () => _editSetting(
                                    context,
                                    l10n.storeAddress,
                                    (data['storeAddress'] as String?) ?? '',
                                    'storeAddress',
                                  ),
                            ),
                            _SettingsTile(
                              icon: Icons.phone_rounded,
                              title: l10n.storePhone,
                              subtitle: (data['storePhone'] as String?) ?? '-',
                              onTap:
                                  () => _editSetting(
                                    context,
                                    l10n.storePhone,
                                    (data['storePhone'] as String?) ?? '',
                                    'storePhone',
                                  ),
                              showDivider: false,
                            ),
                          ],
                        ),

                        const _SectionHeader(title: 'Shift Management'),
                        _SettingsCard(
                          children: [
                            _SettingsTile(
                              icon: Icons.lock_clock_rounded,
                              title: 'Cash Drawer & Shifts',
                              subtitle: 'Open or close your daily shift',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ShiftsScreen(),
                                  ),
                                );
                              },
                              showDivider: false,
                            ),
                          ],
                        ),

                        _SectionHeader(title: l10n.businessType),
                        _SettingsCard(
                          children: [
                            _SettingsTile(
                              icon: Icons.business_rounded,
                              title: l10n.businessType,
                              subtitle: _getBusinessTypeLabel(
                                data['businessType'] as String,
                                l10n,
                              ),
                              onTap:
                                  () => _selectBusinessType(
                                    context,
                                    data['businessType'] as String,
                                    l10n,
                                  ),
                              showDivider: false,
                            ),
                          ],
                        ),

                        _SectionHeader(
                          title: '${l10n.language} & ${l10n.currency}',
                        ),
                        _SettingsCard(
                          children: [
                            _SettingsTile(
                              icon: Icons.language_rounded,
                              title: l10n.language,
                              subtitle: _getLanguageLabel(
                                data['locale'] as String,
                              ),
                              onTap:
                                  () => _selectLanguage(
                                    context,
                                    data['locale'] as String,
                                    l10n,
                                  ),
                            ),
                            _SettingsTile(
                              icon: Icons.attach_money_rounded,
                              title: l10n.currency,
                              subtitle: _getCurrencyLabel(
                                data['currency'] as String,
                                l10n,
                              ),
                              onTap:
                                  () => _selectCurrency(
                                    context,
                                    data['currency'] as String,
                                    l10n,
                                  ),
                              showDivider: false,
                            ),
                          ],
                        ),

                        _SectionHeader(title: 'Cloud Connection'),
                        _SettingsCard(
                          children: _buildCloudSection(
                            context,
                            data,
                            authState,
                          ),
                        ),

                        _SectionHeader(title: l10n.tax),
                        _SettingsCard(
                          children: [
                            SwitchListTile(
                              title: Text(
                                l10n.enableTax,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              secondary: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: KinsaepTheme.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.percent_rounded,
                                  color: KinsaepTheme.primary,
                                  size: 20,
                                ),
                              ),
                              value: data['taxEnabled'] == 1,
                              activeColor: KinsaepTheme.primary,
                              onChanged: (value) async {
                                await DatabaseHelper.instance.updateSettings({
                                  'taxEnabled': value ? 1 : 0,
                                });
                                ref.invalidate(storeSettingsProvider);
                              },
                            ),
                            if (data['taxEnabled'] == 1)
                              _SettingsTile(
                                icon: Icons.calculate_rounded,
                                title: l10n.taxRate,
                                subtitle: '${data['taxRate']}%',
                                onTap:
                                    () => _editSetting(
                                      context,
                                      l10n.taxRate,
                                      '${data['taxRate']}',
                                      'taxRate',
                                      isNumber: true,
                                    ),
                                showDivider: false,
                              ),
                          ],
                        ),

                        _SectionHeader(title: l10n.printer),
                        _SettingsCard(
                          children: [
                            _SettingsTile(
                              icon: Icons.print_rounded,
                              title: l10n.printer,
                              subtitle: 'Not connected',
                              onTap: () {},
                              showDivider: false,
                            ),
                          ],
                        ),

                        const _SectionHeader(title: 'Receipt Configuration'),
                        _SettingsCard(
                          children: [
                            _SettingsTile(
                              icon: Icons.title_rounded,
                              title: 'Receipt Header',
                              subtitle:
                                  (data['receiptHeader'] as String?)
                                              ?.isNotEmpty ==
                                          true
                                      ? (data['receiptHeader'] as String)
                                      : 'Not set',
                              onTap:
                                  () => _editSetting(
                                    context,
                                    'Receipt Header',
                                    (data['receiptHeader'] as String?) ?? '',
                                    'receiptHeader',
                                  ),
                            ),
                            _SettingsTile(
                              icon: Icons.text_snippet_rounded,
                              title: 'Receipt Footer',
                              subtitle:
                                  (data['receiptFooter'] as String?)
                                              ?.isNotEmpty ==
                                          true
                                      ? (data['receiptFooter'] as String)
                                      : 'Not set',
                              onTap:
                                  () => _editSetting(
                                    context,
                                    'Receipt Footer',
                                    (data['receiptFooter'] as String?) ?? '',
                                    'receiptFooter',
                                  ),
                              showDivider: false,
                            ),
                          ],
                        ),

                        _SectionHeader(title: l10n.about),
                        _SettingsCard(
                          children: [
                            _SettingsTile(
                              icon: Icons.info_outline_rounded,
                              title: 'Kinsaep POS',
                              subtitle: '${l10n.version} 1.0.0',
                              onTap: () {},
                              showDivider: false,
                            ),
                          ],
                        ),
                        const SizedBox(height: 100),
                      ],
                    ),
                loading:
                    () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                error: (error, _) => Center(child: Text('Error: $error')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCloudSection(
    BuildContext context,
    Map<String, dynamic> data,
    AuthState authState,
  ) {
    final serverUrl = (data['serverUrl'] as String?) ?? '';
    final subscriptionStatus =
        (data['subscriptionStatus'] as String?) ?? CloudSubscriptionStatus.none;
    final remoteStoreId = data['remoteStoreId'] as String?;
    final syncEnabled = data['syncEnabled'] == 1;
    final hasCloudSession =
        authState.isAuthenticated && (remoteStoreId?.isNotEmpty ?? false);
    final canSync =
        hasCloudSession &&
        serverUrl.isNotEmpty &&
        syncEnabled &&
        subscriptionStatus == CloudSubscriptionStatus.active;

    return [
      _SettingsTile(
        icon: Icons.dns_rounded,
        title: 'Server URL',
        subtitle: serverUrl.isEmpty ? 'Not configured' : serverUrl,
        onTap:
            () => _editSetting(context, 'Server URL', serverUrl, 'serverUrl'),
      ),
      _SettingsTile(
        icon: Icons.cloud_done_rounded,
        title: 'Cloud Status',
        subtitle: _buildCloudStatusText(data, hasCloudSession),
        onTap: () {},
        showDivider: !hasCloudSession,
      ),
      if (!hasCloudSession) ...[
        _SettingsTile(
          icon: Icons.login_rounded,
          title: 'Log In to Cloud',
          subtitle: 'Connect this device to an existing cloud store',
          onTap:
              () => _openCloudAuth(context, const LoginScreen(cloudFlow: true)),
        ),
        _SettingsTile(
          icon: Icons.app_registration_rounded,
          title: 'Create Cloud Store',
          subtitle: 'Create an account and wait for admin activation',
          onTap:
              () => _openCloudAuth(
                context,
                const RegisterScreen(cloudFlow: true),
              ),
          showDivider: false,
        ),
      ] else ...[
        SwitchListTile(
          value: syncEnabled,
          activeColor: KinsaepTheme.primary,
          onChanged: (value) => _toggleSync(context, data, value),
          secondary: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: KinsaepTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.sync_rounded,
              color: KinsaepTheme.primary,
              size: 20,
            ),
          ),
          title: const Text(
            'Sync on this device',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            subscriptionStatus == CloudSubscriptionStatus.active
                ? 'Enable or pause cloud sync for this device only'
                : 'Unavailable while the subscription is $subscriptionStatus',
          ),
        ),
        ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:
                  canSync
                      ? KinsaepTheme.primary.withValues(alpha: 0.1)
                      : KinsaepTheme.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.cloud_sync_rounded,
              color: canSync ? KinsaepTheme.primary : KinsaepTheme.warning,
              size: 20,
            ),
          ),
          title: const Text(
            'Sync Now',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            canSync
                ? 'Push local data to the cloud and pull the latest updates'
                : 'Fix cloud status, server URL, or device sync toggle before syncing',
          ),
          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          onTap: () => _syncNow(context),
        ),
        _SettingsTile(
          icon: Icons.logout_rounded,
          title: 'Disconnect Cloud',
          subtitle: 'Keep the POS offline on this device',
          onTap: () => _disconnectCloud(context),
          showDivider: false,
        ),
      ],
    ];
  }

  Future<void> _openCloudAuth(BuildContext context, Widget screen) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );

    if (result == true && mounted) {
      ref.invalidate(storeSettingsProvider);
      ref.invalidate(authProvider);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Cloud account connected on this device.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _syncNow(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
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
      navigator.pop();
      ref.invalidate(storeSettingsProvider);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Cloud sync completed successfully.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      navigator.pop();
      ref.invalidate(storeSettingsProvider);
      final isLocked = error is SyncException && error.isSubscriptionLocked;
      showDialog(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: Text(isLocked ? 'Subscription Locked' : 'Sync Error'),
              content: Text(
                isLocked
                    ? 'Your subscription is blocked or expired. This device can keep working offline, but cloud sync is disabled.'
                    : '$error',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
    }
  }

  Future<void> _toggleSync(
    BuildContext context,
    Map<String, dynamic> data,
    bool enabled,
  ) async {
    final subscriptionStatus =
        (data['subscriptionStatus'] as String?) ?? CloudSubscriptionStatus.none;
    final serverUrl = (data['serverUrl'] as String?)?.trim() ?? '';
    final hasRemoteStore =
        (data['remoteStoreId'] as String?)?.isNotEmpty ?? false;

    if (enabled) {
      if (serverUrl.isEmpty) {
        _showMessage(context, 'Set your server URL before enabling sync.');
        return;
      }
      if (!hasRemoteStore) {
        _showMessage(context, 'Connect to a cloud store before enabling sync.');
        return;
      }
      if (subscriptionStatus != CloudSubscriptionStatus.active) {
        _showMessage(
          context,
          'This store subscription is $subscriptionStatus. Sync cannot be enabled.',
        );
        return;
      }
    }

    await DatabaseHelper.instance.updateSettings({
      'syncEnabled': enabled ? 1 : 0,
    });
    ref.invalidate(storeSettingsProvider);
  }

  Future<void> _disconnectCloud(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(authProvider.notifier).logout();
    if (!context.mounted) {
      return;
    }
    ref.invalidate(storeSettingsProvider);
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Cloud session removed. This device is now offline-only.',
        ),
      ),
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _buildCloudStatusText(
    Map<String, dynamic> data,
    bool hasCloudSession,
  ) {
    final cloudMode = (data['cloudMode'] as String?) ?? CloudMode.offlineOnly;
    final subscriptionStatus =
        (data['subscriptionStatus'] as String?) ?? CloudSubscriptionStatus.none;
    final remoteStoreId = data['remoteStoreId'] as String?;
    final lastSyncAt = data['lastSyncAt'] as String?;

    if (!hasCloudSession) {
      return 'Offline-only device. Configure a server URL and connect a cloud account when needed.';
    }

    final parts = <String>[
      'Mode: ${_formatCloudMode(cloudMode)}',
      'Subscription: $subscriptionStatus',
      if (remoteStoreId != null && remoteStoreId.isNotEmpty)
        'Store: $remoteStoreId',
      if (lastSyncAt != null && lastSyncAt.isNotEmpty)
        'Last sync: ${_formatDateTime(lastSyncAt)}',
    ];

    return parts.join(' • ');
  }

  String _formatCloudMode(String mode) {
    switch (mode) {
      case CloudMode.active:
        return 'Cloud Active';
      case CloudMode.blocked:
        return 'Cloud Blocked';
      default:
        return 'Offline Only';
    }
  }

  String _formatDateTime(String value) {
    try {
      final dateTime = DateTime.parse(value).toLocal();
      return DateFormat('dd MMM yyyy HH:mm').format(dateTime);
    } catch (_) {
      return value;
    }
  }

  String _getBusinessTypeLabel(String type, AppLocalizations l10n) {
    switch (type) {
      case 'restaurant':
        return l10n.restaurant;
      case 'retail':
        return l10n.retail;
      case 'warehouse':
        return l10n.warehouse;
      case 'service':
        return l10n.service;
      default:
        return l10n.retail;
    }
  }

  String _getLanguageLabel(String locale) {
    switch (locale) {
      case 'lo':
        return 'ລາວ';
      case 'th':
        return 'ไทย';
      case 'en':
        return 'English';
      default:
        return 'English';
    }
  }

  String _getCurrencyLabel(String currency, AppLocalizations l10n) {
    switch (currency) {
      case 'LAK':
        return l10n.laoKip;
      case 'THB':
        return l10n.thaiBaht;
      case 'USD':
        return l10n.usDollar;
      default:
        return currency;
    }
  }

  void _editSetting(
    BuildContext context,
    String title,
    String currentValue,
    String field, {
    bool isNumber = false,
  }) {
    final controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  isNumber
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.text,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              ElevatedButton(
                onPressed: () async {
                  final value =
                      isNumber
                          ? double.tryParse(controller.text) ?? 0
                          : controller.text.trim();
                  await DatabaseHelper.instance.updateSettings({field: value});
                  ref.invalidate(storeSettingsProvider);
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                },
                child: Text(AppLocalizations.of(context)!.save),
              ),
            ],
          ),
    );
  }

  void _selectBusinessType(
    BuildContext context,
    String current,
    AppLocalizations l10n,
  ) {
    final types = [
      {
        'value': 'restaurant',
        'label': l10n.restaurant,
        'icon': Icons.restaurant_rounded,
      },
      {'value': 'retail', 'label': l10n.retail, 'icon': Icons.store_rounded},
      {
        'value': 'warehouse',
        'label': l10n.warehouse,
        'icon': Icons.warehouse_rounded,
      },
      {'value': 'service', 'label': l10n.service, 'icon': Icons.work_rounded},
    ];
    _showSelectionSheet(
      context,
      l10n.businessType,
      types,
      current,
      'businessType',
    );
  }

  void _selectLanguage(
    BuildContext context,
    String current,
    AppLocalizations l10n,
  ) {
    final options = [
      {'value': 'lo', 'label': 'ລາວ', 'icon': Icons.language_rounded},
      {'value': 'th', 'label': 'ไทย', 'icon': Icons.language_rounded},
      {'value': 'en', 'label': 'English', 'icon': Icons.language_rounded},
    ];
    _showSelectionSheet(context, l10n.language, options, current, 'locale');
  }

  void _selectCurrency(
    BuildContext context,
    String current,
    AppLocalizations l10n,
  ) {
    final options = [
      {'value': 'LAK', 'label': l10n.laoKip, 'icon': Icons.money_rounded},
      {'value': 'THB', 'label': l10n.thaiBaht, 'icon': Icons.money_rounded},
      {
        'value': 'USD',
        'label': l10n.usDollar,
        'icon': Icons.attach_money_rounded,
      },
    ];
    _showSelectionSheet(context, l10n.currency, options, current, 'currency');
  }

  void _showSelectionSheet(
    BuildContext context,
    String title,
    List<Map<String, dynamic>> options,
    String current,
    String field,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (sheetContext) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ...options.map(
                  (option) => ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            option['value'] == current
                                ? KinsaepTheme.primary.withValues(alpha: 0.1)
                                : KinsaepTheme.surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        option['icon'] as IconData,
                        color: KinsaepTheme.primary,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      option['label'] as String,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing:
                        option['value'] == current
                            ? const Icon(
                              Icons.check_circle_rounded,
                              color: KinsaepTheme.primary,
                            )
                            : null,
                    onTap: () async {
                      await DatabaseHelper.instance.updateSettings({
                        field: option['value'],
                      });
                      if (field == 'currency') {
                        ref.read(currencyProvider.notifier).state =
                            option['value'] as String;
                      }
                      ref.invalidate(storeSettingsProvider);
                      if (sheetContext.mounted) {
                        Navigator.pop(sheetContext);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: KinsaepTheme.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: KinsaepTheme.cardShadow,
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showDivider;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: KinsaepTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: KinsaepTheme.primary, size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 13)),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: KinsaepTheme.textSecondary,
          ),
          onTap: onTap,
        ),
        if (showDivider) const Divider(height: 1, indent: 56),
      ],
    );
  }
}
