import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:empiran/core/routing/app_routes.dart';
import 'package:empiran/core/services/permission_service.dart';
import 'package:empiran/core/theme/app_theme.dart';
import 'package:empiran/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:empiran/features/auth/presentation/bloc/auth_event.dart';
import 'package:empiran/features/auth/presentation/bloc/auth_state.dart';
import 'package:empiran/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:empiran/features/invoices/presentation/pages/invoices_page.dart';
import 'package:empiran/features/parties/presentation/pages/parties_page.dart';
import 'package:empiran/features/products/presentation/pages/products_page.dart';
import 'package:empiran/features/reports/presentation/pages/reports_page.dart';
import 'package:empiran/features/search/presentation/widgets/global_search_dialog.dart';
import 'package:empiran/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:empiran/features/settings/presentation/bloc/settings_state.dart';
import 'package:empiran/features/settings/presentation/pages/settings_page.dart';

class _ShellNavItem {
  const _ShellNavItem({
    required this.route,
    required this.label,
    required this.icon,
    required this.page,
  });

  final ShellRoute route;
  final String label;
  final IconData icon;
  final Widget page;
}

class ShellPage extends StatefulWidget {
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  ShellRoute _selectedRoute = ShellRoute.dashboard;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.keyK &&
        (HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed)) {
      showGlobalSearchDialog(context, onNavigate: _selectRoute);
      return true;
    }
    return false;
  }

  void _selectRoute(ShellRoute route) {
    if (_selectedRoute == route) return;
    setState(() => _selectedRoute = route);
  }

  void _showLogoutConfirm(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    size: 36,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Sign Out',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Are you sure you want to sign out?\nAny unsaved work will be lost.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          context
                              .read<AuthBloc>()
                              .add(const AuthLogoutRequested());
                        },
                        child: const Text(
                          'Sign Out',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
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
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final authState = context.watch<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;
    final role = user?.role ?? 'Biller';

    final settingsState = context.watch<SettingsBloc>().state;
    final company =
        settingsState is SettingsLoaded ? settingsState.company : null;

    final navItems = <_ShellNavItem>[
      _ShellNavItem(
        route: ShellRoute.dashboard,
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        page: DashboardPage(onNavigate: _selectRoute),
      ),
      const _ShellNavItem(
        route: ShellRoute.quotations,
        label: 'Quotation Maker',
        icon: Icons.request_quote_outlined,
        page: InvoicesPage(type: 'quotation', key: ValueKey('quotes')),
      ),
      const _ShellNavItem(
        route: ShellRoute.invoices,
        label: 'Orders & Invoices',
        icon: Icons.receipt_long_outlined,
        page: InvoicesPage(type: 'order', key: ValueKey('orders')),
      ),
      const _ShellNavItem(
        route: ShellRoute.products,
        label: 'Products & Inventory',
        icon: Icons.inventory_2_outlined,
        page: ProductsPage(key: ValueKey('products')),
      ),
      const _ShellNavItem(
        route: ShellRoute.parties,
        label: 'Customers & Suppliers',
        icon: Icons.groups_outlined,
        page: PartiesPage(key: ValueKey('parties')),
      ),
    ];

    if (PermissionService.canViewReports(role)) {
      navItems.add(
        const _ShellNavItem(
          route: ShellRoute.reports,
          label: 'Reports',
          icon: Icons.analytics_outlined,
          page: ReportsPage(key: ValueKey('reports')),
        ),
      );
    }
    if (PermissionService.canAccessSettings(role)) {
      navItems.add(
        const _ShellNavItem(
          route: ShellRoute.settings,
          label: 'Settings & Users',
          icon: Icons.settings_outlined,
          page: SettingsPage(key: ValueKey('settings')),
        ),
      );
    }

    final selectedIndex =
        navItems.indexWhere((item) => item.route == _selectedRoute);
    final currentIndex = selectedIndex >= 0 ? selectedIndex : 0;
    final currentRoute = navItems[currentIndex].route;
    final currentLabel = navItems[currentIndex].label;
    final currentContent = IndexedStack(
      index: currentIndex,
      children: [for (final item in navItems) item.page],
    );
    final mobileNavItems = navItems.take(5).toList(growable: false);
    final mobileSelectedIndex =
        mobileNavItems.indexWhere((item) => item.route == currentRoute);

    final Widget shell = wide
        ? Scaffold(
            backgroundColor: AppColors.lightBackground,
            body: Row(
              children: [
                // Left Desktop Sidebar
                Container(
                  width: 250,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border:
                        Border(right: BorderSide(color: AppColors.lightBorder)),
                  ),
                  child: Column(
                    children: [
                      // App Branding Header
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 24),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                gradient: AppGradients.primary,
                                borderRadius:
                                    BorderRadius.circular(AppRadii.medium),
                              ),
                              child: const Icon(Icons.receipt_long_rounded,
                                  color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    company?.displayName ?? 'Empiran Traders',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Text(
                                    'Billing Suite',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),

                      // Navigation Items
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 16),
                          itemCount: navItems.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 4),
                          itemBuilder: (context, i) {
                            final item = navItems[i];
                            final isSelected = currentRoute == item.route;

                            return InkWell(
                              onTap: () => _selectRoute(item.route),
                              borderRadius:
                                  BorderRadius.circular(AppRadii.medium),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary.withValues(alpha: 0.1)
                                      : Colors.transparent,
                                  borderRadius:
                                      BorderRadius.circular(AppRadii.medium),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      item.icon,
                                      size: 20,
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.lightTextSecondary,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        item.label,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: isSelected
                                              ? AppColors.primary
                                              : AppColors.lightTextPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Bottom User Profile Card
                      const Divider(height: 1),
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.12),
                              child: Text(
                                (user?.name.isNotEmpty ?? false)
                                    ? user!.name[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user?.name ?? 'User',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    role,
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Logout',
                              icon: const Icon(Icons.logout_rounded,
                                  size: 18, color: AppColors.error),
                              onPressed: () => _showLogoutConfirm(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Content Area
                Expanded(
                  child: Column(
                    children: [
                      // Desktop Top App Bar
                      Container(
                        height: 64,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(
                              bottom: BorderSide(color: AppColors.lightBorder)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              currentLabel,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                            InkWell(
                              onTap: () => showGlobalSearchDialog(
                                context,
                                onNavigate: _selectRoute,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: 320,
                                height: 38,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.lightBackground,
                                  borderRadius: BorderRadius.circular(10),
                                  border:
                                      Border.all(color: AppColors.lightBorder),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.search_rounded,
                                        size: 18, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'Search everything...',
                                        style: TextStyle(
                                            fontSize: 13, color: Colors.grey),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(4),
                                        border:
                                            Border.all(color: Colors.black12),
                                      ),
                                      child: const Text(
                                        'Ctrl+K',
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor:
                                      AppColors.primary.withValues(alpha: 0.1),
                                  child: Text(
                                    (user?.name.isNotEmpty ?? false)
                                        ? user!.name[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(child: currentContent),
                    ],
                  ),
                ),
              ],
            ),
          )
        : Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: AppColors.lightBackground,
            appBar: AppBar(
              title: Text(currentLabel),
              actions: [
                IconButton(
                  tooltip: 'Search (Ctrl+K)',
                  icon: const Icon(Icons.search_rounded),
                  onPressed: () => showGlobalSearchDialog(
                    context,
                    onNavigate: _selectRoute,
                  ),
                ),
                IconButton(
                  tooltip: 'Logout',
                  icon:
                      const Icon(Icons.logout_rounded, color: AppColors.error),
                  onPressed: () => _showLogoutConfirm(context),
                ),
              ],
            ),
            drawer: Drawer(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  DrawerHeader(
                    decoration:
                        const BoxDecoration(gradient: AppGradients.primary),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Icon(Icons.receipt_long_rounded,
                            color: Colors.white, size: 36),
                        const SizedBox(height: 10),
                        Text(
                          company?.displayName ?? 'Empiran Traders',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                        Text(
                          '${user?.name ?? "User"} ($role)',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  for (int i = 0; i < navItems.length; i++)
                    ListTile(
                      leading: Icon(
                        navItems[i].icon,
                        color: currentRoute == navItems[i].route
                            ? AppColors.primary
                            : null,
                      ),
                      title: Text(navItems[i].label),
                      selected: currentRoute == navItems[i].route,
                      onTap: () {
                        _selectRoute(navItems[i].route);
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
            ),
            body: currentContent,
            bottomNavigationBar: NavigationBar(
              selectedIndex: mobileSelectedIndex >= 0 ? mobileSelectedIndex : 0,
              onDestinationSelected: (i) =>
                  _selectRoute(mobileNavItems[i].route),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.request_quote_outlined),
                  selectedIcon: Icon(Icons.request_quote),
                  label: 'Quotes',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: 'Sales',
                ),
                NavigationDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2),
                  label: 'Products',
                ),
                NavigationDestination(
                  icon: Icon(Icons.groups_outlined),
                  selectedIcon: Icon(Icons.groups),
                  label: 'Parties',
                ),
              ],
            ),
          );

    return shell;
  }
}
