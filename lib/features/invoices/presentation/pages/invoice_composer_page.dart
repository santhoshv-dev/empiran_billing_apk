import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:empiran/core/theme/app_theme.dart';
import 'package:empiran/core/utils/formatters.dart';
import 'package:empiran/core/widgets/empiran_components.dart';
import 'package:empiran/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:empiran/features/auth/presentation/bloc/auth_state.dart';
import 'package:empiran/features/parties/presentation/bloc/parties_bloc.dart';
import 'package:empiran/features/parties/presentation/bloc/parties_event.dart';
import 'package:empiran/features/parties/presentation/bloc/parties_state.dart';
import 'package:empiran/features/products/presentation/bloc/products_bloc.dart';
import 'package:empiran/features/products/presentation/bloc/products_event.dart';
import 'package:empiran/features/products/presentation/bloc/products_state.dart';
import 'package:empiran/features/products/presentation/widgets/product_dialog.dart';
import 'package:empiran/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:empiran/features/settings/presentation/bloc/settings_event.dart';
import 'package:empiran/features/settings/presentation/bloc/settings_state.dart';
import 'package:empiran/models.dart';
import '../bloc/invoices_bloc.dart';
import '../bloc/invoices_event.dart';
import '../widgets/document_preview_dialog.dart';

class InvoiceComposerPage extends StatefulWidget {
  final String type; // 'order', 'quotation', 'purchase', etc.
  final BusinessTransaction? source;
  final bool embedded;

  const InvoiceComposerPage({
    super.key,
    this.type = 'order',
    this.source,
    this.embedded = false,
  });

  @override
  State<InvoiceComposerPage> createState() => _InvoiceComposerPageState();
}

class _InvoiceComposerPageState extends State<InvoiceComposerPage> {
  final List<InvoiceLine> _lines = [];
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();
  final _discountController = TextEditingController();

  String? _partyId;
  String _productQuery = '';
  String _category = 'All';
  final String _paymentMode = 'Cash';
  double _discount = 0;
  final double _shipping = 0;
  final double _paid = 0;
  final double _amount = 0;
  bool _isGst = false;
  bool _busy = false;
  final Map<String, String> _dispatch = {};
  String? _error;
  final DateTime _date = DateTime.now();

  // Step state for Quotation Maker flow: Step 0 = Customer details (Optional), Step 1 = Products & Ordering
  late int _quotationStep;
  Map<String, String> _categoryImages = {};

  bool get _isPayment => widget.type.startsWith('payment_');
  double get _subtotal => _isPayment ? _amount : _lines.fold(0, (s, l) => s + l.total);
  double get _effectiveDiscount => _discount;
  double get _taxableAmount => (_subtotal - _effectiveDiscount).clamp(0, double.infinity);
  double get _cgst => _isGst ? _taxableAmount * 0.09 : 0;
  double get _sgst => _isGst ? _taxableAmount * 0.09 : 0;
  double get _total => _taxableAmount + _cgst + _sgst + _shipping;

  @override
  void initState() {
    super.initState();
    // Quotation maker starts at Step 0 (Ask for Customer Name & Mobile Number first)
    _quotationStep = widget.type == 'quotation' ? 0 : 1;

    final s = widget.source;
    if (s != null) {
      _lines.addAll(s.lines.map((l) => InvoiceLine.fromJson(l.toJson())));
      _nameController.text = s.partyName;
      _phoneController.text = s.partyPhone;
      _partyId = s.partyId;
      _discount = s.discount;
      if (_discount > 0) {
        _discountController.text = _discount.toStringAsFixed(0);
      }
      _notesController.text = s.notes;
      _isGst = s.isGst;
      _quotationStep = 1; // If editing or converting existing source, jump straight to products
    }

    _loadCategoryImages();
  }

