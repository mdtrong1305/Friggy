class LocalStatsModel {
  final int id;
  final int totalSpentThisMonth;
  final double wastePercent;
  final int mealsCooked;
  final int expiringSoonCount;
  final int totalItems;
  final String chartJson;
  final int updatedAt;

  LocalStatsModel({
    this.id = 1,
    required this.totalSpentThisMonth,
    required this.wastePercent,
    required this.mealsCooked,
    required this.expiringSoonCount,
    required this.totalItems,
    this.chartJson = '{}',
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'total_spent_this_month': totalSpentThisMonth,
      'waste_percent': wastePercent,
      'meals_cooked': mealsCooked,
      'expiring_soon_count': expiringSoonCount,
      'total_items': totalItems,
      'chart_json': chartJson,
      'updated_at': updatedAt,
    };
  }

  factory LocalStatsModel.fromMap(Map<String, dynamic> map) {
    return LocalStatsModel(
      id: map['id'] as int? ?? 1,
      totalSpentThisMonth: map['total_spent_this_month'] as int? ?? 0,
      wastePercent: (map['waste_percent'] as num?)?.toDouble() ?? 0.0,
      mealsCooked: map['meals_cooked'] as int? ?? 0,
      expiringSoonCount: map['expiring_soon_count'] as int? ?? 0,
      totalItems: map['total_items'] as int? ?? 0,
      chartJson: map['chart_json'] as String? ?? '{}',
      updatedAt: map['updated_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}
