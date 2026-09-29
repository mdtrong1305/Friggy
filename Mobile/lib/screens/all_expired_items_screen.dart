import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/models/ingredient_model.dart';
import '../l10n/app_localizations.dart';
import '../data/services/api_service.dart';
import '../widgets/ingredient_avatar_widget.dart';
import '../sqlite/services/ingredient_local_service.dart';

class AllExpiredItemsScreen extends StatefulWidget {
  const AllExpiredItemsScreen({super.key});

  @override
  State<AllExpiredItemsScreen> createState() => _AllExpiredItemsScreenState();
}

class _AllExpiredItemsScreenState extends State<AllExpiredItemsScreen> {
  final ApiService _apiService = ApiService();
  List<IngredientModel> _expiredItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExpiredItems();
  }

  Future<void> _loadExpiredItems() async {
    setState(() => _isLoading = true);
    final ingredientLocalService = IngredientLocalService();
    try {
      final res = await _apiService.getFridgeItems();
      final list = res
          .map((e) => IngredientModel.fromFridgeApi(e))
          .where((i) => i.isExpired)
          .toList();
      if (mounted) {
        setState(() {
          _expiredItems = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[AllExpiredItemsScreen] Error/Offline loading expired items: $e. Loading from SQLite...');
      try {
        final cached = await ingredientLocalService.getCachedIngredients();
        final List<IngredientModel> offlineExpired = cached
            .where((item) => (item.daysUntilExpiry ?? 5) < 0)
            .map((item) {
          return IngredientModel(
            id: item.id,
            fridgeId: '1',
            fridgeName: 'Tủ lạnh',
            name: item.name,
            englishName: item.name,
            quantity: '${item.quantity} ${item.unit}',
            unit: item.unit,
            category: 'Thực phẩm',
            storageArea: item.storageLocation,
            daysUntilExpiry: item.daysUntilExpiry ?? -1,
            expiryText: 'Quá hạn ${(item.daysUntilExpiry ?? -1).abs()} ngày',
            imagePath: item.imagePath ?? '',
            badgeBgColor: const Color(0xFFFFEBEE),
            badgeTextColor: const Color(0xFFC62828),
          );
        }).toList();

        if (mounted) {
          setState(() {
            _expiredItems = offlineExpired;
            _isLoading = false;
          });
        }
      } catch (err) {
        debugPrint('[AllExpiredItemsScreen] SQLite read error: $err');
        if (mounted) {
          setState(() {
            _expiredItems = [];
            _isLoading = false;
          });
        }
      }
    }
  }

  String _getLocalizedFridgeName(String name, bool isEn) {
    if (!isEn) return name;
    if (name.contains('Gia Đình')) return 'Family Fridge';
    if (name.contains('Phòng Trọ')) return 'Dorm Fridge';
    if (name.contains('Cá Nhân')) return 'Personal Fridge';
    return name;
  }

  String _getLocalizedQuantity(String q, bool isEn) {
    if (!isEn) return q;
    return q.replaceAll('hộp', 'boxes').replaceAll('lít', 'L').replaceAll('quả', 'pcs');
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isEn = loc?.locale.languageCode == 'en';

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF0F0),
              Color(0xFFFFCDD2),
              Color(0xFFEF9A9A),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 1. Top Header with Back Chevron
              Padding(
                padding: EdgeInsets.only(
                  left: 8.0.w,
                  right: 16.0.w,
                  top: 8.0.h,
                  bottom: 8.0.h,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.chevron_left_rounded,
                        size: 34,
                        color: Color(0xFF19221C),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      isEn ? 'Expired Ingredients' : 'Nguyên Liệu Hết Hạn',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFB71C1C),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 8.h),

              // Title Section
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEn ? 'All Expired Items' : 'Tất cả thực phẩm hết hạn',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 21.sp,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFB71C1C),
                              letterSpacing: -0.3,
                              height: 1.15,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            isEn ? 'Combined from all your fridges' : 'Tổng hợp từ tất cả các tủ lạnh của bạn',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF880E4F),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB71C1C),
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: Text(
                        isEn ? '${_expiredItems.length} items' : '${_expiredItems.length} món',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16.h),

              // Expired Items List
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.0),
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Color(0xFFB71C1C)),
                        )
                      : _expiredItems.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    size: 64,
                                    color: Color(0xFF008435),
                                  ),
                                  SizedBox(height: 12.h),
                                  Text(
                                    isEn
                                        ? 'Awesome! No expired food found.'
                                        : 'Tuyệt vời! Không có thực phẩm nào bị hết hạn.',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF008435),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              itemCount: _expiredItems.length,
                              separatorBuilder: (context, index) =>
                                  SizedBox(height: 12.h),
                              itemBuilder: (context, index) {
                                final item = _expiredItems[index];
                                final name = isEn && item.englishName.isNotEmpty ? item.englishName : item.name;
                                final fName = _getLocalizedFridgeName(item.fridgeName, isEn);
                                final qty = _getLocalizedQuantity(item.quantity, isEn);
                                final expiry = isEn ? 'Expired' : item.expiryText;

                                return Container(
                                  padding: EdgeInsets.all(14.w),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20.r),
                                    border: Border.all(
                                      color: const Color(0xFFEF9A9A),
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.05),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      IngredientAvatarWidget(item: item, size: 54),
                                      SizedBox(width: 14.w),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 18.sp,
                                                fontWeight: FontWeight.w800,
                                                color: const Color(0xFFB71C1C),
                                              ),
                                            ),
                                            SizedBox(height: 3.h),
                                            Text(
                                              '$fName • $qty',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 12.5.sp,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF6B786F),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFEBEE),
                                          borderRadius: BorderRadius.circular(12.r),
                                        ),
                                        child: Text(
                                          expiry,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFFD32F2F),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
