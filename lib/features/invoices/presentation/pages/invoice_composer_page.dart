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
  final bool isEditing;

  const InvoiceComposerPage({
    super.key,
    this.type = 'order',
    this.source,
    this.embedded = false,
    this.isEditing = false,
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
  final _collectedController = TextEditingController();
  final _referredByController = TextEditingController();

  String? _partyId;
  String _productQuery = '';
  String _category = 'All';
  String _paymentMode = 'Cash';
  double _discount = 0;
  final double _shipping = 0;
  double _paid = 0;
  final double _amount = 0;
  bool _isGst = false;
  bool _busy = false;
  final Map<String, String> _dispatch = {};
  String? _error;
  late DateTime _date;
  static const List<String> _paymentMethods = [
    'Cash',
    'UPI',
    'Card',
    'Cheque',
    'Borrow',
    'Bank Transfer',
    'Other',
  ];

  // Step state for Quotation Maker flow: Step 0 = Customer details (Optional), Step 1 = Products & Ordering
  late int _quotationStep;
  Map<String, String> _categoryImages = {};

  bool get _isPayment => widget.type.startsWith('payment_');
  double get _subtotal =>
      _isPayment ? _amount : _lines.fold(0, (s, l) => s + l.total);
  double get _effectiveDiscount => _discount;
  double get _taxableAmount =>
      (_subtotal - _effectiveDiscount).clamp(0, double.infinity);
  double get _cgst => _isGst ? _taxableAmount * 0.09 : 0;
  double get _sgst => _isGst ? _taxableAmount * 0.09 : 0;
  double get _total => _taxableAmount + _cgst + _sgst + _shipping;
  bool get _isOrder => widget.type == 'order';
  bool get _collectCashAmount => _isOrder && _paymentMode == 'Cash';
  double get _effectivePaid {
    if (_isPayment) return 0;
    if (!_isOrder) return _paid;
    if (_paymentMode == 'Borrow') return 0;
    if (_paymentMode == 'Cash') return _paid.clamp(0, _total).toDouble();
    return _total;
  }

  double get _balanceDue =>
      (_total - _effectivePaid).clamp(0, double.infinity).toDouble();

  @override
  void initState() {
    super.initState();
    _date = widget.source != null && widget.isEditing
        ? widget.source!.date
        : DateTime.now();
    // Quotation maker starts at Step 0 (Ask for Customer Name & Mobile Number first)
    _quotationStep = widget.type == 'quotation' ? 0 : 1;

    final s = widget.source;
    if (s != null) {
      _lines.addAll(s.lines.map((l) => InvoiceLine.fromJson(l.toJson())));
      _nameController.text = s.partyName;
      _phoneController.text = s.partyPhone;
      _partyId = s.partyId;
      _discount = s.discount;
      _paymentMode = s.paymentMode.trim().isNotEmpty ? s.paymentMode : 'Cash';
      _paid = s.paid;
      if (_paid > 0) {
        _collectedController.text = _paid.toStringAsFixed(0);
      }
      if (_discount > 0) {
        _discountController.text = _discount.toStringAsFixed(0);
      }
      _notesController.text = s.notes;
      _referredByController.text = s.referredBy ?? '';
      _isGst = s.isGst;
      _dispatch.addAll(s.dispatch);
      _quotationStep =
          1; // If editing or converting existing source, jump straight to products
    }

    _loadCategoryImages();
    context.read<PartiesBloc>().add(const LoadPartiesRequested());
    context.read<ProductsBloc>().add(const LoadProductsRequested());
  }

  Future<void> _loadCategoryImages() async {
    try {
      final images = await context
          .read<SettingsBloc>()
          .settingsRepository
          .loadCategoryImages();
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
    _collectedController.dispose();
    _referredByController.dispose();
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

  bool _matchesPartySearch(Party party, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final compactQuery = q.replaceAll(RegExp(r'\s+'), '');
    final phone = party.phone.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    return party.name.toLowerCase().contains(q) ||
        phone.contains(compactQuery) ||
        party.email.toLowerCase().contains(q) ||
        party.gstin.toLowerCase().contains(q) ||
        party.address.toLowerCase().contains(q);
  }

  String _partySearchSubtitle(Party party) {
    final parts = [
      if (party.phone.trim().isNotEmpty) party.phone.trim(),
      if (party.email.trim().isNotEmpty) party.email.trim(),
      if (party.gstin.trim().isNotEmpty) 'GSTIN: ${party.gstin.trim()}',
      if (party.address.trim().isNotEmpty) party.address.trim(),
    ];
    return parts.isEmpty ? 'No contact details saved' : parts.join(' • ');
  }

  bool _matchesProductSearch(Item item, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return item.name.toLowerCase().contains(q) ||
        item.itemCode.toLowerCase().contains(q) ||
        item.hsn.toLowerCase().contains(q) ||
        item.category.toLowerCase().contains(q) ||
        item.unit.toLowerCase().contains(q) ||
        item.salesPrice.toString().contains(q) ||
        item.purchasePrice.toString().contains(q);
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
            price: widget.type.startsWith('purchase')
                ? item.purchasePrice
                : item.salesPrice,
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
        throw ArgumentError(
            'Select a party and enter an amount greater than zero.');
      }
      if (!_isPayment && _lines.isEmpty) {
        throw ArgumentError('Add at least one product to continue.');
      }

      final settingsState = context.read<SettingsBloc>().state;
      final settings = settingsState is SettingsLoaded
          ? settingsState.invoiceSettings
          : InvoiceSettings();

      final invoicesRepo = context.read<InvoicesBloc>().invoicesRepository;
      final source = widget.source;
      final isEditing = widget.isEditing && source != null;
      final number = isEditing
          ? source.number
          : invoicesRepo.generateNumber(widget.type, _isGst, settings);
      if (!isEditing) {
        context
            .read<SettingsBloc>()
            .add(SaveInvoiceSettingsRequested(settings));
      }

      // Auto-save customer details in Customer Section (Requirement 8)
      final custName = _nameController.text.trim();
      final custPhone = _phoneController.text.trim();
      if (custName.isNotEmpty && _partyId == null) {
        final partyState = context.read<PartiesBloc>().state;
        final existingParties =
            partyState is PartiesLoaded ? partyState.parties : <Party>[];
        final match = existingParties
            .where((p) =>
                p.name.toLowerCase() == custName.toLowerCase() ||
                (custPhone.isNotEmpty && p.phone == custPhone))
            .firstOrNull;
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
          ? (authState.user.name.isNotEmpty
              ? authState.user.name
              : authState.user.username)
          : 'Admin';

      final txn = BusinessTransaction(
        id: isEditing
            ? source.id
            : DateTime.now().microsecondsSinceEpoch.toString(),
        type: widget.type,
        number: number,
        date: _date,
        lines: _isPayment
            ? [
                InvoiceLine(
                  itemId: '',
                  name: widget.type == 'payment_in'
                      ? 'Payment In'
                      : 'Payment Out',
                  quantity: 1,
                  unit: '',
                  price: _amount,
                ),
              ]
            : _lines,
        partyId: _partyId,
        partyName: custName,
        partyPhone: custPhone,
        partyAddress: source?.partyAddress ?? '',
        partyGstin: source?.partyGstin ?? '',
        isGst: _isGst,
        paid: _effectivePaid,
        paymentMode: _paymentMode,
        status: _isPayment
            ? 'Completed'
            : (_effectivePaid >= _total
                ? 'Paid'
                : (_effectivePaid > 0 ? 'Partial' : 'Unpaid')),
        dispatch: _dispatch,
        discount: _effectiveDiscount,
        shipping: _shipping,
        notes: _notesController.text,
        referredBy: _referredByController.text.trim().isNotEmpty
            ? _referredByController.text.trim()
            : (source?.referredBy ?? staffName),
        convertedFrom: !isEditing &&
                source?.type == 'quotation' &&
                widget.type != 'quotation'
            ? source!.id
            : source?.convertedFrom,
      );

      // If creating or updating an order, keep product stock aligned with quantity changes.
      if (widget.type == 'order') {
        final oldQuantities = <String, double>{};
        if (isEditing && source.type == 'order') {
          for (final line in source.lines) {
            if (line.itemId.isNotEmpty) {
              oldQuantities[line.itemId] =
                  (oldQuantities[line.itemId] ?? 0) + line.quantity;
            }
          }
        }

        final newQuantities = <String, double>{};
        for (final line in _lines) {
          if (line.itemId.isNotEmpty) {
            newQuantities[line.itemId] =
                (newQuantities[line.itemId] ?? 0) + line.quantity;
          }
        }

        final itemIds = {...oldQuantities.keys, ...newQuantities.keys};
        for (final itemId in itemIds) {
          final oldQty = oldQuantities[itemId] ?? 0;
          final newQty = newQuantities[itemId] ?? 0;
          final delta = newQty - oldQty;
          if (delta != 0) {
            try {
              await context
                  .read<ProductsBloc>()
                  .productsRepository
                  .adjustStockById(
                    itemId,
                    -delta,
                    reason: isEditing
                        ? 'Order updated: #$number'
                        : 'Order placed: #$number',
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
            _collectedController.clear();
            _discount = 0;
            _paid = 0;
            _paymentMode = 'Cash';
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
                          cat == 'All'
                              ? Icons.apps_rounded
                              : Icons.category_outlined,
                          color: isSelected ? AppColors.primary : Colors.grey,
                          size: 22,
                        ),
                      ),
                    )
                  : Icon(
                      cat == 'All'
                          ? Icons.apps_rounded
                          : Icons.category_outlined,
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
                      child: const Icon(Icons.request_quote_rounded,
                          color: AppColors.primary, size: 28),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quotation Maker',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary),
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
                  style: TextStyle(
                      fontSize: 13, color: AppColors.lightTextSecondary),
                ),
                const SizedBox(height: 20),
                if (parties.isNotEmpty) ...[
                  Autocomplete<Party>(
                    displayStringForOption: (option) =>
                        '${option.name} (${option.phone})',
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return parties;
                      }
                      return parties.where((option) =>
                          _matchesPartySearch(option, textEditingValue.text));
                    },
                    onSelected: (selection) {
                      setState(() {
                        _partyId = selection.id;
                        _nameController.text = selection.name;
                        _phoneController.text = selection.phone;
                      });
                    },
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) {
                      return EmpiranTextField(
                        controller: controller,
                        focusNode: focusNode,
                        label: 'Search Registered Customer (Optional)',
                        hint: 'Type name, phone, email, GSTIN, or address...',
                        prefixIcon: Icons.search,
                        onChanged: (val) {
                          if (_partyId != null) {
                            setState(() => _partyId = null);
                          }
                        },
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(8),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                                maxHeight: 250, maxWidth: 400),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final option = options.elementAt(index);
                                return ListTile(
                                  title: Text(option.name),
                                  subtitle: Text(_partySearchSubtitle(option)),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
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
                const SizedBox(height: 14),
                EmpiranTextField(
                  controller: _referredByController,
                  label: 'Who referred (Optional)',
                  hint: 'e.g. Employee name or external referrer',
                  prefixIcon: Icons.person_add_alt_1_outlined,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
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
    final isEditing = widget.isEditing && widget.source != null;
    final title = isQuotation
        ? (isEditing ? 'Update Quotation' : 'Quotation Maker')
        : widget.type == 'order'
            ? (isEditing ? 'Update Order / Invoice' : 'Create Order / Invoice')
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
          final parties =
              partyState is PartiesLoaded ? partyState.parties : <Party>[];

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
                  final items =
                      pState is ProductsLoaded ? pState.items : <Item>[];
                  final rawCategories = items
                      .map((i) => i.category.trim())
                      .where((c) => c.isNotEmpty)
                      .toSet()
                      .toList();
                  final categories = ['All', ...rawCategories];

                  final hasProductQuery = _productQuery.trim().isNotEmpty;
                  final filtered = items.where((i) {
                    final matchCat = _category == 'All' ||
                        i.category.trim() == _category.trim();
                    final matchQuery = _matchesProductSearch(i, _productQuery);
                    return hasProductQuery ? matchQuery : matchCat;
                  }).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isQuotation) ...[
                        // Customer summary banner
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color:
                                    AppColors.primary.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.person_outline,
                                  size: 16, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _nameController.text.trim().isNotEmpty
                                      ? 'Quotation For: ${_nameController.text.trim()} ${_phoneController.text.trim().isNotEmpty ? "(${_phoneController.text.trim()})" : ""}'
                                      : 'Quotation For: Walk-in / General Customer',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () =>
                                    setState(() => _quotationStep = 0),
                                child: const Text('Change',
                                    style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      EmpiranTextField(
                        label: '',
                        hint:
                            'Search all products by name, SKU, HSN, category, unit, or price...',
                        prefixIcon: Icons.search_rounded,
                        onChanged: (v) => setState(() => _productQuery = v),
                      ),
                      const SizedBox(height: 10),

                      // Instamart-Style Categories Carousel (Requirement 1 & 7)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: categories.map((cat) {
                            final count = cat == 'All'
                                ? items.length
                                : items
                                    .where((i) => i.category.trim() == cat)
                                    .length;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _buildCategoryCard(
                                  cat, count, _category == cat),
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
                                description:
                                    'Add your first product to begin billing.',
                                icon: Icons.inventory_2_outlined,
                                actionLabel: 'Add Product',
                                onAction: () => showProductDialog(context),
                              )
                            : filtered.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.search_off_rounded,
                                            size: 40, color: Colors.grey),
                                        const SizedBox(height: 8),
                                        Text(
                                          'No products in category "$_category"',
                                          style: const TextStyle(
                                              color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: filtered.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 6),
                                    itemBuilder: (context, i) {
                                      final item = filtered[i];
                                      final qtyInCart =
                                          _getItemQtyInCart(item.id);
                                      final itemImageBytes =
                                          _decodeImage(item.image);

                                      return EmpiranCard(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 10),
                                        child: Row(
                                          children: [
                                            // Product Image (Requirement 1 & 7)
                                            Container(
                                              width: 52,
                                              height: 52,
                                              decoration: BoxDecoration(
                                                color: AppColors
                                                    .lightSurfaceContainer,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        AppRadii.medium),
                                              ),
                                              child: itemImageBytes != null
                                                  ? ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              AppRadii.medium),
                                                      child: Image.memory(
                                                        itemImageBytes,
                                                        fit: BoxFit.cover,
                                                        gaplessPlayback: true,
                                                        errorBuilder:
                                                            (_, __, ___) =>
                                                                const Icon(
                                                          Icons
                                                              .inventory_2_outlined,
                                                          color:
                                                              AppColors.primary,
                                                          size: 22,
                                                        ),
                                                      ),
                                                    )
                                                  : const Icon(
                                                      Icons
                                                          .inventory_2_outlined,
                                                      color: AppColors.primary,
                                                      size: 22,
                                                    ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item.name,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 13),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Stock: ${item.currentStock} ${item.unit} • ${item.category}',
                                                    style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  Formatters.money(
                                                      item.salesPrice),
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
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                    child: Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 10,
                                                          vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.primary
                                                            .withValues(
                                                                alpha: 0.12),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                        border: Border.all(
                                                            color: AppColors
                                                                .primary
                                                                .withValues(
                                                                    alpha:
                                                                        0.3)),
                                                      ),
                                                      child: const Text(
                                                        '+ Add',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              AppColors.primary,
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                else
                                                  Container(
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primary
                                                          .withValues(
                                                              alpha: 0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                      border: Border.all(
                                                          color: AppColors
                                                              .primary),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        InkWell(
                                                          onTap: () =>
                                                              _decrement(item),
                                                          child: const Padding(
                                                            padding: EdgeInsets
                                                                .symmetric(
                                                                    horizontal:
                                                                        6,
                                                                    vertical:
                                                                        2),
                                                            child: Icon(
                                                                Icons.remove,
                                                                size: 14,
                                                                color: AppColors
                                                                    .primary),
                                                          ),
                                                        ),
                                                        Text(
                                                          '$qtyInCart',
                                                          style:
                                                              const TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 12,
                                                            color: AppColors
                                                                .primary,
                                                          ),
                                                        ),
                                                        InkWell(
                                                          onTap: () =>
                                                              _increment(item),
                                                          child: const Padding(
                                                            padding: EdgeInsets
                                                                .symmetric(
                                                                    horizontal:
                                                                        6,
                                                                    vertical:
                                                                        2),
                                                            child: Icon(
                                                                Icons.add,
                                                                size: 14,
                                                                color: AppColors
                                                                    .primary),
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
                          const Text('Customer Details',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 10),
                          if (parties.isNotEmpty) ...[
                            Autocomplete<Party>(
                              displayStringForOption: (option) =>
                                  '${option.name} (${option.phone})',
                              optionsBuilder: (textEditingValue) {
                                if (textEditingValue.text.isEmpty) {
                                  return parties;
                                }
                                return parties.where((option) =>
                                    _matchesPartySearch(
                                        option, textEditingValue.text));
                              },
                              onSelected: (selection) {
                                setState(() {
                                  _partyId = selection.id;
                                  _nameController.text = selection.name;
                                  _phoneController.text = selection.phone;
                                });
                              },
                              fieldViewBuilder: (context, controller, focusNode,
                                  onFieldSubmitted) {
                                return EmpiranTextField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  label:
                                      'Search Registered Customer (Optional)',
                                  hint:
                                      'Type name, phone, email, GSTIN, or address...',
                                  prefixIcon: Icons.search,
                                  onChanged: (val) {
                                    if (_partyId != null) {
                                      setState(() => _partyId = null);
                                    }
                                  },
                                );
                              },
                              optionsViewBuilder:
                                  (context, onSelected, options) {
                                return Align(
                                  alignment: Alignment.topLeft,
                                  child: Material(
                                    elevation: 4,
                                    borderRadius: BorderRadius.circular(8),
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                          maxHeight: 250, maxWidth: 400),
                                      child: ListView.builder(
                                        padding: EdgeInsets.zero,
                                        shrinkWrap: true,
                                        itemCount: options.length,
                                        itemBuilder: (context, index) {
                                          final option =
                                              options.elementAt(index);
                                          return ListTile(
                                            title: Text(option.name),
                                            subtitle: Text(
                                                _partySearchSubtitle(option)),
                                            onTap: () => onSelected(option),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
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
                              final referredField = EmpiranTextField(
                                controller: _referredByController,
                                label: 'Who referred (Optional)',
                                hint: 'Referrer name',
                              );

                              if (isNarrow) {
                                return Column(
                                  children: [
                                    nameField,
                                    const SizedBox(height: 10),
                                    phoneField,
                                    const SizedBox(height: 10),
                                    referredField,
                                  ],
                                );
                              }

                              return Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: nameField),
                                      const SizedBox(width: 12),
                                      Expanded(child: phoneField),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  referredField,
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
                              const Text('Selected Products',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              Text('${_lines.length} items',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (_lines.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text(
                                    'No products added yet. Select from the catalog on the left.',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 13)),
                              ),
                            )
                          else
                            Column(
                              children: _lines.map((line) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              line.name,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                                Icons.delete_outline,
                                                size: 20,
                                                color: AppColors.error),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () => setState(
                                                () => _lines.remove(line)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${Formatters.money(line.price)} / ${line.unit}',
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.remove_circle_outline,
                                                    size: 22),
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(),
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
                                              const SizedBox(width: 10),
                                              Text('${line.quantity.toInt()}',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold)),
                                              const SizedBox(width: 10),
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.add_circle_outline,
                                                    size: 22),
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(),
                                                onPressed: () => setState(
                                                    () => line.quantity++),
                                              ),
                                              const SizedBox(width: 16),
                                              SizedBox(
                                                width: 60,
                                                child: Text(
                                                  Formatters.money(line.total),
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13),
                                                  textAlign: TextAlign.right,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
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
                              Text(Formatters.money(_subtotal),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Fixed Amount Discount Input (Requirement 5)
                          Row(
                            children: [
                              const Expanded(
                                flex: 3,
                                child: Text('Discount (Fixed ₹):',
                                    style: TextStyle(fontSize: 13)),
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
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                    ),
                                    onChanged: (v) {
                                      setState(() {
                                        _discount =
                                            double.tryParse(v.trim()) ?? 0;
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
                                const Text('Discount Applied:',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.success)),
                                Text('-${Formatters.money(_effectiveDiscount)}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.success)),
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
                                    onChanged: (v) =>
                                        setState(() => _isGst = v ?? false),
                                  ),
                                  const Text('Apply GST (18%)',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                              if (_isGst)
                                Text(
                                  Formatters.money(_cgst + _sgst),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary),
                                ),
                            ],
                          ),

                          // Separate CGST 9% & SGST 9% breakdown if GST is applied
                          if (_isGst) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.primary.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.15)),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Taxable Value:',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey)),
                                      Text(Formatters.money(_taxableAmount),
                                          style: const TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('CGST @ 9%:',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600)),
                                      Text(Formatters.money(_cgst),
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('SGST @ 9%:',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600)),
                                      Text(Formatters.money(_sgst),
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600)),
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
                              const Text('Grand Total:',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary)),
                              Text(Formatters.money(_total),
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary)),
                            ],
                          ),
                          
                          // Payment Method Section
                          if (widget.type != 'quotation') ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                const Expanded(
                                  flex: 3,
                                  child: Text('Payment Method:',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                ),
                                Expanded(
                                  flex: 4,
                                  child: Container(
                                    height: 38,
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _paymentMode,
                                        isExpanded: true,
                                        icon: const Icon(Icons.arrow_drop_down),
                                        items: _paymentMethods
                                            .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                                            .toList(),
                                        onChanged: (v) {
                                          if (v != null) {
                                            setState(() {
                                              _paymentMode = v;
                                              if (v != 'Cash') {
                                                _paid = _total;
                                                _collectedController.text = _total.toStringAsFixed(0);
                                              } else {
                                                _paid = double.tryParse(_collectedController.text.trim()) ?? 0;
                                              }
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_paymentMode == 'Cash') ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Expanded(
                                    flex: 3,
                                    child: Text('Collected Amount:',
                                        style: TextStyle(fontSize: 13)),
                                  ),
                                  Expanded(
                                    flex: 4,
                                    child: SizedBox(
                                      height: 38,
                                      child: TextField(
                                        controller: _collectedController,
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.end,
                                        decoration: InputDecoration(
                                          hintText: '₹0',
                                          prefixText: '₹ ',
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        onChanged: (v) {
                                          setState(() {
                                            _paid = double.tryParse(v.trim()) ?? 0;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (_paymentMode == 'Cash' || _paymentMode == 'Borrow') ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Balance Due:',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.error)),
                                  Text(Formatters.money(_balanceDue),
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.error)),
                                ],
                              ),
                            ],
                          ],
                          const SizedBox(height: 16),
                          if (_error != null) ...[
                            Text(_error!,
                                style: const TextStyle(
                                    color: AppColors.error, fontSize: 12)),
                            const SizedBox(height: 12),
                          ],
                          EmpiranButton(
                            label: isEditing
                                ? 'Update ${widget.type == 'quotation' ? 'Quotation' : widget.type == 'order' ? 'Order' : 'Document'}'
                                : widget.type == 'quotation'
                                    ? 'Create Quotation'
                                    : widget.type == 'order'
                                        ? 'Place Order'
                                        : 'Issue Invoice',
                            icon: isEditing
                                ? Icons.update_rounded
                                : Icons.check_circle_outline,
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
                    Expanded(
                        flex: 6,
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: productsPane)),
                    const VerticalDivider(width: 1),
                    Expanded(
                        flex: 5,
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: checkoutPane)),
                  ],
                );
              } else {
                return DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      const TabBar(
                        tabs: [
                          Tab(
                              text: 'Catalog',
                              icon: Icon(Icons.inventory_2_outlined)),
                          Tab(
                              text: 'Cart & Summary',
                              icon: Icon(Icons.shopping_cart_outlined)),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            Padding(
                                padding: const EdgeInsets.all(16),
                                child: productsPane),
                            Padding(
                                padding: const EdgeInsets.all(16),
                                child: checkoutPane),
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
