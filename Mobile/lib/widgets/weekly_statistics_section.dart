import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../data/services/api_service.dart';
import '../data/models/fridge_models.dart';
import '../sqlite/services/stats_local_service.dart';
import '../sqlite/models/local_stats_model.dart';

class WeeklyStatisticsSection extends StatefulWidget {
  final VoidCallback? onDetailTap;
  final VoidCallback? onMealSuggestionsTap;
  final VoidCallback? onShoppingReminderTap;

  const WeeklyStatisticsSection({
    super.key,
    this.onDetailTap,
    this.onMealSuggestionsTap,
    this.onShoppingReminderTap,
  });

  @override
  State<WeeklyStatisticsSection> createState() =>
      WeeklyStatisticsSectionState();
}

class WeeklyStatisticsSectionState extends State<WeeklyStatisticsSection> {
  final ApiService _apiService = ApiService();
  final StatsLocalService _statsLocalService = StatsLocalService();
  FridgeStatsModel? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  void reload() {
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final statsRes = await _apiService.getFridgeStats();
      final statsModel = FridgeStatsModel.fromJson(statsRes);
      if (mounted) {
        setState(() {
          _stats = statsModel;
        });
      }

      // Save to SQLite
      await _statsLocalService.saveStatsCache(LocalStatsModel(
        totalSpentThisMonth: statsModel.totalSpentThisMonth,
        wastePercent: statsModel.wastePercent,
        mealsCooked: statsModel.mealsCooked,
        expiringSoonCount: statsModel.expiringSoonCount,
        totalItems: statsModel.totalItems,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ));
    } catch (e) {
      debugPrint('[WeeklyStatisticsSection] Error/Offline loading stats: $e. Loading from SQLite.');
      final cached = await _statsLocalService.getCachedStats();
      if (cached != null && mounted) {
        setState(() {
          _stats = FridgeStatsModel(
            totalSpentThisMonth: cached.totalSpentThisMonth,
            wastePercent: cached.wastePercent,
            mealsCooked: cached.mealsCooked,
            expiringSoonCount: cached.expiringSoonCount,
            totalItems: cached.totalItems,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final isEn = loc?.locale.languageCode == 'en';

    final mealsCooked = _stats?.mealsCooked ?? 0;
    final expiringSoon = _stats?.expiringSoonCount ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header Title Row: "This Week Statistics" + "View Details ›"
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              isEn ? "This Week's Stats" : 'Thống Kê Tuần Này',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
            GestureDetector(
              onTap: widget.onDetailTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isEn ? 'View details' : 'Xem chi tiết',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // 2. Side-by-Side Statistics Cards with smaller frame height (106px) and bigger image pop-outs
        GestureDetector(
          onTap: widget.onDetailTap,
          child: Padding(
            padding:
                const EdgeInsets.only(top: 22, bottom: 22, left: 12, right: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Card: MOST USED / BỮA ĐÃ NẤU
                Expanded(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 106,
                        padding: const EdgeInsets.only(
                            left: 72, top: 8, right: 6, bottom: 8),
                        decoration: BoxDecoration(
                          color:
                              isDark ? const Color(0xFF19271E) : Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: isDark
                              ? Border.all(
                                  color: const Color(0xFF2E4D36), width: 1)
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withValues(alpha: isDark ? 0.2 : 0.06),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isEn ? 'COOKED' : 'BỮA ĐÃ NẤU',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? const Color(0xFF81C784)
                                    : const Color(0xFF4CAF50),
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 1),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                isEn ? 'Meals Cooked' : 'Đã nấu ăn',
                                style: GoogleFonts.outfit(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w900,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF19221C),
                                  height: 1.1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '$mealsCooked',
                                  style: GoogleFonts.outfit(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF19221C),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isEn ? 'meals' : 'bữa',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? const Color(0xFF81C784)
                                        : const Color(0xFF2E7D32),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: -28,
                        top: -22,
                        width: 100,
                        height: 100,
                        child: Image.asset(
                          'assets/images/left.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 14),

                // Right Card: WASTED / SẮP HẾT HẠN
                Expanded(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 106,
                        padding: const EdgeInsets.only(
                            left: 14, top: 8, right: 60, bottom: 8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2D1C1C)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: isDark
                              ? Border.all(
                                  color: const Color(0xFF5C2525), width: 1)
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withValues(alpha: isDark ? 0.2 : 0.06),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isEn ? 'EXPIRING' : 'CẦN CHÚ Ý',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? const Color(0xFFFF8A80)
                                    : const Color(0xFFD32F2F),
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 1),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                isEn ? 'Expiring Soon' : 'Sắp hết hạn',
                                style: GoogleFonts.outfit(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w900,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF19221C),
                                  height: 1.1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '$expiringSoon',
                                  style: GoogleFonts.outfit(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: isDark
                                        ? const Color(0xFFFF8A80)
                                        : const Color(0xFFD32F2F),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isEn ? 'items' : 'món',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? const Color(0xFFFF8A80)
                                        : const Color(0xFFD32F2F),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        right: -24,
                        bottom: -22,
                        width: 100,
                        height: 100,
                        child: Image.asset(
                          'assets/images/right.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // 3. First Action Banner Button ("Food suggestions for next week")
        GestureDetector(
          onTap: widget.onMealSuggestionsTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF19271E) : Colors.white,
              borderRadius: BorderRadius.circular(38),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF81C784) : const Color(0xFF008435),
                width: isDark ? 1.5 : 2.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF233629)
                        : const Color(0xFF008435),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.restaurant_rounded,
                      color: isDark ? const Color(0xFF81C784) : Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isEn
                            ? 'Food suggestions for next week'
                            : 'Gợi ý thực phẩm cho tuần tới',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color:
                              isDark ? Colors.white : const Color(0xFF008435),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isEn
                            ? 'Convenient & nutritious'
                            : 'Tiện lợi và dinh dưỡng',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFF81C784)
                              : const Color(0xFF55A44B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // 4. Second Action Banner Button ("Shopping reminder")
        GestureDetector(
          onTap: widget.onShoppingReminderTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF19271E) : Colors.white,
              borderRadius: BorderRadius.circular(38),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF81C784) : const Color(0xFF008435),
                width: isDark ? 1.5 : 2.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF233629)
                        : const Color(0xFF008435),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.restaurant_rounded,
                      color: isDark ? const Color(0xFF81C784) : Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isEn ? 'Shopping reminder' : 'Nhắc nhở mua sắm',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color:
                              isDark ? Colors.white : const Color(0xFF008435),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isEn
                            ? 'Please check your shopping cart!'
                            : 'Vui lòng kiểm tra giỏ hàng của bạn!',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFF81C784)
                              : const Color(0xFF55A44B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
