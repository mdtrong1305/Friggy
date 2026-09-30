import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../data/services/api_service.dart';
import '../models/local_ingredient_model.dart';
import '../models/local_allergy_model.dart';
import '../models/local_user_profile_model.dart';
import '../models/local_user_preference_model.dart';
import '../models/local_ingredient_catalog_model.dart';
import '../models/local_stats_model.dart';
import 'ingredient_local_service.dart';
import 'allergy_local_service.dart';
import 'user_profile_local_service.dart';
import 'user_preference_local_service.dart';
import 'ingredient_catalog_local_service.dart';
import 'stats_local_service.dart';
import 'recipe_detail_local_service.dart';
import 'shopping_local_service.dart';
import 'slot_completion_local_service.dart';
import 'weekly_plan_local_service.dart';
import 'fridge_ops_local_service.dart';
import '../models/local_weekly_plan_model.dart';
import 'dart:convert';

/// Service chạy nền khi vào trang chủ, tự động sync song song
/// tất cả data từ API → SQLite mà không block UI.
class BackgroundSyncService {
  static final BackgroundSyncService _instance =
      BackgroundSyncService._internal();
  factory BackgroundSyncService() => _instance;
  BackgroundSyncService._internal();

  final ApiService _api = ApiService();
  final IngredientLocalService _ingredientSvc = IngredientLocalService();
  final AllergyLocalService _allergySvc = AllergyLocalService();
  final UserProfileLocalService _profileSvc = UserProfileLocalService();
  final UserPreferenceLocalService _prefSvc = UserPreferenceLocalService();
  final IngredientCatalogLocalService _catalogSvc =
      IngredientCatalogLocalService();
  final StatsLocalService _statsSvc = StatsLocalService();
  final RecipeDetailLocalService _recipeDetailSvc = RecipeDetailLocalService();
  final ShoppingLocalService _shoppingSvc = ShoppingLocalService();
  final SlotCompletionLocalService _slotCompletionSvc = SlotCompletionLocalService();
  final WeeklyPlanLocalService _weeklyPlanSvc = WeeklyPlanLocalService();
  final FridgeOpsLocalService _fridgeOpsSvc = FridgeOpsLocalService();

  bool _isSyncing = false;

  /// Gọi từ HomeScreen.initState() — chạy nền, không await
  void syncAll() {
    if (_isSyncing) return;
    _isSyncing = true;
    _runSync().whenComplete(() => _isSyncing = false);
  }

  /// Gọi khi mạng khôi phục — buộc sync lại dù đang có sync khác
  void forceSync() {
    _isSyncing = false; // Reset để cho phép chạy lại
    syncAll();
  }

  Future<void> _runSync() async {
    debugPrint('[BackgroundSync] ▶ Starting background sync...');
    final now = DateTime.now().millisecondsSinceEpoch;

    // ── Giai đoạn 1: Upload pending changes lên server TRƯỚC ────────
    // Phải hoàn thành trước khi pull data về, tránh race condition
    await Future.wait([
      _syncPendingFridgeItems(),       // Upload ingredient thêm lúc offline
      _syncPendingAllergies(),         // Upload dị ứng thêm lúc offline
      _syncPendingDeleteAllergies(),   // Xóa dị ứng đã bấm xóa lúc offline
      _syncPendingProfile(),           // Upload profile cập nhật lúc offline
      _syncPendingPreferences(),       // Upload preferences cập nhật lúc offline
      _syncPendingAvatar(),            // Upload avatar chụp lúc offline
      _syncPendingShoppingToggle(),    // Sync tick/untick mua sắm lúc offline
      _syncPendingSlotCompletions(),   // Sync nấu xong lúc offline
      _syncPendingFridgeOps(),         // Sync edit/consume/delete nguyên liệu lúc offline
    ]);
    debugPrint('[BackgroundSync] ▶ Phase 1 (uploads) done, pulling fresh data...');

    // ── Giai đoạn 2: Pull data mới nhất từ server về SQLite ─────────
    await Future.wait([
      _syncFridgeItems(now),
      _syncAllergies(now),
      _syncUserProfile(now),
      _syncUserPreferences(now),
      _syncStats(now),
      _syncIngredientCatalog(now),
    ]);

    // ── Giai đoạn 3: Pre-cache chi tiết công thức (chạy nền, không block) ─
    _syncRecipeDetails(); // không await — fire-and-forget

    debugPrint('[BackgroundSync] ✓ All sync tasks completed.');
  }

