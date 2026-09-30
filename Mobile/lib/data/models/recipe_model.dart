import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../../sqlite/models/local_recipe_detail_model.dart';
import '../../sqlite/services/recipe_detail_local_service.dart';

class RecipeIngredientDetail {
  final String name;
  final String quantity;
  final bool isAvailable;
  final bool isExpiringSoon;

  const RecipeIngredientDetail({
    required this.name,
    required this.quantity,
    this.isAvailable = true,
    this.isExpiringSoon = false,
  });
}

class RecipeModel {
  final String id;
  final String title;
  final String englishTitle;
  final String imagePath;
  final int? matchPercent; // e.g. 95, 88, 75 or null if not returned
  final String? matchText; // e.g. "95% phù hợp" or null
  final String timeText; // e.g. "10 phút"
  final String difficultyText; // e.g. "Dễ", "Rất dễ"
  final String servingsText; // e.g. "2 người"
  final List<String> tags; // e.g. ["# Trứng", "# Cà chua", "# Hành lá"]
  final bool isFavorite;
  final bool isPremium;
  final String? friggyTip;
  final List<RecipeIngredientDetail>? detailedIngredients;
  final List<String>? steps;
  final String? slotId;
  final String? mealType;

  const RecipeModel({
    required this.id,
    required this.title,
    required this.englishTitle,
    required this.imagePath,
    this.matchPercent,
    this.matchText,
    required this.timeText,
    required this.difficultyText,
    required this.servingsText,
    required this.tags,
    this.isFavorite = false,
    this.isPremium = false,
    this.friggyTip,
    this.detailedIngredients,
    this.steps,
    this.slotId,
    this.mealType,
  });

  factory RecipeModel.fromJson(Map<String, dynamic> json) => RecipeModel.fromApi(json);

  factory RecipeModel.fromApi(Map<String, dynamic> json) {
    final Map<String, dynamic> r = (json['recipe'] is Map)
        ? (json['recipe'] as Map<String, dynamic>)
        : json;

    final id = r['id']?.toString() ?? json['id']?.toString() ?? '';
    final title = r['title']?.toString() ?? json['title']?.toString() ?? 'Công thức món ăn';
    final matchScore = (r['matchScore'] as num?)?.toInt() ??
        (json['summary']?['fridgeReadyPercent'] as num?)?.toInt();
    final matchTextStr = matchScore != null ? '$matchScore% phù hợp' : null;
    final cookTime = r['cookTimeMinutes']?.toString() ?? '15';
    final servings = r['servings']?.toString() ?? json['servings']?.toString() ?? '2';

    String diffText = 'Dễ';
    final diffLevel = r['difficultyLevel']?.toString().toLowerCase() ?? '';
    if (diffLevel == 'very_easy' || diffLevel == 'very easy' || diffLevel == 'rất dễ') {
      diffText = 'Rất dễ';
    } else if (diffLevel == 'medium' || diffLevel == 'vừa') {
      diffText = 'Vừa';
    } else if (diffLevel == 'hard' || diffLevel == 'khó') {
      diffText = 'Khó';
    } else {
      diffText = 'Dễ';
    }

    final List<String> tagList = [];
    if (r['tags'] is List) {
      for (var t in (r['tags'] as List)) {
        if (t is Map && t['name'] != null) {
          tagList.add('# ${t['name']}');
        } else if (t is Map && t['tag'] is Map && t['tag']['name'] != null) {
          tagList.add('# ${t['tag']['name']}');
        } else if (t is String) {
          tagList.add('# $t');
        }
      }
    }
    if (tagList.isEmpty) {
      if (title.isNotEmpty) {
        tagList.add('# $title');
      }
    }

    String imagePath = r['thumbnailPath']?.toString() ??
        r['imagePath']?.toString() ??
        json['thumbnailPath']?.toString() ??
        '';
    if (imagePath == 'null') {
      imagePath = '';
    }

    List<RecipeIngredientDetail>? detailedIngredients;
    final rawIngredients = r['ingredients'] ?? json['ingredients'];
    if (rawIngredients is List) {
      detailedIngredients = rawIngredients.map((ing) {
        final name = ing['ingredientName']?.toString() ??
            ing['ingredient']?['name']?.toString() ??
            ing['name']?.toString() ??
            '';
        final qtyNum = ing['originalQuantity']?.toString() ??
            ing['quantityNeeded']?.toString() ??
            ing['quantity']?.toString() ??
            '';
        final unit = ing['originalUnit']?.toString() ??
            ing['baseUnit']?.toString() ??
            ing['unit']?.toString() ??
            '';
        final qtyStr = '$qtyNum $unit'.trim();
        final inFridge = ing['inFridge'] == true ||
            ing['isAvailable'] == true ||
            ing['fridgeStatus'] == 'have';
        return RecipeIngredientDetail(
          name: name,
          quantity: qtyStr.isNotEmpty ? qtyStr : 'Vừa đủ',
          isAvailable: inFridge,
        );
      }).toList();
    }

    List<String>? steps;
    final rawSteps = r['steps'] ?? json['steps'];
    if (rawSteps is List) {
      steps = rawSteps.map((s) {
        if (s is Map) {
          return s['instruction']?.toString() ?? '';
        }
        return s.toString();
      }).where((s) => s.isNotEmpty).toList();
    }

    return RecipeModel(
      id: id,
      title: title,
      englishTitle: title,
      imagePath: imagePath,
      matchPercent: matchScore,
      matchText: matchTextStr,
      timeText: '$cookTime phút',
      difficultyText: diffText,
      servingsText: '$servings người',
      tags: tagList,
      friggyTip: r['description']?.toString() ?? json['description']?.toString(),
      detailedIngredients: detailedIngredients,
      steps: steps,
    );
  }

