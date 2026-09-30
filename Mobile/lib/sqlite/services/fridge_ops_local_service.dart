import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../helpers/database_helper.dart';

/// Các action có thể pending khi offline
enum FridgeOpAction { update, consume, delete }

/// Service quản lý các thao tác nguyên liệu pending khi offline:
///   - update  → PATCH /fridge/items/:id { quantity, unit }
///   - consume → PATCH /fridge/items/:id/consume
///   - delete  → DELETE /fridge/items/:id
///
/// Khi có mạng → BackgroundSyncService gọi [getPendingOps]
/// → gọi API tương ứng → xóa pending → pull lại cache từ server
class FridgeOpsLocalService {
  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Lưu (hoặc ghi đè) 1 pending op cho item.
  /// Nếu đã có pending cho item đó → thay bằng action mới nhất.
  Future<void> savePendingOp({
    required String itemId,
    required FridgeOpAction action,
    double? quantity,
    String? unit,
  }) async {
    try {
      final db = await _db.database;
      await db.insert(
        'local_pending_fridge_ops',
        {
          'id': itemId, // dùng itemId làm primary key để tự replace
          'item_id': itemId,
          'action': action.name,
          'quantity': quantity,
          'unit': unit,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('[FridgeOpsLocalService] Saved pending op: item=$itemId action=${action.name}');
    } catch (e) {
      debugPrint('[FridgeOpsLocalService] Error saving pending op: $e');
    }
  }

  /// Lấy tất cả ops chưa sync
  Future<List<Map<String, dynamic>>> getPendingOps() async {
    try {
      final db = await _db.database;
      return await db.query(
        'local_pending_fridge_ops',
        orderBy: 'created_at ASC',
      );
    } catch (e) {
      debugPrint('[FridgeOpsLocalService] Error reading pending ops: $e');
      return [];
    }
  }

  /// Xóa 1 pending op sau khi sync thành công
  Future<void> deletePendingOp(String itemId) async {
    try {
      final db = await _db.database;
      await db.delete(
        'local_pending_fridge_ops',
        where: 'id = ?',
        whereArgs: [itemId],
      );
      debugPrint('[FridgeOpsLocalService] Deleted pending op for item=$itemId');
    } catch (e) {
      debugPrint('[FridgeOpsLocalService] Error deleting pending op: $e');
    }
  }

  /// Kiểm tra item có pending op không
  Future<bool> hasPendingOp(String itemId) async {
    try {
      final db = await _db.database;
      final rows = await db.query(
        'local_pending_fridge_ops',
        where: 'id = ?',
        whereArgs: [itemId],
        limit: 1,
      );
      return rows.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Lấy action của 1 item pending (null nếu không có)
  Future<FridgeOpAction?> getPendingAction(String itemId) async {
    try {
      final db = await _db.database;
      final rows = await db.query(
        'local_pending_fridge_ops',
        where: 'id = ?',
        whereArgs: [itemId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final actionStr = rows.first['action'] as String? ?? '';
      return FridgeOpAction.values.firstWhere(
        (e) => e.name == actionStr,
        orElse: () => FridgeOpAction.update,
      );
    } catch (e) {
      return null;
    }
  }

  /// Xóa toàn bộ pending ops (khi logout)
  Future<void> clearAll() async {
    try {
      final db = await _db.database;
      await db.delete('local_pending_fridge_ops');
    } catch (e) {
      debugPrint('[FridgeOpsLocalService] Error clearing all: $e');
    }
  }
}
