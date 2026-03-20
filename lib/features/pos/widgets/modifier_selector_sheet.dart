import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinsaep_pos/app/theme.dart';
import 'package:kinsaep_pos/core/utils/currency_util.dart';
import 'package:kinsaep_pos/core/providers/app_providers.dart';

class ModifierSelectorSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> item;
  final String modifiersJson;

  const ModifierSelectorSheet({
    super.key,
    required this.item,
    required this.modifiersJson,
  });

  @override
  ConsumerState<ModifierSelectorSheet> createState() =>
      _ModifierSelectorSheetState();
}

class _ModifierSelectorSheetState extends ConsumerState<ModifierSelectorSheet> {
  List<Map<String, dynamic>> _groups = [];

  // Tracks the index of the selected option for each group.
  final Map<int, int> _selections = {};
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    try {
      final parsed = jsonDecode(widget.modifiersJson);
      if (parsed is List) {
        _groups = List<Map<String, dynamic>>.from(
          parsed.map((x) => Map<String, dynamic>.from(x)),
        );
        // Default to first option for each group
        for (int i = 0; i < _groups.length; i++) {
          if ((_groups[i]['options'] as List).isNotEmpty) {
            _selections[i] = 0;
          }
        }
      }
    } catch (e) {
      _groups = [];
    }
  }

  double get _totalPrice {
    double base = (widget.item['price'] as num).toDouble();
    for (int i = 0; i < _groups.length; i++) {
      if (_selections.containsKey(i)) {
        final optIndex = _selections[i]!;
        final opt = _groups[i]['options'][optIndex];
        base += (opt['price'] ?? 0.0);
      }
    }
    return base * _quantity;
  }

  String get _variantName {
    final baseName = widget.item['name'] as String;
    final List<String> variants = [];
    for (int i = 0; i < _groups.length; i++) {
      if (_selections.containsKey(i)) {
        final optIndex = _selections[i]!;
        final opt = _groups[i]['options'][optIndex];
        variants.add(opt['name']);
      }
    }
    if (variants.isEmpty) return baseName;
    return '$baseName (${variants.join(', ')})';
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyProvider);
    final total = _totalPrice;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: KinsaepTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.item['name'] as String,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Flexible(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _groups.length,
              itemBuilder: (context, groupIndex) {
                final group = _groups[groupIndex];
                final options = group['options'] as List;
                if (options.isEmpty) return const SizedBox();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        group['name'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: KinsaepTheme.textSecondary,
                        ),
                      ),
                    ),
                    ...List.generate(options.length, (optIndex) {
                      final opt = options[optIndex];
                      final priceStr =
                          (opt['price'] ?? 0.0) > 0
                              ? '+${CurrencyUtil.format(opt['price'], currency)}'
                              : '';

                      return RadioListTile<int>(
                        value: optIndex,
                        groupValue: _selections[groupIndex],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selections[groupIndex] = val);
                          }
                        },
                        title: Text(
                          opt['name'],
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle:
                            priceStr.isNotEmpty
                                ? Text(
                                  priceStr,
                                  style: const TextStyle(
                                    color: KinsaepTheme.primary,
                                  ),
                                )
                                : null,
                        activeColor: KinsaepTheme.primary,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.trailing,
                      );
                    }),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
          ),

          // Bottom Bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Quantity
                  Container(
                    decoration: BoxDecoration(
                      color: KinsaepTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed:
                              _quantity > 1
                                  ? () => setState(() => _quantity--)
                                  : null,
                          icon: Icon(
                            Icons.remove_rounded,
                            color:
                                _quantity > 1
                                    ? KinsaepTheme.textPrimary
                                    : KinsaepTheme.textSecondary,
                          ),
                        ),
                        Text(
                          '$_quantity',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() => _quantity++),
                          icon: const Icon(
                            Icons.add_rounded,
                            color: KinsaepTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Add Button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Calculate final unit price (totalPrice / quantity)
                        final unitPrice = total / _quantity;
                        ref
                            .read(cartProvider.notifier)
                            .addItemFromTicket(
                              itemId: widget.item['id'] as String,
                              name: _variantName,
                              price: unitPrice,
                              quantity: _quantity,
                            );
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: KinsaepTheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Add ${CurrencyUtil.format(total, currency)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
