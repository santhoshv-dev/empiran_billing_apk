import '../../../../data/local/db_helper.dart';
import '../../../../data/remote/api_client.dart';
import '../../../../models.dart';

class ProductsRepository {
  final ApiClient apiClient;

  ProductsRepository({required this.apiClient});

  Future<List<Item>> loadProducts() async {
    // 1. Load from local DB
    final localRows = await DbHelper.instance.queryAll('items');
    final items = localRows.map((r) => Item.fromJson(r)).toList();

    // 2. If online, fetch from remote API
    if (apiClient.token != null && apiClient.token!.isNotEmpty) {
      try {
        final companyId = await apiClient.getActiveBusinessId();
        if (companyId != null) {
          final remoteRows = await apiClient.getItems(companyId);
          final remoteItems = remoteRows.map((r) => Item.fromJson(r)).toList();

          // Sync local DB cache
          for (final item in remoteItems) {
            await DbHelper.instance.insertOrUpdate('items', item.toJson(), item.id);
          }
          return remoteItems;
        }
      } catch (_) {}
    }

    return items;
  }

  Future<void> saveProduct(Item item) async {
    await DbHelper.instance.insertOrUpdate('items', item.toJson(), item.id);

    if (apiClient.token != null && apiClient.token!.isNotEmpty) {
      try {
        final companyId = await apiClient.getActiveBusinessId();
        if (companyId != null) {
          await apiClient.createItem(companyId, item.toJson());
        }
      } catch (_) {}
    }
  }

  Future<void> deleteProduct(Item item) async {
    await DbHelper.instance.delete('items', item.id);

    if (apiClient.token != null && apiClient.token!.isNotEmpty) {
      try {
        final companyId = await apiClient.getActiveBusinessId();
        if (companyId != null) {
          await apiClient.deleteItem(companyId, item.id);
        }
      } catch (_) {}
    }
  }

  Future<void> adjustStock(Item item, double change, {String reason = 'Manual adjustment'}) async {
    final next = item.currentStock + change;
    item.currentStock = next;
    await DbHelper.instance.insertOrUpdate('items', item.toJson(), item.id);

    if (apiClient.token != null && apiClient.token!.isNotEmpty) {
      try {
        final companyId = await apiClient.getActiveBusinessId();
        if (companyId != null) {
          await apiClient.adjustStock(companyId, item.id, {
            'newStock': next,
            'adjustmentType': change < 0 ? 'reduce' : 'add',
            'quantity': change.abs(),
            'reason': reason,
          });
        }
      } catch (_) {}
    }
  }
}
