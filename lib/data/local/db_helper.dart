import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

class DbHelper {
  static final DbHelper instance = DbHelper._init();
  static Database? _database;
  static bool _desktopDatabaseFactoryConfigured = false;
  static final Map<String, List<Map<String, dynamic>>> _webStore = {};
  DbHelper._init();

  Future<Database?> get database async {
    if (kIsWeb) return null;
    if (_database != null) return _database!;
    _database = await _initDB('empiran.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux)) {
      if (!_desktopDatabaseFactoryConfigured) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        _desktopDatabaseFactoryConfigured = true;
      }
    }
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE items (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT,
        itemCode TEXT,
        hsn TEXT,
        unit TEXT,
        salesPrice REAL,
        purchasePrice REAL,
        isService INTEGER,
        currentStock REAL,
        lowStockLimit REAL,
        image TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE parties (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        type TEXT,
        gstin TEXT,
        address TEXT,
        openingBalance REAL,
        currentBalance REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        number TEXT,
        date TEXT,
        partyName TEXT,
        partyPhone TEXT,
        partyAddress TEXT,
        partyGstin TEXT,
        partyId TEXT,
        isGst INTEGER,
        paid REAL,
        paymentMode TEXT,
        status TEXT,
        convertedFrom TEXT,
        discount REAL,
        shipping REAL,
        notes TEXT,
        lines TEXT,
        dispatch TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_queue (
        id TEXT PRIMARY KEY,
        entityType TEXT NOT NULL,
        entityId TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT,
        status TEXT DEFAULT 'pending',
        retryCount INTEGER DEFAULT 0,
        createdAt TEXT,
        lastAttemptAt TEXT,
        errorMessage TEXT
        ,businessId TEXT
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE sync_queue ADD COLUMN businessId TEXT');
    }
  }

  // Generic methods with full Web support
  Future<int> insert(String table, Map<String, dynamic> data) async {
    if (kIsWeb) {
      final list = _webStore.putIfAbsent(table, () => []);
      final id = data['id']?.toString();
      if (id != null) {
        list.removeWhere((x) => x['id']?.toString() == id);
      }
      list.add(Map<String, dynamic>.from(data));
      try {
        final p = await SharedPreferences.getInstance();
        await p.setString('web_db_$table', jsonEncode(list));
      } catch (_) {}
      return 1;
    }
    final db = await instance.database;
    return await db!
        .insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> update(String table, Map<String, dynamic> data, String id) async {
    if (kIsWeb) {
      final list = _webStore.putIfAbsent(table, () => []);
      final idx = list.indexWhere((x) => x['id']?.toString() == id);
      if (idx != -1) {
        list[idx] = {...list[idx], ...data};
        try {
          final p = await SharedPreferences.getInstance();
          await p.setString('web_db_$table', jsonEncode(list));
        } catch (_) {}
        return 1;
      }
      return 0;
    }
    final db = await instance.database;
    return await db!.update(table, data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> delete(String table, String id) async {
    if (kIsWeb) {
      final list = _webStore.putIfAbsent(table, () => []);
      final initialLen = list.length;
      list.removeWhere((x) => x['id']?.toString() == id);
      try {
        final p = await SharedPreferences.getInstance();
        await p.setString('web_db_$table', jsonEncode(list));
      } catch (_) {}
      return initialLen - list.length;
    }
    final db = await instance.database;
    return await db!.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> queryAll(String table) async {
    if (kIsWeb) {
      if (!_webStore.containsKey(table)) {
        try {
          final p = await SharedPreferences.getInstance();
          final raw = p.getString('web_db_$table');
          if (raw != null && raw.isNotEmpty) {
            final decoded = jsonDecode(raw);
            if (decoded is List) {
              _webStore[table] =
                  decoded.map((e) => Map<String, dynamic>.from(e)).toList();
            }
          }
        } catch (_) {}
      }
      return List<Map<String, dynamic>>.from(_webStore[table] ?? []);
    }
    final db = await instance.database;
    return await db!.query(table);
  }

  Future<int> deleteAll(String table) async {
    if (kIsWeb) {
      final count = _webStore[table]?.length ?? 0;
      _webStore[table]?.clear();
      try {
        final p = await SharedPreferences.getInstance();
        await p.remove('web_db_$table');
      } catch (_) {}
      return count;
    }
    final db = await instance.database;
    return await db!.delete(table);
  }

  Future<void> clearAll() async {
    if (kIsWeb) {
      _webStore.clear();
      try {
        final p = await SharedPreferences.getInstance();
        await p.remove('web_db_items');
        await p.remove('web_db_parties');
        await p.remove('web_db_transactions');
        await p.remove('web_db_sync_queue');
      } catch (_) {}
      return;
    }
    final db = await instance.database;
    await db!.delete('items');
    await db.delete('parties');
    await db.delete('transactions');
    await db.delete('sync_queue');
  }
}
