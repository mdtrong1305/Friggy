import 'package:sqflite/sqflite.dart';
import '../helpers/database_helper.dart';
import '../models/local_shopping_model.dart';

class ShoppingLocalService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Replace all shopping list items in SQLite (overwriting old list when new list generated)
  Future<void> saveShoppingItemsOverwrite(List<LocalShoppingItemModel> items) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete('local_shopping_items');
      for (var item in items) {
        await txn.insert(
          'local_shopping_items',
          item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Get cached shopping list items
  Future<List<LocalShoppingItemModel>> getCachedShoppingItems() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('local_shopping_items');
    return maps.map((e) => LocalShoppingItemModel.fromMap(e)).toList();
  }
}
