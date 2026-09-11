enum AppRole { admin, manager, biller }

class PermissionService {
  static AppRole parseRole(String? role) {
    if (role == null) return AppRole.biller;
    switch (role.toLowerCase().trim()) {
      case 'admin':
      case 'owner':
      case 'administrator':
        return AppRole.admin;
      case 'manager':
        return AppRole.manager;
      case 'biller':
      case 'billing staff':
      case 'cashier':
      case 'staff':
        return AppRole.biller;
      default:
        return AppRole.biller;
    }
  }

  /// Only Admin can access Settings, configure tax/sequences, and manage cloud endpoints
  static bool canAccessSettings(String? role) {
    return parseRole(role) == AppRole.admin;
  }

  /// Only Admin can create, edit, update roles, or delete users
  static bool canManageUsers(String? role) {
    return parseRole(role) == AppRole.admin;
  }

  /// Only Admin can delete finalized invoices or transaction records
  static bool canDeleteTransactions(String? role) {
    return parseRole(role) == AppRole.admin;
  }

  /// Admin has full reports (GST, P&L, Audits); Manager can view sales summaries
  static bool canViewReports(String? role) {
    final r = parseRole(role);
    return r == AppRole.admin || r == AppRole.manager;
  }

  /// Admin & Manager can add, edit, or adjust inventory stock; Biller is read-only
  static bool canManageProducts(String? role) {
    final r = parseRole(role);
    return r == AppRole.admin || r == AppRole.manager;
  }

  /// Admin & Manager can view purchase cost prices; Biller only sees selling price
  static bool canViewCostPrice(String? role) {
    final r = parseRole(role);
    return r == AppRole.admin || r == AppRole.manager;
  }

  /// Admin & Manager can view business purchase bills; Biller only sees sales
  static bool canViewPurchases(String? role) {
    final r = parseRole(role);
    return r == AppRole.admin || r == AppRole.manager;
  }

  /// Optimized landing screen tab index:
  /// - Admin: 0 (Dashboard)
  /// - Manager: 0 (Dashboard)
  /// - Biller: 1 (Orders & Sales Invoices / POS Counter for instant billing)
  static int defaultLandingIndex(String? role) {
    final r = parseRole(role);
    if (r == AppRole.biller) return 2; // Orders & Invoices (POS Sales Counter)
    return 0; // Dashboard
  }
}