  Future<void> _loadCategoryImages() async {
    try {
      final images = await context.read<SettingsBloc>().settingsRepository.loadCategoryImages();
      if (mounted) {
        setState(() => _categoryImages = images);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  Uint8List? _decodeImage(String? img) {
    if (img == null || img.trim().isEmpty) return null;
    try {
      final payload = img.contains(',') ? img.split(',').last : img;
      return base64Decode(payload);
    } catch (_) {
      return null;
    }
  }

  int _getItemQtyInCart(String itemId) {
    final line = _lines.where((l) => l.itemId == itemId).firstOrNull;
    return line?.quantity.toInt() ?? 0;
  }

  void _add(Item item) {
    setState(() {
      final index = _lines.indexWhere((l) => l.itemId == item.id);
      if (index >= 0) {
        _lines[index].quantity++;
      } else {
        _lines.add(
          InvoiceLine(
            itemId: item.id,
            name: item.name,
            quantity: 1,
            unit: item.unit,
            price: widget.type.startsWith('purchase') ? item.purchasePrice : item.salesPrice,
            hsn: item.hsn,
          ),
        );
      }
    });
  }

  void _increment(Item item) => _add(item);

  void _decrement(Item item) {
    setState(() {
      final index = _lines.indexWhere((l) => l.itemId == item.id);
      if (index >= 0) {
        if (_lines[index].quantity > 1) {
          _lines[index].quantity--;
        } else {
          _lines.removeAt(index);
        }
      }
    });
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (_isPayment && (_partyId == null || _amount <= 0)) {
        throw ArgumentError('Select a party and enter an amount greater than zero.');
      }
      if (!_isPayment && _lines.isEmpty) {
        throw ArgumentError('Add at least one product to continue.');
      }

      final settingsState = context.read<SettingsBloc>().state;
      final settings = settingsState is SettingsLoaded ? settingsState.invoiceSettings : InvoiceSettings();

      final invoicesRepo = context.read<InvoicesBloc>().invoicesRepository;
      final source = widget.source;
      final number = source?.number ?? invoicesRepo.generateNumber(widget.type, _isGst, settings);
      if (source == null) {
        context.read<SettingsBloc>().add(SaveInvoiceSettingsRequested(settings));
      }

      // Auto-save customer details in Customer Section (Requirement 8)
      final custName = _nameController.text.trim();
      final custPhone = _phoneController.text.trim();
      if (custName.isNotEmpty && _partyId == null) {
        final partyState = context.read<PartiesBloc>().state;
        final existingParties = partyState is PartiesLoaded ? partyState.parties : <Party>[];
        final match = existingParties.where((p) =>
            p.name.toLowerCase() == custName.toLowerCase() ||
            (custPhone.isNotEmpty && p.phone == custPhone)).firstOrNull;
        if (match != null) {
          _partyId = match.id;
        } else {
          final newId = DateTime.now().microsecondsSinceEpoch.toString();
          final newParty = Party(
            id: newId,
            name: custName,
            phone: custPhone,
            type: 'Customer',
          );
          _partyId = newId;
          context.read<PartiesBloc>().add(SavePartyRequested(newParty));
        }
      }

      // Read current logged-in staff/admin name
      final authState = context.read<AuthBloc>().state;
      final staffName = authState is AuthAuthenticated
          ? (authState.user.name.isNotEmpty ? authState.user.name : authState.user.username)
          : 'Admin';

      final txn = BusinessTransaction(
        id: source?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        type: widget.type,
        number: number,
        date: _date,
        lines: _isPayment
            ? [
                InvoiceLine(
                  itemId: '',
                  name: widget.type == 'payment_in' ? 'Payment In' : 'Payment Out',
                  quantity: 1,
                  unit: '',
                  price: _amount,
                ),
              ]
            : _lines,
        partyId: _partyId,
        partyName: custName,
        partyPhone: custPhone,
        isGst: _isGst,
        paid: _isPayment ? 0 : _paid,
        paymentMode: _paymentMode,
        status: _isPayment
            ? 'Completed'
            : (_paid >= _total ? 'Paid' : (_paid > 0 ? 'Partial' : 'Unpaid')),
        dispatch: _dispatch,
        discount: _effectiveDiscount,
        shipping: _shipping,
        notes: _notesController.text,
        referredBy: source?.referredBy ?? staffName,
        convertedFrom: source?.type == 'quotation' && widget.type != 'quotation'
            ? source!.id
            : source?.convertedFrom,
      );

      // If creating an order, deduct stock for the ordered products (Requirement 3)
      if (widget.type == 'order') {
        for (final line in _lines) {
          if (line.itemId.isNotEmpty) {
            try {
              await context.read<ProductsBloc>().productsRepository.adjustStockById(
                    line.itemId,
                    -line.quantity,
                    reason: 'Order placed: #$number',
                  );
            } catch (_) {}
          }
        }
        if (mounted) {
          context.read<ProductsBloc>().add(const LoadProductsRequested());
        }
      }

      if (mounted) {
        context.read<InvoicesBloc>().add(SaveTransactionRequested(txn));
      }

      if (mounted) {
        if (widget.embedded) {
          showDocumentPreviewDialog(context, txn);
          setState(() {
            _lines.clear();
            _nameController.clear();
            _phoneController.clear();
            _discountController.clear();
            _discount = 0;
            _partyId = null;
            if (widget.type == 'quotation') _quotationStep = 0;
          });
        } else {
          Navigator.pop(context, txn);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Instamart-Style Category Card
  Widget _buildCategoryCard(String cat, int count, bool isSelected) {
    final imageBase64 = _categoryImages[cat];
    final imageBytes = _decodeImage(imageBase64);

    return InkWell(
      onTap: () => setState(() => _category = cat),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 96,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.withValues(alpha: 0.2),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.lightSurfaceContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: imageBytes != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        imageBytes,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        errorBuilder: (_, __, ___) => Icon(
                          cat == 'All' ? Icons.apps_rounded : Icons.category_outlined,
                          color: isSelected ? AppColors.primary : Colors.grey,
                          size: 22,
                        ),
                      ),
                    )
                  : Icon(
                      cat == 'All' ? Icons.apps_rounded : Icons.category_outlined,
                      color: isSelected ? AppColors.primary : Colors.grey,
                      size: 22,
                    ),
            ),
            const SizedBox(height: 6),
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
            if (count >= 0)
              Text(
                '$count items',
                style: const TextStyle(fontSize: 9, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  // Quotation Step 0: Customer Information Prompt (Requirement 1)
  Widget _buildQuotationCustomerStep(List<Party> parties) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: EmpiranCard(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.request_quote_rounded, color: AppColors.primary, size: 28),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quotation Maker',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Step 1 of 2: Customer Details (Optional)',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Customer Name and Mobile Number are optional. You can enter them now or continue directly to browse products.',
                  style: TextStyle(fontSize: 13, color: AppColors.lightTextSecondary),
                ),
                const SizedBox(height: 20),
                if (parties.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _partyId,
                    decoration: const InputDecoration(
                      labelText: 'Select Registered Customer (Optional)',
                      prefixIcon: Icon(Icons.people_outline, size: 20),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Manual / Walk-in Customer')),
                      ...parties.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.name} (${p.phone})'))),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _partyId = v;
                        if (v != null) {
                          final p = parties.firstWhere((el) => el.id == v);
                          _nameController.text = p.name;
                          _phoneController.text = p.phone;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                ],
                EmpiranTextField(
                  controller: _nameController,
                  label: 'Customer Name (Optional)',
                  hint: 'e.g. John Doe / Walk-in',
                  prefixIcon: Icons.person_outline,
                ),
                const SizedBox(height: 14),
                EmpiranTextField(
                  controller: _phoneController,
                  label: 'Mobile Number (Optional)',
                  hint: 'e.g. 9876543210',
                  prefixIcon: Icons.phone_outlined,
                  isNumber: true,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          setState(() => _quotationStep = 1);
                        },
                        child: const Text('Skip Customer'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EmpiranButton(
                        label: 'Continue to Products',
                        icon: Icons.arrow_forward_rounded,
                        onPressed: () {
                          setState(() => _quotationStep = 1);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isQuotation = widget.type == 'quotation';
    final title = isQuotation
        ? 'Quotation Maker'
        : widget.type == 'order'
            ? 'Create Order / Invoice'
            : 'Create ${widget.type.replaceAll('_', ' ').toUpperCase()}';

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(title),
              actions: [
                if (isQuotation && _quotationStep == 1)
                  TextButton.icon(
                    icon: const Icon(Icons.person_outline, size: 18),
                    label: const Text('Edit Customer'),
                    onPressed: () => setState(() => _quotationStep = 0),
                  ),
              ],
            ),
      body: BlocBuilder<PartiesBloc, PartiesState>(
        builder: (context, partyState) {
          final parties = partyState is PartiesLoaded ? partyState.parties : <Party>[];

          // If Quotation Maker is in Step 0, ask for Customer first (Requirement 1)
          if (isQuotation && _quotationStep == 0) {
            return _buildQuotationCustomerStep(parties);
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;

              // Left Pane: Products Section with Instamart-Style Categories
              final productsPane = BlocBuilder<ProductsBloc, ProductsState>(
                builder: (context, pState) {
                  final items = pState is ProductsLoaded ? pState.items : <Item>[];
                  final rawCategories = items.map((i) => i.category.trim()).where((c) => c.isNotEmpty).toSet().toList();
                  final categories = ['All', ...rawCategories];

                  final filtered = items.where((i) {
                    final matchCat = _category == 'All' || i.category.trim() == _category.trim();
                    final matchQuery = _productQuery.isEmpty ||
                        i.name.toLowerCase().contains(_productQuery.toLowerCase()) ||
                        i.itemCode.toLowerCase().contains(_productQuery.toLowerCase());
                    return matchCat && matchQuery;
                  }).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isQuotation) ...[
                        // Customer summary banner
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.person_outline, size: 16, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _nameController.text.trim().isNotEmpty
                                      ? 'Quotation For: ${_nameController.text.trim()} ${_phoneController.text.trim().isNotEmpty ? "(${_phoneController.text.trim()})" : ""}'
                                      : 'Quotation For: Walk-in / General Customer',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => setState(() => _quotationStep = 0),
                                child: const Text('Change', style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      EmpiranTextField(
                        label: '',
                        hint: 'Search products by name or SKU...',
                        prefixIcon: Icons.search_rounded,
                        onChanged: (v) => setState(() => _productQuery = v),
                      ),
                      const SizedBox(height: 10),

                      // Instamart-Style Categories Carousel (Requirement 1 & 7)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: categories.map((cat) {
                            final count = cat == 'All' ? items.length : items.where((i) => i.category.trim() == cat).length;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _buildCategoryCard(cat, count, _category == cat),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Products List with Images & Instamart Add/Stepper
                      Expanded(
                        child: items.isEmpty
                            ? EmpiranEmptyState(
                                title: 'No products in catalog',
                                description: 'Add your first product to begin billing.',
                                icon: Icons.inventory_2_outlined,
                                actionLabel: 'Add Product',
                                onAction: () => showProductDialog(context),
                              )
                            : filtered.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.search_off_rounded, size: 40, color: Colors.grey),
                                        const SizedBox(height: 8),
                                        Text(
                                          'No products in category "$_category"',
                                          style: const TextStyle(color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: filtered.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                                    itemBuilder: (context, i) {
                                      final item = filtered[i];
                                      final qtyInCart = _getItemQtyInCart(item.id);
                                      final itemImageBytes = _decodeImage(item.image);

                                      return EmpiranCard(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        child: Row(
                                          children: [
                                            // Product Image (Requirement 1 & 7)
                                            Container(
                                              width: 52,
                                              height: 52,
                                              decoration: BoxDecoration(
                                                color: AppColors.lightSurfaceContainer,
                                                borderRadius: BorderRadius.circular(AppRadii.medium),
                                              ),
                                              child: itemImageBytes != null
                                                  ? ClipRRect(
                                                      borderRadius: BorderRadius.circular(AppRadii.medium),
                                                      child: Image.memory(
                                                        itemImageBytes,
                                                        fit: BoxFit.cover,
                                                        gaplessPlayback: true,
                                                        errorBuilder: (_, __, ___) => const Icon(
                                                          Icons.inventory_2_outlined,
                                                          color: AppColors.primary,
                                                          size: 22,
                                                        ),
                                                      ),
                                                    )
                                                  : const Icon(
                                                      Icons.inventory_2_outlined,
                                                      color: AppColors.primary,
                                                      size: 22,
                                                    ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item.name,
                                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Stock: ${item.currentStock} ${item.unit} • ${item.category}',
                                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
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
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 14,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                if (qtyInCart == 0)
                                                  InkWell(
                                                    onTap: () => _add(item),
                                                    borderRadius: BorderRadius.circular(6),
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.primary.withValues(alpha: 0.12),
                                                        borderRadius: BorderRadius.circular(6),
                                                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                                      ),
                                                      child: const Text(
                                                        '+ Add',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                          color: AppColors.primary,
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                else
                                                  Container(
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primary.withValues(alpha: 0.1),
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(color: AppColors.primary),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        InkWell(
                                                          onTap: () => _decrement(item),
                                                          child: const Padding(
                                                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                            child: Icon(Icons.remove, size: 14, color: AppColors.primary),
                                                          ),
                                                        ),
                                                        Text(
                                                          '$qtyInCart',
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 12,
                                                            color: AppColors.primary,
                                                          ),
                                                        ),
                                                        InkWell(
                                                          onTap: () => _increment(item),
                                                          child: const Padding(
                                                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                            child: Icon(Icons.add, size: 14, color: AppColors.primary),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  );
                },
              );

              // Right Pane: Order Cart & Bill Checkout
              final checkoutPane = SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Customer Information Card (Always editable)
                    EmpiranCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Customer Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 10),
                          if (parties.isNotEmpty) ...[
                            DropdownButtonFormField<String>(
                              initialValue: _partyId,
                              decoration: const InputDecoration(labelText: 'Select Registered Customer (Optional)'),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('Manual / Walk-in Customer')),
                                ...parties.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.name} (${p.phone})'))),
                              ],
                              onChanged: (v) {
                                setState(() {
                                  _partyId = v;
                                  if (v != null) {
                                    final p = parties.firstWhere((element) => element.id == v);
                                    _nameController.text = p.name;
                                    _phoneController.text = p.phone;
                                  }
                                });
                              },
                            ),
                            const SizedBox(height: 10),
                          ],
                          LayoutBuilder(
                            builder: (context, cConstraints) {
                              final isNarrow = cConstraints.maxWidth < 460;
                              final nameField = EmpiranTextField(
                                controller: _nameController,
                                label: 'Customer Name (Optional)',
                                hint: 'Walk-in Customer',
                              );
                              final phoneField = EmpiranTextField(
                                controller: _phoneController,
                                label: 'Mobile Phone (Optional)',
                                hint: 'Optional mobile',
                                isNumber: true,
                              );

                              if (isNarrow) {
                                return Column(
                                  children: [
                                    nameField,
                                    const SizedBox(height: 10),
                                    phoneField,
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(child: nameField),
                                  const SizedBox(width: 12),
                                  Expanded(child: phoneField),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Items in Cart
                    EmpiranCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Selected Products', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text('${_lines.length} items', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (_lines.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text('No products added yet. Select from the catalog on the left.',
                                    style: TextStyle(color: Colors.grey, fontSize: 13)),
                              ),
                            )
                          else
                            Column(
                              children: _lines.map((line) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              line.name,
                                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              '${Formatters.money(line.price)} / ${line.unit}',
                                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove_circle_outline, size: 20),
                                            onPressed: () {
                                              setState(() {
                                                if (line.quantity > 1) {
                                                  line.quantity--;
                                                } else {
                                                  _lines.remove(line);
                                                }
                                              });
                                            },
                                          ),
                                          Text('${line.quantity.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                          IconButton(
                                            icon: const Icon(Icons.add_circle_outline, size: 20),
                                            onPressed: () => setState(() => line.quantity++),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        Formatters.money(line.total),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                        onPressed: () => setState(() => _lines.remove(line)),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Bill Summary & Tax Calculation Card (Requirements 2 & 5)
                    EmpiranCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Subtotal:'),
                              Text(Formatters.money(_subtotal), style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Fixed Amount Discount Input (Requirement 5)
                          Row(
                            children: [
                              const Expanded(
                                flex: 3,
                                child: Text('Discount (Fixed ₹):', style: TextStyle(fontSize: 13)),
                              ),
                              Expanded(
                                flex: 2,
                                child: SizedBox(
                                  height: 38,
                                  child: TextField(
                                    controller: _discountController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.end,
                                    decoration: InputDecoration(
                                      hintText: '₹0',
                                      prefixText: '₹ ',
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onChanged: (v) {
                                      setState(() {
                                        _discount = double.tryParse(v.trim()) ?? 0;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_discount > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Discount Applied:', style: TextStyle(fontSize: 12, color: AppColors.success)),
                                Text('-${Formatters.money(_effectiveDiscount)}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success)),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),

                          // Optional GST 18% with Separate CGST 9% & SGST 9% (Requirement 2)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Checkbox(
                                    value: _isGst,
                                    onChanged: (v) => setState(() => _isGst = v ?? false),
                                  ),
                                  const Text('Apply GST (18%)', style: TextStyle(fontWeight: FontWeight.w600)),
                                ],
                              ),
                              if (_isGst)
                                Text(
                                  Formatters.money(_cgst + _sgst),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                            ],
                          ),

                          // Separate CGST 9% & SGST 9% breakdown if GST is applied
                          if (_isGst) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Taxable Value:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                      Text(Formatters.money(_taxableAmount), style: const TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('CGST @ 9%:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                      Text(Formatters.money(_cgst), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('SGST @ 9%:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                      Text(Formatters.money(_sgst), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Grand Total:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary)),
                              Text(Formatters.money(_total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_error != null) ...[
                            Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                            const SizedBox(height: 12),
                          ],
                          EmpiranButton(
                            label: widget.type == 'quotation'
                                ? 'Create Quotation'
                                : widget.type == 'order'
                                    ? 'Place Order'
                                    : 'Issue Invoice',
                            icon: Icons.check_circle_outline,
                            isLoading: _busy,
                            onPressed: _save,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );

              if (isWide) {
                return Row(
                  children: [
                    Expanded(flex: 6, child: Padding(padding: const EdgeInsets.all(16), child: productsPane)),
                    const VerticalDivider(width: 1),
                    Expanded(flex: 5, child: Padding(padding: const EdgeInsets.all(16), child: checkoutPane)),
                  ],
                );
              } else {
                return DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      const TabBar(
                        tabs: [
                          Tab(text: 'Catalog', icon: Icon(Icons.inventory_2_outlined)),
                          Tab(text: 'Cart & Summary', icon: Icon(Icons.shopping_cart_outlined)),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            Padding(padding: const EdgeInsets.all(16), child: productsPane),
                            Padding(padding: const EdgeInsets.all(16), child: checkoutPane),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }
}
