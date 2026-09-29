import React, { useState, useEffect } from 'react';
import { Menu, Sparkles } from 'lucide-react';

import cuteMascotImg from '../../../assets/images/cute_mascot.png';
import { getMeApi } from '../../../services/userService';
import { API_BASE_URL } from '../../../utils/constants';

export const AdminHeader = ({ activeTab, setMobileOpen, onExitAdmin }) => {
  const resolveAvatarUrl = (rawUrl) => {
    if (!rawUrl) return cuteMascotImg;
    let formatted = rawUrl.trim();
    if (formatted.includes('api.friggy.io.vn')) {
      formatted = formatted.replace('api.friggy.io.vn', 'file.friggy.io.vn');
    }
    if (formatted.startsWith('http://') || formatted.startsWith('https://') || formatted.startsWith('data:')) {
      return formatted;
    }
    if (formatted.startsWith('file.friggy.io.vn')) {
      return `https://${formatted}`;
    }
    const apiBase = API_BASE_URL || 'https://api.friggy.io.vn/api/v1';
    let fileBase = 'https://file.friggy.io.vn';
    if (!apiBase.includes('friggy.io.vn')) {
      fileBase = apiBase.replace(/\/api\/v1\/?$/, '').replace(/\/$/, '');
    }
    return `${fileBase}${formatted.startsWith('/') ? '' : '/'}${formatted}`;
  };

  // Synchronously get cached user profile from localStorage to eliminate flicker
  const getInitialHeaderUserInfo = () => {
    try {
      const cached = localStorage.getItem('friggy_user') || localStorage.getItem('user');
      if (cached) {
        const me = JSON.parse(cached);
        const name =
          me.name ||
          me.profile?.name ||
          (me.googleEmail ? me.googleEmail.split('@')[0] : null) ||
          (me.email ? me.email.split('@')[0] : null) ||
          '';
        const role = me.roleId === 1 ? 'Super Admin' : 'Admin';
        const avatarUrl = me.profile?.avatarUrl || me.avatarUrl || me.profile?.avatarPath || me.avatarPath;
        if (name) {
          return { name, role, avatarUrl };
        }
      }
    } catch (e) {}
    return { name: '', role: 'Admin', avatarUrl: null };
  };

  const [userInfo, setUserInfo] = useState(() => getInitialHeaderUserInfo());

  // Fetch real admin profile for Header
  const fetchHeaderUserInfo = async () => {
    try {
      const res = await getMeApi();
      const me = res?.data || res;
      if (me) {
        try {
          localStorage.setItem('friggy_user', JSON.stringify(me));
          localStorage.setItem('user', JSON.stringify(me));
        } catch (e) {}
        setUserInfo({
          name: me.name || me.profile?.name || me.googleEmail?.split('@')[0] || me.email?.split('@')[0] || '',
          role: me.roleId === 1 ? 'Super Admin' : 'Admin',
          avatarUrl: me.profile?.avatarUrl || me.avatarUrl || me.profile?.avatarPath || me.avatarPath || null,
        });
      }
    } catch (err) {
      console.log('Header user info fallback:', err.message);
    }
  };

  useEffect(() => {
    fetchHeaderUserInfo();

    const handleProfileUpdate = () => {
      fetchHeaderUserInfo();
    };

    window.addEventListener('user_profile_updated', handleProfileUpdate);
    return () => {
      window.removeEventListener('user_profile_updated', handleProfileUpdate);
    };
  }, []);

  const getTitle = () => {
    switch (activeTab) {
      case 'dashboard':
        return { title: 'Trang Chủ Tổng Quan', sub: 'Thống kê người dùng, gói cước và doanh thu hệ thống' };
      case 'ingredients':
        return { title: 'Quản Lý Kho Nguyên Liệu', sub: 'Quản lý nguyên liệu tủ lạnh, danh mục phân loại & thông tin dinh dưỡng' };
      case 'recipes':
        return { title: 'Quản Lý Công Thức Nấu Ăn', sub: 'Quản lý thư viện công thức nấu ăn, khẩu phần & hướng dẫn chế biến' };
      case 'users':
        return { title: 'Quản Lý Người Dùng', sub: 'Quản lý tài khoản, phân quyền và lịch sử hoạt động' };
      case 'transactions':
        return { title: 'Lịch Sử Giao Dịch Thanh Toán', sub: 'Toàn bộ nhật ký giao dịch mua gói Premium từ PayOS' };
      case 'ai':
        return { title: 'Quản Lý AI Engine', sub: 'Cấu hình Provider AI và System Prompts' };
      case 'cron':
        return { title: 'Quản Lý Tiến Trình Cron Jobs', sub: 'Đặt lịch và kích hoạt chạy thử tiến trình tự động' };
      case 'sponsors':
        return { title: 'Quản Lý Nhà Tài Trợ & QC', sub: 'Đối tác liên kết và các chiến dịch banner quảng cáo' };
      case 'packages':
        return { title: 'Quản Lý Gói Cước', sub: 'Thiết lập các gói dịch vụ Premium, Family VIP & Chef Pro' };
      case 'profile':
        return { title: 'Thông Tin Cá Nhân', sub: 'Quản lý thông tin tài khoản admin, cập nhật chi tiết & đổi mật khẩu' };
      case 'settings':
        return { title: 'Cài Đặt Hệ Thống', sub: 'Cấu hình cổng thanh toán, API Keys & bảo mật' };
      default:
        return { title: 'Admin Dashboard', sub: 'Hệ thống quản trị Friggy AI' };
    }
  };

  const current = getTitle();

  return (
    <header className="bg-white/90 backdrop-blur-md border-b border-emerald-100 sticky top-0 z-30 px-4 sm:px-8 py-4 flex items-center justify-between shadow-2xs">
      {/* Left side: Mobile button & Page Title */}
      <div className="flex items-center gap-3">
        <button
          onClick={() => setMobileOpen(true)}
          className="lg:hidden p-2 rounded-xl text-slate-600 hover:text-emerald-700 hover:bg-emerald-50 transition-colors"
        >
          <Menu className="w-6 h-6" />
        </button>

        <div>
          <h1 className="text-lg sm:text-2xl font-black text-slate-900 tracking-tight flex items-center gap-2">
            <span>{current.title}</span>
            <Sparkles className="w-5 h-5 text-emerald-500 hidden sm:inline" />
          </h1>
          <p className="text-xs text-slate-500 font-medium hidden sm:block">
            {current.sub}
          </p>
        </div>
      </div>

      {/* Right side: Admin Profile Badge */}
      <div className="flex items-center gap-3 sm:gap-4 relative">
        <div className="flex items-center gap-2.5 px-3 py-1.5 rounded-2xl bg-emerald-50/80 border border-emerald-200/70">
          <img
            src={resolveAvatarUrl(userInfo.avatarUrl)}
            alt={userInfo.name || 'Admin'}
            className="w-8 h-8 rounded-xl object-cover bg-white border border-emerald-300 shadow-xs"
            onError={(e) => {
              e.target.onerror = null;
              e.target.src = cuteMascotImg;
            }}
          />
          <div className="text-left hidden sm:block">
            <p className="text-xs font-extrabold text-emerald-950 leading-tight truncate max-w-[140px]">
              {userInfo.name || 'Admin'}
            </p>
            <p className="text-[10px] font-bold text-emerald-600">{userInfo.role}</p>
          </div>
        </div>
      </div>
    </header>
  );
};

export default AdminHeader;
