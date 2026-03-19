import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:kinsaep_pos/app/theme.dart';
import 'package:kinsaep_pos/core/providers/app_providers.dart';
import 'package:kinsaep_pos/core/utils/currency_util.dart';
import 'package:kinsaep_pos/features/pos/widgets/cart_panel.dart';
import 'package:kinsaep_pos/features/pos/screens/tickets_screen.dart';
import 'package:kinsaep_pos/features/pos/widgets/modifier_selector_sheet.dart';
import 'package:kinsaep_pos/features/pos/screens/barcode_scanner_screen.dart';


class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode(); // Added FocusNode
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(searchQueryProvider, (previous, next) {
      setState(() => _isSearching = next.isNotEmpty);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose(); // Dispose FocusNode
    super.dispose();
  }

  Future<void> _openScanner() async {
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    
    if (barcode != null && barcode.isNotEmpty && mounted) {
      final itemsList = ref.read(itemsProvider).value ?? [];
      final match = itemsList.where((i) => i['barcode'] == barcode || i['sku'] == barcode).toList();
      
      if (match.isNotEmpty) {
        final item = match.first;
        final modifiers = item['modifiers'] as String? ?? '[]';
        if (modifiers != '[]') {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => ModifierSelectorSheet(
              item: item,
              modifiersJson: modifiers,
            ),
          );
        } else {
          ref.read(cartProvider.notifier).addItem(
            item['id'] as String,
            item['name'] as String,
            (item['price'] as num).toDouble(),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Added ${item['name']}'), duration: const Duration(seconds: 1)),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No item found for barcode: $barcode')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final categories = ref.watch(categoriesProvider);
    final items = ref.watch(itemsProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final cartItems = ref.watch(cartProvider);
    final cartCount = ref.watch(cartItemCountProvider);
    final subtotal = ref.watch(cartSubtotalProvider);
    final currency = ref.watch(currencyProvider);

    return Scaffold(
      backgroundColor: KinsaepTheme.surface,
      appBar: AppBar(
        title: const Text('POS', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TicketsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {
              _searchFocusNode.requestFocus();
              setState(() => _isSearching = true);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column( // Removed SafeArea and the old top bar Container
        children: [
          // ─── Search Field (conditionally displayed) ───
          if (_isSearching)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              color: Colors.white,
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode, // Assign FocusNode
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.searchItems,
                  prefixIcon: const Icon(Icons.search_rounded, color: KinsaepTheme.textSecondary),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isSearching)
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: KinsaepTheme.error),
                          onPressed: () {
                            FocusScope.of(context).unfocus();
                            ref.read(searchQueryProvider.notifier).state = '';
                            _searchController.clear();
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.qr_code_scanner_rounded, color: KinsaepTheme.primary),
                        onPressed: _openScanner,
                      ),
                    ],
                  ),
                  filled: true,
                  fillColor: KinsaepTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (v) => ref.read(searchQueryProvider.notifier).state = v,
              ),
            ),

            // ─── Category Tabs ───
            if (!_isSearching)
              Container(
                height: 52,
                color: Colors.white,
                child: categories.when(
                  data: (cats) => ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: [
                      _CategoryChip(
                        label: l10n.allCategories,
                        isSelected: selectedCategory == null,
                        color: KinsaepTheme.primary,
                        onTap: () => ref.read(selectedCategoryProvider.notifier).state = null,
                      ),
                      ...cats.map((cat) => _CategoryChip(
                        label: cat['name'] as String,
                        isSelected: selectedCategory == cat['id'],
                        color: Color(cat['color'] as int),
                        onTap: () => ref.read(selectedCategoryProvider.notifier).state = cat['id'] as String,
                      )),
                    ],
                  ),
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),
              ),

            // ─── Items Grid ───
            Expanded(
              child: _isSearching
                  ? _buildSearchResults(ref, currency)
                  : _buildItemsGrid(items, ref, currency, l10n),
            ),

            // ─── Cart Summary Bar ───
            if (cartItems.isNotEmpty)
              GestureDetector(
                onTap: () => _showCartPanel(context),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: KinsaepTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: KinsaepTheme.primary.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Cart badge
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              '$cartCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Total
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(l10n.total, style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w500,
                          )),
                          Text(
                            CurrencyUtil.format(subtotal, currency),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      // Charge button
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          l10n.charge,
                          style: const TextStyle(
                            color: KinsaepTheme.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
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

  Widget _buildItemsGrid(AsyncValue<List<Map<String, dynamic>>> items, WidgetRef ref, String currency, AppLocalizations l10n) {
    return items.when(
      data: (itemList) {
        if (itemList.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: KinsaepTheme.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.inventory_2_outlined, size: 48, color: KinsaepTheme.primary.withValues(alpha: 0.5)),
                ),
                const SizedBox(height: 16),
                Text(l10n.noItems, style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600, color: KinsaepTheme.textSecondary,
                )),
                const SizedBox(height: 8),
                Text(l10n.addYourFirstItem, style: const TextStyle(
                  fontSize: 14, color: KinsaepTheme.textSecondary,
                )),
              ],
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.85,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: itemList.length,
          itemBuilder: (context, index) {
            final item = itemList[index];
            return _ItemCard(
              name: item['name'] as String,
              price: CurrencyUtil.format((item['price'] as num).toDouble(), currency),
              imagePath: item['imagePath'] as String?,
              onTap: () {
                HapticFeedback.lightImpact();
                final modifiers = item['modifiers'] as String? ?? '[]';
                if (modifiers != '[]') {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => ModifierSelectorSheet(
                      item: item,
                      modifiersJson: modifiers,
                    ),
                  );
                } else {
                  ref.read(cartProvider.notifier).addItem(
                    item['id'] as String,
                    item['name'] as String,
                    (item['price'] as num).toDouble(),
                  );
                }
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildSearchResults(WidgetRef ref, String currency) {
    final results = ref.watch(searchItemsProvider);
    return results.when(
      data: (itemList) {
        if (itemList.isEmpty) {
          return const Center(child: Icon(Icons.search_off_rounded, size: 64, color: KinsaepTheme.border));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: itemList.length,
          itemBuilder: (context, index) {
            final item = itemList[index];
            return ListTile(
              title: Text(item['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(CurrencyUtil.format((item['price'] as num).toDouble(), currency)),
              trailing: const Icon(Icons.add_circle_rounded, color: KinsaepTheme.primary),
              onTap: () {
                final modifiers = item['modifiers'] as String? ?? '[]';
                if (modifiers != '[]') {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => ModifierSelectorSheet(
                      item: item,
                      modifiersJson: modifiers,
                    ),
                  );
                } else {
                  ref.read(cartProvider.notifier).addItem(
                    item['id'] as String,
                    item['name'] as String,
                    (item['price'] as num).toDouble(),
                  );
                }
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  void _showCartPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CartPanel(),
    );
  }
}

// ─── Category Chip ───
class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? color : KinsaepTheme.border,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : KinsaepTheme.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Item Card ───
class _ItemCard extends StatelessWidget {
  final String name;
  final String price;
  final String? imagePath;
  final VoidCallback onTap;

  const _ItemCard({
    required this.name,
    required this.price,
    this.imagePath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: KinsaepTheme.border.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image area
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: KinsaepTheme.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: Center(
                  child: Icon(
                    Icons.fastfood_rounded,
                    color: KinsaepTheme.primary.withValues(alpha: 0.3),
                    size: 32,
                  ),
                ),
              ),
            ),
            // Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: KinsaepTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      price,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: KinsaepTheme.primary,
                      ),
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
}
