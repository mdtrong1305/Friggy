class FridgeItemModel {
  final String id;
  final int ingredientId;
  final String ingredientName;
  final String? ingredientImagePath;
  final double quantity;
  final String unit;
  final String? purchasedAt;
  final String? expiresAt;
  final String storageLocation; // 'fridge', 'freezer', 'pantry'
  final String addedBy;
  final String? consumedAt;
  final int? daysUntilExpiry;
  final String createdAt;

  FridgeItemModel({
    required this.id,
    required this.ingredientId,
    required this.ingredientName,
    this.ingredientImagePath,
    required this.quantity,
    required this.unit,
    this.purchasedAt,
    this.expiresAt,
    this.storageLocation = 'fridge',
    required this.addedBy,
    this.consumedAt,
    this.daysUntilExpiry,
    required this.createdAt,
  });

  factory FridgeItemModel.fromJson(Map<String, dynamic> json) {
    return FridgeItemModel(
      id: json['id'] as String,
      ingredientId: json['ingredientId'] as int? ?? 0,
      ingredientName: json['ingredientName'] as String? ?? 'Nguyên liệu',
      ingredientImagePath: json['ingredientImagePath'] as String?,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] as String? ?? 'kg',
      purchasedAt: json['purchasedAt'] as String?,
      expiresAt: json['expiresAt'] as String?,
      storageLocation: json['storageLocation'] as String? ?? 'fridge',
      addedBy: json['addedBy'] as String? ?? '',
      consumedAt: json['consumedAt'] as String?,
      daysUntilExpiry: json['daysUntilExpiry'] as int?,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ingredientId': ingredientId,
      'ingredientName': ingredientName,
      if (ingredientImagePath != null) 'ingredientImagePath': ingredientImagePath,
      'quantity': quantity,
      'unit': unit,
      if (purchasedAt != null) 'purchasedAt': purchasedAt,
      if (expiresAt != null) 'expiresAt': expiresAt,
      'storageLocation': storageLocation,
      'addedBy': addedBy,
      if (consumedAt != null) 'consumedAt': consumedAt,
      if (daysUntilExpiry != null) 'daysUntilExpiry': daysUntilExpiry,
      'createdAt': createdAt,
    };
  }
}

class FridgeStatsModel {
  final int totalSpentThisMonth;
  final double wastePercent;
  final int mealsCooked;
  final int expiringSoonCount;
  final int totalItems;

  FridgeStatsModel({
    required this.totalSpentThisMonth,
    required this.wastePercent,
    required this.mealsCooked,
    required this.expiringSoonCount,
    required this.totalItems,
  });

  factory FridgeStatsModel.fromJson(Map<String, dynamic> json) {
    return FridgeStatsModel(
      totalSpentThisMonth: (json['totalSpentThisMonth'] as num?)?.toInt() ?? 0,
      wastePercent: (json['wastePercent'] as num?)?.toDouble() ?? 0.0,
      mealsCooked: (json['mealsCooked'] as num?)?.toInt() ?? 0,
      expiringSoonCount: (json['expiringSoonCount'] as num?)?.toInt() ?? 0,
      totalItems: (json['totalItems'] as num?)?.toInt() ?? 0,
    );
  }
}

class FridgeStatsChartModel {
  final String period; // 'week' or 'month'
  final List<String> labels;
  final List<double> spending;
  final List<int> wasteItems;

  FridgeStatsChartModel({
    required this.period,
    required this.labels,
    required this.spending,
    required this.wasteItems,
  });

  factory FridgeStatsChartModel.fromJson(Map<String, dynamic> json) {
    return FridgeStatsChartModel(
      period: json['period'] as String? ?? 'week',
      labels: json['labels'] is List
          ? (json['labels'] as List).map((e) => e.toString()).toList()
          : [],
      spending: json['spending'] is List
          ? (json['spending'] as List).map((e) => (e as num).toDouble()).toList()
          : [],
      wasteItems: json['wasteItems'] is List
          ? (json['wasteItems'] as List).map((e) => e as int).toList()
          : [],
    );
  }
}