  // ── 1. Thực phẩm trong tủ lạnh ──────────────────────────────────
  Future<void> _syncFridgeItems(int now) async {
    try {
      final items = await _api.getFridgeItems();
      final localItems = items
          .cast<Map<String, dynamic>>()
          .map((item) => LocalIngredientModel(
                id: item['id'] as String? ?? '',
                ingredientId: (item['ingredientId'] as num?)?.toInt() ?? 0,
                name: item['ingredientName'] as String? ?? 'Nguyên liệu',
                quantity: (item['quantity'] as num?)?.toDouble() ?? 0.0,
                unit: item['unit'] as String? ?? 'kg',
                storageLocation:
                    item['storageLocation'] as String? ?? 'fridge',
                expiresAt: item['expiresAt'] as String?,
                daysUntilExpiry:
                    (item['daysUntilExpiry'] as num?)?.toInt(),
                imagePath: item['ingredientImagePath'] as String? ??
                    item['imagePath'] as String?,
                updatedAt: now,
              ))
          .where((i) => i.id.isNotEmpty)
          .toList();

      await _ingredientSvc.saveIngredientsCache(localItems);
      debugPrint(
          '[BackgroundSync] ✓ Fridge: ${localItems.length} items synced.');
    } catch (e) {
      debugPrint('[BackgroundSync] ✗ Fridge sync skipped (offline?): $e');
    }
  }

  // ── 1b. Upload ingredient thêm khi offline lên server ───────────────
  Future<void> _syncPendingFridgeItems() async {
    try {
      final pending = await _ingredientSvc.getPendingIngredients();
      if (pending.isEmpty) return;

      debugPrint('[BackgroundSync] Found ${pending.length} pending fridge items to sync...');
      for (final item in pending) {
        try {
          await _api.addFridgeItem({
            if (item.ingredientId > 0) 'ingredientId': item.ingredientId,
            'name': item.name,
            'quantity': item.quantity,
            'unit': item.unit,
            'storageLocation': item.storageLocation,
            if (item.expiresAt != null) 'expiresAt': item.expiresAt,
          });
          // Xóa item pending cũ (BackgroundSync sẽ pull lại từ server với id thật)
          await _ingredientSvc.markIngredientSynced(item.id);
          debugPrint('[BackgroundSync] ✓ Pending fridge item "${item.name}" synced to server.');
        } catch (e) {
          // Giữ lại 'pending' để thử lại lần sau
          debugPrint('[BackgroundSync] ✗ Could not sync "${item.name}": $e');
        }
      }
    } catch (e) {
      debugPrint('[BackgroundSync] ✗ Pending fridge items sync failed: $e');
    }
  }

  // ── 2. Dị ứng thực phẩm ─────────────────────────────────────────
  Future<void> _syncAllergies(int now) async {
    try {
      final list = await _api.getAllergies();
      final localAllergies = list
          .cast<Map<String, dynamic>>()
          .map((item) => LocalAllergyModel(
                id: item['id'] as String? ?? '',
                ingredientId: (item['ingredientId'] as num?)?.toInt() ?? 0,
                ingredientName:
                    item['ingredientName'] as String? ?? 'Nguyên liệu',
                note: item['note'] as String?,
                updatedAt: now,
              ))
          .where((a) => a.id.isNotEmpty)
          .toList();

      await _allergySvc.saveAllergiesCache(localAllergies);
      debugPrint(
          '[BackgroundSync] ✓ Allergies: ${localAllergies.length} items synced.');
    } catch (e) {
      debugPrint(
          '[BackgroundSync] ✗ Allergies sync skipped (offline?): $e');
    }
  }

