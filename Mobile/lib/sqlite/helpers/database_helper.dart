import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static const String _dbName = 'friggy_offline.db';
  static const int _dbVersion = 1;

  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  factory DatabaseHelper() => instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    debugPrint('[DatabaseHelper] Opening database at: $path');

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    debugPrint('[DatabaseHelper] Creating offline tables version $version...');

    // 1. Table: local_ingredients (Nguyên liệu sẵn có / hết hạn)
    await db.execute('''
      CREATE TABLE local_ingredients (
        id TEXT PRIMARY KEY,
        ingredient_id INTEGER,
        name TEXT NOT NULL,
        quantity REAL,
        unit TEXT,
        storage_location TEXT,
        expires_at TEXT,
        days_until_expiry INTEGER,
        image_path TEXT,
        updated_at INTEGER
      )
    ''');

    // 2. Table: local_fridge_stats (Thống kê bữa đã nấu, % lãng phí, biểu đồ tuần/tháng)
    await db.execute('''
      CREATE TABLE local_fridge_stats (
        id INTEGER PRIMARY KEY DEFAULT 1,
        total_spent_this_month INTEGER,
        waste_percent REAL,
        meals_cooked INTEGER,
        expiring_soon_count INTEGER,
        total_items INTEGER,
        chart_json TEXT,
        updated_at INTEGER
      )
    ''');

    // 3. Table: local_weekly_plans (Gợi ý thực phẩm 1 tuần & Bữa ăn hôm nay)
    await db.execute('''
      CREATE TABLE local_weekly_plans (
        id TEXT PRIMARY KEY,
        week_start_date TEXT,
        days_data_json TEXT,
        updated_at INTEGER
      )
    ''');

    // 4. Table: local_shopping_items (Nhắc nhở mua sắm)
    await db.execute('''
      CREATE TABLE local_shopping_items (
        id TEXT PRIMARY KEY,
        ingredient_id INTEGER,
        ingredient_name TEXT,
        quantity REAL,
        unit TEXT,
        is_purchased INTEGER DEFAULT 0,
        updated_at INTEGER
      )
    ''');
  }

  Future<void> clearAllCache() async {
    final db = await database;
    await db.delete('local_ingredients');
    await db.delete('local_fridge_stats');
    await db.delete('local_weekly_plans');
    await db.delete('local_shopping_items');
    debugPrint('[DatabaseHelper] All local offline cache cleared.');
  }

  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }
}
