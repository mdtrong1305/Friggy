# 🥗 Friggy Web — Landing Page & Admin Dashboard

<p align="center">
  <img src="https://img.shields.io/badge/React-20232A?style=for-the-badge&logo=react&logoColor=61DAFB" />
  <img src="https://img.shields.io/badge/Vite-646CFF?style=for-the-badge&logo=vite&logoColor=white" />
  <img src="https://img.shields.io/badge/JavaScript-F7DF1E?style=for-the-badge&logo=javascript&logoColor=black" />
  <img src="https://img.shields.io/badge/Live-friggy.io.vn-008435?style=for-the-badge" />
</p>

---

## 📖 Giới Thiệu

**Friggy Web** gồm 2 phần chính:

| Phần | Đường dẫn | Đối tượng |
|---|---|---|
| 🌐 **Landing Page** | `/` | Người dùng mới, khách ghé thăm |
| 🛡️ **Admin Dashboard** | `/admin` | Quản trị viên hệ thống |

---

## 🌐 Landing Page — Giới Thiệu Ứng Dụng Friggy

Landing page là trang giới thiệu sản phẩm dành cho người dùng chưa có tài khoản, bao gồm:

### 🏠 Hero Section
- Giới thiệu slogan và giá trị cốt lõi của Friggy
- Nút kêu gọi hành động (CTA) tải app hoặc dùng thử

### ✨ Features — Tính Năng Nổi Bật
Giới thiệu các tính năng chính của ứng dụng:
- 🧊 Quản lý tủ lạnh thông minh
- 📷 Nhận diện thực phẩm bằng AI
- 🍲 Gợi ý món ăn theo nguyên liệu
- 🔔 Cảnh báo hết hạn thực phẩm

### 🔄 How It Works — Cách Hoạt Động
Hướng dẫn 3 bước đơn giản để bắt đầu sử dụng Friggy

### 💰 Pricing — Bảng Giá
So sánh gói **Free** và **Premium (Individual)**:
- Free: Quản lý tủ lạnh cơ bản, AI giới hạn 2 lần/tuần
- Premium: AI không giới hạn, thực đơn tuần, ưu tiên hỗ trợ

### 💬 Testimonials — Đánh Giá Người Dùng
Hiển thị review thực tế từ người dùng

### 🤝 Trust Partners — Đối Tác & Chứng Nhận
Logo các đối tác và chứng nhận uy tín

### ❓ FAQ — Câu Hỏi Thường Gặp
Giải đáp các thắc mắc phổ biến

### 📲 Download CTA — Tải Ứng Dụng
Banner kêu gọi tải app với link App Store / Google Play

### 🔗 Family Invite Action
Trang xử lý link mời gia đình — khi member nhấn link invite từ ứng dụng sẽ redirect về đây để xác nhận tham gia tủ lạnh chung

---

## 🛡️ Admin Dashboard — Quản Trị Hệ Thống

Trang admin dành riêng cho quản trị viên, yêu cầu đăng nhập bằng tài khoản Admin.

### 📊 Dashboard
- Tổng quan hệ thống: tổng user, doanh thu, tỷ lệ Premium, tăng trưởng
- Biểu đồ thống kê theo thời gian thực

### 👥 Quản Lý Người Dùng (User Management)
- Xem danh sách toàn bộ user
- Tìm kiếm, lọc theo gói đăng ký, trạng thái
- Xem chi tiết hồ sơ từng user
- Khóa / mở khóa tài khoản

### 🥬 Quản Lý Nguyên Liệu (Ingredient Management)
- Danh sách 60+ nguyên liệu chuẩn
- Thêm, sửa, xóa nguyên liệu
- Quản lý category và đơn vị đo lường

### 🍜 Quản Lý Công Thức (Recipe Management)
- Danh sách toàn bộ công thức trong hệ thống
- Thêm / chỉnh sửa / xóa công thức
- Gắn tag, phân loại bữa ăn

### 📦 Quản Lý Gói Dịch Vụ (Package Management)
- Xem và chỉnh sửa thông tin các gói Free / Premium
- Cấu hình giá, thời hạn, quyền lợi từng gói

### 💳 Lịch Sử Thanh Toán (Payment Transactions)
- Xem toàn bộ giao dịch nạp tiền / nâng cấp gói
- Lọc theo trạng thái: thành công, thất bại, chờ xử lý

### ⏰ Quản Lý Cron Jobs (Cron Management)
- Xem lịch chạy tự động của các job:
  - `expiry_warning` — Cảnh báo hết hạn (8:00 hàng ngày)
  - `weekly_plan_remind` — Nhắc lập thực đơn (Chủ Nhật 9:00)
  - `subscription_renewal_reminder` — Nhắc gia hạn (9:00 hàng ngày)
- **Trigger Ngay**: Kích hoạt job thủ công để test
- Bật / tắt từng job, chỉnh sửa lịch cron expression

### 🤖 Quản Lý AI (AI Management)
- Theo dõi lượt sử dụng AI của toàn hệ thống
- Cấu hình giới hạn AI theo gói

### 🏆 Quản Lý Nhà Tài Trợ (Sponsor Management)
- Thêm / sửa / xóa thông tin nhà tài trợ hiển thị trên landing page

### ⚙️ Cài Đặt Hệ Thống (Settings)
- Cấu hình thông số chung của ứng dụng

---

## 🛠️ Tech Stack

| Công nghệ | Mục đích |
|---|---|
| React 19 | UI Framework |
| Vite | Build tool (HMR cực nhanh) |
| JavaScript (JSX) | Ngôn ngữ lập trình |
| Context API | State management (Auth, Theme) |
| React Router | Routing (Guest / Admin) |
| Axios / Fetch | Gọi API Backend |

---

## 💻 Hướng Dẫn Cài Đặt & Chạy

### 📥 1. Clone Dự Án

```bash
git clone <repository-url>
cd FRIGGY/Web
```

### 📦 2. Cài Đặt Dependencies

```bash
npm install
```

### ▶️ 3. Khởi Chạy Development Server

```bash
npm run dev
```

Mở trình duyệt tại: `http://localhost:5173`

### 🏗️ 4. Build Production

```bash
npm run build
```

---

## 📁 Cấu Trúc Thư Mục

```
src/
├── pages/
│   ├── Guest/           # Landing Page
│   │   ├── Hero/
│   │   ├── Features/
│   │   ├── HowItWorks/
│   │   ├── Pricing/
│   │   ├── Testimonials/
│   │   ├── TrustPartners/
│   │   ├── Faq/
│   │   ├── DownloadCta/
│   │   ├── Footer/
│   │   └── FamilyInviteAction.jsx
│   └── Admin/           # Admin Dashboard
│       ├── Dashboard/
│       ├── UserManagement/
│       ├── IngredientManagement/
│       ├── RecipeManagement/
│       ├── PackageManagement/
│       ├── PaymentTransactions/
│       ├── CronManagement/
│       ├── AiManagement/
│       ├── SponsorManagement/
│       └── Settings/
├── components/          # Shared components
├── context/             # Auth, Theme context
├── services/            # API calls
├── hooks/               # Custom hooks
└── utils/               # Helper functions
```

---

## 🔗 Liên Kết

| | |
|---|---|
| 🌐 Website | https://friggy.io.vn |
| 📱 API Backend | https://api.friggy.io.vn |
| 📚 API Docs | https://api.friggy.io.vn/docs |

---

<p align="center">Developed with ❤️ by Friggy Team</p>
