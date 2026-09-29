import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../helpers/database_helper.dart';
import '../models/local_allergy_model.dart';

class AllergyLocalService {
  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Lưu toàn bộ danh sách dị ứng từ server (sync=synced)
  /// Chú ý: chỉ xóa các item 'synced', GIỮ LẠI các 'pending' chưa upload
  Future<void> saveAllergiesCache(List<LocalAllergyModel> allergies) async {
    try {
      final db = await _db.database;
      await db.transaction((txn) async {
        // Chỉ xóa những cái đã synced từ server (không xóa pending)
        await txn.delete(
          'local_allergies',
          where: "sync_status = 'synced'",
        );
        for (final allergy in allergies) {
          await txn.insert(
            'local_allergies',
            allergy.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
      debugPrint('[AllergyLocalService] ${allergies.length} allergies saved (kept pending items).');
    } catch (e) {
      debugPrint('[AllergyLocalService] Error saving allergies: $e');
    }
  }

  /// Lấy toàn bộ dị ứng (cả synced và pending, KHÔNG bao gồm pending_delete)
  Future<List<LocalAllergyModel>> getCachedAllergies() async {
    try {
      final db = await _db.database;
      final rows = await db.query(
        'local_allergies',
        where: "sync_status != 'pending_delete'",
        orderBy: 'ingredient_name ASC',
      );
      return rows.map((r) => LocalAllergyModel.fromMap(r)).toList();
    } catch (e) {
      debugPrint('[AllergyLocalService] Error reading allergies: $e');
      return [];
    }
  }

  /// Lưu một dị ứng mới thêm khi offline (sync_status = 'pending')
  Future<void> saveOfflineAllergy(LocalAllergyModel allergy) async {
    try {
      final db = await _db.database;
      await db.insert(
        'local_allergies',
        allergy.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('[AllergyLocalService] Offline allergy saved: ${allergy.ingredientName} (pending).');
    } catch (e) {
      debugPrint('[AllergyLocalService] Error saving offline allergy: $e');
    }
  }

  /// Lấy tất cả dị ứng chưa đồng bộ lên server
  Future<List<LocalAllergyModel>> getPendingAllergies() async {
    try {
      final db = await _db.database;
      final rows = await db.query(
        'local_allergies',
        where: "sync_status = 'pending'",
      );
      return rows.map((r) => LocalAllergyModel.fromMap(r)).toList();
    } catch (e) {
      debugPrint('[AllergyLocalService] Error reading pending allergies: $e');
      return [];
    }
  }

  /// Cập nhật id và sync_status sau khi đã upload lên server thành công
  Future<void> markAsSynced(String localId, String serverId) async {
    try {
      final db = await _db.database;
      // Xóa item pending cũ
      await db.delete('local_allergies', where: 'id = ?', whereArgs: [localId]);
      // Không cần insert lại vì BackgroundSync sẽ pull list mới từ server
      debugPrint('[AllergyLocalService] Allergy $localId marked as synced (server id: $serverId).');
    } catch (e) {
      debugPrint('[AllergyLocalService] Error marking as synced: $e');
    }
  }

  /// Đánh dấu dị ứng cần xóa khi offline (sync_status = 'pending_delete')
  /// Allergy vẫn còn trong DB nhưng UI ẩn đi, khi online sẽ gọi API xóa thật
  Future<void> markPendingDelete(String id) async {
    try {
      final db = await _db.database;
      await db.update(
        'local_allergies',
        {'sync_status': 'pending_delete'},
        where: 'id = ?',
        whereArgs: [id],
      );
      debugPrint('[AllergyLocalService] Allergy $id marked as pending_delete.');
    } catch (e) {
      debugPrint('[AllergyLocalService] Error marking pending_delete: $e');
    }
  }

  /// Lấy tất cả dị ứng cần xóa trên server
  Future<List<LocalAllergyModel>> getPendingDeleteAllergies() async {
    try {
      final db = await _db.database;
      final rows = await db.query(
        'local_allergies',
        where: "sync_status = 'pending_delete'",
      );
      return rows.map((r) => LocalAllergyModel.fromMap(r)).toList();
    } catch (e) {
      debugPrint('[AllergyLocalService] Error reading pending_delete: $e');
      return [];
    }
  }

  /// Xóa 1 dị ứng khỏi cache local
  Future<void> deleteAllergyFromCache(String id) async {
    try {
      final db = await _db.database;
      await db.delete('local_allergies', where: 'id = ?', whereArgs: [id]);
      debugPrint('[AllergyLocalService] Allergy $id deleted from cache.');
    } catch (e) {
      debugPrint('[AllergyLocalService] Error deleting allergy: $e');
    }
  }

  /// Xóa toàn bộ cache dị ứng (khi logout)
  Future<void> clearAllergiesCache() async {
    try {
      final db = await _db.database;
      await db.delete('local_allergies');
      debugPrint('[AllergyLocalService] Allergies cache cleared.');
    } catch (e) {
      debugPrint('[AllergyLocalService] Error clearing allergies: $e');
    }
  }
}
