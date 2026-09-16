import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:empiran/core/services/permission_service.dart';
import 'package:empiran/core/theme/app_theme.dart';
import 'package:empiran/core/utils/formatters.dart';
import 'package:empiran/core/widgets/empiran_components.dart';
import 'package:empiran/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:empiran/features/auth/presentation/bloc/auth_state.dart';
import 'package:empiran/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:empiran/features/settings/presentation/bloc/settings_event.dart';
import 'package:empiran/features/settings/presentation/bloc/settings_state.dart';
import '../bloc/products_bloc.dart';
import '../bloc/products_event.dart';
import '../bloc/products_state.dart';
import '../widgets/product_dialog.dart';
import '../widgets/stock_adjust_dialog.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _stockFilter = 'All'; // 'All', 'In Stock', 'Low Stock', 'Out of Stock'

  @override
  void initState() {
    super.initState();
    context.read<ProductsBloc>().add(const LoadProductsRequested());
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

  void _addCategoryDialog(BuildContext context) {
    final catController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Product Category'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
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
            onPressed: () {
              if (catController.text.trim().isNotEmpty) {
                context.read<SettingsBloc>().add(AddCategoryRequested(catController.text.trim()));
              }
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    ).then((_) => catController.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final role = authState is AuthAuthenticated ? authState.user.role : 'Biller';
    final canManage = PermissionService.canManageProducts(role);
    final canViewCost = PermissionService.canViewCostPrice(role);

    final settingsState = context.watch<SettingsBloc>().state;
    final categories = settingsState is SettingsLoaded
        ? ['All', ...settingsState.categories]
        : ['All', 'General'];

    return BlocBuilder<ProductsBloc, ProductsState>(
      builder: (context, state) {
        if (state is ProductsLoading || state is ProductsInitial) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is ProductsFailure) {
          return Center(child: Text('Error loading products: ${state.message}'));
        }

        final loaded = state as ProductsLoaded;
        var displayItems = loaded.filteredItems;

        if (_stockFilter == 'In Stock') {
          displayItems = displayItems.where((i) => !i.isService && i.currentStock > i.lowStockLimit).toList();
        } else if (_stockFilter == 'Low Stock') {
          displayItems = displayItems.where((i) => !i.isService && i.currentStock > 0 && i.currentStock <= i.lowStockLimit).toList();
        } else if (_stockFilter == 'Out of Stock') {
          displayItems = displayItems.where((i) => !i.isService && i.currentStock <= 0).toList();
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
                          style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
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
                                initialCategory: _selectedCategory == 'All' ? null : _selectedCategory,
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
                              style: const TextStyle(fontSize: 13, color: AppColors.lightTextSecondary),
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
                                onPressed: () => _addCategoryDialog(context),
                              ),
                              const SizedBox(width: 10),
                              EmpiranButton(
                                label: 'Create Product',
                                icon: Icons.add_rounded,
                                onPressed: () => showProductDialog(
                                  context,
                                  initialCategory: _selectedCategory == 'All' ? null : _selectedCategory,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Categories Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: categories.map((cat) {
                        final isSelected = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(cat),
                            selected: isSelected,
                            onSelected: (_) {
                              setState(() => _selectedCategory = cat);
                              _onFilterChanged();
                            },
                          ),
                        );
                      }).toList(),
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
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'All', child: Text('All Stock Levels')),
                            DropdownMenuItem(value: 'In Stock', child: Text('In Stock Only')),
                            DropdownMenuItem(value: 'Low Stock', child: Text('Low Stock Alerts')),
                            DropdownMenuItem(value: 'Out of Stock', child: Text('Out of Stock')),
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
                            description: 'Try adjusting your search criteria or category filter.',
                            icon: Icons.inventory_2_outlined,
                            actionLabel: canManage ? 'Add Product' : null,
                            onAction: canManage ? () => showProductDialog(context) : null,
                          )
                        : ListView.separated(
                            itemCount: displayItems.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final item = displayItems[i];
                              final isLowStock = !item.isService && item.currentStock <= item.lowStockLimit;
                              final isOut = !item.isService && item.currentStock <= 0;

                              return LayoutBuilder(
                                builder: (context, cardConstraints) {
                                  final isCardCompact = cardConstraints.maxWidth < 620;

                                  final titleRow = Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          item.name,
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          item.category,
                                          style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      if (item.isService) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.purple.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text('SERVICE', style: TextStyle(fontSize: 10, color: Colors.purple, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ],
                                  );

                                  final thumbnail = Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: AppColors.lightSurfaceContainer,
                                      borderRadius: BorderRadius.circular(AppRadii.medium),
                                    ),
                                    child: item.image != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(AppRadii.medium),
                                            child: Image.memory(
                                              base64Decode(item.image!.contains(',') ? item.image!.split(',').last : item.image!),
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : const Icon(Icons.inventory_2_outlined, color: AppColors.primary),
                                  );

                                  final stockBadge = !item.isService
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isOut
                                                ? AppColors.error.withValues(alpha: 0.12)
                                                : isLowStock
                                                    ? AppColors.warning.withValues(alpha: 0.12)
                                                    : AppColors.success.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(AppRadii.small),
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

                                  if (isCardCompact) {
                                    return EmpiranCard(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              thumbnail,
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    titleRow,
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      'SKU: ${item.itemCode.isNotEmpty ? item.itemCode : '—'} • ${item.unit}',
                                                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    Formatters.money(item.salesPrice),
                                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.primary),
                                                  ),
                                                  if (canViewCost)
                                                    Text(
                                                      'Cost: ${Formatters.money(item.purchasePrice)}',
                                                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          const Divider(height: 1),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              stockBadge,
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (!item.isService)
                                                    IconButton(
                                                      tooltip: 'Adjust Stock',
                                                      icon: const Icon(Icons.sync_alt_rounded, size: 18),
                                                      onPressed: () => showStockAdjustDialog(context, item),
                                                    ),
                                                  if (canManage)
                                                    IconButton(
                                                      tooltip: 'Edit Product',
                                                      icon: const Icon(Icons.edit_outlined, size: 18),
                                                      onPressed: () => showProductDialog(context, item: item),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  return EmpiranCard(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        thumbnail,
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              titleRow,
                                              const SizedBox(height: 4),
                                              Text(
                                                'SKU: ${item.itemCode.isNotEmpty ? item.itemCode : '—'} • HSN: ${item.hsn.isNotEmpty ? item.hsn : '—'} • Unit: ${item.unit}',
                                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              Formatters.money(item.salesPrice),
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.primary),
                                            ),
                                            if (canViewCost)
                                              Text(
                                                'Cost: ${Formatters.money(item.purchasePrice)}',
                                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(width: 16),
                                        if (!item.isService) ...[
                                          stockBadge,
                                          const SizedBox(width: 8),
                                          IconButton(
                                            tooltip: 'Adjust Stock',
                                            icon: const Icon(Icons.sync_alt_rounded, size: 20),
                                            onPressed: () => showStockAdjustDialog(context, item),
                                          ),
                                        ],
                                        if (canManage)
                                          IconButton(
                                            tooltip: 'Edit Product',
                                            icon: const Icon(Icons.edit_outlined, size: 20),
                                            onPressed: () => showProductDialog(context, item: item),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
