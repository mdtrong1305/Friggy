/// Model cho bảng local_ingredients trong SQLite
/// sync_status: 'synced' | 'pending'
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
  final String syncStatus; // 'synced' | 'pending'

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
    this.syncStatus = 'synced',
  });

  bool get isPending => syncStatus == 'pending';
  bool get isSynced => syncStatus == 'synced';

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
      'sync_status': syncStatus,
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
      syncStatus: map['sync_status'] as String? ?? 'synced',
    );
  }

  LocalIngredientModel copyWith({
    String? id,
    String? syncStatus,
    String? imagePath,
  }) {
    return LocalIngredientModel(
      id: id ?? this.id,
      ingredientId: ingredientId,
      name: name,
      quantity: quantity,
      unit: unit,
      storageLocation: storageLocation,
      expiresAt: expiresAt,
      daysUntilExpiry: daysUntilExpiry,
      imagePath: imagePath ?? this.imagePath,
      updatedAt: updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
