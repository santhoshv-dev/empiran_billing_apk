import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:empiran/core/routing/app_routes.dart';
import 'package:empiran/core/theme/app_theme.dart';
import 'package:empiran/core/utils/formatters.dart';
import 'package:empiran/core/widgets/empiran_components.dart';
import 'package:empiran/features/invoices/presentation/bloc/invoices_bloc.dart';
import 'package:empiran/features/invoices/presentation/bloc/invoices_state.dart';
import 'package:empiran/features/invoices/presentation/pages/invoice_composer_page.dart';
import 'package:empiran/features/invoices/presentation/widgets/document_preview_dialog.dart';
import 'package:empiran/features/parties/presentation/bloc/parties_bloc.dart';
import 'package:empiran/features/parties/presentation/bloc/parties_state.dart';
import 'package:empiran/features/parties/presentation/widgets/party_dialog.dart';
import 'package:empiran/features/products/presentation/bloc/products_bloc.dart';
import 'package:empiran/features/products/presentation/bloc/products_state.dart';
import 'package:empiran/features/products/presentation/widgets/product_dialog.dart';
import 'package:empiran/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:empiran/features/settings/presentation/bloc/settings_state.dart';

class DashboardPage extends StatelessWidget {
  final ValueChanged<ShellRoute> onNavigate;

  const DashboardPage({super.key, required this.onNavigate});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final invoiceState = context.watch<InvoicesBloc>().state;
    final productState = context.watch<ProductsBloc>().state;
    final partyState = context.watch<PartiesBloc>().state;
    final settingsState = context.watch<SettingsBloc>().state;

    final txns = invoiceState is InvoicesLoaded ? invoiceState.transactions : [];
    final items = productState is ProductsLoaded ? productState.items : [];
    final parties = partyState is PartiesLoaded ? partyState.parties : [];
    final companyName = settingsState is SettingsLoaded
        ? settingsState.company.displayName
        : 'Empiran Traders';

    // Calculate metrics
    final salesOrders = txns.where((t) => t.type == 'order' || t.type == 'sale_invoice').toList();
    final totalRevenue = salesOrders.fold<double>(0, (s, t) => s + t.total);
    final totalReceivables = parties
        .where((p) => p.balance > 0)
        .fold<double>(0, (s, p) => s + p.balance);
    final totalPayables = parties
        .where((p) => p.balance < 0)
        .fold<double>(0, (s, p) => s + p.balance.abs());
    final lowStockItems = items.where((i) => !i.isService && i.currentStock <= i.lowStockLimit).toList();
    final recentTxns = txns.take(5).toList();

