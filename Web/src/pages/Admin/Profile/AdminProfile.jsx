import React, { useState, useRef, useEffect } from 'react';
import {
  User,
  Mail,
  Calendar,
  Phone,
  ShieldCheck,
  KeyRound,
  Save,
  CheckCircle2,
  AlertCircle,
  Eye,
  EyeOff,
  Sparkles,
  Camera,
  Loader2,
  FileText,
  UserCheck,
} from 'lucide-react';
import cuteMascotImg from '../../../assets/images/cute_mascot.png';
import { getMeApi, updateProfileApi, uploadAvatarApi } from '../../../services/userService';
import { showToast } from '../../../components/common/Toast';

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
  const apiBase = import.meta.env.VITE_API_BASE_URL || import.meta.env.VITE_API_URL || 'https://api.friggy.io.vn/api/v1';
  let fileBase = 'https://file.friggy.io.vn';
  if (!apiBase.includes('friggy.io.vn')) {
    fileBase = apiBase.replace(/\/api\/v1\/?$/, '').replace(/\/$/, '');
  }
  return `${fileBase}${formatted.startsWith('/') ? '' : '/'}${formatted}`;
};

export const AdminProfile = () => {
  const [loading, setLoading] = useState(true);
  const [savingProfile, setSavingProfile] = useState(false);
  const [uploadingAvatar, setUploadingAvatar] = useState(false);

  // Avatar state & file input ref
  const [avatarUrl, setAvatarUrl] = useState(cuteMascotImg);
  const fileInputRef = useRef(null);

  // Dynamic State for Personal Info
  const [profileData, setProfileData] = useState({
    name: '',
    phone: '',
    email: '',
    gender: 'male',
    dob: '',
    bio: '',
    role: '',
  });

  // State for Changing Password
  const [passwordForm, setPasswordForm] = useState({
    currentPassword: '',
    newPassword: '',
    confirmPassword: '',
  });

  const [showCurrentPw, setShowCurrentPw] = useState(false);
  const [showNewPw, setShowNewPw] = useState(false);
  const [showConfirmPw, setShowConfirmPw] = useState(false);
  const [passwordError, setPasswordError] = useState('');
  const [passwordSuccess, setPasswordSuccess] = useState(false);

  // Fetch real User Info from GET /api/v1/users/me
  const fetchUserProfile = async () => {
    setLoading(true);
    try {
      const res = await getMeApi();
      const me = res?.data || res;
      if (me) {
        let dobStr = me.profile?.dateOfBirth ? String(me.profile.dateOfBirth) : '';
        if (dobStr.includes('T')) {
          dobStr = dobStr.split('T')[0];
        }

        const roleText = typeof me.role === 'string'
          ? (me.role.toLowerCase() === 'admin' ? 'Admin' : me.role)
          : (me.role?.name || me.role?.displayName || '');

        setProfileData({
          name: me.name || me.profile?.displayName || me.email || '',
          phone: me.phone || me.profile?.phone || '',
          email: me.email || me.googleEmail || me.profile?.email || '',
          gender: me.profile?.gender || 'male',
          dob: dobStr,
          bio: me.profile?.bio || me.bio || '',
          role: roleText,
        });

        if (me.profile?.avatarUrl) {
          setAvatarUrl(resolveAvatarUrl(me.profile.avatarUrl));
        }
      }
    } catch (err) {
      console.error('Lỗi khi lấy thông tin /users/me:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchUserProfile();
  }, []);

  // Handle Avatar Change (POST /users/me/avatar)
  const handleAvatarChange = async (e) => {
    const file = e.target.files && e.target.files[0];
    if (!file) return;

    setUploadingAvatar(true);
    try {
      const res = await uploadAvatarApi(file);
      const resData = res?.data || res;
      const newAvatarUrl = resData?.avatarUrl || URL.createObjectURL(file);
      setAvatarUrl(newAvatarUrl);
      showToast.success('Đã tải lên và cập nhật ảnh đại diện thành công!');

      const cached = localStorage.getItem('friggy_user') || localStorage.getItem('user') || '{}';
      const currentUser = JSON.parse(cached);
      currentUser.avatarUrl = newAvatarUrl;
      localStorage.setItem('friggy_user', JSON.stringify(currentUser));
      localStorage.setItem('user', JSON.stringify(currentUser));
      window.dispatchEvent(new Event('user_profile_updated'));
    } catch (err) {
      console.error('Lỗi upload avatar:', err);
      showToast.error(err.message || 'Tải ảnh đại diện thất bại');
    } finally {
      setUploadingAvatar(false);
    }
  };

  // Trigger File Input Click
  const handleCameraClick = () => {
    if (fileInputRef.current) {
      fileInputRef.current.click();
    }
  };

  // Handle Save Profile (PATCH /users/me/profile)
  const handleSaveProfile = async (e) => {
    e.preventDefault();
    setSavingProfile(true);

    try {
      const payload = {
        name: profileData.name,
        gender: profileData.gender,
        dateOfBirth: profileData.dob ? `${profileData.dob}T00:00:00.000Z` : undefined,
        bio: profileData.bio,
      };

      await updateProfileApi(payload);
      showToast.success('Đã cập nhật thông tin cá nhân thành công!');

      const cached = localStorage.getItem('friggy_user') || localStorage.getItem('user') || '{}';
      const currentUser = JSON.parse(cached);
      currentUser.name = profileData.name;
      localStorage.setItem('friggy_user', JSON.stringify(currentUser));
      localStorage.setItem('user', JSON.stringify(currentUser));
      window.dispatchEvent(new Event('user_profile_updated'));
    } catch (err) {
      console.error('Lỗi cập nhật profile:', err);
      showToast.error(err.message || 'Cập nhật thông tin thất bại');
    } finally {
      setSavingProfile(false);
    }
  };

  // Handle Password Change
  const handleChangePassword = async (e) => {
    e.preventDefault();
    setPasswordError('');
    setPasswordSuccess(false);

    if (!passwordForm.currentPassword) {
      setPasswordError('Vui lòng nhập mật khẩu hiện tại.');
      return;
    }
    if (!passwordForm.newPassword) {
      setPasswordError('Vui lòng nhập mật khẩu mới.');
      return;
    }
    if (passwordForm.newPassword.length < 6) {
      setPasswordError('Mật khẩu mới phải có ít nhất 6 ký tự.');
      return;
    }
    if (passwordForm.newPassword !== passwordForm.confirmPassword) {
      setPasswordError('Mật khẩu xác nhận không trùng khớp.');
      return;
    }

    setPasswordSuccess(true);
    showToast.success('Đã đổi mật khẩu thành công!');
    setPasswordForm({
      currentPassword: '',
      newPassword: '',
      confirmPassword: '',
    });
    setTimeout(() => setPasswordSuccess(false), 4000);
  };

  if (loading) {
    return (
      <div className="py-24 text-center text-slate-400 font-semibold text-sm flex flex-col items-center justify-center gap-3">
        <Loader2 className="w-8 h-8 animate-spin text-emerald-600" />
        <p>Đang tải thông tin cá nhân...</p>
      </div>
    );
  }

  return (
    <div className="space-y-6 pb-12 animate__animated animate__fadeIn animate__faster">
      {/* Hidden File Input for Avatar Upload */}
      <input
        type="file"
        ref={fileInputRef}
        onChange={handleAvatarChange}
        accept="image/*"
        className="hidden"
      />

      {/* Top Banner Header with Avatar Upload */}
      <div className="animate__animated animate__fadeInDown p-6 sm:p-8 rounded-[32px] bg-gradient-to-r from-white via-emerald-50/40 to-white border border-emerald-100 shadow-sm flex flex-col sm:flex-row items-center sm:items-center justify-between gap-6 relative overflow-hidden">
        <div className="flex flex-col sm:flex-row items-center gap-5 text-center sm:text-left z-10">
          {/* Avatar Picture Container */}
          <div className="relative group cursor-pointer" onClick={handleCameraClick}>
            <div className="animate__animated animate__zoomIn w-24 h-24 sm:w-28 sm:h-28 rounded-3xl bg-gradient-to-tr from-emerald-500 via-green-400 to-teal-400 p-1 shadow-lg shadow-emerald-600/20 transition-transform duration-300 group-hover:scale-105">
              <img
                src={avatarUrl}
                alt="Admin Avatar"
                className="w-full h-full object-cover rounded-[22px] bg-white"
              />
            </div>

            <button
              type="button"
              disabled={uploadingAvatar}
              onClick={(e) => {
                e.stopPropagation();
                handleCameraClick();
              }}
              title="Cập nhật ảnh đại diện"
              className="absolute -bottom-1 -right-1 w-9 h-9 rounded-2xl bg-emerald-600 hover:bg-emerald-700 text-white flex items-center justify-center shadow-md border-2 border-white transition-all duration-200 group-hover:scale-110 cursor-pointer disabled:opacity-50"
            >
              {uploadingAvatar ? <Loader2 className="w-4 h-4 animate-spin" /> : <Camera className="w-4 h-4" />}
            </button>
          </div>

          <div>
            <h3 className="text-2xl sm:text-3xl font-black text-emerald-950 tracking-tight flex items-center justify-center sm:justify-start gap-2">
              <span>{profileData.name || 'Tài khoản Friggy'}</span>
              <Sparkles className="w-6 h-6 text-emerald-500" />
            </h3>
            <div className="flex flex-wrap items-center justify-center sm:justify-start gap-2 mt-1.5">
              {profileData.role && (
                <span className="px-3 py-1 rounded-full bg-emerald-600 text-white font-black text-xs shadow-xs">
                  {profileData.role}
                </span>
              )}
              <span className="text-xs text-emerald-900/70 font-semibold bg-emerald-100/60 px-3 py-1 rounded-full border border-emerald-200/50">
                Quản trị viên hệ thống Friggy AI
              </span>
            </div>
          </div>
        </div>
      </div>

      {/* Main Grid: Left = Personal Info, Right = Change Password */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left Column: Update Personal Info */}
        <div className="lg:col-span-2 space-y-6">
          <form
            onSubmit={handleSaveProfile}
            className="p-6 sm:p-8 rounded-[32px] bg-white border border-emerald-100 shadow-sm space-y-6"
          >
            <div className="flex items-center justify-between border-b border-emerald-100 pb-4">
              <div className="flex items-center gap-2.5">
                <div className="p-2.5 rounded-xl bg-emerald-50 text-emerald-700">
                  <User className="w-5 h-5" />
                </div>
                <div>
                  <h4 className="text-base font-black text-emerald-950">Thông Tin Tài Khoản</h4>
                  <p className="text-xs text-emerald-900/60 font-medium">
                    Cập nhật chi tiết cá nhân và thông tin liên hệ của bạn
                  </p>
                </div>
              </div>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              {/* Họ và Tên */}
              <div className="space-y-1.5 sm:col-span-1">
                <label className="block text-xs font-bold text-emerald-950 flex items-center gap-1.5">
                  <User className="w-3.5 h-3.5 text-emerald-600" />
                  <span>Họ và Tên</span>
                </label>
                <input
                  type="text"
                  value={profileData.name}
                  onChange={(e) => setProfileData({ ...profileData, name: e.target.value })}
                  placeholder="Nhập họ và tên"
                  className="w-full px-4 py-3 bg-emerald-50/40 hover:bg-emerald-50/70 focus:bg-white border border-emerald-200 rounded-2xl text-xs font-semibold text-emerald-950 focus:outline-none focus:border-emerald-500 focus:ring-4 focus:ring-emerald-500/10 transition-all"
                  required
                />
              </div>

              {/* Địa Chỉ Email */}
              <div className="space-y-1.5 sm:col-span-1">
                <label className="block text-xs font-bold text-emerald-950 flex items-center gap-1.5">
                  <Mail className="w-3.5 h-3.5 text-emerald-600" />
                  <span>Địa Chỉ Email</span>
                </label>
                <input
                  type="email"
                  value={profileData.email}
                  disabled={Boolean(profileData.email)}
                  onChange={(e) => setProfileData({ ...profileData, email: e.target.value })}
                  placeholder="Nhập địa chỉ email"
                  className="w-full px-4 py-3 bg-slate-100 border border-slate-200 rounded-2xl text-xs font-semibold text-slate-600 cursor-not-allowed"
                />
              </div>

              {/* Số Điện Thoại */}
              {Boolean(profileData.phone && profileData.phone.trim()) && (
                <div className="space-y-1.5 sm:col-span-1">
                  <label className="block text-xs font-bold text-emerald-950 flex items-center gap-1.5">
                    <Phone className="w-3.5 h-3.5 text-emerald-600" />
                    <span>Số Điện Thoại (Tên đăng nhập)</span>
                  </label>
                  <input
                    type="text"
                    value={profileData.phone}
                    disabled
                    className="w-full px-4 py-3 bg-slate-100 border border-slate-200 rounded-2xl text-xs font-semibold text-slate-600 cursor-not-allowed"
                  />
                </div>
              )}

              {/* Giới Tính */}
              <div className="space-y-1.5 sm:col-span-1">
                <label className="block text-xs font-bold text-emerald-950 flex items-center gap-1.5">
                  <UserCheck className="w-3.5 h-3.5 text-emerald-600" />
                  <span>Giới Tính</span>
                </label>
                <select
                  value={profileData.gender}
                  onChange={(e) => setProfileData({ ...profileData, gender: e.target.value })}
                  className="w-full px-4 py-3 bg-emerald-50/40 hover:bg-emerald-50/70 focus:bg-white border border-emerald-200 rounded-2xl text-xs font-semibold text-emerald-950 focus:outline-none focus:border-emerald-500 focus:ring-4 focus:ring-emerald-500/10 transition-all cursor-pointer"
                >
                  <option value="male">Nam</option>
                  <option value="female">Nữ</option>
                  <option value="other">Khác</option>
                </select>
              </div>

              {/* Ngày Sinh */}
              <div className="space-y-1.5 sm:col-span-1">
                <label className="block text-xs font-bold text-emerald-950 flex items-center gap-1.5">
                  <Calendar className="w-3.5 h-3.5 text-emerald-600" />
                  <span>Ngày Sinh</span>
                </label>
                <input
                  type="date"
                  value={profileData.dob}
                  onChange={(e) => setProfileData({ ...profileData, dob: e.target.value })}
                  className="w-full px-4 py-3 bg-emerald-50/40 hover:bg-emerald-50/70 focus:bg-white border border-emerald-200 rounded-2xl text-xs font-semibold text-emerald-950 focus:outline-none focus:border-emerald-500 focus:ring-4 focus:ring-emerald-500/10 transition-all"
                />
              </div>

              {/* Vai Trò Phân Quyền */}
              {Boolean(profileData.role && profileData.role.trim()) && (
                <div className="space-y-1.5 sm:col-span-1">
                  <label className="block text-xs font-bold text-emerald-950 flex items-center gap-1.5">
                    <ShieldCheck className="w-3.5 h-3.5 text-emerald-600" />
                    <span>Vai Trò Phân Quyền</span>
                  </label>
                  <input
                    type="text"
                    value={profileData.role}
                    disabled
                    className="w-full px-4 py-3 bg-slate-100 border border-slate-200 rounded-2xl text-xs font-semibold text-slate-600 cursor-not-allowed"
                  />
                </div>
              )}

              {/* Giới Thiệu (Bio) */}
              <div className="space-y-1.5 sm:col-span-2">
                <label className="block text-xs font-bold text-emerald-950 flex items-center gap-1.5">
                  <FileText className="w-3.5 h-3.5 text-emerald-600" />
                  <span>Giới Thiệu (Bio)</span>
                </label>
                <textarea
                  rows={2}
                  value={profileData.bio}
                  onChange={(e) => setProfileData({ ...profileData, bio: e.target.value })}
                  placeholder="Mô tả ngắn về bản thân..."
                  className="w-full px-4 py-3 bg-emerald-50/40 hover:bg-emerald-50/70 focus:bg-white border border-emerald-200 rounded-2xl text-xs font-semibold text-emerald-950 focus:outline-none focus:border-emerald-500 focus:ring-4 focus:ring-emerald-500/10 transition-all"
                />
              </div>
            </div>

            <div className="pt-3 border-t border-emerald-100 flex justify-end">
              <button
                type="submit"
                disabled={savingProfile}
                className="px-6 py-3 rounded-2xl bg-gradient-to-r from-emerald-600 via-green-600 to-teal-600 hover:from-emerald-700 hover:to-teal-700 text-white font-extrabold text-xs sm:text-sm shadow-md shadow-emerald-600/20 flex items-center gap-2 cursor-pointer transition-all active:scale-98 disabled:opacity-50"
              >
                {savingProfile ? <Loader2 className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
                <span>Lưu Thông Tin</span>
              </button>
            </div>
          </form>
        </div>

        {/* Right Column: Change Password Card */}
        <div className="lg:col-span-1">
          <form
            onSubmit={handleChangePassword}
            className="p-6 sm:p-8 rounded-[32px] bg-white border border-emerald-100 shadow-sm space-y-5 h-full flex flex-col justify-between"
          >
            <div className="space-y-5">
              <div className="flex items-center gap-2.5 border-b border-emerald-100 pb-4">
                <div className="p-2.5 rounded-xl bg-emerald-50 text-emerald-700">
                  <KeyRound className="w-5 h-5" />
                </div>
                <div>
                  <h4 className="text-base font-black text-emerald-950">Đổi Mật Khẩu</h4>
                  <p className="text-xs text-emerald-900/60 font-medium">Tăng cường bảo mật cho tài khoản</p>
                </div>
              </div>

              {/* Password Error Alert */}
              {passwordError && (
                <div className="p-3 rounded-2xl bg-rose-50 border border-rose-200 text-rose-700 text-xs font-bold flex items-center gap-2 animate__animated animate__fadeIn animate__faster">
                  <AlertCircle className="w-4 h-4 text-rose-500 flex-shrink-0" />
                  <span>{passwordError}</span>
                </div>
              )}

              {/* Password Success Alert */}
              {passwordSuccess && (
                <div className="p-3 rounded-2xl bg-emerald-50 border border-emerald-200 text-emerald-800 text-xs font-bold flex items-center gap-2 animate__animated animate__fadeIn animate__faster">
                  <CheckCircle2 className="w-4 h-4 text-emerald-600 flex-shrink-0" />
                  <span>Đổi mật khẩu thành công!</span>
                </div>
              )}

              {/* Current Password */}
              <div className="space-y-1.5">
                <label className="block text-xs font-bold text-emerald-950">Mật Khẩu Hiện Tại</label>
                <div className="relative">
                  <input
                    type={showCurrentPw ? 'text' : 'password'}
                    value={passwordForm.currentPassword}
                    onChange={(e) => setPasswordForm({ ...passwordForm, currentPassword: e.target.value })}
                    placeholder="Nhập mật khẩu hiện tại"
                    className="w-full pl-4 pr-10 py-3 bg-emerald-50/40 hover:bg-emerald-50/70 focus:bg-white border border-emerald-200 rounded-2xl text-xs font-semibold text-emerald-950 focus:outline-none focus:border-emerald-500 focus:ring-4 focus:ring-emerald-500/10 transition-all"
                  />
                  <button
                    type="button"
                    onClick={() => setShowCurrentPw(!showCurrentPw)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-emerald-700 p-1 cursor-pointer"
                  >
                    {showCurrentPw ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                  </button>
                </div>
              </div>

              {/* New Password */}
              <div className="space-y-1.5">
                <label className="block text-xs font-bold text-emerald-950">Mật Khẩu Mới</label>
                <div className="relative">
                  <input
                    type={showNewPw ? 'text' : 'password'}
                    value={passwordForm.newPassword}
                    onChange={(e) => setPasswordForm({ ...passwordForm, newPassword: e.target.value })}
                    placeholder="Nhập mật khẩu mới"
                    className="w-full pl-4 pr-10 py-3 bg-emerald-50/40 hover:bg-emerald-50/70 focus:bg-white border border-emerald-200 rounded-2xl text-xs font-semibold text-emerald-950 focus:outline-none focus:border-emerald-500 focus:ring-4 focus:ring-emerald-500/10 transition-all"
                  />
                  <button
                    type="button"
                    onClick={() => setShowNewPw(!showNewPw)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-emerald-700 p-1 cursor-pointer"
                  >
                    {showNewPw ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                  </button>
                </div>
              </div>

              {/* Confirm Password */}
              <div className="space-y-1.5">
                <label className="block text-xs font-bold text-emerald-950">Xác Nhận Mật Khẩu Mới</label>
                <div className="relative">
                  <input
                    type={showConfirmPw ? 'text' : 'password'}
                    value={passwordForm.confirmPassword}
                    onChange={(e) => setPasswordForm({ ...passwordForm, confirmPassword: e.target.value })}
                    placeholder="Nhập lại mật khẩu mới"
                    className="w-full pl-4 pr-10 py-3 bg-emerald-50/40 hover:bg-emerald-50/70 focus:bg-white border border-emerald-200 rounded-2xl text-xs font-semibold text-emerald-950 focus:outline-none focus:border-emerald-500 focus:ring-4 focus:ring-emerald-500/10 transition-all"
                  />
                  <button
                    type="button"
                    onClick={() => setShowConfirmPw(!showConfirmPw)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-emerald-700 p-1 cursor-pointer"
                  >
                    {showConfirmPw ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                  </button>
                </div>
              </div>
            </div>

            <div className="pt-4 border-t border-emerald-100">
              <button
                type="submit"
                className="w-full py-3 rounded-2xl bg-gradient-to-r from-emerald-600 via-green-600 to-teal-600 hover:from-emerald-700 hover:to-teal-700 text-white font-extrabold text-xs sm:text-sm shadow-md shadow-emerald-600/20 flex items-center justify-center gap-2 cursor-pointer transition-all active:scale-98"
              >
                <KeyRound className="w-4 h-4" />
                <span>Cập Nhật Mật Khẩu</span>
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
};

export default AdminProfile;
