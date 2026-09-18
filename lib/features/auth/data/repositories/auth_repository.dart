import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../data/remote/api_client.dart';
import '../models/user_model.dart';

class AuthRepository {
  final ApiClient apiClient;
  final FlutterSecureStorage secureStorage;

  AuthRepository({
    required this.apiClient,
    this.secureStorage = const FlutterSecureStorage(),
  });

  Future<UserModel> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    final response = await apiClient.login(usernameOrEmail, password);
    final token = (response['accessToken'] ?? response['token']) as String?;

    if (token != null && token.isNotEmpty) {
      await secureStorage.write(key: AppConstants.tokenKey, value: token);
      apiClient.token = token;
    }

    final userJson = response['user'] as Map<String, dynamic>? ?? response;
    final user = UserModel.fromJson(userJson, token: token);

    await secureStorage.write(
      key: AppConstants.userKey,
      value: jsonEncode(user.toJson()),
    );

    return user;
  }

  Future<UserModel?> checkAuthStatus() async {
    final token = await secureStorage.read(key: AppConstants.tokenKey);
    if (token == null || token.isEmpty) {
      return null;
    }

    apiClient.token = token;
    try {
      final freshUserJson = await apiClient.getCurrentUser();
      final freshUser = UserModel.fromJson(freshUserJson, token: token);
      await secureStorage.write(
        key: AppConstants.userKey,
        value: jsonEncode(freshUser.toJson()),
      );
      return freshUser;
    } catch (_) {}

    final cachedUserString =
        await secureStorage.read(key: AppConstants.userKey);
    if (cachedUserString != null && cachedUserString.isNotEmpty) {
      try {
        final json = jsonDecode(cachedUserString) as Map<String, dynamic>;
        return UserModel.fromJson(json, token: token);
      } catch (_) {}
    }

    return UserModel(
      username: 'User',
      name: 'User',
      token: token,
    );
  }

  Future<void> logout() async {
    await secureStorage.delete(key: AppConstants.tokenKey);
    await secureStorage.delete(key: AppConstants.userKey);
    apiClient.token = null;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await apiClient.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  Future<void> forgotPassword(String email) async {
    await apiClient.forgotPassword(email);
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await apiClient.resetPassword(
      token: token,
      newPassword: newPassword,
    );
  }
}
