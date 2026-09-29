import 'package:flutter/foundation.dart';
import '../../config/app_constants.dart';
import 'dio_client.dart';

class ApiService {
  final DioClient _dioClient;

  ApiService({DioClient? dioClient}) : _dioClient = dioClient ?? DioClient();

  // ------------------------------------------------------------------
  // Authentication APIs
  // ------------------------------------------------------------------

  /// Authenticate with Google idToken
  Future<Map<String, dynamic>> loginWithGoogle(String idToken) async {
    final response = await _dioClient.post(
      AppConstants.epAuthGoogle,
      data: {'idToken': idToken},
      skipAuth: true,
    );
    return response as Map<String, dynamic>;
  }

  /// Step 1: Register with Email -> sends OTP
  Future<Map<String, dynamic>> emailRegister(String email) async {
    final response = await _dioClient.post(
      AppConstants.epAuthEmailRegister,
      data: {'email': email},
      skipAuth: true,
    );
    return response as Map<String, dynamic>;
  }

  /// Step 2: Verify OTP -> activates account & receives JWT tokens
  Future<Map<String, dynamic>> verifyEmailOtp({
    required String email,
    required String otpCode,
    required String password,
    String? name,
  }) async {
    final data = <String, dynamic>{
      'email': email,
      'otpCode': otpCode,
      'password': password,
    };
    if (name != null && name.trim().isNotEmpty) {
      data['name'] = name.trim();
    }
    final response = await _dioClient.post(
      AppConstants.epAuthEmailVerifyOtp,
      data: data,
      skipAuth: true,
    );
    return response as Map<String, dynamic>;
  }

  /// Login with email + password
  Future<Map<String, dynamic>> emailLogin(String email, String password) async {
    final response = await _dioClient.post(
      AppConstants.epAuthEmailLogin,
      data: {'email': email, 'password': password},
      skipAuth: true,
    );
    return response as Map<String, dynamic>;
  }

