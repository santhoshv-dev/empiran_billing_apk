import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DbHelper {
  static final DbHelper instance = DbHelper._init();
  static Database? _database;
  DbHelper._init();

  Future<Database?> get database async {
    if (kIsWeb) return null;
    if (_database != null) return _database!;
    _database = await _initDB('empiran.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
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
        balance REAL
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
      )
    ''');
  }

  // Generic methods
  Future<int> insert(String table, Map<String, dynamic> data) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db!.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
  }
  
  Future<int> update(String table, Map<String, dynamic> data, String id) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db!.update(table, data, where: 'id = ?', whereArgs: [id]);
  }
  
  Future<int> delete(String table, String id) async {
    if (kIsWeb) return 0;
    final db = await instance.database;
    return await db!.delete(table, where: 'id = ?', whereArgs: [id]);
  }
  
  Future<List<Map<String, dynamic>>> queryAll(String table) async {
    if (kIsWeb) return [];
    final db = await instance.database;
    return await db!.query(table);
  }

  Future<void> clearAll() async {
    if (kIsWeb) return;
    final db = await instance.database;
    await db!.delete('items');
    await db.delete('parties');
    await db.delete('transactions');
    await db.delete('sync_queue');
  }
}
