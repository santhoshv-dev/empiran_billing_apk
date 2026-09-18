import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:empiran/data/local/db_helper.dart';
import 'package:empiran/models.dart';
import 'package:empiran/features/search/models/search_models.dart';

class LocalSearchService {
  /// Executes a unified on-device search across Products, Customers, Suppliers,
  /// Invoices, Orders, Quotes, Categories, and Staff without calling any remote API.
  static Future<GlobalSearchResponse> search({
    required String query,
    String type = 'all',
    int page = 1,
    int pageSize = 20,
    List<Item>? activeItems,
    List<Party>? activeParties,
    List<BusinessTransaction>? activeTransactions,
  }) async {
    final raw = query.trim();
    if (raw.isEmpty) {
      return GlobalSearchResponse(
        query: '',
        totalResults: 0,
        page: page,
        pageSize: pageSize,
        hasMore: false,
        counts: const SearchCounts(),
        results: const [],
      );
    }

    final queryType = type.trim().toLowerCase();
    final cleanAlphanumeric =
        raw.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    final phoneDigits = raw.replaceAll(RegExp(r'\D'), '');

    final tokens = RegExp(r'[a-zA-Z]+|\d+')
        .allMatches(raw)
        .map((m) => m.group(0)!.toLowerCase())
        .where((s) => s.length >= 2)
        .toSet()
        .toList();

    final List<SearchResultItem> allMatched = [];

    int productsCount = 0;
    int customersCount = 0;
    int suppliersCount = 0;
    int invoicesCount = 0;
    int categoriesCount = 0;
    int staffCount = 0;
    int expensesCount = 0;

    // 1. Load data from provided active lists or local DbHelper SQLite tables
    final items = activeItems ?? await _loadItems();
    final parties = activeParties ?? await _loadParties();
    final transactions = activeTransactions ?? await _loadTransactions();
    final categories = await _loadCategories(items);
    final users = await _loadUsers();

    // --- PRODUCTS ---
    if (queryType == 'all' || queryType == 'products') {
      for (final item in items) {
        final score = _matchScore(
          primary: item.name,
          secondary: item.itemCode,
          tertiary: '${item.category} ${item.hsn}',
          raw: raw,
          cleanAlphanumeric: cleanAlphanumeric,
          tokens: tokens,
        );

        if (score > 0) {
          productsCount++;
          final badge = item.isService
              ? 'Service'
              : '${item.currentStock.toStringAsFixed(item.currentStock.truncateToDouble() == item.currentStock ? 0 : 2)} ${item.unit}';
          final subtitle =
              'SKU: ${item.itemCode.isNotEmpty ? item.itemCode : "—"} | ${item.category}';

          allMatched.add(SearchResultItem(
            id: item.id,
            type: 'product',
            title: item.name,
            subtitle: subtitle,
            badge: badge,
            amount: item.salesPrice,
            date: null,
            score: score,
            metadata: {
              'category': item.category,
              'itemCode': item.itemCode,
              'unit': item.unit,
            },
          ));
        }
      }
    }

    // --- PARTIES (CUSTOMERS & SUPPLIERS) ---
    if (queryType == 'all' ||
        queryType == 'customers' ||
        queryType == 'suppliers') {
      for (final party in parties) {
        final isSupplier = party.type.toLowerCase() == 'vendor' ||
            party.type.toLowerCase() == 'supplier';
        final isCustomer = !isSupplier || party.type.toLowerCase() == 'both';

        if (queryType == 'customers' && !isCustomer) continue;
        if (queryType == 'suppliers' && !isSupplier) continue;

        final score = _matchScore(
          primary: party.name,
          secondary: party.phone,
          tertiary: '${party.email} ${party.address} ${party.gstin}',
          raw: raw,
          cleanAlphanumeric: cleanAlphanumeric,
          tokens: tokens,
          phoneDigits: phoneDigits,
        );

        if (score > 0) {
          if (isSupplier) {
            suppliersCount++;
          } else {
            customersCount++;
          }

          final entityType = isSupplier ? 'supplier' : 'customer';
          final subtitle = party.phone.isNotEmpty
              ? '${party.phone} ${party.email.isNotEmpty ? "• ${party.email}" : ""}'
              : (party.email.isNotEmpty ? party.email : party.address);

          allMatched.add(SearchResultItem(
            id: party.id,
            type: entityType,
            title: party.name,
            subtitle: subtitle,
            badge: isSupplier ? 'Supplier' : 'Customer',
            amount: party.balance,
            date: null,
            score: score,
            metadata: {
              'phone': party.phone,
              'email': party.email,
              'partyType': party.type,
            },
          ));
        }
      }
    }

    // --- TRANSACTIONS (INVOICES, ORDERS, QUOTES) ---
    if (queryType == 'all' || queryType == 'invoices') {
      for (final txn in transactions) {
        final lineNames = txn.lines.map((l) => l.name).join(' ');
        final score = _matchScore(
          primary: txn.number,
          secondary: txn.partyName,
          tertiary:
              '${txn.partyPhone} ${txn.status} ${txn.paymentMode} $lineNames',
          raw: raw,
          cleanAlphanumeric: cleanAlphanumeric,
          tokens: tokens,
          phoneDigits: phoneDigits,
        );

        if (score > 0) {
          invoicesCount++;
          final isQuote = txn.type.toLowerCase().contains('quote') ||
              txn.type.toLowerCase() == 'quotation';
          final typeLabel = isQuote ? 'quotation' : 'invoice';

          allMatched.add(SearchResultItem(
            id: txn.id,
            type: typeLabel,
            title:
                '${txn.number} — ${txn.partyName.isNotEmpty ? txn.partyName : "Cash Sale"}',
            subtitle:
                'Status: ${txn.status.toUpperCase()} • Mode: ${txn.paymentMode.toUpperCase()}',
            badge: txn.status.toUpperCase(),
            amount: txn.total,
            date: txn.date,
            score: score,
            metadata: {
              'txnNo': txn.number,
              'txnType': txn.type,
              'status': txn.status,
            },
          ));
        }
      }
    }

    // --- CATEGORIES ---
    if (queryType == 'all' || queryType == 'categories') {
      for (final cat in categories) {
        final score = _matchScore(
          primary: cat,
          raw: raw,
          cleanAlphanumeric: cleanAlphanumeric,
          tokens: tokens,
        );

        if (score > 0) {
          categoriesCount++;
          allMatched.add(SearchResultItem(
            id: cat,
            type: 'category',
            title: cat,
            subtitle: 'Product Category',
            badge: 'Category',
            score: score,
          ));
        }
      }
    }

    // --- USERS / STAFF ---
    if (queryType == 'all' || queryType == 'staff') {
      for (final u in users) {
        final name = u['name'] ?? '';
        final email = u['email'] ?? '';
        final role = u['role'] ?? 'Biller';

        final score = _matchScore(
          primary: name,
          secondary: email,
          tertiary: role,
          raw: raw,
          cleanAlphanumeric: cleanAlphanumeric,
          tokens: tokens,
        );

        if (score > 0) {
          staffCount++;
          allMatched.add(SearchResultItem(
            id: u['id'] ?? u['userId'] ?? name,
            type: 'staff',
            title: name,
            subtitle: '$email ($role)',
            badge: role,
            score: score,
            metadata: {'email': email, 'role': role},
          ));
        }
      }
    }

    // 2. Sort by relevance Score descending
    allMatched.sort((a, b) => b.score.compareTo(a.score));

    // 3. Paginate
    final skip = (page - 1) * pageSize;
    final pagedResults = allMatched.skip(skip).take(pageSize).toList();
    final hasMore = (skip + pageSize) < allMatched.length;

    final allCount = productsCount +
        customersCount +
        suppliersCount +
        invoicesCount +
        categoriesCount +
        staffCount +
        expensesCount;
    final counts = SearchCounts(
      all: allCount,
      products: productsCount,
      customers: customersCount,
      suppliers: suppliersCount,
      invoices: invoicesCount,
      categories: categoriesCount,
      staff: staffCount,
      expenses: expensesCount,
    );

    return GlobalSearchResponse(
      query: raw,
      totalResults: allMatched.length,
      page: page,
      pageSize: pageSize,
      hasMore: hasMore,
      counts: counts,
      results: pagedResults,
    );
  }

