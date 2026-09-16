import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'app_store.dart';
import 'models.dart';
import 'core/services/permission_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/empiran_components.dart';
import 'suite.dart' show confirmDelete, adjustStock;

class ProductsScreen extends StatefulWidget {
  const ProductsScreen(this.store, {super.key});
  final AppStore store;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String query = '';
  String? selectedCategory;
  String stockFilter = 'All'; // 'All', 'In Stock', 'Low Stock', 'Out of Stock'

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final canManage =
        PermissionService.canManageProducts(widget.store.currentUserRole);
    final canViewCost =
        PermissionService.canViewCostPrice(widget.store.currentUserRole);

    // Filter items based on selected category, query and stock status
    final filteredItems = widget.store.items.where((i) {
      if (selectedCategory != null && i.category != selectedCategory) {
        return false;
      }
      if (query.isNotEmpty &&
          !i.name.toLowerCase().contains(query.toLowerCase()) &&
          !i.itemCode.toLowerCase().contains(query.toLowerCase()) &&
          !i.hsn.toLowerCase().contains(query.toLowerCase())) {
        return false;
      }
      if (stockFilter == 'In Stock') {
        return !i.isService && i.currentStock > i.lowStockLimit;
      } else if (stockFilter == 'Low Stock') {
        return !i.isService &&
            i.currentStock > 0 &&
            i.currentStock <= i.lowStockLimit;
      } else if (stockFilter == 'Out of Stock') {
        return !i.isService && i.currentStock <= 0;
      }
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Products & Inventory',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${widget.store.items.length} items catalogued across ${widget.store.categories.length} categories',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
              if (canManage)
                Row(
                  children: [
                    EmpiranButton(
                      label: 'Add Category',
                      icon: Icons.category_outlined,
                      variant: EmpiranButtonVariant.outlined,
                      onPressed: () => _categoryDialog(context),
                    ),
                    const SizedBox(width: 8),
                    EmpiranButton(
                      label: 'Create Product',
                      icon: Icons.add,
                      onPressed: () => _productDialog(
                        context,
                        widget.store,
                        category: selectedCategory,
                      ).then((_) => setState(() {})),
                    ),
                  ],
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility_outlined,
                          size: 14, color: Color(0xFF10B981)),
                      SizedBox(width: 6),
                      Text(
                        'Read-Only Catalog',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),

          // Categories Horizontal Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All Categories'),
                  selected: selectedCategory == null,
                  onSelected: (_) => setState(() => selectedCategory = null),
                ),
                const SizedBox(width: 8),
                ...widget.store.categories.map((cat) {
                  final isSelected = selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InputChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (v) {
                        setState(() {
                          selectedCategory = v ? cat : null;
                        });
                      },
                      onDeleted: cat == 'General'
                          ? null
                          : () async {
                              if (await confirmDelete(
                                context,
                                'Delete category "$cat"? Products will be moved to "General".',
                              )) {
                                await widget.store.deleteCategory(cat);
                                if (selectedCategory == cat) {
                                  setState(() => selectedCategory = null);
                                }
                              }
                            },
                      deleteIcon: const Icon(Icons.close, size: 14),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Search & Stock Status Filters
          Row(
            children: [
              Expanded(
                child: EmpiranSearchBar(
                  hint: 'Search products by name, item code or HSN…',
                  initialValue: query,
                  onChanged: (v) => setState(() => query = v),
                ),
              ),
              const SizedBox(width: 12),
              // Stock Filter Chips
              for (final filter in [
                'All',
                'In Stock',
                'Low Stock',
                'Out of Stock'
              ])
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: FilterChip(
                    label: Text(filter),
                    selected: stockFilter == filter,
                    onSelected: (_) => setState(() => stockFilter = filter),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Product List / Grid
          Expanded(
            child: filteredItems.isEmpty
                ? EmpiranEmptyState(
                    title: 'No products found',
                    description: query.isNotEmpty
                        ? 'No products matched "$query". Clear your search or add a new product.'
                        : 'Get started by creating your first product or importing inventory.',
                    icon: Icons.inventory_2_outlined,
                    actionLabel: canManage ? 'Add Product' : null,
                    onAction: canManage
                        ? () => _productDialog(context, widget.store)
                            .then((_) => setState(() {}))
                        : null,
                  )
                : ListView.separated(
                    itemCount: filteredItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      return EmpiranCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            // Product Image Thumbnail
                            _buildThumbnail(context, item),
                            const SizedBox(width: 14),

                            // Product Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? AppColors
                                                  .darkSurfaceContainerHighest
                                              : AppColors
                                                  .lightSurfaceContainerHighest,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          item.category,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? AppColors.darkTextSecondary
                                                : AppColors.lightTextSecondary,
                                          ),
                                        ),
                                      ),
                                      if (item.itemCode.isNotEmpty)
                                        Text(
                                          'SKU: ${item.itemCode}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? AppColors.darkTextMuted
                                                : AppColors.lightTextMuted,
                                          ),
                                        ),
                                      if (item.hsn.isNotEmpty)
                                        Text(
                                          'HSN: ${item.hsn}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? AppColors.darkTextMuted
                                                : AppColors.lightTextMuted,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Pricing & Stock
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  AppTypography.formatCurrency(item.salesPrice),
                                  style: AppTypography.number.copyWith(
                                    fontSize: 16,
                                    color: AppColors.primary,
                                  ),
                                ),
                                if (canViewCost && item.purchasePrice > 0)
                                  Text(
                                    'Cost: ${AppTypography.formatCurrency(item.purchasePrice)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? AppColors.darkTextMuted
                                          : AppColors.lightTextMuted,
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                _buildStockBadge(item),
                              ],
                            ),
                            const SizedBox(width: 14),

                            // Action Buttons
                            if (canManage) ...[
                              const SizedBox(width: 14),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!item.isService)
                                    IconButton(
                                      tooltip: 'Adjust Stock',
                                      icon: const Icon(Icons.add_box_outlined,
                                          color: AppColors.primary, size: 22),
                                      onPressed: () async {
                                        await adjustStock(
                                            context, widget.store, item);
                                        setState(() {});
                                      },
                                    ),
                                  IconButton(
                                    tooltip: 'Edit Product',
                                    icon: const Icon(Icons.edit_outlined,
                                        size: 20),
                                    onPressed: () => _productDialog(
                                      context,
                                      widget.store,
                                      item: item,
                                    ).then((_) => setState(() {})),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context, Item item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (item.image != null && item.image!.isNotEmpty) {
      try {
        final clean = item.image!.contains(',')
            ? item.image!.split(',').last
            : item.image!;
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          child: Image.memory(
            base64Decode(clean),
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _defaultThumb(isDark, item.isService),
          ),
        );
      } catch (_) {}
    }
    return _defaultThumb(isDark, item.isService);
  }

  Widget _defaultThumb(bool isDark, bool isService) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainerHighest
            : AppColors.primarySubtle,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFDCEAF9),
          width: 1,
        ),
      ),
      child: Icon(
        isService ? Icons.design_services_rounded : Icons.inventory_2_rounded,
        color: AppColors.primary,
        size: 24,
      ),
    );
  }

  Widget _buildStockBadge(Item item) {
    if (item.isService) {
      return const EmpiranStatusChip(
          label: 'Service', type: EmpiranStatusType.info, small: true);
    }
    if (item.currentStock <= 0) {
      return const EmpiranStatusChip(
          label: 'Out of Stock', type: EmpiranStatusType.error, small: true);
    }
    if (item.currentStock <= item.lowStockLimit) {
      return EmpiranStatusChip(
        label: 'Low: ${item.currentStock.toStringAsFixed(0)} ${item.unit}',
        type: EmpiranStatusType.warning,
        small: true,
      );
    }
    return EmpiranStatusChip(
      label: '${item.currentStock.toStringAsFixed(0)} ${item.unit}',
      type: EmpiranStatusType.success,
      small: true,
    );
  }

  Future<void> _categoryDialog(BuildContext context) async {
    final catController = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Product Category'),
        content: SizedBox(
          width: 380,
          child: EmpiranTextField(
            controller: catController,
            label: 'Category Name',
            hint: 'e.g. Cables, Switches, LED',
            isRequired: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          EmpiranButton(
            label: 'Save Category',
            onPressed: () async {
              if (catController.text.trim().isNotEmpty) {
                await widget.store.addCategory(catController.text.trim());
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
    setState(() {});
  }
}

Future<void> _productDialog(
  BuildContext context,
  AppStore store, {
  Item? item,
  String? category,
}) async {
  final name = TextEditingController(text: item?.name ?? '');
  final hsn = TextEditingController(text: item?.hsn ?? '');
  final code = TextEditingController(text: item?.itemCode ?? '');
  final purchase = TextEditingController(text: '${item?.purchasePrice ?? 0}');
  final sales = TextEditingController(text: '${item?.salesPrice ?? 0}');
  final stock = TextEditingController(text: '${item?.currentStock ?? 0}');
  final unit = TextEditingController(text: item?.unit ?? 'Pcs');
  final low = TextEditingController(text: '${item?.lowStockLimit ?? 5}');
  bool isService = item?.isService ?? false;
  String? image = item?.image;

  String selectedCat = item?.category ?? category ?? 'General';
  if (!store.categories.contains(selectedCat)) {
    selectedCat = 'General';
  }

  String? error;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(item == null ? 'Create New Product' : 'Edit Product'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Category & Name
                DropdownButtonFormField<String>(
                  initialValue: selectedCat,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: store.categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) set(() => selectedCat = v);
                  },
                ),
                const SizedBox(height: 12),
                EmpiranTextField(
                  controller: name,
                  label: 'Product Name',
                  hint: 'e.g. LED Downlight 15W',
                  isRequired: true,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: EmpiranTextField(
                        controller: code,
                        label: 'SKU / Barcode',
                        hint: 'Item code',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EmpiranTextField(
                        controller: hsn,
                        label: 'HSN Code',
                        hint: 'e.g. 8539',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: EmpiranTextField(
                        controller: sales,
                        label: 'Selling Price (₹)',
                        hint: '0.00',
                        isNumber: true,
                        isDecimal: true,
                        isRequired: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EmpiranTextField(
                        controller: purchase,
                        label: 'Purchase Cost (₹)',
                        hint: '0.00',
                        isNumber: true,
                        isDecimal: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: EmpiranTextField(
                        controller: stock,
                        label: 'Opening Stock',
                        hint: '0',
                        isNumber: true,
                        isDecimal: true,
                        enabled: item == null,
                        helperText:
                            item != null ? 'Use "Adjust Stock" on list.' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EmpiranTextField(
                        controller: low,
                        label: 'Low Stock Limit',
                        hint: '5',
                        isNumber: true,
                        isDecimal: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EmpiranTextField(
                        controller: unit,
                        label: 'Unit',
                        hint: 'Pcs',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Service Item (No Stock Tracking)',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  value: isService,
                  onChanged: (v) => set(() => isService = v),
                ),
                const SizedBox(height: 10),

                // Modern Image Upload Widget
                Row(
                  children: [
                    if (image != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.medium),
                        child: Image.memory(
                          base64Decode(image!.contains(',')
                              ? image!.split(',').last
                              : image!),
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    EmpiranButton(
                      label: image == null ? 'Add Image' : 'Change Image',
                      icon: Icons.photo_library_outlined,
                      variant: EmpiranButtonVariant.outlined,
                      height: 40,
                      onPressed: () async {
                        final f = await ImagePicker().pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 70,
                          maxWidth: 1000,
                        );
                        if (f != null) {
                          image = base64Encode(await f.readAsBytes());
                          set(() {});
                        }
                      },
                    ),
                    if (image != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Remove',
                        icon: const Icon(Icons.delete_outline,
                            color: AppColors.error),
                        onPressed: () => set(() => image = null),
                      ),
                    ],
                  ],
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!,
                      style: const TextStyle(
                          color: AppColors.error, fontSize: 13)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (item != null)
            TextButton(
              onPressed: () async {
                if (await confirmDelete(
                    context, 'Delete product "${item.name}"?')) {
                  await store.deleteItem(item);
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.error)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          EmpiranButton(
            label: 'Save Product',
            onPressed: () async {
              if (name.text.trim().isEmpty ||
                  double.tryParse(sales.text) == null ||
                  double.tryParse(purchase.text) == null ||
                  double.tryParse(stock.text) == null) {
                set(() => error = 'Please enter valid details and numbers.');
                return;
              }
              try {
                await store.addItem(
                  Item(
                    id: item?.id ??
                        DateTime.now().microsecondsSinceEpoch.toString(),
                    name: name.text.trim(),
                    hsn: hsn.text.trim(),
                    itemCode: code.text.trim(),
                    purchasePrice: double.parse(purchase.text),
                    salesPrice: double.parse(sales.text),
                    currentStock: double.parse(stock.text),
                    category: selectedCat,
                    unit: unit.text.trim().isEmpty ? 'Pcs' : unit.text.trim(),
                    lowStockLimit: double.tryParse(low.text) ?? 5,
                    isService: isService,
                    image: image,
                  ),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                set(() => error = '$e');
              }
            },
          ),
        ],
      ),
    ),
  );

  Future.delayed(const Duration(milliseconds: 500), () {
    for (final c in [name, hsn, code, purchase, sales, stock, unit, low]) {
      c.dispose();
    }
  });
}
