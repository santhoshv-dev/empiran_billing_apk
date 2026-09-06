import 'package:dio/dio.dart';

class ApiClient {
  ApiClient({Dio? dio})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: const String.fromEnvironment(
                'API_URL',
                defaultValue: 'https://empiran-api.runasp.net/api/v1',
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
}
