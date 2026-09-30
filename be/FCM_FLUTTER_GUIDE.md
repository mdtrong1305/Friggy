# 🔔 Hướng dẫn tích hợp FCM Push Notification (Flutter)

> **Backend đã sẵn sàng.** Tài liệu này hướng dẫn phía **Frontend (Flutter)** cách kết nối với hệ thống push notification của Friggy.

---

## 1. Cài đặt package

```yaml
# pubspec.yaml
dependencies:
  firebase_core: ^3.x.x
  firebase_messaging: ^15.x.x
```

```bash
flutter pub get
```

---

## 2. Cấu hình Firebase project

### Android

1. Vào [Firebase Console](https://console.firebase.google.com) → Project **Friggy** → **Project Settings**
2. Chọn tab **"Your apps"** → Add app → Android
3. Nhập package name (ví dụ: `vn.friggy.app`)
4. Tải file `google-services.json` → đặt vào `android/app/`
5. Sửa `android/build.gradle`:
   ```gradle
   dependencies {
     classpath 'com.google.gms:google-services:4.4.x'
   }
   ```
6. Sửa `android/app/build.gradle`:
   ```gradle
   apply plugin: 'com.google.gms.google-services'
   ```

### iOS

1. Firebase Console → Add app → iOS
2. Nhập Bundle ID → tải `GoogleService-Info.plist` → đặt vào `ios/Runner/`
3. Trong Xcode: **Signing & Capabilities** → thêm **Push Notifications** + **Background Modes** (tick "Remote notifications")

---

## 3. Khởi tạo Firebase trong app

```dart
// main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Handler background message (phải là top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Xử lý notification khi app đóng hoặc background
  print('Background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Đăng ký background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(MyApp());
}
```

---

## 4. Xin quyền và lấy FCM Token

```dart
// notification_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Gọi sau khi user đăng nhập thành công
  Future<void> initAndRegister(String accessToken) async {
    // 1. Xin quyền (iOS bắt buộc, Android 13+ cần)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      print('User từ chối nhận notification');
      return;
    }

    // 2. Lấy FCM Token
    final token = await _messaging.getToken();
    if (token == null) return;

    print('FCM Token: $token');

    // 3. Gửi token lên backend
    await _registerTokenToBackend(token, accessToken);

    // 4. Lắng nghe khi token bị refresh (Firebase tự rotate)
    _messaging.onTokenRefresh.listen((newToken) {
      _registerTokenToBackend(newToken, accessToken);
    });
  }

  /// POST /api/v1/notifications/fcm-token
  Future<void> _registerTokenToBackend(String token, String accessToken) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.friggy.io.vn/api/v1/notifications/fcm-token'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'token': token,
          'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
          'deviceName': await _getDeviceName(), // optional
        }),
      );
      print('Register FCM token: ${response.statusCode}');
    } catch (e) {
      print('Lỗi register FCM token: $e');
    }
  }

  /// DELETE /api/v1/notifications/fcm-token — Gọi khi logout
  Future<void> unregisterToken(String accessToken) async {
    final token = await _messaging.getToken();
    if (token == null) return;

    try {
      await http.delete(
        Uri.parse('https://api.friggy.io.vn/api/v1/notifications/fcm-token'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'token': token}),
      );
      print('Unregister FCM token thành công');
    } catch (e) {
      print('Lỗi unregister FCM token: $e');
    }
  }
}
```

---

## 5. Xử lý notification

```dart
// Trong initState() của widget gốc hoặc sau khi init Firebase

// Khi app đang MỞ (foreground)
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  final notification = message.notification;
  if (notification != null) {
    // Hiện snackbar / in-app banner
    showInAppBanner(
      title: notification.title ?? '',
      body: notification.body ?? '',
    );
  }
});

// Khi user TAP vào notification (app background → foreground)
FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
  _handleNotificationTap(message.data);
});

// Khi user TAP notification lúc app ĐANG ĐÓNG
final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
if (initialMessage != null) {
  _handleNotificationTap(initialMessage.data);
}
```

---

## 6. Deep link từ notification data

Backend gửi kèm `data` payload với `screen` để navigate:

```dart
void _handleNotificationTap(Map<String, dynamic> data) {
  final type = data['type'] as String?;
  final screen = data['screen'] as String?;

  switch (screen) {
    case 'fridge':
      // Navigate đến màn hình Tủ lạnh
      Navigator.pushNamed(context, '/fridge');
      break;
    case 'meal_planning':
      // Navigate đến màn hình Thực đơn
      Navigator.pushNamed(context, '/meal-planning');
      break;
    case 'subscription':
      // Navigate đến màn hình Gói dịch vụ
      Navigator.pushNamed(context, '/subscription');
      break;
    default:
      // Về trang chủ
      Navigator.pushNamed(context, '/home');
  }
}
```

---

## 7. Khi nào gọi API nào?

| Thời điểm                             | Action                                                       |
| ------------------------------------- | ------------------------------------------------------------ |
| Sau khi **đăng nhập** thành công      | `initAndRegister(accessToken)`                               |
| Token **tự refresh** (onTokenRefresh) | Tự động — đã handle trong `initAndRegister`                  |
| Khi **logout**                        | `unregisterToken(accessToken)` **trước** khi xóa token local |
| App mở lại sau thời gian dài          | Gọi `_messaging.getToken()` để check token còn valid không   |

---

## 8. Notification types từ backend

Backend gửi các loại notification sau, kèm `data.type`:

| `type`                  | Khi nào                                    | `screen`        |
| ----------------------- | ------------------------------------------ | --------------- |
| `expiry_warning`        | Nguyên liệu sắp hết hạn (hàng ngày 8:00)   | `fridge`        |
| `weekly_remind`         | Chưa lập thực đơn tuần mới (Chủ Nhật 9:00) | `meal_planning` |
| `subscription_reminder` | Gói dịch vụ sắp hết hạn (hàng ngày 9:00)   | `subscription`  |

---

## 9. Test notification

Sau khi deploy, test bằng cách:

1. Đăng nhập app → lấy FCM token từ log
2. Vào [Firebase Console](https://console.firebase.google.com) → **Engage** → **Messaging** → **Send test message**
3. Paste FCM token → gửi thử

Hoặc trigger thủ công qua API admin:

```
POST /api/v1/admin/cron-jobs/expiry_warning/trigger
Authorization: Bearer <admin_token>
```

---

## ⚠️ Lưu ý quan trọng

- **Không lưu FCM token** vào local storage dài hạn — luôn lấy fresh từ `FirebaseMessaging.getToken()`
- **Luôn gọi `unregisterToken` khi logout** để tránh notification gửi nhầm sau khi user đổi tài khoản
- `google-services.json` và `GoogleService-Info.plist` là **public config** — có thể commit lên git (khác với service account key ở backend)
- Background handler phải là **top-level function** (không phải method trong class)
