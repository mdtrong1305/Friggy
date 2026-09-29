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
}
