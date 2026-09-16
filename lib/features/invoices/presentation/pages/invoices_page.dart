import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empiran_components.dart';
import '../../../../models.dart';
import '../bloc/invoices_bloc.dart';
import '../bloc/invoices_event.dart';
import '../bloc/invoices_state.dart';
import '../widgets/document_preview_dialog.dart';
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
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open WhatsApp.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isQuote = widget.type == 'quotation';
    final title = isQuote ? 'Quotation Maker & Estimates' : 'Orders & Tax Invoices';

    return PageFrame(
      title: title,
      subtitle: isQuote
          ? 'Draft price estimates and easily convert them into tax invoices.'
          : 'Official GST tax invoices, cash memos and payment receipts.',
      action: EmpiranButton(
        label: isQuote ? 'Create Quote' : 'Create Invoice',
        icon: Icons.add_rounded,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => InvoiceComposerPage(type: widget.type)),
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
            final matchesType = t.type == widget.type || (widget.type == 'order' && t.type == 'sale_invoice');
            final matchesQuery = _searchController.text.isEmpty ||
                t.number.toLowerCase().contains(_searchController.text.toLowerCase()) ||
                t.partyName.toLowerCase().contains(_searchController.text.toLowerCase());
            final matchesStatus = _status == 'All' || t.status.toLowerCase() == _status.toLowerCase();
            final matchesRange = _range == null ||
                (!t.date.isBefore(_range!.start) && t.date.isBefore(_range!.end.add(const Duration(days: 1))));
            return matchesType && matchesQuery && matchesStatus && matchesRange;
          }).toList();

          return Column(
            children: [
              // Search & Filter Row
              Row(
                children: [
                  Expanded(
                    child: EmpiranTextField(
                      controller: _searchController,
                      label: '',
                      hint: 'Search by document # or customer name...',
                      prefixIcon: Icons.search_rounded,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  for (final s in ['All', 'Paid', 'Unpaid'])
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: FilterChip(
                        label: Text(s),
                        selected: _status == s,
                        onSelected: (_) => setState(() => _status = s),
                      ),
                    ),
                  const SizedBox(width: 10),
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
              const SizedBox(height: 16),

              // Transaction List
              Expanded(
                child: displayList.isEmpty
                    ? EmpiranEmptyState(
                        title: 'No ${isQuote ? "quotations" : "invoices"} found',
                        description: 'Create a new document to start issuing bills to clients.',
                        icon: Icons.receipt_long_outlined,
                        actionLabel: isQuote ? 'Create Quote' : 'Create Invoice',
                        onAction: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => InvoiceComposerPage(type: widget.type)),
                        ),
                      )
                    : ListView.separated(
                        itemCount: displayList.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final t = displayList[i];
                          final isPaid = t.status.toLowerCase() == 'paid';

                          return EmpiranCard(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                  child: Icon(
                                    isQuote ? Icons.request_quote_outlined : Icons.receipt_outlined,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            t.number,
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: (isPaid ? AppColors.success : AppColors.warning).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              t.status.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: isPaid ? AppColors.success : AppColors.warning,
                                              ),
                                            ),
                                          ),
                                          if (t.isGst) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text('GST 18%', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${t.partyName.isNotEmpty ? t.partyName : 'Cash Customer'} • ${Formatters.date(t.date)} • ${t.lines.length} items',
                                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  Formatters.money(t.total),
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.primary),
                                ),
                                const SizedBox(width: 16),
                                if (isQuote)
                                  IconButton(
                                    tooltip: 'Convert to Invoice',
                                    icon: const Icon(Icons.transform_rounded, color: AppColors.secondary),
                                    onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => InvoiceComposerPage(type: 'order', source: t),
                                      ),
                                    ),
                                  ),
                                IconButton(
                                  tooltip: 'WhatsApp Direct',
                                  icon: const Icon(Icons.chat_outlined, color: Color(0xFF25D366)),
                                  onPressed: () => _shareWhatsApp(t),
                                ),
                                IconButton(
                                  tooltip: 'View & Print PDF',
                                  icon: const Icon(Icons.print_outlined),
                                  onPressed: () => showDocumentPreviewDialog(context, t),
                                ),
                                IconButton(
                                  tooltip: 'Thermal Receipt (80mm)',
                                  icon: const Icon(Icons.receipt_long_outlined),
                                  onPressed: () => showDocumentPreviewDialog(context, t, isThermal: true),
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
      ),
    );
  }
}
