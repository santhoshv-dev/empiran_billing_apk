import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/invoice_pdf_service.dart';
import '../../../../core/widgets/empiran_components.dart';
import '../../../../models.dart';
import 'package:empiran/features/parties/presentation/bloc/parties_bloc.dart';
import 'package:empiran/features/parties/presentation/bloc/parties_event.dart';
import 'package:empiran/features/parties/presentation/bloc/parties_state.dart';
import 'package:empiran/features/products/presentation/bloc/products_bloc.dart';
import 'package:empiran/features/products/presentation/bloc/products_event.dart';
import 'package:empiran/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:empiran/features/settings/presentation/bloc/settings_state.dart';
import '../bloc/invoices_bloc.dart';
import '../bloc/invoices_event.dart';
import '../bloc/invoices_state.dart';
import '../widgets/document_preview_dialog.dart';
import '../widgets/product_return_dialog.dart';
import 'invoice_composer_page.dart';

class InvoicesPage extends StatefulWidget {
  final String type; // 'order' or 'quotation'

  const InvoicesPage({super.key, this.type = 'order'});

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  final _searchController = TextEditingController();
  String _status = 'All'; // 'All', 'Paid', 'Unpaid', 'Partial'
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    context.read<InvoicesBloc>().add(const LoadInvoicesRequested());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _shareWhatsApp(BusinessTransaction t) async {
    final phone = t.partyPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.https('wa.me', '/$phone', {
      'text':
          'Hello ${t.partyName.isEmpty ? 'Customer' : t.partyName}, ${t.type == 'quotation' ? 'Quotation' : 'Tax Invoice'} ${t.number}: ${Formatters.money(t.total)}. Thank you for your business!',
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open WhatsApp.')),
      );
    }
  }

