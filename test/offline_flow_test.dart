import 'package:flutter_test/flutter_test.dart';
import 'package:empiran/data/local/db_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('DbHelper can cache a category offline', () async {
    final dbHelper = DbHelper.instance;
    await dbHelper.clearAll(); // Ensure clean state
    
    // Simulate offline creation
    await dbHelper.insert('categories', {
      'id': 'cat-123',
      'name': 'Offline Category Test'
    });
    
    // Add to sync queue
    await dbHelper.insert('sync_queue', {
      'id': 'sync-1',
      'entityType': 'categories',
      'entityId': 'cat-123',
      'operation': 'CREATE',
      'payload': '{"name":"Offline Category Test"}',
      'status': 'pending',
      'businessId': 'biz-1'
    });
    
    // Verify it is cached
    final categories = await dbHelper.queryAll('categories');
    expect(categories.length, 1);
    expect(categories.first['name'], 'Offline Category Test');
    
    // Verify sync queue
    final queue = await dbHelper.queryAll('sync_queue');
    expect(queue.length, 1);
    expect(queue.first['status'], 'pending');
    expect(queue.first['entityType'], 'categories');
  });
}
