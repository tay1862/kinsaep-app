import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:kinsaep_pos/app/theme.dart';
import 'package:kinsaep_pos/core/database/database_helper.dart';
import 'package:kinsaep_pos/core/providers/shift_providers.dart';
import 'package:kinsaep_pos/core/utils/currency_util.dart';

class ShiftsScreen extends ConsumerStatefulWidget {
  const ShiftsScreen({super.key});

  @override
  ConsumerState<ShiftsScreen> createState() => _ShiftsScreenState();
}

class _ShiftsScreenState extends ConsumerState<ShiftsScreen> {
  final _cashController = TextEditingController();
  final _uuid = const Uuid();

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  Future<void> _openShift() async {
    final startingCash = double.tryParse(_cashController.text) ?? 0.0;

    final newShift = {
      'id': _uuid.v4(),
      'openedAt': DateTime.now().toIso8601String(),
      'startingCash': startingCash,
      'cashAdded': 0.0,
      'cashRemoved': 0.0,
      'status': 'open',
      'syncStatus': 'PENDING',
    };

    await DatabaseHelper.instance.insertShift(newShift);
    ref.invalidate(currentShiftProvider);
    if (mounted) {
      _cashController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shift Opened successfully')),
      );
    }
  }

  Future<void> _closeShift(
    Map<String, dynamic> shift,
    double expectedCash,
  ) async {
    final actualCash = double.tryParse(_cashController.text) ?? 0.0;
    final difference = actualCash - expectedCash;

    final updates = {
      'closedAt': DateTime.now().toIso8601String(),
      'expectedCash': expectedCash,
      'actualCash': actualCash,
      'difference': difference,
      'status': 'closed',
      'syncStatus': 'PENDING',
    };

    await DatabaseHelper.instance.updateShift(shift['id'] as String, updates);
    ref.invalidate(currentShiftProvider);
    if (mounted) {
      _cashController.clear();
      Navigator.pop(context); // close the dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shift Closed successfully')),
      );
    }
  }

  void _showCloseShiftDialog(
    Map<String, dynamic> shift,
    double expectedCash,
    String currency,
  ) {
    _cashController.text = '';
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text(
              'Close Shift',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Expected Cash in Drawer: ${CurrencyUtil.format(expectedCash, currency)}',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _cashController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Actual Cash Counted',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money_rounded),
                  ),
                  autofocus: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => _closeShift(shift, expectedCash),
                style: ElevatedButton.styleFrom(
                  backgroundColor: KinsaepTheme.error,
                ),
                child: const Text(
                  'Close Shift',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shiftAsync = ref.watch(currentShiftProvider);

    return Scaffold(
      backgroundColor: KinsaepTheme.surface,
      appBar: AppBar(
        title: const Text('Shift Management'),
        backgroundColor: Colors.white,
      ),
      body: shiftAsync.when(
        data: (shift) {
          if (shift == null) {
            return _buildOpenShiftView();
          } else {
            return _buildActiveShiftView(shift);
          }
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildOpenShiftView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock_clock_rounded,
              size: 80,
              color: KinsaepTheme.textSecondary,
            ),
            const SizedBox(height: 16),
            const Text(
              'No active shift currently open',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _cashController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Starting Cash Amount',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.money_rounded),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _openShift,
                style: ElevatedButton.styleFrom(
                  backgroundColor: KinsaepTheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Open Shift',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveShiftView(Map<String, dynamic> shift) {
    final currency =
        'LAK'; // Should be read from settings ideally, hardcoded or use currencyUtil normally
    final openedAt = DateTime.parse(shift['openedAt'] as String);
    final salesAsync = ref.watch(
      shiftSalesProvider(shift['openedAt'] as String),
    );

    return salesAsync.when(
      data: (sales) {
        final startingCash = (shift['startingCash'] as num).toDouble();
        final cashSales = (sales['cashSales'] as num).toDouble();
        final otherSales = (sales['otherSales'] as num).toDouble();
        final cashAdded = (shift['cashAdded'] as num).toDouble();
        final cashRemoved = (shift['cashRemoved'] as num).toDouble();

        final expectedCash = startingCash + cashSales + cashAdded - cashRemoved;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
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
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: KinsaepTheme.accent.withAlpha(25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.lock_open_rounded,
                          color: KinsaepTheme.accent,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Shift is Open',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Opened at ${DateFormat('MM/dd/yyyy HH:mm').format(openedAt)}',
                            style: const TextStyle(
                              color: KinsaepTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildStatRow('Starting Cash Drawer', startingCash, currency),
                  const Divider(height: 24),
                  _buildStatRow(
                    'Cash Sales',
                    cashSales,
                    currency,
                    isPositive: true,
                  ),
                  _buildStatRow(
                    'Other Sales (Card, transfer)',
                    otherSales,
                    currency,
                  ),
                  const Divider(height: 24),
                  _buildStatRow('Cash Paid In', cashAdded, currency),
                  _buildStatRow('Cash Paid Out', cashRemoved, currency),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Expected Cash in Drawer',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        CurrencyUtil.format(expectedCash, currency),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: KinsaepTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Implement Pay In
                    },
                    icon: const Icon(Icons.arrow_downward_rounded),
                    label: const Text('Pay In'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Implement Pay Out
                    },
                    icon: const Icon(Icons.arrow_upward_rounded),
                    label: const Text('Pay Out'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed:
                  () => _showCloseShiftDialog(shift, expectedCash, currency),
              style: ElevatedButton.styleFrom(
                backgroundColor: KinsaepTheme.error,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Close Shift',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildStatRow(
    String label,
    double amount,
    String currency, {
    bool isPositive = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              color: KinsaepTheme.textSecondary,
            ),
          ),
          Text(
            CurrencyUtil.format(amount, currency),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color:
                  isPositive ? KinsaepTheme.accent : KinsaepTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
