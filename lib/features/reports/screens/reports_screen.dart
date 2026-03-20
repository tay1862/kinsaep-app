import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:kinsaep_pos/app/theme.dart';
import 'package:kinsaep_pos/core/providers/app_providers.dart';
import 'package:kinsaep_pos/core/services/printer_service.dart';
import 'package:kinsaep_pos/core/utils/currency_util.dart';
import 'package:kinsaep_pos/core/database/database_helper.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  void _showRefundDialog(Map<String, dynamic> sale, String currency) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text(
              'Refund This Sale?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Receipt: #${sale['receiptNumber']}'),
                const SizedBox(height: 8),
                Text(
                  'Amount: ${CurrencyUtil.format((sale['totalAmount'] as num).toDouble(), currency)}',
                ),
                const SizedBox(height: 8),
                Text('Method: ${sale['paymentMethod']}'),
                const SizedBox(height: 16),
                const Text(
                  'This will restore all items back to stock and mark this sale as refunded.',
                  style: TextStyle(
                    color: KinsaepTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await DatabaseHelper.instance.refundSale(
                    sale['id'] as String,
                  );
                  ref.invalidate(salesHistoryProvider);
                  ref.invalidate(dailySummaryProvider);
                  ref.invalidate(itemsProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sale refunded successfully'),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: KinsaepTheme.error,
                ),
                child: const Text(
                  'Confirm Refund',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _handleReceiptAction(
    BuildContext context,
    Map<String, dynamic> sale, {
    required bool print,
  }) async {
    final settings = await DatabaseHelper.instance.getSettings();
    final items = await DatabaseHelper.instance.getSaleItems(
      sale['id'] as String,
    );
    final currency = settings['currency'] as String? ?? 'LAK';

    try {
      if (print) {
        await PrinterService.printReceipt(
          printerMac: settings['printerMac'] as String?,
          settings: settings,
          sale: sale,
          saleItems: items,
          currency: currency,
        );
      } else {
        await PrinterService.shareReceipt(
          settings: settings,
          sale: sale,
          saleItems: items,
          currency: currency,
        );
      }
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final summary = ref.watch(dailySummaryProvider);
    final topItems = ref.watch(topItemsProvider);
    final salesHistory = ref.watch(salesHistoryProvider);
    final currency = ref.watch(currencyProvider);

    return Scaffold(
      backgroundColor: KinsaepTheme.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dailySummaryProvider);
            ref.invalidate(topItemsProvider);
            ref.invalidate(salesHistoryProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
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
                          Icons.bar_chart_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l10n.reports,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── Today Summary Cards ───
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: KinsaepTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: KinsaepTheme.primary.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: summary.when(
                      data:
                          (data) => Column(
                            children: [
                              Text(
                                l10n.todaySales,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                CurrencyUtil.format(
                                  (data['totalSales'] as num).toDouble(),
                                  currency,
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  _MiniStat(
                                    label: l10n.totalOrders,
                                    value: '${data['totalOrders']}',
                                    icon: Icons.receipt_long_rounded,
                                  ),
                                  const SizedBox(width: 12),
                                  _MiniStat(
                                    label: l10n.averageOrder,
                                    value: CurrencyUtil.format(
                                      (data['averageOrder'] as num).toDouble(),
                                      currency,
                                    ),
                                    icon: Icons.trending_up_rounded,
                                  ),
                                ],
                              ),
                            ],
                          ),
                      loading:
                          () => const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                      error:
                          (_, __) => const Text(
                            'Error',
                            style: TextStyle(color: Colors.white),
                          ),
                    ),
                  ),
                ),

                // ─── Top Items ───
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Text(
                    l10n.topItems,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                topItems.when(
                  data: (items) {
                    if (items.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: Text(
                            l10n.noSalesYet,
                            style: const TextStyle(
                              color: KinsaepTheme.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: KinsaepTheme.cardShadow,
                          ),
                          child: Row(
                            children: [
                              // Rank badge
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color:
                                      index < 3
                                          ? KinsaepTheme.primary.withValues(
                                            alpha: 0.1,
                                          )
                                          : KinsaepTheme.surface,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      color:
                                          index < 3
                                              ? KinsaepTheme.primary
                                              : KinsaepTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item['itemName'] as String,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                'x${(item['totalQty'] as num).toInt()}',
                                style: const TextStyle(
                                  color: KinsaepTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                CurrencyUtil.format(
                                  (item['totalRevenue'] as num).toDouble(),
                                  currency,
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: KinsaepTheme.primary,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  loading:
                      () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                  error: (_, __) => const SizedBox(),
                ),

                // ─── Sales History ───
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Text(
                    l10n.salesHistory,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                salesHistory.when(
                  data: (sales) {
                    if (sales.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: Text(
                            l10n.noSalesYet,
                            style: const TextStyle(
                              color: KinsaepTheme.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount: sales.length,
                      itemBuilder: (context, index) {
                        final sale = sales[index];
                        final time = DateTime.parse(
                          sale['createdAt'] as String,
                        );
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color:
                                      sale['status'] == 'refunded'
                                          ? KinsaepTheme.error.withValues(
                                            alpha: 0.1,
                                          )
                                          : KinsaepTheme.accent.withValues(
                                            alpha: 0.1,
                                          ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  sale['status'] == 'refunded'
                                      ? Icons.undo_rounded
                                      : Icons.receipt_rounded,
                                  color:
                                      sale['status'] == 'refunded'
                                          ? KinsaepTheme.error
                                          : KinsaepTheme.accent,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '#${sale['receiptNumber']}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        if (sale['status'] == 'refunded') ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: KinsaepTheme.error
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'Refunded',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: KinsaepTheme.error,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} · ${sale['paymentMethod']}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: KinsaepTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                CurrencyUtil.format(
                                  (sale['totalAmount'] as num).toDouble(),
                                  currency,
                                ),
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  decoration:
                                      sale['status'] == 'refunded'
                                          ? TextDecoration.lineThrough
                                          : null,
                                  color:
                                      sale['status'] == 'refunded'
                                          ? KinsaepTheme.textSecondary
                                          : KinsaepTheme.textPrimary,
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'print') {
                                    _handleReceiptAction(
                                      context,
                                      sale,
                                      print: true,
                                    );
                                  } else if (value == 'share') {
                                    _handleReceiptAction(
                                      context,
                                      sale,
                                      print: false,
                                    );
                                  } else if (value == 'refund') {
                                    _showRefundDialog(sale, currency);
                                  }
                                },
                                itemBuilder:
                                    (context) => [
                                      const PopupMenuItem(
                                        value: 'print',
                                        child: Text('Reprint receipt'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'share',
                                        child: Text('Share receipt'),
                                      ),
                                      if (sale['status'] != 'refunded')
                                        const PopupMenuItem(
                                          value: 'refund',
                                          child: Text('Refund sale'),
                                        ),
                                    ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  loading:
                      () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                  error: (_, __) => const SizedBox(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
