/// Model cho danh mục nguyên liệu toàn hệ thống (để tìm kiếm offline)
/// Khác với LocalIngredientModel (items trong tủ của user)
class LocalIngredientCatalogModel {
  final int id; // ingredient catalog ID từ server
  final String name; // tên tiếng Việt
  final String? englishName; // tên tiếng Anh
  final String? defaultUnit; // đơn vị mặc định: kg, gram, quả...
  final String? category; // nhóm: Rau củ, Thịt, Hải sản...
  final String? imagePath; // URL ảnh từ server
  final int updatedAt;

  LocalIngredientCatalogModel({
    required this.id,
    required this.name,
    this.englishName,
    this.defaultUnit,
    this.category,
    this.imagePath,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'english_name': englishName,
      'default_unit': defaultUnit,
      'category': category,
      'image_path': imagePath,
      'updated_at': updatedAt,
    };
  }

  factory LocalIngredientCatalogModel.fromMap(Map<String, dynamic> map) {
    return LocalIngredientCatalogModel(
      id: map['id'] as int,
      name: map['name'] as String,
      englishName: map['english_name'] as String?,
      defaultUnit: map['default_unit'] as String?,
      category: map['category'] as String?,
      imagePath: map['image_path'] as String?,
      updatedAt: map['updated_at'] as int,
    );
  }

  /// Chuyển sang dạng Map để hiển thị trong UI (tương thích với API response)
  Map<String, dynamic> toApiFormat() {
    return {
      'id': id,
      'name': name,
      'englishName': englishName ?? name,
      'defaultUnit': defaultUnit ?? 'kg',
      'category': category,
      'imagePath': imagePath ?? '',
    };
  }
}
