import 'package:dio/dio.dart';

class ApiClient {
  ApiClient()
    : dio = Dio(
        BaseOptions(
          baseUrl: const String.fromEnvironment(
            'API_URL',
            defaultValue: 'http://localhost:5186/api/v1',
          ),
          connectTimeout: const Duration(seconds: 8),
        ),
      );
  final Dio dio;
  String? token;
  Options get auth => Options(headers: {'Authorization': 'Bearer $token'});

  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await dio.post(
      '/auth/login',
      data: {'email': username, 'username': username, 'password': password},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    token = (data['accessToken'] ?? data['token']) as String?;
    return data;
  }

  Future<dynamic> getCompany(String businessId) =>
      dio.get('/businesses/$businessId', options: auth);
  Future<dynamic> updateCompany(String businessId, Map<String, dynamic> data) =>
      dio.put('/businesses/$businessId', data: data, options: auth);
  Future<dynamic> getItems(String businessId) =>
      dio.get('/businesses/$businessId/items', options: auth);
  Future<dynamic> createItem(String businessId, Map<String, dynamic> data) =>
      dio.post('/businesses/$businessId/items', data: data, options: auth);
  Future<dynamic> getTransactions(String businessId) =>
      dio.get('/businesses/$businessId/transactions', options: auth);
  Future<dynamic> createTransaction(
    String businessId,
    Map<String, dynamic> data,
  ) => dio.post(
    '/businesses/$businessId/transactions',
    data: data,
    options: auth,
  );
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
