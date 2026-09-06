import '../../models.dart';

enum AppRole { owner, admin, biller }

class PermissionService {
  static AppRole _parseRole(String role) {
    switch (role.toLowerCase()) {
      case 'owner': return AppRole.owner;
      case 'admin': return AppRole.admin;
      case 'biller': return AppRole.biller;
      default: return AppRole.biller;
    }
  }

  static bool canAccessSettings(Company company) {
    final role = _parseRole(company.role);
    return role == AppRole.owner || role == AppRole.admin;
  }

  static bool canManageUsers(Company company) {
    return _parseRole(company.role) == AppRole.owner;
  }
  
  static bool canDeleteTransactions(Company company) {
    final role = _parseRole(company.role);
    return role == AppRole.owner || role == AppRole.admin;
  }

  static bool canViewReports(Company company) {
    final role = _parseRole(company.role);
    return role == AppRole.owner || role == AppRole.admin;
  }
}
