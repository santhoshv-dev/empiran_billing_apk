import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'data/remote/api_client.dart';
import 'data/local/db_helper.dart';
import 'core/services/financial_year_service.dart';
import 'data/remote/sync_engine.dart';

class AppStore extends ChangeNotifier {
  final ApiClient api = ApiClient();
  late final SyncEngine syncEngine;

  AppStore() {
    syncEngine = SyncEngine(this);
  }

  bool remoteMode = false;
  bool syncing = false;
  String? syncError;
  List<Map<String, dynamic>> remoteBusinesses = [];
  Company company = Company();
  InvoiceSettings settings = InvoiceSettings();
  List<Item> items = [];
  List<Party> parties = [];
  List<BusinessTransaction> transactions = [];
  Map<String, String>? currentUser;
  String get currentUserRole => currentUser?['role'] ?? 'Admin';
  String get currentUserName => currentUser?['name'] ?? currentUser?['username'] ?? 'User';
  String get currentApiUrl => api.baseUrl;
  void notify() => notifyListeners();

  Future<void> setApiUrl(String url) async {
    api.baseUrl = url;
    final p = await SharedPreferences.getInstance();
    await p.setString('apiUrl', url);
    notifyListeners();
  }

  List<String> categories = ['General', 'Electronics', 'Hardware', 'Grocery', 'Services'];

  Future<void> addCategory(String cat) async {
    final trimmed = cat.trim();
    if (trimmed.isNotEmpty && !categories.contains(trimmed)) {
      categories.add(trimmed);
      await _save();
      notifyListeners();
    }
  }

  Future<void> deleteCategory(String cat) async {
    categories.remove(cat.trim());
    await _save();
    notifyListeners();
  }

  List<Map<String, String>> users = [
    {
      'name': 'Business Admin',
      'username': 'empirantraders',
      'email': 'admin@empiran.com',
      'password': '123456',
      'role': 'Admin',
    },
    {
      'name': 'Store Manager',
      'username': 'manager',
      'email': 'manager@empiran.com',
      'password': '123456',
      'role': 'Manager',
    },
    {
      'name': 'POS Biller',
      'username': 'biller',
      'email': 'biller@empiran.com',
      'password': '123456',
      'role': 'Biller',
    },
  ];
  List<Map<String, dynamic>> expenses = [], bankAccounts = [];
  bool darkMode = true;
  Map<String, dynamic> firms = {};
  bool ready = false;
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    api.token = p.getString('apiToken');
    remoteMode = api.token != null && api.token!.isNotEmpty;
    Map<String, dynamic>? map(String k) {
      final v = p.getString(k);
      return v == null ? null : Map<String, dynamic>.from(jsonDecode(v));
    }

    List<Map<String, dynamic>> list(String k) {
      final v = p.getString(k);
      return v == null
          ? []
          : (jsonDecode(v) as List)
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
    }

    expenses = list('expenses');
    bankAccounts = list('bankAccounts');
    darkMode = p.getBool('darkMode') ?? true;
    final c = map('company');
    firms = map('firms') ?? {};
    if (c != null) company = Company.fromJson(c);
    final s = map('settings');
    if (s != null) settings = InvoiceSettings.fromJson(s);

    final savedCats = p.getString('categories');
    if (savedCats != null && savedCats.isNotEmpty) {
      try {
        final decoded = jsonDecode(savedCats);
        if (decoded is List) {
          categories = decoded.map((e) => '$e').toList();
        }
      } catch (_) {}
    }
    final savedApiUrl = p.getString('apiUrl');
    if (savedApiUrl != null && savedApiUrl.isNotEmpty) {
      api.baseUrl = savedApiUrl;
    }
    
    // SQLite Loading
    final dbItems = await DbHelper.instance.queryAll('items');
    if (dbItems.isEmpty && p.containsKey('items')) {
       // Migrate from SharedPreferences to SQLite once
       items = list('items').map(Item.fromJson).toList();
       for (var item in items) {
         final j = item.toJson();
         j['isService'] = item.isService ? 1 : 0;
         await DbHelper.instance.insert('items', j);
       }
       p.remove('items');
    } else {
       items = dbItems.map((j) {
         final data = Map<String, dynamic>.from(j);
         data['isService'] = (data['isService'] as int) == 1;
         return Item.fromJson(data);
       }).toList();
    }