  // ── 2b. Upload dị ứng thêm khi offline lên server ───────────────
  Future<void> _syncPendingAllergies() async {
    try {
      final pending = await _allergySvc.getPendingAllergies();
      if (pending.isEmpty) return;

      debugPrint('[BackgroundSync] Found ${pending.length} pending allergies to sync...');
      for (final item in pending) {
        try {
          final result = await _api.addAllergy(item.ingredientId, item.note);
          final serverId = result['id'] as String? ?? '';
          if (serverId.isNotEmpty) {
            await _allergySvc.markAsSynced(item.id, serverId);
            debugPrint('[BackgroundSync] ✓ Pending allergy "${item.ingredientName}" synced → id: $serverId');
          }
        } catch (e) {
          // Giữ lại 'pending' để thử lại lần sau
          debugPrint('[BackgroundSync] ✗ Could not sync "${item.ingredientName}": $e');
        }
      }
    } catch (e) {
      debugPrint('[BackgroundSync] ✗ Pending allergy sync failed: $e');
    }
  }

  // ── 2c. Xóa dị ứng đã bấm xóa khi offline lên server ────────────
  Future<void> _syncPendingDeleteAllergies() async {
    try {
      final pendingDelete = await _allergySvc.getPendingDeleteAllergies();
      if (pendingDelete.isEmpty) return;

      debugPrint('[BackgroundSync] Found ${pendingDelete.length} allergies to delete from server...');
      for (final item in pendingDelete) {
        try {
          await _api.removeAllergy(item.id);
          // Xóa khỏi SQLite sau khi xóa server thành công
          await _allergySvc.deleteAllergyFromCache(item.id);
          debugPrint('[BackgroundSync] ✓ Pending delete "${item.ingredientName}" synced.');
        } catch (e) {
          // Giữ lại 'pending_delete' để thử lại lần sau
          debugPrint('[BackgroundSync] ✗ Could not delete "${item.ingredientName}": $e');
        }
      }
    } catch (e) {
      debugPrint('[BackgroundSync] ✗ Pending delete sync failed: $e');
    }
  }

  // ── 3. Thông tin cá nhân ────────────────────────────────────────
  Future<void> _syncUserProfile(int now) async {
    try {
      final me = await _api.getMe();
      final profile = me['profile'] as Map<String, dynamic>? ?? {};

      await _profileSvc.saveProfileCache(LocalUserProfileModel(
        id: 'me', // Luôn dùng 'me' để tránh tạo 2 row với UUID khác nhau
        name: me['name'] as String?,
        email: me['email'] as String? ?? me['googleEmail'] as String?,
        phone: me['phone'] as String?,
        avatarUrl: profile['avatarUrl'] as String?,
        dateOfBirth: profile['dateOfBirth'] as String?,
        gender: profile['gender'] as String?,
        bio: profile['bio'] as String?,
        role: me['role'] as String?,
        status: me['status'] as String?,
        updatedAt: now,
        syncStatus: 'synced',
      ));
      debugPrint('[BackgroundSync] ✓ User profile synced.');
    } catch (e) {
      debugPrint(
          '[BackgroundSync] ✗ Profile sync skipped (offline?): $e');
    }
  }

  // ── 4. Tùy chọn ăn uống & kỹ năng ──────────────────────────────
  Future<void> _syncUserPreferences(int now) async {
    try {
      final prefs = await _api.getPreferences();
      if (prefs == null) return;

      await _prefSvc.savePreferencesCache(LocalUserPreferenceModel(
        weeklyBudget: prefs['weeklyBudget'] as int?,
        dailyCalorieTarget: prefs['dailyCalorieTarget'] as int?,
        dietaryStyle: prefs['dietaryStyle'] as String? ?? 'omnivore',
        preferSimpleRecipes:
            (prefs['preferSimpleRecipes'] as bool? ?? false) ? 1 : 0,
        maxCookTimeMinutes: prefs['maxCookTimeMinutes'] as int?,
        skillLevel: prefs['skillLevel'] as String? ?? 'beginner',
        householdSize: prefs['householdSize'] as int? ?? 1,
        aiPersonalityMode:
            prefs['aiPersonalityMode'] as String? ?? 'friendly',
        primaryGoal: prefs['primaryGoal'] as String?,
        cookingFrequency: prefs['cookingFrequency'] as String?,
        height: prefs['height'] as int?,
        weight: prefs['weight'] as int?,
        activityLevel: prefs['activityLevel'] as String?,
        updatedAt: now,
      ));
      debugPrint('[BackgroundSync] ✓ Preferences synced.');
    } catch (e) {
      debugPrint(
          '[BackgroundSync] ✗ Preferences sync skipped (offline?): $e');
    }
  }

