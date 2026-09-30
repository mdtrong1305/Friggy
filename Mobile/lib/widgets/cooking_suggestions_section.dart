import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:convert';
import '../data/models/recipe_model.dart';
import '../data/services/api_exception.dart';
import '../data/services/api_service.dart';
import '../l10n/app_localizations.dart';
import '../screens/recipe_detail_screen.dart';
import '../screens/package_management_screen.dart';
import '../theme/app_theme.dart';
import '../sqlite/services/weekly_plan_local_service.dart';
import '../sqlite/services/slot_completion_local_service.dart';
import '../sqlite/services/stats_local_service.dart';
import '../sqlite/models/local_weekly_plan_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class DailyMealSlotData {
  final String id;
  final String mealType; // 'breakfast', 'lunch', 'dinner'
  final String recipeId;
  final String recipeTitle;
  final int servings;
  final int cookTimeMinutes;
  final bool isCompleted;

  const DailyMealSlotData({
    required this.id,
    required this.mealType,
    required this.recipeId,
    required this.recipeTitle,
    this.servings = 1,
    this.cookTimeMinutes = 20,
    this.isCompleted = false,
  });

  DailyMealSlotData copyWith({
    String? id,
    String? mealType,
    String? recipeId,
    String? recipeTitle,
    int? servings,
    int? cookTimeMinutes,
    bool? isCompleted,
  }) {
    return DailyMealSlotData(
      id: id ?? this.id,
      mealType: mealType ?? this.mealType,
      recipeId: recipeId ?? this.recipeId,
      recipeTitle: recipeTitle ?? this.recipeTitle,
      servings: servings ?? this.servings,
      cookTimeMinutes: cookTimeMinutes ?? this.cookTimeMinutes,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class CookingSuggestionsSection extends StatefulWidget {
  final VoidCallback? onUpgradeTap;
  final ValueChanged<RecipeModel>? onRecipeTap;
  final VoidCallback? onMealToggled;
  final bool showHeaderTitle;

  const CookingSuggestionsSection({
    super.key,
    this.onUpgradeTap,
    this.onRecipeTap,
    this.onMealToggled,
    this.showHeaderTitle = true,
  });

  @override
  State<CookingSuggestionsSection> createState() =>
      CookingSuggestionsSectionState();
}

class CookingSuggestionsSectionState extends State<CookingSuggestionsSection> {
  bool _isLoading = true;
  bool _isGenerating = false;
  String? _loadingMealType;
  List<DailyMealSlotData> _dailySlots = [];
  int _dayOfWeek = 1; // 1 = Thứ 2, ..., 7 = Chủ nhật

  final SlotCompletionLocalService _slotCompletionSvc = SlotCompletionLocalService();
  final StatsLocalService _statsLocalSvc = StatsLocalService();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _wasOffline = false;

  void reload() {
    _loadTodayMealPlan();
  }



  @override
  void initState() {
    super.initState();
    _dayOfWeek = DateTime.now().weekday;
    _loadTodayMealPlan();
    // Lắng nghe kết nối mạng: khi online trở lại sau offline → reload để lấy dữ liệu mới nhất
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline && _wasOffline) {
        // Đợi 3 giây cho BackgroundSync upload pending xong rồi mới reload
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) _loadTodayMealPlan();
        });
      }
      _wasOffline = !isOnline;
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _loadTodayMealPlan() async {
    _dayOfWeek = DateTime.now().weekday;
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
          final detail = await ApiService().getMealPlanDetail(firstPlan['id'].toString());
          final dailyPlans = (detail['dailyPlans'] as List<dynamic>?)
                  ?.map((e) => Map<String, dynamic>.from(e as Map))
                  .toList() ??
              [];

          // Cache to SQLite
          await weeklyPlanLocalService.saveWeeklyPlanOverwrite(
            LocalWeeklyPlanModel(
              id: firstPlan['id'].toString(),
              weekStartDate: detail['weekStartDate']?.toString() ?? '',
              daysDataJson: jsonEncode(dailyPlans),
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );

          Map<String, dynamic>? todayPlan;
          for (final item in dailyPlans) {
            final rawDay = item['dayOfWeek'];
            final dOfWeek = rawDay is int
                ? rawDay
                : (int.tryParse(rawDay?.toString() ?? '') ?? 1);
            if (dOfWeek == _dayOfWeek) {
              todayPlan = item;
              break;
            }
          }
          if (todayPlan == null && dailyPlans.isNotEmpty) {
            todayPlan = dailyPlans.first;
          }

          if (todayPlan != null && todayPlan['mealSlots'] is List) {
            final slotsList = todayPlan['mealSlots'] as List<dynamic>;
            final List<DailyMealSlotData> loadedSlots = [];

            for (final s in slotsList) {
              final slotMap = s as Map<String, dynamic>;
              final slotId = slotMap['id']?.toString() ?? '';
              final mType = slotMap['mealType']?.toString().toLowerCase() ?? 'lunch';
              final recipeName = slotMap['recipeName']?.toString() ??
                  slotMap['recipe']?['title']?.toString() ??
                  'Món ăn AI';
              final recId = slotMap['recipeId']?.toString() ?? 'rec_default';
              final servings = (slotMap['servings'] as num?)?.toInt() ?? 1;
              final isCompleted = slotMap['completedAt'] != null || slotMap['completed'] == true;

              loadedSlots.add(DailyMealSlotData(
                id: slotId,
                mealType: mType,
                recipeId: recId,
                recipeTitle: recipeName,
                servings: servings,
                cookTimeMinutes: mType == 'breakfast' ? 15 : (mType == 'lunch' ? 25 : 20),
                isCompleted: isCompleted,
              ));
            }

            if (loadedSlots.isNotEmpty && mounted) {
              loadedSlots.sort((a, b) {
                final order = {'breakfast': 0, 'lunch': 1, 'dinner': 2, 'snack': 3};
                return (order[a.mealType] ?? 99).compareTo(order[b.mealType] ?? 99);
              });

              setState(() {
                _dailySlots = loadedSlots.take(3).toList();
                _isLoading = false;
              });
              return;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[CookingSuggestionsSection] Error/Offline loading today plan: $e. Loading from SQLite...');
      final offlineMeals = await weeklyPlanLocalService.getTodayMealsFromWeeklyPlan();
      if (offlineMeals.isNotEmpty) {
        final List<DailyMealSlotData> offlineSlots = [];
        final List<dynamic> slotsToProcess = [];

        for (final m in offlineMeals) {
          if (m is Map) {
            final mParts = Map<String, dynamic>.from(m);
            if (mParts['mealSlots'] is List) {
              slotsToProcess.addAll(mParts['mealSlots'] as List);
            } else {
              slotsToProcess.add(mParts);
            }
          }
        }

        for (final s in slotsToProcess) {
          if (s is Map) {
            final slotMap = Map<String, dynamic>.from(s);
            final slotId = slotMap['id']?.toString() ?? '';
            final mType = slotMap['mealType']?.toString().toLowerCase() ?? 'lunch';
            final recipeName = slotMap['recipeName']?.toString() ??
                slotMap['recipe']?['title']?.toString() ??
                'Món ăn AI';
            final recId = slotMap['recipeId']?.toString() ?? 'rec_default';
            final servings = (slotMap['servings'] as num?)?.toInt() ?? 1;
            final isCompleted = slotMap['completedAt'] != null || slotMap['completed'] == true;

            offlineSlots.add(DailyMealSlotData(
              id: slotId,
              mealType: mType,
              recipeId: recId,
              recipeTitle: recipeName,
              servings: servings,
              cookTimeMinutes: mType == 'breakfast' ? 15 : (mType == 'lunch' ? 25 : 20),
              isCompleted: isCompleted,
            ));
          }
        }

        if (offlineSlots.isNotEmpty && mounted) {
          offlineSlots.sort((a, b) {
            final order = {'breakfast': 0, 'lunch': 1, 'dinner': 2, 'snack': 3};
            return (order[a.mealType] ?? 99).compareTo(order[b.mealType] ?? 99);
          });
          setState(() {
            _dailySlots = offlineSlots.take(3).toList();
            _isLoading = false;
          });
          return;
        }
      }
    }

    if (mounted) {
      setState(() {
        _dailySlots = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _generateTodayMealPlan() async {
    if (_isGenerating) return;

    setState(() {
      _isGenerating = true;
    });

    final isEn = AppLocalizations.of(context)?.locale.languageCode == 'en';

    try {
      await ApiService().generateFromExpiring(withinDays: 3, days: 1);

      const int maxAttempts = 15; // wait up to ~45s
      for (int i = 0; i < maxAttempts; i++) {
        await Future.delayed(const Duration(seconds: 3));
        if (!mounted) return;

        await _loadTodayMealPlan();
        if (_dailySlots.isNotEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isEn
                      ? '✨ AI đã tạo xong thực đơn cho hôm nay!'
                      : '✨ AI đã tạo xong thực đơn cho hôm nay!',
                ),
                backgroundColor: const Color(0xFF008435),
                duration: const Duration(seconds: 2),
              ),
            );
          }
          break;
        }
      }
    } catch (e) {
      debugPrint('[CookingSuggestionsSection] Error generating today plan: $e');
      if (mounted) {
        String errorMessage = isEn
            ? 'Failed to generate meal plan for today. Please try again.'
            : 'Tạo thực đơn cho hôm nay thất bại. Vui lòng thử lại.';
        if (e is ApiException) {
          errorMessage = e.message;
        } else if (e.toString().contains('dùng hết')) {
          errorMessage = e.toString().replaceAll('Exception: ', '');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _toggleMealCompletion(int index) async {
    final targetSlot = _dailySlots[index];
    final newStatus = !targetSlot.isCompleted;

    if (newStatus) {
      final isEn = AppLocalizations.of(context)?.locale.languageCode == 'en';
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          title: Text(
            isEn ? 'Confirm Cooked Meal?' : 'Xác nhận đã nấu món này?',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
          ),
          content: Text(
            isEn
                ? 'This will mark the meal as completed and automatically deduct used ingredients from your fridge.'
                : 'Hệ thống sẽ đánh dấu bữa ăn là đã hoàn thành và tự động trừ nguyên liệu tương ứng trong tủ lạnh của bạn.',
            style: GoogleFonts.plusJakartaSans(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                isEn ? 'Cancel' : 'Hủy',
                style: GoogleFonts.plusJakartaSans(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF008435),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                isEn ? 'Confirm' : 'Xác nhận',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    // Kiểm tra kết nối mạng
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOnline = connectivityResult.contains(ConnectivityResult.wifi) ||
        connectivityResult.contains(ConnectivityResult.mobile) ||
        connectivityResult.contains(ConnectivityResult.ethernet);

    // Cập nhật UI ngay lập tức
    setState(() {
      _dailySlots[index] = targetSlot.copyWith(isCompleted: newStatus);
    });

    if (targetSlot.id.isNotEmpty && !targetSlot.id.startsWith('slot_')) {
      if (isOnline) {
        // === ONLINE: gọi API bình thường ===
        try {
          await ApiService().updateMealSlot(
            slotId: targetSlot.id,
            completed: newStatus,
          );
          widget.onMealToggled?.call();
        } catch (e) {
          debugPrint('[CookingSuggestionsSection] Error toggling status (online): $e');
        }
      } else {
        // === OFFLINE: lưu pending vào SQLite ===
        await _slotCompletionSvc.savePendingCompletion(
          slotId: targetSlot.id,
          completed: newStatus,
        );
        // Cập nhật số bữa nấu trong local_fridge_stats ngay lập tức
        if (newStatus) {
          await _statsLocalSvc.incrementMealsCookedLocally();
        } else {
          await _statsLocalSvc.decrementMealsCookedLocally();
        }
        // Cập nhật days_data_json trong local_weekly_plans
        await _updateWeeklyPlanLocalCompleted(targetSlot.id, newStatus);
        // Notify home screen reload stats
        widget.onMealToggled?.call();
      }
    } else {
      widget.onMealToggled?.call();
    }
  }

  /// Cập nhật trạng thái completed của slot trong local_weekly_plans (days_data_json)
  Future<void> _updateWeeklyPlanLocalCompleted(String slotId, bool completed) async {
    try {
      final svc = WeeklyPlanLocalService();
      final cached = await svc.getCachedWeeklyPlan();
      if (cached == null) return;
      final days = cached.decodedDaysData;
      final updatedDays = days.map((day) {
        if (day is! Map) return day;
        final dayMap = Map<String, dynamic>.from(day);
        final slots = (dayMap['mealSlots'] as List<dynamic>? ?? []).map((s) {
          if (s is! Map) return s;
          final slot = Map<String, dynamic>.from(s);
          if (slot['id']?.toString() == slotId) {
            slot['completed'] = completed;
            slot['completedAt'] = completed ? DateTime.now().toIso8601String() : null;
          }
          return slot;
        }).toList();
        dayMap['mealSlots'] = slots;
        return dayMap;
      }).toList();
      await svc.saveWeeklyPlanOverwrite(LocalWeeklyPlanModel(
        id: cached.id,
        weekStartDate: cached.weekStartDate,
        daysDataJson: jsonEncode(updatedDays),
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ));
    } catch (e) {
      debugPrint('[CookingSuggestionsSection] Error updating weekly plan local: $e');
    }
  }

  Future<void> _swapDishWithAi(int index) async {
    final targetSlot = _dailySlots[index];
    final mType = targetSlot.mealType;

    setState(() {
      _loadingMealType = mType;
    });

    final isEn = AppLocalizations.of(context)?.locale.languageCode == 'en';
    try {
      if (targetSlot.id.isNotEmpty && !targetSlot.id.startsWith('slot_')) {
        // 1. Call POST /meal-planning/slots/:id/regenerate (Triggers AI job & rate limit check)
        await ApiService().regenerateSlot(slotId: targetSlot.id);

        // 2. Fetch recipes from backend to select a replacement
        final recipes = await ApiService().getRecipes();
        Map<String, dynamic>? selectedRecipe;

        if (recipes.isNotEmpty) {
          final typedRecipes = recipes.map((r) => Map<String, dynamic>.from(r as Map)).toList();

          // Filter matching mealType if available, excluding current recipeId
          final matchingMealType = typedRecipes.where((r) {
            final recMealType = r['mealType']?.toString().toLowerCase();
            final recId = r['id']?.toString();
            return recId != targetSlot.recipeId && (recMealType == null || recMealType == mType.toLowerCase());
          }).toList();

          if (matchingMealType.isNotEmpty) {
            matchingMealType.shuffle();
            selectedRecipe = matchingMealType.first;
          } else {
            final differentRecipes = typedRecipes.where((r) => r['id']?.toString() != targetSlot.recipeId).toList();
            if (differentRecipes.isNotEmpty) {
              differentRecipes.shuffle();
              selectedRecipe = differentRecipes.first;
            } else {
              selectedRecipe = typedRecipes.first;
            }
          }
        }

        if (selectedRecipe != null) {
          final newRecipeId = selectedRecipe['id'].toString();
          final newRecipeTitle = selectedRecipe['title']?.toString() ?? 'Món mới AI';
          final newCookTime = (selectedRecipe['cookTimeMinutes'] as num?)?.toInt() ?? targetSlot.cookTimeMinutes;
          final newServings = (selectedRecipe['servings'] as num?)?.toInt() ?? targetSlot.servings;

          // 3. Persist the updated recipeId in backend DB via PATCH /meal-planning/slots/:id
          await ApiService().updateMealSlot(
            slotId: targetSlot.id,
            recipeId: newRecipeId,
          );

          if (mounted) {
            setState(() {
              _dailySlots[index] = targetSlot.copyWith(
                recipeId: newRecipeId,
                recipeTitle: newRecipeTitle,
                cookTimeMinutes: newCookTime,
                servings: newServings,
              );
              _loadingMealType = null;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✨ AI đã đổi món thành công: $newRecipeTitle'),
                backgroundColor: const Color(0xFF008435),
                duration: const Duration(seconds: 2),
              ),
            );
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('[CookingSuggestionsSection] Error regenerating slot: $e');
      if (mounted) {
        setState(() {
          _loadingMealType = null;
        });
        String errorMessage = isEn
            ? 'Failed to swap dish. Please try again.'
            : 'Đổi món thất bại. Vui lòng thử lại.';
        if (e is ApiException) {
          errorMessage = e.message;
        } else if (e.toString().contains('dùng hết')) {
          errorMessage = e.toString().replaceAll('Exception: ', '');
        }
        final isLimitError = errorMessage.contains('dùng hết') || errorMessage.contains('lượt AI');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.stars_rounded, color: Color(0xFFFFD54F), size: 20),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    errorMessage,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF006428),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
            margin: EdgeInsets.all(16.w),
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
      return;
    }

    if (mounted) {
      setState(() {
        _loadingMealType = null;
      });
    }
  }

  void _openRecipeDetail(DailyMealSlotData slot) {
    final effectiveId = (slot.recipeId.isNotEmpty && !slot.recipeId.startsWith('rec_'))
        ? slot.recipeId
        : slot.id;

    final recipe = RecipeModel(
      id: effectiveId,
      title: slot.recipeTitle,
      englishTitle: slot.recipeTitle,
      imagePath: '',
      timeText: '${slot.cookTimeMinutes} phút',
      difficultyText: 'Dễ',
      servingsText: '${slot.servings} người',
      tags: ['# Món ngon hôm nay', '# AI gợi ý'],
      friggyTip: 'Món ăn cân bằng dinh dưỡng, chế biến nhanh từ nguyên liệu trong tủ lạnh.',
    );

    if (widget.onRecipeTap != null) {
      widget.onRecipeTap!(recipe);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RecipeDetailScreen(
            recipe: recipe,
            slotId: slot.id,
          ),
        ),
      );
    }
  }

  String _getDayOfWeekName(bool isEn) {
    final names = isEn
        ? ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
        : ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];
    final idx = (_dayOfWeek - 1).clamp(0, 6);
    return names[idx];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final isEn = loc?.locale.languageCode == 'en';
    final dayName = _getDayOfWeekName(isEn);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showHeaderTitle) ...[
          // 1. Header Title Row: "Gợi Ý Món Ăn Hôm Nay" + "✨ 3 bữa ăn"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                isEn ? "Today's Meal Suggestions" : 'Gợi Ý Món Ăn Hôm Nay',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: const Color(0xFFFFD54F),
                      size: 14.sp,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      isEn ? '3 meals' : '3 bữa ăn',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 14.h),
        ],

        // 2. Main Daily Meals Card Container
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF19271E) : Colors.white,
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF2E4D36)
                  : const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.07),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Title inside Card
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(7.w),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF233629)
                                : const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Icon(
                            Icons.restaurant_menu_rounded,
                            size: 18.sp,
                            color: isDark
                                ? const Color(0xFF81C784)
                                : const Color(0xFF008435),
                          ),
                        ),
                        SizedBox(width: 9.w),
                        Flexible(
                          child: Text(
                            isEn ? 'Meals for $dayName' : 'Các bữa ăn trong $dayName',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF1B5E20),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 9.w,
                      vertical: 3.5.h,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF233629)
                          : const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      isEn ? '3 meals' : '3 bữa ăn',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? const Color(0xFF81C784)
                            : const Color(0xFF008435),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 14.h),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF008435),
                      strokeWidth: 2.5,
                    ),
                  ),
                )
              else if (_dailySlots.isEmpty)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF19271E) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFE2E8E4),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 52.w,
                        height: 52.w,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF233629) : const Color(0xFFE8F5E9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.restaurant_menu_rounded,
                          size: 28.sp,
                          color: isDark ? const Color(0xFF81C784) : const Color(0xFF008435),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        isEn ? 'No meal plan for today' : 'Chưa có thực đơn cho hôm nay',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        isEn
                            ? 'Generate a meal plan with AI to get customized recipes for your day.'
                            : 'Hãy tạo thực đơn bằng AI để tự động lên lịch bữa ăn phù hợp cho bạn.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: isDark ? const Color(0xFFD0D7D1) : const Color(0xFF6B786F),
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      ElevatedButton.icon(
                        onPressed: _isGenerating ? null : _generateTodayMealPlan,
                        icon: _isGenerating
                            ? SizedBox(
                                width: 16.w,
                                height: 16.w,
                                child: const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(Icons.auto_awesome_rounded, size: 18.sp),
                        label: Text(
                          _isGenerating
                              ? (isEn ? 'AI is creating your plan...' : 'AI đang phân tích & lên thực đơn...')
                              : (isEn ? 'Generate Today\'s Meal Plan' : 'Tạo thực đơn AI'),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF008435),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF008435).withValues(alpha: 0.8),
                          disabledForegroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                )
              else
                // 3 Meal Slot Items (Bữa Sáng, Bữa Trưa, Bữa Tối)
                ...List.generate(_dailySlots.length, (index) {
                  final slot = _dailySlots[index];
                  return _buildMealSlotCard(
                    slot: slot,
                    index: index,
                    isDark: isDark,
                    isEn: isEn,
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMealSlotCard({
    required DailyMealSlotData slot,
    required int index,
    required bool isDark,
    required bool isEn,
  }) {
    final isRegenerating = _loadingMealType == slot.mealType;

    String mealLabel = 'Bữa Trưa';
    IconData mealIcon = Icons.wb_sunny_rounded;
    Color mealTagColor = const Color(0xFFEA580C);
    Color mealBgColor = isDark ? const Color(0xFF3E2723) : const Color(0xFFFFF3E0);

    if (slot.mealType == 'breakfast') {
      mealLabel = isEn ? 'Breakfast' : 'Bữa Sáng';
      mealIcon = Icons.wb_twilight_rounded;
      mealTagColor = const Color(0xFFD97706);
      mealBgColor = isDark ? const Color(0xFF3E2723) : const Color(0xFFFFF8E1);
    } else if (slot.mealType == 'lunch') {
      mealLabel = isEn ? 'Lunch' : 'Bữa Trưa';
      mealIcon = Icons.wb_sunny_rounded;
      mealTagColor = const Color(0xFFEA580C);
      mealBgColor = isDark ? const Color(0xFF3E2723) : const Color(0xFFFFF3E0);
    } else if (slot.mealType == 'dinner') {
      mealLabel = isEn ? 'Dinner' : 'Bữa Tối';
      mealIcon = Icons.nights_stay_rounded;
      mealTagColor = const Color(0xFF7C3AED);
      mealBgColor = isDark ? const Color(0xFF1A237E) : const Color(0xFFF3E8FF);
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(13.w),
      decoration: BoxDecoration(
        color: slot.isCompleted
            ? (isDark ? const Color(0xFF1B2E21) : const Color(0xFFEAF5E1))
            : (isDark ? const Color(0xFF233629) : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: slot.isCompleted
              ? const Color(0xFF008435)
              : (isDark ? const Color(0xFF2E4D36) : const Color(0xFFCBD5E1)),
          width: slot.isCompleted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Meal Tag + Status toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Meal Type Tag
              Container(
                padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: mealBgColor,
                  borderRadius: BorderRadius.circular(9.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(mealIcon, size: 14.sp, color: mealTagColor),
                    SizedBox(width: 4.w),
                    Text(
                      mealLabel,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: mealTagColor,
                      ),
                    ),
                  ],
                ),
              ),

              // Status Toggle Button (Nấu xong / Chưa nấu)
              InkWell(
                onTap: () => _toggleMealCompletion(index),
                borderRadius: BorderRadius.circular(20.r),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 9.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: slot.isCompleted
                        ? const Color(0xFF008435)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: slot.isCompleted
                          ? const Color(0xFF008435)
                          : (isDark ? const Color(0xFF558B2F) : const Color(0xFF4CAF50)),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        slot.isCompleted
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 14.sp,
                        color: slot.isCompleted
                            ? Colors.white
                            : (isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32)),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        isEn
                            ? (slot.isCompleted ? 'Cooked' : 'Pending')
                            : (slot.isCompleted ? 'Nấu xong' : 'Chưa nấu'),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: slot.isCompleted
                              ? Colors.white
                              : (isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 9.h),

          // Recipe Title
          Text(
            slot.recipeTitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          SizedBox(height: 2.h),

          // Servings info
          Text(
            isEn
                ? '${slot.servings} serving • ${slot.cookTimeMinutes} mins'
                : '${slot.servings} người ăn • ${slot.cookTimeMinutes} phút',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),

          SizedBox(height: 10.h),

          // Action Buttons: [📖 Xem công thức]  [🔄 Đổi món AI]
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openRecipeDetail(slot),
                  icon: Icon(Icons.menu_book_rounded, size: 14.sp),
                  label: Text(
                    isEn ? 'Recipe' : 'Xem công thức',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark
                        ? const Color(0xFF81C784)
                        : const Color(0xFF008435),
                    side: BorderSide(
                      color: isDark
                          ? const Color(0xFF2E4D36)
                          : const Color(0xFF008435).withValues(alpha: 0.4),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 7.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isRegenerating ? null : () => _swapDishWithAi(index),
                  icon: isRegenerating
                      ? SizedBox(
                          width: 14.w,
                          height: 14.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(Icons.sync_rounded, size: 14.sp),
                  label: Text(
                    isRegenerating
                        ? (isEn ? 'Swapping...' : 'Đang đổi...')
                        : (isEn ? 'AI Swap' : 'Đổi món AI'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF008435),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(vertical: 7.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
