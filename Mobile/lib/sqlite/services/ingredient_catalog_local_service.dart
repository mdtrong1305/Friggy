import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../helpers/database_helper.dart';
import '../models/local_ingredient_catalog_model.dart';

class IngredientCatalogLocalService {
  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Lưu toàn bộ danh mục nguyên liệu vào SQLite (upsert từng item)
  Future<void> saveCatalogCache(List<LocalIngredientCatalogModel> items) async {
    if (items.isEmpty) return;
    try {
      final db = await _db.database;
      final batch = db.batch();
      for (final item in items) {
        batch.insert(
          'local_ingredient_catalog',
          item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
      debugPrint('[IngredientCatalogLocalService] ${items.length} catalog items saved.');
    } catch (e) {
      debugPrint('[IngredientCatalogLocalService] Error saving catalog: $e');
    }
  }

  /// Tìm kiếm nguyên liệu theo tên (hỗ trợ cả tiếng Việt và tiếng Anh)
  Future<List<LocalIngredientCatalogModel>> searchCatalog(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final db = await _db.database;
      final keyword = '%${query.trim()}%';
      final rows = await db.query(
        'local_ingredient_catalog',
        where: 'name LIKE ? OR english_name LIKE ?',
        whereArgs: [keyword, keyword],
        orderBy: 'name ASC',
        limit: 20,
      );
      return rows.map((r) => LocalIngredientCatalogModel.fromMap(r)).toList();
    } catch (e) {
      debugPrint('[IngredientCatalogLocalService] Error searching catalog: $e');
      return [];
    }
  }

  /// Lấy tất cả nguyên liệu trong catalog (giới hạn 500)
  Future<List<LocalIngredientCatalogModel>> getAllCatalog({int limit = 500}) async {
    try {
      final db = await _db.database;
      final rows = await db.query(
        'local_ingredient_catalog',
        orderBy: 'name ASC',
        limit: limit,
      );
      return rows.map((r) => LocalIngredientCatalogModel.fromMap(r)).toList();
    } catch (e) {
      debugPrint('[IngredientCatalogLocalService] Error fetching all catalog: $e');
      return [];
    }
  }

  /// Kiểm tra xem catalog đã có dữ liệu chưa
  Future<bool> hasCatalogData() async {
    try {
      final db = await _db.database;
      final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM local_ingredient_catalog'),
      );
      return (count ?? 0) > 0;
    } catch (e) {
      return false;
    }
  }

  /// Xóa toàn bộ catalog (dùng khi cần refresh)
  Future<void> clearCatalogCache() async {
    try {
      final db = await _db.database;
      await db.delete('local_ingredient_catalog');
      debugPrint('[IngredientCatalogLocalService] Catalog cache cleared.');
    } catch (e) {
      debugPrint('[IngredientCatalogLocalService] Error clearing catalog: $e');
    }
  }
}
