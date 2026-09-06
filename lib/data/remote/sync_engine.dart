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
      store.notifyListeners();
      
      await _pushChanges();
      await store.syncFromApi(); // Pull
      
    } catch (e) {
      store.syncError = e.toString();
    } finally {
      _isSyncing = false;
      store.syncing = false;
      store.notifyListeners();
    }
  }

  Future<void> queueOperation(String entityType, String entityId, String operation, Map<String, dynamic> payload) async {
    final queueItem = {
      'id': _uuid.v4(),
      'entityType': entityType,
      'entityId': entityId,
      'operation': operation,
      'payload': jsonEncode(payload),
      'status': 'pending',
      'retryCount': 0,
      'createdAt': DateTime.now().toIso8601String(),
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
    final pending = queue.where((q) => q['status'] == 'pending' || q['status'] == 'failed');
    
    for (var item in pending) {
      if ((item['retryCount'] as int) > 5) continue; // Skip after 5 retries
      
      try {
        await _executeOperation(item);
        await DbHelper.instance.update('sync_queue', {'status': 'completed'}, item['id']);
      } catch (e) {
        await DbHelper.instance.update('sync_queue', {
          'status': 'failed',
          'retryCount': (item['retryCount'] as int) + 1,
          'errorMessage': e.toString(),
          'lastAttemptAt': DateTime.now().toIso8601String()
        }, item['id']);
      }
    }
  }

  Future<void> _executeOperation(Map<String, dynamic> queueItem) async {
    final entityType = queueItem['entityType'];
    final entityId = queueItem['entityId'];
    final operation = queueItem['operation'];
    final payload = jsonDecode(queueItem['payload'] as String);

    switch (entityType) {
      case 'transaction':
        if (operation == 'CREATE') {
          payload['clientTransactionId'] = entityId; // Idempotency key
          await store.api.createTransaction(store.company.id, payload);
        } else if (operation == 'DELETE') {
          await store.api.deleteTransaction(store.company.id, entityId);
        }
        break;
      case 'item':
        if (operation == 'CREATE') {
          await store.api.createItem(store.company.id, payload);
        } else if (operation == 'UPDATE') {
          await store.api.updateItem(store.company.id, entityId, payload);
        } else if (operation == 'DELETE') {
          await store.api.deleteItem(store.company.id, entityId);
        }
        break;
      case 'party':
        if (operation == 'CREATE') {
          await store.api.createParty(store.company.id, payload);
        } else if (operation == 'UPDATE') {
          await store.api.updateParty(store.company.id, entityId, payload);
        } else if (operation == 'DELETE') {
          await store.api.deleteParty(store.company.id, entityId);
        }
        break;
    }
  }
}
