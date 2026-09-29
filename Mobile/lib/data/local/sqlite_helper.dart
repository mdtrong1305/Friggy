import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// SQLite Database Service Helper for Friggy (Offline-First Storage)
class SqliteHelper {
  static const String _dbName = 'friggy_local.db';
  static const int _dbVersion = 1;

  // Singleton instance
  static final SqliteHelper instance = SqliteHelper._internal();
  static Database? _database;

  SqliteHelper._internal();

  factory SqliteHelper() => instance;

  /// Get active Database instance (Lazy Initialization)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize and open SQLite database
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    debugPrint('[SqliteHelper] Initializing database at path: $path');

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Callback executed when the database is created for the first time
  Future<void> _onCreate(Database db, int version) async {
    debugPrint('[SqliteHelper] Database onCreate version $version');
    // Schema definition tables will be added here upon user requirements.
  }

  /// Callback executed when the database version is upgraded
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('[SqliteHelper] Database onUpgrade from $oldVersion to $newVersion');
  }

  // ─────────────────────────────────────────────────────────
  // HELPER CRUD METHODS
  // ─────────────────────────────────────────────────────────

  /// Insert a record into table
  Future<int> insert(String table, Map<String, dynamic> values) async {
    final db = await database;
    return await db.insert(
      table,
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Query records from table
  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    final db = await database;
    return await db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
  }

  /// Raw query SQL execution
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? arguments,
  ]) async {
    final db = await database;
    return await db.rawQuery(sql, arguments);
  }

  /// Update record in table
  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    final db = await database;
    return await db.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
    );
  }

  /// Delete record from table
  Future<int> delete(
    String table, {
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    final db = await database;
    return await db.delete(
      table,
      where: where,
      whereArgs: whereArgs,
    );
  }

  /// Execute raw SQL query (CREATE TABLE, DROP, ALTER, etc.)
  Future<void> execute(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    await db.execute(sql, arguments);
  }

  /// Close database connection
  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
      debugPrint('[SqliteHelper] Database connection closed.');
    }
  }
}
