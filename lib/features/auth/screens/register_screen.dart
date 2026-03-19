import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinsaep_pos/app/theme.dart';
import 'package:kinsaep_pos/features/auth/providers/auth_provider.dart';
import 'package:kinsaep_pos/main.dart'; // To route back to MainShell

class RegisterScreen extends ConsumerStatefulWidget {
  final bool cloudFlow;

  const RegisterScreen({super.key, this.cloudFlow = false});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _storeNameController = TextEditingController();

  void _handleRegister() async {
    final success = await ref.read(authProvider.notifier).register({
      'name': _nameController.text,
      'email': _emailController.text,
      'password': _passwordController.text,
      'storeName': _storeNameController.text,
    });

    if (!mounted) return;

    if (success) {
      if (widget.cloudFlow) {
        Navigator.pop(context, true);
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainShell()),
          (route) => false,
        );
      }
    } else {
      final error = ref.read(authProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error ?? 'Registration failed',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: KinsaepTheme.surface,
      appBar: AppBar(
        title: const Text(
          'Create New Store',
          style: TextStyle(
            color: KinsaepTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: KinsaepTheme.textPrimary),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.cloudFlow
                    ? 'Create your cloud store account. Sync stays blocked until an admin activates it.'
                    : 'Create your cloud store account. Sync stays blocked until an admin activates it.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 32),

              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Your Full Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _storeNameController,
                decoration: InputDecoration(
                  labelText: 'Store Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.storefront_outlined),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password (min 6 chars)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: authState.isLoading ? null : _handleRegister,
                style: ElevatedButton.styleFrom(
                  backgroundColor: KinsaepTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    authState.isLoading
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Text(
                          'Create Account',
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
