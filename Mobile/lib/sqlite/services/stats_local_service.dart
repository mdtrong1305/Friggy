import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../helpers/database_helper.dart';
import '../models/local_stats_model.dart';

class StatsLocalService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Save or overwrite stats cache
  Future<void> saveStatsCache(LocalStatsModel stats) async {
    final db = await _dbHelper.database;
    await db.insert(
      'local_fridge_stats',
      stats.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get cached stats
  Future<LocalStatsModel?> getCachedStats() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'local_fridge_stats',
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return LocalStatsModel.fromMap(maps.first);
    }
    return null;
  }

  /// Tăng số bữa ăn đã nấu trong SQLite ngay lập tức (dùng khi offline tick "Nấu xong")
  Future<void> incrementMealsCookedLocally({int delta = 1}) async {
    try {
      final db = await _dbHelper.database;
      await db.rawUpdate(
        'UPDATE local_fridge_stats SET meals_cooked = meals_cooked + ?, updated_at = ? WHERE id = 1',
        [delta, DateTime.now().millisecondsSinceEpoch],
      );
    } catch (e) {
      debugPrint('[StatsLocalService] Error incrementing meals_cooked: $e');
    }
  }

  /// Giảm số bữa ăn đã nấu trong SQLite (dùng khi untoggle offline)
  Future<void> decrementMealsCookedLocally({int delta = 1}) async {
    try {
      final db = await _dbHelper.database;
      await db.rawUpdate(
        'UPDATE local_fridge_stats SET meals_cooked = MAX(0, meals_cooked - ?), updated_at = ? WHERE id = 1',
        [delta, DateTime.now().millisecondsSinceEpoch],
      );
    } catch (e) {
      debugPrint('[StatsLocalService] Error decrementing meals_cooked: $e');
    }
  }
}