  /// Request forgot password OTP to email
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final response = await _dioClient.post(
      AppConstants.epAuthEmailForgotPassword,
      data: {'email': email},
      skipAuth: true,
    );
    return response as Map<String, dynamic>;
  }

  /// Reset password with OTP + new password
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String otpCode,
    required String newPassword,
  }) async {
    final response = await _dioClient.post(
      AppConstants.epAuthEmailResetPassword,
      data: {
        'email': email,
        'otpCode': otpCode,
        'newPassword': newPassword,
      },
      skipAuth: true,
    );
    return response as Map<String, dynamic>;
  }

  /// POST /auth/email/change-password - Change password for logged-in user
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _dioClient.post(
      AppConstants.epAuthEmailChangePassword,
      data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
    return response as Map<String, dynamic>;
  }

  /// Send OTP to phone number
  Future<dynamic> sendPhoneOtp(String phone) async {
    return await _dioClient.post(
      AppConstants.epAuthPhoneSendOtp,
      data: {'phone': phone},
      skipAuth: true,
    );
  }

  /// Verify phone OTP
  Future<Map<String, dynamic>> verifyPhoneOtp(String phone, String otp) async {
    final response = await _dioClient.post(
      AppConstants.epAuthPhoneVerify,
      data: {'phone': phone, 'otpCode': otp},
      skipAuth: true,
    );
    return response as Map<String, dynamic>;
  }

  /// Logout and revoke refresh token
  Future<dynamic> logout(String refreshToken) async {
    return await _dioClient.post(
      AppConstants.epAuthLogout,
      data: {'refreshToken': refreshToken},
    );
  }

  // ------------------------------------------------------------------
  // Users APIs (/users/me/*)
  // ------------------------------------------------------------------

  /// GET /users/me - Get current user profile & details
  Future<Map<String, dynamic>> getMe() async {
    final response = await _dioClient.get(AppConstants.epUsersMe);
    return response as Map<String, dynamic>;
  }

  /// PATCH /users/me/profile - Update name, gender, dateOfBirth, bio
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> profileData) async {
    final response = await _dioClient.patch(
      AppConstants.epUsersProfile,
      data: profileData,
    );
    return response as Map<String, dynamic>;
  }

  /// POST /users/me/avatar - Upload avatar image (fileKey: 'file')
  Future<Map<String, dynamic>> uploadAvatar(String filePath) async {
    final response = await _dioClient.uploadFile(
      AppConstants.epUsersAvatar,
      filePath: filePath,
      fileKey: 'file',
    );
    return response as Map<String, dynamic>;
  }

  /// GET /users/me/preferences - Get user dietary, skill & budget preferences
  Future<Map<String, dynamic>?> getPreferences() async {
    final response = await _dioClient.get(AppConstants.epUsersPreferences);
    return response as Map<String, dynamic>?;
  }

  /// PATCH /users/me/preferences - Update user preferences
  Future<Map<String, dynamic>> updatePreferences(Map<String, dynamic> preferencesData) async {
    final response = await _dioClient.patch(
      AppConstants.epUsersPreferences,
      data: preferencesData,
    );
    return response as Map<String, dynamic>;
  }

  /// GET /users/me/allergies - Get list of food allergies
  Future<List<dynamic>> getAllergies() async {
    final response = await _dioClient.get(AppConstants.epUsersAllergies);
    return response as List<dynamic>;
  }

  /// POST /users/me/allergies - Add a food allergy
  Future<Map<String, dynamic>> addAllergy(int ingredientId, String? note) async {
    final response = await _dioClient.post(
      AppConstants.epUsersAllergies,
      data: {
        'ingredientId': ingredientId,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    return response as Map<String, dynamic>;
  }

  /// DELETE /users/me/allergies/:id - Remove food allergy
  Future<void> removeAllergy(String allergyId) async {
    await _dioClient.delete('${AppConstants.epUsersAllergies}/$allergyId');
  }

  /// GET /users/me/ai-usage - Get current week AI usage stats
  Future<Map<String, dynamic>> getAiUsage() async {
    final response = await _dioClient.get(AppConstants.epUsersAiUsage);
    return response as Map<String, dynamic>;
  }

  /// GET /users/me/notification-settings - Get notification settings
  Future<Map<String, dynamic>> getNotificationSettings() async {
    final response = await _dioClient.get(AppConstants.epUsersNotificationSettings);
    return response as Map<String, dynamic>;
  }

  /// PATCH /users/me/notification-settings - Update notification settings
  Future<Map<String, dynamic>> updateNotificationSettings(Map<String, dynamic> settingsData) async {
    final response = await _dioClient.patch(
      AppConstants.epUsersNotificationSettings,
      data: settingsData,
    );
    return response as Map<String, dynamic>;
  }

  /// POST /users/me/onboarding - Complete onboarding survey
  Future<Map<String, dynamic>> completeOnboarding(Map<String, dynamic> onboardingData) async {
    final response = await _dioClient.post(
      AppConstants.epUsersOnboarding,
      data: onboardingData,
    );
    return response as Map<String, dynamic>;
  }

  // ------------------------------------------------------------------
  // Ingredients & Categories
  // ------------------------------------------------------------------

  /// Get list of ingredients
  Future<List<dynamic>> getIngredients({int? categoryId, String? search, int limit = 100, int skip = 0}) async {
    final queryParams = <String, dynamic>{'limit': limit};
    if (skip > 0) queryParams['skip'] = skip;
    if (categoryId != null) queryParams['categoryId'] = categoryId;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final response = await _dioClient.get(
      AppConstants.epIngredients,
      queryParameters: queryParams,
    );
    if (response is Map<String, dynamic> && response.containsKey('data') && response['data'] is List) {
      return response['data'] as List<dynamic>;
    }
    if (response is List<dynamic>) {
      return response;
    }
    return [];
  }

  /// Get ingredient categories
  Future<List<dynamic>> getIngredientCategories() async {
    final response = await _dioClient.get(AppConstants.epIngredientCategories);
    return response as List<dynamic>;
  }

  // ------------------------------------------------------------------
  // Fridge Management
  // ------------------------------------------------------------------

  /// GET /fridge - Get list of items currently in the fridge
  Future<List<dynamic>> getFridgeItems({String? storageLocation, bool? expiringSoon}) async {
    final queryParams = <String, dynamic>{};
    if (storageLocation != null && storageLocation.isNotEmpty) {
      queryParams['storageLocation'] = storageLocation;
    }
    if (expiringSoon != null) {
      queryParams['expiringSoon'] = expiringSoon;
    }

    final response = await _dioClient.get(
      AppConstants.epFridge,
      queryParameters: queryParams,
    );
    if (response is List<dynamic>) {
      return response;
    }
    return [];
  }

  /// POST /fridge/items - Add item to fridge
  Future<Map<String, dynamic>> addFridgeItem(Map<String, dynamic> itemData) async {
    final response = await _dioClient.post(
      AppConstants.epFridgeItems,
      data: itemData,
    );
    return response as Map<String, dynamic>;
  }

  /// PATCH /fridge/items/:id - Update item (quantity, unit, expiresAt, storageLocation)
  Future<Map<String, dynamic>> updateFridgeItem(String id, Map<String, dynamic> updateData) async {
    final response = await _dioClient.patch(
      '${AppConstants.epFridgeItems}/$id',
      data: updateData,
    );
    return response as Map<String, dynamic>;
  }

  /// DELETE /fridge/items/:id - Soft delete item from fridge
  Future<void> deleteFridgeItem(String id) async {
    await _dioClient.delete('${AppConstants.epFridgeItems}/$id');
  }

  /// PATCH /fridge/items/:id/consume - Mark item as consumed ("Đã dùng hết")
  Future<Map<String, dynamic>> consumeFridgeItem(String id) async {
    final response = await _dioClient.patch('${AppConstants.epFridgeItems}/$id/consume');
    return response as Map<String, dynamic>;
  }

  /// GET /fridge/expiring - Get expiring items in N days
  Future<List<dynamic>> getExpiringFridgeItems({int days = 3}) async {
    final response = await _dioClient.get(
      AppConstants.epFridgeExpiring,
      queryParameters: {'days': days},
    );
    if (response is List<dynamic>) return response;
    return [];
  }

  /// GET /fridge/stats - Get overall stats (spent, waste %, meals cooked, counts)
  Future<Map<String, dynamic>> getFridgeStats() async {
    final response = await _dioClient.get(AppConstants.epFridgeStats);
    return response as Map<String, dynamic>;
  }

  /// GET /fridge/stats/chart - Get spending & waste chart data (week/month)
  Future<Map<String, dynamic>> getFridgeStatsChart({String period = 'week'}) async {
    final response = await _dioClient.get(
      AppConstants.epFridgeStatsChart,
      queryParameters: {'period': period},
    );
    return response as Map<String, dynamic>;
  }

  // ------------------------------------------------------------------
  // AI Scan APIs (/fridge/scan/*)
  // ------------------------------------------------------------------

  /// POST /fridge/scan/image - Scan food photo
  Future<Map<String, dynamic>> scanFoodImage(String filePath) async {
    final response = await _dioClient.uploadFile(
      AppConstants.epFridgeScanImage,
      filePath: filePath,
      fileKey: 'file',
    );
    return response as Map<String, dynamic>;
  }

  /// POST /fridge/scan/receipt - Scan receipt
  Future<Map<String, dynamic>> scanReceiptImage(String filePath) async {
    final response = await _dioClient.uploadFile(
      AppConstants.epFridgeScanReceipt,
      filePath: filePath,
      fileKey: 'file',
    );
    return response as Map<String, dynamic>;
  }

  /// POST /fridge/scan/barcode - Scan barcode
  Future<Map<String, dynamic>> scanBarcodeImage(String filePath) async {
    final response = await _dioClient.uploadFile(
      AppConstants.epFridgeScanBarcode,
      filePath: filePath,
      fileKey: 'file',
    );
    return response as Map<String, dynamic>;
  }

  /// GET /fridge/scan/:scanId - Poll scan status
  Future<Map<String, dynamic>> getScanStatus(String scanId) async {
    final response = await _dioClient.get('/fridge/scan/$scanId');
    return response as Map<String, dynamic>;
  }

  /// POST /fridge/scan/:scanId/confirm - Confirm scan items into fridge
  Future<List<dynamic>> confirmScan(String scanId, List<Map<String, dynamic>> items) async {
    try {
      if (scanId.isNotEmpty && !scanId.startsWith('barcode_')) {
        final response = await _dioClient.post(
          '/fridge/scan/$scanId/confirm',
          data: {'items': items},
        );
        if (response is List<dynamic>) return response;
      }
    } catch (e) {
      debugPrint('[ApiService confirmScan] Scan confirm API error: $e, falling back to direct item creation.');
    }

    // Fallback: Add items individually directly to fridge
    final List<dynamic> resultList = [];
    for (final item in items) {
      try {
        final added = await addFridgeItem(item);
        resultList.add(added);
      } catch (e) {
        debugPrint('[ApiService confirmScan] Fallback add item error: $e');
      }
    }
    return resultList;
  }

  /// GET /fridge/scan/history - Get scan history
  Future<List<dynamic>> getScanHistory() async {
    final response = await _dioClient.get(AppConstants.epFridgeScanHistory);
    if (response is List<dynamic>) return response;
    return [];
  }

  /// GET /recipes - Get list of recipes
  Future<List<dynamic>> getRecipes() async {
    try {
      final response = await _dioClient.get(AppConstants.epRecipes);
      if (response is Map<String, dynamic> && response.containsKey('data') && response['data'] is List) {
        return response['data'] as List<dynamic>;
      }
      if (response is List<dynamic>) return response;
    } catch (e) {
      debugPrint('[ApiService] Error fetching recipes: $e');
    }
    return [];
  }

  /// GET /recipes/:id - Get recipe detail (ingredients, steps, description)
  Future<Map<String, dynamic>> getRecipeDetail(String recipeId) async {
    final response = await _dioClient.get('${AppConstants.epRecipes}/$recipeId');
    return response as Map<String, dynamic>;
  }

  /// POST /meal-planning/plans/generate - Trigger AI weekly meal plan generation
  Future<Map<String, dynamic>> generateWeeklyPlan({
    String? weekStartDate,
    double? budget,
  }) async {
    final data = <String, dynamic>{};
    if (weekStartDate != null) data['weekStartDate'] = weekStartDate;
    if (budget != null) data['budget'] = budget;

    final response = await _dioClient.post(
      AppConstants.epMealPlanningGenerate,
      data: data,
    );
    return response as Map<String, dynamic>;
  }

  /// POST /meal-planning/plans/generate-from-expiring - Trigger AI plan from expiring ingredients
  Future<Map<String, dynamic>> generateFromExpiring({
    int withinDays = 3,
    int days = 1,
  }) async {
    final response = await _dioClient.post(
      AppConstants.epMealPlanningGenerateExpiring,
      data: {
        'withinDays': withinDays,
        'days': days,
      },
    );
    return response as Map<String, dynamic>;
  }

  /// GET /meal-planning/plans - Get user's meal plans
  Future<List<dynamic>> getMealPlans() async {
    final response = await _dioClient.get(AppConstants.epMealPlanningPlans);
    if (response is List<dynamic>) return response;
    return [];
  }

  /// GET /meal-planning/plans/:id - Get meal plan detail
  Future<Map<String, dynamic>> getMealPlanDetail(String planId) async {
    final response = await _dioClient.get('${AppConstants.epMealPlanningPlans}/$planId');
    return response as Map<String, dynamic>;
  }

  /// PATCH /meal-planning/plans/:id - Update plan status (confirmed/active/completed/draft)
  Future<Map<String, dynamic>> updateMealPlanStatus(String planId, String status) async {
    final response = await _dioClient.patch(
      '${AppConstants.epMealPlanningPlans}/$planId',
      data: {'status': status},
    );
    return response as Map<String, dynamic>;
  }

  /// DELETE /meal-planning/plans/:id - Soft delete plan
  Future<void> deleteMealPlan(String planId) async {
    await _dioClient.delete('${AppConstants.epMealPlanningPlans}/$planId');
  }

  /// PATCH /meal-planning/slots/:id - Update meal slot (change recipe / toggle completed)
  Future<Map<String, dynamic>> updateMealSlot({
    required String slotId,
    String? recipeId,
    int? servings,
    String? note,
    bool? completed,
  }) async {
    final data = <String, dynamic>{};
    if (recipeId != null) data['recipeId'] = recipeId;
    if (servings != null) data['servings'] = servings;
    if (note != null) data['note'] = note;
    if (completed != null) data['completed'] = completed;

    final response = await _dioClient.patch(
      '/meal-planning/slots/$slotId',
      data: data,
    );
    return response as Map<String, dynamic>;
  }

  /// POST /meal-planning/slots/:id/regenerate - AI regenerate slot alternative dish
  Future<Map<String, dynamic>> regenerateSlot({
    required String slotId,
    String? reason,
  }) async {
    final response = await _dioClient.post(
      '/meal-planning/slots/$slotId/regenerate',
      data: {'reason': reason ?? 'want_different'},
    );
    return response as Map<String, dynamic>;
  }

  /// GET /meal-planning/slots/:id - Get meal slot detail (recipe, ingredients, steps, fridge analysis)
  Future<Map<String, dynamic>> getSlotDetail(String slotId) async {
    final response = await _dioClient.get('/meal-planning/slots/$slotId');
    return response as Map<String, dynamic>;
  }

  // ------------------------------------------------------------------
  // Shopping Lists (/meal-planning/shopping-lists/*)
  // ------------------------------------------------------------------

  /// GET /meal-planning/shopping-lists - Get user's shopping lists
  Future<List<dynamic>> getShoppingLists() async {
    final response = await _dioClient.get(AppConstants.epMealPlanningShoppingLists);
    if (response is List<dynamic>) return response;
    return [];
  }

  /// POST /meal-planning/shopping-lists - Create shopping list from weekly plan
  Future<Map<String, dynamic>> createShoppingList({
    required String weeklyPlanId,
    String? title,
  }) async {
    final data = <String, dynamic>{'weeklyPlanId': weeklyPlanId};
    if (title != null && title.isNotEmpty) data['title'] = title;

    final response = await _dioClient.post(
      AppConstants.epMealPlanningShoppingLists,
      data: data,
    );
    return response as Map<String, dynamic>;
  }

  /// PATCH /meal-planning/shopping-lists/:listId/items/:itemId - Toggle item isPurchased
  Future<Map<String, dynamic>> toggleShoppingListItem({
    required String listId,
    required int itemId,
  }) async {
    final response = await _dioClient.patch(
      '${AppConstants.epMealPlanningShoppingLists}/$listId/items/$itemId',
    );
    return response as Map<String, dynamic>;
  }

  // ------------------------------------------------------------------
  // Subscriptions APIs (/subscriptions/*)
  // ------------------------------------------------------------------

  /// GET /subscriptions/plans - Get list of subscription plans (Free & Individual)
  Future<List<dynamic>> getSubscriptionPlans() async {
    final response = await _dioClient.get(AppConstants.epSubscriptionsPlans);
    if (response is List<dynamic>) return response;
    return [];
  }

  /// GET /subscriptions/me - Get current user active subscription
  Future<Map<String, dynamic>> getMySubscription() async {
    final response = await _dioClient.get(AppConstants.epSubscriptionsMe);
    return response as Map<String, dynamic>;
  }

  /// GET /payment-transactions/me - Lịch sử giao dịch thanh toán của user (paginated)
  Future<Map<String, dynamic>> getMyPaymentTransactions({int page = 1, int limit = 10}) async {
    final response = await _dioClient.get(
      '/payment-transactions/me',
      queryParameters: {'page': page, 'limit': limit},
    );
    return response as Map<String, dynamic>;
  }

  /// GET /payment-transactions/me/:paymentRef - Tra cứu trạng thái giao dịch theo paymentRef
  Future<Map<String, dynamic>> checkPaymentTransaction(String paymentRef) async {
    final response = await _dioClient.get('/payment-transactions/me/$paymentRef');
    return response as Map<String, dynamic>;
  }

  /// POST /subscriptions/subscribe - Subscribe to plan (returns payment QR mock)
  Future<Map<String, dynamic>> subscribePlan(int planId) async {
    final response = await _dioClient.post(
      AppConstants.epSubscriptionsSubscribe,
      data: {'planId': planId},
    );
    return response as Map<String, dynamic>;
  }

  /// POST /subscriptions/webhook - Public payment callback simulation
  Future<Map<String, dynamic>> simulatePaymentWebhook(String paymentRef, {bool isSuccess = true}) async {
    final response = await _dioClient.post(
      AppConstants.epSubscriptionsWebhook,
      data: {
        'paymentRef': paymentRef,
        'status': isSuccess ? 'success' : 'failed',
      },
      skipAuth: true,
    );
    return response as Map<String, dynamic>;
  }

  /// POST /subscriptions/renew - Renew subscription 1 month (returns payment QR mock)
  Future<Map<String, dynamic>> renewSubscription() async {
    final response = await _dioClient.post(AppConstants.epSubscriptionsRenew);
    return response as Map<String, dynamic>;
  }

  /// DELETE /subscriptions/me/auto-renewal - Cancel auto renewal
  Future<Map<String, dynamic>> cancelAutoRenewal() async {
    final response = await _dioClient.delete(AppConstants.epSubscriptionsAutoRenewal);
    return response as Map<String, dynamic>;
  }

  /// Deprecated alias: Cancel Individual subscription auto-renewal
  Future<Map<String, dynamic>> cancelSubscription() async {
    return await cancelAutoRenewal();
  }

  // ------------------------------------------------------------------
  // Notifications APIs (/notifications/*)
  // ------------------------------------------------------------------

  static final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);

  static void updateUnreadCount(int count) {
    unreadCountNotifier.value = count < 0 ? 0 : count;
  }

  /// GET /notifications/unread-count - Get unread notifications count
  Future<int> getUnreadNotificationCount() async {
    try {
      final response = await _dioClient.get(AppConstants.epNotificationsUnreadCount);
      if (response is Map<String, dynamic> && response.containsKey('count')) {
        final count = response['count'] as int? ?? 0;
        unreadCountNotifier.value = count;
        return count;
      }
    } catch (e) {
      debugPrint('[ApiService] Error fetching unread count: $e');
    }
    return unreadCountNotifier.value;
  }

  /// GET /notifications - Get paginated notifications list
  Future<Map<String, dynamic>> getNotifications({int page = 1, int limit = 20}) async {
    final response = await _dioClient.get(
      AppConstants.epNotifications,
      queryParameters: {'page': page, 'limit': limit},
    );
    if (response is Map<String, dynamic> && response.containsKey('unreadCount')) {
      final count = response['unreadCount'] as int? ?? 0;
      unreadCountNotifier.value = count;
    }
    return response as Map<String, dynamic>;
  }

  /// PATCH /notifications/read-all - Mark all notifications read
  Future<void> markAllNotificationsRead() async {
    await _dioClient.patch(AppConstants.epNotificationsReadAll);
    unreadCountNotifier.value = 0;
  }

  /// PATCH /notifications/:id/read - Mark one notification read
  Future<Map<String, dynamic>> markNotificationRead(String id) async {
    final response = await _dioClient.patch('${AppConstants.epNotifications}/$id/read');
    if (unreadCountNotifier.value > 0) {
      unreadCountNotifier.value = unreadCountNotifier.value - 1;
    }
    return response as Map<String, dynamic>;
  }

  /// DELETE /notifications/:id - Soft delete notification
  Future<void> deleteNotification(String id) async {
    await _dioClient.delete('${AppConstants.epNotifications}/$id');
  }

  // ------------------------------------------------------------------
  // Family APIs (/family/*)
  // ------------------------------------------------------------------

  /// GET /family/me - Get my family role and group info
  Future<Map<String, dynamic>> getMyFamily() async {
    final response = await _dioClient.get(AppConstants.epFamilyMe);
    return response as Map<String, dynamic>;
  }

  /// POST /family/invite - Invite member by email (Owner only)
  Future<Map<String, dynamic>> inviteFamilyMember(String email) async {
    final response = await _dioClient.post(
      AppConstants.epFamilyInvite,
      data: {'email': email},
    );
    return response as Map<String, dynamic>;
  }

  /// POST /family/accept - Accept invitation with token
  Future<Map<String, dynamic>> acceptFamilyInvite(String token) async {
    final response = await _dioClient.post(
      AppConstants.epFamilyAccept,
      data: {'token': token},
    );
    return response as Map<String, dynamic>;
  }

  /// POST /family/reject - Reject invitation with token
  Future<Map<String, dynamic>> rejectFamilyInvite(String token) async {
    final response = await _dioClient.post(
      AppConstants.epFamilyReject,
      data: {'token': token},
    );
    return response as Map<String, dynamic>;
  }

  /// DELETE /family/members/:memberId - Remove member from family (Owner only)
  Future<Map<String, dynamic>> removeFamilyMember(String memberId) async {
    final response = await _dioClient.delete('${AppConstants.epFamilyMembers}/$memberId');
    return response as Map<String, dynamic>;
  }

  /// DELETE /family/groups - Dissolve family group (Owner only)
  Future<Map<String, dynamic>> dissolveFamilyGroup() async {
    final response = await _dioClient.delete(AppConstants.epFamilyGroups);
    return response as Map<String, dynamic>;
  }
}