  // ── 5. Thống kê tủ lạnh ─────────────────────────────────────────
  Future<void> _syncStats(int now) async {
    try {
      final stats = await _api.getFridgeStats();

      await _statsSvc.saveStatsCache(LocalStatsModel(
        totalSpentThisMonth:
            (stats['totalSpentThisMonth'] as num?)?.toInt() ?? 0,
        wastePercent: (stats['wastePercent'] as num?)?.toDouble() ?? 0.0,
        mealsCooked: (stats['mealsCooked'] as num?)?.toInt() ?? 0,
        expiringSoonCount:
            (stats['expiringSoonCount'] as num?)?.toInt() ?? 0,
        totalItems: (stats['totalItems'] as num?)?.toInt() ?? 0,
        updatedAt: now,
      ));
      debugPrint('[BackgroundSync] ✓ Stats synced.');
    } catch (e) {
      debugPrint('[BackgroundSync] ✗ Stats sync skipped (offline?): $e');
    }
  }

  // ── 6. Danh mục nguyên liệu (sync toàn bộ bằng pagination) ──────
  Future<void> _syncIngredientCatalog(int now) async {
    try {
      const int pageSize = 100;
      int page = 0;
      final List<LocalIngredientCatalogModel> allItems = [];

      // Lặp qua từng trang cho đến khi server trả về ít hơn pageSize
      while (true) {
        final res = await _api.getIngredients(
          limit: pageSize,
          skip: page * pageSize, // offset: trang 0 = skip 0, trang 1 = skip 100, ...
        );

        final pageItems = res
            .cast<Map<String, dynamic>>()
            .map((item) => LocalIngredientCatalogModel(
                  id: (item['id'] as num?)?.toInt() ?? 0,
                  name: item['name'] as String? ?? '',
                  englishName: item['englishName'] as String?,
                  defaultUnit: item['defaultUnit'] as String?,
                  category: item['category'] as String?,
                  imagePath: item['imagePath'] as String?,
                  updatedAt: now,
                ))
            .where((i) => i.id > 0 && i.name.isNotEmpty)
            .toList();

        allItems.addAll(pageItems);
        page++;

        // Nếu số item nhận được ít hơn pageSize → đã hết data
        if (pageItems.length < pageSize) break;

        // Giới hạn tối đa 20 trang (2000 nguyên liệu) để tránh vòng lặp vô hạn
        if (page >= 20) {
          debugPrint('[BackgroundSync] ⚠ Catalog: reached max page limit (${page * pageSize} items).');
          break;
        }
      }

      if (allItems.isNotEmpty) {
        await _catalogSvc.saveCatalogCache(allItems);
        debugPrint(
            '[BackgroundSync] ✓ Catalog: ${allItems.length} items synced ($page page(s)).');
      } else {
        debugPrint('[BackgroundSync] ⚠ Catalog: API returned 0 items.');
      }
    } catch (e) {
      debugPrint(
          '[BackgroundSync] ✗ Catalog sync skipped (offline?): $e');
    }
  }

  // ── 7. Upload profile cập nhật khi offline ───────────────────────
  Future<void> _syncPendingProfile() async {
    try {
      final pending = await _profileSvc.getPendingProfile();
      if (pending == null) return;

      debugPrint('[BackgroundSync] Found pending profile update, uploading...');
      final profileData = <String, dynamic>{
        'name': pending.name,
        'gender': pending.gender,
        if (pending.dateOfBirth != null) 'dateOfBirth': pending.dateOfBirth,
        if (pending.bio != null) 'bio': pending.bio,
      };
      await _api.updateProfile(profileData);
      await _profileSvc.markProfileSynced(pending.id);
      debugPrint('[BackgroundSync] ✓ Pending profile synced.');
    } catch (e) {
      debugPrint('[BackgroundSync] ✗ Pending profile sync failed: $e');
    }
  }

