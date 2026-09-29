/// Model cho bảng local_allergies trong SQLite
/// sync_status: 'synced' | 'pending' | 'pending_delete'
class LocalAllergyModel {
  final String id;
  final int ingredientId;
  final String ingredientName;
  final String? note;
  final int updatedAt;
  final String syncStatus; // 'synced' | 'pending' | 'pending_delete'

  LocalAllergyModel({
    required this.id,
    required this.ingredientId,
    required this.ingredientName,
    this.note,
    required this.updatedAt,
    this.syncStatus = 'synced',
  });

  bool get isPending => syncStatus == 'pending';
  bool get isSynced => syncStatus == 'synced';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ingredient_id': ingredientId,
      'ingredient_name': ingredientName,
      'note': note,
      'updated_at': updatedAt,
      'sync_status': syncStatus,
    };
  }

  factory LocalAllergyModel.fromMap(Map<String, dynamic> map) {
    return LocalAllergyModel(
      id: map['id'] as String,
      ingredientId: map['ingredient_id'] as int,
      ingredientName: map['ingredient_name'] as String,
      note: map['note'] as String?,
      updatedAt: map['updated_at'] as int,
      syncStatus: map['sync_status'] as String? ?? 'synced',
    );
  }

  LocalAllergyModel copyWith({String? id, String? syncStatus}) {
    return LocalAllergyModel(
      id: id ?? this.id,
      ingredientId: ingredientId,
      ingredientName: ingredientName,
      note: note,
      updatedAt: updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
