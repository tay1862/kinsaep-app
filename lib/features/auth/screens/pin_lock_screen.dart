import 'package:flutter/material.dart';
import 'package:kinsaep_pos/app/theme.dart';
import 'package:kinsaep_pos/core/database/database_helper.dart';
import 'package:kinsaep_pos/core/utils/pin_security.dart';

class PinLockScreen extends StatefulWidget {
  final Widget child; // The screen to show after unlocking

  const PinLockScreen({super.key, required this.child});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  String _pin = '';
  bool _isLoading = false;
  String _errorMsg = '';

  void _onDigitPress(String digit) {
    if (_pin.length < 6) {
      setState(() {
        _pin += digit;
        _errorMsg = '';
      });
      if (_pin.length == 4 || _pin.length == 6) {
        _verifyPin();
      }
    }
  }

  void _onDeletePress() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _errorMsg = '';
      });
    }
  }

  Future<void> _verifyPin() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper.instance.database;
      final staffMembers = await db.query('staff', where: 'isActive = 1');
      Map<String, dynamic>? matchedStaff;

      for (final staff in staffMembers) {
        final storedPin = staff['pin'] as String? ?? '';
        if (PinSecurity.matches(_pin, storedPin)) {
          matchedStaff = staff;

          if (PinSecurity.needsMigration(storedPin)) {
            await db.update(
              'staff',
              {'pin': PinSecurity.hashPin(_pin)},
              where: 'id = ?',
              whereArgs: [staff['id']],
            );
          }
          break;
        }
      }

      if (matchedStaff != null) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => widget.child,
            transitionDuration: Duration.zero,
          ),
        );
      } else {
        // Only show error if they pressed 6 digits, or wait for them to press more
        if (_pin.length >= 4) {
          setState(() {
            _isLoading = false;
            _errorMsg = 'Invalid PIN. Try again.';
            _pin = '';
          });
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMsg = 'Database error.';
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C), // Deep dark for lock screen
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            const Icon(
              Icons.lock_person_rounded,
              size: 60,
              color: Colors.white,
            ),
            const SizedBox(height: 20),
            const Text(
              'Enter PIN',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _errorMsg,
              style: const TextStyle(color: Colors.redAccent, fontSize: 14),
            ),
            const SizedBox(height: 30),

            // PIN Dots Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                final isFilled = index < _pin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        isFilled
                            ? KinsaepTheme.primary
                            : Colors.white.withValues(alpha: 0.1),
                    border: Border.all(
                      color: KinsaepTheme.primary,
                      width: isFilled ? 0 : 2,
                    ),
                  ),
                );
              }),
            ),
            const Spacer(),

            // Numpad
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                childAspectRatio: 1.2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (var i = 1; i <= 9; i++) _buildNumBtn(i.toString()),
                  Container(), // Empty spot for layout
                  _buildNumBtn('0'),
                  _buildDelBtn(),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildNumBtn(String n) {
    return TextButton(
      onPressed: _isLoading ? null : () => _onDigitPress(n),
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
      ),
      child: Text(
        n,
        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDelBtn() {
    return IconButton(
      onPressed: _isLoading ? null : _onDeletePress,
      icon: const Icon(Icons.backspace_rounded, color: Colors.white, size: 28),
    );
  }
}
