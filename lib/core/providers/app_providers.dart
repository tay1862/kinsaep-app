import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinsaep_pos/core/database/database_helper.dart';

// ─── Database Provider ───
final databaseProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper.instance;
});

// ─── Store Settings ───
final storeSettingsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final db = ref.watch(databaseProvider);
  return await db.getSettings();
});

// ─── Categories ───
final categoriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseProvider);
  return await db.getCategories();
});

// ─── Items ───
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

final itemsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseProvider);
  final categoryId = ref.watch(selectedCategoryProvider);
  return await db.getItems(categoryId: categoryId);
});

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchItemsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseProvider);
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return [];
  return await db.searchItems(query);
});

// ─── Cart ───
class CartItem {
  final String id;
  final String itemId;
  final String name;
  final double unitPrice;
  int quantity;
  final String? note;

  CartItem({
    required this.id,
    required this.itemId,
    required this.name,
    required this.unitPrice,
    this.quantity = 1,
    this.note,
  });

  double get totalPrice => unitPrice * quantity;

  CartItem copyWith({int? quantity, String? note}) {
    return CartItem(
      id: id,
      itemId: itemId,
      name: name,
      unitPrice: unitPrice,
      quantity: quantity ?? this.quantity,
      note: note ?? this.note,
    );
  }
}

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  void addItem(String itemId, String name, double price) {
    final existingIndex = state.indexWhere((e) => e.itemId == itemId);
    if (existingIndex >= 0) {
      final updated = [...state];
      updated[existingIndex] = updated[existingIndex].copyWith(
        quantity: updated[existingIndex].quantity + 1,
      );
      state = updated;
    } else {
      state = [
        ...state,
        CartItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          itemId: itemId,
          name: name,
          unitPrice: price,
        ),
      ];
    }
  }

  void removeItem(String id) {
    state = state.where((e) => e.id != id).toList();
  }

  void updateQuantity(String itemId, int delta) {
    state = state.map((item) {
      if (item.itemId == itemId) {
        final newQty = item.quantity + delta;
        return newQty > 0 ? item.copyWith(quantity: newQty) : item;
      }
      return item;
    }).toList();
  }

  void addItemFromTicket({
    required String itemId,
    required String name,
    required double price,
    required int quantity,
  }) {
    state = [
      ...state,
      CartItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(), // Generate a unique ID
        itemId: itemId,
        name: name,
        unitPrice: price,
        quantity: quantity,
      ),
    ];
  }

  void clearCart() {
    state = [];
  }

  double get subtotal => state.fold(0, (sum, item) => sum + item.totalPrice);
  int get itemCount => state.fold(0, (sum, item) => sum + item.quantity);
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier();
});

final cartSubtotalProvider = Provider<double>((ref) {
  final items = ref.watch(cartProvider);
  return items.fold(0, (sum, item) => sum + item.totalPrice);
});

final cartItemCountProvider = Provider<int>((ref) {
  final items = ref.watch(cartProvider);
  return items.fold(0, (sum, item) => sum + item.quantity);
});

// ─── Discount ───
final discountPercentProvider = StateProvider<double>((ref) => 0);
final discountAmountProvider = StateProvider<double>((ref) => 0);

final totalAfterDiscountProvider = Provider<double>((ref) {
  final subtotal = ref.watch(cartSubtotalProvider);
  final discountPercent = ref.watch(discountPercentProvider);
  final discountAmount = ref.watch(discountAmountProvider);
  double total = subtotal;
  if (discountPercent > 0) {
    total -= total * (discountPercent / 100);
  }
  if (discountAmount > 0) {
    total -= discountAmount;
  }
  return total < 0 ? 0 : total;
});

// ─── Daily Summary ───
final dailySummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final db = ref.watch(databaseProvider);
  final today = DateTime.now().toIso8601String().substring(0, 10);
  return await db.getDailySummary(today);
});

final topItemsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseProvider);
  final today = DateTime.now().toIso8601String().substring(0, 10);
  return await db.getTopItems(today);
});

final salesHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseProvider);
  return await db.getSales();
});

// ─── Navigation ───
final currentTabProvider = StateProvider<int>((ref) => 0);

// ─── Currency ───
final currencyProvider = StateProvider<String>((ref) => 'LAK');

// ─── Open Tickets & Tables ───
final openTicketsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return DatabaseHelper.instance.getOpenTickets();
});

final activeTicketIdProvider = StateProvider<String?>((ref) => null);
final activeTicketNameProvider = StateProvider<String?>((ref) => null);
