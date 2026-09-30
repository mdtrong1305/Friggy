import 'dart:io';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import 'api_service.dart';
import '../local/storage_service.dart';
import '../../utils/navigation_service.dart';
import '../../screens/fridge_inventory_screen.dart';
import '../../screens/next_week_suggestions_screen.dart';
import '../../screens/package_management_screen.dart';
import '../../screens/my_fridges_screen.dart';

// Top-level background handler — MUST be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM Background] messageId=${message.messageId} data=${message.data}');
}

/// NotificationService — Singleton quan ly toan bo FCM push notification
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final ApiService _apiService = ApiService();
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Android notification channel
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'friggy_high_importance_channel',
    'Thong bao Friggy',
    description: 'Thong bao het han, thuc don tuan va goi dich vu tu Friggy',
    importance: Importance.high,
    playSound: true,
  );

  // -------------------------------------------------------
  // 1. Init & Register — goi sau khi dang nhap thanh cong
  // -------------------------------------------------------

  Future<void> initAndRegister() async {
    if (_initialized) {
      await _refreshAndRegisterToken();
      return;
    }

    try {
      // Buoc 1: Xin quyen notification
      final granted = await _requestPermission();
      if (!granted) {
        debugPrint('[NotificationService] Quyen notification bi tu choi');
      }

      // Buoc 2: Setup Android notification channel
      await _setupLocalNotifications();

      // Buoc 3: Lay FCM token va dang ky len BE
      await _refreshAndRegisterToken();

      // Buoc 4: Lang nghe khi Firebase tu rotate token
      _fcm.onTokenRefresh.listen((newToken) async {
        debugPrint('[NotificationService] Token refreshed, re-registering...');
        await _registerTokenToBackend(newToken);
      });

      // Buoc 5: Xu ly notification khi app FOREGROUND
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Buoc 6: Xu ly khi user TAP notification — app BACKGROUND
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Buoc 7: Xu ly khi user TAP notification — app TERMINATED
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        await Future.delayed(const Duration(milliseconds: 500));
        _handleNotificationTap(initialMessage);
      }

      _initialized = true;
      debugPrint('[NotificationService] FCM khoi tao thanh cong');
    } catch (e) {
      debugPrint('[NotificationService] Loi khoi tao: $e');
    }
  }

  // -------------------------------------------------------
  // 2. Unregister — goi khi logout
  // -------------------------------------------------------

  Future<void> unregister() async {
    try {
      final token = await _fcm.getToken();
      if (token != null && token.isNotEmpty) {
        await _apiService.unregisterFcmToken(token);
        debugPrint('[NotificationService] Da unregister FCM token');
      }
    } catch (e) {
      debugPrint('[NotificationService] Loi unregister FCM token: $e');
    } finally {
      _initialized = false;
    }
  }

  // -------------------------------------------------------
  // 3. Kiem tra quyen & mo Settings
  // -------------------------------------------------------

  Future<bool> isPermissionGranted() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      return status.isGranted;
    }
    final settings = await _fcm.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  Future<void> openNotificationSettings() async {
    await openAppSettings();
  }

  // -------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------

  Future<bool> _requestPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      debugPrint('[NotificationService] Permission status: ${status.name}');
      return status.isGranted;
    }
    final settings = await _fcm.requestPermission(alert: true, badge: true, sound: true);
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  Future<void> _setupLocalNotifications() async {
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        _navigateFromPayload(details.payload);
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// Lay FCM token hien tai (public)
  Future<String?> getToken() => _fcm.getToken();

  Future<void> _refreshAndRegisterToken() async {
    try {
      final token = await _fcm.getToken();
      if (token == null || token.isEmpty) return;
      debugPrint('[NotificationService] FCM Token (full): $token');
      // Auto copy to clipboard de test voi Firebase Console
      await Clipboard.setData(ClipboardData(text: token));
      debugPrint('[NotificationService] FCM Token da copy vao clipboard!');
      await _registerTokenToBackend(token);
    } catch (e) {
      debugPrint('[NotificationService] Loi lay FCM token: $e');
    }
  }

  Future<void> _registerTokenToBackend(String token) async {
    try {
      final storage = await StorageService.getInstance();
      final accessToken = storage.getAccessToken();
      if (accessToken == null || accessToken.isEmpty) return;
      await _apiService.registerFcmToken(token: token, platform: 'android');
      debugPrint('[NotificationService] Da dang ky FCM token len BE');
    } catch (e) {
      debugPrint('[NotificationService] Loi dang ky token len BE: $e');
    }
  }

  // -------------------------------------------------------
  // Foreground notification — hien local banner
  // -------------------------------------------------------

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[NotificationService] Foreground: ${message.messageId}');
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
        ),
      ),
      payload: message.data['screen'] as String?,
    );
  }

  // -------------------------------------------------------
  // Deep link navigation khi tap notification
  // -------------------------------------------------------

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('[NotificationService] Notification tapped: ${message.data}');
    _navigateFromPayload(message.data['screen'] as String?);
  }

  void _navigateFromPayload(String? screen) {
    final navigator = NavigationService.navigatorKey.currentState;
    if (navigator == null) return;

    switch (screen) {
      case 'fridge':
        navigator.push(MaterialPageRoute(
          builder: (_) => FridgeInventoryScreen(
            fridge: FridgeModel(
              id: 'family',
              name: 'Tu lanh',
              description: 'Tu lanh chinh',
              totalItems: 0,
              expiringItems: 0,
              themeColor: const Color(0xFF006428),
            ),
            onRename: () {},
            isEmbedded: false,
          ),
        ));
        break;
      case 'meal_planning':
        navigator.push(MaterialPageRoute(
          builder: (_) => const NextWeekSuggestionsScreen(),
        ));
        break;
      case 'subscription':
        navigator.push(MaterialPageRoute(
          builder: (_) => const PackageManagementScreen(),
        ));
        break;
      default:
        debugPrint('[NotificationService] Tap: screen=$screen, ve home');
    }
  }
}


