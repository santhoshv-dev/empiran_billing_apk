import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_store.dart';
import 'invoice_pdf.dart';
import 'models.dart';
import 'dashboard.dart';
import 'products_screen.dart';
import 'sync_screen.dart';
import 'core/services/permission_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/empiran_components.dart';
import 'core/widgets/server_config_dialog.dart';

part 'workflows.dart';

class SuiteShell extends StatefulWidget {
  const SuiteShell({super.key, required this.store, required this.onLogout});
  final AppStore store;
  final VoidCallback onLogout;
  @override
  State<SuiteShell> createState() => _SuiteShellState();
}

class _SuiteShellState extends State<SuiteShell> {
  int page = 0;

  @override
  void initState() {
    super.initState();
    page = PermissionService.defaultLandingIndex(widget.store.currentUserRole);
    widget.store.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.store.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final allowedNavItems = <(String, IconData)>[];
    final allowedPages = <Widget>[];

    void addNav(String title, IconData icon, Widget p) {
      allowedNavItems.add((title, icon));
      allowedPages.add(p);
    }

    addNav(
      'Dashboard',
      Icons.dashboard_outlined,
      DashboardScreen(
        store: widget.store,
        onNavigate: (i) => setState(() => page = i),
        onQuickAction: (action) {
          if (action == 'product') {
            _itemDialog(context, widget.store);
          } else if (action == 'customer') {
            _partyDialog(context, widget.store);
          } else {
            openComposer(context, widget.store, action);
          }
        },
        onPreviewTransaction: (t) => previewDocument(context, widget.store, t),
        onOpenSync: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SyncScreen(widget.store)),
        ),
      ),
    );
    addNav(
      'Quotation Maker',
      Icons.request_quote_outlined,
      QuotationWorkspace(widget.store),
    );
    addNav(
      'Orders & Invoices',
      Icons.receipt_long_outlined,
      TransactionPage(widget.store, 'order', key: const ValueKey('order')),
    );
    addNav(
      'Products & Inventory',
      Icons.inventory_2_outlined,
      ProductsScreen(widget.store),
    );
    addNav(
      'Customers & Suppliers',
      Icons.groups_outlined,
      CatalogPage(widget.store, parties: true),
    );

    if (PermissionService.canViewReports(widget.store.currentUserRole)) {
      addNav('Reports', Icons.analytics_outlined, ReportsPage(widget.store));
    }
    if (PermissionService.canAccessSettings(widget.store.currentUserRole)) {
      addNav('Settings & Users', Icons.settings_outlined, SettingsPage(widget.store));
    }

    if (page >= allowedPages.length) page = 0;

    final mainContent = AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.015, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(
        key: ValueKey('${widget.store.company.id}-$page'),
        child: allowedPages[page],
      ),
    );

    // Modern Responsive Layout
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            // Modern Sidebar Navigation Rail
            _buildDesktopSidebar(context, allowedNavItems),
            // Main App Content with Top Bar
            Expanded(
              child: Column(
                children: [
                  _buildDesktopTopBar(context, allowedNavItems[page].$1),
                  Expanded(child: mainContent),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Mobile Layout with Standard Modern AppBar & NavigationBar
    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        title: Row(
          children: [
            Image.asset(
              'assets/images/empiran_traders_logo.png',
              height: 28,
              errorBuilder: (_, __, ___) => const Icon(Icons.account_balance, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                allowedNavItems[page].$1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: EmpiranSyncIndicator(
              isOnline: widget.store.remoteMode,
              isSyncing: widget.store.syncing,
              pendingCount: 0,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SyncScreen(widget.store)),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Search',
            onPressed: () => showSearch(
              context: context,
              delegate: BusinessSearch(widget.store),
            ),
            icon: const Icon(Icons.search, size: 22),
          ),
          IconButton(
            tooltip: 'Toggle Theme',
            onPressed: widget.store.toggleTheme,
            icon: Icon(
              widget.store.darkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 22,
            ),
          ),
          IconButton(
            tooltip: 'Businesses',
            onPressed: () => switchBusiness(context, widget.store),
            icon: const Icon(Icons.business_outlined, size: 22),
          ),
        ],
      ),
      drawer: Drawer(child: _buildMobileDrawer(context, allowedNavItems)),
      body: mainContent,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _mobileNavIndex(page),
        onDestinationSelected: (i) {
          if (i < 4) {
            // Map 0: Dashboard, 1: Sales, 2: Products, 3: Quotations
            final targetPage = _mobileIndexToPage(i);
            setState(() => page = targetPage);
          } else {
            _showMoreBottomSheet(context, allowedNavItems);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Sales',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Icon(Icons.request_quote_outlined),
            selectedIcon: Icon(Icons.request_quote_rounded),
            label: 'Quotes',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_rounded),
            label: 'More',
          ),
        ],
      ),
    );
  }

  int _mobileNavIndex(int curPage) {
    if (curPage == 0) return 0; // Dashboard
    if (curPage == 2) return 1; // Orders/Sales
    if (curPage == 3) return 2; // Products
    if (curPage == 1) return 3; // Quotes
    return 4; // More
  }

  int _mobileIndexToPage(int idx) {
    if (idx == 0) return 0;
    if (idx == 1) return 2;
    if (idx == 2) return 3;
    if (idx == 3) return 1;
    return 0;
  }

  Widget _buildDesktopSidebar(BuildContext context, List<(String, IconData)> items) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border(
          right: BorderSide(
            color: isDark ? AppColors.darkBorder : const Color(0xFFE2EDF9),
            width: 1.2,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Branding Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceContainerHighest : AppColors.primarySubtle,
                      borderRadius: BorderRadius.circular(AppRadii.medium),
                      border: Border.all(color: const Color(0xFFDCEAF9), width: 1),
                    ),
                    clipBehavior: Clip.antiAlias,
                    padding: const EdgeInsets.all(6),
                    child: Image.asset(
                      'assets/images/empiran_traders_logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.account_balance, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EMPIRAN',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          'Billing & Management',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Active Company Card Switcher
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: InkWell(
                onTap: () => switchBusiness(context, widget.store),
                borderRadius: BorderRadius.circular(AppRadii.medium),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceContainer : AppColors.primarySubtle,
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                    border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFDCEAF9)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.business_rounded, size: 18, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.store.company.name,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.unfold_more, size: 16, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Navigation Items List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (_, i) {
                  final isSelected = i == page;
                  return InkWell(
                    onTap: () => setState(() => page = i),
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark ? AppColors.darkSurfaceContainerHighest : AppColors.primarySubtle)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadii.medium),
                        border: isSelected
                            ? Border.all(color: const Color(0xFFBAE6FD), width: 1)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            items[i].$2,
                            size: 20,
                            color: isSelected
                                ? AppColors.primary
                                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              items[i].$1,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected
                                    ? AppColors.primary
                                    : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                              ),
                            ),
                          ),
                          if (isSelected)
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Bottom Profile / Sign out tile
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : const Color(0xFFE2EDF9))),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primarySubtle,
                    child: const Icon(Icons.person, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.store.currentUserName,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: widget.store.currentUserRole.toLowerCase() == 'admin'
                                    ? AppColors.primary.withValues(alpha: 0.12)
                                    : (widget.store.currentUserRole.toLowerCase() == 'manager'
                                        ? const Color(0xFF0284C7).withValues(alpha: 0.12)
                                        : const Color(0xFF10B981).withValues(alpha: 0.12)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                widget.store.currentUserRole,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: widget.store.currentUserRole.toLowerCase() == 'admin'
                                      ? AppColors.primary
                                      : (widget.store.currentUserRole.toLowerCase() == 'manager'
                                          ? const Color(0xFF0284C7)
                                          : const Color(0xFF10B981)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sign out',
                    onPressed: widget.onLogout,
                    icon: const Icon(Icons.logout_rounded, size: 20, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopTopBar(BuildContext context, String currentTitle) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : const Color(0xFFE2EDF9),
            width: 1.2,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            currentTitle,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const Spacer(),
          EmpiranSyncIndicator(
            isOnline: widget.store.remoteMode,
            isSyncing: widget.store.syncing,
            pendingCount: 0,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SyncScreen(widget.store)),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Search catalog & records',
            onPressed: () => showSearch(
              context: context,
              delegate: BusinessSearch(widget.store),
            ),
            icon: const Icon(Icons.search, size: 22),
          ),
          IconButton(
            tooltip: 'Toggle Theme',
            onPressed: widget.store.toggleTheme,
            icon: Icon(
              widget.store.darkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 22,
            ),
          ),
          const SizedBox(width: 8),
          EmpiranButton(
            label: 'Sale Invoice',
            icon: Icons.add,
            onPressed: () => openComposer(context, widget.store, 'order'),
          ),
          const SizedBox(width: 8),
          EmpiranButton(
            label: 'Payment In',
            icon: Icons.payments_outlined,
            variant: EmpiranButtonVariant.secondary,
            onPressed: () => openComposer(context, widget.store, 'payment_in'),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileDrawer(BuildContext context, List<(String, IconData)> items) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ColoredBox(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/empiran_traders_logo.png',
                    width: 36,
                    height: 36,
                    errorBuilder: (_, __, ___) => const Icon(Icons.account_balance, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'EMPIRAN',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceContainer : AppColors.primarySubtle,
                borderRadius: BorderRadius.circular(AppRadii.medium),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : const Color(0xFFDCEAF9),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      widget.store.currentUserName.isNotEmpty
                          ? widget.store.currentUserName[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.store.currentUserName,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Role: ${widget.store.currentUserRole}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: widget.store.currentUserRole.toLowerCase() == 'admin'
                                ? AppColors.primary
                                : (widget.store.currentUserRole.toLowerCase() == 'manager'
                                    ? const Color(0xFF0284C7)
                                    : const Color(0xFF10B981)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (_, i) => ListTile(
                  selected: i == page,
                  selectedColor: AppColors.primary,
                  leading: Icon(items[i].$2),
                  title: Text(items[i].$1, style: const TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    setState(() => page = i);
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.sync, color: AppColors.primary),
              title: const Text('Cloud & Sync Status'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SyncScreen(widget.store)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.grey),
              title: const Text('Sign out'),
              onTap: () {
                Navigator.pop(context);
                widget.onLogout();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreBottomSheet(BuildContext context, List<(String, IconData)> items) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: SizedBox(
                  width: 40,
                  height: 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'More Modules',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.groups_outlined, color: Colors.purple),
                title: const Text('Customers & Suppliers', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Parties, ledgers & statements'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => page = 4);
                },
              ),
              if (PermissionService.canViewReports(widget.store.currentUserRole))
                ListTile(
                  leading: const Icon(Icons.analytics_outlined, color: Colors.pink),
                  title: const Text('Reports & Analytics', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Sales, tax & transaction reports'),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => page = 5);
                  },
                ),
              if (PermissionService.canAccessSettings(widget.store.currentUserRole))
                ListTile(
                  leading: const Icon(Icons.settings_outlined, color: Colors.blueGrey),
                  title: const Text('Settings & Staff', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Sequences, business profile & users'),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => page = 6);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.sync_outlined, color: AppColors.primary),
                title: const Text('Sync & Cloud Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(widget.store.remoteMode ? 'Online - Auto Syncing' : 'Offline Mode'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SyncScreen(widget.store)),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });
  final String title, subtitle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 18),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage(this.data);
  final String? data;

  @override
  Widget build(BuildContext context) {
    if (data != null && data!.isNotEmpty) {
      try {
        final clean = data!.contains(',') ? data!.split(',').last : data!;
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          child: Image.memory(
            base64Decode(clean),
            width: 54,
            height: 54,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallback(context),
          ),
        );
      } catch (_) {}
    }
    return _fallback(context);
  }

  Widget _fallback(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainerHighest : AppColors.lightSurfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Icon(
        Icons.inventory_2_outlined,
        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
        size: 24,
      ),
    );
  }
}

Future<void> _itemDialog(
  BuildContext context,
  AppStore store, {
  Item? item,
}) async {
  final name = TextEditingController(text: item?.name ?? ''),
      code = TextEditingController(text: item?.itemCode ?? ''),
      price = TextEditingController(text: '${item?.salesPrice ?? 0}'),
      stock = TextEditingController(text: '${item?.currentStock ?? 0}'),
      hsn = TextEditingController(text: item?.hsn ?? ''),
      purchase = TextEditingController(text: '${item?.purchasePrice ?? 0}'),
      category = TextEditingController(text: item?.category ?? 'General'),
      unit = TextEditingController(text: item?.unit ?? 'Pcs'),
      low = TextEditingController(text: '${item?.lowStockLimit ?? 5}');
  bool service = item?.isService ?? false;
  String? image = item?.image;
  String? error;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(item == null ? 'Create Product' : 'Edit Product'),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                EmpiranTextField(
                  controller: name,
                  label: 'Product Name',
                  hint: 'e.g. LED Bulb 9W',
                  isRequired: true,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: EmpiranTextField(
                        controller: code,
                        label: 'SKU / Item Code',
                        hint: 'e.g. LED-009',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EmpiranTextField(
                        controller: hsn,
                        label: 'HSN Code',
                        hint: 'e.g. 8539',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: EmpiranTextField(
                        controller: price,
                        label: 'Sales Price',
                        hint: '0.00',
                        isNumber: true,
                        isDecimal: true,
                        isRequired: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EmpiranTextField(
                        controller: purchase,
                        label: 'Purchase Price',
                        hint: '0.00',
                        isNumber: true,
                        isDecimal: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: EmpiranTextField(
                        controller: stock,
                        label: 'Opening Stock',
                        hint: '0',
                        isNumber: true,
                        isDecimal: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EmpiranTextField(
                        controller: low,
                        label: 'Low Stock Alert Limit',
                        hint: '5',
                        isNumber: true,
                        isDecimal: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: EmpiranTextField(
                        controller: category,
                        label: 'Category',
                        hint: 'e.g. Lighting',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EmpiranTextField(
                        controller: unit,
                        label: 'Unit',
                        hint: 'Pcs, Kg, Box',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Service Item', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('No inventory deduction or tracking'),
                  value: service,
                  onChanged: (v) => set(() => service = v),
                ),
                const SizedBox(height: 12),
                // Modern Image UI
                Row(
                  children: [
                    if (image != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.medium),
                        child: Image.memory(
                          base64Decode(image!.contains(',') ? image!.split(',').last : image!),
                          width: 58,
                          height: 58,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    EmpiranButton(
                      label: image == null ? 'Upload Image' : 'Change Image',
                      icon: Icons.photo_library_outlined,
                      variant: EmpiranButtonVariant.outlined,
                      height: 40,
                      onPressed: () async {
                        final f = await ImagePicker().pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 70,
                          maxWidth: 1000,
                        );
                        if (f != null) {
                          image = base64Encode(await f.readAsBytes());
                          set(() {});
                        }
                      },
                    ),
                    if (image != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Remove Image',
                        icon: const Icon(Icons.delete_outline, color: AppColors.error),
                        onPressed: () => set(() => image = null),
                      ),
                    ],
                  ],
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          EmpiranButton(
            label: 'Save Product',
            onPressed: () async {
              if (name.text.trim().isEmpty ||
                  [price, purchase, stock, low].any((c) =>
                      double.tryParse(c.text) == null || !double.parse(c.text).isFinite) ||
                  double.parse(price.text) < 0 ||
                  double.parse(purchase.text) < 0 ||
                  double.parse(low.text) < 0) {
                set(() => error = 'Enter a name and valid numbers for price, stock and limit.');
                return;
              }
              try {
                await store.addItem(
                  Item(
                    id: item?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
                    purchasePrice: double.parse(purchase.text),
                    category: category.text.trim().isEmpty ? 'General' : category.text.trim(),
                    unit: unit.text.trim().isEmpty ? 'Pcs' : unit.text.trim(),
                    lowStockLimit: double.parse(low.text),
                    isService: service,
                    name: name.text.trim(),
                    itemCode: code.text.trim(),
                    hsn: hsn.text.trim(),
                    salesPrice: double.tryParse(price.text) ?? 0,
                    currentStock: double.tryParse(stock.text) ?? 0,
                    image: image,
                  ),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                set(() => error = '$e');
              }
            },
          ),
        ],
      ),
    ),
  );

  for (final c in [name, code, price, stock, hsn, purchase, category, unit, low]) {
    c.dispose();
  }
}

Future<void> _partyDialog(
  BuildContext context,
  AppStore store, {
  Party? party,
}) async {
  final n = TextEditingController(text: party?.name ?? ''),
      ph = TextEditingController(text: party?.phone ?? ''),
      em = TextEditingController(text: party?.email ?? ''),
      gst = TextEditingController(text: party?.gstin ?? ''),
      address = TextEditingController(text: party?.address ?? ''),
      balance = TextEditingController(text: '${party?.balance ?? 0}');
  String type = party?.type ?? 'Customer';
  String? error;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(party == null ? 'Add Contact / Party' : 'Edit Contact / Party'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                EmpiranTextField(
                  controller: n,
                  label: 'Party Name',
                  hint: 'e.g. ABC Electricals',
                  isRequired: true,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: EmpiranTextField(
                        controller: ph,
                        label: 'Mobile Number',
                        hint: '10-digit number',
                        isNumber: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EmpiranTextField(
                        controller: em,
                        label: 'Email',
                        hint: 'name@company.com',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: type,
                        decoration: const InputDecoration(labelText: 'Party Type'),
                        items: ['Customer', 'Supplier', 'Both']
                            .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                            .toList(),
                        onChanged: (v) => set(() => type = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EmpiranTextField(
                        controller: gst,
                        label: 'GSTIN / UIN',
                        hint: '15-character GSTIN',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                EmpiranTextField(
                  controller: balance,
                  label: 'Opening Balance',
                  hint: 'Positive (+) for receivable, Negative (-) for payable',
                  isNumber: true,
                  isDecimal: true,
                ),
                const SizedBox(height: 12),
                EmpiranTextField(
                  controller: address,
                  label: 'Billing & Shipping Address',
                  maxLines: 3,
                  hint: 'Full address details',
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          EmpiranButton(
            label: 'Save Contact',
            onPressed: () async {
              if (n.text.trim().isEmpty ||
                  double.tryParse(balance.text) == null ||
                  !double.parse(balance.text).isFinite) {
                set(() => error = 'Enter a valid name and opening balance.');
                return;
              }
              try {
                await store.addParty(
                  Party(
                    id: party?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
                    balance: double.parse(balance.text),
                    name: n.text.trim(),
                    phone: ph.text.trim(),
                    email: em.text.trim(),
                    type: type,
                    gstin: gst.text.trim(),
                    address: address.text.trim(),
                  ),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                set(() => error = '$e');
              }
            },
          ),
        ],
      ),
    ),
  );

  for (final c in [n, ph, em, gst, address, balance]) {
    c.dispose();
  }
}

enum ReportRange { today, month, last30, all }

class ReportsPage extends StatefulWidget {
  const ReportsPage(this.store, {super.key});
  final AppStore store;
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  int tab = 0;
  ReportRange range = ReportRange.all;
  DateTime? from, to;

  List<BusinessTransaction> get rows {
    var data = widget.store.transactions
        .where(
          (t) => tab == 0
              ? true
              : tab == 1
                  ? ['order', 'sale_invoice', 'sale_order', 'quotation', 'estimate'].contains(t.type)
                  : t.paid > 0 || t.type.startsWith('payment_'),
        )
        .toList();
    final now = DateTime.now();
    DateTime? start, end;
    if (range == ReportRange.today) {
      start = DateTime(now.year, now.month, now.day);
      end = start.add(const Duration(days: 1));
    } else if (range == ReportRange.month) {
      start = DateTime(now.year, now.month);
      end = DateTime(now.year, now.month + 1);
    } else if (range == ReportRange.last30) {
      start = now.subtract(const Duration(days: 30));
      end = now.add(const Duration(days: 1));
    } else {
      start = from;
      end = to?.add(const Duration(days: 1));
    }
    return data
        .where(
          (t) =>
              (start == null || !t.date.isBefore(start)) &&
              (end == null || t.date.isBefore(end)),
        )
        .toList();
  }

  String summary() {
    final r = rows,
        total = r.fold<double>(0, (a, b) => a + b.total),
        paid = r.fold<double>(0, (a, b) => a + b.paid);
    return '${['Transaction Details', 'Sales Details', 'Payment Details'][tab]}\nRecords: ${r.length}\nTotal: ${AppTypography.formatCurrency(total)}\nPaid: ${AppTypography.formatCurrency(paid)}\nOutstanding: ${AppTypography.formatCurrency(total - paid)}';
  }

  Future<void> shareWhatsApp() async {
    await launchUrl(
      Uri.parse('https://wa.me/?text=${Uri.encodeComponent(summary())}'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> csv() async {
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

  Future<void> printReport() async {
    await Printing.layoutPdf(
      onLayout: (_) => buildReportPdf(
        widget.store.company,
        rows,
        ['Transaction Details', 'Sales Details', 'Payment Details'][tab],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = rows,
        total = r.fold<double>(0, (a, b) => a + b.total),
        paid = r.fold<double>(0, (a, b) => a + b.paid);

    return PageFrame(
      title: 'Reports & Analytics',
      subtitle: 'Transaction breakdown, tax liabilities and payment reconciliation',
      child: Column(
        children: [
          // Filter Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(['All Transactions', 'Sales Only', 'Payments Only'][i]),
                      selected: tab == i,
                      onSelected: (_) => setState(() => tab = i),
                    ),
                  ),
                const SizedBox(width: 12),
                for (final x in ReportRange.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text({
                        ReportRange.today: 'Today',
                        ReportRange.month: 'This Month',
                        ReportRange.last30: 'Last 30 Days',
                        ReportRange.all: 'All Time',
                      }[x]!),
                      selected: range == x,
                      onSelected: (_) => setState(() {
                        range = x;
                        from = null;
                        to = null;
                      }),
                    ),
                  ),
                TextButton.icon(
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(from == null
                      ? 'Custom Dates'
                      : '${DateFormat.yMd().format(from!)} - ${DateFormat.yMd().format(to!)}'),
                  onPressed: () async {
                    final dates = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (dates != null && mounted) {
                      setState(() {
                        from = dates.start;
                        to = dates.end;
                        range = ReportRange.all;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // KPI Summary Cards
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth > 800;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: wide ? 4 : 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: wide ? 2.2 : 1.7,
                children: [
                  EmpiranStatCard(
                    title: 'Total Records',
                    value: '${r.length}',
                    icon: Icons.list_alt,
                  ),
                  EmpiranStatCard(
                    title: 'Total Volume',
                    value: AppTypography.formatCurrency(total),
                    icon: Icons.currency_rupee,
                    iconColor: AppColors.primary,
                  ),
                  EmpiranStatCard(
                    title: 'Paid Amount',
                    value: AppTypography.formatCurrency(paid),
                    icon: Icons.payments_outlined,
                    iconColor: AppColors.success,
                  ),
                  EmpiranStatCard(
                    title: 'Outstanding Balance',
                    value: AppTypography.formatCurrency(total - paid),
                    icon: Icons.pending_actions,
                    iconColor: (total - paid) > 0 ? AppColors.error : AppColors.success,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Action Toolbar
          Row(
            children: [
              EmpiranButton(
                label: 'Export CSV',
                icon: Icons.table_view_outlined,
                variant: EmpiranButtonVariant.outlined,
                height: 38,
                onPressed: csv,
              ),
              const SizedBox(width: 8),
              EmpiranButton(
                label: 'Print PDF',
                icon: Icons.print_outlined,
                variant: EmpiranButtonVariant.outlined,
                height: 38,
                onPressed: printReport,
              ),
              const SizedBox(width: 8),
              EmpiranButton(
                label: 'WhatsApp',
                icon: Icons.chat_outlined,
                variant: EmpiranButtonVariant.secondary,
                height: 38,
                onPressed: shareWhatsApp,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Report List
          Expanded(
            child: r.isEmpty
                ? const EmpiranEmptyState(
                    title: 'No records in this range',
                    description: 'Try adjusting your date filters or record types.',
                  )
                : ListView.separated(
                    itemCount: r.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final item = r[i];
                      return EmpiranCard(
                        padding: const EdgeInsets.all(14),
                        onTap: () => previewDocument(context, widget.store, item),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '# ${item.number} • ${item.partyName.isEmpty ? "Cash Customer" : item.partyName}',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${DateFormat.yMMMd().format(item.date)} • ${transactionLabels[item.type] ?? item.type}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  AppTypography.formatCurrency(item.total),
                                  style: AppTypography.number.copyWith(fontSize: 15),
                                ),
                                const SizedBox(height: 4),
                                EmpiranStatusChip(
                                  label: item.status,
                                  type: item.status.toLowerCase() == 'paid'
                                      ? EmpiranStatusType.success
                                      : EmpiranStatusType.warning,
                                  small: true,
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
}

class SettingsPage extends StatefulWidget {
  const SettingsPage(this.store, {super.key});
  final AppStore store;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with SingleTickerProviderStateMixin {
  late final TabController tabs = TabController(length: 6, vsync: this);

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageFrame(
        title: 'Settings & Administration',
        subtitle: 'Company profile, invoice controls, staff access, appearance and backend API server.',
        child: Column(
          children: [
            TabBar(
              controller: tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: 'Company Profile', icon: Icon(Icons.business_outlined)),
                Tab(text: 'Invoice Control', icon: Icon(Icons.pin_outlined)),
                Tab(text: 'Appearance & Theme', icon: Icon(Icons.palette_outlined)),
                Tab(text: 'Staff & Roles', icon: Icon(Icons.manage_accounts_outlined)),
                Tab(text: 'Backend & Cloud', icon: Icon(Icons.dns_outlined)),
                Tab(text: 'Email & SMTP', icon: Icon(Icons.mail_outline)),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: TabBarView(
                controller: tabs,
                children: [
                  _CompanyForm(widget.store),
                  _InvoiceControl(widget.store),
                  _AppearanceSettings(widget.store),
                  _Users(widget.store),
                  _ServerSettingsTab(widget.store),
                  _EmailSettingsTab(widget.store),
                ],
              ),
            ),
          ],
        ),
      );
}

class _CompanyForm extends StatefulWidget {
  const _CompanyForm(this.store);
  final AppStore store;
  @override
  State<_CompanyForm> createState() => _CompanyFormState();
}

class _CompanyFormState extends State<_CompanyForm> {
  late final fields = <String, TextEditingController>{
    for (final e in {
      'name': widget.store.company.name,
      'gstin': widget.store.company.gstin,
      'address': widget.store.company.address,
      'phone': widget.store.company.phone,
      'state': widget.store.company.state,
      'stateCode': widget.store.company.stateCode,
      'email': widget.store.company.email,
      'bankName': widget.store.company.bankName,
      'accountNo': widget.store.company.accountNo,
      'branch': widget.store.company.branch,
      'ifsc': widget.store.company.ifsc,
    }.entries)
      e.key: TextEditingController(text: e.value),
  };

  String? logo;

  @override
  void initState() {
    super.initState();
    logo = widget.store.company.logo;
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        child: EmpiranCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Business Identity',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'These details appear on your invoices, tax receipts, and payment drafts.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final x in [
                    ('name', 'Company Name', true),
                    ('gstin', 'GSTIN / UIN', true),
                    ('phone', 'Primary Contact / Mobile', true),
                    ('email', 'Official Email', false),
                    ('state', 'State Name', false),
                    ('stateCode', 'State Code (e.g. 33)', false),
                    ('bankName', 'Bank Name', false),
                    ('accountNo', 'Bank Account Number', false),
                    ('branch', 'Bank Branch', false),
                    ('ifsc', 'Bank IFSC Code', false),
                  ])
                    SizedBox(
                      width: 320,
                      child: EmpiranTextField(
                        controller: fields[x.$1],
                        label: x.$2,
                        isRequired: x.$3,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              EmpiranTextField(
                controller: fields['address'],
                label: 'Registered Business Address',
                maxLines: 3,
                isRequired: true,
              ),
              const SizedBox(height: 24),
              const Text(
                'Company Logo',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (logo != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.medium),
                      child: Image.memory(
                        base64Decode(logo!.contains(',') ? logo!.split(',').last : logo!),
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  EmpiranButton(
                    label: logo == null ? 'Upload Logo' : 'Replace Logo',
                    icon: Icons.image_outlined,
                    variant: EmpiranButtonVariant.outlined,
                    onPressed: () async {
                      final f = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 75,
                        maxWidth: 1200,
                      );
                      if (f != null) {
                        final bytes = await f.readAsBytes();
                        setState(() => logo = base64Encode(bytes));
                      }
                    },
                  ),
                  if (logo != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Remove Logo',
                      icon: const Icon(Icons.delete_outline, color: AppColors.error),
                      onPressed: () => setState(() => logo = null),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 28),
              Align(
                alignment: Alignment.centerRight,
                child: EmpiranButton(
                  label: 'Save Business Profile',
                  icon: Icons.save_outlined,
                  onPressed: () async {
                    if (['name', 'gstin', 'address', 'phone']
                        .any((k) => fields[k]!.text.trim().isEmpty)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Complete all mandatory fields (*).')),
                      );
                      return;
                    }
                    final c = widget.store.company;
                    c.name = fields['name']!.text.trim();
                    c.gstin = fields['gstin']!.text.trim();
                    c.address = fields['address']!.text.trim();
                    c.phone = fields['phone']!.text.trim();
                    c.state = fields['state']!.text.trim();
                    c.stateCode = fields['stateCode']!.text.trim();
                    c.email = fields['email']!.text.trim();
                    c.bankName = fields['bankName']!.text.trim();
                    c.accountNo = fields['accountNo']!.text.trim();
                    c.branch = fields['branch']!.text.trim();
                    c.ifsc = fields['ifsc']!.text.trim();
                    c.logo = logo;
                    await widget.store.saveCompany();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Company profile saved successfully.')),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      );
}

class _InvoiceControl extends StatefulWidget {
  const _InvoiceControl(this.store);
  final AppStore store;
  @override
  State<_InvoiceControl> createState() => _InvoiceControlState();
}

class _InvoiceControlState extends State<_InvoiceControl> {
  late final gy = TextEditingController(text: widget.store.settings.gstYear),
      gc = TextEditingController(text: '${widget.store.settings.gstCounter}'),
      np = TextEditingController(text: widget.store.settings.nonGstPrefix),
      nc = TextEditingController(text: '${widget.store.settings.nonGstCounter}');

  @override
  void dispose() {
    gy.dispose();
    gc.dispose();
    np.dispose();
    nc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        child: EmpiranCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'GST Invoice Sequence',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'Standard fiscal year numbering format used for tax invoices.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: EmpiranTextField(
                      controller: gy,
                      label: 'Financial Year Tag',
                      hint: 'e.g. 25-26',
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: EmpiranTextField(
                      controller: gc,
                      label: 'Next Counter',
                      hint: '1',
                      isNumber: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AnimatedBuilder(
                animation: Listenable.merge([gy, gc]),
                builder: (_, __) => Text(
                  'Preview: #${gc.text}/${gy.text}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    fontSize: 13,
                  ),
                ),
              ),
              const Divider(height: 40),
              const Text(
                'Non-GST / Cash Bill Sequence',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'Sequential numbering for estimates, cash memos and standard receipts.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: EmpiranTextField(
                      controller: np,
                      label: 'Prefix Tag',
                      hint: 'e.g. ORD-',
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: EmpiranTextField(
                      controller: nc,
                      label: 'Starting Counter',
                      hint: '1001',
                      isNumber: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AnimatedBuilder(
                animation: Listenable.merge([np, nc]),
                builder: (_, __) => Text(
                  'Preview: #${np.text}${nc.text}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondary,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: EmpiranButton(
                  label: 'Save Sequences',
                  icon: Icons.save_outlined,
                  onPressed: () async {
                    widget.store.settings.gstYear = gy.text;
                    widget.store.settings.gstCounter = int.tryParse(gc.text) ?? 1;
                    widget.store.settings.nonGstPrefix = np.text;
                    widget.store.settings.nonGstCounter = int.tryParse(nc.text) ?? 1001;
                    await widget.store.saveSettings();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Numbering sequences updated.')),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      );
}

class _AppearanceSettings extends StatelessWidget {
  const _AppearanceSettings(this.store);
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final isDark = store.darkMode;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Theme & Interface Appearance',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Select your preferred workspace theme. Dark mode uses an eye-friendly charcoal and slate palette without pure black.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: [
              // Light Theme Card Preview
              _buildThemeCard(
                title: 'Light Theme',
                subtitle: 'Clean white surfaces with soft slate canvas',
                isSelected: !isDark,
                previewBg: AppColors.lightBackground,
                previewCard: AppColors.lightSurface,
                previewText: AppColors.lightTextPrimary,
                previewBorder: AppColors.lightBorder,
                onTap: () {
                  if (store.darkMode) store.toggleTheme();
                },
              ),

              // Charcoal / Slate Dark Theme Card Preview
              _buildThemeCard(
                title: 'Charcoal Dark',
                subtitle: 'Deep slate comfort palette (zero pure black)',
                isSelected: isDark,
                previewBg: AppColors.darkBackground,
                previewCard: AppColors.darkSurfaceContainer,
                previewText: AppColors.darkTextPrimary,
                previewBorder: AppColors.darkBorder,
                onTap: () {
                  if (!store.darkMode) store.toggleTheme();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeCard({
    required String title,
    required String subtitle,
    required bool isSelected,
    required Color previewBg,
    required Color previewCard,
    required Color previewText,
    required Color previewBorder,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.large),
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: previewBg,
          borderRadius: BorderRadius.circular(AppRadii.large),
          border: Border.all(
            color: isSelected ? AppColors.primary : previewBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mock UI preview
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: previewCard,
                borderRadius: BorderRadius.circular(AppRadii.medium),
                border: Border.all(color: previewBorder),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 80,
                        height: 8,
                        decoration: BoxDecoration(
                          color: previewText.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    width: 120,
                    height: 12,
                    decoration: BoxDecoration(
                      color: previewText,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 70,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: previewText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: previewText.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isSelected ? AppColors.primary : Colors.grey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Users extends StatelessWidget {
  const _Users(this.store);
  final AppStore store;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Staff Accounts & Access',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Authorized billers, managers and administrators',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              EmpiranButton(
                label: 'Add Staff Member',
                icon: Icons.person_add_outlined,
                onPressed: () => _userDialog(context, store),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: store.users.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final u = store.users[i];
                final isSuperAdmin = u['username']?.toLowerCase() == 'empirantraders';
                final roleStr = u['role'] ?? 'Biller';
                final isAdminRole = roleStr.toLowerCase() == 'admin';
                final isManagerRole = roleStr.toLowerCase() == 'manager';

                return EmpiranCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: isAdminRole
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : (isManagerRole
                                ? const Color(0xFF0284C7).withValues(alpha: 0.12)
                                : const Color(0xFF10B981).withValues(alpha: 0.12)),
                        child: Icon(
                          isAdminRole
                              ? Icons.admin_panel_settings_outlined
                              : (isManagerRole ? Icons.manage_accounts_outlined : Icons.person_outline),
                          color: isAdminRole
                              ? AppColors.primary
                              : (isManagerRole ? const Color(0xFF0284C7) : const Color(0xFF10B981)),
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
                                  u['name']!,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                                if (isSuperAdmin) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primarySubtle,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Owner / Root',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${u['username']} • ${u['email']}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isAdminRole
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : (isManagerRole
                                  ? const Color(0xFF0284C7).withValues(alpha: 0.12)
                                  : const Color(0xFF10B981).withValues(alpha: 0.12)),
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        child: Text(
                          roleStr,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isAdminRole
                                ? AppColors.primary
                                : (isManagerRole ? const Color(0xFF0284C7) : const Color(0xFF10B981)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Edit User & Role',
                        icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.primary),
                        onPressed: () => _editUserDialog(context, store, u),
                      ),
                      if (!isSuperAdmin) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Delete Account',
                          icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                          onPressed: () async {
                            if (await confirmDelete(context, 'Delete staff account for "${u['name']}"?')) {
                              await store.deleteUser(u['username']!);
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      );
}

Future<void> _userDialog(BuildContext context, AppStore store) async {
  final n = TextEditingController(),
      u = TextEditingController(),
      e = TextEditingController(),
      p = TextEditingController();
  String role = 'Biller';
  String? error;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('Create Staff Account'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                EmpiranTextField(
                  controller: n,
                  label: 'Full Name',
                  hint: 'e.g. John Doe',
                  isRequired: true,
                ),
                const SizedBox(height: 12),
                EmpiranTextField(
                  controller: u,
                  label: 'Username',
                  hint: 'johndoe',
                  isRequired: true,
                ),
                const SizedBox(height: 12),
                EmpiranTextField(
                  controller: e,
                  label: 'Email',
                  hint: 'john@empiran.com',
                ),
                const SizedBox(height: 12),
                EmpiranTextField(
                  controller: p,
                  label: 'Password',
                  obscureText: true,
                  isRequired: true,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(
                    labelText: 'Role / Permission Level',
                    border: OutlineInputBorder(),
                  ),
                  items: ['Admin', 'Manager', 'Biller']
                      .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                      .toList(),
                  onChanged: (v) => set(() => role = v!),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          EmpiranButton(
            label: 'Create Account',
            onPressed: () async {
              if (n.text.trim().isEmpty || u.text.trim().isEmpty || p.text.trim().isEmpty) {
                set(() => error = 'Name, username and password are required.');
                return;
              }
              if (store.users.any((x) =>
                  x['username']?.toLowerCase() == u.text.trim().toLowerCase() ||
                  (e.text.trim().isNotEmpty &&
                      x['email']?.toLowerCase() == e.text.trim().toLowerCase()))) {
                set(() => error = 'Username or email already exists.');
                return;
              }
              await store.createUser(
                name: n.text.trim(),
                username: u.text.trim(),
                email: e.text.trim(),
                password: p.text,
                role: role,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    ),
  );

  for (final c in [n, u, e, p]) {
    c.dispose();
  }
}

Future<void> _editUserDialog(BuildContext context, AppStore store, Map<String, String> user) async {
  final isSuperAdmin = user['username']?.toLowerCase() == 'empirantraders';
  final n = TextEditingController(text: user['name']),
      e = TextEditingController(text: user['email']),
      p = TextEditingController();
  String role = user['role'] ?? 'Biller';
  if (role.toLowerCase() == 'admin') {
    role = 'Admin';
  } else if (role.toLowerCase() == 'manager') {
    role = 'Manager';
  } else {
    role = 'Biller';
  }
  String? error;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.manage_accounts_outlined, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Edit Staff: ${user['username']}'),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EmpiranTextField(
                  controller: n,
                  label: 'Full Name',
                  isRequired: true,
                ),
                const SizedBox(height: 12),
                EmpiranTextField(
                  controller: e,
                  label: 'Email',
                  hint: 'email@empiran.com',
                ),
                const SizedBox(height: 12),
                EmpiranTextField(
                  controller: p,
                  label: 'Reset Password',
                  obscureText: true,
                  hint: 'Leave blank to keep existing password',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(
                    labelText: 'Role / Permission Level',
                    border: OutlineInputBorder(),
                  ),
                  items: ['Admin', 'Manager', 'Biller']
                      .map((x) => DropdownMenuItem(
                            value: x,
                            enabled: !isSuperAdmin || x == 'Admin',
                            child: Text(x),
                          ))
                      .toList(),
                  onChanged: isSuperAdmin ? null : (v) => set(() => role = v!),
                ),
                if (isSuperAdmin)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Primary root administrator role cannot be changed.',
                      style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
                  ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          EmpiranButton(
            label: 'Save Changes',
            onPressed: () async {
              if (n.text.trim().isEmpty) {
                set(() => error = 'Full name cannot be empty.');
                return;
              }
              await store.updateUser(
                user['username']!,
                name: n.text.trim(),
                email: e.text.trim(),
                password: p.text.isNotEmpty ? p.text : null,
                role: role,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    ),
  );

  n.dispose();
  e.dispose();
  p.dispose();
}

class _ServerSettingsTab extends StatefulWidget {
  const _ServerSettingsTab(this.store);
  final AppStore store;

  @override
  State<_ServerSettingsTab> createState() => _ServerSettingsTabState();
}

class _ServerSettingsTabState extends State<_ServerSettingsTab> {
  late final TextEditingController _customUrlController;
  bool _testing = false;
  Map<String, dynamic>? _health;

  @override
  void initState() {
    super.initState();
    _customUrlController = TextEditingController(text: widget.store.currentApiUrl);
    _checkHealth();
  }

  @override
  void dispose() {
    _customUrlController.dispose();
    super.dispose();
  }

  Future<void> _checkHealth() async {
    setState(() {
      _testing = true;
      _health = null;
    });
    final res = await widget.store.api.checkHealth(widget.store.currentApiUrl);
    if (mounted) {
      setState(() {
        _testing = false;
        _health = res;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUrl = widget.store.currentApiUrl;
    final isLocal = currentUrl == ServerConfigDialog.localPreset;
    final isCloud = currentUrl == ServerConfigDialog.cloudPreset;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Backend API & Cloud Synchronization',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Configure your active ASP.NET Core backend server endpoint, test live latency, and manage sync.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 20),

          // Status & Connection Card
          EmpiranCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadii.medium),
                      ),
                      child: const Icon(Icons.dns_rounded, color: AppColors.primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                isLocal
                                    ? 'Local Development Server'
                                    : (isCloud ? 'Cloud Production Server' : 'Custom Server Endpoint'),
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (_health?['healthy'] == true)
                                      ? AppColors.success.withValues(alpha: 0.15)
                                      : (_testing
                                          ? AppColors.info.withValues(alpha: 0.15)
                                          : AppColors.error.withValues(alpha: 0.15)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _testing
                                      ? 'PINGING...'
                                      : ((_health?['healthy'] == true) ? 'ONLINE' : 'OFFLINE'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: (_health?['healthy'] == true)
                                        ? AppColors.success
                                        : (_testing ? AppColors.info : AppColors.error),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          SelectableText(
                            currentUrl,
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    EmpiranButton(
                      label: _testing ? 'Pinging...' : 'Test Latency',
                      icon: Icons.network_check_rounded,
                      variant: EmpiranButtonVariant.secondary,
                      isLoading: _testing,
                      onPressed: _checkHealth,
                    ),
                  ],
                ),
                if (_health != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceContainerHighest
                          : AppColors.lightSurfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadii.small),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _health!['healthy'] == true ? Icons.check_circle_outline : Icons.error_outline,
                          size: 16,
                          color: _health!['healthy'] == true ? AppColors.success : AppColors.error,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _health!['healthy'] == true
                              ? 'Response: ${_health!['latencyMs']} ms • Environment: ${_health!['environment'] ?? 'Live'}'
                              : 'Failed: ${_health!['message']}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _health!['healthy'] == true ? AppColors.success : AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Environment Switcher
          const Text(
            'Switch Environment Preset',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _PresetTile(
                  title: 'Localhost (ASP.NET Core)',
                  subtitle: 'http://localhost:5186/api/v1',
                  isActive: isLocal,
                  icon: Icons.computer_rounded,
                  badge: 'Local Port 5186',
                  onTap: () async {
                    await widget.store.setApiUrl(ServerConfigDialog.localPreset);
                    _customUrlController.text = ServerConfigDialog.localPreset;
                    _checkHealth();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PresetTile(
                  title: 'Official Cloud API',
                  subtitle: 'https://empiran-api.runasp.net/api/v1',
                  isActive: isCloud,
                  icon: Icons.cloud_done_rounded,
                  badge: 'runasp.net Cloud',
                  onTap: () async {
                    await widget.store.setApiUrl(ServerConfigDialog.cloudPreset);
                    _customUrlController.text = ServerConfigDialog.cloudPreset;
                    _checkHealth();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Custom Endpoint Box
          EmpiranCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Custom Endpoint Configuration',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Specify a custom IP address or domain when deploying to a self-hosted server or on a local network.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: EmpiranTextField(
                        controller: _customUrlController,
                        label: 'Custom Backend URL',
                        hint: 'http://192.168.1.100:5186/api/v1',
                        prefixIcon: Icons.lan_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    EmpiranButton(
                      label: 'Apply Endpoint',
                      icon: Icons.save_outlined,
                      onPressed: () async {
                        final val = _customUrlController.text.trim();
                        if (val.isNotEmpty) {
                          await widget.store.setApiUrl(val);
                          _checkHealth();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('API Endpoint updated to $val'),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Cloud Sync & Remote Token Info
          EmpiranCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: widget.store.remoteMode
                        ? AppColors.success.withValues(alpha: 0.12)
                        : AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                  ),
                  child: Icon(
                    widget.store.remoteMode ? Icons.cloud_sync_rounded : Icons.cloud_off_rounded,
                    color: widget.store.remoteMode ? AppColors.success : AppColors.warning,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.store.remoteMode ? 'Cloud Synchronization Active' : 'Offline / Local SQLite Mode',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        widget.store.remoteMode
                            ? 'Your transactions and records sync with the backend automatically.'
                            : 'Sign in with cloud credentials to sync businesses, items, and transactions with the backend.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.store.remoteMode) ...[
                  EmpiranButton(
                    label: widget.store.syncing ? 'Syncing...' : 'Sync Now',
                    icon: Icons.sync_rounded,
                    isLoading: widget.store.syncing,
                    onPressed: () async {
                      try {
                        await widget.store.syncFromApi();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Cloud sync completed successfully!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Sync error: $e'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.title,
    required this.subtitle,
    required this.isActive,
    required this.icon,
    required this.badge,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool isActive;
  final IconData icon;
  final String badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.medium),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1)
              : (isDark ? AppColors.darkSurfaceContainer : AppColors.lightSurfaceContainer),
          borderRadius: BorderRadius.circular(AppRadii.medium),
          border: Border.all(
            color: isActive ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: isActive ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: isActive ? AppColors.primary : (isDark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isActive ? AppColors.primary : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.primary : (isDark ? Colors.white12 : Colors.black12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isActive ? Colors.white : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isActive)
              const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _EmailSettingsTab extends StatefulWidget {
  const _EmailSettingsTab(this.store);
  final AppStore store;

  @override
  State<_EmailSettingsTab> createState() => _EmailSettingsTabState();
}

class _EmailSettingsTabState extends State<_EmailSettingsTab> {
  final TextEditingController _testEmailCtrl = TextEditingController(text: 'empirantraders@gmail.com');
  bool _loadingStatus = false;
  bool _sendingTest = false;
  Map<String, dynamic>? _smtpStatus;
  Map<String, dynamic>? _testResult;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  @override
  void dispose() {
    _testEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchStatus() async {
    setState(() {
      _loadingStatus = true;
    });
    try {
      final res = await widget.store.api.getEmailStatus();
      if (mounted) {
        setState(() {
          _smtpStatus = res;
          _loadingStatus = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _smtpStatus = null;
          _loadingStatus = false;
        });
      }
    }
  }

  Future<void> _sendTestEmail() async {
    final to = _testEmailCtrl.text.trim();
    if (to.isEmpty) return;

    setState(() {
      _sendingTest = true;
      _testResult = null;
    });

    try {
      final res = await widget.store.api.sendTestEmail(to);
      if (mounted) {
        setState(() {
          _sendingTest = false;
          _testResult = res;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? 'Test email sent!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sendingTest = false;
          _testResult = {
            'success': false,
            'message': 'Failed: $e',
          };
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delivery error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Google SMTP & Email Notification Service',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Manage outgoing mail credentials, test connectivity to smtp.gmail.com, and review system email templates.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 20),

          // Status Card
          EmpiranCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadii.medium),
                          ),
                          child: const Icon(Icons.mark_email_read_rounded, color: AppColors.primary),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Google SMTP Configuration',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _smtpStatus != null && _smtpStatus!['configured'] == true
                                  ? 'Connected • smtp.gmail.com:587 (TLS)'
                                  : 'Checking status or connecting to backend...',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    EmpiranButton(
                      label: _loadingStatus ? 'Checking...' : 'Refresh Status',
                      icon: Icons.refresh_rounded,
                      variant: EmpiranButtonVariant.secondary,
                      isLoading: _loadingStatus,
                      onPressed: _fetchStatus,
                    ),
                  ],
                ),
                if (_smtpStatus != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceContainerHighest
                          : AppColors.lightSurfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadii.medium),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    child: Wrap(
                      spacing: 24,
                      runSpacing: 12,
                      children: [
                        _InfoItem('SMTP Server', '${_smtpStatus!['host']}:${_smtpStatus!['port']}'),
                        _InfoItem('Security', 'STARTTLS (Enabled)'),
                        _InfoItem('Sender Account', '${_smtpStatus!['senderEmail']}'),
                        _InfoItem('Display Name', '${_smtpStatus!['fromName']}'),
                        _InfoItem('App Password', '${_smtpStatus!['maskedPassword']}'),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Test Delivery Card
          EmpiranCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Send Verification Test Email',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Verify that your Google App Password can successfully dispatch authenticated emails.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: EmpiranTextField(
                        controller: _testEmailCtrl,
                        label: 'Recipient Email Address',
                        hint: 'empirantraders@gmail.com',
                        prefixIcon: Icons.alternate_email_rounded,
                      ),
                    ),
                    const SizedBox(width: 14),
                    EmpiranButton(
                      label: _sendingTest ? 'Sending...' : 'Send Test Email',
                      icon: Icons.send_rounded,
                      isLoading: _sendingTest,
                      onPressed: _sendTestEmail,
                    ),
                  ],
                ),
                if (_testResult != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _testResult!['success'] == true
                          ? AppColors.success.withValues(alpha: 0.12)
                          : AppColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadii.small),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _testResult!['success'] == true ? Icons.check_circle_outline : Icons.error_outline,
                          color: _testResult!['success'] == true ? AppColors.success : AppColors.error,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _testResult!['message']?.toString() ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _testResult!['success'] == true ? AppColors.success : AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Available Templates Card
          const Text(
            'Branded Email Templates',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: const [
              _TemplateTile(
                title: 'Invoice & Bill Receipt',
                subtitle: 'Dispatched to customer parties with payment status, breakdown and direct online link.',
                icon: Icons.receipt_long_rounded,
                color: Color(0xFF2563EB),
              ),
              _TemplateTile(
                title: 'Staff Welcome & Credentials',
                subtitle: 'Automatically dispatched when creating a new Admin, Manager, or Biller account.',
                icon: Icons.badge_outlined,
                color: Color(0xFF059669),
              ),
              _TemplateTile(
                title: 'Security Verification OTP',
                subtitle: 'Provides single-use 6-digit codes with 10-minute expiry for resets and authorizations.',
                icon: Icons.security_rounded,
                color: Color(0xFF7C3AED),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainer : AppColors.lightSurfaceContainer,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.small),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

