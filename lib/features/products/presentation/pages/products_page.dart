import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:empiran/core/services/permission_service.dart';
import 'package:empiran/core/theme/app_theme.dart';
import 'package:empiran/core/utils/formatters.dart';
import 'package:empiran/core/utils/image_helper.dart';
import 'package:empiran/core/widgets/empiran_components.dart';
import 'package:empiran/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:empiran/features/auth/presentation/bloc/auth_state.dart';
import 'package:empiran/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:empiran/features/settings/presentation/bloc/settings_event.dart';
import 'package:empiran/features/settings/presentation/bloc/settings_state.dart';
import 'package:empiran/models.dart';
import '../bloc/products_bloc.dart';
import '../bloc/products_event.dart';
import '../bloc/products_state.dart';
import '../widgets/product_dialog.dart';
import '../widgets/stock_adjust_dialog.dart';
import '../widgets/stock_history_dialog.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _stockFilter = 'All'; // 'All', 'In Stock', 'Low Stock', 'Out of Stock'
  Map<String, String> _categoryImages = {};

  @override
  void initState() {
    super.initState();
    context.read<ProductsBloc>().add(const LoadProductsRequested());
    _loadCategoryImages();
  }

  Future<void> _loadCategoryImages() async {
    final images = await context
        .read<SettingsBloc>()
        .settingsRepository
        .loadCategoryImages();
    if (mounted) {
      setState(() => _categoryImages = images);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onFilterChanged() {
    context.read<ProductsBloc>().add(
          FilterProductsRequested(
            query: _searchController.text.trim(),
            category: _selectedCategory,
          ),
        );
  }

  Widget _buildProductThumbnail(Item item, {double size = 56}) {
    final imageBytes = ImageHelper.decodeBase64(item.image);
    final radius = BorderRadius.circular(AppRadii.medium);

    Widget fallbackIcon() => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.lightSurfaceContainer,
            borderRadius: radius,
          ),
          child: const Icon(
            Icons.inventory_2_outlined,
            color: AppColors.primary,
          ),
        );

    if (imageBytes == null) return fallbackIcon();

    final cacheSize = (size * MediaQuery.devicePixelRatioOf(context)).toInt();

    return ClipRRect(
      borderRadius: radius,
      child: Image.memory(
        imageBytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        cacheWidth: cacheSize,
        errorBuilder: (_, __, ___) => fallbackIcon(),
      ),
    );
  }

  Widget _buildCategoryCard(
    String cat,
    int count,
    bool isSelected,
    bool canManage,
  ) {
    final imageBase64 = _categoryImages[cat];
    final imageBytes = ImageHelper.decodeBase64(imageBase64);

    return InkWell(
      onTap: () {
        setState(() => _selectedCategory = cat);
        _onFilterChanged();
      },
      onLongPress: cat == 'All' || !canManage
          ? null
          : () => _editCategoryDialog(context, cat),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 96,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : Colors.grey.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : AppColors.lightSurfaceContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: imageBytes != null
                      ? Image.memory(
                          imageBytes,
                          width: 30,
                          height: 30,
                          fit: BoxFit.cover,
                          cacheWidth: (30 * MediaQuery.devicePixelRatioOf(context)).toInt(),
                          errorBuilder: (_, __, ___) => Icon(
                            cat == 'All'
                                ? Icons.apps_rounded
                                : Icons.category_rounded,
                            color: isSelected
                                ? AppColors.primary
                                : Colors.grey.shade600,
                            size: 22,
                          ),
                        )
                      : Icon(
                          cat == 'All'
                              ? Icons.apps_rounded
                              : Icons.category_rounded,
                          color: isSelected
                              ? AppColors.primary
                              : Colors.grey.shade600,
                          size: 22,
                        ),
                ),
                const SizedBox(height: 4),
                Text(
                  cat,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? AppColors.primary : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  cat == 'All' ? '$count items' : '$count items',
                  style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                ),
              ],
            ),
            if (cat != 'All' && canManage)
              Positioned(
                top: -4,
                right: -4,
                child: InkWell(
                  onTap: () => _editCategoryDialog(context, cat),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.edit_outlined,
                        size: 11, color: AppColors.primary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteProduct(BuildContext context, Item item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product?'),
        content: Text(
            'Are you sure you want to delete "${item.name}"? This action will remove the item from catalog.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          EmpiranButton(
            label: 'Delete Product',
            variant: EmpiranButtonVariant.danger,
            icon: Icons.delete_outline,
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ProductsBloc>().add(DeleteProductRequested(item));
            },
          ),
        ],
      ),
    );
  }

  void _showProductDetailsSheet(
    BuildContext context,
    Item item,
    bool canManage,
    bool canViewCost,
  ) {
    final imageBytes = ImageHelper.decodeBase64(item.image);
    final isLowStock =
        !item.isService && item.currentStock <= item.lowStockLimit;
    final isOut = !item.isService && item.currentStock <= 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          maxWidth: 640,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Thumbnail and Title
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.lightSurfaceContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: imageBytes != null
                        ? Image.memory(
                            imageBytes,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            cacheWidth: (80 * MediaQuery.devicePixelRatioOf(context)).toInt(),
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.inventory_2_outlined,
                              size: 32,
                              color: AppColors.primary,
                            ),
                          )
                        : const Icon(Icons.inventory_2_outlined,
                            size: 36, color: AppColors.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.category,
                                style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11),
                              ),
                            ),
                            if (item.isService)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'SERVICE',
                                  style: TextStyle(
                                      color: Colors.purple,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'SKU: ${item.itemCode.isNotEmpty ? item.itemCode : '—'} • HSN: ${item.hsn.isNotEmpty ? item.hsn : '—'} • Unit: ${item.unit}',
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(height: 1),
              const SizedBox(height: 16),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sales Details Card
                      const Text('Sales & Pricing Details',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.grey.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text('Sales Price',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                                const SizedBox(height: 4),
                                Text(
                                  Formatters.money(item.salesPrice),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 17,
                                      color: AppColors.primary),
                                ),
                              ],
                            ),
                            if (canViewCost)
                              Column(
                                children: [
                                  const Text('Cost / Purchase',
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                  const SizedBox(height: 4),
                                  Text(
                                    Formatters.money(item.purchasePrice),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15),
                                  ),
                                ],
                              ),
                            Column(
                              children: [
                                const Text('Unit of Measure',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                                const SizedBox(height: 4),
                                Text(
                                  item.unit,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Current Stock & Status
                      if (!item.isService) ...[
                        const Text('Inventory & Stock Status',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isOut
                                ? AppColors.error.withValues(alpha: 0.08)
                                : isLowStock
                                    ? AppColors.warning.withValues(alpha: 0.08)
                                    : AppColors.success.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isOut
                                  ? AppColors.error.withValues(alpha: 0.3)
                                  : isLowStock
                                      ? AppColors.warning.withValues(alpha: 0.3)
                                      : AppColors.success
                                          .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isOut
                                        ? 'Out of Stock'
                                        : isLowStock
                                            ? 'Low Stock Warning'
                                            : 'Healthy Stock Level',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isOut
                                          ? AppColors.error
                                          : isLowStock
                                              ? AppColors.warning
                                              : AppColors.success,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Low stock threshold: ${item.lowStockLimit.toStringAsFixed(0)} ${item.unit}',
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                              Text(
                                '${item.currentStock.toStringAsFixed(0)} ${item.unit}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                  color: isOut
                                      ? AppColors.error
                                      : isLowStock
                                          ? AppColors.warning
                                          : AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Action buttons
                      Row(
                        children: [
                          if (!item.isService) ...[
                            Expanded(
                              child: EmpiranButton(
                                label: 'Stock History',
                                icon: Icons.history_rounded,
                                variant: EmpiranButtonVariant.outlined,
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  showStockHistoryDialog(context, item);
                                },
                              ),
                            ),
                            if (canManage) ...[
                              const SizedBox(width: 10),
                              Expanded(
                                child: EmpiranButton(
                                  label: 'Add Stock',
                                  icon: Icons.add_circle_outline_rounded,
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    showStockAdjustDialog(context, item);
                                  },
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                      if (canManage) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: EmpiranButton(
                                label: 'Edit Product Details',
                                icon: Icons.edit_outlined,
                                variant: EmpiranButtonVariant.secondary,
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  showProductDialog(context, item: item);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton(
                              tooltip: 'Delete Product',
                              icon: const Icon(Icons.delete_outline_rounded,
                                  color: AppColors.error),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _confirmDeleteProduct(context, item);
                              },
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addCategoryDialog(BuildContext context) {
    final catController = TextEditingController();
    String? imageBase64;
    Uint8List? imageBytes;
    bool isImageLoading = false;

    Future<void> pickCategoryImage(StateSetter setDialogState) async {
      setDialogState(() => isImageLoading = true);
      try {
        final file = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 50,
          maxWidth: 200,
          maxHeight: 200,
        );
        if (file == null) return;

        final bytes = await file.readAsBytes();
        final b64 = base64Encode(bytes);
        if (context.mounted) {
          setDialogState(() {
            imageBytes = bytes;
            imageBase64 = b64;
          });
        }
      } finally {
        if (context.mounted) {
          setDialogState(() => isImageLoading = false);
        }
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Product Category'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EmpiranTextField(
                  controller: catController,
                  label: 'Category Name',
                  hint: 'e.g. Cables, Switches, LED',
                  isRequired: true,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: AppColors.lightSurfaceContainer,
                        borderRadius: BorderRadius.circular(AppRadii.medium),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: isImageLoading
                          ? const Center(child: CircularProgressIndicator())
                          : imageBytes == null
                              ? const Icon(
                                  Icons.category_outlined,
                                  color: AppColors.primary,
                                )
                              : Image.memory(
                                  imageBytes!,
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EmpiranButton(
                        label: imageBytes == null
                            ? 'Add Category Image'
                            : 'Change Category Image',
                        icon: Icons.photo_library_outlined,
                        variant: EmpiranButtonVariant.outlined,
                        height: 40,
                        onPressed: isImageLoading ? null : () => pickCategoryImage(setDialogState),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            EmpiranButton(
              label: 'Save Category',
              onPressed: () {
                final name = catController.text.trim();
                if (name.isNotEmpty) {
                  context.read<SettingsBloc>().add(
                        AddCategoryRequested(
                          name,
                          imageBase64: imageBase64,
                        ),
                      );
                }
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    ).then((_) => catController.dispose());
  }

  void _editCategoryDialog(BuildContext context, String category) {
    if (category == 'All') return;
    final catController = TextEditingController(text: category);
    final settingsBloc = context.read<SettingsBloc>();
    final productsBloc = context.read<ProductsBloc>();
    final messenger = ScaffoldMessenger.of(context);
    String? imageBase64 = _categoryImages[category];
    Uint8List? imageBytes = ImageHelper.decodeBase64(imageBase64);
    bool imageModified = false;
    bool isImageLoading = false;

    Future<void> pickCategoryImage(StateSetter setDialogState) async {
      setDialogState(() => isImageLoading = true);
      try {
        final file = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 50,
          maxWidth: 200,
          maxHeight: 200,
        );
        if (file == null) return;

        final bytes = await file.readAsBytes();
        final b64 = base64Encode(bytes);
        if (context.mounted) {
          setDialogState(() {
            imageBytes = bytes;
            imageBase64 = b64;
            imageModified = true;
          });
        }
      } finally {
        if (context.mounted) {
          setDialogState(() => isImageLoading = false);
        }
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Edit Category: $category',
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EmpiranTextField(
                  controller: catController,
                  label: 'Category Name',
                  hint: 'e.g. Cables, Switches, LED',
                  isRequired: true,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: AppColors.lightSurfaceContainer,
                        borderRadius: BorderRadius.circular(AppRadii.medium),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: isImageLoading
                          ? const Center(child: CircularProgressIndicator())
                          : imageBytes == null
                              ? const Icon(
                                  Icons.category_outlined,
                                  color: AppColors.primary,
                                )
                              : Image.memory(
                                  imageBytes!,
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          EmpiranButton(
                            label: imageBytes == null
                                ? 'Upload Category Image'
                                : 'Change Category Image',
                            icon: Icons.photo_library_outlined,
                            variant: EmpiranButtonVariant.outlined,
                            height: 38,
                            onPressed: isImageLoading ? null : () => pickCategoryImage(setDialogState),
                          ),
                          if (imageBytes != null) ...[
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () {
                                setDialogState(() {
                                  imageBytes = null;
                                  imageBase64 = '';
                                  imageModified = true;
                                });
                              },
                              child: const Text(
                                'Remove Image',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.error,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    title: const Text('Delete Category'),
                    content: Text(
                        'Are you sure you want to delete category "$category"? Products in this category will remain intact.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dCtx, false),
                          child: const Text('Cancel')),
                      TextButton(
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.error),
                        onPressed: () => Navigator.pop(dCtx, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirm == true && mounted) {
                  settingsBloc.add(DeleteCategoryRequested(category));
                  if (_selectedCategory == category) {
                    setState(() => _selectedCategory = 'All');
                  }
                  await _loadCategoryImages();
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Delete Category'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            EmpiranButton(
              label: 'Save Changes',
              icon: Icons.check,
              onPressed: () async {
                final newName = catController.text.trim();
                if (newName.isEmpty) return;

                settingsBloc.add(
                  UpdateCategoryRequested(
                    oldName: category,
                    newName: newName,
                    imageBase64:
                        imageModified ? imageBase64 : _categoryImages[category],
                  ),
                );

                // Update catalog items if category was renamed
                if (category.toLowerCase() != newName.toLowerCase()) {
                  final pState = productsBloc.state;
                  if (pState is ProductsLoaded) {
                    final repo = productsBloc.productsRepository;
                    for (final item in pState.items) {
                      if (item.category.trim().toLowerCase() ==
                          category.toLowerCase()) {
                        item.category = newName;
                        try {
                          await repo.saveProduct(item);
                        } catch (_) {}
                      }
                    }
                    if (mounted) {
                      productsBloc.add(const LoadProductsRequested());
                    }
                  }
                  if (_selectedCategory == category) {
                    setState(() => _selectedCategory = newName);
                  }
                }

                await _loadCategoryImages();
                if (ctx.mounted) Navigator.pop(ctx);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Category "$newName" updated successfully.'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ).then((_) => catController.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final role =
        authState is AuthAuthenticated ? authState.user.role : 'Biller';
    final canManage = PermissionService.canManageProducts(role);
    final canViewCost = PermissionService.canViewCostPrice(role);

    final settingsState = context.watch<SettingsBloc>().state;
    final categories = settingsState is SettingsLoaded
        ? ['All', ...settingsState.categories]
        : ['All', 'General'];

    return BlocListener<SettingsBloc, SettingsState>(
        listener: (context, state) {
      if (state is SettingsLoaded) {
        _loadCategoryImages();
      }
    }, child: BlocBuilder<ProductsBloc, ProductsState>(
      builder: (context, state) {
        if (state is ProductsLoading || state is ProductsInitial) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is ProductsFailure) {
          return Center(
              child: Text('Error loading products: ${state.message}'));
        }

        final loaded = state as ProductsLoaded;
        var displayItems = loaded.filteredItems;

        if (_stockFilter == 'In Stock') {
          displayItems = displayItems
              .where((i) => !i.isService && i.currentStock > i.lowStockLimit)
              .toList();
        } else if (_stockFilter == 'Low Stock') {
          displayItems = displayItems
              .where((i) =>
                  !i.isService &&
                  i.currentStock > 0 &&
                  i.currentStock <= i.lowStockLimit)
              .toList();
        } else if (_stockFilter == 'Out of Stock') {
          displayItems = displayItems
              .where((i) => !i.isService && i.currentStock <= 0)
              .toList();
        }

        return LayoutBuilder(
          builder: (context, pageConstraints) {
            final isCompact = pageConstraints.maxWidth < 650;

            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 14 : 24,
                vertical: isCompact ? 14 : 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row
                  if (isCompact) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Products & Inventory',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${loaded.items.length} items catalogued across ${categories.length - 1} categories',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.lightTextSecondary),
                        ),
                      ],
                    ),
                    if (canManage) ...[
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            EmpiranButton(
                              label: 'Add Category',
                              icon: Icons.category_outlined,
                              variant: EmpiranButtonVariant.outlined,
                              onPressed: () => _addCategoryDialog(context),
                            ),
                            const SizedBox(width: 10),
                            EmpiranButton(
                              label: 'Create Product',
                              icon: Icons.add_rounded,
                              onPressed: () => showProductDialog(
                                context,
                                initialCategory: _selectedCategory == 'All'
                                    ? null
                                    : _selectedCategory,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ] else ...[
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
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${loaded.items.length} items catalogued across ${categories.length - 1} categories',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.lightTextSecondary),
                            ),
                          ],
                        ),
                        if (canManage)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              EmpiranButton(
                                label: 'Add Category',
                                icon: Icons.category_outlined,
                                variant: EmpiranButtonVariant.outlined,
                                onPressed: () => _addCategoryDialog(context),
                              ),
                              if (_selectedCategory != 'All')
                                EmpiranButton(
                                  label: 'Edit "$_selectedCategory"',
                                  icon: Icons.edit_outlined,
                                  variant: EmpiranButtonVariant.outlined,
                                  onPressed: () => _editCategoryDialog(
                                      context, _selectedCategory),
                                ),
                              EmpiranButton(
                                label: 'Create Product',
                                icon: Icons.add_rounded,
                                onPressed: () => showProductDialog(
                                  context,
                                  initialCategory: _selectedCategory == 'All'
                                      ? null
                                      : _selectedCategory,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Instamart-Style Category Visual Cards
                  SizedBox(
                    height: 112,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, idx) {
                        final cat = categories[idx];
                        final count = cat == 'All'
                            ? loaded.items.length
                            : loaded.items
                                .where((x) =>
                                    x.category.toLowerCase() ==
                                    cat.toLowerCase())
                                .length;
                        return _buildCategoryCard(
                          cat,
                          count,
                          _selectedCategory == cat,
                          canManage,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Search and Filter Bar
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 550;
                      final searchField = EmpiranTextField(
                        controller: _searchController,
                        label: '',
                        hint: 'Search by item name, SKU barcode or HSN...',
                        prefixIcon: Icons.search_rounded,
                        onChanged: (_) => _onFilterChanged(),
                      );

                      final stockDropdown = SizedBox(
                        width: isNarrow ? double.infinity : 180,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _stockFilter,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'All', child: Text('All Stock Levels')),
                            DropdownMenuItem(
                                value: 'In Stock',
                                child: Text('In Stock Only')),
                            DropdownMenuItem(
                                value: 'Low Stock',
                                child: Text('Low Stock Alerts')),
                            DropdownMenuItem(
                                value: 'Out of Stock',
                                child: Text('Out of Stock')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _stockFilter = v);
                          },
                        ),
                      );

                      if (isNarrow) {
                        return Column(
                          children: [
                            searchField,
                            const SizedBox(height: 10),
                            stockDropdown,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: searchField),
                          const SizedBox(width: 12),
                          stockDropdown,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Products Grid / List
                  Expanded(
                    child: displayItems.isEmpty
                        ? EmpiranEmptyState(
                            title: 'No products found',
                            description:
                                'Try adjusting your search criteria or category filter.',
                            icon: Icons.inventory_2_outlined,
                            actionLabel: canManage ? 'Add Product' : null,
                            onAction: canManage
                                ? () => showProductDialog(context)
                                : null,
                          )
                        : RefreshIndicator(
                            onRefresh: () async {
                              context
                                  .read<ProductsBloc>()
                                  .add(const LoadProductsRequested());
                              await Future.delayed(
                                  const Duration(milliseconds: 500));
                            },
                            child: ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: displayItems.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                final item = displayItems[i];
                                final isLowStock = !item.isService &&
                                    item.currentStock <= item.lowStockLimit;
                                final isOut =
                                    !item.isService && item.currentStock <= 0;

                                return LayoutBuilder(
                                  builder: (context, cardConstraints) {
                                    final isCardCompact =
                                        cardConstraints.maxWidth < 620;

                                    final titleRow = Wrap(
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        Text(
                                          item.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            item.category,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        if (item.isService)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.purple
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: const Text('SERVICE',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.purple,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ),
                                      ],
                                    );

                                    final thumbnail = _buildProductThumbnail(
                                      item,
                                      size: isCardCompact ? 54 : 60,
                                    );

                                    final stockBadge = !item.isService
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isOut
                                                  ? AppColors.error
                                                      .withValues(alpha: 0.12)
                                                  : isLowStock
                                                      ? AppColors.warning
                                                          .withValues(
                                                              alpha: 0.12)
                                                      : AppColors.success
                                                          .withValues(
                                                              alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      AppRadii.small),
                                            ),
                                            child: Text(
                                              '${item.currentStock.toStringAsFixed(0)} ${item.unit}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: isOut
                                                    ? AppColors.error
                                                    : isLowStock
                                                        ? AppColors.warning
                                                        : AppColors.success,
                                              ),
                                            ),
                                          )
                                        : const SizedBox.shrink();

                                    final actions = [
                                      if (!item.isService) ...[
                                        IconButton(
                                          tooltip: 'Stock History',
                                          icon: const Icon(
                                              Icons.history_rounded,
                                              size: 19),
                                          onPressed: () =>
                                              showStockHistoryDialog(
                                                  context, item),
                                        ),
                                        if (canManage)
                                          IconButton(
                                            tooltip: 'Add Stock',
                                            icon: const Icon(
                                                Icons.sync_alt_rounded,
                                                size: 19),
                                            onPressed: () =>
                                                showStockAdjustDialog(
                                                    context, item),
                                          ),
                                      ],
                                      if (canManage) ...[
                                        IconButton(
                                          tooltip: 'Edit Product',
                                          icon: const Icon(Icons.edit_outlined,
                                              size: 19),
                                          onPressed: () => showProductDialog(
                                              context,
                                              item: item),
                                        ),
                                        IconButton(
                                          tooltip: 'Delete Product',
                                          icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              size: 19,
                                              color: AppColors.error),
                                          onPressed: () =>
                                              _confirmDeleteProduct(
                                                  context, item),
                                        ),
                                      ],
                                    ];

                                    if (isCardCompact) {
                                      return EmpiranCard(
                                        padding: EdgeInsets.zero,
                                        child: InkWell(
                                          onTap: () => _showProductDetailsSheet(
                                              context,
                                              item,
                                              canManage,
                                              canViewCost),
                                          borderRadius: BorderRadius.circular(
                                              AppRadii.medium),
                                          child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    thumbnail,
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          titleRow,
                                                          const SizedBox(
                                                              height: 3),
                                                          Text(
                                                            'SKU: ${item.itemCode.isNotEmpty ? item.itemCode : '—'} • ${item.unit}',
                                                            style:
                                                                const TextStyle(
                                                                    color: Colors
                                                                        .grey,
                                                                    fontSize:
                                                                        11),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .end,
                                                      children: [
                                                        Text(
                                                          Formatters.money(
                                                              item.salesPrice),
                                                          style: const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
                                                              fontSize: 15,
                                                              color: AppColors
                                                                  .primary),
                                                        ),
                                                        if (canViewCost)
                                                          Text(
                                                            'Cost: ${Formatters.money(item.purchasePrice)}',
                                                            style:
                                                                const TextStyle(
                                                                    fontSize:
                                                                        10,
                                                                    color: Colors
                                                                        .grey),
                                                          ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                const Divider(height: 1),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    stockBadge,
                                                    Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: actions,
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }

                                    return EmpiranCard(
                                      padding: EdgeInsets.zero,
                                      child: InkWell(
                                        onTap: () => _showProductDetailsSheet(
                                            context,
                                            item,
                                            canManage,
                                            canViewCost),
                                        borderRadius: BorderRadius.circular(
                                            AppRadii.medium),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Row(
                                            children: [
                                              thumbnail,
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    titleRow,
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      'SKU: ${item.itemCode.isNotEmpty ? item.itemCode : '—'} • HSN: ${item.hsn.isNotEmpty ? item.hsn : '—'} • Unit: ${item.unit}',
                                                      style: const TextStyle(
                                                          color: Colors.grey,
                                                          fontSize: 12),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    Formatters.money(
                                                        item.salesPrice),
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        fontSize: 16,
                                                        color:
                                                            AppColors.primary),
                                                  ),
                                                  if (canViewCost)
                                                    Text(
                                                      'Cost: ${Formatters.money(item.purchasePrice)}',
                                                      style: const TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.grey),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(width: 14),
                                              if (!item.isService) ...[
                                                stockBadge,
                                                const SizedBox(width: 6),
                                              ],
                                              ...actions,
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ));
  }
}
