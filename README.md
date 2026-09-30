# 🥗 Friggy — Hệ Thống Quản Lý Tủ Lạnh & Dinh Dưỡng Thông Minh

<p align="center">
  <img src="https://img.shields.io/badge/NestJS-E0234E?style=for-the-badge&logo=nestjs&logoColor=white" />
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" />
  <img src="https://img.shields.io/badge/React-20232A?style=for-the-badge&logo=react&logoColor=61DAFB" />
  <img src="https://img.shields.io/badge/PostgreSQL-4169E1?style=for-the-badge&logo=postgresql&logoColor=white" />
  <img src="https://img.shields.io/badge/RabbitMQ-FF6600?style=for-the-badge&logo=rabbitmq&logoColor=white" />
  <img src="https://img.shields.io/badge/Redis-DC382D?style=for-the-badge&logo=redis&logoColor=white" />
  <img src="https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black" />
  <img src="https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white" />
</p>

<p align="center">
  <strong>🌐 Website:</strong> <a href="https://friggy.io.vn">friggy.io.vn</a> &nbsp;|&nbsp;
  <strong>📡 API:</strong> <a href="https://api.friggy.io.vn">api.friggy.io.vn</a> &nbsp;|&nbsp;
  <strong>📚 Docs:</strong> <a href="https://api.friggy.io.vn/docs">api.friggy.io.vn/docs</a>
</p>

---

## 📖 Tổng Quan

**Friggy** là hệ thống full-stack giúp người dùng quản lý tủ lạnh thông minh, gợi ý món ăn dựa trên AI, lên thực đơn tuần tự động và nhận thông báo kịp thời về thực phẩm sắp hết hạn.

Dự án được xây dựng theo kiến trúc **microservices** gồm 5 service độc lập:

```
FRIGGY/
├── be/              # Backend API chính (NestJS) — Port 6969
├── ai-service/      # AI Microservice (NestJS + LangChain) — Port 3001
├── email-service/   # Email Microservice (NestJS + Nodemailer)
├── Web/             # Landing Page + Admin Dashboard (React + Vite)
└── Mobile/          # Ứng dụng di động Android (Flutter)
```

---

## 🏗️ Kiến Trúc Hệ Thống

```
┌──────────────────────────────────────────────────────┐
│                   CLIENT LAYER                       │
│   📱 Mobile App (Flutter)   🌐 Web (React/Vite)     │
└─────────────────────┬────────────────────────────────┘
                      │ HTTPS / REST
┌─────────────────────▼────────────────────────────────┐
│              BACKEND API (NestJS :6969)              │
│   Auth · Fridge · Recipes · Notifications · Admin    │
│   Subscriptions · Meal Planning · Family · Payment   │
└───────┬───────────────────────────────┬──────────────┘
        │ RabbitMQ                      │ RabbitMQ
┌───────▼───────┐               ┌───────▼──────────┐
│  AI SERVICE   │               │  EMAIL SERVICE   │
│  (NestJS)     │               │  (NestJS)        │
│  LangChain    │               │  Nodemailer      │
│  OpenAI/Gemini│               │  HTML Templates  │
└───────┬───────┘               └──────────────────┘
        │
┌───────▼──────────────────────────────────────────────┐
│              INFRASTRUCTURE                          │
│  🐘 PostgreSQL (Prisma ORM)                         │
│  ⚡ Redis (Cache + SSE Pub/Sub)                     │
│  🐰 RabbitMQ (Message Queue)                        │
│  🔥 Firebase FCM (Push Notifications)               │
│  💳 PayOS (Payment Gateway)                         │
└──────────────────────────────────────────────────────┘
```

---

## 📦 Mô Tả Từng Service

### 1. 🖥️ Backend API (`be/`)

**Framework:** NestJS · **Port:** 6969 · **URL:** `https://api.friggy.io.vn`

Backend chính xử lý toàn bộ business logic và cung cấp RESTful API cho Mobile và Web.

**API Modules:**

