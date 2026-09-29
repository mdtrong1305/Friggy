import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../../sqlite/services/ingredient_local_service.dart';
import '../../sqlite/models/local_ingredient_model.dart';

class FridgeSummaryModel {
  final int expiredCount;
  final int availableCount;

  const FridgeSummaryModel({
    required this.expiredCount,
    required this.availableCount,
  });

  factory FridgeSummaryModel.fromJson(Map<String, dynamic> json) {
    return FridgeSummaryModel(
      expiredCount: json['expired_count'] ?? 0,
      availableCount: json['available_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'expired_count': expiredCount,
      'available_count': availableCount,
    };
  }
}

class FridgeSummaryRepository {
  static final IngredientLocalService _ingredientLocalService = IngredientLocalService();

  /// Fetch summary stats calculated dynamically from live Backend API or SQLite offline cache
  static Future<FridgeSummaryModel> fetchFridgeSummary() async {
    try {
      final items = await ApiService().getFridgeItems();
      int expiredCount = 0;
      int availableCount = 0;
      final List<LocalIngredientModel> localItems = [];

      for (var item in items) {
        final days = (item['daysUntilExpiry'] as num?)?.toInt() ?? 5;
        if (days < 0) {
          expiredCount++;
        } else {
          availableCount++;
        }
        localItems.add(LocalIngredientModel(
          id: item['id']?.toString() ?? '',
          ingredientId: (item['ingredientId'] as num?)?.toInt() ?? 0,
          name: item['ingredientName']?.toString() ?? 'Nguyên liệu',
          quantity: (item['quantity'] as num?)?.toDouble() ?? 1.0,
          unit: item['unit']?.toString() ?? 'kg',
          storageLocation: item['storageLocation']?.toString() ?? 'fridge',
          expiresAt: item['expiresAt']?.toString(),
          daysUntilExpiry: days,
          imagePath: item['ingredientImagePath']?.toString(),
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ));
      }

      // Save to SQLite cache
      await _ingredientLocalService.saveIngredientsCache(localItems);

      return FridgeSummaryModel(
        expiredCount: expiredCount,
        availableCount: availableCount,
      );
    } catch (e) {
      debugPrint('[FridgeSummaryRepository] Offline or Error fetching summary from API: $e. Falling back to SQLite cache.');
      try {
        final cached = await _ingredientLocalService.getCachedIngredients();
        int expiredCount = 0;
        int availableCount = 0;

        for (var item in cached) {
          if ((item.daysUntilExpiry ?? 5) < 0) {
            expiredCount++;
          } else {
            availableCount++;
          }
        }
        return FridgeSummaryModel(
          expiredCount: expiredCount,
          availableCount: availableCount,
        );
      } catch (err) {
        debugPrint('[FridgeSummaryRepository] SQLite cache read error: $err');
        return const FridgeSummaryModel(
          expiredCount: 0,
          availableCount: 0,
        );
      }
    }
  }
}