  // ── 8. Upload preferences cập nhật khi offline ──────────────────
  Future<void> _syncPendingPreferences() async {
    try {
      final pending = await _prefSvc.getPendingPreferences();
      if (pending == null) return;

      debugPrint('[BackgroundSync] Found pending preferences update, uploading...');
      await _api.updatePreferences(pending.toApiMap());
      await _prefSvc.markPreferencesSynced();
      debugPrint('[BackgroundSync] ✓ Pending preferences synced.');
    } catch (e) {
      debugPrint('[BackgroundSync] ✗ Pending preferences sync failed: $e');
    }
  }

  // ── 9. Upload avatar chụp/chọn khi offline ───────────────────────
  Future<void> _syncPendingAvatar() async {
    try {
      final profile = await _profileSvc.getCachedProfile();
      if (profile == null) return;
      final localPath = profile.avatarLocalPath;
      if (localPath == null || localPath.isEmpty) return;

      final file = File(localPath);
      if (!await file.exists()) {
        // File bị xóa → xóa local path khỏi SQLite
        await _profileSvc.saveProfileCache(profile.copyWith(avatarLocalPath: ''));
        return;
      }

      debugPrint('[BackgroundSync] Found pending avatar at: $localPath, uploading...');
      final res = await _api.uploadAvatar(localPath);
      final String? newAvatarUrl = res['avatarUrl'];
      if (newAvatarUrl != null) {
        // Lưu URL mới, xóa local path
        await _profileSvc.saveProfileCache(profile.copyWith(
          avatarUrl: newAvatarUrl,
          avatarLocalPath: '',
          syncStatus: 'synced',
        ));
        debugPrint('[BackgroundSync] ✓ Pending avatar uploaded: $newAvatarUrl');
      }
    } catch (e) {
      debugPrint('[BackgroundSync] ✗ Pending avatar upload failed: $e');
    }
  }

