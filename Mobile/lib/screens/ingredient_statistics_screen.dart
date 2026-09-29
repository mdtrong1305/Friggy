import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_constants.dart';
import '../l10n/app_localizations.dart';
import '../widgets/friggy_app_bar.dart';
import 'recipe_suggestions_screen.dart';

import '../data/services/api_service.dart';
import '../data/models/fridge_models.dart';

import '../data/models/ingredient_model.dart';

import '../sqlite/services/stats_local_service.dart';
import '../sqlite/services/ingredient_local_service.dart';
import '../sqlite/models/local_stats_model.dart';

class IngredientStatisticsScreen extends StatefulWidget {
  final int initialTabIndex; // 0 for Tuần, 1 for Tháng

  const IngredientStatisticsScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<IngredientStatisticsScreen> createState() =>
      _IngredientStatisticsScreenState();
}

class _IngredientStatisticsScreenState
    extends State<IngredientStatisticsScreen> {
  late int _selectedTab;
  final ApiService _apiService = ApiService();
  final StatsLocalService _statsLocalService = StatsLocalService();
  final IngredientLocalService _ingredientLocalService = IngredientLocalService();
  FridgeStatsModel? _stats;
  FridgeStatsChartModel? _chartData;
  List<IngredientModel> _expiringItems = [];
  List<IngredientModel> _allFridgeItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTabIndex;
    _loadStatsData();
  }

  Future<void> _loadStatsData() async {
    setState(() => _isLoading = true);
    try {
      final period = _selectedTab == 0 ? 'week' : 'month';
      final statsRes = await _apiService.getFridgeStats();
      final chartRes = await _apiService.getFridgeStatsChart(period: period);
      final expiringRes = await _apiService.getExpiringFridgeItems(days: 7);
      final allItemsRes = await _apiService.getFridgeItems();

      final List<IngredientModel> loadedExpiring = expiringRes.map((json) {
        return IngredientModel.fromFridgeApi(json as Map<String, dynamic>);
      }).toList();

      final List<IngredientModel> loadedAll = allItemsRes.map((json) {
        return IngredientModel.fromFridgeApi(json as Map<String, dynamic>);
      }).toList();

      final parsedStats = FridgeStatsModel.fromJson(statsRes);
      final parsedChart = FridgeStatsChartModel.fromJson(chartRes);

      if (mounted) {
        setState(() {
          _stats = parsedStats;
          _chartData = parsedChart;
          _expiringItems = loadedExpiring;
          _allFridgeItems = loadedAll;
          _isLoading = false;
        });
      }

      // Save stats to SQLite
      await _statsLocalService.saveStatsCache(LocalStatsModel(
        totalSpentThisMonth: parsedStats.totalSpentThisMonth,
        wastePercent: parsedStats.wastePercent,
        mealsCooked: parsedStats.mealsCooked,
        expiringSoonCount: parsedStats.expiringSoonCount,
        totalItems: parsedStats.totalItems,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ));
    } catch (e) {
      debugPrint('[IngredientStatisticsScreen] Error/Offline loading stats: $e. Loading from SQLite...');
      try {
        final cachedStats = await _statsLocalService.getCachedStats();
        final cachedIngredients = await _ingredientLocalService.getCachedIngredients();

        final List<IngredientModel> offlineAll = cachedIngredients.map((item) {
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
            daysUntilExpiry: item.daysUntilExpiry ?? 5,
            expiryText: (item.daysUntilExpiry ?? 5) < 0
                ? 'Quá hạn ${(item.daysUntilExpiry ?? 5).abs()} ngày'
                : 'Còn ${item.daysUntilExpiry ?? 5} ngày',
            imagePath: item.imagePath ?? '',
            badgeBgColor: const Color(0xFFE8F5E9),
            badgeTextColor: const Color(0xFF2E7D32),
          );
        }).toList();

        final List<IngredientModel> offlineExpiring = offlineAll.where((e) => e.daysUntilExpiry <= 3).toList();

        if (mounted) {
          setState(() {
            _stats = cachedStats != null
                ? FridgeStatsModel(
                    totalSpentThisMonth: cachedStats.totalSpentThisMonth,
                    wastePercent: cachedStats.wastePercent,
                    mealsCooked: cachedStats.mealsCooked,
                    expiringSoonCount: cachedStats.expiringSoonCount,
                    totalItems: cachedStats.totalItems,
                  )
                : FridgeStatsModel(
                    totalSpentThisMonth: 0,
                    wastePercent: 0.0,
                    mealsCooked: 0,
                    expiringSoonCount: offlineExpiring.length,
                    totalItems: offlineAll.length,
                  );

            _chartData = FridgeStatsChartModel(
              period: _selectedTab == 0 ? 'week' : 'month',
              labels: _selectedTab == 0 ? ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'] : ['Tuần 1', 'Tuần 2', 'Tuần 3', 'Tuần 4'],
              spending: _selectedTab == 0 ? [0, 0, 0, 0, 0, 0, 0] : [0, 0, 0, 0],
              wasteItems: _selectedTab == 0 ? [0, 0, 0, 0, 0, 0, 0] : [0, 0, 0, 0],
            );

            _expiringItems = offlineExpiring;
            _allFridgeItems = offlineAll;
            _isLoading = false;
          });
        }
      } catch (err) {
        debugPrint('[IngredientStatisticsScreen] SQLite offline load error: $err');
        if (mounted) {
          setState(() {
            _stats = FridgeStatsModel(
              totalSpentThisMonth: 0,
              wastePercent: 0.0,
              mealsCooked: 0,
              expiringSoonCount: 0,
              totalItems: 0,
            );
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final isEn = loc?.locale.languageCode == 'en';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0E1611) : const Color(0xFFF4FAF2),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? const [
                    Color(0xFF0E1611),
                    Color(0xFF142017),
                    Color(0xFF1B2E21),
                  ]
                : const [
                    Color(0xFFFFFFFF),
                    Color(0xFFF5FCF4),
                    Color(0xFFC7EFC2),
                    Color(0xFF86D978),
                    Color(0xFF4CB93E),
                  ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: isDark ? const [0.0, 0.5, 1.0] : const [0.0, 0.24, 0.42, 0.72, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 1. Header Bar using reusable FriggyAppBar
              const FriggyAppBar(),

              // 2. Scrollable Body Content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),

                      // Screen Title
                      Text(
                        isEn ? 'Ingredient Statistics' : 'Thống kê nguyên liệu',
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF006428),
                          letterSpacing: -0.3,
                        ),
                      ),

                      const SizedBox(height: 14),

                      // 3. Segmented Control Toggle (Tuần / Tháng)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF19271E) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: isDark
                              ? Border.all(color: const Color(0xFF2E4D36), width: 1)
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedTab = 0;
                                  });
                                  _loadStatsData();
                                },
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _selectedTab == 0
                                        ? const Color(0xFF2E7D32)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      isEn ? 'Week' : 'Tuần',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: _selectedTab == 0
                                            ? Colors.white
                                            : (isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32)),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedTab = 1;
                                  });
                                  _loadStatsData();
                                },
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _selectedTab == 1
                                        ? const Color(0xFF2E7D32)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      isEn ? 'Month' : 'Tháng',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: _selectedTab == 1
                                            ? Colors.white
                                            : (isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32)),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Render body based on selected tab (0 = Tuần, 1 = Tháng)
                      _selectedTab == 0
                          ? _buildWeeklyTabContent(isDark, isEn)
                          : _buildMonthlyTabContent(isDark, isEn),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // WEEKLY TAB CONTENT (TUẦN)
  // ==========================================
  Widget _buildWeeklyTabContent(bool isDark, bool isEn) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Top Card: Đã sử dụng (18 món)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF19271E) : const Color(0xFFEAF5E1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFC8E6C9),
                width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF233629) : const Color(0xFF4CAF50),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.restaurant_rounded,
                  color: isDark ? const Color(0xFF81C784) : Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEn ? 'Meals Cooked' : 'Bữa đã nấu',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isEn ? '${_stats?.mealsCooked ?? 0} meals' : '${_stats?.mealsCooked ?? 0} bữa',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF006428),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Row of 2 Cards: Bị bỏ phí (2 món) & Lãng phí (% / đ)
        Row(
          children: [
            // Left Card: Bị bỏ phí
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2D1C1C) : const Color(0xFFFEEBEE),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isDark ? const Color(0xFF5C2525) : const Color(0xFFFFCDD2),
                      width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF5350),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isEn ? 'Expiring soon' : 'Sắp hết hạn',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFFF8A80) : const Color(0xFFD32F2F),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEn ? '${_stats?.expiringSoonCount ?? 0} items' : '${_stats?.expiringSoonCount ?? 0} món',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: isDark ? const Color(0xFFFF8A80) : const Color(0xFFB71C1C),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Right Card: Lãng phí (% / VND)
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2D281C) : const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isDark ? const Color(0xFF5C4E25) : const Color(0xFFFFE082),
                      width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFB74D),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.savings_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isEn ? 'Wasted' : 'Lãng phí',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFFFD54F) : const Color(0xFFE65100),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_stats?.wastePercent ?? 0}%',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: isDark ? const Color(0xFFFFD54F) : const Color(0xFFBF360C),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        // 2. Insight từ Friggy Card (Dark Green Box)
        _buildFriggyInsightCard(isDark, isEn),

        const SizedBox(height: 22),

        // 3. Section: Được sử dụng nhiều (Top 4)
        _buildTopUsedSection(isDark, isEn),

        const SizedBox(height: 22),

        // 4. Section: Bị bỏ quên nhiều (Cần chú ý)
        _buildNeglectedSection(isDark, isEn),
      ],
    );
  }

  // ==========================================
  String _formatVnd(int amount) {
    final str = amount.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return '${buffer.toString()}đ';
  }

  // MONTHLY TAB CONTENT (THÁNG)
  // ==========================================
  Widget _buildMonthlyTabContent(bool isDark, bool isEn) {
    final now = DateTime.now();
    final monthTitle = isEn
        ? 'Month ${now.month}, ${now.year}'
        : 'Tháng ${now.month}, ${now.year}';
    final totalSpentFormatted = _formatVnd(_stats?.totalSpentThisMonth ?? 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Monthly Usage Trend Bar Chart Card (Xu hướng dùng)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF19271E) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: isDark
                ? Border.all(color: const Color(0xFF2E4D36), width: 1)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Month title & Trending Percentage Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        monthTitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isEn ? 'Usage Trend' : 'Xu hướng dùng',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF006428),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.trending_up_rounded,
                        color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_stats?.wastePercent ?? 0}%',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Dynamic Bar Chart Representation from _chartData
              _buildMonthlyChart(isDark, isEn),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 2. Grid of 2 Cards: Đã sử dụng & Lãng phí
        Row(
          children: [
            // Left Card: Đã sử dụng
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF19271E) : const Color(0xFFEAF5E1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFC8E6C9),
                      width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF233629) : Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.restaurant_rounded,
                        color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isEn ? 'Meals Cooked' : 'Bữa đã nấu',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEn ? '${_stats?.mealsCooked ?? 0} meals' : '${_stats?.mealsCooked ?? 0} bữa',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF006428),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Right Card: Lãng phí
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2D1C1C) : const Color(0xFFFEEBEE),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isDark ? const Color(0xFF5C2525) : const Color(0xFFFFCDD2),
                      width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF381F1F) : Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: isDark ? const Color(0xFFFF8A80) : const Color(0xFFD32F2F),
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isEn ? 'Expiring soon' : 'Sắp hết hạn',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFFF8A80) : const Color(0xFFD32F2F),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEn ? '${_stats?.expiringSoonCount ?? 0} items' : '${_stats?.expiringSoonCount ?? 0} món',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: isDark ? const Color(0xFFFF8A80) : const Color(0xFFB71C1C),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 3. Savings / Monthly Expense Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF19271E) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: isDark
                ? Border.all(color: const Color(0xFF2E4D36), width: 1)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn ? 'Total monthly food spending' : 'Tổng chi tiêu mua sắm tháng này',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      totalSpentFormatted,
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: isDark ? const Color(0xFFFFD54F) : const Color(0xFF4A3800),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isEn ? 'ⓘ Based on purchased shopping items' : 'ⓘ Dựa trên sản phẩm đã mua từ danh sách',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF9DA8A0) : const Color(0xFF888888),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF382E1C) : const Color(0xFFFFF59D),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.savings_rounded,
                  color: Color(0xFFF57F17),
                  size: 34,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),

        // 4. Section: So với tháng trước
        Text(
          isEn ? 'Compared to last month' : 'So với tháng trước',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF006428),
          ),
        ),

        const SizedBox(height: 14),

        // Card 1: Chỉ số "Sống Xanh"
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF19271E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: isDark
                ? Border.all(color: const Color(0xFF2E4D36), width: 1)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF233629) : const Color(0xFFE8EAF6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.eco_rounded,
                  color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn ? '"Eco Living" Score' : 'Chỉ số "Sống Xanh"',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF006428),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: 0.75,
                        minHeight: 8,
                        backgroundColor: isDark ? const Color(0xFF233629) : const Color(0xFFE8F5E9),
                        valueColor: AlwaysStoppedAnimation<Color>(
                            isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Text(
                '+15%',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Card 2: Tần suất mua sắm
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF19271E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: isDark
                ? Border.all(color: const Color(0xFF2E4D36), width: 1)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF382E1C) : const Color(0xFFEFEBE9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.shopping_bag_outlined,
                  color: isDark ? const Color(0xFFFFB74D) : const Color(0xFF8D6E63),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn ? 'Shopping Frequency' : 'Tần suất mua sắm',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF006428),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: 0.4,
                        minHeight: 8,
                        backgroundColor: isDark ? const Color(0xFF233629) : const Color(0xFFE8F5E9),
                        valueColor: AlwaysStoppedAnimation<Color>(
                            isDark ? const Color(0xFFFFB74D) : const Color(0xFF8D6E63)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Text(
                '-8%',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isDark ? const Color(0xFFFFB74D) : const Color(0xFF8D6E63),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),

        // 5. Insight từ Friggy Card (Dark Green Box)
        _buildFriggyInsightCard(isDark, isEn),

        const SizedBox(height: 22),

        // 6. Section: Được sử dụng nhiều (Top 4)
        _buildTopUsedSection(isDark, isEn),

        const SizedBox(height: 22),

        // 7. Section: Bị bỏ quên nhiều (Cần chú ý)
        _buildNeglectedSection(isDark, isEn),
      ],
    );
  }

  Widget _buildMonthlyChart(bool isDark, bool isEn) {
    final labelsList = _chartData?.labels ?? [];
    final spendingList = _chartData?.spending ?? [];

    if (labelsList.isEmpty) {
      // Fallback bars if API returns empty chart data
      return SizedBox(
        height: 165,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildBarItem(isEn ? 'Jul' : 'T.7', 0.52, isSelected: false, isDark: isDark),
            _buildBarItem(isEn ? 'Aug' : 'T.8', 0.70, isSelected: false, isDark: isDark),
            _buildBarItem(isEn ? 'Sep' : 'T.9', 0.62, isSelected: false, isDark: isDark),
            _buildBarItem(isEn ? 'Oct' : 'T.10', 0.95, isSelected: true, tooltip: '0đ', isDark: isDark),
          ],
        ),
      );
    }

    final maxVal = spendingList.fold<double>(0.0, (m, e) => e > m ? e : m);

    // Pick last 5-7 labels/items for optimal display
    final totalCount = labelsList.length;
    final displayIndices = totalCount > 6
        ? List.generate(6, (i) => totalCount - 6 + i)
        : List.generate(totalCount, (i) => i);

    return SizedBox(
      height: 165,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: displayIndices.map((idx) {
          final label = labelsList[idx];
          final val = idx < spendingList.length ? spendingList[idx] : 0.0;
          final factor = maxVal > 0 ? (val / maxVal).clamp(0.2, 0.95) : 0.2;
          final isSelected = idx == displayIndices.last;
          final tooltip = val > 0 ? '${(val / 1000).toStringAsFixed(0)}k' : null;

          return _buildBarItem(
            label,
            factor,
            isSelected: isSelected,
            tooltip: tooltip,
            isDark: isDark,
          );
        }).toList(),
      ),
    );
  }

  // Bar Item Widget for Usage Trend Chart
  Widget _buildBarItem(String label, double heightFactor,
      {required bool isSelected, String? tooltip, bool isDark = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (tooltip != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              tooltip,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: isDark ? const Color(0xFF19271E) : Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 6),
        ] else ...[
          const SizedBox(height: 27),
        ],
        Container(
          width: 54,
          height: 100 * heightFactor,
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32))
                : (isDark ? const Color(0xFF233629) : const Color(0xFFDCEDC8)),
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: (isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32))
                          .withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
            color: isSelected
                ? (isDark ? const Color(0xFF81C784) : const Color(0xFF006428))
                : (isDark ? const Color(0xFF9DA8A0) : const Color(0xFF666666)),
          ),
        ),
      ],
    );
  }

  // Insight từ Friggy Box (High-contrast, crisp readable styling)
  Widget _buildFriggyInsightCard(bool isDark, bool isEn) {
    final String item1 = _expiringItems.isNotEmpty ? _expiringItems[0].displayName(isEn) : '';
    final String item2 = _expiringItems.length > 1 ? _expiringItems[1].displayName(isEn) : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF19271E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFA5E69C),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Smart Robot Icon Badge + "Insight từ Friggy" Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF233629) : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.smart_toy_rounded,
                  color: isDark ? const Color(0xFF81C784) : const Color(0xFF008435),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                isEn ? 'Friggy Insights' : 'Insight từ Friggy',
                style: GoogleFonts.outfit(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF006428),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Body Text with High-Contrast Dark Text & Highlighted Green Words
          RichText(
            text: TextSpan(
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15.0,
                color: isDark ? const Color(0xFFD0D7D1) : const Color(0xFF2C3E35),
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
              children: item1.isNotEmpty
                  ? (isEn
                      ? [
                          TextSpan(
                            text: 'Friggy gentle reminder!\nThis week ',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF19221C),
                            ),
                          ),
                          TextSpan(
                            text: item1,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: isDark ? const Color(0xFF81C784) : const Color(0xFF008435),
                            ),
                          ),
                          if (item2.isNotEmpty) ...[
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: item2,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: isDark ? const Color(0xFF81C784) : const Color(0xFF008435),
                              ),
                            ),
                          ],
                          const TextSpan(text: ' need attention soon 👀\nLet\'s '),
                          TextSpan(
                            text: 'cook them with diverse recipes',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: isDark ? const Color(0xFF81C784) : const Color(0xFF006428),
                            ),
                          ),
                          const TextSpan(text: ' for next week!'),
                        ]
                      : [
                          TextSpan(
                            text: 'Friggy nhắc nhẹ nè!\nTuần này ',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF19221C),
                            ),
                          ),
                          TextSpan(
                            text: item1,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: isDark ? const Color(0xFF81C784) : const Color(0xFF008435),
                            ),
                          ),
                          if (item2.isNotEmpty) ...[
                            const TextSpan(text: ' và '),
                            TextSpan(
                              text: item2,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: isDark ? const Color(0xFF81C784) : const Color(0xFF008435),
                              ),
                            ),
                          ],
                          const TextSpan(text: ' cần chú ý dùng sớm nhé 👀\nCùng '),
                          TextSpan(
                            text: 'chế biến món ngon để tránh lãng phí',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: isDark ? const Color(0xFF81C784) : const Color(0xFF006428),
                            ),
                          ),
                          const TextSpan(text: ' cho tuần tới nhé!'),
                        ])
                  : (isEn
                      ? [
                          TextSpan(
                            text: 'Friggy status report!\nYour fridge is in ',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF19221C),
                            ),
                          ),
                          TextSpan(
                            text: 'great shape',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: isDark ? const Color(0xFF81C784) : const Color(0xFF008435),
                            ),
                          ),
                          const TextSpan(text: '! 🎉\nNo items are neglected. Let\'s '),
                          TextSpan(
                            text: 'keep maintaining a balanced diet',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: isDark ? const Color(0xFF81C784) : const Color(0xFF006428),
                            ),
                          ),
                          const TextSpan(text: ' for your family!'),
                        ]
                      : [
                          TextSpan(
                            text: 'Friggy báo cáo nè!\nTủ lạnh của bạn đang trong trạng thái ',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF19221C),
                            ),
                          ),
                          TextSpan(
                            text: 'tuyệt vời',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: isDark ? const Color(0xFF81C784) : const Color(0xFF008435),
                            ),
                          ),
                          const TextSpan(text: '! 🎉\nKhông có nguyên liệu nào bị bỏ quên. Cùng '),
                          TextSpan(
                            text: 'duy trì thực đơn phong phú và tiết kiệm',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: isDark ? const Color(0xFF81C784) : const Color(0xFF008435),
                            ),
                          ),
                          const TextSpan(text: ' nhé!'),
                        ]),
            ),
          ),

          const SizedBox(height: 18),

          // Action Button: Solid Green Button with Crisp White Text
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RecipeSuggestionsScreen(),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: const Color(0xFF008435),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF008435).withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isEn ? 'Explore now!' : 'Cùng khám phá nhé!',
                    style: GoogleFonts.outfit(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Top Used Section
  Widget _buildTopUsedSection(bool isDark, bool isEn) {
    final displayItems = _allFridgeItems.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isEn ? 'Most Used' : 'Được sử dụng nhiều',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF006428),
              ),
            ),
            if (displayItems.isNotEmpty)
              Text(
                'Top ${displayItems.length}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF19271E) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: isDark
                ? Border.all(color: const Color(0xFF2E4D36), width: 1)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: displayItems.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      isEn
                          ? 'No ingredient usage data available yet'
                          : 'Chưa có dữ liệu nguyên liệu trong tủ lạnh',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF9DA8A0) : const Color(0xFF666666),
                      ),
                    ),
                  ),
                )
              : Column(
                  children: List.generate(displayItems.length, (index) {
                    final item = displayItems[index];
                    final progress = (0.9 - (index * 0.15)).clamp(0.2, 1.0);
                    return Padding(
                      padding: EdgeInsets.only(bottom: index == displayItems.length - 1 ? 0 : 14.0),
                      child: _buildUsageProgressItem(
                        item.displayName(isEn),
                        item.quantity,
                        progress,
                        isDark,
                      ),
                    );
                  }),
                ),
        ),
      ],
    );
  }

  // Neglected Section
  Widget _buildNeglectedSection(bool isDark, bool isEn) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isEn ? 'Most Neglected' : 'Bị bỏ quên nhiều',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF006428),
              ),
            ),
            Text(
              isEn ? 'Needs Attention' : 'Cần chú ý',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFFF8A80) : const Color(0xFFD32F2F),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_expiringItems.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF19271E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: isDark
                  ? Border.all(color: const Color(0xFF2E4D36), width: 1)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF233629) : const Color(0xFFE8F5E9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_outline_rounded,
                    color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEn ? 'No Neglected Items' : 'Không có nguyên liệu bị bỏ quên',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF19221C),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isEn
                            ? 'All ingredients in your fridge are fresh!'
                            : 'Tất cả thực phẩm trong tủ của bạn đều còn hạn dùng tốt.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF9DA8A0) : const Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: List.generate(_expiringItems.length, (index) {
              final item = _expiringItems[index];
              final isExpired = item.daysUntilExpiry < 0;
              final isExpiringSoon = item.daysUntilExpiry <= 2;

              final tagText = isExpired
                  ? (isEn ? 'Expired' : 'Đã quá hạn')
                  : isExpiringSoon
                      ? (isEn ? 'Expiring soon' : 'Sắp hỏng')
                      : (isEn ? 'Neglected' : 'Bỏ quên');

              final tagBgColor = isExpired
                  ? (isDark ? const Color(0xFF381F1F) : const Color(0xFFFFCDD2))
                  : isExpiringSoon
                      ? (isDark ? const Color(0xFF2D1C1C) : const Color(0xFFFFEBEE))
                      : (isDark ? const Color(0xFF382E1C) : const Color(0xFFFFF8E1));

              final tagTextColor = isExpired
                  ? (isDark ? const Color(0xFFFF8A80) : const Color(0xFFB71C1C))
                  : isExpiringSoon
                      ? (isDark ? const Color(0xFFFF8A80) : const Color(0xFFD32F2F))
                      : (isDark ? const Color(0xFFFFB74D) : const Color(0xFFE65100));

              final subtitle = item.expiryStatusText(isEn);

              return Padding(
                padding: EdgeInsets.only(bottom: index == _expiringItems.length - 1 ? 0 : 12.0),
                child: _buildNeglectedCard(
                  name: item.displayName(isEn),
                  subtitle: subtitle,
                  tagText: tagText,
                  tagBgColor: tagBgColor,
                  tagTextColor: tagTextColor,
                  imagePath: item.imagePath,
                  fallbackIcon: Icons.restaurant_rounded,
                  isDark: isDark,
                ),
              );
            }),
          ),
      ],
    );
  }

  // Progress Bar Item Helper
  Widget _buildUsageProgressItem(
      String title, String countText, double progress, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF006428),
              ),
            ),
            Text(
              countText,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: isDark ? const Color(0xFF233629) : const Color(0xFFF1F8E9),
            valueColor: AlwaysStoppedAnimation<Color>(
                isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32)),
          ),
        ),
      ],
    );
  }

  // Neglected Card Helper
  Widget _buildNeglectedCard({
    required String name,
    required String subtitle,
    required String tagText,
    required Color tagBgColor,
    required Color tagTextColor,
    required String imagePath,
    required IconData fallbackIcon,
    required bool isDark,
  }) {
    final fullImageUrl = AppConstants.getImageUrl(imagePath);

    Widget imageWidget;
    if (fullImageUrl != null) {
      imageWidget = Image.network(
        fullImageUrl,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _buildFallbackIcon(fallbackIcon, isDark),
      );
    } else if (imagePath.startsWith('assets/')) {
      imageWidget = Image.asset(
        imagePath,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _buildFallbackIcon(fallbackIcon, isDark),
      );
    } else {
      imageWidget = _buildFallbackIcon(fallbackIcon, isDark);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF19271E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isDark
            ? Border.all(color: const Color(0xFF2E4D36), width: 1)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: imageWidget,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF19221C),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF9DA8A0) : const Color(0xFF666666),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: tagBgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              tagText,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: tagTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackIcon(IconData fallbackIcon, bool isDark) {
    return Container(
      width: 48,
      height: 48,
      color: isDark ? const Color(0xFF233629) : const Color(0xFFF1F8E9),
      child: Icon(
        fallbackIcon,
        color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
        size: 24,
      ),
    );
  }
}
