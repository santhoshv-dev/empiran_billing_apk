import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:empiran/core/theme/app_theme.dart';
import 'package:empiran/core/utils/formatters.dart';
import 'package:empiran/core/widgets/empiran_components.dart';
import 'package:empiran/features/parties/presentation/bloc/parties_bloc.dart';
import 'package:empiran/features/parties/presentation/bloc/parties_state.dart';
import 'package:empiran/features/products/presentation/bloc/products_bloc.dart';
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

  String? _partyId;
  String _productQuery = '';
  String _category = 'All';
  final String _paymentMode = 'Cash';
  double _discount = 0;
  double _shipping = 0;
  final double _paid = 0;
  final double _amount = 0;
  bool _isGst = false;
  bool _busy = false;
  final bool _percentageDiscount = false;
  final Map<String, String> _dispatch = {};
  String? _error;
  final DateTime _date = DateTime.now();

  bool get _isPayment => widget.type.startsWith('payment_');
  double get _subtotal => _isPayment ? _amount : _lines.fold(0, (s, l) => s + l.total);
  double get _effectiveDiscount => _percentageDiscount ? _subtotal * _discount / 100 : _discount;
  double get _total => (_subtotal - _effectiveDiscount) * (_isGst ? 1.18 : 1) + _shipping;

  @override
  void initState() {
    super.initState();
    final s = widget.source;
    if (s != null) {
      _lines.addAll(s.lines.map((l) => InvoiceLine.fromJson(l.toJson())));
      _nameController.text = s.partyName;
      _phoneController.text = s.partyPhone;
      _partyId = s.partyId;
      _discount = s.discount;
      _shipping = s.shipping;
      _notesController.text = s.notes;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
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
        throw ArgumentError('Add at least one product to the invoice.');
      }

      final settingsState = context.read<SettingsBloc>().state;
      final settings = settingsState is SettingsLoaded ? settingsState.invoiceSettings : InvoiceSettings();

      final invoicesRepo = context.read<InvoicesBloc>().invoicesRepository;
      final number = invoicesRepo.generateNumber(widget.type, _isGst, settings);
      context.read<SettingsBloc>().add(SaveInvoiceSettingsRequested(settings));

      final txn = BusinessTransaction(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
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
        partyName: _nameController.text.trim(),
        partyPhone: _phoneController.text.trim(),
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
        convertedFrom: widget.source?.type == 'quotation' ? widget.source?.id : null,
      );

      context.read<InvoicesBloc>().add(SaveTransactionRequested(txn));

      if (mounted) {
        if (widget.embedded) {
          showDocumentPreviewDialog(context, txn);
          setState(() {
            _lines.clear();
            _nameController.clear();
            _phoneController.clear();
            _partyId = null;
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

  @override
  Widget build(BuildContext context) {
    final title = widget.type == 'quotation' ? 'Create Quotation / Estimate' : 'Create Sales Invoice';

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: widget.embedded ? null : AppBar(title: Text(title)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 860;

          // Products Selector Pane
          final productsPane = BlocBuilder<ProductsBloc, ProductsState>(
            builder: (context, pState) {
              final items = pState is ProductsLoaded ? pState.items : <Item>[];
              final categories = ['All', ...items.map((i) => i.category).toSet()];

              final filtered = items.where((i) {
                final matchCat = _category == 'All' || i.category == _category;
                final matchQuery = _productQuery.isEmpty ||
                    i.name.toLowerCase().contains(_productQuery.toLowerCase()) ||
                    i.itemCode.toLowerCase().contains(_productQuery.toLowerCase());
                return matchCat && matchQuery;
              }).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EmpiranTextField(
                    label: '',
                    hint: 'Search products by name or SKU...',
                    prefixIcon: Icons.search_rounded,
                    onChanged: (v) => setState(() => _productQuery = v),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: categories.map((cat) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(cat),
                            selected: _category == cat,
                            onSelected: (_) => setState(() => _category = cat),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: items.isEmpty
                        ? EmpiranEmptyState(
                            title: 'No products in catalog',
                            description: 'Add your first product to begin billing.',
                            icon: Icons.inventory_2_outlined,
                            actionLabel: 'Add Product',
                            onAction: () => showProductDialog(context),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (context, i) {
                              final item = filtered[i];
                              final inCart = _lines.any((l) => l.itemId == item.id);

                              return EmpiranCard(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                onTap: () => _add(item),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
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
                                          : const Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                          Text('Stock: ${item.currentStock} ${item.unit} • ${item.category}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          Formatters.money(item.salesPrice),
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.primary),
                                        ),
                                        const SizedBox(height: 2),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: inCart ? AppColors.success.withValues(alpha: 0.15) : AppColors.primary.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            inCart ? 'Added ✓' : '+ Add',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: inCart ? AppColors.success : AppColors.primary,
                                            ),
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

          // Billing / Line Items Pane
          final checkoutPane = BlocBuilder<PartiesBloc, PartiesState>(
            builder: (context, partyState) {
              final parties = partyState is PartiesLoaded ? partyState.parties : <Party>[];

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Customer / Party Section
                    EmpiranCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Customer Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 10),
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
                          LayoutBuilder(
                            builder: (context, cConstraints) {
                              final isNarrow = cConstraints.maxWidth < 460;
                              final nameField = EmpiranTextField(
                                controller: _nameController,
                                label: 'Customer Name',
                                hint: 'Walk-in Customer',
                              );
                              final phoneField = EmpiranTextField(
                                controller: _phoneController,
                                label: 'Mobile Phone',
                                hint: 'Optional mobile',
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

                    // Items in Cart Table
                    EmpiranCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Line Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text('${_lines.length} items', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (_lines.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text('No products added yet. Pick from the catalog.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                              ),
                            )
                          else
                            LayoutBuilder(
                              builder: (context, itemConstraints) {
                                final isNarrow = itemConstraints.maxWidth < 440;

                                return Column(
                                  children: _lines.map((line) {
                                    final nameCol = Column(
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
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    );

                                    final qtyRow = Row(
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
                                    );

                                    final priceAndDel = Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          Formatters.money(line.total),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                          onPressed: () => setState(() => _lines.remove(line)),
                                        ),
                                      ],
                                    );

                                    if (isNarrow) {
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 10),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            nameCol,
                                            const SizedBox(height: 4),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                qtyRow,
                                                priceAndDel,
                                              ],
                                            ),
                                            const Divider(height: 8),
                                          ],
                                        ),
                                      );
                                    }

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        children: [
                                          Expanded(child: nameCol),
                                          const SizedBox(width: 8),
                                          qtyRow,
                                          const SizedBox(width: 8),
                                          priceAndDel,
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Bill Summary Card
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
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Checkbox(
                                    value: _isGst,
                                    onChanged: (v) => setState(() => _isGst = v ?? false),
                                  ),
                                  const Text('Apply GST (18%)'),
                                ],
                              ),
                              if (_isGst)
                                Text(Formatters.money((_subtotal - _effectiveDiscount) * 0.18), style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
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
                            label: widget.type == 'quotation' ? 'Create Quotation' : 'Issue Invoice',
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
            },
          );

          if (isWide) {
            return Row(
              children: [
                Expanded(flex: 5, child: Padding(padding: const EdgeInsets.all(16), child: productsPane)),
                const VerticalDivider(width: 1),
                Expanded(flex: 6, child: Padding(padding: const EdgeInsets.all(16), child: checkoutPane)),
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
      ),
    );
  }
}
