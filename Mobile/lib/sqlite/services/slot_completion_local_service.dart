import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../helpers/database_helper.dart';

/// Service quản lý trạng thái "nấu xong" offline cho meal slots.
///
/// Khi người dùng tick "Nấu xong" lúc offline:
///   1. Lưu vào bảng [local_pending_slot_completions] (sync_status = pending)
///   2. Cập nhật [local_weekly_plans.days_data_json] để UI phản ánh ngay
///
/// Khi có mạng trở lại → BackgroundSyncService gọi [getPendingCompletions]
/// rồi PATCH lên server và xóa bản ghi pending.
class SlotCompletionLocalService {
  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Lưu 1 slot completion pending (lúc offline)
  Future<void> savePendingCompletion({
    required String slotId,
    required bool completed,
  }) async {
    try {
      final db = await _db.database;
      await db.insert(
        'local_pending_slot_completions',
        {
          'slot_id': slotId,
          'completed': completed ? 1 : 0,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('[SlotCompletionLocalService] Saved pending: slot=$slotId completed=$completed');
    } catch (e) {
      debugPrint('[SlotCompletionLocalService] Error saving pending: $e');
    }
  }

  /// Lấy tất cả slot completions chưa sync
  Future<List<Map<String, dynamic>>> getPendingCompletions() async {
    try {
      final db = await _db.database;
      return await db.query(
        'local_pending_slot_completions',
        orderBy: 'created_at ASC',
      );
    } catch (e) {
      debugPrint('[SlotCompletionLocalService] Error reading pending: $e');
      return [];
    }
  }

  /// Xóa 1 bản ghi pending sau khi sync thành công
  Future<void> deletePendingCompletion(String slotId) async {
    try {
      final db = await _db.database;
      await db.delete(
        'local_pending_slot_completions',
        where: 'slot_id = ?',
        whereArgs: [slotId],
      );
      debugPrint('[SlotCompletionLocalService] Deleted pending for slot=$slotId');
    } catch (e) {
      debugPrint('[SlotCompletionLocalService] Error deleting pending: $e');
    }
  }

  /// Kiểm tra 1 slot có đang pending không
  Future<bool> isPending(String slotId) async {
    try {
      final db = await _db.database;
      final rows = await db.query(
        'local_pending_slot_completions',
        where: 'slot_id = ?',
        whereArgs: [slotId],
        limit: 1,
      );
      return rows.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Lấy trạng thái completed của 1 slot pending (null nếu không tồn tại)
  Future<bool?> getPendingCompletedStatus(String slotId) async {
    try {
      final db = await _db.database;
      final rows = await db.query(
        'local_pending_slot_completions',
        where: 'slot_id = ?',
        whereArgs: [slotId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return (rows.first['completed'] as int? ?? 0) == 1;
    } catch (e) {
      return null;
    }
  }

  /// Xóa toàn bộ pending (khi logout)
  Future<void> clearAll() async {
    try {
      final db = await _db.database;
      await db.delete('local_pending_slot_completions');
    } catch (e) {
      debugPrint('[SlotCompletionLocalService] Error clearing all: $e');
    }
  }
}
