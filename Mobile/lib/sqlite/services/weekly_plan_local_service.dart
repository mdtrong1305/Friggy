import 'package:sqflite/sqflite.dart';
import '../helpers/database_helper.dart';
import '../models/local_weekly_plan_model.dart';

class WeeklyPlanLocalService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Save new weekly plan (overwriting old plan when user generates/modifies weekly plan)
  Future<void> saveWeeklyPlanOverwrite(LocalWeeklyPlanModel plan) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // Overwrite: clear old plan data
      await txn.delete('local_weekly_plans');
      await txn.insert(
        'local_weekly_plans',
        plan.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  /// Get cached weekly plan
  Future<LocalWeeklyPlanModel?> getCachedWeeklyPlan() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'local_weekly_plans',
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return LocalWeeklyPlanModel.fromMap(maps.first);
    }
    return null;
  }

  /// Get today's meals directly derived from the weekly plan
  Future<List<dynamic>> getTodayMealsFromWeeklyPlan() async {
    final plan = await getCachedWeeklyPlan();
    if (plan != null) {
      return plan.getTodayMeals();
    }
    return [];
  }
}