class DetectedScanItemModel {
  final String name;
  final int? ingredientId;
  final double quantity;
  final String unit;
  final double? confidence;
  final bool needsConfirm;
  final bool allergyWarning;
  final int? estimatedExpiryDays;

  DetectedScanItemModel({
    required this.name,
    this.ingredientId,
    required this.quantity,
    required this.unit,
    this.confidence,
    this.needsConfirm = false,
    this.allergyWarning = false,
    this.estimatedExpiryDays,
  });

  factory DetectedScanItemModel.fromJson(Map<String, dynamic> json) {
    return DetectedScanItemModel(
      name: json['name'] as String? ?? 'Thực phẩm',
      ingredientId: json['ingredientId'] as int?,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: json['unit'] as String? ?? 'pcs',
      confidence: (json['confidence'] as num?)?.toDouble(),
      needsConfirm: json['needsConfirm'] as bool? ?? false,
      allergyWarning: json['allergyWarning'] as bool? ?? false,
      estimatedExpiryDays: json['estimatedExpiryDays'] as int?,
    );
  }

  Map<String, dynamic> toConfirmJson() {
    return {
      if (ingredientId != null) 'ingredientId': ingredientId,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      if (estimatedExpiryDays != null)
        'expiresAt': DateTime.now()
            .add(Duration(days: estimatedExpiryDays!))
            .toIso8601String()
            .split('T')[0],
      'storageLocation': 'fridge',
    };
  }
}

class ScanStatusModel {
  final String scanId;
  final String scanType;
  final String status; // 'pending', 'success', 'failed'
  final List<DetectedScanItemModel> detectedItems;
  final String? errorMessage;
  final String createdAt;

  ScanStatusModel({
    required this.scanId,
    required this.scanType,
    required this.status,
    required this.detectedItems,
    this.errorMessage,
    required this.createdAt,
  });

  factory ScanStatusModel.fromJson(Map<String, dynamic> json) {
    return ScanStatusModel(
      scanId: json['scanId'] as String? ?? '',
      scanType: json['scanType'] as String? ?? 'image',
      status: json['status'] as String? ?? 'pending',
      detectedItems: json['detectedItems'] is List
          ? (json['detectedItems'] as List)
              .map((e) => DetectedScanItemModel.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
      errorMessage: json['errorMessage'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class IngredientCatalogModel {
  final int id;
  final String name;
  final String? normalizedName;
  final String defaultUnit;
  final int defaultShelfLifeDays;
  final String? imageUrl;
  final int categoryId;
  final String? categoryName;

  IngredientCatalogModel({
    required this.id,
    required this.name,
    this.normalizedName,
    required this.defaultUnit,
    required this.defaultShelfLifeDays,
    this.imageUrl,
    required this.categoryId,
    this.categoryName,
  });

  factory IngredientCatalogModel.fromJson(Map<String, dynamic> json) {
    return IngredientCatalogModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      normalizedName: json['normalizedName'] as String?,
      defaultUnit: json['defaultUnit'] as String? ?? 'kg',
      defaultShelfLifeDays: json['defaultShelfLifeDays'] as int? ?? 7,
      imageUrl: json['imageUrl'] as String?,
      categoryId: json['categoryId'] as int? ?? 0,
      categoryName: json['category'] != null ? json['category']['name'] as String? : null,
    );
  }
}

class IngredientCategoryModel {
  final int id;
  final String name;
  final String? icon;
  final List<IngredientCategoryModel> children;

  IngredientCategoryModel({
    required this.id,
    required this.name,
    this.icon,
    this.children = const [],
  });

  factory IngredientCategoryModel.fromJson(Map<String, dynamic> json) {
    return IngredientCategoryModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      icon: json['icon'] as String?,
      children: json['children'] is List
          ? (json['children'] as List)
              .map((e) => IngredientCategoryModel.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
    );
  }
}
