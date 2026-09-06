import 'package:flutter/material.dart';
import 'app_store.dart';
import 'core/services/permission_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.store, required this.onNavigate});
  
  final AppStore store;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
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
                      'Good Morning,',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      store.company.name,
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.0,
                      ),
                    ),
                  ],
                ),
              ),
              _buildConnectionBadge(context, store),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Choose a module to begin',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 32),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = 2;
                if (constraints.maxWidth > 1200) crossAxisCount = 4;
                else if (constraints.maxWidth > 800) crossAxisCount = 3;
                
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.5,
                  children: [
                    _FeatureCard(
                      title: 'Sales',
                      subtitle: 'Create invoices & orders',
                      icon: Icons.receipt_long_outlined,
                      color: Colors.blue,
                      onTap: () => onNavigate(2), // 2 = Orders & Invoices
                    ),
                    _FeatureCard(
                      title: 'Products',
                      subtitle: 'Manage inventory',
                      icon: Icons.inventory_2_outlined,
                      color: Colors.orange,
                      onTap: () => onNavigate(3), // 3 = Products & Inventory
                    ),
                    _FeatureCard(
                      title: 'Customers',
                      subtitle: 'Customer & suppliers',
                      icon: Icons.groups_outlined,
                      color: Colors.purple,
                      onTap: () => onNavigate(4), // 4 = Customers & Suppliers
                    ),
                    _FeatureCard(
                      title: 'Quotations',
                      subtitle: 'Create quotes & estimates',
                      icon: Icons.request_quote_outlined,
                      color: Colors.teal,
                      onTap: () => onNavigate(1), // 1 = Quotation Maker
                    ),
                    if (PermissionService.canViewReports(store.company))
                      _FeatureCard(
                        title: 'Reports',
                        subtitle: 'View analytics & totals',
                        icon: Icons.analytics_outlined,
                        color: Colors.pink,
                        onTap: () => onNavigate(5), // 5 = Reports
                      ),
                    if (PermissionService.canAccessSettings(store.company))
                      _FeatureCard(
                        title: 'Settings',
                        subtitle: 'App configuration & users',
                        icon: Icons.settings_outlined,
                        color: Colors.blueGrey,
                        onTap: () => onNavigate(6), // 6 = Settings
                      ),
                  ],
                );
              }
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionBadge(BuildContext context, AppStore store) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: store.remoteMode 
          ? Colors.green.withValues(alpha: 0.1) 
          : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: store.remoteMode 
            ? Colors.green.withValues(alpha: 0.5) 
            : Colors.orange.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: store.remoteMode ? Colors.green : Colors.orange,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            store.remoteMode ? 'Online' : 'Offline',
            style: TextStyle(
              color: store.remoteMode ? Colors.green : Colors.orange,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatefulWidget {
  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()
            ..scale(_isPressed ? 0.95 : _isHovered ? 1.02 : 1.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _isHovered ? widget.color.withOpacity(0.5) : Theme.of(context).colorScheme.outlineVariant,
              width: _isHovered ? 2 : 1,
            ),
            boxShadow: [
              if (_isHovered && !_isPressed)
                BoxShadow(
                  color: widget.color.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(widget.icon, color: widget.color, size: 32),
              ),
              const Spacer(),
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.subtitle,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
