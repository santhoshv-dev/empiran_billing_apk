import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../../app_store.dart';
import '../local/db_helper.dart';

class SyncEngine {
  final AppStore store;
  final Uuid _uuid = const Uuid();
  bool _isSyncing = false;

  SyncEngine(this.store) {
    Connectivity().onConnectivityChanged.listen((result) {
      if (!result.contains(ConnectivityResult.none)) {
        syncNow();
      }
    });
  }

  Future<void> syncNow() async {
    if (_isSyncing || !store.remoteMode) return;
    _isSyncing = true;
    try {
      store.syncing = true;
      store.notify();

      await _pushChanges();
      await store.syncFromApi(); // Pull
    } catch (e) {
      store.syncError = e.toString();
    } finally {
      _isSyncing = false;
      store.syncing = false;
      store.notify();
    }
  }

  Future<void> queueOperation(
    String entityType,
    String entityId,
    String operation,
    Map<String, dynamic> payload, {
    required String businessId,
  }) async {
    final queueItem = {
      'id': _uuid.v4(),
      'entityType': entityType,
      'entityId': entityId,
      'operation': operation,
      'payload': jsonEncode(payload),
      'status': 'pending',
      'retryCount': 0,
      'createdAt': DateTime.now().toIso8601String(),
      'businessId': businessId,
    };
    await DbHelper.instance.insert('sync_queue', queueItem);

    // Attempt sync if online
    final connectivity = await Connectivity().checkConnectivity();
    if (!connectivity.contains(ConnectivityResult.none)) {
      syncNow();
    }
  }

  Future<void> _pushChanges() async {
    final queue = await DbHelper.instance.queryAll('sync_queue');
    final pending =
        queue.where((q) => q['status'] == 'pending' || q['status'] == 'failed');

    for (var item in pending) {
      if ((item['retryCount'] as int) > 5) continue; // Skip after 5 retries

      try {
        await _executeOperation(item);
        await DbHelper.instance
            .update('sync_queue', {'status': 'completed'}, item['id']);
      } catch (e) {
        await DbHelper.instance.update(
            'sync_queue',
            {
              'status': 'failed',
              'retryCount': (item['retryCount'] as int) + 1,
              'errorMessage': e.toString(),
              'lastAttemptAt': DateTime.now().toIso8601String()
            },
            item['id']);
      }
    }
  }

  Future<void> _executeOperation(Map<String, dynamic> queueItem) async {
    final entityType = queueItem['entityType'];
    final entityId = queueItem['entityId'];
    final operation = queueItem['operation'];
    final businessId = queueItem['businessId'] as String? ?? store.company.id;
    final payload = jsonDecode(queueItem['payload'] as String);

    switch (entityType) {
      case 'transaction':
        if (operation == 'CREATE') {
          payload['clientTransactionId'] = entityId;
          final res = await store.api.createTransaction(businessId, payload);
          if (res['id'] != null) {
            final newId = res['id'].toString();
            final idx = store.transactions.indexWhere((x) => x.id == entityId);
            if (idx != -1) {
              store.transactions[idx].id = newId;
            }
          }
        } else if (operation == 'DELETE') {
          await store.api.deleteTransaction(businessId, entityId);
        }
        break;
      case 'item':
        if (operation == 'CREATE') {
          final res = await store.api.createItem(businessId, payload);
          if (res['id'] != null) {
            final newId = res['id'].toString();
            final idx = store.items.indexWhere((x) => x.id == entityId);
            if (idx != -1) {
              store.items[idx].id = newId;
              await DbHelper.instance.delete('items', entityId);
              final j = store.items[idx].toJson();
              j['isService'] = store.items[idx].isService ? 1 : 0;
              await DbHelper.instance.insert('items', j);
            }
          }
        } else if (operation == 'UPDATE') {
          await store.api.updateItem(businessId, entityId, payload);
        } else if (operation == 'DELETE') {
          await store.api.deleteItem(businessId, entityId);
        }
        break;
      case 'party':
        if (operation == 'CREATE') {
          final res = await store.api.createParty(businessId, payload);
          if (res['id'] != null) {
            final newId = res['id'].toString();
            final idx = store.parties.indexWhere((x) => x.id == entityId);
            if (idx != -1) {
              store.parties[idx].id = newId;
              await DbHelper.instance.delete('parties', entityId);
              await DbHelper.instance
                  .insert('parties', store.parties[idx].toJson());
            }
          }
        } else if (operation == 'UPDATE') {
          await store.api.updateParty(businessId, entityId, payload);
        } else if (operation == 'DELETE') {
          await store.api.deleteParty(businessId, entityId);
        }
        break;
      case 'category':
        if (operation == 'CREATE') {
          await store.api.createCategory(businessId, payload);
        } else if (operation == 'UPDATE') {
          await store.api.updateCategory(businessId, entityId, payload);
        } else if (operation == 'DELETE') {
          await store.api.deleteCategory(businessId, entityId);
        }
        break;
    }
  }
}
