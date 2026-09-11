import 'package:flutter/material.dart';
import 'app_store.dart';
import 'core/services/permission_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/empiran_components.dart';
import 'models.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.store,
    required this.onNavigate,
    this.onQuickAction,
    this.onPreviewTransaction,
    this.onOpenSync,
  });

  final AppStore store;
  final ValueChanged<int> onNavigate;
  final void Function(String action)? onQuickAction;
  final void Function(BusinessTransaction t)? onPreviewTransaction;
  final VoidCallback? onOpenSync;

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    // Calculate Today's Metrics
    final todaySales = store.transactions.where((t) =>
        (t.type == 'order' || t.type == 'sale_invoice') &&
        !t.date.isBefore(todayStart) &&
        t.date.isBefore(todayEnd));
    final todaySalesTotal = todaySales.fold<double>(0, (s, t) => s + t.total);

    final todayPurchases = store.transactions.where((t) =>
        t.type == 'purchase_bill' &&
        !t.date.isBefore(todayStart) &&
        t.date.isBefore(todayEnd));
    final todayPurchasesTotal = todayPurchases.fold<double>(0, (s, t) => s + t.total);

    final totalReceivables = store.parties.fold<double>(
      0,
      (s, p) => s + store.partyBalance(p).clamp(0, double.infinity),
    );

    final lowStockItems = store.items
        .where((i) => !i.isService && i.currentStock <= i.lowStockLimit)
        .toList();

    final recentTransactions = store.transactions.take(6).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x6, vertical: AppSpacing.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SWeShare Hero Showcase Banner (Vibrant Electric Blue Gradient)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.x6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0066FF), Color(0xFF0052CC), Color(0xFF1E40AF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadii.extraLarge),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x350066FF),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, heroBox) {
                final isCompact = heroBox.maxWidth < 620;

                final textContent = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified, color: Colors.white, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                store.company.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.shield_outlined, color: Colors.white, size: 14),
                              const SizedBox(width: 5),
                              Text(
                                '${store.currentUserRole} Mode',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${_greeting()}, ${store.currentUserName}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'EMPIRAN Business Console',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Automated GST Billing, Multi-Firm Stock & Smart Sync',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                    ),
                  ],
                );

                final actions = Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    EmpiranButton(
                      label: 'Create Invoice',
                      trailingIcon: Icons.arrow_forward_rounded,
                      variant: EmpiranButtonVariant.secondary,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      height: 40,
                      onPressed: () {
                        if (onQuickAction != null) {
                          onQuickAction!('order');
                        } else {
                          onNavigate(2);
                        }
                      },
                    ),
                    EmpiranSyncIndicator(
                      isOnline: store.remoteMode,
                      isSyncing: store.syncing,
                      pendingCount: 0,
                      onTap: onOpenSync,
                    ),
                  ],
                );

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      textContent,
                      const SizedBox(height: 16),
                      actions,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: textContent),
                    const SizedBox(width: 16),
                    actions,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.x6),

          // SWeShare Quick Actions Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickActionBtn(
                  context,
                  icon: Icons.add_circle_outline,
                  label: '+ Sale Invoice',
                  color: AppColors.primary,
                  onTap: () {
                    if (onQuickAction != null) {
                      onQuickAction!('order');
                    } else {
                      onNavigate(2);
                    }
                  },
                ),
                const SizedBox(width: AppSpacing.x3),
                _buildQuickActionBtn(
                  context,
                  icon: Icons.payments_outlined,
                  label: 'Payment In',
                  color: AppColors.success,
                  onTap: () {
                    if (onQuickAction != null) {
                      onQuickAction!('payment_in');
                    } else {
                      onNavigate(2);
                    }
                  },
                ),
                if (PermissionService.canManageProducts(store.currentUserRole)) ...[
                  const SizedBox(width: AppSpacing.x3),
                  _buildQuickActionBtn(
                    context,
                    icon: Icons.inventory_2_outlined,
                    label: 'Add Product',
                    color: const Color(0xFF0284C7),
                    onTap: () {
                      if (onQuickAction != null) {
                        onQuickAction!('product');
                      } else {
                        onNavigate(3);
                      }
                    },
                  ),
                ],
                const SizedBox(width: AppSpacing.x3),
                _buildQuickActionBtn(
                  context,
                  icon: Icons.person_add_outlined,
                  label: 'Add Customer',
                  color: const Color(0xFF7C3AED),
                  onTap: () {
                    if (onQuickAction != null) {
                      onQuickAction!('customer');
                    } else {
                      onNavigate(4);
                    }
                  },
                ),
                const SizedBox(width: AppSpacing.x3),
                _buildQuickActionBtn(
                  context,
                  icon: Icons.request_quote_outlined,
                  label: 'New Quote',
                  color: const Color(0xFF0D9488),
                  onTap: () {
                    if (onQuickAction != null) {
                      onQuickAction!('quotation');
                    } else {
                      onNavigate(1);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x6),

          // SWeShare KPI Summary Cards (Support Shimmer Loading)
          if (store.syncing)
            const ShimmerStatsGrid()
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;
                final isTablet = constraints.maxWidth > 600 && constraints.maxWidth <= 900;
                final crossAxisCount = isWide ? 4 : (isTablet ? 2 : 2);
                final childAspectRatio = isWide ? 1.6 : (isTablet ? 1.7 : 1.28);

                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: AppSpacing.x4,
                  mainAxisSpacing: AppSpacing.x4,
                  childAspectRatio: childAspectRatio,
                  children: [
                    EmpiranStatCard(
                      title: 'Today\'s Sales',
                      value: AppTypography.formatCurrency(todaySalesTotal),
                      icon: Icons.receipt_long_rounded,
                      iconColor: AppColors.primary,
                      badgeText: '${todaySales.length} bills',
                      badgeType: EmpiranStatusType.info,
                      onTap: () => onNavigate(2),
                    ),
                    if (PermissionService.canViewPurchases(store.currentUserRole))
                      EmpiranStatCard(
                        title: 'Today\'s Purchases',
                        value: AppTypography.formatCurrency(todayPurchasesTotal),
                        icon: Icons.shopping_bag_rounded,
                        iconColor: const Color(0xFF0284C7),
                        badgeText: '${todayPurchases.length} bills',
                        badgeType: EmpiranStatusType.warning,
                        onTap: () => onNavigate(2),
                      )
                    else
                      EmpiranStatCard(
                        title: 'Bills Settled',
                        value: '${todaySales.length}',
                        icon: Icons.check_circle_outline_rounded,
                        iconColor: const Color(0xFF0284C7),
                        badgeText: 'Active Session',
                        badgeType: EmpiranStatusType.success,
                        onTap: () => onNavigate(2),
                      ),
                    EmpiranStatCard(
                      title: 'Receivables',
                      value: AppTypography.formatCurrency(totalReceivables),
                      icon: Icons.account_balance_wallet_rounded,
                      iconColor: AppColors.success,
                      badgeText: 'Outstanding',
                      badgeType: EmpiranStatusType.success,
                      onTap: () => onNavigate(4),
                    ),
                    EmpiranStatCard(
                      title: 'Inventory Status',
                      value: '${store.items.length} Items',
                      icon: Icons.inventory_2_rounded,
                      iconColor: lowStockItems.isNotEmpty ? AppColors.error : AppColors.primary,
                      badgeText: lowStockItems.isNotEmpty ? '${lowStockItems.length} Low Stock' : 'Optimal',
                      badgeType: lowStockItems.isNotEmpty ? EmpiranStatusType.error : EmpiranStatusType.success,
                      onTap: () => onNavigate(3),
                    ),
                  ],
                );
              },
            ),
          const SizedBox(height: AppSpacing.x8),

          // Primary Module Operations
          const EmpiranSectionHeader(
            title: 'Business Modules',
            subtitle: 'Collaborate and manage all operations effortlessly',
          ),
          const SizedBox(height: AppSpacing.x3),

          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 1050;
              final isTablet = constraints.maxWidth > 650 && constraints.maxWidth <= 1050;
              final crossAxisCount = isDesktop ? 3 : (isTablet ? 2 : 1);
              final childAspectRatio = isDesktop ? 2.1 : (isTablet ? 2.2 : 2.6);

              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: AppSpacing.x4,
                mainAxisSpacing: AppSpacing.x4,
                childAspectRatio: childAspectRatio,
                children: [
                  EmpiranFeatureCard(
                    title: 'Sales & Invoices',
                    subtitle: 'Create GST bills, orders & receipts',
                    icon: Icons.receipt_long_rounded,
                    accentColor: AppColors.primary,
                    statBadge: '${store.transactions.where((t) => t.type == 'order' || t.type == 'sale_invoice').length} sales recorded',
                    onTap: () => onNavigate(2),
                  ),
                  EmpiranFeatureCard(
                    title: 'Products & Inventory',
                    subtitle: 'Manage catalog, stock & pricing',
                    icon: Icons.inventory_2_rounded,
                    accentColor: const Color(0xFF0284C7),
                    statBadge: '${store.items.length} products listed',
                    onTap: () => onNavigate(3),
                  ),
                  EmpiranFeatureCard(
                    title: 'Customers & Suppliers',
                    subtitle: 'Ledgers, statements & GST directory',
                    icon: Icons.groups_rounded,
                    accentColor: const Color(0xFF7C3AED),
                    statBadge: '${store.parties.length} parties connected',
                    onTap: () => onNavigate(4),
                  ),
                  EmpiranFeatureCard(
                    title: 'Quotations & Estimates',
                    subtitle: 'Draft estimates & convert to orders',
                    icon: Icons.request_quote_rounded,
                    accentColor: const Color(0xFF0D9488),
                    statBadge: '${store.transactions.where((t) => t.type == 'quotation' || t.type == 'estimate').length} quotes issued',
                    onTap: () => onNavigate(1),
                  ),
                  if (PermissionService.canViewReports(store.currentUserRole))
                    EmpiranFeatureCard(
                      title: 'Reports & Analytics',
                      subtitle: 'Financial insights, GST summaries & CSV export',
                      icon: Icons.analytics_rounded,
                      accentColor: const Color(0xFFE11D48),
                      onTap: () => onNavigate(5),
                    ),
                  if (PermissionService.canAccessSettings(store.currentUserRole))
                    EmpiranFeatureCard(
                      title: 'Settings & Cloud Sync',
                      subtitle: 'Business profiles, sequences & cloud sync',
                      icon: Icons.settings_rounded,
                      accentColor: const Color(0xFF475569),
                      onTap: () => onNavigate(6),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.x8),

          // Low Stock Alert Banner (if any)
          if (lowStockItems.isNotEmpty) ...[
            EmpiranCard(
              color: const Color(0xFFFEF2F2),
              borderColor: const Color(0xFFFECACA),
              padding: const EdgeInsets.all(AppSpacing.x4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEE2E2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 22),
                  ),
                  const SizedBox(width: AppSpacing.x4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${lowStockItems.length} Products Low in Stock',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.errorDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Reorder: ${lowStockItems.take(3).map((e) => e.name).join(", ")}${lowStockItems.length > 3 ? "..." : ""}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  EmpiranButton(
                    label: 'Manage Stock',
                    height: 36,
                    variant: EmpiranButtonVariant.secondary,
                    onPressed: () => onNavigate(3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.x6),
          ],

          // Recent Activity Preview
          EmpiranSectionHeader(
            title: 'Recent Transactions',
            subtitle: 'Latest orders, invoices, and vouchers',
            action: TextButton.icon(
              onPressed: () => onNavigate(2),
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('View All'),
            ),
          ),
          const SizedBox(height: AppSpacing.x2),

          if (recentTransactions.isEmpty)
            EmpiranCard(
              padding: const EdgeInsets.all(AppSpacing.x8),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: AppColors.primarySubtle,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 28),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No transactions recorded yet',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tap "+ Sale Invoice" above to create your first bill',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentTransactions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final t = recentTransactions[i];
                final isPaid = t.status.toLowerCase() == 'paid';
                return EmpiranCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  onTap: () => onPreviewTransaction?.call(t),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primarySubtle,
                          borderRadius: BorderRadius.circular(AppRadii.medium),
                          border: Border.all(color: const Color(0xFFDCEAF9), width: 1),
                        ),
                        child: const Icon(Icons.receipt_rounded, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.partyName.isEmpty ? 'Cash Customer' : t.partyName,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${t.number} • ${t.isGst ? "GST" : "Non-GST"} • ${t.type.replaceAll('_', ' ').toUpperCase()}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            AppTypography.formatCurrency(t.total),
                            style: AppTypography.number.copyWith(fontSize: 15, color: AppColors.primaryDark),
                          ),
                          const SizedBox(height: 4),
                          EmpiranStatusChip(
                            label: t.status.toUpperCase(),
                            type: isPaid ? EmpiranStatusType.success : EmpiranStatusType.warning,
                            small: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActionBtn(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceContainer : Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : const Color(0xFFE2EDF9),
            width: 1.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x080066FF),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
