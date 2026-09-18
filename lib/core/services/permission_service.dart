enum AppRole { admin, manager, biller }

class PermissionService {
  static AppRole parseRole(String? role) {
    if (role == null) return AppRole.biller;
    final normalized = role.toLowerCase().trim();
    switch (normalized) {
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
        if (normalized.contains('admin') || normalized.contains('owner')) {
          return AppRole.admin;
        }
        if (normalized.contains('manager')) {
          return AppRole.manager;
        }
        if (normalized.contains('biller') ||
            normalized.contains('billing') ||
            normalized.contains('cashier') ||
            normalized.contains('staff')) {
          return AppRole.biller;
        }
        return AppRole.biller;
    }
  }

  /// Admin gets full settings. Manager and Biller get account security only.
  static bool canAccessSettings(String? role) {
    final r = parseRole(role);
    return r == AppRole.admin || r == AppRole.manager || r == AppRole.biller;
  }

  static bool canAccessFullSettings(String? role) {
    return parseRole(role) == AppRole.admin;
  }

  static bool isBiller(String? role) {
    return parseRole(role) == AppRole.biller;
  }

  static bool isManager(String? role) {
    return parseRole(role) == AppRole.manager;
  }

  static bool hasLimitedSettings(String? role) {
    final r = parseRole(role);
    return r == AppRole.manager || r == AppRole.biller;
  }

  /// Only Admin can create, edit, update roles, or delete users
  static bool canManageUsers(String? role) {
    return parseRole(role) == AppRole.admin;
  }

  /// Only Admin can delete finalized invoices or transaction records
  static bool canDeleteTransactions(String? role) {
    return parseRole(role) == AppRole.admin;
  }

  /// Admin has full reports (GST, P&L, Audits). Manager reports stay hidden in
  /// the shell unless a dedicated limited reports surface is added.
  static bool canViewReports(String? role) {
    return parseRole(role) == AppRole.admin;
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
  /// - Biller: 0 (Role-specific dashboard)
  static int defaultLandingIndex(String? role) {
    return 0; // Dashboard
  }
}
