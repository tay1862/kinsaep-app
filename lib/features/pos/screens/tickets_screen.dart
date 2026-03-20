import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kinsaep_pos/app/theme.dart';
import 'package:kinsaep_pos/core/database/database_helper.dart';
import 'package:kinsaep_pos/core/providers/app_providers.dart';
import 'package:kinsaep_pos/core/utils/currency_util.dart';

class TicketsScreen extends ConsumerWidget {
  const TicketsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    final ticketsAsync = ref.watch(openTicketsProvider);

    return Scaffold(
      backgroundColor: KinsaepTheme.surface,
      appBar: AppBar(
        title: const Text(
          'Open Tickets',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
      ),
      body: ticketsAsync.when(
        data: (tickets) {
          if (tickets.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.receipt_long_rounded,
                    size: 64,
                    color: KinsaepTheme.border,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No open tickets',
                    style: TextStyle(
                      fontSize: 18,
                      color: KinsaepTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: tickets.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final ticket = tickets[index];
              final dateStr = ticket['createdAt'] as String;
              final date = DateTime.tryParse(dateStr);
              final formattedDate =
                  date != null ? DateFormat('HH:mm').format(date) : '';
              final total = ticket['totalAmount'] as double;
              final name = ticket['ticketName'] as String? ?? 'Unknown';

              return Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: KinsaepTheme.border),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _resumeTicket(context, ref, ticket),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: KinsaepTheme.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.table_restaurant_rounded,
                            color: KinsaepTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: KinsaepTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Opened at $formattedDate',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: KinsaepTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              CurrencyUtil.format(total, currency),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: KinsaepTheme.accent,
                              ),
                            ),
                            const SizedBox(height: 4),
                            IconButton(
                              onPressed:
                                  () => _deleteTicket(
                                    context,
                                    ref,
                                    ticket['id'] as String,
                                  ),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: KinsaepTheme.error,
                                size: 20,
                              ),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Future<void> _resumeTicket(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> ticket,
  ) async {
    final saleId = ticket['id'] as String;
    final items = await DatabaseHelper.instance.getSaleItems(saleId);

    ref.read(cartProvider.notifier).clearCart();

    for (final item in items) {
      ref
          .read(cartProvider.notifier)
          .addItemFromTicket(
            itemId: item['itemId'] as String,
            name: item['itemName'] as String,
            price: (item['unitPrice'] as num).toDouble(),
            quantity: (item['quantity'] as num).toInt(),
          );
    }

    // Restore discounts if any
    ref.read(discountAmountProvider.notifier).state =
        (ticket['discountAmount'] as num).toDouble();
    ref.read(discountPercentProvider.notifier).state =
        (ticket['discountPercent'] as num).toDouble();

    ref.read(activeTicketIdProvider.notifier).state = saleId;
    ref.read(activeTicketNameProvider.notifier).state =
        ticket['ticketName'] as String?;

    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _deleteTicket(
    BuildContext context,
    WidgetRef ref,
    String saleId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Ticket'),
            content: const Text(
              'Are you sure you want to delete this open ticket?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: KinsaepTheme.error,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteTicket(saleId);
      ref.invalidate(openTicketsProvider);
    }
  }
}