| Module | Chức năng |
|---|---|
| `auth` | Đăng nhập Google OAuth, Email/OTP, JWT refresh token |
| `users` | Quản lý hồ sơ, avatar, cài đặt dinh dưỡng, dị ứng |
| `fridge` | CRUD thực phẩm, phân loại ngăn, theo dõi hạn dùng |
| `ingredients` | Danh mục 60+ nguyên liệu chuẩn (admin quản lý) |
| `recipes` | Công thức nấu ăn với thành phần, bước thực hiện |
| `meal-planning` | Lập thực đơn tuần, gợi ý AI theo nguyên liệu có sẵn |
| `ai-chat` | Chat với AI Đầu Bếp qua SSE streaming |
| `public-chat` | Chat công khai không cần đăng nhập |
| `family` | Mời thành viên, chia sẻ tủ lạnh gia đình |
| `notifications` | In-app notifications, FCM token, cron jobs |
| `subscriptions` | Gói Free/Premium, webhook thanh toán |
| `payment-transactions` | Lịch sử giao dịch, PayOS integration |
| `admin` | Dashboard tổng quan, quản lý user/cron/AI provider |

**System Modules:**

| Module | Chức năng |
|---|---|
| `prisma` | ORM kết nối PostgreSQL |
| `redis` | Cache response + SSE Pub/Sub real-time |
| `rabbit-mq` | Publish job sang AI Service & Email Service |
| `fcm` | Gửi Firebase Cloud Messaging push notification |
| `payos` | Tích hợp cổng thanh toán PayOS |
| `tokens` | Quản lý JWT access/refresh token |
| `email-client` | Client publish message lên Email Service queue |

**Tech Stack:** NestJS · Prisma · PostgreSQL · Redis · RabbitMQ · JWT · Swagger · Docker

---

### 2. 🤖 AI Service (`ai-service/`)

**Framework:** NestJS · **Port:** 3001 · **Giao tiếp:** RabbitMQ (nhận job từ BE)

AI Service là microservice xử lý các tác vụ AI nặng, hoàn toàn tách biệt khỏi BE để không block main thread.

**Agents:**

| Agent | Chức năng |
|---|---|
| `fridge-scan` | Nhận diện thực phẩm từ ảnh chụp (AI Vision) |
| `meal-plan` | Lập thực đơn tuần tự động dựa trên nguyên liệu trong tủ |

**AI Tools (LangChain):**

| Tool | Chức năng |
|---|---|
| `fridge.tools` | Đọc danh sách thực phẩm trong tủ lạnh của user |
| `meal-plan.tools` | Tạo và lưu thực đơn tuần |
| `recipe.tools` | Tìm kiếm và gợi ý công thức nấu ăn |
| `user.tools` | Đọc hồ sơ, dị ứng, khẩu vị của user |

**AI Provider — Multi-Provider Support:**
- Hỗ trợ **OpenAI**, **Gemini**, **OpenRouter** và bất kỳ provider nào tương thích OpenAI API
- API key được mã hóa **AES-256-CBC** trước khi lưu vào DB
- Admin có thể **đổi provider** không cần restart server
- **Rate limiting** per user theo gói đăng ký

**Tech Stack:** NestJS · LangChain · OpenAI SDK · Prisma · RabbitMQ · Redis

---

### 3. 📧 Email Service (`email-service/`)

**Framework:** NestJS Microservice · **Giao tiếp:** RabbitMQ (`email.send` pattern)

Email Service nhận message từ RabbitMQ và gửi email HTML template cho người dùng.

**Loại email được hỗ trợ:**

| Type | Khi nào gửi |
|---|---|
| `otp` | Xác thực đăng nhập bằng số điện thoại/email |
| `welcome` | Chào mừng user đăng ký mới |
| `subscription_reminder` | Nhắc gia hạn gói Premium (còn 7 ngày) |
| `password_changed` | Thông báo đổi mật khẩu thành công |
| `family_invite` | Mời tham gia tủ lạnh gia đình (kèm link xác nhận) |
| `family_removed` | Thông báo bị xóa khỏi nhóm gia đình |
| `family_dissolved` | Thông báo nhóm gia đình bị giải tán |

