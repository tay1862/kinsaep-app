import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:kinsaep_pos/app/theme.dart';
import 'package:kinsaep_pos/core/providers/app_providers.dart';
import 'package:kinsaep_pos/core/utils/currency_util.dart';
import 'package:kinsaep_pos/core/database/database_helper.dart';
import 'package:uuid/uuid.dart';
import 'package:kinsaep_pos/features/pos/widgets/payment_sheet.dart';

class CartPanel extends ConsumerWidget {
  const CartPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final cartItems = ref.watch(cartProvider);
    final subtotal = ref.watch(cartSubtotalProvider);
    final total = ref.watch(totalAfterDiscountProvider);
    final currency = ref.watch(currencyProvider);

    final discountTotal = subtotal - total;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder:
          (context, scrollController) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: KinsaepTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      Text(
                        l10n.cart,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      if (cartItems.isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            ref.read(cartProvider.notifier).clearCart();
                            Navigator.pop(context);
                          },
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                          ),
                          label: Text(l10n.clearCart),
                          style: TextButton.styleFrom(
                            foregroundColor: KinsaepTheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Cart items
                Expanded(
                  child:
                      cartItems.isEmpty
                          ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.shopping_cart_outlined,
                                  size: 64,
                                  color: KinsaepTheme.border,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  l10n.emptyCart,
                                  style: const TextStyle(
                                    color: KinsaepTheme.textSecondary,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                          : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: cartItems.length,
                            separatorBuilder:
                                (_, __) => const Divider(
                                  height: 1,
                                  indent: 20,
                                  endIndent: 20,
                                ),
                            itemBuilder: (context, index) {
                              final item = cartItems[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    // Item info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            CurrencyUtil.format(
                                              item.unitPrice,
                                              currency,
                                            ),
                                            style: const TextStyle(
                                              color: KinsaepTheme.textSecondary,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Quantity controls
                                    Container(
                                      decoration: BoxDecoration(
                                        color: KinsaepTheme.surface,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _QtyButton(
                                            icon:
                                                item.quantity > 1
                                                    ? Icons.remove_rounded
                                                    : Icons
                                                        .delete_outline_rounded,
                                            color:
                                                item.quantity > 1
                                                    ? KinsaepTheme.textSecondary
                                                    : KinsaepTheme.error,
                                            onTap:
                                                () => ref
                                                    .read(cartProvider.notifier)
                                                    .updateQuantity(
                                                      item.id,
                                                      -1,
                                                    ),
                                          ),
                                          SizedBox(
                                            width: 36,
                                            child: Text(
                                              '${item.quantity}',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                          _QtyButton(
                                            icon: Icons.add_rounded,
                                            color: KinsaepTheme.primary,
                                            onTap:
                                                () => ref
                                                    .read(cartProvider.notifier)
                                                    .updateQuantity(item.id, 1),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    // Total
                                    SizedBox(
                                      width: 80,
                                      child: Text(
                                        CurrencyUtil.format(
                                          item.totalPrice,
                                          currency,
                                        ),
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                ),
                // Bottom summary
                if (cartItems.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 16,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: Column(
                        children: [
                          // Named Discount Presets
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _DiscountPreset(
                                    label: 'VIP 10%',
                                    isActive:
                                        ref.watch(discountPercentProvider) ==
                                        10,
                                    onTap: () {
                                      final current = ref.read(
                                        discountPercentProvider,
                                      );
                                      ref
                                          .read(
                                            discountPercentProvider.notifier,
                                          )
                                          .state = current == 10 ? 0 : 10;
                                      ref
                                          .read(discountAmountProvider.notifier)
                                          .state = 0;
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _DiscountPreset(
                                    label: 'Happy Hour 15%',
                                    isActive:
                                        ref.watch(discountPercentProvider) ==
                                        15,
                                    onTap: () {
                                      final current = ref.read(
                                        discountPercentProvider,
                                      );
                                      ref
                                          .read(
                                            discountPercentProvider.notifier,
                                          )
                                          .state = current == 15 ? 0 : 15;
                                      ref
                                          .read(discountAmountProvider.notifier)
                                          .state = 0;
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _DiscountPreset(
                                    label: 'Staff 50%',
                                    isActive:
                                        ref.watch(discountPercentProvider) ==
                                        50,
                                    onTap: () {
                                      final current = ref.read(
                                        discountPercentProvider,
                                      );
                                      ref
                                          .read(
                                            discountPercentProvider.notifier,
                                          )
                                          .state = current == 50 ? 0 : 50;
                                      ref
                                          .read(discountAmountProvider.notifier)
                                          .state = 0;
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _DiscountPreset(
                                    label: 'Custom %',
                                    isActive: false,
                                    onTap:
                                        () => _showCustomDiscountDialog(
                                          context,
                                          ref,
                                          l10n,
                                          subtotal,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Subtotal
                          _SummaryRow(
                            label: l10n.subtotal,
                            value: CurrencyUtil.format(subtotal, currency),
                          ),
                          if (discountTotal > 0) ...[
                            const SizedBox(height: 4),
                            _SummaryRow(
                              label: l10n.discount,
                              value:
                                  '-${CurrencyUtil.format(discountTotal, currency)}',
                              valueColor: KinsaepTheme.error,
                            ),
                          ],
                          const SizedBox(height: 8),
                          const Divider(),
                          const SizedBox(height: 8),
                          // Total
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                l10n.total,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                CurrencyUtil.format(total, currency),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: KinsaepTheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Action buttons
                          Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: OutlinedButton(
                                  onPressed: () {
                                    ref.read(cartProvider.notifier).clearCart();
                                    ref
                                        .read(discountPercentProvider.notifier)
                                        .state = 0;
                                    ref
                                        .read(discountAmountProvider.notifier)
                                        .state = 0;
                                    ref
                                        .read(activeTicketIdProvider.notifier)
                                        .state = null;
                                    ref
                                        .read(activeTicketNameProvider.notifier)
                                        .state = null;
                                    Navigator.pop(context);
                                  },
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    foregroundColor: KinsaepTheme.error,
                                    side: const BorderSide(
                                      color: KinsaepTheme.error,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 22,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 1,
                                child: OutlinedButton(
                                  onPressed:
                                      () => _saveTicket(context, ref, l10n),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    foregroundColor: KinsaepTheme.primary,
                                    side: const BorderSide(
                                      color: KinsaepTheme.primary,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.pause_circle_outline_rounded,
                                    size: 22,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton(
                                  onPressed:
                                      cartItems.isEmpty
                                          ? null
                                          : () {
                                            Navigator.pop(
                                              context,
                                            ); // Close cart panel
                                            _showPaymentSheet(context);
                                          },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: KinsaepTheme.accent,
                                    disabledBackgroundColor:
                                        KinsaepTheme.border,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    l10n.charge,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
    );
  }

  void _showPaymentSheet(BuildContext context) {
    // Already opens payment_sheet.dart via PosScreen callback
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PaymentSheet(),
    );
  }

  void _saveTicket(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    if (ref.read(cartProvider).isEmpty) return;

    final nameController = TextEditingController(
      text: ref.read(activeTicketNameProvider) ?? '',
    );

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Save Ticket'),
            content: TextField(
              controller: nameController,
              decoration: const InputDecoration(
                hintText: 'Table 1, Customer Name...',
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  l10n.cancel,
                  style: const TextStyle(color: KinsaepTheme.textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) return;

                  final activeTicketId = ref.read(activeTicketIdProvider);
                  final cartItems = ref.read(cartProvider);
                  final subtotal = ref.read(cartSubtotalProvider);
                  final total = ref.read(totalAfterDiscountProvider);
                  final db = DatabaseHelper.instance;

                  final saleUpdates = {
                    'receiptNumber': 'TICKET',
                    'subtotal': subtotal,
                    'discountAmount': ref.read(discountAmountProvider),
                    'discountPercent': ref.read(discountPercentProvider),
                    'taxAmount': 0.0,
                    'totalAmount': total,
                    'amountPaid': 0.0,
                    'changeAmount': 0.0,
                    'paymentMethod': 'none',
                    'status': 'open',
                    'ticketName': nameController.text.trim(),
                    'updatedAt': DateTime.now().toIso8601String(),
                    'syncStatus': 'PENDING',
                  };

                  final saleId = activeTicketId ?? const Uuid().v4();
                  saleUpdates['id'] = saleId;

                  final saleItemsList =
                      cartItems
                          .map(
                            (item) => {
                              'id': const Uuid().v4(),
                              'saleId': saleId,
                              'itemId': item.itemId,
                              'itemName': item.name,
                              'quantity': item.quantity.toDouble(),
                              'unitPrice': item.unitPrice,
                              'totalPrice': item.totalPrice,
                            },
                          )
                          .toList();

                  if (activeTicketId == null) {
                    saleUpdates['createdAt'] = DateTime.now().toIso8601String();
                    saleUpdates['receiptNumber'] =
                        'TICKET-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
                    await db.insertSale(saleUpdates, saleItemsList);
                  } else {
                    await db.updateTicketToSale(
                      saleId,
                      saleUpdates,
                      saleItemsList,
                    );
                  }

                  ref.read(cartProvider.notifier).clearCart();
                  ref.read(discountPercentProvider.notifier).state = 0;
                  ref.read(discountAmountProvider.notifier).state = 0;
                  ref.read(activeTicketIdProvider.notifier).state = null;
                  ref.read(activeTicketNameProvider.notifier).state = null;

                  ref.invalidate(openTicketsProvider);

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) Navigator.pop(context);
                },
                child: Text(l10n.save),
              ),
            ],
          ),
    );
  }

  static void _showCustomDiscountDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    double subtotal,
  ) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text(
              'Custom Discount',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Discount %',
                    suffixText: '%',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: () {
                  final pct = double.tryParse(controller.text) ?? 0;
                  if (pct > 0 && pct <= 100) {
                    ref.read(discountPercentProvider.notifier).state = pct;
                    ref.read(discountAmountProvider.notifier).state = 0;
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('Apply'),
              ),
            ],
          ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QtyButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: KinsaepTheme.textSecondary,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _DiscountPreset extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _DiscountPreset({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? KinsaepTheme.primary : KinsaepTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? KinsaepTheme.primary : KinsaepTheme.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isActive ? Colors.white : KinsaepTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
