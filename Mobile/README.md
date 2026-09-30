# 🥗 Friggy Mobile — Ứng Dụng Quản Lý Tủ Lạnh & Dinh Dưỡng Thông Minh

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" />
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" />
  <img src="https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black" />
  <img src="https://img.shields.io/badge/Platform-Android-brightgreen?style=for-the-badge&logo=android&logoColor=white" />
</p>

---

## 📖 Giới Thiệu

**Friggy Mobile** là ứng dụng di động giúp người dùng quản lý tủ lạnh thông minh, gợi ý món ăn theo nguyên liệu có sẵn, theo dõi dinh dưỡng gia đình và nhận thông báo đẩy về thực phẩm sắp hết hạn. Kết nối trực tiếp với Backend API tại `https://api.friggy.io.vn`.

---

## 🚀 Chức Năng Dành Cho Người Dùng

### 🔐 1. Đăng Nhập & Tài Khoản
- Đăng nhập bằng **Google OAuth 2.0** (một chạm)
- Đăng nhập bằng **Số điện thoại + OTP**
- Đăng nhập bằng **Email & Mật khẩu**
- Tự động làm mới JWT token — không cần đăng nhập lại

### 🧊 2. Quản Lý Tủ Lạnh
- Phân loại 3 khu vực: **Ngăn mát**, **Ngăn đông**, **Tủ khô**
- Xem danh sách thực phẩm với cảnh báo màu:
  - 🔴 **Đỏ** — Hết hạn
  - 🟡 **Vàng** — Sắp hết hạn (≤ 3 ngày)
  - 🟢 **Xanh** — Còn tươi
- Thêm thực phẩm bằng nhiều cách:
  - 📷 **Chụp ảnh AI** — nhận diện tự động
  - 🧾 **Scan hóa đơn** — đọc danh sách mua sắm
  - 🏷️ **Quét mã vạch** — sản phẩm đóng gói
  - ✍️ **Thêm thủ công** — tìm kiếm từ 60+ nguyên liệu chuẩn

### 🍲 3. Gợi Ý Công Thức Nấu Ăn
- Gợi ý món **Bữa sáng / Trưa / Tối** theo nguyên liệu trong tủ
- Xem chi tiết: thành phần, mức độ khó, thời gian, chi phí ước tính, từng bước thực hiện
- Tính năng **Đầu bếp AI** — chat hỏi công thức theo yêu cầu

### 📅 4. Lập Thực Đơn Tuần
- Lên kế hoạch bữa ăn cho cả tuần tới
- Gợi ý AI tự động dựa trên nguyên liệu và khẩu vị gia đình
- Xem lại lịch sử thực đơn các tuần trước

### 🔔 5. Thông Báo Đẩy (Push Notifications — FCM)
- Nhận thông báo **ra màn hình khóa** khi:
  - ⚠️ Có nguyên liệu sắp hết hạn trong vòng 3 ngày
  - 📅 Chưa lập thực đơn cho tuần tới (nhắc mỗi Chủ Nhật)
  - 💳 Gói Premium sắp hết hạn (nhắc trước 7 ngày)
- Hỗ trợ thông báo khi app đang **Foreground**, **Background** và **Terminated**
- Banner cảnh báo trong app khi quyền thông báo bị tắt

### 👥 6. Chia Sẻ Tủ Lạnh Gia Đình
- Mời thành viên gia đình cùng quản lý tủ lạnh qua link
- Xem và chỉnh sửa thực phẩm chung theo thời gian thực

### 👤 7. Hồ Sơ & Cài Đặt Cá Nhân
- Chỉnh sửa tên, giới tính, ngày sinh, ảnh đại diện
- Cài đặt khẩu vị, số thành viên gia đình, calo mục tiêu
- Quản lý danh sách dị ứng thực phẩm
- Giao diện **Dark Mode / Light Mode**
- Hỗ trợ đa ngôn ngữ: 🇻🇳 Tiếng Việt & 🇬🇧 English

### 💳 8. Gói Đăng Ký Premium
- Xem và so sánh gói **Free** vs **Premium (Individual)**
- Nâng cấp gói — AI không giới hạn

---

## 🛠️ Tech Stack

| Công nghệ | Mục đích |
|---|---|
| Flutter / Dart | Core framework |
| Dio | HTTP client + Auth interceptor + Token refresh |
| Firebase Messaging | Push notification FCM |
| flutter_local_notifications | Foreground notification banner |
| permission_handler | Xin quyền runtime Android 13+ |
| Google Fonts (Plus Jakarta Sans) | Typography |
| SharedPreferences | Lưu session local |
| Flutter Localizations | i18n (vi / en) |
| flutter_screenutil | Responsive layout |

---

## 💻 Hướng Dẫn Cài Đặt & Chạy

### 📋 Yêu Cầu Tiền Đề
- [Flutter SDK](https://docs.flutter.dev/get-started/install) `>= 3.0.0`
- Android Studio hoặc VS Code (cài Flutter & Dart Extension)
- Android Emulator hoặc điện thoại Android thật
- File `google-services.json` từ Firebase Console (xem bên dưới)

---

### 📥 1. Clone Dự Án

```bash
git clone <repository-url>
cd FRIGGY/Mobile
```

---

### 📦 2. Cài Đặt Dependencies

```bash
flutter pub get
```

---

### 🔥 3. Cấu Hình Firebase (Bắt Buộc)

Để tính năng **Push Notification** hoạt động, cần file `google-services.json`:

1. Vào [Firebase Console](https://console.firebase.google.com) → Project **Friggy**
2. **Settings** → **General** → **Your apps** → Android app `com.example.friggy`
3. Tải file `google-services.json`
4. Đặt vào: `android/app/google-services.json`

> ⚠️ Không có file này app sẽ **không build được**

---

### ▶️ 4. Khởi Chạy

```bash
# Kiểm tra thiết bị kết nối
flutter devices

# Chạy debug
flutter run

# Chạy release (hiệu năng cao hơn)
flutter run --release
```

---

### ⚙️ 5. Cấu Hình API (nếu chạy local)

Mở `lib/config/app_constants.dart` và điều chỉnh `baseUrl`:

```dart
// Android Emulator
static const String baseUrl = 'http://10.0.2.2:6969/api/v1';

// Điện thoại thật (thay bằng IP máy tính)
static const String baseUrl = 'http://192.168.x.x:6969/api/v1';

// Production (mặc định)
static const String baseUrl = 'https://api.friggy.io.vn/api/v1';
```

---

## 📁 Cấu Trúc Thư Mục

```
lib/
├── config/          # Constants, API endpoints
├── data/
│   ├── models/      # Data models
│   ├── services/    # API service, Auth, Notification, Storage
│   └── local/       # Local storage
├── l10n/            # Localization (vi, en)
├── screens/         # UI screens
├── theme/           # Dark/Light theme
└── utils/           # Navigation service, helpers
android/
└── app/
    ├── google-services.json   # ← Cần có file này!
    └── build.gradle.kts
```

---

<p align="center">Developed with ❤️ by Friggy Team</p>
