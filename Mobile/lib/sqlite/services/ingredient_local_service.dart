import 'package:sqflite/sqflite.dart';
import '../helpers/database_helper.dart';
import '../models/local_ingredient_model.dart';

class IngredientLocalService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Replace all ingredients cache in SQLite
  Future<void> saveIngredientsCache(List<LocalIngredientModel> items) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete('local_ingredients');
      for (var item in items) {
        await txn.insert(
          'local_ingredients',
          item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Get all cached ingredients
  Future<List<LocalIngredientModel>> getCachedIngredients() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('local_ingredients');
    return maps.map((e) => LocalIngredientModel.fromMap(e)).toList();
  }

  /// Get expiring ingredients
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
}