    final dbParties = await DbHelper.instance.queryAll('parties');
    if (dbParties.isEmpty && p.containsKey('parties')) {
       parties = list('parties').map(Party.fromJson).toList();
       for (var party in parties) {
         await DbHelper.instance.insert('parties', party.toJson());
       }
       p.remove('parties');
    } else {
       parties = dbParties.map((j) => Party.fromJson(j)).toList();
    }

    final dbTxns = await DbHelper.instance.queryAll('transactions');
    if (dbTxns.isEmpty && p.containsKey('transactions')) {
       transactions = list('transactions').map(BusinessTransaction.fromJson).toList();
       for (var t in transactions) {
         final j = t.toJson();
         j['isGst'] = t.isGst ? 1 : 0;
         j['lines'] = jsonEncode(j['lines']);
         j['dispatch'] = jsonEncode(j['dispatch']);
         await DbHelper.instance.insert('transactions', j);
       }
       p.remove('transactions');
    } else {
       transactions = dbTxns.map((j) {
         final data = Map<String, dynamic>.from(j);
         data['isGst'] = (data['isGst'] as int) == 1;
         data['lines'] = jsonDecode(data['lines'] as String);
         data['dispatch'] = jsonDecode(data['dispatch'] as String);
         return BusinessTransaction.fromJson(data);
       }).toList();
    }

    final u = list('users');
    if (u.isNotEmpty) {
      users = u.map((e) => e.map((k, v) => MapEntry(k, '$v'))).toList();
    }
    // Ensure default RBAC accounts exist (Admin, Manager, Biller)
    void ensureUser(String username, String name, String email, String role) {
      if (!users.any((x) => x['username']?.toLowerCase() == username.toLowerCase())) {
        users.add({
          'name': name,
          'username': username,
          'email': email,
          'password': '123456',
          'role': role,
        });
      }
    }
    ensureUser('empirantraders', 'Business Admin', 'admin@empiran.com', 'Admin');
    ensureUser('manager', 'Store Manager', 'manager@empiran.com', 'Manager');
    ensureUser('biller', 'POS Biller', 'biller@empiran.com', 'Biller');

