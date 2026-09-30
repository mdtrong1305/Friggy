/// Model cho bảng local_shopping_items trong SQLite
/// sync_status:
///   'synced'         — đã đồng bộ với server
///   'pending_toggle' — tick/untick offline, chờ PATCH lên server
class LocalShoppingItemModel {
  final String id;
  final int ingredientId;
  final String ingredientName;
  final double quantity;
  final String unit;
  final bool isPurchased;
  final int updatedAt;
  final String syncStatus;

  /// listId của shopping list trên server (cần cho PATCH toggle)
  final String? listId;
  /// backendItemId (int) từ server (cần cho PATCH toggle)
  final int? backendItemId;

  LocalShoppingItemModel({
    required this.id,
    required this.ingredientId,
    required this.ingredientName,
    required this.quantity,
    required this.unit,
    this.isPurchased = false,
    required this.updatedAt,
    this.syncStatus = 'synced',
    this.listId,
    this.backendItemId,
  });

  bool get isSynced => syncStatus == 'synced';
  bool get isPendingToggle => syncStatus == 'pending_toggle';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ingredient_id': ingredientId,
      'ingredient_name': ingredientName,
      'quantity': quantity,
      'unit': unit,
      'is_purchased': isPurchased ? 1 : 0,
      'updated_at': updatedAt,
      'sync_status': syncStatus,
      'list_id': listId,
      'backend_item_id': backendItemId,
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
      syncStatus: map['sync_status'] as String? ?? 'synced',
      listId: map['list_id'] as String?,
      backendItemId: map['backend_item_id'] as int?,
    );
  }

  LocalShoppingItemModel copyWith({
    bool? isPurchased,
    String? syncStatus,
    String? listId,
    int? backendItemId,
  }) {
    return LocalShoppingItemModel(
      id: id,
      ingredientId: ingredientId,
      ingredientName: ingredientName,
      quantity: quantity,
      unit: unit,
      isPurchased: isPurchased ?? this.isPurchased,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      syncStatus: syncStatus ?? this.syncStatus,
      listId: listId ?? this.listId,
      backendItemId: backendItemId ?? this.backendItemId,
    );
  }
}
