import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;

  LocalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('academia_local.db');
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
      CREATE TABLE cache (
        id TEXT PRIMARY KEY,
        collection TEXT NOT NULL,
        data TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action TEXT NOT NULL,
        collection TEXT NOT NULL,
        doc_id TEXT,
        data TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> cacheData(String collection, String id, Map<String, dynamic> data) async {
    try {
      final db = await instance.database;
      await db.insert(
        'cache',
        {
          'id': '${collection}_$id',
          'collection': collection,
          'data': jsonEncode(data),
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> getCachedData(String collection, String id) async {
    try {
      final db = await instance.database;
      final maps = await db.query(
        'cache',
        columns: ['data'],
        where: 'id = ?',
        whereArgs: ['${collection}_$id'],
      );

      if (maps.isNotEmpty) {
        return jsonDecode(maps.first['data'] as String);
      } else {
        return null;
      }
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteCachedData(String collection, String id) async {
    try {
      final db = await instance.database;
      await db.delete(
        'cache',
        where: 'id = ?',
        whereArgs: ['${collection}_$id'],
      );
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> getCachedCollection(String collection) async {
    try {
      final db = await instance.database;
      final maps = await db.query(
        'cache',
        columns: ['data'],
        where: 'collection = ?',
        whereArgs: [collection],
      );

      return maps.map((map) => jsonDecode(map['data'] as String) as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }
  
  Future<void> queueSyncAction(String action, String collection, String? docId, Map<String, dynamic> data) async {
    try {
      final db = await instance.database;
      await db.insert('sync_queue', {
        'action': action,
        'collection': collection,
        'doc_id': docId ?? '',
        'data': jsonEncode(data),
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {}
  }
}
