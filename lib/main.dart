import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:kinsaep_pos/app/theme.dart';
import 'package:kinsaep_pos/core/providers/app_providers.dart';
import 'package:kinsaep_pos/features/pos/screens/pos_screen.dart';
import 'package:kinsaep_pos/features/items/screens/items_screen.dart';
import 'package:kinsaep_pos/features/reports/screens/reports_screen.dart';
import 'package:kinsaep_pos/features/settings/screens/settings_screen.dart';
import 'package:kinsaep_pos/features/auth/screens/pin_lock_screen.dart';
import 'package:kinsaep_pos/features/auth/screens/setup_wizard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const ProviderScope(child: KinsaepApp()));
}

class KinsaepApp extends ConsumerWidget {
  const KinsaepApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(storeSettingsProvider);
    final locale = settingsAsync.when(
      data: (data) => Locale(data['locale'] as String? ?? 'lo'),
      loading: () => const Locale('lo'),
      error: (_, __) => const Locale('lo'),
    );

    return MaterialApp(
      title: 'Kinsaep POS',
      debugShowCheckedModeBanner: false,
      theme: KinsaepTheme.lightTheme,
      darkTheme: KinsaepTheme.darkTheme,
      themeMode: ThemeMode.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('th'), Locale('lo')],
      locale: locale,
      home: settingsAsync.when(
        data: (data) {
          if (data['isSetupComplete'] == 1) {
            return const PinLockScreen(child: MainShell());
          }
          return const SetupWizardScreen();
        },
        loading:
            () => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
        error:
            (e, _) =>
                Scaffold(body: Center(child: Text('Error initializing: $e'))),
      ),
    );
  }
}

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(currentTabProvider);
    final l10n = AppLocalizations.of(context)!;

    final screens = [
      const PosScreen(),
      const ItemsScreen(),
      const ReportsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: currentTab, children: screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.point_of_sale_rounded,
                  label: l10n.pos,
                  isSelected: currentTab == 0,
                  onTap: () => ref.read(currentTabProvider.notifier).state = 0,
                ),
                _NavItem(
                  icon: Icons.inventory_2_rounded,
                  label: l10n.items,
                  isSelected: currentTab == 1,
                  onTap: () => ref.read(currentTabProvider.notifier).state = 1,
                ),
                _NavItem(
                  icon: Icons.bar_chart_rounded,
                  label: l10n.reports,
                  isSelected: currentTab == 2,
                  onTap: () => ref.read(currentTabProvider.notifier).state = 2,
                ),
                _NavItem(
                  icon: Icons.settings_rounded,
                  label: l10n.settings,
                  isSelected: currentTab == 3,
                  onTap: () => ref.read(currentTabProvider.notifier).state = 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? KinsaepTheme.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color:
                  isSelected
                      ? KinsaepTheme.primary
                      : KinsaepTheme.textSecondary,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color:
                    isSelected
                        ? KinsaepTheme.primary
                        : KinsaepTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
