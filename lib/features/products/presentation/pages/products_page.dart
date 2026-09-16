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
            onPressed: () {
              if (catController.text.trim().isNotEmpty) {
                context.read<SettingsBloc>().add(AddCategoryRequested(catController.text.trim()));
              }
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );

    Future.delayed(const Duration(milliseconds: 500), () => catController.dispose());
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

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
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
              Row(
                children: [
                  Expanded(
                    child: EmpiranTextField(
                      controller: _searchController,
                      label: '',
                      hint: 'Search by item name, SKU barcode or HSN...',
                      prefixIcon: Icons.search_rounded,
                      onChanged: (_) => _onFilterChanged(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
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
                  ),
                ],
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

                          return EmpiranCard(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Thumbnail or Icon
                                Container(
                                  width: 52,
                                  height: 52,
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
                                ),
                                const SizedBox(width: 16),

                                // Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            item.name,
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
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
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'SKU: ${item.itemCode.isNotEmpty ? item.itemCode : '—'} • HSN: ${item.hsn.isNotEmpty ? item.hsn : '—'} • Unit: ${item.unit}',
                                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),

                                // Pricing & Stock Info
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
                                const SizedBox(width: 20),

                                // Stock Badge
                                if (!item.isService) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                                        fontSize: 13,
                                        color: isOut
                                            ? AppColors.error
                                            : isLowStock
                                                ? AppColors.warning
                                                : AppColors.success,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
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
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