  /// Calculates relevance matching score (0 = no match, 50-100 = match)
  static int _matchScore({
    required String primary,
    String secondary = '',
    String tertiary = '',
    required String raw,
    required String cleanAlphanumeric,
    required List<String> tokens,
    String? phoneDigits,
  }) {
    final pLower = primary.toLowerCase();
    final sLower = secondary.toLowerCase();
    final tLower = tertiary.toLowerCase();
    final rLower = raw.toLowerCase();

    // 1. Exact match
    if (pLower == rLower || sLower == rLower) return 100;

    // 2. StartsWith prefix match
    if (pLower.startsWith(rLower) || sLower.startsWith(rLower)) return 95;

    // 3. Phone number digit search (e.g. 9876543210 vs +91 98765-43210)
    if (phoneDigits != null && phoneDigits.length >= 3) {
      final targetDigits = '$secondary $tertiary'.replaceAll(RegExp(r'\D'), '');
      if (targetDigits.contains(phoneDigits)) return 90;
    }

    // 4. Direct substring match
    if (pLower.contains(rLower) || sLower.contains(rLower)) return 85;
    if (tLower.contains(rLower)) return 80;

    // 5. Space-agnostic matching (e.g. "iphone15" matches "iPhone 15", "johnsmith" matches "John Smith")
    final pClean =
        primary.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    final sClean =
        secondary.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    if (cleanAlphanumeric.isNotEmpty) {
      if (pClean.contains(cleanAlphanumeric) ||
          sClean.contains(cleanAlphanumeric)) {
        return 80;
      }
    }

    // 6. Multi-token match (e.g. query "iphon15" tokens ["iphon", "15"] both exist in "iPhone 15")
    if (tokens.length > 1) {
      final combined = '$pLower $sLower $tLower';
      if (tokens.every((tok) => combined.contains(tok))) {
        return 75;
      }
    }

    // 7. Token stem typo tolerance (for words >= 4 chars, prefix stem matches)
    for (final tok in tokens) {
      if (tok.length >= 4) {
        final stem = tok.substring(0, tok.length - 1);
        if (pLower.contains(stem) || sLower.contains(stem)) {
          return 72;
        }
      }
    }

    // 8. Levenshtein edit distance typo tolerance (e.g. "iphon" vs "iphone")
    if (rLower.length >= 4) {
      final pWords = pLower.split(RegExp(r'\s+'));
      for (final w in pWords) {
        if (w.length >= 4) {
          final dist = _levenshtein(w, rLower);
          if (dist <= 2) return 70;
        }
      }
    }

    return 0; // No match
  }