**Tech Stack:** NestJS · Nodemailer · RabbitMQ · HTML Email Templates

---

### 4. 📱 Mobile App (`Mobile/`)

**Framework:** Flutter (Dart) · **Platform:** Android · **APK:** `https://friggy.io.vn/friggy-app.apk`

Ứng dụng di động dành cho người dùng cuối với đầy đủ tính năng quản lý tủ lạnh và dinh dưỡng.

**Tính năng chính:**
- 🔐 Đăng nhập Google, Email/OTP
- 🧊 Quản lý tủ lạnh (Ngăn mát / Đông / Tủ khô)
- 📷 Thêm thực phẩm: AI Scan ảnh, Scan hóa đơn, Quét mã vạch, Thêm thủ công
- 🍲 Gợi ý công thức theo nguyên liệu có sẵn
- 📅 Lập thực đơn tuần với AI
- 🤖 Chat với Đầu Bếp AI (SSE streaming)
- 👥 Chia sẻ tủ lạnh gia đình
- 🔔 Push Notification (Firebase FCM) — hết hạn, thực đơn, gia hạn gói
- 💳 Quản lý & nâng cấp gói Premium
- 🌙 Dark Mode / Light Mode · 🌐 Tiếng Việt & English

**Tech Stack:** Flutter · Dio · Firebase Messaging · flutter_local_notifications · Provider · SharedPreferences

---

### 5. 🌐 Web (`Web/`)

**Framework:** React + Vite · **URL:** `https://friggy.io.vn`

Web gồm 2 phần: Landing Page giới thiệu sản phẩm và Admin Dashboard quản trị hệ thống.

**Landing Page** (`/`): Hero · Features · HowItWorks · Pricing · Testimonials · TrustPartners · FAQ · DownloadCTA · FamilyInviteAction

**Admin Dashboard** (`/admin`):
- 📊 Dashboard tổng quan (user, doanh thu, tăng trưởng)
- 👥 Quản lý người dùng
- 🥬 Quản lý nguyên liệu
- 🍜 Quản lý công thức nấu ăn
- 📦 Quản lý gói dịch vụ
- 💳 Lịch sử thanh toán
- ⏰ Quản lý Cron Jobs (trigger thủ công, bật/tắt, đổi lịch)
- 🤖 Quản lý AI Provider (đổi model/key không cần restart)
- 🏆 Quản lý nhà tài trợ
- ⚙️ Cài đặt hệ thống (link download APK, hotline, email)

**Tech Stack:** React 19 · Vite · JavaScript · Context API · React Router

---

## 🚀 Hướng Dẫn Chạy Local

### Yêu Cầu Tiên Quyết

- Node.js `>= 20`
- Flutter `>= 3.0`
- PostgreSQL
- Redis
- RabbitMQ
- Docker (tùy chọn)

---

### 1️⃣ Clone Dự Án

```bash
git clone <repository-url>
cd FRIGGY
```

---

### 2️⃣ Chạy Backend API

```bash
cd be
cp .env.example .env   # cấu hình DB, Redis, RabbitMQ, JWT secret...
npm install
npm run start:dev
```

API chạy tại: `http://localhost:6969`
Swagger Docs: `http://localhost:6969/docs`

---

### 3️⃣ Chạy AI Service

```bash
cd ai-service
cp .env.example .env   # cấu hình RabbitMQ, DB, AI_KEY_ENCRYPTION_SECRET
npm install
npm run start:dev
```

---

### 4️⃣ Chạy Email Service

```bash
cd email-service
cp .env.example .env   # cấu hình RabbitMQ, SMTP (Gmail/SendGrid)
npm install
npm run start:dev
```

---

### 5️⃣ Chạy Web

```bash
cd Web
npm install
npm run dev
```

Mở trình duyệt tại: `http://localhost:5173`

---

