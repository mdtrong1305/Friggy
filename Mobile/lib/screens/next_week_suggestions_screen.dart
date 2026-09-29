import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/models/recipe_model.dart';
import '../data/services/api_exception.dart';
import '../data/services/api_service.dart';
import '../l10n/app_localizations.dart';
import '../widgets/friggy_app_bar.dart';
import 'recipe_detail_screen.dart';
import 'package_management_screen.dart';
import 'shopping_reminder_screen.dart';
import '../sqlite/services/weekly_plan_local_service.dart';
import '../sqlite/models/local_weekly_plan_model.dart';
import 'dart:convert';

class NextWeekSuggestionsScreen extends StatefulWidget {
  const NextWeekSuggestionsScreen({super.key});

  @override
  State<NextWeekSuggestionsScreen> createState() => _NextWeekSuggestionsScreenState();
}

class _NextWeekSuggestionsScreenState extends State<NextWeekSuggestionsScreen> {
  bool _isLoading = true;
  bool _isGenerating = false;
  String _loadingMessage = '🤖 Đang kết nối lấy thực đơn tuần...';

  Map<int, Map<String, dynamic>> _dailyPlansMap = {};
  String? _weeklyPlanId;
  int _selectedDayOfWeek = 1;
  String? _regeneratingSlotId;
  bool _hasShoppingList = false;
  final ScrollController _dayTabScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedDayOfWeek = DateTime.now().weekday;
    _fetchWeeklyPlan();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedDayTab();
    });
  }

  @override
  void dispose() {
    _dayTabScrollController.dispose();
    super.dispose();
  }

  void _scrollToSelectedDayTab() {
    if (_dayTabScrollController.hasClients && _selectedDayOfWeek > 1) {
      final offset = (_selectedDayOfWeek - 1) * 85.0;
      _dayTabScrollController.animateTo(
        offset.clamp(0.0, _dayTabScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _checkExistingShoppingList() async {
    try {
      final lists = await ApiService().getShoppingLists();
      bool exists = false;
      if (lists.isNotEmpty) {
        if (_weeklyPlanId != null) {
          exists = lists.any((item) => (item as Map)['weeklyPlanId']?.toString() == _weeklyPlanId);
        }
        if (!exists) {
          exists = lists.isNotEmpty;
        }
      }
      if (mounted) {
        setState(() {
          _hasShoppingList = exists;
        });
      }
    } catch (e) {
      debugPrint('[NextWeekSuggestionsScreen] Error checking shopping lists: $e');
    }
  }

  Future<void> _toggleMealSlotCompleted(String slotId, bool currentlyCompleted) async {
    if (slotId.isEmpty || slotId.startsWith('rec_')) return;
    try {
      await ApiService().updateMealSlot(
        slotId: slotId,
        completed: !currentlyCompleted,
      );
      if (_weeklyPlanId != null) {
        final detail = await ApiService().getMealPlanDetail(_weeklyPlanId!);
        final list = (detail['dailyPlans'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [];

        final Map<int, Map<String, dynamic>> mapByDay = {};
        for (final item in list) {
          final rawDay = item['dayOfWeek'];
          final dOfWeek = rawDay is int
              ? rawDay
              : (int.tryParse(rawDay?.toString() ?? '') ?? 1);
          mapByDay[dOfWeek] = item;
        }

        if (mounted) {
          setState(() {
            _dailyPlansMap = mapByDay;
          });
        }
      }
    } catch (e) {
      debugPrint('[NextWeekSuggestionsScreen] Error toggling completed: $e');
    }
  }

  Future<void> _regenerateMealSlot(String slotId, String currentRecipeId) async {
    if (slotId.isEmpty || slotId.startsWith('rec_')) return;
    if (_regeneratingSlotId != null) return;

    setState(() {
      _regeneratingSlotId = slotId;
    });

    try {
      // 1. Call POST /slots/:id/regenerate (Trigger AI job)
      await ApiService().regenerateSlot(slotId: slotId);

      // 2. Fetch recipes from backend to update MealSlot via PATCH /slots/:id
      final recipes = await ApiService().getRecipes();
      if (recipes.isNotEmpty) {
        final alternative = recipes.firstWhere(
          (r) => (r as Map)['id']?.toString() != currentRecipeId,
          orElse: () => recipes.first,
        );
        final newRecipeId = (alternative as Map)['id']?.toString();
        if (newRecipeId != null) {
          await ApiService().updateMealSlot(
            slotId: slotId,
            recipeId: newRecipeId,
          );
        }
      }

      // 3. Reload plan detail to refresh UI with updated DB record
      if (_weeklyPlanId != null) {
        final detail = await ApiService().getMealPlanDetail(_weeklyPlanId!);
        final list = (detail['dailyPlans'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [];

        final Map<int, Map<String, dynamic>> mapByDay = {};
        for (final item in list) {
          final rawDay = item['dayOfWeek'];
          final dOfWeek = rawDay is int
              ? rawDay
              : (int.tryParse(rawDay?.toString() ?? '') ?? 1);
          mapByDay[dOfWeek] = item;
        }

        if (mounted) {
          setState(() {
            _dailyPlansMap = mapByDay;
            _regeneratingSlotId = null;
          });
        }
      }
    } catch (e) {
      debugPrint('[NextWeekSuggestionsScreen] Error regenerating slot: $e');
      if (mounted) {
        final isEn = AppLocalizations.of(context)?.locale.languageCode == 'en';
        String errorMessage = isEn
            ? 'Failed to swap dish. Please try again.'
            : 'Đổi món thất bại. Vui lòng thử lại.';
        if (e is ApiException) {
          errorMessage = e.message;
        } else if (e.toString().contains('dùng hết')) {
          errorMessage = e.toString().replaceAll('Exception: ', '');
        }
        setState(() {
          _regeneratingSlotId = null;
        });
        final isLimitError = errorMessage.contains('dùng hết') || errorMessage.contains('lượt AI');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.stars_rounded, color: Color(0xFFFFD54F), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    errorMessage,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF006428),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.all(16),
            action: isLimitError
                ? SnackBarAction(
                    label: isEn ? 'Upgrade' : 'Nâng cấp',
                    textColor: const Color(0xFFFFD54F),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PackageManagementScreen(),
                        ),
                      );
                    },
                  )
                : null,
          ),
        );
      }
    }
  }

  Future<void> _fetchWeeklyPlan() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadingMessage = '🤖 Đang tải thực đơn tuần từ hệ thống...';
    });

    final weeklyPlanLocalService = WeeklyPlanLocalService();
    try {
      final plans = await ApiService().getMealPlans();
      if (plans.isNotEmpty) {
        plans.sort((a, b) {
          final dateA = DateTime.tryParse((a as Map)['createdAt']?.toString() ?? '') ?? DateTime(1970);
          final dateB = DateTime.tryParse((b as Map)['createdAt']?.toString() ?? '') ?? DateTime(1970);
          return dateB.compareTo(dateA);
        });

        final firstPlan = plans.first as Map<String, dynamic>;
        if (firstPlan['id'] != null) {
          final planId = firstPlan['id'].toString();
          _weeklyPlanId = planId;
          final detail = await ApiService().getMealPlanDetail(planId);
          final list = (detail['dailyPlans'] as List<dynamic>?)
                  ?.map((e) => Map<String, dynamic>.from(e as Map))
                  .toList() ??
              [];

          // Save / Overwrite SQLite cache
          await weeklyPlanLocalService.saveWeeklyPlanOverwrite(
            LocalWeeklyPlanModel(
              id: planId,
              weekStartDate: detail['weekStartDate']?.toString() ?? '',
              daysDataJson: jsonEncode(list),
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );

          final Map<int, Map<String, dynamic>> mapByDay = {};
          for (final item in list) {
            final rawDay = item['dayOfWeek'];
            final dOfWeek = rawDay is int
                ? rawDay
                : (int.tryParse(rawDay?.toString() ?? '') ?? 1);
            mapByDay[dOfWeek] = item;
          }

          if (mounted) {
            setState(() {
              _dailyPlansMap = mapByDay;
              _isLoading = false;
            });
            _checkExistingShoppingList();
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('[NextWeekSuggestionsScreen] Error/Offline fetching weekly plan: $e. Loading from SQLite...');
      try {
        final cachedPlan = await weeklyPlanLocalService.getCachedWeeklyPlan();
        if (cachedPlan != null) {
          final list = cachedPlan.decodedDaysData;
          final Map<int, Map<String, dynamic>> mapByDay = {};
          for (final item in list) {
            if (item is Map) {
              final dayMap = Map<String, dynamic>.from(item);
              final rawDay = dayMap['dayOfWeek'];
              final dOfWeek = rawDay is int
                  ? rawDay
                  : (int.tryParse(rawDay?.toString() ?? '') ?? 1);
              mapByDay[dOfWeek] = dayMap;
            }
          }

          if (mapByDay.isNotEmpty && mounted) {
            setState(() {
              _weeklyPlanId = cachedPlan.id;
              _dailyPlansMap = mapByDay;
              _isLoading = false;
            });
            return;
          }
        }
      } catch (err) {
        debugPrint('[NextWeekSuggestionsScreen] SQLite read error: $err');
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      _generateWeeklyPlanWithAi();
    }
  }

  Future<void> _generateWeeklyPlanWithAi() async {
    if (_isGenerating) return;
    final weeklyPlanLocalService = WeeklyPlanLocalService();

    setState(() {
      _isGenerating = true;
      _loadingMessage = '🤖 AI Friggy đang quét tủ lạnh & khởi tạo thực đơn tuần...';
    });

    try {
      final Set<String> initialSlotIds = {};
      for (final d in _dailyPlansMap.values) {
        final slots = (d['mealSlots'] as List<dynamic>?) ?? [];
        for (final s in slots) {
          final sId = (s as Map)['id']?.toString();
          if (sId != null) initialSlotIds.add(sId);
        }
      }

      setState(() {
        _loadingMessage = '🧠 AI đang tính toán thực đơn 7 ngày đủ chất & tiết kiệm...';
      });

      // Calculate Monday YYYY-MM-DD
      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final mondayStr = monday.toIso8601String().split('T')[0];

      final res = await ApiService().generateWeeklyPlan(
        weekStartDate: mondayStr,
        budget: 500000,
      );
      final jobId = res['jobId'] as String?;
      debugPrint('[NextWeekSuggestionsScreen] Triggered generateWeeklyPlan jobId: $jobId');

      const int maxAttempts = 25; // max ~87.5s

      for (int i = 0; i < maxAttempts; i++) {
        await Future.delayed(const Duration(milliseconds: 3500));

        if (i == 2) {
          setState(() => _loadingMessage = '🍲 AI đang chọn món ăn cho cả tuần (Thứ 2 - Chủ Nhật)...');
        } else if (i == 6) {
          setState(() => _loadingMessage = '🍳 AI đang phân bổ bữa sáng, trưa, tối hợp lý...');
        } else if (i == 12) {
          setState(() => _loadingMessage = '💾 AI đang lưu thực đơn tuần vào cơ sở dữ liệu...');
        }

        try {
          final currentPlans = await ApiService().getMealPlans();
          if (currentPlans.isNotEmpty) {
            currentPlans.sort((a, b) {
              final dateA = DateTime.tryParse((a as Map)['createdAt']?.toString() ?? '') ?? DateTime(1970);
              final dateB = DateTime.tryParse((b as Map)['createdAt']?.toString() ?? '') ?? DateTime(1970);
              return dateB.compareTo(dateA);
            });
            final latestPlanId = currentPlans.first['id']?.toString();
            if (latestPlanId != null) {
              _weeklyPlanId = latestPlanId;
              final detail = await ApiService().getMealPlanDetail(latestPlanId);
              final dailyList = (detail['dailyPlans'] as List<dynamic>?)
                      ?.map((e) => Map<String, dynamic>.from(e as Map))
                      .toList() ??
                  [];

              final Set<String> currentSlotIds = {};
              final Map<int, Map<String, dynamic>> mapByDay = {};

              for (final d in dailyList) {
                final rawDay = d['dayOfWeek'];
                final dOfWeek = rawDay is int
                    ? rawDay
                    : (int.tryParse(rawDay?.toString() ?? '') ?? 1);
                mapByDay[dOfWeek] = d;

                final slots = (d['mealSlots'] as List<dynamic>?) ?? [];
                for (final s in slots) {
                  final sId = (s as Map)['id']?.toString();
                  if (sId != null) currentSlotIds.add(sId);
                }
              }

              bool hasNewSlots = false;
              if (initialSlotIds.isEmpty && currentSlotIds.isNotEmpty) {
                hasNewSlots = true;
              } else if (initialSlotIds.isNotEmpty && currentSlotIds.isNotEmpty) {
                for (final sId in currentSlotIds) {
                  if (!initialSlotIds.contains(sId)) {
                    hasNewSlots = true;
                    break;
                  }
                }
              }

              if (hasNewSlots || mapByDay.isNotEmpty) {
                await weeklyPlanLocalService.saveWeeklyPlanOverwrite(
                  LocalWeeklyPlanModel(
                    id: latestPlanId,
                    weekStartDate: detail['weekStartDate']?.toString() ?? '',
                    daysDataJson: jsonEncode(dailyList),
                    updatedAt: DateTime.now().millisecondsSinceEpoch,
                  ),
                );

                if (mounted) {
                  setState(() {
                    _weeklyPlanId = latestPlanId;
                    _dailyPlansMap = mapByDay;
                  });
                }
                break;
              }
            }
          }
        } catch (e) {
          debugPrint('[NextWeekSuggestionsScreen] Polling attempt $i error: $e');
        }
      }

      if (mounted) {
        setState(() {
          _isGenerating = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('🎉 AI đã lập thực đơn 7 ngày thành công!'),
            backgroundColor: const Color(0xFF008435),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
        _checkExistingShoppingList();
      }
    } catch (e) {
      debugPrint('[NextWeekSuggestionsScreen] Error generating plan: $e');
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi kết nối AI: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleShoppingListAction() async {
    if (_hasShoppingList) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ShoppingReminderScreen(),
        ),
      );
      _checkExistingShoppingList();
      return;
    }

    if (_weeklyPlanId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chờ AI tạo thực đơn xong trước khi lập danh sách mua sắm!'),
        ),
      );
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🛒 Đang tổng hợp nguyên liệu cần mua từ thực đơn...'),
          duration: Duration(seconds: 2),
        ),
      );

      await ApiService().createShoppingList(
        weeklyPlanId: _weeklyPlanId!,
        title: 'Danh sách mua sắm tuần này',
      );

      if (mounted) {
        setState(() {
          _hasShoppingList = true;
        });
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ShoppingReminderScreen(),
          ),
        );
        _checkExistingShoppingList();
      }
    } catch (e) {
      debugPrint('[NextWeekSuggestionsScreen] Error creating shopping list: $e');
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ShoppingReminderScreen(),
          ),
        );
        _checkExistingShoppingList();
      }
    }
  }

  String _getDayName(int dayOfWeek, bool isEn) {
    switch (dayOfWeek) {
      case 1:
        return isEn ? 'Mon' : 'Thứ 2';
      case 2:
        return isEn ? 'Tue' : 'Thứ 3';
      case 3:
        return isEn ? 'Wed' : 'Thứ 4';
      case 4:
        return isEn ? 'Thu' : 'Thứ 5';
      case 5:
        return isEn ? 'Fri' : 'Thứ 6';
      case 6:
        return isEn ? 'Sat' : 'Thứ 7';
      case 7:
        return isEn ? 'Sun' : 'Chủ Nhật';
      default:
        return isEn ? 'Day $dayOfWeek' : 'Thứ $dayOfWeek';
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
              const FriggyAppBar(),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),

                      // Title & Generate Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              isEn ? 'Suggestions for Next Week' : 'Gợi ý cho tuần tới',
                              style: GoogleFonts.outfit(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : const Color(0xFF006428),
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _isGenerating ? null : _generateWeeklyPlanWithAi,
                            icon: const Icon(Icons.auto_awesome, size: 16),
                            label: Text(
                              _isGenerating
                                  ? (isEn ? 'Creating...' : 'Đang tạo...')
                                  : (isEn ? 'AI Plan' : 'AI Lập tuần'),
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF008435),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      if (_isGenerating || _isLoading)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF19271E) : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              const CircularProgressIndicator(color: Color(0xFF008435)),
                              const SizedBox(height: 16),
                              Text(
                                _loadingMessage,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF006428),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // 1. General Overview Card
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF233629) : const Color(0xFF2E7D32),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.auto_awesome_rounded,
                                    color: isDark ? const Color(0xFF81C784) : Colors.white,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  isEn ? 'AI Meal Assistant' : 'Trợ lý thực đơn AI',
                                  style: GoogleFonts.outfit(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : const Color(0xFF006428),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      RichText(
                                        text: TextSpan(
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14.5,
                                            color: isDark ? const Color(0xFF9DA8A0) : const Color(0xFF4A6B53),
                                            fontWeight: FontWeight.w600,
                                            height: 1.45,
                                          ),
                                          children: isEn
                                              ? [
                                                  const TextSpan(text: 'AI Friggy automatically crafts smart meal plans based on your '),
                                                  TextSpan(
                                                    text: 'fridge ingredients',
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w900,
                                                      color: isDark ? const Color(0xFF81C784) : const Color(0xFF006428),
                                                    ),
                                                  ),
                                                  const TextSpan(text: ' and '),
                                                  TextSpan(
                                                    text: 'nutritional balance',
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w900,
                                                      color: isDark ? const Color(0xFF81C784) : const Color(0xFF006428),
                                                    ),
                                                  ),
                                                  const TextSpan(text: ' for the entire week.'),
                                                ]
                                              : [
                                                  const TextSpan(text: 'AI Friggy tự động tổng hợp thực đơn thông minh dựa trên '),
                                                  TextSpan(
                                                    text: 'nguyên liệu trong tủ lạnh',
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w900,
                                                      color: isDark ? const Color(0xFF81C784) : const Color(0xFF006428),
                                                    ),
                                                  ),
                                                  const TextSpan(text: ' và nhu cầu '),
                                                  TextSpan(
                                                    text: 'dinh dưỡng tối ưu',
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w900,
                                                      color: isDark ? const Color(0xFF81C784) : const Color(0xFF006428),
                                                    ),
                                                  ),
                                                  const TextSpan(text: ' cho cả tuần.'),
                                                ],
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      Container(
                                        height: 1,
                                        color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFC8E6C9),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.tips_and_updates_rounded,
                                            color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              isEn
                                                  ? 'Explore recipes, replace dishes with AI, or mark cooked meals below!'
                                                  : 'Xem công thức, đổi món AI hoặc đánh dấu đã nấu từng bữa ăn bên dưới nhé!',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w800,
                                                color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
                                                height: 1.3,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Transform.translate(
                                  offset: const Offset(8, -12),
                                  child: Transform.scale(
                                    scale: 1.25,
                                    alignment: Alignment.centerRight,
                                    child: Image.asset(
                                      'assets/images/suggest.png',
                                      width: 130,
                                      height: 160,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          width: 130,
                                          height: 160,
                                          color: isDark ? const Color(0xFF233629) : const Color(0xFFE8F5E9),
                                          child: Icon(
                                            Icons.smart_toy_rounded,
                                            size: 70,
                                            color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),

                      // 2. Shopping Button Banner
                      InkWell(
                        onTap: _handleShoppingListAction,
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF19271E) : Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF233629) : const Color(0xFF2E7D32),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.shopping_cart_checkout_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _hasShoppingList
                                          ? (isEn ? 'View Meal Shopping List' : 'Xem danh sách thực đơn cần mua')
                                          : (isEn ? 'Create Shopping List from Plan' : 'Tạo danh sách mua sắm từ thực đơn'),
                                      style: GoogleFonts.outfit(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w900,
                                        color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
                                      ),
                                    ),
                                    Text(
                                      _hasShoppingList
                                          ? (isEn ? 'View and update ingredients to buy' : 'Xem và quản lý các sản phẩm cần mua')
                                          : (isEn ? 'Automatically aggregate missing items' : 'Tự động tổng hợp sản phẩm thiếu'),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? const Color(0xFF9DA8A0) : const Color(0xFF55A44B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 3. Daily Meal Plans List Title
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF19271E) : Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          border: isDark ? Border.all(color: const Color(0xFF2E4D36), width: 1) : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEn ? '7-Day Weekly Menu Plan' : 'Thực đơn 7 ngày trong tuần',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : const Color(0xFF006428),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isEn ? 'AI generated balanced menu for 7 days!' : 'Thực đơn 7 ngày từ Thứ 2 đến Chủ nhật do AI lập!',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFF81C784) : const Color(0xFF55A44B),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Horizontal Compact Selector Bar of 7 Days (Thứ 2 -> Chủ Nhật)
                      SizedBox(
                        height: 46,
                        child: ListView.builder(
                          controller: _dayTabScrollController,
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: 7, // 7 days of the week (1=Mon to 7=Sun)
                          itemBuilder: (context, index) {
                            final dayOfWeek = index + 1; // 1 = Mon, ..., 7 = Sun
                            final dayText = _getDayName(dayOfWeek, isEn);
                            final isSelected = dayOfWeek == _selectedDayOfWeek;

                            final dayData = _dailyPlansMap[dayOfWeek];
                            final slots = (dayData?['mealSlots'] as List<dynamic>?) ?? [];
                            final hasMeals = slots.isNotEmpty;

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedDayOfWeek = dayOfWeek;
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 10),
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF008435)
                                      : (isDark ? const Color(0xFF19271E) : Colors.white),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF008435)
                                        : (isDark ? const Color(0xFF2E4D36) : const Color(0xFFC8E6C9)),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isSelected
                                          ? const Color(0xFF008435).withValues(alpha: 0.35)
                                          : Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                                      blurRadius: isSelected ? 8 : 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      dayText,
                                      style: GoogleFonts.outfit(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w800,
                                        color: isSelected
                                            ? Colors.white
                                            : (isDark ? Colors.white : const Color(0xFF006428)),
                                      ),
                                    ),
                                    if (hasMeals) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(0xFFFFB74D)
                                              : (isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32)),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 4. Detailed Meal Slots for Selected Day
                      _buildSelectedDayMealSlots(isDark, isEn),

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

  Widget _buildSelectedDayMealSlots(bool isDark, bool isEn) {
    final dayText = _getDayName(_selectedDayOfWeek, isEn);
    final dayData = _dailyPlansMap[_selectedDayOfWeek];
    final slots = (dayData?['mealSlots'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF19271E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFC8E6C9),
          width: 1.5,
        ),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF233629) : const Color(0xFFDCEDC8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.restaurant_menu_rounded,
                  color: isDark ? const Color(0xFF81C784) : const Color(0xFF006428),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isEn ? 'Meal Slots for $dayText' : 'Các bữa ăn trong $dayText',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF006428),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF233629) : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${slots.length} ${isEn ? "meals" : "bữa ăn"}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (slots.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Center(
                child: Text(
                  isEn ? 'No meals scheduled for this day.' : 'Chưa có bữa ăn được lập cho ngày này.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF9DA8A0) : const Color(0xFF757575),
                  ),
                ),
              ),
            )
          else
            Column(
              children: slots.map((slot) {
                return _buildMealSlotItem(slot, isDark, isEn);
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildMealSlotItem(Map<String, dynamic> slot, bool isDark, bool isEn) {
    final slotId = slot['id']?.toString() ?? '';
    final mealType = slot['mealType']?.toString().toLowerCase() ?? 'lunch';
    final recipeName = slot['recipeName']?.toString() ?? 'Món ngon AI';
    final recipeId = slot['recipeId']?.toString() ?? 'rec_default';
    final servings = slot['servings'] ?? 1;
    final isCompleted = slot['completedAt'] != null || slot['completed'] == true;
    final isRegenerating = _regeneratingSlotId == slotId;

    String mealLabel = 'Bữa Trưa';
    IconData mealIcon = Icons.wb_sunny_rounded;
    Color mealColor = const Color(0xFFFFA726);

    if (mealType == 'breakfast') {
      mealLabel = isEn ? 'Breakfast' : 'Bữa Sáng';
      mealIcon = Icons.wb_twilight_rounded;
      mealColor = const Color(0xFFFFB74D);
    } else if (mealType == 'lunch') {
      mealLabel = isEn ? 'Lunch' : 'Bữa Trưa';
      mealIcon = Icons.wb_sunny_rounded;
      mealColor = const Color(0xFFFFA726);
    } else if (mealType == 'dinner') {
      mealLabel = isEn ? 'Dinner' : 'Bữa Tối';
      mealIcon = Icons.nights_stay_rounded;
      mealColor = const Color(0xFF7E57C2);
    } else if (mealType == 'snack') {
      mealLabel = isEn ? 'Snack' : 'Bữa Phụ';
      mealIcon = Icons.local_cafe_rounded;
      mealColor = const Color(0xFF26A69A);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCompleted
            ? (isDark ? const Color(0xFF1B2E21) : const Color(0xFFEAF5E1))
            : (isDark ? const Color(0xFF233629) : const Color(0xFFF5F9F2)),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCompleted
              ? const Color(0xFF008435)
              : (isDark ? const Color(0xFF2E4D36) : const Color(0xFFC8E6C9)),
          width: isCompleted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: mealColor.withValues(alpha: isDark ? 0.3 : 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(mealIcon, size: 15, color: mealColor),
                    const SizedBox(width: 5),
                    Text(
                      mealLabel,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : mealColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Nút Đánh dấu đã nấu xong / Toggle completed
              InkWell(
                onTap: () => _toggleMealSlotCompleted(slotId, isCompleted),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFF008435).withValues(alpha: isDark ? 0.3 : 0.15)
                        : (isDark ? const Color(0xFF19271E) : Colors.white),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isCompleted
                          ? const Color(0xFF008435)
                          : (isDark ? const Color(0xFF2E4D36) : const Color(0xFFC8E6C9)),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCompleted ? Icons.check_circle_rounded : Icons.circle_outlined,
                        size: 15,
                        color: isCompleted
                            ? const Color(0xFF008435)
                            : (isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32)),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isCompleted ? (isEn ? 'Cooked' : 'Đã nấu xong') : (isEn ? 'Mark Cooked' : 'Nấu xong'),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isCompleted
                              ? const Color(0xFF008435)
                              : (isDark ? const Color(0xFF81C784) : const Color(0xFF006428)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                recipeName,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF006428),
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isEn ? '$servings serving' : '$servings người ăn',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF9DA8A0) : const Color(0xFF666666),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  final match = RecipeModel(
                    id: recipeId,
                    title: recipeName,
                    englishTitle: recipeName,
                    imagePath: '',
                    timeText: '20 phút',
                    difficultyText: 'Dễ',
                    servingsText: '$servings người',
                    tags: ['# Thực đơn AI tuần'],
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RecipeDetailScreen(recipe: match),
                    ),
                  );
                },
                icon: const Icon(Icons.menu_book_rounded, size: 15),
                label: Text(
                  isEn ? 'Recipe' : 'Xem công thức',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? const Color(0xFF81C784) : const Color(0xFF006428),
                  side: BorderSide(
                    color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFC8E6C9),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: isRegenerating ? null : () => _regenerateMealSlot(slotId, recipeId),
                icon: isRegenerating
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.refresh_rounded, size: 15),
                label: Text(
                  isRegenerating
                      ? (isEn ? 'Changing...' : 'Đang đổi...')
                      : (isEn ? 'Change Dish' : 'Đổi món AI'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF008435),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