  String get safeTitle => title.isNotEmpty ? title : 'Món ăn gợi ý';
  String get safeTimeText => timeText.isNotEmpty ? timeText : '10 phút';
  String get safeDifficultyText => difficultyText.isNotEmpty ? difficultyText : 'Dễ';
  String get safeServingsText => servingsText.isNotEmpty ? servingsText : '2 người';
  String get safeMatchText => matchText ?? (matchPercent != null ? '$matchPercent% phù hợp' : '');

  String displayTitle(bool isEn) => (isEn && englishTitle.isNotEmpty) ? englishTitle : safeTitle;
  String displayMatchText(bool isEn) => isEn ? '$matchPercent% match' : safeMatchText;
  String displayTimeText(bool isEn) {
    if (!isEn) return safeTimeText;
    final mins = cookingTimeMinutes;
    return '$mins mins';
  }

  String displayDifficultyText(bool isEn) {
    if (!isEn) return safeDifficultyText;
    if (difficultyText.contains('Rất dễ')) return 'Very easy';
    if (difficultyText.contains('Dễ')) return 'Easy';
    if (difficultyText.contains('Vừa')) return 'Medium';
    if (difficultyText.contains('Khó')) return 'Hard';
    return 'Easy';
  }

  String displayServingsText(bool isEn) {
    if (!isEn) return safeServingsText;
    final numStr = safeServingsText.replaceAll(RegExp(r'[^0-9]'), '');
    if (numStr.isNotEmpty) return '$numStr servings';
    return '2 servings';
  }

  List<String> displayTags(bool isEn) {
    if (!isEn) return tags;
    final tagMap = {
      'Trứng': 'Egg',
      'Cà chua': 'Tomato',
      'Hành lá': 'Green Onion',
      'Dưa chuột': 'Cucumber',
      'Cà chua bi': 'Cherry Tomato',
      'Xà lách': 'Lettuce',
      'Ngô': 'Corn',
      'Cà rốt': 'Carrot',
      'Súp lơ': 'Broccoli',
      'Bắp cải': 'Cabbage',
      'Thịt heo': 'Pork',
      'Thịt bò': 'Beef',
      'Tôm': 'Shrimp',
      'Cá': 'Fish',
      'Tỏi': 'Garlic',
      'Hành tây': 'Onion',
    };
    return tags.map((t) {
      final raw = t.replaceAll('#', '').trim();
      final translated = tagMap[raw] ?? raw;
      return '# $translated';
    }).toList();
  }