  // ── Phase 3: Pre-cache chi tiết công thức tất cả slot trong plan hiện tại ──
  Future<void> _syncRecipeDetails() async {
    try {
      // Lấy tất cả meal plans để tìm slot IDs cần cache
      final rawPlans = await _api.getMealPlans();
      if (rawPlans.isEmpty) return;

      rawPlans.sort((a, b) {
        final dateA = DateTime.tryParse((a as Map)['createdAt']?.toString() ?? '') ?? DateTime(1970);
        final dateB = DateTime.tryParse((b as Map)['createdAt']?.toString() ?? '') ?? DateTime(1970);
        return dateB.compareTo(dateA);
      });

      // Chỉ pre-cache plan mới nhất (tránh gọi API quá nhiều)
      final newestPlan = rawPlans.first as Map;
      final planId = newestPlan['id']?.toString();
      if (planId == null || planId.isEmpty) return;

      final detail = await _api.getMealPlanDetail(planId);
      final rawDailyPlans = detail['dailyPlans'];
      if (rawDailyPlans is! List) return;

      // Thu thập tất cả slotId từ plan
      final List<String> slotIds = [];
      for (final day in rawDailyPlans) {
        if (day is! Map) continue;
        final slots = day['mealSlots'];
        if (slots is! List) continue;
        for (final slot in slots) {
          if (slot is! Map) continue;
          final slotId = slot['id']?.toString();
          if (slotId != null && slotId.isNotEmpty) {
            slotIds.add(slotId);
          }
        }
      }

      if (slotIds.isEmpty) return;

      // Lấy những slot chưa có trong cache
      final cachedIds = await _recipeDetailSvc.getCachedIds();
      final toFetch = slotIds.where((id) => !cachedIds.contains(id)).toList();

      if (toFetch.isEmpty) {
        debugPrint('[BackgroundSync] ✓ Recipe details: all ${slotIds.length} slots already cached.');
        return;
      }

      debugPrint('[BackgroundSync] Pre-caching ${toFetch.length} recipe detail(s)...');
      int cached = 0;
      for (final slotId in toFetch) {
        try {
          final slotJson = await _api.getSlotDetail(slotId);
          if (slotJson['recipe'] != null) {
            await _recipeDetailSvc.saveFromJson(slotId, 'slot', slotJson);
            final recId = (slotJson['recipe'] as Map?)?['id']?.toString();
            if (recId != null && recId.isNotEmpty) {
              await _recipeDetailSvc.saveFromJson(recId, 'recipe', slotJson);
            }
            cached++;
          }
        } catch (e) {
          debugPrint('[BackgroundSync] Notice: failed to cache slot $slotId: $e');
        }
        // Delay nhỏ tránh overwhelm API
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // Dọn cache cũ > 7 ngày
      await _recipeDetailSvc.cleanOldCache();

      debugPrint('[BackgroundSync] ✓ Pre-cached $cached/${toFetch.length} recipe detail(s).');
    } catch (e) {
      debugPrint('[BackgroundSync] Recipe detail pre-cache skipped (offline?): $e');
    }
  }

  // ── 10. Sync tick/untick mua sắm đã lưu offline (pending_toggle) ──────────────
  Future<void> _syncPendingShoppingToggle() async {
    try {
      final pending = await _shoppingSvc.getPendingToggleItems();
      if (pending.isEmpty) return;

      debugPrint('[BackgroundSync] Found ${pending.length} pending shopping toggle(s) to sync...');
      for (final item in pending) {
        // Cần có listId và backendItemId để gọi API
        if (item.listId == null || item.backendItemId == null) {
          debugPrint('[BackgroundSync] Skipping "${item.ingredientName}": no listId/backendItemId.');
          // Đánh dấu synced để tránh loop mãi mãi
          await _shoppingSvc.markToggleSynced(item.id);
          continue;
        }
        try {
          await _api.toggleShoppingListItem(
            listId: item.listId!,
            itemId: item.backendItemId!,
          );
          await _shoppingSvc.markToggleSynced(item.id);
          // Nếu item đã được check (đã mua) → xóa shopping_tick trong local_ingredients
          // vì _syncFridgeItems() sẽ pull data thật từ server về sau
          if (item.isPurchased) {
            await _ingredientSvc.clearShoppingTickByName(item.ingredientName);
          }
          debugPrint('[BackgroundSync] ✓ Shopping toggle "${item.ingredientName}" synced (isPurchased: ${item.isPurchased}).');
        } catch (e) {
          // Giữ lại pending_toggle để thử lại lần sau
          debugPrint('[BackgroundSync] ✗ Could not sync toggle "${item.ingredientName}": $e');
        }
      }
    } catch (e) {
      debugPrint('[BackgroundSync] ✗ Pending shopping toggle sync failed: $e');
    }
  }

  // ── 11. Sync nấu xong offline → PATCH /meal-planning/slots/:id ──────────────
  Future<void> _syncPendingSlotCompletions() async {
    try {
      final pending = await _slotCompletionSvc.getPendingCompletions();
      if (pending.isEmpty) return;

      debugPrint('[BackgroundSync] Found ${pending.length} pending slot completion(s) to sync...');
      bool anySuccess = false;
      for (final row in pending) {
        final slotId = row['slot_id'] as String? ?? '';
        final completed = (row['completed'] as int? ?? 1) == 1;
        if (slotId.isEmpty) continue;
        try {
          await _api.updateMealSlot(slotId: slotId, completed: completed);
          await _slotCompletionSvc.deletePendingCompletion(slotId);
          anySuccess = true;
          debugPrint('[BackgroundSync] ✓ Pending slot completion slotId=$slotId synced (completed=$completed).');
        } catch (e) {
          // Giữ lại để thử lại lần sau
          debugPrint('[BackgroundSync] ✗ Could not sync slot completion slotId=$slotId: $e');
        }
      }

      // Nếu có bất kỳ slot nào sync thành công → pull lại plan để cập nhật SQLite
      if (anySuccess) {
        await _refreshWeeklyPlanCache();
      }
    } catch (e) {
      debugPrint('[BackgroundSync] ✗ Pending slot completions sync failed: $e');
    }
  }

  /// Pull lại plan mới nhất từ server và lưu vào local_weekly_plans
  Future<void> _refreshWeeklyPlanCache() async {
    try {
      final plans = await _api.getMealPlans();
      if (plans.isEmpty) return;
      plans.sort((a, b) {
        final dateA = DateTime.tryParse((a as Map)['createdAt']?.toString() ?? '') ?? DateTime(1970);
        final dateB = DateTime.tryParse((b as Map)['createdAt']?.toString() ?? '') ?? DateTime(1970);
        return dateB.compareTo(dateA);
      });
      final planId = (plans.first as Map)['id']?.toString();
      if (planId == null) return;
      final detail = await _api.getMealPlanDetail(planId);
      final dailyList = (detail['dailyPlans'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      await _weeklyPlanSvc.saveWeeklyPlanOverwrite(
        LocalWeeklyPlanModel(
          id: planId,
          weekStartDate: detail['weekStartDate']?.toString() ?? '',
          daysDataJson: jsonEncode(dailyList),
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      debugPrint('[BackgroundSync] ✓ Weekly plan cache refreshed after slot sync.');
    } catch (e) {
      debugPrint('[BackgroundSync] ✗ Weekly plan cache refresh failed: $e');
    }
  }

  /// Sync c\u00e1c thao t\u00e1c nguy\u00ean li\u1ec7u pending khi offline: update/consume/delete
  Future<void> _syncPendingFridgeOps() async {
    try {
      final ops = await _fridgeOpsSvc.getPendingOps();
      if (ops.isEmpty) return;
      debugPrint('[BackgroundSync] ▶ Syncing ${ops.length} pending fridge ops...');

      for (final op in ops) {
        final itemId = op['item_id'] as String? ?? '';
        final actionStr = op['action'] as String? ?? '';
        if (itemId.isEmpty) continue;

        try {
          final action = FridgeOpAction.values.firstWhere(
            (e) => e.name == actionStr,
            orElse: () => FridgeOpAction.update,
          );

          switch (action) {
            case FridgeOpAction.update:
              final qty = (op['quantity'] as num?)?.toDouble() ?? 1.0;
              final unit = op['unit'] as String? ?? '';
              await _api.updateFridgeItem(itemId, {'quantity': qty, 'unit': unit});
              debugPrint('[BackgroundSync] ✓ Fridge update synced: $itemId ($qty $unit)');
              break;
            case FridgeOpAction.consume:
              await _api.consumeFridgeItem(itemId);
              debugPrint('[BackgroundSync] ✓ Fridge consume synced: $itemId');
              break;
            case FridgeOpAction.delete:
              await _api.deleteFridgeItem(itemId);
              debugPrint('[BackgroundSync] ✓ Fridge delete synced: $itemId');
              break;
          }
          // Xóa pending sau khi sync thành công
          await _fridgeOpsSvc.deletePendingOp(itemId);
        } catch (e) {
          debugPrint('[BackgroundSync] ✗ Fridge op failed for $itemId: $e');
          // Gi\u1eef l\u1ea1i pending \u0111\u1ec3 retry l\u1ea7n sau
        }
      }

      // Pull l\u1ea1i danh s\u00e1ch t\u1eeb server v\u00e0 l\u01b0u v\u00e0o SQLite
      try {
        final items = await _api.getFridgeItems();
        final localItems = items.map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          final daysRaw = m['daysUntilExpiry'];
          final days = daysRaw is int ? daysRaw : (int.tryParse(daysRaw?.toString() ?? ''));
          return LocalIngredientModel(
            id: m['id']?.toString() ?? '',
            ingredientId: 0,
            name: m['ingredientName']?.toString() ?? m['name']?.toString() ?? '',
            quantity: (m['quantity'] as num?)?.toDouble() ?? 1.0,
            unit: m['unit']?.toString() ?? '',
            storageLocation: m['storageLocation']?.toString() ?? '',
            expiresAt: m['expiresAt']?.toString(),
            daysUntilExpiry: days,
            imagePath: m['imagePath']?.toString(),
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          );
        }).toList();
        await _ingredientSvc.saveIngredientsCache(localItems);
        debugPrint('[BackgroundSync] ✓ Fridge cache refreshed after ops sync.');
      } catch (e) {
        debugPrint('[BackgroundSync] ✗ Fridge cache refresh failed: $e');
      }
    } catch (e) {
      debugPrint('[BackgroundSync] ✗ _syncPendingFridgeOps error: $e');
    }
  }
}
