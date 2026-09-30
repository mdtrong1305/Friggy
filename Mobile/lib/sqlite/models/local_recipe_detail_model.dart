import 'dart:convert';

/// Cache chi tiết công thức từ API (slot detail hoặc recipe detail)
/// Lưu toàn bộ JSON gốc để RecipeModel.fromApi() có thể parse offline
class LocalRecipeDetailModel {
  /// Key tìm kiếm: có thể là recipeId hoặc slotId
  final String id;

  /// 'slot' hoặc 'recipe' — biết loại API nào đã fetch
  final String idType;

  /// JSON gốc từ API — encode thành String để lưu SQLite
  final String detailJson;

  final int updatedAt;

  LocalRecipeDetailModel({
    required this.id,
    required this.idType,
    required this.detailJson,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'id_type': idType,
        'detail_json': detailJson,
        'updated_at': updatedAt,
      };

  factory LocalRecipeDetailModel.fromMap(Map<String, dynamic> map) =>
      LocalRecipeDetailModel(
        id: map['id'] as String,
        idType: map['id_type'] as String? ?? 'recipe',
        detailJson: map['detail_json'] as String? ?? '{}',
        updatedAt: map['updated_at'] as int? ?? 0,
      );

  /// Decode JSON thành Map để truyền vào RecipeModel.fromApi()
  Map<String, dynamic> get decodedDetail {
    try {
      return jsonDecode(detailJson) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}
