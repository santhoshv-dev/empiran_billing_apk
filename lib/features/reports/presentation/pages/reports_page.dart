import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

enum ReportRange { today, month, last30, all }

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  int _tab = 0;
  final ReportRange _range = ReportRange.all;
  DateTime? _from, _to;

  List<BusinessTransaction> _filterRows(List<BusinessTransaction> all) {
    var data = all.where((t) {
      if (_tab == 0) return true;
      if (_tab == 1) return ['order', 'sale_invoice', 'quotation', 'estimate'].contains(t.type);
      return t.paid > 0 || t.type.startsWith('payment_');
    }).toList();

    final now = DateTime.now();
    DateTime? start, end;
    if (_range == ReportRange.today) {
      start = DateTime(now.year, now.month, now.day);
      end = start.add(const Duration(days: 1));
    } else if (_range == ReportRange.month) {
      start = DateTime(now.year, now.month);
      end = DateTime(now.year, now.month + 1);
    } else if (_range == ReportRange.last30) {
      start = now.subtract(const Duration(days: 30));
      end = now.add(const Duration(days: 1));
    } else {
      start = _from;
      end = _to?.add(const Duration(days: 1));
    }

    return data.where((t) {
      return (start == null || !t.date.isBefore(start)) && (end == null || t.date.isBefore(end));
    }).toList();
  }

  Future<void> _exportCsv(List<BusinessTransaction> rows) async {
    final content = reportCsv(rows);
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            Uint8List.fromList(utf8.encode(content)),
            mimeType: 'text/csv',
          ),
        ],
        fileNameOverrides: ['empiran-report.csv'],
      ),
    );
  }

  Future<void> _printReport(Company company, List<BusinessTransaction> rows) async {
    await Printing.layoutPdf(
      onLayout: (_) => buildReportPdf(
        company,
        rows,
        ['Transaction Details', 'Sales Details', 'Payment Details'][_tab],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsState = context.watch<SettingsBloc>().state;
    final company = settingsState is SettingsLoaded ? settingsState.company : Company();

    final invoiceState = context.watch<InvoicesBloc>().state;
    final allTxns = invoiceState is InvoicesLoaded ? invoiceState.transactions : <BusinessTransaction>[];
    final rows = _filterRows(allTxns);

    final total = rows.fold<double>(0, (a, b) => a + b.total);
    final paid = rows.fold<double>(0, (a, b) => a + b.paid);
    final balance = total - paid;

    return PageFrame(
      title: 'Reports & Analytics',
      subtitle: 'Transaction breakdown, tax liabilities, and payment reconciliation.',
      child: Column(
        children: [
          // Filter Tabs & Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  for (int i = 0; i < 3; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(['All Transactions', 'Sales Only', 'Payments Only'][i]),
                        selected: _tab == i,
                        onSelected: (_) => setState(() => _tab = i),
                      ),
                    ),
                ],
              ),
              Row(
                children: [
                  EmpiranButton(
                    label: 'Export CSV',
                    icon: Icons.table_chart_outlined,
                    variant: EmpiranButtonVariant.outlined,
                    onPressed: rows.isEmpty ? null : () => _exportCsv(rows),
                  ),
                  const SizedBox(width: 8),
                  EmpiranButton(
                    label: 'Print PDF',
                    icon: Icons.print_outlined,
                    onPressed: rows.isEmpty ? null : () => _printReport(company, rows),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Summary Metrics Cards
          Row(
            children: [
              Expanded(
                child: _buildMetricCard('Total Invoiced', Formatters.money(total), AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildMetricCard('Total Collected', Formatters.money(paid), AppColors.success),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildMetricCard('Outstanding Balance', Formatters.money(balance), balance > 0 ? AppColors.error : Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Records Table
          Expanded(
            child: rows.isEmpty
                ? const EmpiranEmptyState(
                    title: 'No report data available',
                    description: 'No records found for the selected range or type.',
                    icon: Icons.analytics_outlined,
                  )
                : ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final t = rows[i];
                      return EmpiranCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Text(
                              t.number,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                '${t.partyName.isNotEmpty ? t.partyName : 'Cash Customer'} • ${Formatters.date(t.date)}',
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  Formatters.money(t.total),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  'Paid: ${Formatters.money(t.paid)}',
                                  style: const TextStyle(color: Colors.grey, fontSize: 11),
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
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, Color color) {
    return EmpiranCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lightTextSecondary)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }
}
