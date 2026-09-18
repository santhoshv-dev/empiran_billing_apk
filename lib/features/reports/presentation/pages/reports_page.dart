import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:empiran/core/theme/app_theme.dart';
import 'package:empiran/core/utils/formatters.dart';
import 'package:empiran/core/utils/invoice_pdf_service.dart';
import 'package:empiran/core/widgets/empiran_components.dart';
import 'package:empiran/features/invoices/presentation/bloc/invoices_bloc.dart';
import 'package:empiran/features/invoices/presentation/bloc/invoices_state.dart';
import 'package:empiran/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:empiran/features/settings/presentation/bloc/settings_state.dart';
import 'package:empiran/models.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  int _tab = 0; // 0: All Transactions, 1: Sales Only, 2: Payments Only
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    // Default to current month range (e.g. 01-09-2026 to 17-09-2026)
    final now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, 1);
    _toDate = now;
  }

  List<BusinessTransaction> _filterRows(List<BusinessTransaction> all) {
    var data = all.where((t) {
      if (_tab == 0) return true;
      if (_tab == 1)
        return ['order', 'sale_invoice', 'quotation', 'estimate']
            .contains(t.type);
      return t.paid > 0 || t.type.startsWith('payment_');
    }).toList();

    final start = _fromDate != null
        ? DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day)
        : null;
    final end = _toDate != null
        ? DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59)
        : null;

    return data.where((t) {
      return (start == null || !t.date.isBefore(start)) &&
          (end == null || !t.date.isAfter(end));
    }).toList();
  }

  Future<void> _exportCsv(List<BusinessTransaction> rows) async {
    final content = reportCsv(rows);
    final fromStr = _fromDate != null
        ? DateFormat('dd-MM-yyyy').format(_fromDate!)
        : 'start';
    final toStr =
        _toDate != null ? DateFormat('dd-MM-yyyy').format(_toDate!) : 'end';
    final filename = 'sales_transactions_${fromStr}_to_$toStr.csv';

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            Uint8List.fromList(utf8.encode(content)),
            mimeType: 'text/csv',
          ),
        ],
        fileNameOverrides: [filename],
      ),
    );
  }

  Future<void> _printReport(
      Company company, List<BusinessTransaction> rows) async {
    final reportTitle =
        ['Transaction Details', 'Sales Details', 'Payment Details'][_tab];
    final fromStr = _fromDate != null
        ? DateFormat('dd-MM-yyyy').format(_fromDate!)
        : 'Beginning';
    final toStr =
        _toDate != null ? DateFormat('dd-MM-yyyy').format(_toDate!) : 'Present';

    await Printing.layoutPdf(
      onLayout: (_) => buildReportPdf(
        company,
        rows,
        '$reportTitle ($fromStr to $toStr)',
      ),
    );
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked;
        if (_toDate != null && _toDate!.isBefore(_fromDate!)) {
          _toDate = _fromDate;
        }
      });
    }
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: _fromDate ?? DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _toDate = picked);
    }
  }

  void _setQuickRange(String type) {
    final now = DateTime.now();
    setState(() {
      if (type == 'today') {
        _fromDate = DateTime(now.year, now.month, now.day);
        _toDate = now;
      } else if (type == 'month') {
        _fromDate = DateTime(now.year, now.month, 1);
        _toDate = now;
      } else if (type == 'last30') {
        _fromDate = now.subtract(const Duration(days: 30));
        _toDate = now;
      } else {
        _fromDate = null;
        _toDate = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settingsState = context.watch<SettingsBloc>().state;
    final company =
        settingsState is SettingsLoaded ? settingsState.company : Company();

    final invoiceState = context.watch<InvoicesBloc>().state;
    final allTxns = invoiceState is InvoicesLoaded
        ? invoiceState.transactions
        : <BusinessTransaction>[];
    final rows = _filterRows(allTxns);

    final total = rows.fold<double>(0, (a, b) => a + b.total);
    final paid = rows.fold<double>(0, (a, b) => a + b.paid);
    final balance = total - paid;

    final dateFmt = DateFormat('dd-MM-yyyy');

    return PageFrame(
      title: 'Reports & Export',
      subtitle:
          'Export transactions and sales data based on custom date range.',
      child: Column(
        children: [
          // Date Range Selection & Quick Filters Card (Requirement 9)
          EmpiranCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.date_range_rounded,
                        size: 20, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Select Date-to-Date Export Range',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 640;

                    final fromBtn = InkWell(
                      onTap: _pickFromDate,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Colors.grey.withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.circular(8),
                          color: Theme.of(context).cardColor,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined,
                                size: 16, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('From Date',
                                    style: TextStyle(
                                        fontSize: 10, color: Colors.grey)),
                                Text(
                                  _fromDate != null
                                      ? dateFmt.format(_fromDate!)
                                      : 'Select Date',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );

                    final toBtn = InkWell(
                      onTap: _pickToDate,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Colors.grey.withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.circular(8),
                          color: Theme.of(context).cardColor,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event_outlined,
                                size: 16, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('To Date',
                                    style: TextStyle(
                                        fontSize: 10, color: Colors.grey)),
                                Text(
                                  _toDate != null
                                      ? dateFmt.format(_toDate!)
                                      : 'Select Date',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );

                    final quickChips = SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ActionChip(
                            label: const Text('Today',
                                style: TextStyle(fontSize: 11)),
                            onPressed: () => _setQuickRange('today'),
                          ),
                          const SizedBox(width: 6),
                          ActionChip(
                            label: const Text('This Month',
                                style: TextStyle(fontSize: 11)),
                            onPressed: () => _setQuickRange('month'),
                          ),
                          const SizedBox(width: 6),
                          ActionChip(
                            label: const Text('Last 30 Days',
                                style: TextStyle(fontSize: 11)),
                            onPressed: () => _setQuickRange('last30'),
                          ),
                          const SizedBox(width: 6),
                          ActionChip(
                            label: const Text('All Time',
                                style: TextStyle(fontSize: 11)),
                            onPressed: () => _setQuickRange('all'),
                          ),
                        ],
                      ),
                    );

                    if (isNarrow) {
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: fromBtn),
                              const SizedBox(width: 8),
                              Expanded(child: toBtn),
                            ],
                          ),
                          const SizedBox(height: 10),
                          quickChips,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: fromBtn),
                        const SizedBox(width: 10),
                        Expanded(child: toBtn),
                        const SizedBox(width: 14),
                        quickChips,
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Filter Tabs & Export Actions
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 680;
              final tabs = SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (int i = 0; i < 3; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text([
                            'All Transactions',
                            'Sales Only',
                            'Payments Only'
                          ][i]),
                          selected: _tab == i,
                          onSelected: (_) => setState(() => _tab = i),
                        ),
                      ),
                  ],
                ),
              );

              final actions = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  EmpiranButton(
                    label: 'Export CSV',
                    icon: Icons.table_chart_outlined,
                    variant: EmpiranButtonVariant.outlined,
                    onPressed: rows.isEmpty ? null : () => _exportCsv(rows),
                  ),
                  const SizedBox(width: 8),
                  EmpiranButton(
                    label: 'Export PDF',
                    icon: Icons.print_outlined,
                    onPressed:
                        rows.isEmpty ? null : () => _printReport(company, rows),
                  ),
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    tabs,
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: actions,
                    ),
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: tabs),
                  const SizedBox(width: 12),
                  actions,
                ],
              );
            },
          ),
          const SizedBox(height: 14),

          // Summary Metrics Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 620;
              final cards = [
                _buildMetricCard(
                  'Total Invoiced (${rows.length} records)',
                  Formatters.money(total),
                  AppColors.primary,
                ),
                _buildMetricCard('Total Collected', Formatters.money(paid),
                    AppColors.success),
                _buildMetricCard(
                    'Outstanding Balance',
                    Formatters.money(balance),
                    balance > 0 ? AppColors.error : Colors.grey),
              ];

              if (isWide) {
                return Row(
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 12),
                    Expanded(child: cards[1]),
                    const SizedBox(width: 12),
                    Expanded(child: cards[2]),
                  ],
                );
              } else {
                final cardWidth = constraints.maxWidth < 360
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 10) / 2;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: cards
                      .map((c) => SizedBox(width: cardWidth, child: c))
                      .toList(),
                );
              }
            },
          ),
          const SizedBox(height: 14),

          // Records Table
          Expanded(
            child: rows.isEmpty
                ? const EmpiranEmptyState(
                    title: 'No transactions found in this date range',
                    description:
                        'Adjust your from/to dates or clear filters to view data.',
                    icon: Icons.analytics_outlined,
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      context
                          .read<InvoicesBloc>()
                          .add(const LoadInvoicesRequested());
                      await Future.delayed(const Duration(milliseconds: 500));
                    },
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final t = rows[i];
                        return EmpiranCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          t.number,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            t.type.toUpperCase(),
                                            style: const TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primary),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${t.partyName.isNotEmpty ? t.partyName : 'Cash Customer'} • ${Formatters.date(t.date)}${t.referredBy != null && t.referredBy!.isNotEmpty ? ' • Staff: ${t.referredBy}' : ''}',
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    Formatters.money(t.total),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14),
                                  ),
                                  Text(
                                    'Paid: ${Formatters.money(t.paid)}',
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, Color color) {
    return EmpiranCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.lightTextSecondary)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }
}