    return LayoutBuilder(
      builder: (context, rootConstraints) {
        final isCompact = rootConstraints.maxWidth < 650;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 14 : 24,
            vertical: isCompact ? 14 : 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting & Quick Summary
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 550;
                  final greetingCol = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_greeting()}, $companyName',
                        style: TextStyle(
                          fontSize: isNarrow ? 20 : 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Here is your business performance and inventory status.',
                        style: TextStyle(fontSize: 13, color: AppColors.lightTextSecondary),
                      ),
                    ],
                  );

                  final newInvoiceBtn = EmpiranButton(
                    label: 'New Invoice',
                    icon: Icons.add_rounded,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const InvoiceComposerPage(type: 'order')),
                    ),
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        greetingCol,
                        const SizedBox(height: 12),
                        newInvoiceBtn,
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: greetingCol),
                      const SizedBox(width: 12),
                      newInvoiceBtn,
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // Key Metrics Grid
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 780;

                  final cards = [
                    _buildStatCard(
                      'Total Revenue',
                      Formatters.money(totalRevenue),
                      '${salesOrders.length} sales issued',
                      Icons.currency_rupee_rounded,
                      AppColors.primary,
                    ),
                    _buildStatCard(
                      'Receivables',
                      Formatters.money(totalReceivables),
                      'Pending customer balances',
                      Icons.trending_up_rounded,
                      AppColors.success,
                    ),
                    _buildStatCard(
                      'Payables',
                      Formatters.money(totalPayables),
                      'Pending vendor payments',
                      Icons.trending_down_rounded,
                      AppColors.warning,
                    ),
                    _buildStatCard(
                      'Catalog Items',
                      '${items.length}',
                      '${lowStockItems.length} low stock alerts',
                      Icons.inventory_2_outlined,
                      AppColors.secondary,
                    ),
                  ];

                  if (isWide) {
                    return Row(
                      children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: c))).toList(),
                    );
                  } else {
                    final cardWidth = constraints.maxWidth < 420
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: cards.map((c) => SizedBox(width: cardWidth, child: c)).toList(),
                    );
                  }
                },
              ),
              const SizedBox(height: 28),

              // Quick Action Launchpad
              const Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 780;

                  final actionItems = [
                    _buildQuickAction(
                      context,
                      'Create Invoice',
                      Icons.receipt_long_outlined,
                      () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InvoiceComposerPage(type: 'order'))),
                    ),
                    _buildQuickAction(
                      context,
                      'Create Quote',
                      Icons.request_quote_outlined,
                      () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InvoiceComposerPage(type: 'quotation'))),
                    ),
                    _buildQuickAction(
                      context,
                      'Add Product',
                      Icons.inventory_2_outlined,
                      () => showProductDialog(context),
                    ),
                    _buildQuickAction(
                      context,
                      'Add Customer',
                      Icons.person_add_outlined,
                      () => showPartyDialog(context),
                    ),
                  ];

                  if (isWide) {
                    return Row(
                      children: actionItems.map((a) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: a))).toList(),
                    );
                  } else {
                    final itemWidth = (constraints.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: actionItems.map((a) => SizedBox(width: itemWidth, child: a)).toList(),
                    );
                  }
                },
              ),
              const SizedBox(height: 28),

              // Recent Invoices & Low Stock Split
              LayoutBuilder(
                builder: (context, splitConstraints) {
                  final isSplitWide = splitConstraints.maxWidth >= 850;

                  final recentTransactionsCard = EmpiranCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Recent Transactions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            TextButton(
                              onPressed: () => onNavigate(ShellRoute.invoices),
                              child: const Text('View All →'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (recentTxns.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 36),
                            child: Center(
                              child: Text('No transactions recorded yet.', style: TextStyle(color: Colors.grey)),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: recentTxns.length,
                            separatorBuilder: (_, __) => const Divider(height: 16),
                            itemBuilder: (context, i) {
                              final t = recentTxns[i];
                              return InkWell(
                                onTap: () => showDocumentPreviewDialog(context, t),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                      child: const Icon(Icons.receipt_outlined, size: 18, color: AppColors.primary),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            t.number,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            '${t.partyName.isNotEmpty ? t.partyName : 'Cash Customer'} • ${Formatters.date(t.date)}',
                                            style: const TextStyle(color: Colors.grey, fontSize: 11),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      Formatters.money(t.total),
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primary),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  );

                  final lowStockCard = EmpiranCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Low Stock Alerts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            TextButton(
                              onPressed: () => onNavigate(ShellRoute.products),
                              child: const Text('Manage →'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (lowStockItems.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 36),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_outline, color: AppColors.success, size: 18),
                                  SizedBox(width: 8),
                                  Text('All inventory is well stocked.', style: TextStyle(color: AppColors.success, fontSize: 13)),
                                ],
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: lowStockItems.take(5).length,
                            separatorBuilder: (_, __) => const Divider(height: 12),
                            itemBuilder: (context, i) {
                              final item = lowStockItems[i];
                              final isOut = item.currentStock <= 0;
                              return Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text('Min limit: ${item.lowStockLimit.toInt()} ${item.unit}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (isOut ? AppColors.error : AppColors.warning).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(AppRadii.small),
                                    ),
                                    child: Text(
                                      '${item.currentStock.toInt()} ${item.unit}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: isOut ? AppColors.error : AppColors.warning,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                      ],
                    ),
                  );

                  if (isSplitWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: recentTransactionsCard),
                        const SizedBox(width: 20),
                        Expanded(flex: 4, child: lowStockCard),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      recentTransactionsCard,
                      const SizedBox(height: 16),
                      lowStockCard,
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, String subtitle, IconData icon, Color color) {
    return EmpiranCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.lightTextSecondary)),
              CircleAvatar(
                radius: 16,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primary)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildQuickAction(BuildContext context, String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.medium),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.medium),
          border: Border.all(color: AppColors.lightBorder),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.lightTextPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
