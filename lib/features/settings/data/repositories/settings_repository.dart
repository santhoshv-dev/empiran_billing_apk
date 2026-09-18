import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../data/remote/api_client.dart';
import '../../../../models.dart';

class SettingsRepository {
  final ApiClient apiClient;

  SettingsRepository({required this.apiClient});

  Future<Company> loadCompany() async {
    final prefs = await SharedPreferences.getInstance();
    Company company = Company();
    final jsonString = prefs.getString(AppConstants.companyKey);
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        company = Company.fromJson(jsonDecode(jsonString));
        if (company.name.trim() == '1') {
          company.name = 'Empiran Traders';
        }
      } catch (_) {}
    }

    if (apiClient.token != null && apiClient.token!.isNotEmpty) {
      try {
        final businesses = await apiClient.getBusinesses();
        if (businesses.isNotEmpty) {
          final b = businesses.first;
          final realId = b['id']?.toString() ?? company.id;
          final remoteName = b['name']?.toString().trim();
          company = Company(
            id: realId,
            name: remoteName == null || remoteName.isEmpty || remoteName == '1'
                ? company.displayName
                : remoteName,
            gstin: b['gstin']?.toString() ?? company.gstin,
            address: '${b['addressLine1'] ?? ''} ${b['addressLine2'] ?? ''}'
                    .trim()
                    .isNotEmpty
                ? '${b['addressLine1'] ?? ''} ${b['addressLine2'] ?? ''}'.trim()
                : company.address,
            phone: b['phone']?.toString() ?? company.phone,
            email: b['email']?.toString() ?? company.email,
            state: b['city']?.toString() ?? company.state,
            stateCode: b['stateCode']?.toString() ?? company.stateCode,
            bankName: company.bankName,
            accountNo: company.accountNo,
            branch: company.branch,
            ifsc: company.ifsc,
            logo: company.logo,
            role: b['role']?.toString() ?? company.role,
          );
          await prefs.setString(
              AppConstants.companyKey, jsonEncode(company.toJson()));
          await prefs.setString('company_id', realId);
        }
      } catch (_) {}
    }

    return company;
  }

  Future<void> saveCompany(Company company) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        AppConstants.companyKey, jsonEncode(company.toJson()));

    if (apiClient.token != null && apiClient.token!.isNotEmpty) {
      try {
        final companyId = await apiClient.getActiveBusinessId();
        if (companyId != null) {
          await apiClient.updateBusiness(companyId, company.toApiJson());
        }
      } catch (_) {}
    }
  }

  Future<InvoiceSettings> loadInvoiceSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(AppConstants.settingsKey);
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        return InvoiceSettings.fromJson(jsonDecode(jsonString));
      } catch (_) {}
    }
    return InvoiceSettings();
  }

  Future<void> saveInvoiceSettings(InvoiceSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        AppConstants.settingsKey, jsonEncode(settings.toJson()));
  }

  Future<List<String>> loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(AppConstants.categoriesKey);
    var categories = List<String>.from(AppConstants.defaultCategories);
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        categories = List<String>.from(jsonDecode(jsonString));
      } catch (_) {}
    }

    final companyId = await apiClient.getActiveBusinessId();
    if (apiClient.token != null &&
        apiClient.token!.isNotEmpty &&
        companyId != null) {
      try {
        final remote = await apiClient.getCategories(companyId);
        final remoteNames = remote
            .map((c) => c['name']?.toString().trim() ?? '')
            .where((name) => name.isNotEmpty)
            .toList();
        if (remoteNames.isNotEmpty) {
          categories = [
            ...{...categories, ...remoteNames}
          ];
          await prefs.setString(
              AppConstants.categoriesKey, jsonEncode(categories));
        }
      } catch (_) {}
    }

    return categories;
  }

  Future<void> saveCategories(List<String> categories) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.categoriesKey, jsonEncode(categories));
  }

  Future<Map<String, String>> loadCategoryImages() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('category_images_map');
    if (raw != null && raw.isNotEmpty) {
      try {
        return Map<String, String>.from(jsonDecode(raw));
      } catch (_) {}
    }
    return {};
  }

  Future<void> saveCategoryImage(String category, String image) async {
    final map = await loadCategoryImages();
    map[category.trim()] = image;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('category_images_map', jsonEncode(map));
  }

  Future<void> addCategory(String category, {String? imageBase64}) async {
    final trimmed = category.trim();
    if (trimmed.isEmpty) return;

    final existing = await loadCategories();
    if (!existing.contains(trimmed)) {
      await saveCategories([...existing, trimmed]);
    }

    if (imageBase64 != null && imageBase64.trim().isNotEmpty) {
      await saveCategoryImage(trimmed, imageBase64.trim());
    }

    final companyId = await apiClient.getActiveBusinessId();
    if (apiClient.token == null ||
        apiClient.token!.isEmpty ||
        companyId == null) {
      return;
    }

    try {
      final remote = await apiClient.getCategories(companyId);
      final existingRemote = remote.where(
        (c) =>
            (c['name']?.toString().trim().toLowerCase() ?? '') ==
            trimmed.toLowerCase(),
      );
      final created = existingRemote.isNotEmpty
          ? existingRemote.first
          : await apiClient.createCategory(companyId, {'name': trimmed});
      final categoryId = created['id']?.toString();
      if (categoryId != null &&
          categoryId.isNotEmpty &&
          imageBase64 != null &&
          imageBase64.trim().isNotEmpty) {
        await apiClient.uploadCategoryImageBase64(
          companyId,
          categoryId,
          imageBase64,
        );
      }
    } catch (_) {}
  }

  Future<void> updateCategory(
    String oldName,
    String newName, {
    String? imageBase64,
  }) async {
    final oldTrimmed = oldName.trim();
    final newTrimmed = newName.trim();
    if (newTrimmed.isEmpty) return;

    final existing = await loadCategories();
    final updated =
        existing.map((c) => c == oldTrimmed ? newTrimmed : c).toList();
    if (!updated.contains(newTrimmed)) {
      updated.add(newTrimmed);
    }
    await saveCategories(updated);

    final images = await loadCategoryImages();
    final currentImage = images[oldTrimmed];
    if (oldTrimmed != newTrimmed) {
      images.remove(oldTrimmed);
    }
    if (imageBase64 != null) {
      images[newTrimmed] = imageBase64.trim();
    } else if (currentImage != null) {
      images[newTrimmed] = currentImage;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('category_images_map', jsonEncode(images));

    final companyId = await apiClient.getActiveBusinessId();
    if (apiClient.token == null ||
        apiClient.token!.isEmpty ||
        companyId == null) {
      return;
    }

    try {
      final remote = await apiClient.getCategories(companyId);
      final match = remote
          .where(
            (c) =>
                (c['name']?.toString().trim().toLowerCase() ?? '') ==
                oldTrimmed.toLowerCase(),
          )
          .firstOrNull;
      if (match != null) {
        final categoryId = match['id']?.toString();
        if (categoryId != null && categoryId.isNotEmpty) {
          await apiClient
              .updateCategory(companyId, categoryId, {'name': newTrimmed});
          if (imageBase64 != null && imageBase64.trim().isNotEmpty) {
            await apiClient.uploadCategoryImageBase64(
                companyId, categoryId, imageBase64.trim());
          }
        }
      }
    } catch (_) {}
  }

  Future<void> deleteCategory(String category) async {
    final trimmed = category.trim();
    final existing = await loadCategories();
    await saveCategories(existing.where((c) => c != trimmed).toList());

    final images = await loadCategoryImages();
    if (images.containsKey(trimmed)) {
      images.remove(trimmed);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('category_images_map', jsonEncode(images));
    }

    final companyId = await apiClient.getActiveBusinessId();
    if (apiClient.token == null ||
        apiClient.token!.isEmpty ||
        companyId == null) {
      return;
    }

    try {
      final remote = await apiClient.getCategories(companyId);
      for (final item in remote) {
        final id = item['id']?.toString();
        final name = item['name']?.toString().trim();
        if (id != null &&
            id.isNotEmpty &&
            name != null &&
            name.toLowerCase() == trimmed.toLowerCase()) {
          await apiClient.deleteCategory(companyId, id);
        }
      }
    } catch (_) {}
  }

  Future<List<Map<String, String>>> loadUsers() async {
    final companyId = await apiClient.getActiveBusinessId();
    if (apiClient.token != null &&
        apiClient.token!.isNotEmpty &&
        companyId != null) {
      try {
        final remote = await apiClient.getStaff(companyId);
        final list = remote
            .map((u) => {
                  'id': '${u['id'] ?? u['userId'] ?? ''}',
                  'name': '${u['name'] ?? u['displayName'] ?? ''}',
                  'username': '${u['username'] ?? u['email'] ?? ''}',
                  'email': '${u['email'] ?? ''}',
                  'role': '${u['role'] ?? 'Biller'}',
                })
            .toList();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('staff_users', jsonEncode(list));
        return list;
      } catch (_) {}
    }

    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('staff_users');
    if (jsonString != null) {
      try {
        return (jsonDecode(jsonString) as List)
            .map((e) => Map<String, String>.from(e))
            .toList();
      } catch (_) {}
    }
    return [];
  }

  Future<void> createUser({
    required String name,
    required String username,
    required String email,
    required String password,
    required String role,
  }) async {
    final companyId = await apiClient.getActiveBusinessId();
    if (apiClient.token != null &&
        apiClient.token!.isNotEmpty &&
        companyId != null) {
      try {
        await apiClient.createStaff(companyId, {
          'name': name,
          'email': email.isNotEmpty ? email : '$username@empiran.local',
          'password': password,
          'role': role,
        });
        await loadUsers();
        return;
      } catch (_) {}
    }
    final existing = await loadUsers();
    final updated = List<Map<String, String>>.from(existing)
      ..add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': name,
        'username': username,
        'email': email,
        'role': role,
      });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('staff_users', jsonEncode(updated));
  }

  Future<void> updateUser({
    required String username,
    required String name,
    required String email,
    String? password,
    required String role,
    String? id,
  }) async {
    final companyId = await apiClient.getActiveBusinessId();
    if (apiClient.token != null &&
        apiClient.token!.isNotEmpty &&
        companyId != null &&
        id != null) {
      try {
        await apiClient.updateStaffRole(companyId, id, role);
      } catch (_) {}
    }
    final existing = await loadUsers();
    final updated = existing.map((u) {
      if (u['username'] == username || (id != null && u['id'] == id)) {
        return {
          ...u,
          'name': name,
          'email': email,
          'role': role,
        };
      }
      return u;
    }).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('staff_users', jsonEncode(updated));
  }

  Future<void> deleteUser(String username, {String? id}) async {
    final companyId = await apiClient.getActiveBusinessId();
    if (apiClient.token != null &&
        apiClient.token!.isNotEmpty &&
        companyId != null &&
        id != null) {
      try {
        await apiClient.deleteStaff(companyId, id);
      } catch (_) {}
    }
    final existing = await loadUsers();
    final updated = existing
        .where(
            (u) => u['username'] != username && (id == null || u['id'] != id))
        .toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('staff_users', jsonEncode(updated));
  }
}