  Future<void> _shareDocument(BusinessTransaction t) async {
    final documentLabel = switch (t.type) {
      'quotation' || 'estimate' => 'Quotation',
      'order' => 'Order',
      _ => 'Invoice',
    };
    final safeNumber = t.number
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final fileName =
        '${documentLabel.toLowerCase()}_${safeNumber.isEmpty ? t.id : safeNumber}.pdf';

    try {
      final settingsState = context.read<SettingsBloc>().state;
      final company =
          settingsState is SettingsLoaded ? settingsState.company : Company();
      final invoiceSettings = settingsState is SettingsLoaded
          ? settingsState.invoiceSettings
          : InvoiceSettings();
      final pdf = await buildInvoicePdf(
        company,
        t,
        settings: invoiceSettings,
      );
      if (!mounted) return;

      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(pdf, mimeType: 'application/pdf')],
          fileNameOverrides: [fileName],
          title: '$documentLabel ${t.number}',
          subject: '$documentLabel ${t.number}',
          text:
              'Please find attached $documentLabel ${t.number}${t.partyName.isEmpty ? '.' : ' for ${t.partyName}.'}',
          sharePositionOrigin:
              box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to share the $documentLabel PDF.')),
      );
    }
  }

  // Convert Invoice to Order with Automatic Stock Reduction & Customer Auto-saving (Requirement 3)
  Future<void> _convertToOrder(BusinessTransaction t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.shopping_bag_outlined, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Convert Invoice to Order'),
          ],
        ),
        content: Text(
          'Convert Invoice #${t.number} to an official Order?\n\n'
          '• Stock for all ${t.lines.length} item(s) will be automatically reduced.\n'
          '• Customer details will be automatically saved in the Customer Section.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          EmpiranButton(
            label: 'Convert Now',
            icon: Icons.check,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // 1. Deduct stock for all items
    for (final line in t.lines) {
      if (line.itemId.isNotEmpty) {
        try {
          await context.read<ProductsBloc>().productsRepository.adjustStockById(
                line.itemId,
                -line.quantity,
                reason: 'Converted to Order from Invoice #${t.number}',
              );
        } catch (_) {}
      }
    }
    if (!mounted) return;
    context.read<ProductsBloc>().add(const LoadProductsRequested());

    // 2. Auto-save customer details in Customer section
    final custName = t.partyName.trim();
    final custPhone = t.partyPhone.trim();
    if (custName.isNotEmpty && t.partyId == null) {
      if (!mounted) return;
      final partyState = context.read<PartiesBloc>().state;
      final existingParties =
          partyState is PartiesLoaded ? partyState.parties : <Party>[];
      final match = existingParties
          .where((p) =>
              p.name.toLowerCase() == custName.toLowerCase() ||
              (custPhone.isNotEmpty && p.phone == custPhone))
          .firstOrNull;
      if (match == null) {
        final newParty = Party(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: custName,
          phone: custPhone,
          type: 'Customer',
        );
        if (!mounted) return;
        context.read<PartiesBloc>().add(SavePartyRequested(newParty));
      }
    }

    // 3. Update transaction type to 'order'
    final updatedTxn = BusinessTransaction(
      id: t.id,
      type: 'order',
      number: t.number,
      date: t.date,
      lines: t.lines,
      partyId: t.partyId,
      partyName: t.partyName,
      partyPhone: t.partyPhone,
      partyAddress: t.partyAddress,
      partyGstin: t.partyGstin,
      isGst: t.isGst,
      paid: t.paid,
      paymentMode: t.paymentMode,
      status: t.status,
      dispatch: t.dispatch,
      discount: t.discount,
      shipping: t.shipping,
      notes:
          '${t.notes}\n[Converted to Order on ${Formatters.date(DateTime.now())}]'
              .trim(),
      referredBy: t.referredBy,
      convertedFrom: t.convertedFrom ?? t.id,
    );

    if (!mounted) return;
    context.read<InvoicesBloc>().add(SaveTransactionRequested(updatedTxn));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Invoice #${t.number} converted to Order. Stock reduced and customer saved.'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  // Delete Order (Requirement 4)
  Future<void> _deleteOrder(BusinessTransaction t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: AppColors.error),
            SizedBox(width: 8),
            Text('Delete Order'),
          ],
        ),
        content: Text(
            'Are you sure you want to delete Order #${t.number}? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Order'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      context.read<InvoicesBloc>().add(DeleteTransactionRequested(t));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order #${t.number} deleted.')),
      );
    }
  }

  Future<void> _deleteQuotation(BusinessTransaction t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: AppColors.error),
            SizedBox(width: 8),
            Text('Delete Quotation'),
          ],
        ),
        content: Text(
            'Are you sure you want to delete Quotation #${t.number}? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Quotation'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      context.read<InvoicesBloc>().add(DeleteTransactionRequested(t));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Quotation #${t.number} deleted.')),
      );
    }
  }

  Future<void> _editTransaction(BusinessTransaction t) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InvoiceComposerPage(
          type: widget.type,
          source: t,
          isEditing: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isQuote = widget.type == 'quotation';
    final title =
        isQuote ? 'Quotation Maker & Estimates' : 'Orders & Tax Invoices';

    return PageFrame(
      title: title,
      subtitle: isQuote
          ? 'Draft price estimates and easily convert them into tax invoices.'
          : 'Official GST tax invoices, orders, and payment receipts.',
      action: EmpiranButton(
        label: isQuote ? 'Create Quote' : 'Create Order / Invoice',
        icon: Icons.add_rounded,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => InvoiceComposerPage(type: widget.type)),
        ),
      ),
      child: BlocBuilder<InvoicesBloc, InvoicesState>(
        builder: (context, state) {
          if (state is InvoicesLoading || state is InvoicesInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is InvoicesFailure) {
            return Center(child: Text('Error: ${state.message}'));
          }

          final loaded = state as InvoicesLoaded;
          var displayList = loaded.transactions.where((t) {
            final matchesType = isQuote
                ? (t.type == 'quotation' || t.type == 'estimate')
                : (t.type == 'order' ||
                    t.type == 'sale_invoice' ||
                    t.type == 'invoice');
            final matchesQuery = _searchController.text.isEmpty ||
                t.number
                    .toLowerCase()
                    .contains(_searchController.text.toLowerCase()) ||
                t.partyName
                    .toLowerCase()
                    .contains(_searchController.text.toLowerCase());
            final matchesStatus = _status == 'All' ||
                t.status.toLowerCase() == _status.toLowerCase();
            final matchesRange = _range == null ||
                (!t.date.isBefore(_range!.start) &&
                    t.date.isBefore(_range!.end.add(const Duration(days: 1))));
            return matchesType && matchesQuery && matchesStatus && matchesRange;
          }).toList();
          displayList.sort((a, b) => b.date.compareTo(a.date));

          return Column(
            children: [
              // Search & Filter Row
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 680;
                  final searchField = EmpiranTextField(
                    controller: _searchController,
                    label: '',
                    hint: 'Search by document # or customer name...',
                    prefixIcon: Icons.search_rounded,
                    onChanged: (_) => setState(() {}),
                  );

                  final filterChipsAndDate = SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final s in ['All', 'Paid', 'Unpaid'])
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text(s),
                              selected: _status == s,
                              onSelected: (_) => setState(() => _status = s),
                            ),
                          ),
                        const SizedBox(width: 6),
                        TextButton.icon(
                          icon: const Icon(Icons.date_range_outlined, size: 18),
                          label: Text(_range == null
                              ? 'Filter Dates'
                              : '${DateFormat.MMMd().format(_range!.start)} - ${DateFormat.MMMd().format(_range!.end)}'),
                          onPressed: () async {
                            final val = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (val != null) setState(() => _range = val);
                          },
                        ),
                        if (_range != null)
                          IconButton(
                            tooltip: 'Clear Date Filter',
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _range = null),
                          ),
                      ],
                    ),
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        searchField,
                        const SizedBox(height: 10),
                        filterChipsAndDate,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: searchField),
                      const SizedBox(width: 12),
                      filterChipsAndDate,
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              // Transaction List
              Expanded(
                child: displayList.isEmpty
                    ? EmpiranEmptyState(
                        title:
                            'No ${isQuote ? "quotations" : "orders/invoices"} found',
                        description:
                            'Create a new document to begin transactions.',
                        icon: Icons.receipt_long_outlined,
                        actionLabel: isQuote ? 'Create Quote' : 'Create Order',
                        onAction: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  InvoiceComposerPage(type: widget.type)),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          context
                              .read<InvoicesBloc>()
                              .add(const LoadInvoicesRequested());
                          await Future.delayed(
                              const Duration(milliseconds: 500));
                        },
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: displayList.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final t = displayList[i];
                            final isPaid = t.status.toLowerCase() == 'paid';
                            final isOrder = t.type == 'order';

                            return LayoutBuilder(
                              builder: (context, cardConstraints) {
                                final isCompact =
                                    cardConstraints.maxWidth < 900;

                                final detailsColumn = Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          t.number,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: (isPaid
                                                    ? AppColors.success
                                                    : AppColors.warning)
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            t.status.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isPaid
                                                  ? AppColors.success
                                                  : AppColors.warning,
                                            ),
                                          ),
                                        ),
                                        if (t.isGst)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: const Text('GST 18%',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: AppColors.primary,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ),
                                        if (t.discount > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.success
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                                'Disc: -${Formatters.money(t.discount)}',
                                                style: const TextStyle(
                                                    fontSize: 10,
                                                    color: AppColors.success,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ),
                                        if (isOrder)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.deepPurple
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: const Text('ORDER',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.deepPurple,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${t.partyName.isNotEmpty ? t.partyName : 'Cash Customer'} • ${Formatters.date(t.date)} • ${t.lines.length} items',
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                );

                                final actions = [
                                  IconButton(
                                    tooltip: isQuote
                                        ? 'View Quotation'
                                        : 'View Order',
                                    icon: const Icon(Icons.visibility_outlined,
                                        color: AppColors.primary),
                                    onPressed: () =>
                                        showDocumentPreviewDialog(context, t),
                                  ),
                                  IconButton(
                                    tooltip: isQuote
                                        ? 'Edit / Update Quotation'
                                        : 'Edit / Update Order',
                                    icon: const Icon(Icons.edit_outlined,
                                        color: AppColors.secondary),
                                    onPressed: () => _editTransaction(t),
                                  ),
                                  IconButton(
                                    tooltip: isQuote
                                        ? 'Customize Quotation'
                                        : (isOrder
                                            ? 'Customize Order'
                                            : 'Customize Invoice'),
                                    icon: const Icon(Icons.palette_outlined,
                                        color: AppColors.primary),
                                    onPressed: () => showDocumentPreviewDialog(
                                      context,
                                      t,
                                      initiallyCustomize: true,
                                    ),
                                  ),
                                  // Convert Invoice to Order (Requirement 3)
                                  if (!isOrder && !isQuote)
                                    IconButton(
                                      tooltip: 'Convert Invoice to Order',
                                      icon: const Icon(
                                          Icons.shopping_bag_outlined,
                                          color: AppColors.primary),
                                      onPressed: () => _convertToOrder(t),
                                    ),
                                  if (isQuote)
                                    IconButton(
                                      tooltip: 'Convert to order',
                                      icon: const Icon(Icons.transform_rounded,
                                          color: AppColors.secondary),
                                      onPressed: () =>
                                          Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => InvoiceComposerPage(
                                              type: 'order', source: t),
                                        ),
                                      ),
                                    ),
                                  // Product Return option on Orders (Requirement 4)
                                  if (isOrder)
                                    IconButton(
                                      tooltip: 'Product Return',
                                      icon: const Icon(
                                          Icons.assignment_return_outlined,
                                          color: AppColors.warning),
                                      onPressed: () =>
                                          showProductReturnDialog(context, t),
                                    ),
                                  IconButton(
                                    tooltip: 'WhatsApp Direct',
                                    icon: const Icon(Icons.chat_outlined,
                                        color: Color(0xFF25D366)),
                                    onPressed: () => _shareWhatsApp(t),
                                  ),
                                  IconButton(
                                    tooltip: isQuote
                                        ? 'Share Quotation'
                                        : (isOrder
                                            ? 'Share Order'
                                            : 'Share Invoice'),
                                    icon: const Icon(Icons.share_outlined,
                                        color: AppColors.primary),
                                    onPressed: () => _shareDocument(t),
                                  ),
                                  IconButton(
                                    tooltip: 'View & Print PDF',
                                    icon: const Icon(Icons.print_outlined),
                                    onPressed: () =>
                                        showDocumentPreviewDialog(context, t),
                                  ),
                                  IconButton(
                                    tooltip: 'Thermal Receipt (80mm)',
                                    icon:
                                        const Icon(Icons.receipt_long_outlined),
                                    onPressed: () => showDocumentPreviewDialog(
                                        context, t,
                                        isThermal: true),
                                  ),
                                  if (isQuote)
                                    IconButton(
                                      tooltip: 'Delete Quotation',
                                      icon: const Icon(Icons.delete_outline,
                                          color: AppColors.error),
                                      onPressed: () => _deleteQuotation(t),
                                    ),
                                  // Delete Order option (Requirement 4)
                                  if (isOrder)
                                    IconButton(
                                      tooltip: 'Delete Order',
                                      icon: const Icon(Icons.delete_outline,
                                          color: AppColors.error),
                                      onPressed: () => _deleteOrder(t),
                                    ),
                                ];

                                if (isCompact) {
                                  return EmpiranCard(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: AppColors.primary
                                                  .withValues(alpha: 0.1),
                                              radius: 18,
                                              child: Icon(
                                                isQuote
                                                    ? Icons
                                                        .request_quote_outlined
                                                    : (isOrder
                                                        ? Icons
                                                            .shopping_bag_outlined
                                                        : Icons
                                                            .receipt_outlined),
                                                color: AppColors.primary,
                                                size: 18,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(child: detailsColumn),
                                            const SizedBox(width: 8),
                                            Text(
                                              Formatters.money(t.total),
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 15,
                                                  color: AppColors.primary),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        const Divider(height: 1),
                                        Wrap(
                                          alignment: WrapAlignment.end,
                                          children: actions,
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                return EmpiranCard(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: AppColors.primary
                                            .withValues(alpha: 0.1),
                                        child: Icon(
                                          isQuote
                                              ? Icons.request_quote_outlined
                                              : (isOrder
                                                  ? Icons.shopping_bag_outlined
                                                  : Icons.receipt_outlined),
                                          color: AppColors.primary,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(child: detailsColumn),
                                      const SizedBox(width: 12),
                                      Text(
                                        Formatters.money(t.total),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                            color: AppColors.primary),
                                      ),
                                      const SizedBox(width: 12),
                                      ...actions,
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
