import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../helpers/database_helper.dart';
import '../models/local_shopping_model.dart';

class ShoppingLocalService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Replace all shopping list items in SQLite (overwriting old list when new list generated)
  /// Lưu đồng thời listId và backendItemId để dùng khi toggle offline
  Future<void> saveShoppingItemsOverwrite(List<LocalShoppingItemModel> items) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // Chỉ xóa các item đã synced, GIỮ LẠI pending_toggle chưa upload
      await txn.delete(
        'local_shopping_items',
        where: "sync_status = 'synced'",
      );
      for (var item in items) {
        await txn.insert(
          'local_shopping_items',
          item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    debugPrint('[ShoppingLocalService] ${items.length} items saved (kept pending_toggle).');
  }

  /// Get cached shopping list items (tất cả)
  Future<List<LocalShoppingItemModel>> getCachedShoppingItems() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('local_shopping_items');
    return maps.map((e) => LocalShoppingItemModel.fromMap(e)).toList();
  }

  /// Cập nhật isPurchased của 1 item trong SQLite, đặt sync_status = 'pending_toggle'
  /// Gọi khi người dùng tick/untick lúc OFFLINE
  Future<void> markPendingToggle(String itemId, bool isPurchased) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'local_shopping_items',
        {
          'is_purchased': isPurchased ? 1 : 0,
          'sync_status': 'pending_toggle',
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [itemId],
      );
      debugPrint('[ShoppingLocalService] Item $itemId marked pending_toggle (isPurchased: $isPurchased).');
    } catch (e) {
      debugPrint('[ShoppingLocalService] Error marking pending_toggle: $e');
    }
  }

  /// Lấy tất cả items cần sync toggle lên server
  Future<List<LocalShoppingItemModel>> getPendingToggleItems() async {
    try {
      final db = await _dbHelper.database;
      final rows = await db.query(
        'local_shopping_items',
        where: "sync_status = 'pending_toggle'",
      );
      return rows.map((r) => LocalShoppingItemModel.fromMap(r)).toList();
    } catch (e) {
      debugPrint('[ShoppingLocalService] Error reading pending_toggle: $e');
      return [];
    }
  }

  /// Đánh dấu 1 item đã sync thành công
  Future<void> markToggleSynced(String itemId) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'local_shopping_items',
        {'sync_status': 'synced'},
        where: 'id = ?',
        whereArgs: [itemId],
      );
      debugPrint('[ShoppingLocalService] Item $itemId toggle synced.');
    } catch (e) {
      debugPrint('[ShoppingLocalService] Error marking toggle synced: $e');
    }
  }
}
