import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../helpers/database_helper.dart';
import '../models/local_recipe_detail_model.dart';

class RecipeDetailLocalService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Lưu hoặc cập nhật chi tiết công thức vào SQLite
  Future<void> saveRecipeDetail(LocalRecipeDetailModel detail) async {
    try {
      final db = await _dbHelper.database;
      await db.insert(
        'local_recipe_details',
        detail.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('[RecipeDetailLocalService] Saved ${detail.idType} detail: ${detail.id}');
    } catch (e) {
      debugPrint('[RecipeDetailLocalService] Error saving recipe detail: $e');
    }
  }

  /// Lưu từ JSON Map trực tiếp (tiện gọi hơn)
  Future<void> saveFromJson(
    String id,
    String idType,
    Map<String, dynamic> json,
  ) async {
    await saveRecipeDetail(LocalRecipeDetailModel(
      id: id,
      idType: idType,
      detailJson: jsonEncode(json),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  /// Lấy chi tiết công thức theo id (slotId hoặc recipeId)
  Future<LocalRecipeDetailModel?> getRecipeDetail(String id) async {
    try {
      final db = await _dbHelper.database;
      final rows = await db.query(
        'local_recipe_details',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isNotEmpty) return LocalRecipeDetailModel.fromMap(rows.first);
    } catch (e) {
      debugPrint('[RecipeDetailLocalService] Error reading recipe detail: $e');
    }
    return null;
  }

  /// Lấy tất cả IDs đã cache
  Future<Set<String>> getCachedIds() async {
    try {
      final db = await _dbHelper.database;
      final rows = await db.query('local_recipe_details', columns: ['id']);
      return rows.map((r) => r['id'] as String).toSet();
    } catch (e) {
      debugPrint('[RecipeDetailLocalService] Error reading cached IDs: $e');
      return {};
    }
  }

  /// Xóa cache cũ (> 7 ngày) để tránh SQLite phình to
  Future<void> cleanOldCache() async {
    try {
      final db = await _dbHelper.database;
      final cutoff = DateTime.now()
          .subtract(const Duration(days: 7))
          .millisecondsSinceEpoch;
      final deleted = await db.delete(
        'local_recipe_details',
        where: 'updated_at < ?',
        whereArgs: [cutoff],
      );
      if (deleted > 0) {
        debugPrint('[RecipeDetailLocalService] Cleaned $deleted old recipe detail(s).');
      }
    } catch (e) {
      debugPrint('[RecipeDetailLocalService] Error cleaning cache: $e');
    }
  }
}
