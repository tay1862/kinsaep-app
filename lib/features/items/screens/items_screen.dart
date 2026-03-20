import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:kinsaep_pos/app/theme.dart';
import 'package:kinsaep_pos/core/providers/app_providers.dart';
import 'package:kinsaep_pos/core/database/database_helper.dart';
import 'package:kinsaep_pos/core/utils/currency_util.dart';
import 'package:kinsaep_pos/core/utils/media_util.dart';
import 'package:uuid/uuid.dart';
import 'package:kinsaep_pos/features/items/widgets/modifier_editor.dart';

class ItemsScreen extends ConsumerStatefulWidget {
  const ItemsScreen({super.key});

  @override
  ConsumerState<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends ConsumerState<ItemsScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = ref.watch(itemsProvider);
    final categories = ref.watch(categoriesProvider);
    final kitchenStations = ref.watch(kitchenStationsProvider);
    final currency = ref.watch(currencyProvider);

    return Scaffold(
      backgroundColor: KinsaepTheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: KinsaepTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.inventory_2_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l10n.items,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  // Add category
                  _ActionButton(
                    icon: Icons.category_rounded,
                    label: l10n.addCategory,
                    onTap: () => _showAddCategoryDialog(context, ref, l10n),
                  ),
                ],
              ),
            ),

            // Categories horizontal list
            categories.when(
              data: (cats) {
                if (cats.isEmpty) return const SizedBox();
                return Container(
                  height: 44,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children:
                        cats
                            .map(
                              (cat) => Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: Color(
                                    cat['color'] as int,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Color(
                                      cat['color'] as int,
                                    ).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: Color(cat['color'] as int),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      cat['name'] as String,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: Color(cat['color'] as int),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                  ),
                );
              },
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),

            // Items list
            Expanded(
              child: items.when(
                data: (itemList) {
                  if (itemList.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: KinsaepTheme.primary.withValues(
                                alpha: 0.08,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.add_shopping_cart_rounded,
                              size: 48,
                              color: KinsaepTheme.primary.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.noItems,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: KinsaepTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.addYourFirstItem,
                            style: const TextStyle(
                              fontSize: 14,
                              color: KinsaepTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed:
                                () => _showAddItemDialog(
                                  context,
                                  ref,
                                  l10n,
                                  categories.value ?? [],
                                  kitchenStations.value ?? [],
                                ),
                            icon: const Icon(Icons.add_rounded),
                            label: Text(l10n.addItem),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    itemCount: itemList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = itemList[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: KinsaepTheme.cardShadow,
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: KinsaepTheme.surface,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _buildItemThumbnail(item),
                          ),
                          title: Text(
                            item['name'] as String,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Row(
                            children: [
                              Text(
                                CurrencyUtil.format(
                                  (item['price'] as num).toDouble(),
                                  currency,
                                ),
                                style: const TextStyle(
                                  color: KinsaepTheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (item['trackStock'] == 1) ...[
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        (item['stockQuantity'] as num)
                                                    .toDouble() >
                                                (item['lowStockThreshold']
                                                        as num)
                                                    .toDouble()
                                            ? KinsaepTheme.accent.withValues(
                                              alpha: 0.1,
                                            )
                                            : KinsaepTheme.warning.withValues(
                                              alpha: 0.1,
                                            ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${l10n.stock}: ${(item['stockQuantity'] as num).toInt()}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          (item['stockQuantity'] as num)
                                                      .toDouble() >
                                                  (item['lowStockThreshold']
                                                          as num)
                                                      .toDouble()
                                              ? KinsaepTheme.accent
                                              : KinsaepTheme.warning,
                                    ),
                                  ),
                                ),
                              ],
                              if ((item['syncStatus'] as String?) ==
                                  'PENDING') ...[
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: KinsaepTheme.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Pending sync',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: KinsaepTheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_vert_rounded,
                              color: KinsaepTheme.textSecondary,
                            ),
                            onSelected: (value) async {
                              if (value == 'delete') {
                                await DatabaseHelper.instance.deleteItem(
                                  item['id'] as String,
                                );
                                ref.invalidate(itemsProvider);
                              } else if (value == 'edit') {
                                _showAddItemDialog(
                                  context,
                                  ref,
                                  l10n,
                                  categories.value ?? [],
                                  kitchenStations.value ?? [],
                                  editItem: item,
                                );
                              }
                            },
                            itemBuilder:
                                (context) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text(l10n.editItem),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text(
                                      l10n.deleteItem,
                                      style: const TextStyle(
                                        color: KinsaepTheme.error,
                                      ),
                                    ),
                                  ),
                                ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
            () => _showAddItemDialog(
              context,
              ref,
              l10n,
              categories.value ?? [],
              kitchenStations.value ?? [],
            ),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.addItem),
      ),
    );
  }

  Widget _buildItemThumbnail(Map<String, dynamic> item) {
    final imagePath = item['imagePath'] as String?;
    final imageUrl = item['imageUrl'] as String?;
    if (imagePath != null &&
        imagePath.isNotEmpty &&
        File(imagePath).existsSync()) {
      return Image.file(File(imagePath), fit: BoxFit.cover);
    }
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder:
            (_, __, ___) => Icon(
              Icons.fastfood_rounded,
              color: KinsaepTheme.primary.withValues(alpha: 0.4),
            ),
      );
    }
    return Icon(
      Icons.fastfood_rounded,
      color: KinsaepTheme.primary.withValues(alpha: 0.4),
    );
  }

  void _showAddCategoryDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final nameController = TextEditingController();
    int selectedColor = KinsaepTheme.categoryColors[0].toARGB32();

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setDialogState) => AlertDialog(
                  title: Text(l10n.addCategory),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(hintText: l10n.category),
                        autofocus: true,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.categoryColor,
                        style: const TextStyle(
                          fontSize: 13,
                          color: KinsaepTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            KinsaepTheme.categoryColors
                                .map(
                                  (color) => GestureDetector(
                                    onTap:
                                        () => setDialogState(
                                          () =>
                                              selectedColor = color.toARGB32(),
                                        ),
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                        border:
                                            selectedColor == color.toARGB32()
                                                ? Border.all(
                                                  color:
                                                      KinsaepTheme.textPrimary,
                                                  width: 3,
                                                )
                                                : null,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(l10n.cancel),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (nameController.text.trim().isEmpty) return;
                        final now = DateTime.now().toIso8601String();
                        await DatabaseHelper.instance.insertCategory({
                          'id': const Uuid().v4(),
                          'name': nameController.text.trim(),
                          'color': selectedColor,
                          'sortOrder': 0,
                          'createdAt': now,
                          'updatedAt': now,
                        });
                        ref.invalidate(categoriesProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: Text(l10n.save),
                    ),
                  ],
                ),
          ),
    );
  }

  void _showAddItemDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    List<Map<String, dynamic>> categories,
    List<Map<String, dynamic>> kitchenStations, {
    Map<String, dynamic>? editItem,
  }) {
    final nameController = TextEditingController(
      text: editItem?['name'] as String?,
    );
    final priceController = TextEditingController(
      text: editItem != null ? '${editItem['price']}' : '',
    );
    final costController = TextEditingController(
      text: editItem != null ? '${editItem['cost']}' : '',
    );
    final barcodeController = TextEditingController(
      text: editItem?['barcode'] as String? ?? '',
    );
    final skuController = TextEditingController(
      text: editItem?['sku'] as String? ?? '',
    );
    final itemId = editItem?['id'] as String? ?? const Uuid().v4();
    String? selectedCategoryId = editItem?['categoryId'] as String?;
    String? selectedKitchenStationId = editItem?['kitchenStationId'] as String?;
    bool trackStock = (editItem?['trackStock'] as int? ?? 0) == 1;
    final stockController = TextEditingController(
      text: editItem != null ? '${editItem['stockQuantity']}' : '0',
    );
    final lowStockThresholdController = TextEditingController(
      text: editItem != null ? '${editItem['lowStockThreshold']}' : '5',
    );
    String modifiersJson = editItem?['modifiers'] as String? ?? '[]';
    SavedMediaAsset? pickedAsset;
    String? localImagePath = editItem?['imagePath'] as String?;
    String? remoteImageUrl = editItem?['imageUrl'] as String?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setSheetState) => Container(
                  height: MediaQuery.of(context).size.height * 0.85,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: Row(
                          children: [
                            Text(
                              editItem == null ? l10n.addItem : l10n.editItem,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ),
                      const Divider(),
                      // Form
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: nameController,
                                decoration: InputDecoration(
                                  labelText: l10n.itemName,
                                  prefixIcon: const Icon(
                                    Icons.label_outline_rounded,
                                  ),
                                ),
                                autofocus: true,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: priceController,
                                      decoration: InputDecoration(
                                        labelText: l10n.price,
                                        prefixIcon: const Icon(
                                          Icons.attach_money_rounded,
                                        ),
                                      ),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: costController,
                                      decoration: InputDecoration(
                                        labelText: l10n.cost,
                                        prefixIcon: const Icon(
                                          Icons.money_off_rounded,
                                        ),
                                      ),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Category
                              if (categories.isNotEmpty)
                                DropdownButtonFormField<String>(
                                  value: selectedCategoryId,
                                  decoration: InputDecoration(
                                    labelText: l10n.category,
                                    prefixIcon: const Icon(
                                      Icons.category_outlined,
                                    ),
                                  ),
                                  items:
                                      categories
                                          .map(
                                            (cat) => DropdownMenuItem(
                                              value: cat['id'] as String,
                                              child: Text(
                                                cat['name'] as String,
                                              ),
                                            ),
                                          )
                                          .toList(),
                                  onChanged:
                                      (v) => setSheetState(
                                        () => selectedCategoryId = v,
                                      ),
                                ),
                              const SizedBox(height: 16),
                              if (kitchenStations.isNotEmpty)
                                DropdownButtonFormField<String>(
                                  value: selectedKitchenStationId,
                                  decoration: const InputDecoration(
                                    labelText: 'Kitchen Station',
                                    prefixIcon: Icon(
                                      Icons.soup_kitchen_rounded,
                                    ),
                                  ),
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: null,
                                      child: Text('No station'),
                                    ),
                                    ...kitchenStations.map(
                                      (station) => DropdownMenuItem(
                                        value: station['id'] as String,
                                        child: Text(
                                          '${station['name']} (${station['type']})',
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged:
                                      (value) => setSheetState(
                                        () => selectedKitchenStationId = value,
                                      ),
                                ),
                              if (kitchenStations.isNotEmpty)
                                const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: KinsaepTheme.surface,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Product Image',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Container(
                                          width: 72,
                                          height: 72,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: KinsaepTheme.border,
                                            ),
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child:
                                              localImagePath != null &&
                                                      localImagePath!
                                                          .isNotEmpty &&
                                                      File(
                                                        localImagePath!,
                                                      ).existsSync()
                                                  ? Image.file(
                                                    File(localImagePath!),
                                                    fit: BoxFit.cover,
                                                  )
                                                  : (remoteImageUrl != null &&
                                                      remoteImageUrl!
                                                          .isNotEmpty)
                                                  ? Image.network(
                                                    remoteImageUrl!,
                                                    fit: BoxFit.cover,
                                                    errorBuilder:
                                                        (
                                                          _,
                                                          __,
                                                          ___,
                                                        ) => const Icon(
                                                          Icons.image_outlined,
                                                        ),
                                                  )
                                                  : const Icon(
                                                    Icons.image_outlined,
                                                  ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              OutlinedButton.icon(
                                                onPressed: () async {
                                                  final file =
                                                      await MediaUtil.pickFromCamera();
                                                  if (file == null) {
                                                    return;
                                                  }
                                                  final asset =
                                                      await MediaUtil.savePickedImage(
                                                        file,
                                                        itemId: itemId,
                                                      );
                                                  if (asset == null) {
                                                    return;
                                                  }
                                                  setSheetState(() {
                                                    pickedAsset = asset;
                                                    localImagePath =
                                                        asset.imagePath;
                                                    remoteImageUrl = null;
                                                  });
                                                },
                                                icon: const Icon(
                                                  Icons.photo_camera_rounded,
                                                ),
                                                label: const Text('Camera'),
                                              ),
                                              OutlinedButton.icon(
                                                onPressed: () async {
                                                  final file =
                                                      await MediaUtil.pickFromGallery();
                                                  if (file == null) {
                                                    return;
                                                  }
                                                  final asset =
                                                      await MediaUtil.savePickedImage(
                                                        file,
                                                        itemId: itemId,
                                                      );
                                                  if (asset == null) {
                                                    return;
                                                  }
                                                  setSheetState(() {
                                                    pickedAsset = asset;
                                                    localImagePath =
                                                        asset.imagePath;
                                                    remoteImageUrl = null;
                                                  });
                                                },
                                                icon: const Icon(
                                                  Icons.photo_library_rounded,
                                                ),
                                                label: const Text('Gallery'),
                                              ),
                                              if (localImagePath != null ||
                                                  remoteImageUrl != null)
                                                TextButton.icon(
                                                  onPressed: () {
                                                    setSheetState(() {
                                                      pickedAsset = null;
                                                      localImagePath = null;
                                                      remoteImageUrl = null;
                                                    });
                                                  },
                                                  icon: const Icon(
                                                    Icons
                                                        .delete_outline_rounded,
                                                  ),
                                                  label: const Text('Remove'),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: barcodeController,
                                decoration: InputDecoration(
                                  labelText: l10n.barcode,
                                  prefixIcon: const Icon(
                                    Icons.qr_code_scanner_rounded,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: skuController,
                                decoration: InputDecoration(
                                  labelText: l10n.sku,
                                  prefixIcon: const Icon(Icons.qr_code_rounded),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Modifiers & Variants',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  modifiersJson == '[]'
                                      ? 'None added'
                                      : 'Configured',
                                  style: const TextStyle(
                                    color: KinsaepTheme.primary,
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => ModifierEditor(
                                            initialModifiers: modifiersJson,
                                            onSave: (json) {
                                              setSheetState(() {
                                                modifiersJson = json;
                                              });
                                            },
                                          ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              // Track stock
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(l10n.trackStock),
                                value: trackStock,
                                onChanged:
                                    (v) => setSheetState(() => trackStock = v),
                                activeColor: KinsaepTheme.primary,
                              ),
                              if (trackStock) ...[
                                TextField(
                                  controller: stockController,
                                  decoration: InputDecoration(
                                    labelText: l10n.stock,
                                    prefixIcon: const Icon(
                                      Icons.inventory_rounded,
                                    ),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: lowStockThresholdController,
                                  decoration: InputDecoration(
                                    labelText: l10n.lowStockAlert,
                                    prefixIcon: const Icon(
                                      Icons.warning_amber_rounded,
                                    ),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      // Save button
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        child: SafeArea(
                          child: SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (nameController.text.trim().isEmpty) return;
                                final now = DateTime.now().toIso8601String();
                                final row = {
                                  'id': itemId,
                                  'name': nameController.text.trim(),
                                  'price':
                                      double.tryParse(priceController.text) ??
                                      0,
                                  'cost':
                                      double.tryParse(costController.text) ?? 0,
                                  'categoryId': selectedCategoryId,
                                  'kitchenStationId': selectedKitchenStationId,
                                  'barcode':
                                      barcodeController.text.isEmpty
                                          ? null
                                          : barcodeController.text,
                                  'sku':
                                      skuController.text.isEmpty
                                          ? null
                                          : skuController.text,
                                  'imagePath': localImagePath,
                                  'imageUrl': remoteImageUrl,
                                  'trackStock': trackStock ? 1 : 0,
                                  'stockQuantity':
                                      double.tryParse(stockController.text) ??
                                      0,
                                  'lowStockThreshold':
                                      double.tryParse(
                                        lowStockThresholdController.text,
                                      ) ??
                                      5.0,
                                  'modifiers': modifiersJson,
                                  'updatedAt': now,
                                };

                                if (editItem == null) {
                                  row['isActive'] = 1;
                                  row['sortOrder'] = 0;
                                  row['createdAt'] = now;
                                  await DatabaseHelper.instance.insertItem(row);
                                } else {
                                  await DatabaseHelper.instance.updateItem(
                                    editItem['id'] as String,
                                    row,
                                  );
                                }
                                if (pickedAsset != null) {
                                  await DatabaseHelper.instance.saveMediaAsset({
                                    'id': const Uuid().v4(),
                                    'itemId': itemId,
                                    'fileName': pickedAsset!.fileName,
                                    'mimeType': pickedAsset!.mimeType,
                                    'imagePath': pickedAsset!.imagePath,
                                    'thumbnailBase64':
                                        pickedAsset!.thumbnailBase64,
                                    'remoteUrl': null,
                                    'syncStatus':
                                        ((ref
                                                        .read(
                                                          storeSettingsProvider,
                                                        )
                                                        .value?['syncEnabled'] ??
                                                    0) ==
                                                1)
                                            ? 'PENDING'
                                            : 'PENDING',
                                    'createdAt': now,
                                    'updatedAt': now,
                                  });
                                }

                                ref.invalidate(itemsProvider);
                                ref.invalidate(categoriesProvider);
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                              child: Text(
                                l10n.save,
                                style: const TextStyle(fontSize: 16),
                              ),
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
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: KinsaepTheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: KinsaepTheme.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: KinsaepTheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
