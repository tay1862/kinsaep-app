import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:kinsaep_pos/app/theme.dart';
import 'package:kinsaep_pos/core/providers/app_providers.dart';
import 'package:kinsaep_pos/core/utils/currency_util.dart';
import 'package:kinsaep_pos/core/database/database_helper.dart';
import 'package:kinsaep_pos/core/services/printer_service.dart';
import 'package:uuid/uuid.dart';

class PaymentSheet extends ConsumerStatefulWidget {
  const PaymentSheet({super.key});

  @override
  ConsumerState<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<PaymentSheet> {
  String _paymentMethod = 'cash';
  double _amountPaid = 0;
  bool _saleCompleted = false;
  String _receiptNumber = '';
  final _amountController = TextEditingController();
  Map<String, dynamic>? _completedSale;
  List<Map<String, dynamic>> _completedSaleItems = const [];
  // Split payment
  double _splitCash = 0;
  double _splitOther = 0;
  final _splitCashController = TextEditingController();
  final _splitOtherController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _setExactCashAmount(ref.read(totalAfterDiscountProvider));
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _splitCashController.dispose();
    _splitOtherController.dispose();
    super.dispose();
  }

  void _setExactCashAmount(double amount) {
    final normalizedText =
        amount == amount.roundToDouble()
            ? amount.toStringAsFixed(0)
            : amount.toStringAsFixed(2);
    _amountPaid = amount;
    _amountController.text = normalizedText;
    _amountController.selection = TextSelection.fromPosition(
      TextPosition(offset: _amountController.text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final total = ref.watch(totalAfterDiscountProvider);
    final currency = ref.watch(currencyProvider);
    final change = _amountPaid - total;
    final quickAmounts = CurrencyUtil.quickAmounts(total, currency);

    if (_saleCompleted) {
      return _buildSuccessView(context, l10n, total, currency);
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder:
          (context, scrollController) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: KinsaepTheme.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Total display
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: Column(
                      children: [
                        Text(
                          l10n.total,
                          style: const TextStyle(
                            fontSize: 14,
                            color: KinsaepTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          CurrencyUtil.format(total, currency),
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            color: KinsaepTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Payment method
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        _PayMethodChip(
                          icon: Icons.payments_rounded,
                          label: l10n.cash,
                          isSelected: _paymentMethod == 'cash',
                          onTap:
                              () => setState(() {
                                _paymentMethod = 'cash';
                                _setExactCashAmount(total);
                              }),
                        ),
                        const SizedBox(width: 10),
                        _PayMethodChip(
                          icon: Icons.qr_code_rounded,
                          label: l10n.qrCode,
                          isSelected: _paymentMethod == 'transfer',
                          onTap:
                              () => setState(() {
                                _paymentMethod = 'transfer';
                                _amountPaid = total;
                              }),
                        ),
                        const SizedBox(width: 10),
                        _PayMethodChip(
                          icon: Icons.credit_card_rounded,
                          label: l10n.card,
                          isSelected: _paymentMethod == 'card',
                          onTap:
                              () => setState(() {
                                _paymentMethod = 'card';
                                _amountPaid = total;
                              }),
                        ),
                        const SizedBox(width: 10),
                        _PayMethodChip(
                          icon: Icons.call_split_rounded,
                          label: 'Split',
                          isSelected: _paymentMethod == 'split',
                          onTap:
                              () => setState(() {
                                _paymentMethod = 'split';
                                _splitCash = 0;
                                _splitOther = 0;
                                _splitCashController.clear();
                                _splitOtherController.clear();
                              }),
                        ),
                      ],
                    ),
                  ),

                  // Cash-specific: amount received
                  if (_paymentMethod == 'cash') ...[
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        l10n.amountReceived,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: KinsaepTheme.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: KinsaepTheme.primary,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.payments_rounded,
                            color: KinsaepTheme.primary,
                          ),
                          filled: true,
                          fillColor: KinsaepTheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: KinsaepTheme.border,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: KinsaepTheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _amountPaid = double.tryParse(val) ?? 0;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Quick amount buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _QuickAmountChip(
                            label: l10n.total,
                            isSelected: _amountPaid == total,
                            onTap:
                                () => setState(() {
                                  _amountPaid = total;
                                  _amountController.text = total
                                      .toStringAsFixed(0);
                                }),
                          ),
                          ...quickAmounts
                              .where((a) => a >= total)
                              .take(5)
                              .map(
                                (amount) => _QuickAmountChip(
                                  label: CurrencyUtil.format(amount, currency),
                                  isSelected: _amountPaid == amount,
                                  onTap:
                                      () => setState(() {
                                        _amountPaid = amount;
                                        _amountController.text = amount
                                            .toStringAsFixed(0);
                                      }),
                                ),
                              ),
                        ],
                      ),
                    ),
                    // Change
                    if (_amountPaid > 0 && _amountPaid >= total) ...[
                      const SizedBox(height: 20),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: KinsaepTheme.accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: KinsaepTheme.accent.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.change,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: KinsaepTheme.accent,
                              ),
                            ),
                            Text(
                              CurrencyUtil.format(
                                change > 0 ? change : 0,
                                currency,
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 24,
                                color: KinsaepTheme.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],

                  // Split payment UI
                  if (_paymentMethod == 'split') ...[
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cash Amount',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: KinsaepTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _splitCashController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(
                                Icons.payments_rounded,
                                color: KinsaepTheme.primary,
                              ),
                              filled: true,
                              fillColor: KinsaepTheme.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onChanged: (val) {
                              setState(() {
                                _splitCash = double.tryParse(val) ?? 0;
                                _amountPaid = _splitCash + _splitOther;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Card / Transfer Amount',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: KinsaepTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _splitOtherController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(
                                Icons.credit_card_rounded,
                                color: KinsaepTheme.secondary,
                              ),
                              filled: true,
                              fillColor: KinsaepTheme.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onChanged: (val) {
                              setState(() {
                                _splitOther = double.tryParse(val) ?? 0;
                                _amountPaid = _splitCash + _splitOther;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  (_splitCash + _splitOther) >= total
                                      ? KinsaepTheme.accent.withValues(
                                        alpha: 0.08,
                                      )
                                      : KinsaepTheme.warning.withValues(
                                        alpha: 0.08,
                                      ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  (_splitCash + _splitOther) >= total
                                      ? 'Total Covered'
                                      : 'Remaining',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color:
                                        (_splitCash + _splitOther) >= total
                                            ? KinsaepTheme.accent
                                            : KinsaepTheme.warning,
                                  ),
                                ),
                                Text(
                                  CurrencyUtil.format(
                                    (total - _splitCash - _splitOther).clamp(
                                      0,
                                      double.infinity,
                                    ),
                                    currency,
                                  ),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                    color:
                                        (_splitCash + _splitOther) >= total
                                            ? KinsaepTheme.accent
                                            : KinsaepTheme.warning,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Complete button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed:
                            (_paymentMethod == 'cash' && _amountPaid < total)
                                ? null
                                : (_paymentMethod == 'split' &&
                                    (_splitCash + _splitOther) < total)
                                ? null
                                : () => _completeSale(total, currency),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: KinsaepTheme.accent,
                          disabledBackgroundColor: KinsaepTheme.border,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 22),
                            const SizedBox(width: 10),
                            Text(
                              l10n.completeSale,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildSuccessView(
    BuildContext context,
    AppLocalizations l10n,
    double total,
    String currency,
  ) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Success animation
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: KinsaepTheme.accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 72,
              color: KinsaepTheme.accent,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.saleComplete,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyUtil.format(total, currency),
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: KinsaepTheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.receiptNo(_receiptNumber),
            style: const TextStyle(color: KinsaepTheme.textSecondary),
          ),
          const SizedBox(height: 40),
          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _printReceipt,
                    icon: const Icon(Icons.print_rounded),
                    label: Text(l10n.printReceipt),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _shareReceipt,
                    icon: const Icon(Icons.share_rounded),
                    label: Text(l10n.shareReceipt),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // New sale
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.newSale, style: const TextStyle(fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _completeSale(double total, String currency) async {
    if (_paymentMethod == 'cash' && _amountPaid < total) return;

    HapticFeedback.heavyImpact();
    final db = DatabaseHelper.instance;
    final cartItems = ref.read(cartProvider);
    final subtotal = ref.read(cartSubtotalProvider);
    final receiptNum = await db.getNextReceiptNumber();

    const uuid = Uuid();
    final saleId = uuid.v4();
    final now = DateTime.now().toIso8601String();

    final sale = {
      'id': saleId,
      'receiptNumber': receiptNum.toString().padLeft(6, '0'),
      'subtotal': subtotal,
      'discountAmount': ref.read(discountAmountProvider),
      'discountPercent': ref.read(discountPercentProvider),
      'taxAmount': 0.0,
      'totalAmount': total,
      'amountPaid': _paymentMethod == 'cash' ? _amountPaid : total,
      'changeAmount':
          _paymentMethod == 'cash'
              ? (_amountPaid - total).clamp(0, double.infinity)
              : 0.0,
      'paymentMethod': _paymentMethod,
      'status': 'completed',
      'createdAt': now,
      'updatedAt': now,
      'syncStatus': 'PENDING',
    };

    final saleItemsList =
        cartItems
            .map(
              (item) => {
                'id': uuid.v4(),
                'saleId': saleId,
                'itemId': item.itemId,
                'itemName': item.name,
                'quantity': item.quantity.toDouble(),
                'unitPrice': item.unitPrice,
                'totalPrice': item.totalPrice,
              },
            )
            .toList();

    await db.insertSale(sale, saleItemsList);
    await _createKitchenTicketIfNeeded(saleId, saleItemsList);

    // Clear cart and discounts
    ref.read(cartProvider.notifier).clearCart();
    ref.read(discountPercentProvider.notifier).state = 0;
    ref.read(discountAmountProvider.notifier).state = 0;
    // Refresh data
    ref.invalidate(dailySummaryProvider);
    ref.invalidate(salesHistoryProvider);
    ref.invalidate(itemsProvider);

    setState(() {
      _saleCompleted = true;
      _receiptNumber = receiptNum.toString().padLeft(6, '0');
      _completedSale = sale;
      _completedSaleItems = saleItemsList;
    });
  }

  Future<void> _createKitchenTicketIfNeeded(
    String saleId,
    List<Map<String, dynamic>> saleItemsList,
  ) async {
    final settings = await DatabaseHelper.instance.getSettings();
    final catalogItems = await DatabaseHelper.instance.getItemsByIds(
      saleItemsList.map((item) => item['itemId'] as String).toSet().toList(),
    );
    final byId = {for (final item in catalogItems) item['id'] as String: item};
    final kitchenItems =
        saleItemsList
            .where((item) => byId[item['itemId']]?['kitchenStationId'] != null)
            .map(
              (item) => {
                'id': const Uuid().v4(),
                'itemId': item['itemId'],
                'stationId': byId[item['itemId']]?['kitchenStationId'],
                'itemName': item['itemName'],
                'quantity': item['quantity'],
                'status': 'NEW',
                'note': item['note'],
                'createdAt': DateTime.now().toIso8601String(),
                'updatedAt': DateTime.now().toIso8601String(),
              },
            )
            .toList();

    if (kitchenItems.isEmpty) {
      return;
    }

    final now = DateTime.now().toIso8601String();
    final localTicketId = const Uuid().v4();
    final baseTicket = {
      'id': localTicketId,
      'saleId': saleId,
      'sourceDeviceId': settings['deviceId'],
      'status': 'NEW',
      'note': null,
      'createdAt': now,
      'updatedAt': now,
      'syncStatus': 'PENDING',
    };

    await DatabaseHelper.instance.saveKitchenTicket(baseTicket);
    await DatabaseHelper.instance.replaceKitchenTicketItems(
      localTicketId,
      kitchenItems,
    );
    ref.invalidate(kitchenTicketsProvider);
  }

  Future<void> _printReceipt() async {
    if (_completedSale == null) {
      return;
    }
    try {
      final settings = await DatabaseHelper.instance.getSettings();
      await PrinterService.printReceipt(
        printerMac: settings['printerMac'] as String?,
        settings: settings,
        sale: _completedSale!,
        saleItems: _completedSaleItems,
        currency: settings['currency'] as String? ?? 'LAK',
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Receipt sent to printer.')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _shareReceipt() async {
    if (_completedSale == null) {
      return;
    }
    try {
      final settings = await DatabaseHelper.instance.getSettings();
      await PrinterService.shareReceipt(
        settings: settings,
        sale: _completedSale!,
        saleItems: _completedSaleItems,
        currency: settings['currency'] as String? ?? 'LAK',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }
}

class _PayMethodChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PayMethodChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? KinsaepTheme.primary.withValues(alpha: 0.1)
                    : KinsaepTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? KinsaepTheme.primary : KinsaepTheme.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color:
                    isSelected
                        ? KinsaepTheme.primary
                        : KinsaepTheme.textSecondary,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color:
                      isSelected
                          ? KinsaepTheme.primary
                          : KinsaepTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAmountChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _QuickAmountChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? KinsaepTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? KinsaepTheme.primary : KinsaepTheme.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : KinsaepTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}
