import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:empiran/core/services/permission_service.dart';
import 'package:empiran/core/theme/app_theme.dart';
import 'package:empiran/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:empiran/features/auth/presentation/bloc/auth_event.dart';
import 'package:empiran/features/auth/presentation/bloc/auth_state.dart';
import 'package:empiran/features/auth/presentation/pages/change_password_page.dart';
import 'package:empiran/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:empiran/features/invoices/presentation/pages/invoices_page.dart';
import 'package:empiran/features/parties/presentation/pages/parties_page.dart';
import 'package:empiran/features/products/presentation/pages/products_page.dart';
import 'package:empiran/features/reports/presentation/pages/reports_page.dart';
import 'package:empiran/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:empiran/features/settings/presentation/bloc/settings_state.dart';
import 'package:empiran/features/settings/presentation/pages/settings_page.dart';

class ShellPage extends StatefulWidget {
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  int _selectedIndex = 0;

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
                  style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
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
                          context.read<AuthBloc>().add(const AuthLogoutRequested());
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
    final company = settingsState is SettingsLoaded ? settingsState.company : null;

    final navItems = <(String, IconData, Widget)>[
      ('Dashboard', Icons.dashboard_outlined, DashboardPage(onNavigate: (i) => setState(() => _selectedIndex = i))),
      ('Quotation Maker', Icons.request_quote_outlined, const InvoicesPage(type: 'quotation', key: ValueKey('quotes'))),
      ('Orders & Invoices', Icons.receipt_long_outlined, const InvoicesPage(type: 'order', key: ValueKey('orders'))),
      ('Products & Inventory', Icons.inventory_2_outlined, const ProductsPage(key: ValueKey('products'))),
      ('Customers & Suppliers', Icons.groups_outlined, const PartiesPage(key: ValueKey('parties'))),
    ];

    if (PermissionService.canViewReports(role)) {
      navItems.add(('Reports', Icons.analytics_outlined, const ReportsPage(key: ValueKey('reports'))));
    }
    if (PermissionService.canAccessSettings(role)) {
      navItems.add(('Settings & Users', Icons.settings_outlined, const SettingsPage(key: ValueKey('settings'))));
    }

    if (_selectedIndex >= navItems.length) _selectedIndex = 0;

    final currentWidget = navItems[_selectedIndex].$3;

    if (wide) {
      return Scaffold(
        backgroundColor: AppColors.lightBackground,
        body: Row(
          children: [
            // Left Desktop Sidebar
            Container(
              width: 250,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(right: BorderSide(color: AppColors.lightBorder)),
              ),
              child: Column(
                children: [
                  // App Branding Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: AppGradients.primary,
                            borderRadius: BorderRadius.circular(AppRadii.medium),
                          ),
                          child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                company?.name ?? 'Empiran Traders',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Text(
                                'Billing Suite',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      itemCount: navItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (context, i) {
                        final item = navItems[i];
                        final isSelected = _selectedIndex == i;

                        return InkWell(
                          onTap: () => setState(() => _selectedIndex = i),
                          borderRadius: BorderRadius.circular(AppRadii.medium),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
                              borderRadius: BorderRadius.circular(AppRadii.medium),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  item.$2,
                                  size: 20,
                                  color: isSelected ? AppColors.primary : AppColors.lightTextSecondary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item.$1,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected ? AppColors.primary : AppColors.lightTextPrimary,
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
                          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                          child: Text(
                            (user?.name.isNotEmpty ?? false) ? user!.name[0].toUpperCase() : 'U',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.name ?? 'User',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                role,
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Logout',
                          icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.error),
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
                      border: Border(bottom: BorderSide(color: AppColors.lightBorder)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          navItems[_selectedIndex].$1,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'Update Password',
                              icon: const Icon(Icons.lock_reset_rounded, size: 20),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
                              ),
                            ),
                            const SizedBox(width: 8),
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              child: Text(
                                (user?.name.isNotEmpty ?? false) ? user!.name[0].toUpperCase() : 'U',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: currentWidget),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Mobile Layout
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: Text(navItems[_selectedIndex].$1),
        actions: [
          IconButton(
            tooltip: 'Update Password',
            icon: const Icon(Icons.lock_reset_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
            ),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded, color: AppColors.error),
            onPressed: () => _showLogoutConfirm(context),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(gradient: AppGradients.primary),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 36),
                  const SizedBox(height: 10),
                  Text(
                    company?.name ?? 'Empiran Traders',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    '${user?.name ?? "User"} ($role)',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            for (int i = 0; i < navItems.length; i++)
              ListTile(
                leading: Icon(navItems[i].$2, color: _selectedIndex == i ? AppColors.primary : null),
                title: Text(navItems[i].$1),
                selected: _selectedIndex == i,
                onTap: () {
                  setState(() => _selectedIndex = i);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
      body: currentWidget,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex.clamp(0, 3),
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.request_quote_outlined), selectedIcon: Icon(Icons.request_quote), label: 'Quotes'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Sales'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Products'),
        ],
      ),
    );
  }
}
