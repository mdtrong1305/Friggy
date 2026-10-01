class AppConstants {
  AppConstants._();

  // Network Configuration
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.friggy.io.vn/api/v1',
  );

  static String get serverBaseUrl {
    if (baseUrl.endsWith('/api/v1')) {
      return baseUrl.substring(0, baseUrl.length - '/api/v1'.length);
    }
    return baseUrl;
  }

  static String get fileBaseUrl {
    const override = String.fromEnvironment('FILE_BASE_URL');
    if (override.isNotEmpty) return override;
    if (baseUrl.contains('api.friggy.io.vn')) {
      return 'https://file.friggy.io.vn';
    }
    return serverBaseUrl;
  }

  static String? getImageUrl(String? url) {
    if (url == null) return null;
    final trimmed = url.trim();
    if (trimmed.isEmpty || trimmed == 'null') return null;

    String formatted = trimmed;

    if (formatted.contains('api.friggy.io.vn')) {
      formatted = formatted.replaceAll('api.friggy.io.vn', 'file.friggy.io.vn');
    }

    if (formatted.startsWith('http://') || formatted.startsWith('https://')) {
      return formatted;
    }

    if (formatted.startsWith('file.friggy.io.vn')) {
      return 'https://$formatted';
    }

    final leadingSlash = formatted.startsWith('/') ? '' : '/';
    return '$fileBaseUrl$leadingSlash$formatted';
  }

  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: '717739810642-4neqbd4q4v3i65hup78shtn557u80d3s.apps.googleusercontent.com',
  );
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Storage Keys
  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUserId = 'user_id';
  static const String keyUserData = 'user_data';

  // API Endpoints - Auth & Users
  static const String epAuthGoogle = '/auth/google';
  static const String epAuthEmailRegister = '/auth/email/register';
  static const String epAuthEmailVerifyOtp = '/auth/email/verify-otp';
  static const String epAuthEmailLogin = '/auth/email/login';
  static const String epAuthEmailForgotPassword = '/auth/email/forgot-password';
  static const String epAuthEmailResetPassword = '/auth/email/reset-password';
  static const String epAuthEmailChangePassword = '/auth/email/change-password';
  static const String epAuthPhoneSendOtp = '/auth/phone/send-otp';
  static const String epAuthPhoneVerify = '/auth/phone/verify';
  static const String epAuthRefreshToken = '/auth/refresh';
  static const String epAuthLogout = '/auth/logout';

  static const String epUsersMe = '/users/me';
  static const String epUsersProfile = '/users/me/profile';
  static const String epUsersAvatar = '/users/me/avatar';
  static const String epUsersPreferences = '/users/me/preferences';
  static const String epUsersAllergies = '/users/me/allergies';
  static const String epUsersAiUsage = '/users/me/ai-usage';
  static const String epUsersNotificationSettings =
      '/users/me/notification-settings';
  static const String epUsersOnboarding = '/users/me/onboarding';

  static const String epIngredients = '/ingredients';
  static const String epIngredientCategories = '/ingredients/categories';

  static const String epFridgeItems = '/fridge/items';
  static const String epFridge = '/fridge';
  static const String epFridgeExpiring = '/fridge/expiring';
  static const String epFridgeStats = '/fridge/stats';
  static const String epFridgeStatsChart = '/fridge/stats/chart';
  static const String epFridgeScanImage = '/fridge/scan/image';
  static const String epFridgeScanReceipt = '/fridge/scan/receipt';
  static const String epFridgeScanBarcode = '/fridge/scan/barcode';
  static const String epFridgeScanHistory = '/fridge/scan/history';

  static const String epRecipes = '/recipes';
  static const String epRecipeDetail = '/recipes'; // + /{id}

  static const String epWeeklyPlans = '/weekly-plans';
  static const String epMealPlanningGenerate = '/meal-planning/plans/generate';
  static const String epMealPlanningGenerateExpiring =
      '/meal-planning/plans/generate-from-expiring';
  static const String epMealPlanningPlans = '/meal-planning/plans';
  static const String epMealPlanningShoppingLists =
      '/meal-planning/shopping-lists';
  static const String epChatSessions = '/chat/sessions';
  static const String epAiChatSessions = '/ai-chat/sessions';

  // Subscriptions APIs
  static const String epSubscriptionsPlans = '/subscriptions/plans';
  static const String epSubscriptionsMe = '/subscriptions/me';
  static const String epSubscriptionsSubscribe = '/subscriptions/subscribe';
  static const String epSubscriptionsRenew = '/subscriptions/renew';
  static const String epSubscriptionsAutoRenewal =
      '/subscriptions/me/auto-renewal';
  static const String epSubscriptionsWebhook = '/subscriptions/webhook';

  // Notifications APIs
  static const String epNotifications = '/notifications';
  static const String epNotificationsUnreadCount =
      '/notifications/unread-count';
  static const String epNotificationsReadAll = '/notifications/read-all';

  // Family APIs
  static const String epFamilyMe = '/family/me';
  static const String epFamilyInvite = '/family/invite';
  static const String epFamilyAccept = '/family/accept';
  static const String epFamilyReject = '/family/reject';
  static const String epFamilyMembers = '/family/members';
  static const String epFamilyGroups = '/family/groups';

  // FCM Token APIs
  static const String epFcmToken = '/notifications/fcm-token';
}
