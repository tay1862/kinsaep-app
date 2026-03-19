import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinsaep_pos/app/theme.dart';
import 'package:kinsaep_pos/core/database/database_helper.dart';
import 'package:kinsaep_pos/core/network/cloud_state.dart';
import 'package:kinsaep_pos/core/providers/app_providers.dart';
import 'package:kinsaep_pos/core/utils/pin_security.dart';
import 'package:kinsaep_pos/main.dart'; // To route back to MainShell
import 'package:uuid/uuid.dart';

class SetupWizardScreen extends ConsumerStatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  ConsumerState<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends ConsumerState<SetupWizardScreen> {
  final _storeNameController = TextEditingController();
  final _pinController = TextEditingController();
  String _selectedCurrency = 'LAK';
  String _selectedLanguage = 'lo';
  bool _isLoading = false;

  void _finishSetup() async {
    final name = _storeNameController.text.trim();
    final pin = _pinController.text.trim();

    if (name.isEmpty || pin.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter store name and a 4-6 digit PIN.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Update SQLite Settings
      await DatabaseHelper.instance.updateSettings({
        'storeName': name,
        'currency': _selectedCurrency,
        'locale': _selectedLanguage,
        'isSetupComplete': 1,
        'syncEnabled': 0,
        'cloudMode': CloudMode.offlineOnly,
        'subscriptionStatus': CloudSubscriptionStatus.none,
      });

      // 2. Create the first OWNER staff with the PIN
      final db = await DatabaseHelper.instance.database;
      await db.insert('staff', {
        'id': const Uuid().v4(),
        'name': 'Owner',
        'pin': PinSecurity.hashPin(pin),
        'role': 'OWNER',
        'isActive': 1,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // 3. Refresh global providers
      ref.invalidate(storeSettingsProvider);

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KinsaepTheme.surface,
      appBar: AppBar(
        title: const Text(
          'Store Setup Wizard',
          style: TextStyle(
            color: KinsaepTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Let\'s configure your store for offline use.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 32),

              TextField(
                controller: _storeNameController,
                decoration: InputDecoration(
                  labelText: 'Offline Store Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.storefront_outlined),
                ),
              ),
              const SizedBox(height: 24),

              DropdownButtonFormField<String>(
                value: _selectedCurrency,
                decoration: InputDecoration(
                  labelText: 'Default Currency',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'LAK', child: Text('LAK (₭)')),
                  DropdownMenuItem(value: 'THB', child: Text('THB (฿)')),
                  DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                ],
                onChanged: (v) => setState(() => _selectedCurrency = v!),
              ),
              const SizedBox(height: 24),

              DropdownButtonFormField<String>(
                value: _selectedLanguage,
                decoration: InputDecoration(
                  labelText: 'App Language',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'lo', child: Text('ພາສາລາວ (Lao)')),
                  DropdownMenuItem(value: 'th', child: Text('ภาษาไทย (Thai)')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                ],
                onChanged: (v) => setState(() => _selectedLanguage = v!),
              ),
              const SizedBox(height: 24),

              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Owner Security PIN (4-6 digits)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.password_rounded),
                ),
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _isLoading ? null : _finishSetup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: KinsaepTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    _isLoading
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Text(
                          'Complete Setup ->',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
