import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinsaep_pos/app/theme.dart';
import 'package:kinsaep_pos/core/network/cloud_state.dart';
import 'package:kinsaep_pos/core/providers/app_providers.dart';
import 'package:kinsaep_pos/features/devices/screens/devices_screen.dart';
import 'package:kinsaep_pos/features/kitchen/screens/kitchen_console_screen.dart';
import 'package:kinsaep_pos/features/printer/screens/printer_screen.dart';
import 'package:kinsaep_pos/features/settings/screens/settings_screen.dart';
import 'package:kinsaep_pos/features/staff/screens/staff_screen.dart';
import 'package:kinsaep_pos/features/sync/screens/cloud_sync_screen.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(storeSettingsProvider);

    return Scaffold(
      backgroundColor: KinsaepTheme.surface,
      body: SafeArea(
        child: settingsAsync.when(
          data: (settings) {
            final cloudMode =
                (settings['cloudMode'] as String?) ?? CloudMode.offlineOnly;
            final deviceType =
                (settings['deviceType'] as String?) ?? DeviceTypeState.pos;
            final syncProfile =
                (settings['syncProfile'] as String?) ?? SyncProfileState.light;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: KinsaepTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.dashboard_customize_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'More',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: KinsaepTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: KinsaepTheme.primary.withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        settings['storeName'] as String? ?? 'My Store',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Device $deviceType • Cloud ${_modeLabel(cloudMode)} • Sync $syncProfile',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _MoreTile(
                  icon: Icons.groups_rounded,
                  title: 'Staff',
                  subtitle: 'Create, edit, and deactivate PIN staff accounts',
                  onTap: () => _open(context, const StaffScreen()),
                ),
                _MoreTile(
                  icon: Icons.devices_rounded,
                  title: 'Devices',
                  subtitle:
                      'Register this device, set scanner mode, and choose POS or kitchen mode',
                  onTap: () => _open(context, const DevicesScreen()),
                ),
                _MoreTile(
                  icon: Icons.cloud_sync_rounded,
                  title: 'Cloud & Sync',
                  subtitle:
                      'Server URL, login, sync profile, progress, and diagnostics',
                  onTap: () => _open(context, const CloudSyncScreen()),
                ),
                _MoreTile(
                  icon: Icons.print_rounded,
                  title: 'Printer',
                  subtitle: 'Pick a Bluetooth printer and run a receipt test',
                  onTap: () => _open(context, const PrinterScreen()),
                ),
                _MoreTile(
                  icon: Icons.storefront_rounded,
                  title: 'Store Settings',
                  subtitle:
                      'Store details, tax, shifts, language, and receipt text',
                  onTap: () => _open(context, const SettingsScreen()),
                ),
                if (deviceType == DeviceTypeState.kitchen)
                  _MoreTile(
                    icon: Icons.soup_kitchen_rounded,
                    title: 'Kitchen Console',
                    subtitle: 'Open the live kitchen view for this device',
                    onTap: () => _open(context, const KitchenConsoleScreen()),
                  ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Error: $error')),
        ),
      ),
    );
  }

  static void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  static String _modeLabel(String mode) {
    switch (mode) {
      case CloudMode.active:
        return 'Active';
      case CloudMode.blocked:
        return 'Blocked';
      default:
        return 'Offline';
    }
  }
}

class _MoreTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MoreTile({
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
        borderRadius: BorderRadius.circular(18),
        boxShadow: KinsaepTheme.cardShadow,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
