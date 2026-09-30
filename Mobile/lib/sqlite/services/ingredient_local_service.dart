import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../helpers/database_helper.dart';
import '../models/local_ingredient_model.dart';

class IngredientLocalService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Replace tất cả ingredients 'synced' trong SQLite với data từ server
  /// GIỮ LẠI các item 'pending' chưa upload
  Future<void> saveIngredientsCache(List<LocalIngredientModel> items) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // Chỉ xóa những cái đã synced từ server (không xóa pending)
      await txn.delete(
        'local_ingredients',
        where: "sync_status = 'synced'",
      );
      for (var item in items) {
        await txn.insert(
          'local_ingredients',
          item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    debugPrint('[IngredientLocalService] ${items.length} ingredients saved (kept pending items).');
  }

  /// Lưu 1 ingredient thêm khi offline (sync_status = 'pending')
  Future<void> saveOfflineIngredient(LocalIngredientModel item) async {
    try {
      final db = await _dbHelper.database;
      await db.insert(
        'local_ingredients',
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('[IngredientLocalService] Offline ingredient saved: ${item.name} (pending).');
    } catch (e) {
      debugPrint('[IngredientLocalService] Error saving offline ingredient: $e');
    }
  }

  /// Lấy tất cả ingredients (cả synced và pending)
  Future<List<LocalIngredientModel>> getCachedIngredients() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('local_ingredients');
    return maps.map((e) => LocalIngredientModel.fromMap(e)).toList();
  }

  /// Lấy ingredient sắp hết hạn (≤ 3 ngày)
  Future<List<LocalIngredientModel>> getExpiringIngredients() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'local_ingredients',
      where: 'days_until_expiry IS NOT NULL AND days_until_expiry <= 3',
      orderBy: 'days_until_expiry ASC',
    );
    return maps.map((e) => LocalIngredientModel.fromMap(e)).toList();
  }

  /// Get available ingredients count
  Future<int> getAvailableCount() async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery('SELECT COUNT(*) as cnt FROM local_ingredients');
    return Sqflite.firstIntValue(res) ?? 0;
  }

  /// Lấy tất cả ingredients chưa đồng bộ lên server
  Future<List<LocalIngredientModel>> getPendingIngredients() async {
    try {
      final db = await _dbHelper.database;
      final rows = await db.query(
        'local_ingredients',
        where: "sync_status = 'pending'",
      );
      return rows.map((r) => LocalIngredientModel.fromMap(r)).toList();
    } catch (e) {
      debugPrint('[IngredientLocalService] Error reading pending ingredients: $e');
      return [];
    }
  }

  /// Đánh dấu ingredient đã upload thành công (xóa item pending cũ,
  /// BackgroundSync sẽ pull lại từ server với id thật)
  Future<void> markIngredientSynced(String localId) async {
    try {
      final db = await _dbHelper.database;
      await db.delete('local_ingredients', where: 'id = ?', whereArgs: [localId]);
      debugPrint('[IngredientLocalService] Pending ingredient $localId removed (synced to server).');
    } catch (e) {
      debugPrint('[IngredientLocalService] Error marking ingredient synced: $e');
    }
  }

  /// Xóa 1 ingredient khỏi cache local
  Future<void> deleteIngredientFromCache(String id) async {
    try {
      final db = await _dbHelper.database;
      await db.delete('local_ingredients', where: 'id = ?', whereArgs: [id]);
      debugPrint('[IngredientLocalService] Ingredient $id deleted from cache.');
    } catch (e) {
      debugPrint('[IngredientLocalService] Error deleting ingredient: $e');
    }
  }

  /// Xóa tất cả pending ingredients trùng tên (case-insensitive)
  /// Gọi sau khi online addFridgeItem thành công để tránh BackgroundSync upload lại
  Future<void> clearPendingByName(String name) async {
    try {
      final db = await _dbHelper.database;
      final count = await db.delete(
        'local_ingredients',
        where: "sync_status = 'pending' AND LOWER(name) = LOWER(?)",
        whereArgs: [name],
      );
      if (count > 0) {
        debugPrint('[IngredientLocalService] Cleared $count pending item(s) for "$name" (already added online).');
      }
    } catch (e) {
      debugPrint('[IngredientLocalService] Error clearing pending by name: $e');
    }
  }

  /// Xóa các local_ingredients với sync_status='shopping_tick' theo tên
  /// Gọi sau khi toggleShoppingListItem thành công (online) để cleanup offline display items
  /// BackgroundSync không bao giờ upload 'shopping_tick' items — chỉ upload 'pending'
  Future<void> clearShoppingTickByName(String name) async {
    try {
      final db = await _dbHelper.database;
      final count = await db.delete(
        'local_ingredients',
        where: "sync_status = 'shopping_tick' AND LOWER(name) = LOWER(?)",
        whereArgs: [name],
      );
      if (count > 0) {
        debugPrint('[IngredientLocalService] Cleared $count shopping_tick item(s) for "$name" (synced via toggle).');
      }
    } catch (e) {
      debugPrint('[IngredientLocalService] Error clearing shopping_tick by name: $e');
    }
  }
}
