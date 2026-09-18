import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:empiran/core/routing/app_routes.dart';
import 'package:empiran/core/services/permission_service.dart';
import 'package:empiran/core/theme/app_theme.dart';
import 'package:empiran/core/utils/formatters.dart';
import 'package:empiran/core/widgets/empiran_components.dart';
import 'package:empiran/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:empiran/features/auth/presentation/bloc/auth_state.dart';
import 'package:empiran/features/invoices/presentation/bloc/invoices_bloc.dart';
import 'package:empiran/features/invoices/presentation/bloc/invoices_event.dart';
import 'package:empiran/features/invoices/presentation/bloc/invoices_state.dart';
import 'package:empiran/features/invoices/presentation/pages/invoice_composer_page.dart';
import 'package:empiran/features/invoices/presentation/widgets/document_preview_dialog.dart';
import 'package:empiran/features/parties/presentation/bloc/parties_bloc.dart';
import 'package:empiran/features/parties/presentation/bloc/parties_event.dart';
import 'package:empiran/features/parties/presentation/bloc/parties_state.dart';
import 'package:empiran/features/products/presentation/bloc/products_bloc.dart';
import 'package:empiran/features/products/presentation/bloc/products_event.dart';
import 'package:empiran/features/products/presentation/bloc/products_state.dart';
import 'package:empiran/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:empiran/features/settings/presentation/bloc/settings_state.dart';
import 'package:empiran/models.dart';

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
    final authState = context.watch<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;
    final invoiceState = context.watch<InvoicesBloc>().state;
    final productState = context.watch<ProductsBloc>().state;
    final partyState = context.watch<PartiesBloc>().state;
    final settingsState = context.watch<SettingsBloc>().state;

    final txns = invoiceState is InvoicesLoaded ? invoiceState.transactions : <BusinessTransaction>[];
    final items = productState is ProductsLoaded ? productState.items : <Item>[];
    final parties = partyState is PartiesLoaded ? partyState.parties : <Party>[];
    final companyName = settingsState is SettingsLoaded
        ? settingsState.company.displayName
        : 'Empiran Traders';

    if (PermissionService.isBiller(user?.role)) {
      return _BillerDashboard(
        companyName: companyName,
        userName: user?.name ?? 'Biller',
        greeting: _greeting(),
        onNavigate: onNavigate,
      );
    }

    if (PermissionService.isManager(user?.role)) {
      return _ManagerDashboard(
        companyName: companyName,
        userName: user?.name ?? 'Manager',
        greeting: _greeting(),
        onNavigate: onNavigate,
      );
    }

    // 1. Orders & Sales transactions
    final allOrders = txns.where((t) => t.type == 'order' || t.type == 'sale_invoice').toList();
    final totalRevenue = allOrders.fold<double>(0, (s, t) => s + t.total);

    // 2. Today's Metrics (Requirement 10)
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final todayOrders = allOrders.where((t) => !t.date.isBefore(todayStart) && !t.date.isAfter(todayEnd)).toList();
    final todaySalesAmount = todayOrders.fold<double>(0, (s, t) => s + t.total);
    final totalTransactionsCount = txns.length;

    // 3. Staff-wise Performance Aggregation (Requirement 10)
    final Map<String, ({int orderCount, double salesAmount})> staffMap = {};
    for (final order in allOrders) {
      final staff = (order.referredBy != null && order.referredBy!.trim().isNotEmpty)
          ? order.referredBy!.trim()
          : 'Admin';
      final prev = staffMap[staff] ?? (orderCount: 0, salesAmount: 0.0);
      staffMap[staff] = (
        orderCount: prev.orderCount + 1,
        salesAmount: prev.salesAmount + order.total,
      );
    }
    final staffEntries = staffMap.entries.toList()
      ..sort((a, b) => b.value.salesAmount.compareTo(a.value.salesAmount));

    // 4. Date-wise Sales Breakdown (Requirement 10)
    final Map<String, ({DateTime date, int orderCount, double salesAmount})> dateMap = {};
    for (final order in allOrders) {
      final key = DateFormat('yyyy-MM-dd').format(order.date);
      final prev = dateMap[key] ?? (date: order.date, orderCount: 0, salesAmount: 0.0);
      dateMap[key] = (
        date: prev.date,
        orderCount: prev.orderCount + 1,
        salesAmount: prev.salesAmount + order.total,
      );
    }
    final dateEntries = dateMap.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    // Inventory & Party metrics
    final totalReceivables = parties
        .where((p) => p.balance > 0)
        .fold<double>(0, (s, p) => s + p.balance);
    final lowStockItems = items.where((i) => !i.isService && i.currentStock <= i.lowStockLimit).toList();
    final recentTxns = txns.take(6).toList();

    return LayoutBuilder(
      builder: (context, rootConstraints) {
        final isCompact = rootConstraints.maxWidth < 650;

        return RefreshIndicator(
          onRefresh: () async {
            context.read<InvoicesBloc>().add(const LoadInvoicesRequested());
            context.read<ProductsBloc>().add(const LoadProductsRequested());
            context.read<PartiesBloc>().add(const LoadPartiesRequested());
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 14 : 24,
              vertical: isCompact ? 14 : 20,
            ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting & Actions Header
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
                        'Admin Sales Dashboard: monitor daily sales, orders, and staff performance.',
                        style: TextStyle(fontSize: 13, color: AppColors.lightTextSecondary),
                      ),
                    ],
                  );

                  final newOrderBtn = EmpiranButton(
                    label: 'New Order',
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
                        newOrderBtn,
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: greetingCol),
                      const SizedBox(width: 12),
                      newOrderBtn,
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // Admin Sales Metrics Grid (Requirement 10)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 780;

                  final cards = [
                    _buildStatCard(
                      'Today\'s Orders',
                      '${todayOrders.length}',
                      'Placed today',
                      Icons.shopping_bag_outlined,
                      AppColors.primary,
                    ),
                    _buildStatCard(
                      'Today\'s Sales',
                      Formatters.money(todaySalesAmount),
                      'Revenue today',
                      Icons.currency_rupee_rounded,
                      AppColors.success,
                    ),
                    _buildStatCard(
                      'Total Transactions',
                      '$totalTransactionsCount',
                      'Orders, bills, receipts',
                      Icons.receipt_long_outlined,
                      AppColors.secondary,
                    ),
                    _buildStatCard(
                      'All-Time Sales',
                      Formatters.money(totalRevenue),
                      '${allOrders.length} total orders',
                      Icons.trending_up_rounded,
                      Colors.indigo,
                    ),
                  ];

                  if (isWide) {
                    return Row(
                      children: cards
                          .map((c) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 5),
                                  child: c,
                                ),
                              ))
                          .toList(),
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
              const SizedBox(height: 24),

              // Staff Performance Section (Requirement 10)
              EmpiranCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.badge_outlined, size: 20, color: AppColors.primary),
                            SizedBox(width: 8),
                            Text(
                              'Staff Performance & Order Attribution',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Text(
                          '${staffEntries.length} active members',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Track which admin or staff member created each order and how many sales they generated.',
                      style: TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
                    ),
                    const SizedBox(height: 16),
                    if (staffEntries.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text('No orders created yet to evaluate staff performance.',
                              style: TextStyle(color: Colors.grey)),
                        ),
                      )
                    else
                      LayoutBuilder(
                        builder: (context, sConstraints) {
                          final isNarrow = sConstraints.maxWidth < 600;

                          if (isNarrow) {
                            return Column(
                              children: staffEntries.map((e) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                                        child: Text(
                                          e.key.isNotEmpty ? e.key[0].toUpperCase() : 'S',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                            Text('${e.value.orderCount} orders created', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        Formatters.money(e.value.salesAmount),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            );
                          }

                          return Table(
                            columnWidths: const {
                              0: FlexColumnWidth(3),
                              1: FlexColumnWidth(2),
                              2: FlexColumnWidth(2),
                              3: FlexColumnWidth(2),
                            },
                            children: [
                              TableRow(
                                decoration: BoxDecoration(
                                  color: AppColors.lightSurfaceContainer,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                children: const [
                                  Padding(padding: EdgeInsets.all(10), child: Text('Staff / Admin Member', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                  Padding(padding: EdgeInsets.all(10), child: Text('Orders Created', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                  Padding(padding: EdgeInsets.all(10), child: Text('Total Sales', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                  Padding(padding: EdgeInsets.all(10), child: Text('Avg. Ticket', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                ],
                              ),
                              ...staffEntries.map((e) {
                                final avgTicket = e.value.orderCount > 0 ? e.value.salesAmount / e.value.orderCount : 0.0;
                                return TableRow(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 14,
                                            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                                            child: Text(
                                              e.key.isNotEmpty ? e.key[0].toUpperCase() : 'S',
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              e.key,
                                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                      child: Text(
                                        '${e.value.orderCount}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                      child: Text(
                                        Formatters.money(e.value.salesAmount),
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                      child: Text(
                                        Formatters.money(avgTicket),
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Date-Wise Sales Breakdown & Recent Orders Split (Requirement 10)
              LayoutBuilder(
                builder: (context, splitConstraints) {
                  final isSplitWide = splitConstraints.maxWidth >= 850;

                  final dateWiseSalesCard = EmpiranCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(Icons.calendar_month_outlined, size: 20, color: AppColors.primary),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Sales & Orders by Date',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                            ),
                            TextButton(
                              onPressed: () => onNavigate(ShellRoute.reports),
                              child: const Text('Export →'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (dateEntries.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(child: Text('No order history available.', style: TextStyle(color: Colors.grey))),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: dateEntries.take(7).length,
                            separatorBuilder: (_, __) => const Divider(height: 12),
                            itemBuilder: (context, i) {
                              final d = dateEntries[i];
                              return Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      DateFormat('dd-MMM').format(d.date),
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      '${d.orderCount} order${d.orderCount > 1 ? "s" : ""}',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Text(
                                    Formatters.money(d.salesAmount),
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.primary),
                                  ),
                                ],
                              );
                            },
                          ),
                      ],
                    ),
                  );

                  final recentOrdersCard = EmpiranCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(Icons.receipt_long_outlined, size: 20, color: AppColors.primary),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Recent Orders & Invoices',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                            ),
                            TextButton(
                              onPressed: () => onNavigate(ShellRoute.invoices),
                              child: const Text('Manage →'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (recentTxns.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(child: Text('No transactions recorded yet.', style: TextStyle(color: Colors.grey))),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: recentTxns.length,
                            separatorBuilder: (_, __) => const Divider(height: 14),
                            itemBuilder: (context, i) {
                              final t = recentTxns[i];
                              final staffWhoCreated = (t.referredBy != null && t.referredBy!.isNotEmpty)
                                  ? t.referredBy!
                                  : 'Admin';

                              return InkWell(
                                onTap: () => showDocumentPreviewDialog(context, t),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                      child: const Icon(Icons.receipt_outlined, size: 16, color: AppColors.primary),
                                    ),
                                    const SizedBox(width: 10),
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
                                            '${t.partyName.isNotEmpty ? t.partyName : "Cash Customer"} • By: $staffWhoCreated',
                                            style: const TextStyle(color: Colors.grey, fontSize: 11),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      Formatters.money(t.total),
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primary),
                                    ),
                                  ],
                                ),
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
                        Expanded(flex: 5, child: dateWiseSalesCard),
                        const SizedBox(width: 20),
                        Expanded(flex: 5, child: recentOrdersCard),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      dateWiseSalesCard,
                      const SizedBox(height: 16),
                      recentOrdersCard,
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // Inventory & Receivables Status
              LayoutBuilder(
                builder: (context, invConstraints) {
                  final isWide = invConstraints.maxWidth >= 700;

                  final lowStockCard = EmpiranCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Low Stock Alerts', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            TextButton(
                              onPressed: () => onNavigate(ShellRoute.products),
                              child: const Text('Inventory →'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (lowStockItems.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_outline, color: AppColors.success, size: 18),
                                SizedBox(width: 8),
                                Text('All items adequately stocked.', style: TextStyle(color: AppColors.success, fontSize: 13)),
                              ],
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: lowStockItems.take(4).length,
                            separatorBuilder: (_, __) => const Divider(height: 10),
                            itemBuilder: (context, i) {
                              final item = lowStockItems[i];
                              final isOut = item.currentStock <= 0;
                              return Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (isOut ? AppColors.error : AppColors.warning).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${item.currentStock.toInt()} ${item.unit}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
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

                  final receivablesCard = EmpiranCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Customer Receivables', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            TextButton(
                              onPressed: () => onNavigate(ShellRoute.parties),
                              child: const Text('Parties →'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          Formatters.money(totalReceivables),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.warning),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${parties.where((p) => p.balance > 0).length} customer accounts with outstanding balances',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  );

                  if (isWide) {
                    return Row(
                      children: [
                        Expanded(child: lowStockCard),
                        const SizedBox(width: 16),
                        Expanded(child: receivablesCard),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      lowStockCard,
                      const SizedBox(height: 14),
                      receivablesCard,
                    ],
                  );
                },
              ),
            ],
          ),
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
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.lightTextSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
}

class _BillerDashboard extends StatelessWidget {
  const _BillerDashboard({
    required this.companyName,
    required this.userName,
    required this.greeting,
    required this.onNavigate,
  });

  final String companyName;
  final String userName;
  final String greeting;
  final ValueChanged<ShellRoute> onNavigate;

  @override
  Widget build(BuildContext context) {
    final options = [
      _BillerAction(
        title: 'Quotation',
        subtitle: 'Create and manage customer quotations.',
        icon: Icons.description_outlined,
        route: ShellRoute.quotations,
      ),
      _BillerAction(
        title: 'Sales',
        subtitle: 'Create bills and review sales invoices.',
        icon: Icons.point_of_sale_outlined,
        route: ShellRoute.invoices,
      ),
      _BillerAction(
        title: 'Products',
        subtitle: 'View product details and selling prices.',
        icon: Icons.inventory_2_outlined,
        route: ShellRoute.products,
      ),
      _BillerAction(
        title: 'Settings',
        subtitle: 'Update your account password.',
        icon: Icons.settings_outlined,
        route: ShellRoute.settings,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 720;
        final cardWidth = isCompact
            ? constraints.maxWidth
            : (constraints.maxWidth - 32) / (constraints.maxWidth >= 1060 ? 4 : 2);

        return SingleChildScrollView(
          padding: EdgeInsets.all(isCompact ? 16 : 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isCompact ? 24 : 32),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      right: -30,
                      bottom: -40,
                      child: Opacity(
                        opacity: 0.15,
                        child: Icon(
                          Icons.room_service_rounded,
                          size: isCompact ? 140 : 200,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: CircleAvatar(
                            radius: isCompact ? 36 : 46,
                            backgroundColor: Colors.white,
                            child: const Icon(
                              Icons.person_rounded,
                              size: 50,
                              color: Color(0xFF7C3AED),
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$greeting,',
                                style: TextStyle(
                                  fontSize: isCompact ? 16 : 20,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                userName.trim().isEmpty ? 'Biller' : userName,
                                style: TextStyle(
                                  fontSize: isCompact ? 32 : 44,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.workspace_premium_rounded, size: 16, color: Colors.white),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        companyName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final option in options)
                    SizedBox(
                      width: cardWidth,
                      child: _BillerOptionCard(
                        action: option,
                        onPressed: () => onNavigate(option.route),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ManagerDashboard extends StatelessWidget {
  const _ManagerDashboard({
    required this.companyName,
    required this.userName,
    required this.greeting,
    required this.onNavigate,
  });

  final String companyName;
  final String userName;
  final String greeting;
  final ValueChanged<ShellRoute> onNavigate;

  @override
  Widget build(BuildContext context) {
    final options = [
      _BillerAction(
        title: 'Quotation',
        subtitle: 'Start a new customer quotation.',
        icon: Icons.note_add_outlined,
        route: ShellRoute.quotationComposer,
      ),
      _BillerAction(
        title: 'Sales',
        subtitle: 'Create and manage sales invoices.',
        icon: Icons.point_of_sale_outlined,
        route: ShellRoute.invoices,
      ),
      _BillerAction(
        title: 'Products',
        subtitle: 'Manage products, pricing, and stock.',
        icon: Icons.inventory_2_outlined,
        route: ShellRoute.products,
      ),
      _BillerAction(
        title: 'Quotes',
        subtitle: 'Review and update saved quotations.',
        icon: Icons.request_quote_outlined,
        route: ShellRoute.quotations,
      ),
      _BillerAction(
        title: 'Settings',
        subtitle: 'Update your account password.',
        icon: Icons.lock_reset_rounded,
        route: ShellRoute.settings,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 720;
        final columns = constraints.maxWidth >= 1120
            ? 3
            : constraints.maxWidth >= 760
                ? 2
                : 1;
        final cardWidth =
            columns == 1 ? constraints.maxWidth : (constraints.maxWidth - (16 * (columns - 1))) / columns;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isCompact ? 16 : 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isCompact ? 24 : 32),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      right: -30,
                      bottom: -40,
                      child: Opacity(
                        opacity: 0.15,
                        child: Icon(
                          Icons.insights_rounded,
                          size: isCompact ? 140 : 200,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: CircleAvatar(
                            radius: isCompact ? 36 : 46,
                            backgroundColor: Colors.white,
                            child: const Icon(
                              Icons.manage_accounts_rounded,
                              size: 50,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$greeting,',
                                style: TextStyle(
                                  fontSize: isCompact ? 16 : 20,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                userName.trim().isEmpty ? 'Manager' : userName,
                                style: TextStyle(
                                  fontSize: isCompact ? 32 : 44,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.business_rounded, size: 16, color: Colors.white),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        companyName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final option in options)
                    SizedBox(
                      width: cardWidth,
                      child: _BillerOptionCard(
                        action: option,
                        onPressed: () => onNavigate(option.route),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BillerAction {
  const _BillerAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final ShellRoute route;
}

class _BillerOptionCard extends StatefulWidget {
  const _BillerOptionCard({
    required this.action,
    required this.onPressed,
  });

  final _BillerAction action;
  final VoidCallback onPressed;

  @override
  State<_BillerOptionCard> createState() => _BillerOptionCardState();
}

class _BillerOptionCardState extends State<_BillerOptionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _isHovered ? -5 : 0, 0),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Container(
            constraints: const BoxConstraints(minHeight: 220),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isHovered ? AppColors.primary.withValues(alpha: 0.5) : Colors.grey.withValues(alpha: 0.15),
                width: _isHovered ? 2 : 1,
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  right: -20,
                  bottom: -20,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _isHovered ? 0.15 : 0.05,
                    child: Icon(
                      widget.action.icon,
                      size: 120,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(widget.action.icon, size: 28, color: AppColors.primary),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      widget.action.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.action.subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Text(
                          'Open ${widget.action.title}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _isHovered ? AppColors.primary : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 4),
                        AnimatedPadding(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.only(left: _isHovered ? 6 : 0),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: _isHovered ? AppColors.primary : Colors.grey,
                          ),
                        ),
                      ],
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
}