  String get safeFriggyTip {
    if (friggyTip != null && friggyTip!.trim().isNotEmpty) {
      return friggyTip!;
    }
    return 'Món ăn này cực kỳ thơm ngon và bổ dưỡng giúp tận dụng nguyên liệu sẵn có!';
  }

  List<RecipeIngredientDetail> get safeDetailedIngredients {
    if (detailedIngredients != null && detailedIngredients!.isNotEmpty) {
      return detailedIngredients!;
    }
    if (tags.isNotEmpty) {
      return tags.map((t) {
        final name = t.replaceAll('#', '').trim();
        return RecipeIngredientDetail(
          name: name,
          quantity: 'Vừa đủ',
          isAvailable: false,
        );
      }).toList();
    }
    return [
      RecipeIngredientDetail(
        name: title.isNotEmpty ? title : 'Nguyên liệu chính',
        quantity: 'Đầy đủ',
        isAvailable: false,
      ),
      const RecipeIngredientDetail(
        name: 'Gia vị',
        quantity: 'Vừa đủ',
        isAvailable: false,
      ),
    ];
  }

  List<String> get safeSteps {
    if (steps != null && steps!.isNotEmpty) {
      return steps!;
    }
    return [
      'Sơ chế sạch các nguyên liệu.',
      'Chế biến và nêm nếm gia vị vừa ăn.',
      'Bày ra đĩa và thưởng thức khi còn nóng.',
    ];
  }

  int get cookingTimeMinutes =>
      int.tryParse(safeTimeText.replaceAll(RegExp(r'[^0-9]'), '')) ?? 15;
  List<String> get ingredients =>
      tags.map((t) => t.replaceAll('#', '').trim()).toList();
  int get extraIngredientsCount => 2;
}

