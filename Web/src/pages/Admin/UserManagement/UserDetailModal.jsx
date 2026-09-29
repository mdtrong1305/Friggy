import React, { useEffect, useState } from 'react';
import {
  X,
  User,
  Mail,
  Phone,
  Calendar,
  Shield,
  Refrigerator,
  Sparkles,
  PackageCheck,
  CheckCircle,
  AlertTriangle,
  Loader2,
  Clock,
  Heart,
  Utensils,
  DollarSign,
} from 'lucide-react';
import { getAdminUserDetailApi } from '../../../services/adminService';
import { showToast } from '../../../components/common/Toast';

const resolveAvatarUrl = (rawUrl) => {
  if (!rawUrl) return null;
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
  const apiBase = import.meta.env.VITE_API_BASE_URL || import.meta.env.VITE_API_URL || 'https://api.friggy.io.vn/api/v1';
  let fileBase = 'https://file.friggy.io.vn';
  if (!apiBase.includes('friggy.io.vn')) {
    fileBase = apiBase.replace(/\/api\/v1\/?$/, '').replace(/\/$/, '');
  }
  return `${fileBase}${formatted.startsWith('/') ? '' : '/'}${formatted}`;
};

export const UserDetailModal = ({ user: initialUser, onClose }) => {
  const [userDetail, setUserDetail] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!initialUser?.id) return;
    let isMounted = true;
    setLoading(true);

    getAdminUserDetailApi(initialUser.id)
      .then((res) => {
        if (!isMounted) return;
        const data = res?.data || res;
        setUserDetail(data);
      })
      .catch((err) => {
        if (!isMounted) return;
        console.error('Lỗi lấy chi tiết user:', err);
        showToast.error(err.message || 'Không thể tải chi tiết người dùng');
        setUserDetail(initialUser);
      })
      .finally(() => {
        if (isMounted) setLoading(false);
      });

    return () => {
      isMounted = false;
    };
  }, [initialUser]);

  if (!initialUser) return null;

  const displayUser = userDetail || initialUser;
  const isSuspended = displayUser.status === 'suspended' || displayUser.status === 'Banned';

  const formattedDate = displayUser.createdAt
    ? new Date(displayUser.createdAt).toLocaleDateString('vi-VN')
    : 'Chưa cập nhật';

  const lastLoginFormatted = displayUser.lastLoginAt
    ? new Date(displayUser.lastLoginAt).toLocaleString('vi-VN')
    : 'Chưa đăng nhập';

  const avatarUrl =
    resolveAvatarUrl(displayUser.profile?.avatarUrl) ||
    `https://api.dicebear.com/7.x/avataaars/svg?seed=${encodeURIComponent(
      displayUser.name || displayUser.googleEmail || 'User'
    )}`;

  return (
    <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-xs flex items-center justify-center p-4 overflow-y-auto animate__animated animate__fadeIn animate__faster">
      <div
        className="w-full max-w-xl bg-white rounded-[36px] shadow-2xl border border-slate-100 overflow-hidden relative animate__animated animate__zoomIn animate__faster"
      >
        {/* Top Header Graphic */}
        <div className="bg-gradient-to-r from-emerald-600 via-teal-600 to-emerald-700 p-6 sm:p-8 text-white relative">
          <button
            onClick={onClose}
            className="absolute top-5 right-5 p-2 rounded-full bg-white/10 hover:bg-white/20 text-white transition-colors cursor-pointer"
          >
            <X className="w-5 h-5" />
          </button>

          <div className="flex items-center gap-4">
            <img
              src={avatarUrl}
              alt={displayUser.name || 'User'}
              className="w-20 h-20 rounded-2xl object-cover border-4 border-white/20 shadow-md bg-white"
            />
            <div className="space-y-1">
              <div className="flex items-center gap-2 flex-wrap">
                <h3 className="text-xl sm:text-2xl font-black">
                  {displayUser.name || displayUser.googleEmail?.split('@')[0] || 'Người dùng'}
                </h3>
                <span className="px-2.5 py-0.5 rounded-full bg-white/20 text-white text-[10px] font-bold">
                  {displayUser.roleId === 1 ? 'ADMIN' : 'USER'}
                </span>
              </div>
              <p className="text-xs text-emerald-100 font-medium">{displayUser.googleEmail || 'N/A'}</p>
              <div className="pt-1 flex items-center gap-2">
                {!isSuspended ? (
                  <span className="inline-flex items-center gap-1 text-[11px] font-bold bg-emerald-400/20 px-2.5 py-0.5 rounded-full text-emerald-200 border border-emerald-300/30">
                    <CheckCircle className="w-3.5 h-3.5 text-emerald-300" />
                    Đang hoạt động
                  </span>
                ) : (
                  <span className="inline-flex items-center gap-1 text-[11px] font-bold bg-rose-400/20 px-2.5 py-0.5 rounded-full text-rose-200 border border-rose-300/30">
                    <AlertTriangle className="w-3.5 h-3.5 text-rose-300" />
                    Tài khoản bị khóa
                  </span>
                )}
              </div>
            </div>
          </div>
        </div>

        {/* Modal Body */}
        {loading ? (
          <div className="p-12 text-center text-slate-500 font-semibold text-sm flex flex-col items-center gap-3">
            <Loader2 className="w-8 h-8 animate-spin text-emerald-600" />
            <p>Đang tải chi tiết người dùng...</p>
          </div>
        ) : (
          <div className="p-6 sm:p-8 space-y-6">
            {/* Info Grid */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div className="p-3.5 rounded-2xl bg-slate-50 border border-slate-100 space-y-1">
                <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider flex items-center gap-1">
                  <Mail className="w-3.5 h-3.5 text-emerald-600" />
                  Địa chỉ Email
                </span>
                <p className="text-xs font-bold text-slate-900 truncate">{displayUser.googleEmail || 'Chưa cập nhật'}</p>
              </div>

              <div className="p-3.5 rounded-2xl bg-slate-50 border border-slate-100 space-y-1">
                <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider flex items-center gap-1">
                  <Phone className="w-3.5 h-3.5 text-emerald-600" />
                  Số Điện Thoại
                </span>
                <p className="text-xs font-bold text-slate-900">{displayUser.phone || 'Chưa cập nhật'}</p>
              </div>

              <div className="p-3.5 rounded-2xl bg-slate-50 border border-slate-100 space-y-1">
                <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider flex items-center gap-1">
                  <PackageCheck className="w-3.5 h-3.5 text-emerald-600" />
                  Gói Dịch Vụ
                </span>
                <p className="text-xs font-black text-emerald-700">
                  {displayUser.subscription?.plan?.displayName || displayUser.subscription?.plan?.name || 'Gói Miễn Phí (FREE)'}
                </p>
              </div>

              <div className="p-3.5 rounded-2xl bg-slate-50 border border-slate-100 space-y-1">
                <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider flex items-center gap-1">
                  <Calendar className="w-3.5 h-3.5 text-emerald-600" />
                  Ngày Tham Gia
                </span>
                <p className="text-xs font-bold text-slate-900">{formattedDate}</p>
              </div>
            </div>

            {/* Extra Details: Preferences & AI Usage */}
            <div className="space-y-3">
              <h4 className="text-xs font-extrabold text-slate-400 uppercase tracking-wider">Thông Tin Bổ Sung</h4>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs">
                <div className="p-3 rounded-xl bg-slate-50 border border-slate-100 flex items-center gap-2.5">
                  <Clock className="w-4 h-4 text-emerald-600 shrink-0" />
                  <div>
                    <p className="text-[10px] text-slate-400 font-bold">Đăng nhập gần nhất</p>
                    <p className="font-bold text-slate-800">{lastLoginFormatted}</p>
                  </div>
                </div>

                <div className="p-3 rounded-xl bg-slate-50 border border-slate-100 flex items-center gap-2.5">
                  <Sparkles className="w-4 h-4 text-emerald-600 shrink-0" />
                  <div>
                    <p className="text-[10px] text-slate-400 font-bold">Sử dụng AI trong tuần</p>
                    <p className="font-bold text-slate-800">{displayUser.aiUsageThisWeek ?? 0} lần</p>
                  </div>
                </div>

                {displayUser.preferences?.dietaryStyle && (
                  <div className="p-3 rounded-xl bg-slate-50 border border-slate-100 flex items-center gap-2.5">
                    <Heart className="w-4 h-4 text-emerald-600 shrink-0" />
                    <div>
                      <p className="text-[10px] text-slate-400 font-bold">Chế độ ăn uống</p>
                      <p className="font-bold text-slate-800">{displayUser.preferences.dietaryStyle}</p>
                    </div>
                  </div>
                )}

                {displayUser.preferences?.skillLevel && (
                  <div className="p-3 rounded-xl bg-slate-50 border border-slate-100 flex items-center gap-2.5">
                    <Utensils className="w-4 h-4 text-emerald-600 shrink-0" />
                    <div>
                      <p className="text-[10px] text-slate-400 font-bold">Trình độ nấu ăn</p>
                      <p className="font-bold text-slate-800">{displayUser.preferences.skillLevel}</p>
                    </div>
                  </div>
                )}
              </div>
            </div>

            {/* Modal Actions */}
            <div className="flex items-center justify-end gap-3 pt-2 border-t border-slate-100">
              <button
                onClick={onClose}
                className="px-5 py-2.5 rounded-2xl bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold text-xs transition-colors cursor-pointer"
              >
                Đóng
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default UserDetailModal;
