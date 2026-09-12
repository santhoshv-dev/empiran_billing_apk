import 'package:dio/dio.dart';

class ApiClient {
  ApiClient({Dio? dio})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: _normalizeUrl(
                const String.fromEnvironment(
                  'API_URL',
                  defaultValue: 'https://empiran-api.runasp.net/api/v1',
                ),
              ),
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
              headers: const {'Accept': 'application/json'},
            ),
          ) {
    this.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
          // Prevent Dio from dropping baseUrl path segments (e.g. /api/v1/)
          // when relative paths begin with a leading slash
          if (!options.path.startsWith('http://') && !options.path.startsWith('https://')) {
            while (options.path.startsWith('/')) {
              options.path = options.path.substring(1);
            }
          }
          handler.next(options);
        },
        onError: (error, handler) => handler.reject(
          DioException(
            requestOptions: error.requestOptions,
            response: error.response,
            type: error.type,
            error: error.error,
            message: _message(error),
          ),
        ),
      ),
    );
  }
  final Dio dio;
  String? token;

  static String _normalizeUrl(String url) {
    var clean = url.trim();
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    return '$clean/';
  }

  String get baseUrl {
    final raw = dio.options.baseUrl;
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  set baseUrl(String url) {
    dio.options.baseUrl = _normalizeUrl(url);
  }

  /// Live health check probe supporting both local API /health and cloud controllers
  Future<Map<String, dynamic>> checkHealth([String? targetUrl]) async {
    final raw = targetUrl?.trim();
    final urlToTest = (raw != null && raw.isNotEmpty) ? raw : baseUrl;
    final sw = Stopwatch()..start();
    try {
      var clean = urlToTest;
      while (clean.endsWith('/')) {
        clean = clean.substring(0, clean.length - 1);
      }
      final testDio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 6),
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      // Probe 1: Dedicated health endpoint (/health or /api/v1/health)
      final healthUri = clean.endsWith('/api/v1') ? '$clean/health' : '$clean/api/v1/health';
      try {
        final res = await testDio.get(healthUri);
        if (res.statusCode == 200 && res.data is Map) {
          sw.stop();
          final m = res.data as Map;
          return {
            'healthy': true,
            'latencyMs': sw.elapsedMilliseconds,
            'environment': m['environment']?.toString() ?? 'Development',
            'service': m['service']?.toString() ?? 'Empiran Business Suite API',
            'message': 'Connected successfully (${sw.elapsedMilliseconds}ms)',
          };
        }
      } catch (_) {
        // Fallback to checking API root
      }

      // Probe 2: Business controller fallback (401 or 200 means API is live and rejecting unauthenticated)
      final apiUri = clean.endsWith('/api/v1') ? '$clean/businesses' : '$clean/api/v1/businesses';
      final resApi = await testDio.get(apiUri);
      sw.stop();
      if (resApi.statusCode == 200 || resApi.statusCode == 401) {
        return {
          'healthy': true,
          'latencyMs': sw.elapsedMilliseconds,
          'environment': clean.contains('localhost') || clean.contains('127.0.0.1')
              ? 'Local Dev'
              : 'Cloud Production',
          'service': 'Empiran Business Suite API',
          'message': 'Connected successfully (${sw.elapsedMilliseconds}ms)',
        };
      }

      return {
        'healthy': false,
        'latencyMs': sw.elapsedMilliseconds,
        'message': 'Server returned HTTP ${resApi.statusCode}',
      };
    } catch (e) {
      sw.stop();
      return {
        'healthy': false,
        'latencyMs': sw.elapsedMilliseconds,
        'message': 'Cannot reach server (${e.toString().split('\n').first})',
      };
    }
  }

  static String _message(DioException error) {
    final body = error.response?.data;
    if (body is Map && body['message'] != null) return '${body['message']}';
    if (body is Map && body['errors'] is Map) {
      return (body['errors'] as Map).values
          .expand((v) => v is List ? v : [v])
          .join('\n');
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return 'Cannot reach the Empiran API. Check the server and API_URL.';
    }
    return error.message ?? 'API request failed.';
  }

  Map<String, dynamic> _map(Response r) =>
      Map<String, dynamic>.from(r.data as Map);
  List<Map<String, dynamic>> _list(Response r) =>
      (r.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  Future<Map<String, dynamic>> login(String email, String password) async {
    final data = _map(
      await dio.post(
        '/auth/login',
        data: {'email': email.trim(), 'password': password},
      ),
    );
    token = (data['accessToken'] ?? data['token']) as String?;
    return data;
  }

  Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
  ) async {
    final data = _map(
      await dio.post(
        '/auth/register',
        data: {
          'name': name.trim(),
          'email': email.trim(),
          'password': password,
        },
      ),
    );
    token = (data['accessToken'] ?? data['token']) as String?;
    return data;
  }

  Future<List<Map<String, dynamic>>> getBusinesses() async =>
      _list(await dio.get('/businesses'));
  Future<Map<String, dynamic>> createBusiness(
    Map<String, dynamic> data,
  ) async => _map(await dio.post('/businesses', data: data));
  Future<Map<String, dynamic>> updateBusiness(
    String id,
    Map<String, dynamic> data,
  ) async => _map(await dio.put('/businesses/$id', data: data));
  Future<List<Map<String, dynamic>>> getItems(String id) async =>
      _list(await dio.get('/businesses/$id/items'));
  Future<Map<String, dynamic>> createItem(
    String id,
    Map<String, dynamic> data,
  ) async => _map(await dio.post('/businesses/$id/items', data: data));
  Future<Map<String, dynamic>> updateItem(
    String id,
    String itemId,
    Map<String, dynamic> data,
  ) async => _map(await dio.put('/businesses/$id/items/$itemId', data: data));
  Future<Map<String, dynamic>> adjustStock(
    String id,
    String itemId,
    Map<String, dynamic> data,
  ) async => _map(
    await dio.post('/businesses/$id/items/$itemId/adjust-stock', data: data),
  );
  Future<void> deleteItem(String id, String itemId) async =>
      dio.delete('/businesses/$id/items/$itemId');
  Future<List<Map<String, dynamic>>> getParties(String id) async =>
      _list(await dio.get('/businesses/$id/parties'));
  Future<Map<String, dynamic>> createParty(
    String id,
    Map<String, dynamic> data,
  ) async => _map(await dio.post('/businesses/$id/parties', data: data));
  Future<Map<String, dynamic>> updateParty(
    String id,
    String partyId,
    Map<String, dynamic> data,
  ) async =>
      _map(await dio.put('/businesses/$id/parties/$partyId', data: data));
  Future<void> deleteParty(String id, String partyId) async =>
      dio.delete('/businesses/$id/parties/$partyId');
  Future<List<Map<String, dynamic>>> getTransactions(String id) async =>
      _list(await dio.get('/businesses/$id/transactions'));
  Future<Map<String, dynamic>> createTransaction(
    String id,
    Map<String, dynamic> data,
  ) async => _map(await dio.post('/businesses/$id/transactions', data: data));
  Future<void> deleteTransaction(String id, String transactionId) async =>
      dio.delete('/businesses/$id/transactions/$transactionId');
  Future<List<Map<String, dynamic>>> getExpenses(String id) async =>
      _list(await dio.get('/businesses/$id/expenses'));
  Future<Map<String, dynamic>> createExpense(
    String id,
    Map<String, dynamic> data,
  ) async => _map(await dio.post('/businesses/$id/expenses', data: data));
  Future<void> deleteExpense(String id, String expenseId) async =>
      dio.delete('/businesses/$id/expenses/$expenseId');
  Future<List<Map<String, dynamic>>> getBankAccounts(String id) async =>
      _list(await dio.get('/businesses/$id/bank-accounts'));
  Future<Map<String, dynamic>> createBankAccount(
    String id,
    Map<String, dynamic> data,
  ) async => _map(await dio.post('/businesses/$id/bank-accounts', data: data));
  Future<void> deleteBankAccount(String id, String accountId) async =>
      dio.delete('/businesses/$id/bank-accounts/$accountId');
  Future<Map<String, dynamic>> getProfitAndLoss(
    String id, {
    DateTime? from,
    DateTime? to,
  }) async => _map(
    await dio.get(
      '/businesses/$id/reports/pnl',
      queryParameters: {
        if (from != null) 'from': from.toIso8601String(),
        if (to != null) 'to': to.toIso8601String(),
      },
    ),
  );
  Future<List<Map<String, dynamic>>> getStockSummary(String id) async =>
      _list(await dio.get('/businesses/$id/reports/stock-summary'));
  Future<List<Map<String, dynamic>>> getCategories(String id) async =>
      _list(await dio.get('/businesses/$id/categories'));
  Future<Map<String, dynamic>> createCategory(
    String id,
    Map<String, dynamic> data,
  ) async => _map(await dio.post('/businesses/$id/categories', data: data));
  Future<Map<String, dynamic>> updateCategory(
    String id,
    String categoryId,
    Map<String, dynamic> data,
  ) async => _map(await dio.put('/businesses/$id/categories/$categoryId', data: data));
  Future<void> deleteCategory(String id, String categoryId) async =>
      dio.delete('/businesses/$id/categories/$categoryId');

  Future<List<Map<String, dynamic>>> getStaff(String id) async =>
      _list(await dio.get('/businesses/$id/staff'));
  Future<Map<String, dynamic>> createStaff(
    String id,
    Map<String, dynamic> data,
  ) async => _map(await dio.post('/businesses/$id/staff', data: data));
  Future<Map<String, dynamic>> updateStaffRole(
    String id,
    String userId,
    String role,
  ) async => _map(await dio.put('/businesses/$id/staff/$userId', data: {'role': role}));
  Future<void> deleteStaff(String id, String userId) async =>
      dio.delete('/businesses/$id/staff/$userId');

  Future<Map<String, dynamic>> getEmailStatus() async =>
      _map(await dio.get('/email/status'));
  Future<Map<String, dynamic>> sendTestEmail([String? toEmail]) async =>
      _map(await dio.post('/email/test', data: toEmail != null ? {'toEmail': toEmail} : {}));
  Future<Map<String, dynamic>> sendInvoiceEmail(Map<String, dynamic> data) async =>
      _map(await dio.post('/email/invoice', data: data));

  Future<Map<String, dynamic>?> getItemImage(String businessId, String itemId) async {
    try {
      return _map(await dio.get('/businesses/$businessId/items/$itemId/image'));
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> uploadItemImageBase64(String businessId, String itemId, String base64) async =>
      _map(await dio.post('/businesses/$businessId/items/$itemId/image/base64', data: {'base64Data': base64}));

  Future<void> deleteItemImage(String businessId, String itemId) async =>
      dio.delete('/businesses/$businessId/items/$itemId/image');
}
