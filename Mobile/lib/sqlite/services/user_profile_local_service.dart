import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../helpers/database_helper.dart';
import '../models/local_user_profile_model.dart';

class UserProfileLocalService {
  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Lưu (upsert) thông tin cá nhân vào SQLite
  Future<void> saveProfileCache(LocalUserProfileModel profile) async {
    try {
      final db = await _db.database;
      // Xóa các row UUID cũ (không phải 'me') trước khi lưu
      await db.delete(
        'local_user_profile',
        where: "id != 'me'",
      );
      await db.insert(
        'local_user_profile',
        profile.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('[UserProfileLocalService] Profile saved (${profile.syncStatus}) for user: ${profile.id}');
    } catch (e) {
      debugPrint('[UserProfileLocalService] Error saving profile: $e');
    }
  }

  /// Lấy thông tin cá nhân từ SQLite — luôn query theo id='me'
  Future<LocalUserProfileModel?> getCachedProfile() async {
    try {
      final db = await _db.database;
      // Ưu tiên id='me' (row offline/pending)
      final rows = await db.query(
        'local_user_profile',
        where: "id = 'me'",
        limit: 1,
      );
      if (rows.isNotEmpty) return LocalUserProfileModel.fromMap(rows.first);
      // Fallback: bất kỳ row nào (phòng trường hợp cũ)
      final fallback = await db.query('local_user_profile', limit: 1);
      if (fallback.isEmpty) return null;
      return LocalUserProfileModel.fromMap(fallback.first);
    } catch (e) {
      debugPrint('[UserProfileLocalService] Error reading profile cache: $e');
      return null;
    }
  }

  /// Kiểm tra có profile pending cần sync không
  Future<LocalUserProfileModel?> getPendingProfile() async {
    try {
      final db = await _db.database;
      final rows = await db.query(
        'local_user_profile',
        where: "sync_status = 'pending'",
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return LocalUserProfileModel.fromMap(rows.first);
    } catch (e) {
      debugPrint('[UserProfileLocalService] Error getting pending profile: $e');
      return null;
    }
  }

  /// Đánh dấu profile đã synced
  Future<void> markProfileSynced(String id) async {
    try {
      final db = await _db.database;
      await db.update(
        'local_user_profile',
        {'sync_status': 'synced'},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      debugPrint('[UserProfileLocalService] Error marking profile synced: $e');
    }
  }

  /// Xóa cache thông tin cá nhân (khi logout)
  Future<void> clearProfileCache() async {
    try {
      final db = await _db.database;
      await db.delete('local_user_profile');
      debugPrint('[UserProfileLocalService] Profile cache cleared.');
    } catch (e) {
      debugPrint('[UserProfileLocalService] Error clearing profile: $e');
    }
  }
}