class RecipeRepository {
  /// Fetch cooking suggestions for TODAY (3 meals: Breakfast, Lunch, Dinner)
  static Future<List<RecipeModel>> fetchCookingSuggestions({
    Function(String message)? onProgress,
    bool forceRegenerate = false,
  }) async {
    final int todayWeekday = DateTime.now().weekday;
    String? targetPlanId;

    // Helper to extract today's 3 recipes from meal plan detail JSON
    List<RecipeModel> extractTodayRecipes(Map<String, dynamic> detail) {
      if (detail.isEmpty || detail['dailyPlans'] == null) return [];
      final rawDailyPlans = detail['dailyPlans'];
      if (rawDailyPlans is! List || rawDailyPlans.isEmpty) return [];

      final dailyPlans = rawDailyPlans
          .map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
          .where((m) => m.isNotEmpty)
          .toList();
      if (dailyPlans.isEmpty) return [];

      Map<String, dynamic>? targetDailyPlan;

      // 1. Try finding dailyPlan for todayWeekday with non-empty mealSlots
      for (final d in dailyPlans) {
        final rawDay = d['dayOfWeek'];
        final dOfWeek = rawDay is int
            ? rawDay
            : (int.tryParse(rawDay?.toString() ?? '') ?? 1);
        final slots = d['mealSlots'];
        if (dOfWeek == todayWeekday && slots is List && slots.isNotEmpty) {
          targetDailyPlan = d;
          break;
        }
      }

      // 2. If no match for today, find ANY dailyPlan with non-empty mealSlots
      if (targetDailyPlan == null) {
        for (final d in dailyPlans) {
          final slots = d['mealSlots'];
          if (slots is List && slots.isNotEmpty) {
            targetDailyPlan = d;
            break;
          }
        }
      }

      if (targetDailyPlan == null) return [];

      final rawSlots = targetDailyPlan['mealSlots'];
      if (rawSlots is! List || rawSlots.isEmpty) return [];

      final sortedSlots = rawSlots
          .map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
          .where((m) => m.isNotEmpty)
          .toList();

      sortedSlots.sort((a, b) {
        final order = {'breakfast': 0, 'lunch': 1, 'dinner': 2, 'snack': 3};
        final mA = a['mealType']?.toString().toLowerCase() ?? '';
        final mB = b['mealType']?.toString().toLowerCase() ?? '';
        return (order[mA] ?? 99).compareTo(order[mB] ?? 99);
      });

      final List<RecipeModel> result = [];
      for (final slotMap in sortedSlots) {
        final recipeId = slotMap['recipeId']?.toString() ?? 'rec_default';
        final recipeName = slotMap['recipeName']?.toString() ??
            (slotMap['recipe'] is Map ? slotMap['recipe']['title']?.toString() : null) ??
            'Món ngon AI';
        final slotId = slotMap['id']?.toString();
        final mealType = slotMap['mealType']?.toString().toLowerCase() ?? 'lunch';

        result.add(RecipeModel(
          id: recipeId,
          title: recipeName,
          englishTitle: recipeName,
          imagePath: (slotMap['recipe'] is Map ? slotMap['recipe']['thumbnailPath']?.toString() : null) ?? '',
          matchPercent: null,
          matchText: null,
          timeText: '20 phút',
          difficultyText: 'Dễ',
          servingsText: '${slotMap['servings'] ?? 1} người',
          tags: ['# Thực đơn hôm nay', '# AI gợi ý'],
          friggyTip: 'Gợi ý từ AI ưu tiên giải cứu thực phẩm trong tủ lạnh.',
          slotId: slotId,
          mealType: mealType,
        ));
      }
      return result;
    }

    // 1. If not forceRegenerate, check if today's existing 3 meals are available in DB
    if (!forceRegenerate) {
      try {
        onProgress?.call('🔍 Đang kiểm tra thực đơn hôm nay...');
        final rawPlans = await ApiService().getMealPlans();
        if (rawPlans.isNotEmpty) {
          final plansList = rawPlans
              .map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
              .where((m) => m.isNotEmpty)
              .toList();

          // Sort plans descending by createdAt to check newest plans first
          plansList.sort((a, b) {
            final dateA = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime(1970);
            final dateB = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime(1970);
            return dateB.compareTo(dateA);
          });

          for (final plan in plansList) {
            final planId = plan['id']?.toString();
            if (planId != null && planId.isNotEmpty) {
              try {
                final detail = await ApiService().getMealPlanDetail(planId);
                final todayList = extractTodayRecipes(detail);
                if (todayList.isNotEmpty) {
                  onProgress?.call('✨ Đã tải 3 bữa ăn hôm nay!');
                  return todayList;
                }
              } catch (err) {
                debugPrint('[RecipeRepository] Error fetching plan detail for $planId: $err');
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[RecipeRepository] Notice checking existing plan: $e');
      }
    }

    // 2. Today does NOT have a plan yet (or forceRegenerate = true):
    //    Trigger AI generate-from-expiring (within 3 days, 1 day plan)
    String initialSlotKey = '';
    try {
      onProgress?.call('🤖 AI Friggy đang kết nối hệ thống...');
      final initialPlans = await ApiService().getMealPlans();
      if (initialPlans.isNotEmpty) {
        initialPlans.sort((a, b) {
          final dateA = DateTime.tryParse((a as Map)['createdAt']?.toString() ?? '') ?? DateTime(1970);
          final dateB = DateTime.tryParse((b as Map)['createdAt']?.toString() ?? '') ?? DateTime(1970);
          return dateB.compareTo(dateA);
        });
        targetPlanId = initialPlans.first['id']?.toString();
        if (targetPlanId != null) {
          final detail = await ApiService().getMealPlanDetail(targetPlanId);
          initialSlotKey = extractTodayRecipes(detail).map((r) => '${r.id}:${r.title}').join('|');
        }
      }
    } catch (e) {
      debugPrint('[RecipeRepository] Notice initial plan fetch: $e');
    }

    try {
      onProgress?.call('🥬 AI đang quét nguyên liệu sắp hết hạn để lập thực đơn 1 ngày...');
      final res = await ApiService().generateFromExpiring(withinDays: 3, days: 1);
      final jobId = res['jobId'] as String?;
      debugPrint('[RecipeRepository] Triggered generateFromExpiring jobId: $jobId');

      Map<String, dynamic>? updatedPlanDetail;
      const int maxAttempts = 15; // max ~22 seconds with 1.5s interval

      for (int i = 0; i < maxAttempts; i++) {
        await Future.delayed(const Duration(milliseconds: 1500));

        if (i == 2) {
          onProgress?.call('🍲 AI đang kết hợp công thức từ đồ sắp hết hạn...');
        } else if (i == 5) {
          onProgress?.call('🍳 AI đang chọn bữa ăn dinh dưỡng và tiết kiệm nhất...');
        } else if (i == 9) {
          onProgress?.call('💾 AI đang lưu thực đơn gợi ý vào hệ thống...');
        }

        try {
          final currentPlans = await ApiService().getMealPlans();
          if (currentPlans.isNotEmpty) {
            currentPlans.sort((a, b) {
              final dateA = DateTime.tryParse((a as Map)['createdAt']?.toString() ?? '') ?? DateTime(1970);
              final dateB = DateTime.tryParse((b as Map)['createdAt']?.toString() ?? '') ?? DateTime(1970);
              return dateB.compareTo(dateA);
            });
            targetPlanId = currentPlans.first['id']?.toString();
          }

          if (targetPlanId != null) {
            final detail = await ApiService().getMealPlanDetail(targetPlanId);
            final currentSlotKey = extractTodayRecipes(detail).map((r) => '${r.id}:${r.title}').join('|');

            final bool hasChanged = currentSlotKey.isNotEmpty && (initialSlotKey.isEmpty || currentSlotKey != initialSlotKey);
            final bool isMinTimePassed = i >= 3 && currentSlotKey.isNotEmpty;

            if (hasChanged || isMinTimePassed) {
              onProgress?.call('✅ AI đã lập thực đơn hôm nay thành công!');
              updatedPlanDetail = detail;
              break;
            }
          }
        } catch (e) {
          debugPrint('[RecipeRepository] Polling attempt $i error: $e');
        }
      }

      final detail = updatedPlanDetail ?? await (() async {
        final plans = await ApiService().getMealPlans();
        if (plans.isNotEmpty) {
          plans.sort((a, b) {
            final dateA = DateTime.tryParse((a as Map)['createdAt']?.toString() ?? '') ?? DateTime(1970);
            final dateB = DateTime.tryParse((b as Map)['createdAt']?.toString() ?? '') ?? DateTime(1970);
            return dateB.compareTo(dateA);
          });
          if (plans.first['id'] != null) {
            return await ApiService().getMealPlanDetail(plans.first['id']);
          }
        }
        return <String, dynamic>{};
      })();

      final resultList = extractTodayRecipes(detail);
      if (resultList.isNotEmpty) return resultList;
    } catch (e) {
      debugPrint('[RecipeRepository] Error fetching meal plan details: $e');
      if (forceRegenerate) {
        rethrow;
      }
    }

    // 3. Fallback to system recipes or default 3 recipes if AI generation fails or hits rate limit
    try {
      final recipes = await ApiService().getRecipes();
      if (recipes.isNotEmpty) {
        final List<RecipeModel> fallbackList = [];
        for (final r in recipes.take(3)) {
          final map = Map<String, dynamic>.from(r as Map);
          fallbackList.add(RecipeModel(
            id: map['id']?.toString() ?? '',
            title: map['title']?.toString() ?? 'Món ngon',
            englishTitle: map['title']?.toString() ?? 'Món ngon',
            imagePath: map['thumbnailPath']?.toString() ?? '',
            timeText: '${map['cookTimeMinutes'] ?? 20} phút',
            difficultyText: map['difficultyLevel']?.toString() ?? 'Dễ',
            servingsText: '${map['servings'] ?? 1} người',
            tags: ['# Thực đơn hôm nay', '# AI gợi ý'],
            friggyTip: 'Công thức gợi ý từ thực đơn Friggy.',
          ));
        }
        if (fallbackList.isNotEmpty) return fallbackList;
      }
    } catch (_) {}

    return const [
      RecipeModel(
        id: 'rec_phobo',
        title: 'Phở bò Hà Nội',
        englishTitle: 'Hanoi Beef Pho',
        imagePath: 'assets/images/recipe_pho.png',
        timeText: '30 phút',
        difficultyText: 'Trung bình',
        servingsText: '2 người',
        tags: ['# Thực đơn hôm nay', '# Món Việt'],
        friggyTip: 'Món ăn truyền thống thơm ngon đậm vị.',
        mealType: 'breakfast',
      ),
      RecipeModel(
        id: 'rec_comrang',
        title: 'Cơm rang dưa bò',
        englishTitle: 'Fried Rice with Beef and Pickles',
        imagePath: 'assets/images/recipe_fried_rice.png',
        timeText: '20 phút',
        difficultyText: 'Dễ',
        servingsText: '2 người',
        tags: ['# Thực đơn hôm nay', '# Bữa trưa'],
        friggyTip: 'Dưa chua giòn kết hợp thịt bò mềm mọng.',
        mealType: 'lunch',
      ),
      RecipeModel(
        id: 'rec_lauthai',
        title: 'Lẩu thái hải sản',
        englishTitle: 'Thai Seafood Hotpot',
        imagePath: 'assets/images/recipe_tomato_egg.png',
        timeText: '25 phút',
        difficultyText: 'Dễ',
        servingsText: '3 người',
        tags: ['# Thực đơn hôm nay', '# Bữa tối'],
        friggyTip: 'Nước dùng chua cay đậm đà ấm áp.',
        mealType: 'dinner',
      ),
      ];
  }

  /// Fetch full detail of a recipe (either by recipeId or slotId)
  /// Offline-first: check SQLite cache → gọi API → save lại SQLite
  static Future<RecipeModel?> fetchRecipeDetail(String id, {String? slotId}) async {
    final cacheSvc = RecipeDetailLocalService();

    // ── 1. Thử đọc từ SQLite cache trước ────────────────────────────
    if (slotId != null && slotId.isNotEmpty && !slotId.startsWith('rec_')) {
      final cached = await cacheSvc.getRecipeDetail(slotId);
      if (cached != null && cached.decodedDetail.isNotEmpty) {
        debugPrint('[RecipeRepository] ✓ Cache hit (slot): $slotId');
        return RecipeModel.fromApi(cached.decodedDetail);
      }
    }
    if (id.isNotEmpty && !id.startsWith('rec_')) {
      final cached = await cacheSvc.getRecipeDetail(id);
      if (cached != null && cached.decodedDetail.isNotEmpty) {
        debugPrint('[RecipeRepository] ✓ Cache hit (recipe): $id');
        return RecipeModel.fromApi(cached.decodedDetail);
      }
    }

    // ── 2. Gọi API (chỉ chạy khi online) ───────────────────────────
    try {
      // 2a. Thử slot detail endpoint nếu có slotId
      if (slotId != null && slotId.isNotEmpty && !slotId.startsWith('rec_')) {
        try {
          final slotJson = await ApiService().getSlotDetail(slotId);
          if (slotJson['recipe'] != null) {
            await cacheSvc.saveFromJson(slotId, 'slot', slotJson);
            final recId = (slotJson['recipe'] as Map?)?['id']?.toString();
            if (recId != null && recId.isNotEmpty) {
              await cacheSvc.saveFromJson(recId, 'recipe', slotJson);
            }
            return RecipeModel.fromApi(slotJson);
          }
        } catch (e) {
          debugPrint('[RecipeRepository] Notice getSlotDetail($slotId) failed: $e');
        }
      }

      // 2b. Thử getRecipeDetail nếu id là recipe ID hợp lệ
      if (id.isNotEmpty && !id.startsWith('rec_')) {
        try {
          final json = await ApiService().getRecipeDetail(id);
          await cacheSvc.saveFromJson(id, 'recipe', json);
          return RecipeModel.fromApi(json);
        } catch (e) {
          debugPrint('[RecipeRepository] Notice getRecipeDetail($id) failed: $e');
        }
      }

      // 2c. Fallback: thử id như slotId
      if (id.isNotEmpty && !id.startsWith('rec_')) {
        try {
          final slotJson = await ApiService().getSlotDetail(id);
          if (slotJson['recipe'] != null) {
            await cacheSvc.saveFromJson(id, 'slot', slotJson);
            return RecipeModel.fromApi(slotJson);
          }
        } catch (_) {}
      }

      return null;
    } catch (e) {
      debugPrint('[RecipeRepository] Error fetching recipe detail: $e');
      return null;
    }
  }
}