    final savedUser = p.getString('currentUser');
    if (savedUser != null && savedUser.isNotEmpty) {
      try {
        final decoded = jsonDecode(savedUser);
        if (decoded is Map) {
          currentUser = decoded.map((k, v) => MapEntry('$k', '$v'));
        }
      } catch (_) {}
    }
    ready = true;
    notifyListeners();
    if (remoteMode) {
      try {
        await syncFromApi();
      } catch (e) {
        syncError = '$e';
        notifyListeners();
      }
    }
  }

  Future<Map<String, dynamic>> remoteLogin(
    String email,
    String password,
  ) async {
    final auth = await api.login(email, password);
    final p = await SharedPreferences.getInstance();
    await p.setString('apiToken', api.token!);
    await p.setString('sessionExpiry', '${auth['expiresAt']}');
    remoteMode = true;

    final authUser = auth['user'];
    if (authUser is Map) {
      currentUser = {
        'name': authUser['name']?.toString() ?? email,
        'username': email.split('@').first,
        'email': authUser['email']?.toString() ?? email,
        'role': authUser['role']?.toString() ?? 'Admin',
      };
      await p.setString('currentUser', jsonEncode(currentUser));
    }

    await syncFromApi(createFirstBusiness: true);
    return auth;
  }

  Future<Map<String, dynamic>> remoteRegister(
    String name,
    String email,
    String password,
  ) async {
    final auth = await api.register(name, email, password);
    final p = await SharedPreferences.getInstance();
    await p.setString('apiToken', api.token!);
    await p.setString('sessionExpiry', '${auth['expiresAt']}');
    remoteMode = true;
    await syncFromApi(createFirstBusiness: true);
    return auth;
  }

  Future<void> disconnectApi() async {
    api.token = null;
    remoteMode = false;
    remoteBusinesses = [];
    syncError = null;
    final p = await SharedPreferences.getInstance();
    await p.remove('apiToken');
  }

  Future<void> syncFromApi({bool createFirstBusiness = false}) async {
    if (!remoteMode || api.token == null) return;
    syncing = true;
    syncError = null;
    notifyListeners();
    try {
      remoteBusinesses = await api.getBusinesses();
      if (remoteBusinesses.isEmpty && createFirstBusiness) {
        remoteBusinesses = [
          await api.createBusiness(_businessPayload(company)),
        ];
      }
      if (remoteBusinesses.isEmpty) {
        throw StateError('Create a business before syncing records.');
      }
      final selected = remoteBusinesses.cast<Map<String, dynamic>>().firstWhere(
        (b) => '${b['id']}' == company.id,
        orElse: () => remoteBusinesses.first,
      );
      company = Company.fromJson(selected);
      final results = await Future.wait([
        api.getItems(company.id),
        api.getParties(company.id),
        api.getTransactions(company.id),
        api.getExpenses(company.id),
        api.getBankAccounts(company.id),
        api.getStaff(company.id).catchError((_) => <Map<String, dynamic>>[]),
      ]);
      items = results[0].map(Item.fromJson).toList();
      parties = results[1].map(Party.fromJson).toList();
      transactions = results[2].map(BusinessTransaction.fromJson).toList();
      for (final transaction in transactions) {
        for (final party in parties.where((p) => p.id == transaction.partyId)) {
          transaction.partyPhone = party.phone;
          transaction.partyAddress = party.address;
          transaction.partyGstin = party.gstin;
        }
      }
      expenses = results[3].map(_expenseFromApi).toList();
      bankAccounts = results[4].map(_bankFromApi).toList();

      final staffList = results[5];
      for (final s in staffList) {
        final email = s['email']?.toString() ?? '';
        final name = s['name']?.toString() ?? '';
        final role = s['role']?.toString() ?? 'Biller';
        if (email.isNotEmpty) {
          final idx = users.indexWhere((u) => u['email']?.toLowerCase() == email.toLowerCase());
          if (idx != -1) {
            users[idx]['role'] = role;
            users[idx]['name'] = name;
          } else {
            users.add({
              'name': name,
              'username': email.split('@').first,
              'email': email,
              'password': '******',
              'role': role,
            });
          }
        }
      }
      await _save();
    } catch (e) {
      syncError = '$e';
      rethrow;
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await Future.wait([
      p.setString('expenses', jsonEncode(expenses)),
      p.setString('bankAccounts', jsonEncode(bankAccounts)),
      p.setBool('darkMode', darkMode),
      p.setString('firms', jsonEncode(firms)),
      p.setString('company', jsonEncode(company.toJson())),
      p.setString('settings', jsonEncode(settings.toJson())),
      p.setString('categories', jsonEncode(categories)),
      p.setString('users', jsonEncode(users)),
      p.setString('currentUser', currentUser != null ? jsonEncode(currentUser) : ''),
    ]);
    // Persist items, parties, transactions to SQLite to ensure in-memory changes are saved
    for (var item in items) {
      final j = item.toJson();
      j['isService'] = item.isService ? 1 : 0;
      await DbHelper.instance.insert('items', j);
    }
    for (var party in parties) {
      await DbHelper.instance.insert('parties', party.toJson());
    }
    for (var t in transactions) {
      final j = t.toJson();
      j['isGst'] = t.isGst ? 1 : 0;
      j['lines'] = jsonEncode(j['lines']);
      j['dispatch'] = jsonEncode(j['dispatch']);
      await DbHelper.instance.insert('transactions', j);
    }
    notifyListeners();
  }

  Future<void> saveCompany() async {
    if (remoteMode) {
      company = Company.fromJson(
        await api.updateBusiness(company.id, _businessPayload(company)),
      );
    }
    await _save();
  }

  Future<void> saveSettings() => _save();
  Future<void> addItem(Item value) async {
    final isNew = value.id.length != 36 && !value.id.startsWith(RegExp(r'[0-9]{16}'));
    if (isNew && value.id.length < 13) {
      value.id = DateTime.now().microsecondsSinceEpoch.toString();
    }
    items.removeWhere((i) => i.id == value.id);
    items.add(value);
    await _save();
    
    if (remoteMode) {
      await syncEngine.queueOperation('item', value.id, isNew ? 'CREATE' : 'UPDATE', _itemPayload(value), businessId: company.id);
    }
  }

  Future<void> addParty(Party value) async {
    final isNew = value.id.length != 36 && !value.id.startsWith(RegExp(r'[0-9]{16}'));
    if (isNew && value.id.length < 13) {
      value.id = DateTime.now().microsecondsSinceEpoch.toString();
    }
    parties.removeWhere((p) => p.id == value.id);
    parties.add(value);
    await _save();
    
    if (remoteMode) {
      await syncEngine.queueOperation('party', value.id, isNew ? 'CREATE' : 'UPDATE', _partyPayload(value), businessId: company.id);
    }
  }

  Future<void> addUser(Map<String, String> value) async {
    users.add(value);
    await _save();
  }

  Future<void> createUser({
    required String name,
    required String username,
    required String email,
    required String password,
    required String role,
  }) async {
    final entry = {
      'name': name.trim(),
      'username': username.trim().toLowerCase(),
      'email': email.trim().toLowerCase(),
      'password': password.trim(),
      'role': role.trim(),
    };
    users.add(entry);
    await _save();
    notifyListeners();

    if (remoteMode) {
      try {
        await api.createStaff(company.id, entry);
      } catch (_) {}
    }
  }

  Future<void> updateUser(
    String targetUsername, {
    String? name,
    String? email,
    String? password,
    String? role,
  }) async {
    final idx = users.indexWhere((u) => u['username']?.toLowerCase() == targetUsername.toLowerCase());
    if (idx != -1) {
      final existing = Map<String, String>.from(users[idx]);
      if (name != null && name.trim().isNotEmpty) existing['name'] = name.trim();
      if (email != null) existing['email'] = email.trim();
      if (password != null && password.trim().isNotEmpty) existing['password'] = password.trim();
      if (role != null && role.trim().isNotEmpty) existing['role'] = role.trim();
      users[idx] = existing;

      if (currentUser?['username']?.toLowerCase() == targetUsername.toLowerCase()) {
        currentUser = existing;
      }
      await _save();
      notifyListeners();
    }
  }

  Future<bool> deleteUser(String targetUsername) async {
    if (targetUsername.toLowerCase() == 'empirantraders') return false;
    users.removeWhere((u) => u['username']?.toLowerCase() == targetUsername.toLowerCase());
    await _save();
    notifyListeners();
    return true;
  }

  Future<void> persist() => _save();
  Map<String, dynamic> snapshot() => {
    'company': company.toJson(),
    'settings': settings.toJson(),
    'items': items.map((e) => e.toJson()).toList(),
    'parties': parties.map((e) => e.toJson()).toList(),
    'transactions': transactions.map((e) => e.toJson()).toList(),
    'expenses': expenses,
    'bankAccounts': bankAccounts,
  };
  void restore(Map<String, dynamic> data) {
    final nextCompany = Company.fromJson(
      Map<String, dynamic>.from(data['company']),
    );
    final nextSettings = InvoiceSettings.fromJson(
      Map<String, dynamic>.from(data['settings']),
    );
    final nextItems = (data['items'] as List)
        .map((e) => Item.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final nextParties = (data['parties'] as List)
        .map((e) => Party.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final nextTransactions = (data['transactions'] as List)
        .map((e) => BusinessTransaction.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final nextExpenses = (data['expenses'] as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final nextBanks = (data['bankAccounts'] as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    company = nextCompany;
    settings = nextSettings;
    items = nextItems;
    parties = nextParties;
    transactions = nextTransactions;
    expenses = nextExpenses;
    bankAccounts = nextBanks;
  }

  Future<void> switchFirm(String id) async {
    if (remoteMode) {
      final selected = remoteBusinesses.firstWhere((b) => '${b['id']}' == id);
      company = Company.fromJson(selected);
      await syncFromApi();
      return;
    }
    if (id == company.id) return;
    final next = firms[id];
    if (next == null) throw ArgumentError('Business not found.');
    firms[company.id] = jsonDecode(jsonEncode(snapshot()));
    restore(Map<String, dynamic>.from(next));
    await _save();
  }

  Future<void> addFirm(String name) async {
    if (name.trim().isEmpty) throw ArgumentError('Enter a business name.');
    if (remoteMode) {
      company = Company.fromJson(
        await api.createBusiness(_businessPayload(Company(name: name.trim()))),
      );
      await syncFromApi();
      return;
    }
    firms[company.id] = jsonDecode(jsonEncode(snapshot()));
    company = Company(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim(),
    );
    settings = InvoiceSettings();
    items = [];
    parties = [];
    transactions = [];
    expenses = [];
    bankAccounts = [];
    await _save();
  }

  Future<void> toggleTheme() async {
    darkMode = !darkMode;
    await _save();
  }

  int stockDirection(String type) => switch (type) {
    'order' || 'sale_invoice' || 'purchase_return' => -1,
    'purchase_bill' || 'sale_return' => 1,
    _ => 0,
  };
  double partyBalance(Party p) => remoteMode
      ? p.balance
      : p.balance +
            transactions
                .where((t) => t.partyId == p.id)
                .fold<double>(
                  0,
                  (sum, t) =>
                      sum +
                      switch (t.type) {
                        'order' || 'sale_invoice' => t.balance,
                        'purchase_bill' => -t.balance,
                        'payment_in' => -t.total,
                        'sale_return' => -t.balance,
                        'payment_out' => t.total,
                        'purchase_return' => t.balance,
                        _ => 0,
                      },
                );
  Future<void> deleteTransaction(BusinessTransaction t) async {
    final direction = stockDirection(t.type);
    for (final l in t.lines) {
      for (final item in items.where((i) => i.id == l.itemId && !i.isService)) {
        item.currentStock -= direction * l.quantity;
      }
    }
    transactions.removeWhere((x) => x.id == t.id);
    await _save();
    
    if (remoteMode) {
      await syncEngine.queueOperation('transaction', t.id, 'DELETE', {}, businessId: company.id);
    }
  }

  Future<BusinessTransaction> create({
    required bool gst,
    required String type,
    required List<InvoiceLine> lines,
    String partyName = '',
    String partyPhone = '',
    String? partyId,
    String? convertedFrom,
    double paid = 0,
    double discount = 0,
    double shipping = 0,
    String notes = '',
    String paymentMode = 'Cash',
    Map<String, String> dispatch = const {},
    DateTime? date,
    bool deductStock = true,
  }) async {
    if (lines.isEmpty ||
        lines.any(
          (l) =>
              !l.quantity.isFinite ||
              l.quantity <= 0 ||
              !l.price.isFinite ||
              l.price < 0,
        )) {
      throw ArgumentError('Add a valid quantity and price for each line.');
    }
    final subtotal = lines.fold<double>(0, (sum, l) => sum + l.total);
    if (!discount.isFinite ||
        discount < 0 ||
        discount > subtotal ||
        !shipping.isFinite ||
        shipping < 0 ||
        !paid.isFinite ||
        paid < 0) {
      throw ArgumentError('Check discount, shipping and payment amounts.');
    }
    if (convertedFrom != null &&
        transactions.any((t) => t.convertedFrom == convertedFrom)) {
      throw StateError('This quotation has already been converted.');
    }
    final quote = type == 'quotation' || type == 'estimate';
    final String no;
    if (quote) {
      settings.nonGstCounter++;
      no = FinancialYearService.generateDocumentNumber('QT', settings.nonGstCounter, date: date);
    } else if (gst) {
      settings.gstCounter++;
      no = FinancialYearService.generateDocumentNumber('INV', settings.gstCounter, date: date);
    } else {
      settings.nonGstCounter++;
      no = '${settings.nonGstPrefix}${settings.nonGstCounter}';
    }
    
    final t = BusinessTransaction(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: type,
      number: no,
      date: date ?? DateTime.now(),
      lines: lines.map((e) => InvoiceLine.fromJson(e.toJson())).toList(),
      partyName: partyName,
      partyPhone: partyPhone,
      partyId: partyId,
      isGst: gst,
      paid: paid,
      discount: discount,
      shipping: shipping,
      paymentMode: paymentMode,
      notes: notes,
      convertedFrom: convertedFrom,
      dispatch: Map.of(dispatch),
    );
    if (paid > t.total) throw ArgumentError('Payment cannot exceed the total.');
    for (final p in parties.where((p) => p.id == partyId)) {
      t.partyAddress = p.address;
      t.partyGstin = p.gstin;
    }
    if (type.startsWith('payment_')) {
      t.paid = t.total;
    }
    t.status = t.balance <= 0
        ? 'Paid'
        : paid > 0
        ? 'Partial'
        : 'Unpaid';
        
    transactions.insert(0, t);
    final direction = deductStock ? stockDirection(type) : 0;
    for (final l in lines) {
      for (final item in items.where((i) => i.id == l.itemId && !i.isService)) {
        item.currentStock += direction * l.quantity;
      }
    }
    // Counter incremented during generation to ensure no duplication

    await _save();
    
    if (remoteMode) {
      await syncEngine.queueOperation('transaction', t.id, 'CREATE', _transactionPayload(t), businessId: company.id);
    }
    
    return t;
  }

  Future<void> deleteItem(Item item) async {
    if (remoteMode) await api.deleteItem(company.id, item.id);
    items.removeWhere((i) => i.id == item.id);
    await _save();
  }

  Future<void> deleteParty(Party party) async {
    if (remoteMode) await api.deleteParty(company.id, party.id);
    parties.removeWhere((p) => p.id == party.id);
    await _save();
  }

  Future<void> changeStock(
    Item item,
    double change, {
    String reason = 'Manual adjustment',
  }) async {
    final next = item.currentStock + change;
    if (remoteMode) {
      final data = await api.adjustStock(company.id, item.id, {
        'newStock': next,
        'adjustmentType': change < 0 ? 'reduce' : 'add',
        'quantity': change.abs(),
        'reason': reason,
      });
      final replacement = Item.fromJson(data);
      items[items.indexWhere((i) => i.id == item.id)] = replacement;
    } else {
      item.currentStock = next;
    }
    await _save();
  }

  Future<Map<String, dynamic>> saveExpense(Map<String, dynamic> record) async {
    if (remoteMode) {
      record = _expenseFromApi(
        await api.createExpense(company.id, {
          'category': record['Category'],
          'date': record['date'],
          'amount': record['amount'],
          'paymentMode': '${record['Payment mode']}'.toLowerCase(),
          'bankAccountId': null,
          'paidTo': record['Expense name'],
          'notes': record['Notes'],
          'receiptUrl': null,
        }),
      );
    }
    expenses.insert(0, record);
    await _save();
    return record;
  }

  Future<Map<String, dynamic>> saveBankAccount(
    Map<String, dynamic> record,
  ) async {
    if (remoteMode) {
      record = _bankFromApi(
        await api.createBankAccount(company.id, {
          'accountName': record['Account name'],
          'bankName': record['Bank name'],
          'accountNo': record['Account number'],
          'ifsc': record['IFSC'],
          'branch': null,
          'openingBalance': record['amount'],
          'currentBalance': record['amount'],
          'isDefault': false,
        }),
      );
    }
    bankAccounts.insert(0, record);
    await _save();
    return record;
  }

  Future<void> deleteRecord(
    Map<String, dynamic> record, {
    required bool bank,
  }) async {
    if (remoteMode) {
      if (bank) {
        await api.deleteBankAccount(company.id, '${record['id']}');
      } else {
        await api.deleteExpense(company.id, '${record['id']}');
      }
    }
    (bank ? bankAccounts : expenses).remove(record);
    await _save();
  }

  static Map<String, dynamic> _businessPayload(Company c) => {
    'name': c.name,
    'legalName': c.name,
    'gstin': c.gstin.isEmpty ? null : c.gstin,
    'pan': null,
    'phone': c.phone,
    'email': c.email,
    'addressLine1': c.address,
    'addressLine2': null,
    'city': null,
    'stateCode': c.stateCode,
    'pincode': null,
    'invoicePrefix': 'INV',
    'defaultTerms': null,
  };
  static Map<String, dynamic> _itemPayload(Item i) => {
    'name': i.name,
    'category': i.category,
    'itemCode': i.itemCode,
    'barcode': null,
    'hsn': i.hsn,
    'unit': i.unit,
    'secondaryUnit': null,
    'conversionFactor': 1,
    'salesPrice': i.salesPrice,
    'salesPriceIncludesTax': false,
    'purchasePrice': i.purchasePrice,
    'purchasePriceIncludesTax': false,
    'mrp': i.salesPrice,
    'minimumPrice': 0,
    'openingStock': i.currentStock,
    'currentStock': i.currentStock,
    'lowStockLimit': i.lowStockLimit,
    'taxRate': 0,
    'isService': i.isService,
    'batchNumber': null,
    'manufacturingDate': null,
    'expiryDate': null,
    'warehouse': null,
    'rawMaterialsJson': null,
  };
  static Map<String, dynamic> _partyPayload(Party p) => {
    'name': p.name,
    'phone': p.phone,
    'email': p.email,
    'type': p.type.toLowerCase(),
    'gstin': p.gstin,
    'pan': null,
    'address': p.address,
    'shippingAddress': null,
    'openingBalance': p.balance.abs(),
    'openingBalanceType': p.balance < 0 ? 'payable' : 'receivable',
    'creditLimit': 0,
    'creditPeriodDays': 0,
    'group': null,
  };
  static String _remoteType(String type) => switch (type) {
    'order' => 'sale_invoice',
    'quotation' => 'estimate',
    _ => type,
  };
  static Map<String, dynamic> _transactionPayload(BusinessTransaction t) => {
    'txnType': _remoteType(t.type),
    'txnNo': t.number,
    'partyId': t.partyId?.length == 36 ? t.partyId : null,
    'partyName': t.partyName,
    'date': t.date.toIso8601String(),
    'dueDate': null,
    'lineItems': t.lines
        .map(
          (l) => {
            'itemId': l.itemId.length == 36 ? l.itemId : null,
            'name': l.name,
            'hsn': l.hsn,
            'quantity': l.quantity,
            'unit': l.unit,
            'price': l.price,
            'discountPercent': 0,
            'discountAmount': 0,
            'taxRate': t.isGst ? 18 : 0,
            'taxAmount': t.isGst ? l.total * .18 : 0,
            'total': l.total,
          },
        )
        .toList(),
    'subTotal': t.subtotal,
    'discountPercent': 0,
    'discountAmount': t.discount,
    'taxTotal': t.cgst + t.sgst,
    'cgst': t.cgst,
    'sgst': t.sgst,
    'igst': 0,
    'shippingCharges': t.shipping,
    'grandTotal': t.total,
    'paidAmount': t.paid,
    'balanceDue': t.balance,
    'paymentMode': t.paymentMode.toLowerCase(),
    'bankAccountId': null,
    'status': t.status.toLowerCase(),
    'referenceNo': t.convertedFrom,
    'notes': jsonEncode({'text': t.notes, 'dispatch': t.dispatch}),
    'expenseCategory': null,
  };
  static Map<String, dynamic> _expenseFromApi(Map<String, dynamic> e) => {
    ...e,
    'Expense name': e['paidTo'] ?? e['category'],
    'Category': e['category'],
    'Amount': '${e['amount']}',
    'Payment mode': e['paymentMode'] ?? '',
    'Notes': e['notes'] ?? '',
  };
  static Map<String, dynamic> _bankFromApi(Map<String, dynamic> b) => {
    ...b,
    'Account name': b['accountName'],
    'Bank name': b['bankName'],
    'Account number': b['accountNo'] ?? '',
    'IFSC': b['ifsc'] ?? '',
    'Opening balance': '${b['currentBalance'] ?? b['openingBalance']}',
    'amount': b['currentBalance'] ?? b['openingBalance'] ?? 0,
  };
}
