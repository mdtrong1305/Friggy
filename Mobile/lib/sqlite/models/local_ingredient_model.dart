class LocalIngredientModel {
  final String id;
  final int ingredientId;
  final String name;
  final double quantity;
  final String unit;
  final String storageLocation;
  final String? expiresAt;
  final int? daysUntilExpiry;
  final String? imagePath;
  final int updatedAt;

  LocalIngredientModel({
    required this.id,
    required this.ingredientId,
    required this.name,
    required this.quantity,
    required this.unit,
    this.storageLocation = 'fridge',
    this.expiresAt,
    this.daysUntilExpiry,
    this.imagePath,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ingredient_id': ingredientId,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'storage_location': storageLocation,
      'expires_at': expiresAt,
      'days_until_expiry': daysUntilExpiry,
      'image_path': imagePath,
      'updated_at': updatedAt,
    };
  }

  factory LocalIngredientModel.fromMap(Map<String, dynamic> map) {
    return LocalIngredientModel(
      id: map['id'] as String,
      ingredientId: map['ingredient_id'] as int? ?? 0,
      name: map['name'] as String? ?? 'Nguyên liệu',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] as String? ?? 'kg',
      storageLocation: map['storage_location'] as String? ?? 'fridge',
      expiresAt: map['expires_at'] as String?,
      daysUntilExpiry: map['days_until_expiry'] as int?,
      imagePath: map['image_path'] as String?,
      updatedAt: map['updated_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}
