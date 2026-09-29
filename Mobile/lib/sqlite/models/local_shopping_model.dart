class LocalShoppingItemModel {
  final String id;
  final int ingredientId;
  final String ingredientName;
  final double quantity;
  final String unit;
  final bool isPurchased;
  final int updatedAt;

  LocalShoppingItemModel({
    required this.id,
    required this.ingredientId,
    required this.ingredientName,
    required this.quantity,
    required this.unit,
    this.isPurchased = false,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ingredient_id': ingredientId,
      'ingredient_name': ingredientName,
      'quantity': quantity,
      'unit': unit,
      'is_purchased': isPurchased ? 1 : 0,
      'updated_at': updatedAt,
    };
  }

  factory LocalShoppingItemModel.fromMap(Map<String, dynamic> map) {
    return LocalShoppingItemModel(
      id: map['id'] as String,
      ingredientId: map['ingredient_id'] as int? ?? 0,
      ingredientName: map['ingredient_name'] as String? ?? 'Nguyên liệu',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: map['unit'] as String? ?? 'món',
      isPurchased: (map['is_purchased'] as int? ?? 0) == 1,
      updatedAt: map['updated_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}
