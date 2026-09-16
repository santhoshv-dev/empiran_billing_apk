class SearchResultItem {
  final String id;
  final String type; // 'product' | 'customer' | 'supplier' | 'invoice' | 'quotation' | 'category' | 'staff' | 'expense'
  final String title;
  final String subtitle;
  final String? badge;
  final double? amount;
  final DateTime? date;
  final int score;
  final Map<String, dynamic>? metadata;

  const SearchResultItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    this.badge,
    this.amount,
    this.date,
    this.score = 50,
    this.metadata,
  });

  factory SearchResultItem.fromJson(Map<String, dynamic> json) {
    double? amt;
    if (json['amount'] != null) {
      amt = (json['amount'] as num).toDouble();
    }

    DateTime? dt;
    if (json['date'] != null) {
      dt = DateTime.tryParse(json['date'].toString());
    }

    return SearchResultItem(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString().toLowerCase() ?? 'general',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      badge: json['badge']?.toString(),
      amount: amt,
      date: dt,
      score: (json['score'] as num?)?.toInt() ?? 50,
      metadata: json['metadata'] is Map ? Map<String, dynamic>.from(json['metadata'] as Map) : null,
    );
  }
}

class SearchCounts {
  final int all;
  final int products;
  final int customers;
  final int suppliers;
  final int invoices;
  final int categories;
  final int staff;
  final int expenses;

  const SearchCounts({
    this.all = 0,
    this.products = 0,
    this.customers = 0,
    this.suppliers = 0,
    this.invoices = 0,
    this.categories = 0,
    this.staff = 0,
    this.expenses = 0,
  });

  factory SearchCounts.fromJson(Map<String, dynamic> json) {
    return SearchCounts(
      all: (json['all'] as num?)?.toInt() ?? 0,
      products: (json['products'] as num?)?.toInt() ?? 0,
      customers: (json['customers'] as num?)?.toInt() ?? 0,
      suppliers: (json['suppliers'] as num?)?.toInt() ?? 0,
      invoices: (json['invoices'] as num?)?.toInt() ?? 0,
      categories: (json['categories'] as num?)?.toInt() ?? 0,
      staff: (json['staff'] as num?)?.toInt() ?? 0,
      expenses: (json['expenses'] as num?)?.toInt() ?? 0,
    );
  }
}

class GlobalSearchResponse {
  final String query;
  final int totalResults;
  final int page;
  final int pageSize;
  final bool hasMore;
  final SearchCounts counts;
  final List<SearchResultItem> results;

  const GlobalSearchResponse({
    required this.query,
    required this.totalResults,
    required this.page,
    required this.pageSize,
    required this.hasMore,
    required this.counts,
    required this.results,
  });

  factory GlobalSearchResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['results'] as List? ?? [])
        .map((e) => SearchResultItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return GlobalSearchResponse(
      query: json['query']?.toString() ?? '',
      totalResults: (json['totalResults'] as num?)?.toInt() ?? list.length,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
      hasMore: json['hasMore'] == true,
      counts: json['counts'] is Map
          ? SearchCounts.fromJson(Map<String, dynamic>.from(json['counts'] as Map))
          : const SearchCounts(),
      results: list,
    );
  }
}