  static int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    final v0 = List<int>.generate(t.length + 1, (i) => i);
    final v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        final cost = (s.codeUnitAt(i) == t.codeUnitAt(j)) ? 0 : 1;
        v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
      }
      for (int j = 0; j <= t.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[t.length];
  }

  // --- Helpers for loading local data ---

  static Future<List<Item>> _loadItems() async {
    try {
      final rows = await DbHelper.instance.queryAll('items');
      return rows.map((r) => Item.fromJson(r)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<Party>> _loadParties() async {
    try {
      final rows = await DbHelper.instance.queryAll('parties');
      return rows.map((r) => Party.fromJson(r)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<BusinessTransaction>> _loadTransactions() async {
    try {
      final rows = await DbHelper.instance.queryAll('transactions');
      return rows.map((r) => BusinessTransaction.fromJson(r)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<String>> _loadCategories(List<Item> items) async {
    final catSet = <String>{'General'};

    for (final item in items) {
      if (item.category.trim().isNotEmpty) {
        catSet.add(item.category.trim());
      }
    }

    try {
      final rows = await DbHelper.instance.queryAll('categories');
      for (final r in rows) {
        final name = (r['name'] ?? r['Name'])?.toString().trim();
        if (name != null && name.isNotEmpty) catSet.add(name);
      }
    } catch (_) {}

    return catSet.toList();
  }

  static Future<List<Map<String, String>>> _loadUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('staff_users');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .map((e) => Map<String, String>.from(e as Map))
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }
}