### 6️⃣ Chạy Mobile

```bash
cd Mobile
flutter pub get
flutter run
```

> ⚠️ Cần file `android/app/google-services.json` từ Firebase Console để push notification hoạt động.

---

## 🔗 Biến Môi Trường Quan Trọng

### Backend (`be/.env`)

```env
DATABASE_URL=postgresql://...
REDIS_URL=redis://...
RABBITMQ_URL=amqp://...
JWT_ACCESS_SECRET=...
JWT_REFRESH_SECRET=...
FIREBASE_PROJECT_ID=...
PAYOS_API_KEY=...
```

### AI Service (`ai-service/.env`)

```env
DATABASE_URL=postgresql://...
RABBITMQ_URL=amqp://...
REDIS_URL=redis://...
AI_KEY_ENCRYPTION_SECRET=...  # 32 ký tự — dùng để decrypt API key trong DB
PORT=3001
```

### Email Service (`email-service/.env`)

```env
RABBITMQ_URL=amqp://...
SMTP_HOST=smtp.gmail.com
SMTP_USER=...
SMTP_PASS=...
```

---

## 🗂️ Cấu Trúc Monorepo

```
FRIGGY/
├── be/                        # Backend API (NestJS)
│   ├── src/
│   │   ├── modules-api/       # 13 API modules (auth, fridge, ai-chat...)
│   │   ├── modules-system/    # Prisma, Redis, RabbitMQ, FCM, PayOS...
│   │   └── common/            # Guards, interceptors, filters, decorators
│   └── prisma/                # Database schema
│
├── ai-service/                # AI Microservice (NestJS + LangChain)
│   ├── src/
│   │   ├── ai-core/           # Agents, Tools, Provider, Rate Limit
│   │   │   ├── agents/        # fridge-scan, meal-plan
│   │   │   └── tools/         # fridge, meal-plan, recipe, user tools
│   │   └── rabbitmq/          # Consumer nhận job từ BE
│   └── prisma/
│
├── email-service/             # Email Microservice (NestJS)
│   └── src/
│       └── mail/              # Mail service + HTML templates
│
├── Web/                       # Landing Page + Admin (React + Vite)
│   ├── src/
│   │   ├── pages/
│   │   │   ├── Guest/         # Landing page sections
│   │   │   └── Admin/         # Admin dashboard modules
│   │   ├── services/          # API calls
│   │   └── utils/             # systemSettings, helpers
│   └── public/
│       └── friggy-app.apk     # APK file cho download
│
└── Mobile/                    # Flutter Android App
    ├── lib/
    │   ├── screens/           # UI screens
    │   ├── data/services/     # API, Auth, Notification, Storage
    │   ├── theme/             # Dark/Light theme
    │   └── l10n/              # Localization (vi, en)
    └── android/
        └── app/
            └── google-services.json   # Firebase config
```

---

## 🔄 Luồng Xử Lý Chính

### Luồng AI Chat (SSE Streaming)
```
Mobile → POST /ai-chat/stream → BE → RabbitMQ → AI Service
                                                     ↓ (LangChain + LLM)
Mobile ← SSE stream chunks ←────────── Redis Pub/Sub ←
```

### Luồng Gửi Email
```
BE (auth/family/subscription) → RabbitMQ (email.send) → Email Service → SMTP → User
```

### Luồng Push Notification
```
BE Cron Job → FcmService → Firebase FCM → Mobile App
```

### Luồng Thanh Toán
```
Mobile → POST /subscriptions/create-payment → BE → PayOS → QR Code
PayOS Webhook → BE → Nâng cấp gói user → FCM notification
```

---

## 📡 API Documentation

Swagger UI đầy đủ tại: **https://api.friggy.io.vn/docs**

Xác thực: `Bearer <JWT access_token>`

Lấy token:
```http
POST /api/v1/auth/google
POST /api/v1/auth/email/login
POST /api/v1/auth/phone/verify-otp
```

---

<p align="center">Developed with ❤️ by Friggy Team</p>
