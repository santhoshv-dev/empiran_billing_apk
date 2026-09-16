class AppConstants {
  AppConstants._();

  static const String appName = 'Billing App';
  static const String defaultApiUrl = 'https://empiran-api.runasp.net/api/v1';

  // Secure Storage Keys
  static const String tokenKey = 'apiToken';
  static const String userKey = 'currentUser';
  static const String companyKey = 'company';
  static const String settingsKey = 'settings';
  static const String categoriesKey = 'categories';
  static const String expensesKey = 'expenses';
  static const String bankAccountsKey = 'bankAccounts';

  // Default Categories
  static const List<String> defaultCategories = [
    'General',
    'Electronics',
    'Hardware',
    'Kichen Wares',
    'Services',
  ];
}
