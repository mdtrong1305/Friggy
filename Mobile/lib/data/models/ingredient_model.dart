import 'package:flutter/material.dart';

class IngredientModel {
  final String id;
  final String fridgeId; // 'family', 'roommates', 'personal'
  final String fridgeName; // "Family Home Fridge", etc.
  final String name; // e.g. "Cà chua"
  final String englishName;
  final String quantity;
  final String unit;
  final String category; // "Vegetables", "Fruit", "Dairy", "Meat"
  final String storageArea; // "Fridge", "Freezer", "Pantry"
  final int daysUntilExpiry; // positive for valid, negative for expired
  final String expiryText;
  final String imagePath;
  final Color badgeBgColor;
  final Color badgeTextColor;

  const IngredientModel({
    required this.id,
    required this.fridgeId,
    required this.fridgeName,
    required this.name,
    required this.englishName,
    required this.quantity,
    this.unit = 'kg',
    required this.category,
    required this.storageArea,
    required this.daysUntilExpiry,
    required this.expiryText,
    required this.imagePath,
    required this.badgeBgColor,
    required this.badgeTextColor,
  });

  bool get isExpired => daysUntilExpiry < 0;
  bool get isExpiringSoon => daysUntilExpiry >= 0 && daysUntilExpiry <= 2;

  String displayName(bool isEn) {
    if (!isEn) return name;
    if (englishName.isNotEmpty) return englishName;
    return name;
  }

  String expiryStatusText(bool isEn) {
    if (!isEn) return expiryText;
    if (daysUntilExpiry < 0) return 'Expired';
    if (daysUntilExpiry == 0) return 'Expires today';
    if (daysUntilExpiry == 1) return '1 day left';
    return '$daysUntilExpiry days left';
  }

  IngredientModel copyWith({
    String? id,
    String? fridgeId,
    String? fridgeName,
    String? name,
    String? englishName,
    String? quantity,
    String? unit,
    String? category,
    String? storageArea,
    int? daysUntilExpiry,
    String? expiryText,
    String? imagePath,
    Color? badgeBgColor,
    Color? badgeTextColor,
  }) {
    return IngredientModel(
      id: id ?? this.id,
      fridgeId: fridgeId ?? this.fridgeId,
      fridgeName: fridgeName ?? this.fridgeName,
      name: name ?? this.name,
      englishName: englishName ?? this.englishName,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      category: category ?? this.category,
      storageArea: storageArea ?? this.storageArea,
      daysUntilExpiry: daysUntilExpiry ?? this.daysUntilExpiry,
      expiryText: expiryText ?? this.expiryText,
      imagePath: imagePath ?? this.imagePath,
      badgeBgColor: badgeBgColor ?? this.badgeBgColor,
      badgeTextColor: badgeTextColor ?? this.badgeTextColor,
    );
  }

  factory IngredientModel.fromFridgeApi(Map<String, dynamic> json, [String fridgeId = 'family', String fridgeName = 'Tủ Lạnh Gia Đình']) {
    final id = json['id'] as String? ?? '';
    final name = json['ingredientName'] as String? ?? 'Nguyên liệu';
    final qty = json['quantity'];
    final unit = json['unit'] as String? ?? 'kg';
    final storageLoc = json['storageLocation'] as String? ?? 'fridge';
    
    String storageArea = 'Fridge';
    if (storageLoc == 'freezer') storageArea = 'Freezer';
    if (storageLoc == 'pantry') storageArea = 'Pantry';

    final daysUntilExpiry = (json['daysUntilExpiry'] as num?)?.toInt() ?? 999;
    String expiryText = 'Còn $daysUntilExpiry ngày';
    Color badgeBgColor = const Color(0xFFE8F5E9);
    Color badgeTextColor = const Color(0xFF2E7D32);

    if (daysUntilExpiry == 999 || json['daysUntilExpiry'] == null) {
      expiryText = 'Chưa có HSD';
      badgeBgColor = const Color(0xFFF5F5F5);
      badgeTextColor = const Color(0xFF757575);
    } else if (daysUntilExpiry < 0) {
      expiryText = 'Quá hạn ${daysUntilExpiry.abs()} ngày';
      badgeBgColor = const Color(0xFFFFEBEE);
      badgeTextColor = const Color(0xFFC62828);
    } else if (daysUntilExpiry == 0) {
      expiryText = 'Hết hạn hôm nay';
      badgeBgColor = const Color(0xFFFFF8E1);
      badgeTextColor = const Color(0xFFF57F17);
    } else if (daysUntilExpiry <= 2) {
      expiryText = 'Còn $daysUntilExpiry ngày';
      badgeBgColor = const Color(0xFFFFF8E1);
      badgeTextColor = const Color(0xFFF57F17);
    }

    String img = json['ingredientImagePath'] as String? ??
        json['imagePath'] as String? ??
        json['image'] as String? ??
        '';
    if (img == 'null') {
      img = '';
    }

    return IngredientModel(
      id: id,
      fridgeId: fridgeId,
      fridgeName: fridgeName,
      name: name,
      englishName: name,
      quantity: '$qty $unit',
      unit: unit,
      category: 'Thực phẩm',
      storageArea: storageArea,
      daysUntilExpiry: daysUntilExpiry,
      expiryText: expiryText,
      imagePath: img,
      badgeBgColor: badgeBgColor,
      badgeTextColor: badgeTextColor,
    );
  }
}
