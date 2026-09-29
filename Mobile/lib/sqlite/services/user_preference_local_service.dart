import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../helpers/database_helper.dart';
import '../models/local_user_preference_model.dart';

class UserPreferenceLocalService {
  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Lưu (upsert) tùy chọn ăn uống vào SQLite
  Future<void> savePreferencesCache(LocalUserPreferenceModel prefs) async {
    try {
      final db = await _db.database;
      await db.insert(
        'local_user_preferences',
        prefs.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('[UserPreferenceLocalService] Preferences saved (${prefs.syncStatus}).');
    } catch (e) {
      debugPrint('[UserPreferenceLocalService] Error saving preferences: $e');
    }
  }

  /// Lấy tùy chọn ăn uống từ SQLite
  Future<LocalUserPreferenceModel?> getCachedPreferences() async {
    try {
      final db = await _db.database;
      final rows = await db.query('local_user_preferences', limit: 1);
      if (rows.isEmpty) return null;
      return LocalUserPreferenceModel.fromMap(rows.first);
    } catch (e) {
      debugPrint('[UserPreferenceLocalService] Error reading preferences: $e');
      return null;
    }
  }

  /// Kiểm tra có preferences pending cần sync không
  Future<LocalUserPreferenceModel?> getPendingPreferences() async {
    try {
      final db = await _db.database;
      final rows = await db.query(
        'local_user_preferences',
        where: "sync_status = 'pending'",
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return LocalUserPreferenceModel.fromMap(rows.first);
    } catch (e) {
      debugPrint('[UserPreferenceLocalService] Error getting pending preferences: $e');
      return null;
    }
  }

  /// Đánh dấu preferences đã synced
  Future<void> markPreferencesSynced() async {
    try {
      final db = await _db.database;
      await db.update(
        'local_user_preferences',
        {'sync_status': 'synced'},
        where: 'id = ?',
        whereArgs: [1],
      );
    } catch (e) {
      debugPrint('[UserPreferenceLocalService] Error marking preferences synced: $e');
    }
  }

  /// Xóa cache (khi logout)
  Future<void> clearPreferencesCache() async {
    try {
      final db = await _db.database;
      await db.delete('local_user_preferences');
      debugPrint('[UserPreferenceLocalService] Preferences cache cleared.');
    } catch (e) {
      debugPrint('[UserPreferenceLocalService] Error clearing preferences: $e');
    }
  }
}
