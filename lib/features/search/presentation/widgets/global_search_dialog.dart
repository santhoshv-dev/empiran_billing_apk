import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:empiran/core/routing/app_routes.dart';
import 'package:empiran/core/theme/app_theme.dart';
import 'package:empiran/features/search/models/search_models.dart';
import 'package:empiran/features/products/presentation/bloc/products_bloc.dart';
import 'package:empiran/features/products/presentation/bloc/products_state.dart';
import 'package:empiran/features/products/presentation/widgets/product_dialog.dart';
import 'package:empiran/models.dart';
import 'package:empiran/features/invoices/presentation/bloc/invoices_bloc.dart';
import 'package:empiran/features/invoices/presentation/bloc/invoices_state.dart';
import 'package:empiran/features/parties/presentation/bloc/parties_bloc.dart';
import 'package:empiran/features/parties/presentation/bloc/parties_state.dart';
import 'package:empiran/features/parties/presentation/widgets/party_dialog.dart';
import 'package:empiran/features/search/data/local_search_service.dart';

void showGlobalSearchDialog(
  BuildContext context, {
  void Function(ShellRoute route)? onNavigate,
}) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: context.read<ProductsBloc>()),
        BlocProvider.value(value: context.read<PartiesBloc>()),
        BlocProvider.value(value: context.read<InvoicesBloc>()),
      ],
      child: GlobalSearchDialog(onNavigate: onNavigate),
    ),
  );
}

class GlobalSearchDialog extends StatefulWidget {
  const GlobalSearchDialog({super.key, this.onNavigate});
  final void Function(ShellRoute route)? onNavigate;

  @override
  State<GlobalSearchDialog> createState() => _GlobalSearchDialogState();
}

