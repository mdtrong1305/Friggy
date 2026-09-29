import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static const String _dbName = 'friggy_offline.db';
  static const int _dbVersion = 5; // v5: thêm sync_status cho profile & preferences

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
      onUpgrade: _onUpgrade,
      onOpen: _onOpen,
    );
  }

  /// Safety net: đảm bảo tất cả bảng luôn tồn tại khi mở DB
  /// (chạy mỗi lần mở app, dùng IF NOT EXISTS nên rất nhanh)
  Future<void> _onOpen(Database db) async {
    debugPrint('[DatabaseHelper] Running onOpen safety checks...');

    // 4 bảng cốt lõi (tạo inline vì không có method riêng)
    await db.execute('CREATE TABLE IF NOT EXISTS local_ingredients (id TEXT PRIMARY KEY, ingredient_id INTEGER, name TEXT, quantity REAL, unit TEXT, storage_location TEXT, expires_at TEXT, days_until_expiry INTEGER, image_path TEXT, updated_at INTEGER)');
    await db.execute('CREATE TABLE IF NOT EXISTS local_fridge_stats (id INTEGER PRIMARY KEY DEFAULT 1, total_spent_this_month INTEGER, waste_percent REAL, meals_cooked INTEGER, expiring_soon_count INTEGER, total_items INTEGER, chart_json TEXT, updated_at INTEGER)');
    await db.execute('CREATE TABLE IF NOT EXISTS local_weekly_plans (id TEXT PRIMARY KEY, week_start_date TEXT, days_data_json TEXT, updated_at INTEGER)');
    await db.execute('CREATE TABLE IF NOT EXISTS local_shopping_items (id TEXT PRIMARY KEY, ingredient_id INTEGER, ingredient_name TEXT, quantity REAL, unit TEXT, is_purchased INTEGER DEFAULT 0, updated_at INTEGER)');

    // 4 bảng mở rộng (có method riêng)
    await _createUserProfileTable(db);
    await _createUserPreferencesTable(db);
    await _createAllergiesTable(db);
    await _createIngredientCatalogTable(db);

    // Thêm cột sync_status vào allergies nếu chưa có
    try {
      await db.execute(
        "ALTER TABLE local_allergies ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'synced'",
      );
    } catch (_) {} // Cột đã tồn tại → bỏ qua
    // Thêm cột sync_status vào profile nếu chưa có
    try {
      await db.execute(
        "ALTER TABLE local_user_profile ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'synced'",
      );
    } catch (_) {}
    // Thêm cột sync_status vào preferences nếu chưa có
    try {
      await db.execute(
        "ALTER TABLE local_user_preferences ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'synced'",
      );
    } catch (_) {}

    debugPrint('[DatabaseHelper] onOpen safety checks done.');
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

    // 5. Table: local_user_profile (Thông tin cá nhân + ảnh đại diện)
    await _createUserProfileTable(db);

    // 6. Table: local_user_preferences (Tùy chọn ăn uống & kỹ năng)
    await _createUserPreferencesTable(db);

    // 7. Table: local_allergies (Dị ứng thực phẩm)
    await _createAllergiesTable(db);

    // 8. Table: local_ingredient_catalog (Danh mục nguyên liệu toàn hệ thống)
    await _createIngredientCatalogTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('[DatabaseHelper] Upgrading DB from v$oldVersion to v$newVersion...');

    if (oldVersion < 2) {
      // Thêm 3 tables mới khi nâng từ v1 lên v2
      await _createUserProfileTable(db);
      await _createUserPreferencesTable(db);
      await _createAllergiesTable(db);
      debugPrint('[DatabaseHelper] Migration v1->v2: Added user_profile, user_preferences, allergies tables.');
    }
    if (oldVersion < 3) {
      // Thêm bảng danh mục nguyên liệu khi nâng từ v2 lên v3
      await _createIngredientCatalogTable(db);
      debugPrint('[DatabaseHelper] Migration v2->v3: Added ingredient_catalog table.');
    }
    if (oldVersion < 4) {
      try {
        await db.execute(
          "ALTER TABLE local_allergies ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'synced'",
        );
        debugPrint('[DatabaseHelper] Migration v3->v4: Added sync_status to local_allergies.');
      } catch (e) {
        debugPrint('[DatabaseHelper] sync_status (allergies) may already exist: $e');
      }
    }
    if (oldVersion < 5) {
      // Thêm sync_status vào profile và preferences
      try {
        await db.execute(
          "ALTER TABLE local_user_profile ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'synced'",
        );
      } catch (e) {
        debugPrint('[DatabaseHelper] sync_status (profile) may already exist: $e');
      }
      try {
        await db.execute(
          "ALTER TABLE local_user_preferences ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'synced'",
        );
      } catch (e) {
        debugPrint('[DatabaseHelper] sync_status (preferences) may already exist: $e');
      }
      debugPrint('[DatabaseHelper] Migration v4->v5: Added sync_status to profile & preferences.');
    }
  }


  Future<void> _createUserProfileTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_user_profile (
        id TEXT PRIMARY KEY,
        name TEXT,
        email TEXT,
        phone TEXT,
        avatar_url TEXT,
        avatar_local_path TEXT,
        date_of_birth TEXT,
        gender TEXT,
        bio TEXT,
        role TEXT,
        status TEXT,
        updated_at INTEGER NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'synced'
      )
    ''');
    debugPrint('[DatabaseHelper] Table local_user_profile created.');
  }

  Future<void> _createUserPreferencesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_user_preferences (
        id INTEGER PRIMARY KEY DEFAULT 1,
        weekly_budget INTEGER,
        daily_calorie_target INTEGER,
        dietary_style TEXT DEFAULT "omnivore",
        prefer_simple_recipes INTEGER DEFAULT 0,
        max_cook_time_minutes INTEGER,
        skill_level TEXT DEFAULT "beginner",
        household_size INTEGER DEFAULT 1,
        ai_personality_mode TEXT DEFAULT "friendly",
        primary_goal TEXT,
        cooking_frequency TEXT,
        height INTEGER,
        weight INTEGER,
        activity_level TEXT,
        updated_at INTEGER NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'synced'
      )
    ''');
    debugPrint('[DatabaseHelper] Table local_user_preferences created.');
  }

  Future<void> _createAllergiesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_allergies (
        id TEXT PRIMARY KEY,
        ingredient_id INTEGER NOT NULL,
        ingredient_name TEXT NOT NULL,
        note TEXT,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        updated_at INTEGER NOT NULL
      )
    ''');
    debugPrint('[DatabaseHelper] Table local_allergies created.');
  }

  Future<void> _createIngredientCatalogTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_ingredient_catalog (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        english_name TEXT,
        default_unit TEXT,
        category TEXT,
        image_path TEXT,
        updated_at INTEGER NOT NULL
      )
    ''');
    // Tạo index để tìm kiếm nhanh theo tên
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_catalog_name
      ON local_ingredient_catalog(name)
    ''');
    debugPrint('[DatabaseHelper] Table local_ingredient_catalog + index created.');
  }

  Future<void> clearAllCache() async {
    final db = await database;
    await db.delete('local_ingredients');
    await db.delete('local_fridge_stats');
    await db.delete('local_weekly_plans');
    await db.delete('local_shopping_items');
    await db.delete('local_user_profile');
    await db.delete('local_user_preferences');
    await db.delete('local_allergies');
    await db.delete('local_ingredient_catalog');
    debugPrint('[DatabaseHelper] All local offline cache cleared.');
  }

  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }
}