class _GlobalSearchDialogState extends State<GlobalSearchDialog> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  Timer? _debounceTimer;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String _selectedType = 'all';
  int _page = 1;
  bool _hasMore = false;
  SearchCounts _counts = const SearchCounts();
  List<SearchResultItem> _results = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 80) {
      if (!_isLoading && !_isLoadingMore && _hasMore) {
        _loadMore();
      }
    }
  }

  void _onQueryChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _counts = const SearchCounts();
        _isLoading = false;
        _isLoadingMore = false;
        _hasMore = false;
        _errorMessage = null;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 280), () {
      _performSearch(resetPage: true);
    });
  }

  Future<void> _performSearch({bool resetPage = false}) async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    if (resetPage) {
      setState(() {
        _page = 1;
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      List<Item>? activeItems;
      List<Party>? activeParties;
      List<BusinessTransaction>? activeTransactions;

      try {
        final pState = context.read<ProductsBloc>().state;
        if (pState is ProductsLoaded) activeItems = pState.items;
      } catch (_) {}

      try {
        final partyState = context.read<PartiesBloc>().state;
        if (partyState is PartiesLoaded) activeParties = partyState.parties;
      } catch (_) {}

      try {
        final invState = context.read<InvoicesBloc>().state;
        if (invState is InvoicesLoaded)
          activeTransactions = invState.transactions;
      } catch (_) {}

      final searchResponse = await LocalSearchService.search(
        query: query,
        type: _selectedType,
        page: _page,
        pageSize: 20,
        activeItems: activeItems,
        activeParties: activeParties,
        activeTransactions: activeTransactions,
      );

      if (mounted) {
        setState(() {
          if (resetPage) {
            _results = searchResponse.results;
          } else {
            _results.addAll(searchResponse.results);
          }
          _counts = searchResponse.counts;
          _hasMore = searchResponse.hasMore;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _errorMessage = 'Search failed: ${e.toString().split('\n').first}';
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() {
      _isLoadingMore = true;
      _page += 1;
    });
    await _performSearch(resetPage: false);
  }

  void _selectType(String type) {
    if (_selectedType == type) return;
    setState(() {
      _selectedType = type;
    });
    _performSearch(resetPage: true);
  }

  void _handleResultClick(SearchResultItem item) {
    Navigator.of(context).pop();

    switch (item.type) {
      case 'product':
        try {
          final productsState = context.read<ProductsBloc>().state;
          if (productsState is ProductsLoaded) {
            final found = productsState.items.where((i) => i.id == item.id);
            if (found.isNotEmpty) {
              showProductDialog(context, item: found.first);
              return;
            }
          }
        } catch (_) {}
        widget.onNavigate?.call(ShellRoute.products);
        break;

      case 'customer':
      case 'supplier':
        try {
          final partiesState = context.read<PartiesBloc>().state;
          if (partiesState is PartiesLoaded) {
            final found = partiesState.parties.where((p) => p.id == item.id);
            if (found.isNotEmpty) {
              showPartyDialog(context, party: found.first);
              return;
            }
          }
        } catch (_) {}
        widget.onNavigate?.call(ShellRoute.parties);
        break;

      case 'quotation':
        widget.onNavigate?.call(ShellRoute.quotations);
        break;

      case 'invoice':
        widget.onNavigate?.call(ShellRoute.invoices);
        break;

      case 'category':
        widget.onNavigate?.call(ShellRoute.products);
        break;

      case 'staff':
        widget.onNavigate?.call(ShellRoute.settings);
        break;

      case 'expense':
        widget.onNavigate?.call(ShellRoute.dashboard);
        break;

      default:
        break;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'product':
        return Icons.inventory_2_outlined;
      case 'customer':
        return Icons.person_outline_rounded;
      case 'supplier':
        return Icons.local_shipping_outlined;
      case 'invoice':
        return Icons.receipt_long_outlined;
      case 'quotation':
        return Icons.request_quote_outlined;
      case 'category':
        return Icons.category_outlined;
      case 'staff':
        return Icons.badge_outlined;
      case 'expense':
        return Icons.payments_outlined;
      default:
        return Icons.search_rounded;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'product':
        return const Color(0xFF1976D2);
      case 'customer':
        return const Color(0xFF00897B);
      case 'supplier':
        return const Color(0xFFF57C00);
      case 'invoice':
        return const Color(0xFF7B1FA2);
      case 'quotation':
        return const Color(0xFF5E35B1);
      case 'category':
        return const Color(0xFF0288D1);
      case 'staff':
        return const Color(0xFFD81B60);
      case 'expense':
        return const Color(0xFFE53935);
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final isCompact = screenSize.width < 600;
    final dialogWidth = isCompact ? screenSize.width - 24 : 680.0;
    final dialogHeight = screenSize.height * (isCompact ? 0.9 : 0.84);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 32,
        vertical: isCompact ? 16 : 40,
      ),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Search Input Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.black12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded,
                      size: 24, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      autofocus: true,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500),
                      decoration: const InputDecoration(
                        hintText:
                            'Search products, customers, invoices, codes...',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      onChanged: _onQueryChanged,
                    ),
                  ),
                  if (_isLoading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon:
                          const Icon(Icons.clear, size: 20, color: Colors.grey),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        _searchController.clear();
                        _onQueryChanged('');
                      },
                    ),
                  const SizedBox(width: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'ESC',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),

            // Category Filter Pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  _buildTypeChip('all', 'All', _counts.all),
                  _buildTypeChip('products', 'Products', _counts.products),
                  _buildTypeChip('customers', 'Customers', _counts.customers),
                  _buildTypeChip('suppliers', 'Suppliers', _counts.suppliers),
                  _buildTypeChip('invoices', 'Invoices', _counts.invoices),
                  _buildTypeChip(
                      'categories', 'Categories', _counts.categories),
                  _buildTypeChip('staff', 'Staff', _counts.staff),
                  _buildTypeChip('expenses', 'Expenses', _counts.expenses),
                ],
              ),
            ),

            // Typo-tolerance & Smart Filter hint banner
            if (_searchController.text.trim().isNotEmpty && _results.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: AppColors.primary.withValues(alpha: 0.04),
                child: Row(
                  children: [
                    const Icon(Icons.bolt_rounded,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Space-agnostic & typo-tolerant search active • Found ${_counts.all > 0 ? _counts.all : _results.length} matches',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            // Content Area / Results List
            Expanded(
              child: _buildBody(),
            ),

            // Footer / Shortcuts tip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.black12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Search works with or without spaces (e.g. "iphone15", "9876543210"). Tap an item to open.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_results.isNotEmpty)
                    Text(
                      '${_results.length} loaded',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String type, String label, int count) {
    final isSelected = _selectedType == type;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: isSelected,
        label: Text(
          count > 0 ? '$label ($count)' : label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.lightTextPrimary,
          ),
        ),
        selectedColor: AppColors.primary,
        checkmarkColor: Colors.white,
        backgroundColor: Colors.black.withValues(alpha: 0.04),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        onSelected: (_) => _selectType(type),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _results.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Searching across database...',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
      );
    }

    if (_errorMessage != null && _results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 36, color: AppColors.error),
              const SizedBox(height: 10),
              Text(_errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.error, fontSize: 13)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Try Again'),
                onPressed: () => _performSearch(resetPage: true),
              ),
            ],
          ),
        ),
      );
    }

    if (_searchController.text.trim().isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.manage_search_rounded,
                    size: 32, color: AppColors.primary),
              ),
              const SizedBox(height: 14),
              const Text(
                'Universal Quick Search',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'Search across Products, Customers, Suppliers, Invoices, Staff, and Categories instantly.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildSearchSuggestion('iphone15'),
                  _buildSearchSuggestion('john smith'),
                  _buildSearchSuggestion('9876543210'),
                  _buildSearchSuggestion('INV-001'),
                  _buildSearchSuggestion('Cables'),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off_rounded,
                  size: 42, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                'No results found for "${_searchController.text}"',
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(height: 6),
              const Text(
                'Try searching with partial words, phone digits, or SKU code.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      itemCount: _results.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
      itemBuilder: (context, index) {
        if (index == _results.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final item = _results[index];
        final typeColor = _getTypeColor(item.type);
        final icon = _getTypeIcon(item.type);

        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _handleResultClick(item),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: typeColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (item.amount != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '₹${item.amount!.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.type.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: typeColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          if (item.badge != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.badge!,
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87),
                              ),
                            ),
                          ],
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.subtitle,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: Colors.grey),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchSuggestion(String sample) {
    return ActionChip(
      avatar: const Icon(Icons.history_rounded, size: 14, color: Colors.grey),
      label: Text(sample, style: const TextStyle(fontSize: 12)),
      backgroundColor: Colors.black.withValues(alpha: 0.04),
      onPressed: () {
        _searchController.text = sample;
        _onQueryChanged(sample);
      },
    );
  }
}
