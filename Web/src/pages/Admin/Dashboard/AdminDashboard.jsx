import React, { useEffect, useState } from 'react';
import { useOutletContext, useNavigate } from 'react-router-dom';
import {
  Users,
  DollarSign,
  TrendingUp,
  PackageCheck,
  Calendar,
  ChevronRight,
  Cpu,
  PieChart,
  UserPlus,
} from 'lucide-react';
import goodMorningImg from '../../../assets/images/goodmorning-Photoroom.png';
import goodAfternoonImg from '../../../assets/images/goodafternoon-Photoroom.png';
import goodEveningImg from '../../../assets/images/goodevening-Photoroom.png';
import {
  getAdminStatsOverviewApi,
  getAdminStatsAiUsageApi,
  getAdminStatsSubscriptionsApi,
} from '../../../services/adminService';
import { getMeApi } from '../../../services/userService';
import AnimatedCounter from '../../../components/common/AnimatedCounter';

export const AdminDashboard = (props) => {


  const context = useOutletContext() || {};
  const navigate = useNavigate();

  // Stats Data States
  const [overviewData, setOverviewData] = useState(null);
  const [aiUsageData, setAiUsageData] = useState(null);
  const [subscriptionData, setSubscriptionData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [aiDays, setAiDays] = useState(7);

  const onNavigateTab = props.onNavigateTab || ((tab) => navigate(`/admin/${tab}`));

  // Helper to resolve avatar URL path
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

  // Synchronously get cached admin name & avatar from localStorage
  const getInitialAdminInfo = () => {
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
        const avatarUrl = me.profile?.avatarUrl || me.avatarUrl || me.profile?.avatarPath || me.avatarPath || null;
        return { name, avatarUrl };
      }
    } catch (e) {}
    return { name: '', avatarUrl: null };
  };

  const initialInfo = getInitialAdminInfo();
  const [adminName, setAdminName] = useState(initialInfo.name);
  const [adminAvatarUrl, setAdminAvatarUrl] = useState(initialInfo.avatarUrl);

  // Fetch all 3 Stats APIs & User Profile
  const fetchAllStats = async () => {
    setLoading(true);
    try {
      const [overviewRes, aiUsageRes, subRes, meRes] = await Promise.allSettled([
        getAdminStatsOverviewApi(),
        getAdminStatsAiUsageApi(aiDays),
        getAdminStatsSubscriptionsApi(),
        getMeApi(),
      ]);

      if (overviewRes.status === 'fulfilled') {
        setOverviewData(overviewRes.value?.data || overviewRes.value);
      }
      if (aiUsageRes.status === 'fulfilled') {
        setAiUsageData(aiUsageRes.value?.data || aiUsageRes.value);
      }
      if (subRes.status === 'fulfilled') {
        const list = Array.isArray(subRes.value?.data)
          ? subRes.value.data
          : Array.isArray(subRes.value)
          ? subRes.value
          : [];
        setSubscriptionData(list);
      }
      if (meRes.status === 'fulfilled') {
        const me = meRes.value?.data || meRes.value;
        if (me) {
          try {
            localStorage.setItem('friggy_user', JSON.stringify(me));
            localStorage.setItem('user', JSON.stringify(me));
          } catch (e) {}
          const fetchedName =
            me.name ||
            me.profile?.name ||
            (me.googleEmail ? me.googleEmail.split('@')[0] : null) ||
            (me.email ? me.email.split('@')[0] : null) ||
            '';
          const fetchedAvatar = me.profile?.avatarUrl || me.avatarUrl || me.profile?.avatarPath || me.avatarPath || null;
          setAdminName(fetchedName);
          setAdminAvatarUrl(fetchedAvatar);
        }
      }
    } catch (err) {
      console.error('Lỗi khi lấy dữ liệu thống kê Admin:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchAllStats();

    const handleProfileUpdate = () => {
      getMeApi()
        .then((res) => {
          const me = res?.data || res;
          if (me) {
            try {
              localStorage.setItem('friggy_user', JSON.stringify(me));
              localStorage.setItem('user', JSON.stringify(me));
            } catch (e) {}
            const fetchedName =
              me.name ||
              me.profile?.name ||
              (me.googleEmail ? me.googleEmail.split('@')[0] : null) ||
              (me.email ? me.email.split('@')[0] : null) ||
              '';
            const fetchedAvatar = me.profile?.avatarUrl || me.avatarUrl || me.profile?.avatarPath || me.avatarPath || null;
            setAdminName(fetchedName);
            setAdminAvatarUrl(fetchedAvatar);
          }
        })
        .catch(() => {});
    };

    window.addEventListener('user_profile_updated', handleProfileUpdate);
    return () => window.removeEventListener('user_profile_updated', handleProfileUpdate);
  }, [aiDays]);

  // Greeting based on time
  const getTimeGreeting = () => {
    const hour = new Date().getHours();
    const namePart = adminName ? `, ${adminName}` : '';
    if (hour >= 5 && hour < 12) {
      return { title: `Chào buổi sáng${namePart}! ☀️`, image: goodMorningImg, alt: 'Good Morning' };
    } else if (hour >= 12 && hour < 18) {
      return { title: `Chào buổi chiều${namePart}! 🌤️`, image: goodAfternoonImg, alt: 'Good Afternoon' };
    } else {
      return { title: `Chào buổi tối${namePart}! 🌙`, image: goodEveningImg, alt: 'Good Evening' };
    }
  };

  const timeGreeting = getTimeGreeting();

  // Stats values
  const totalUsers = overviewData?.totalUsers ?? 0;
  const activeUsers = overviewData?.activeUsers ?? 0;
  const suspendedUsers = overviewData?.suspendedUsers ?? 0;
  const newUsersThisMonth = overviewData?.newUsersThisMonth ?? 0;
  const activeSubscriptions = overviewData?.activeSubscriptions ?? 0;
  const revenueThisMonthVnd = overviewData?.revenueThisMonthVnd ?? 0;

  const statCards = [
    {
      title: 'TỔNG NGƯỜI DÙNG',
      numericValue: totalUsers,
      growth: `Active: ${activeUsers}`,
      icon: Users,
      bgColor: 'bg-emerald-50',
      textColor: 'text-emerald-600',
      borderColor: 'border-emerald-200',
      subtext: `Hoạt động: ${activeUsers} • Bị khóa: ${suspendedUsers}`,
    },
    {
      title: 'USER MUA GÓI (SUBSCRIPTIONS)',
      numericValue: activeSubscriptions,
      growth: 'Active Plans',
      icon: PackageCheck,
      bgColor: 'bg-teal-50',
      textColor: 'text-teal-600',
      borderColor: 'border-teal-200',
      subtext: 'Tài khoản đang có gói đăng ký active',
    },
    {
      title: 'DOANH THU THÁNG NÀY',
      numericValue: revenueThisMonthVnd,
      isCurrency: true,
      growth: 'Tháng hiện tại',
      icon: DollarSign,
      bgColor: 'bg-green-50',
      textColor: 'text-green-600',
      borderColor: 'border-green-200',
      subtext: 'Doanh thu từ các gói đăng ký active',
    },
    {
      title: 'USER MỚI THÁNG NÀY',
      numericValue: newUsersThisMonth,
      growth: '+ Mới',
      icon: UserPlus,
      bgColor: 'bg-emerald-50',
      textColor: 'text-emerald-600',
      borderColor: 'border-emerald-200',
      subtext: 'Thành viên mới đăng ký trong tháng',
    },
  ];

  // Helper formatting for feature types
  const formatFeatureName = (type) => {
    switch (type) {
      case 'scan_ingredient':
      case 'ingredient_scan':
        return { name: 'Quét Ảnh Nguyên Liệu Tủ Lạnh', icon: '📸' };
      case 'recipe_suggest':
      case 'recipe_generation':
        return { name: 'Gợi Ý Món Ăn Tự Động', icon: '🍳' };
      case 'chat_assistant':
      case 'fridge_chat':
        return { name: 'Trợ Lý Tư Vấn Friggy AI', icon: '💬' };
      default:
        return { name: type, icon: '🤖' };
    }
  };

  return (
    <div className="space-y-8 pb-12 animate__animated animate__fadeIn animate__faster">
      {/* Welcome Banner */}
      <div className="p-6 sm:p-8 lg:p-10 rounded-[32px] bg-gradient-to-r from-[#dcfce7] via-[#eaf6ef] to-[#d1fae5] text-emerald-950 relative overflow-hidden shadow-xs border border-emerald-200/90 animate__animated animate__fadeInDown">
        <div className="absolute top-0 right-0 w-96 h-96 bg-emerald-400/20 rounded-full blur-3xl pointer-events-none" />

        <div className="relative z-10 flex flex-col md:flex-row md:items-center justify-between gap-6">
          <div className="space-y-3 max-w-2xl">
            <div className="inline-flex items-center gap-2 px-3.5 py-1 rounded-full bg-emerald-600/10 border border-emerald-600/20 text-emerald-800 text-xs font-bold">
              <Calendar className="w-3.5 h-3.5 text-emerald-600" />
              <span>
                {new Date().toLocaleDateString('vi-VN', {
                  weekday: 'long',
                  year: 'numeric',
                  month: 'long',
                  day: 'numeric',
                })}
              </span>
            </div>

            <h2 className="text-2xl sm:text-3xl lg:text-4xl font-black tracking-tight text-emerald-950 animate__animated animate__fadeInLeft">
              {timeGreeting.title}
            </h2>

            <p className="text-xs sm:text-sm text-emerald-900/75 font-semibold leading-relaxed">
              Báo cáo số liệu tổng quan người dùng, lượng sử dụng AI Engine và phân bố gói cước trực tiếp từ hệ thống.
            </p>
          </div>

          {/* Time-of-day dynamic mascot image */}
          <div className="flex items-center justify-center md:justify-end shrink-0">
            <img
              src={timeGreeting.image}
              alt={timeGreeting.alt}
              className="w-52 h-52 sm:w-64 sm:h-64 md:w-72 md:h-72 lg:w-80 lg:h-80 -my-3 lg:-my-6 object-contain drop-shadow-lg relative z-10 animate__animated animate__zoomIn"
            />
          </div>
        </div>
      </div>

      {/* SECTION 1: Overview Cards */}
      <div className="space-y-3">
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
          {statCards.map((card) => {
            const IconComponent = card.icon;
            return (
              <div
                key={card.title}
                className="p-6 rounded-[28px] bg-white border border-slate-100 shadow-md hover:shadow-xl transition-all duration-300 group relative overflow-hidden animate__animated animate__fadeInUp"
              >
                <div className="flex items-center justify-between mb-4">
                  <div
                    className={`w-12 h-12 rounded-2xl ${card.bgColor} ${card.textColor} border ${card.borderColor} flex items-center justify-center shadow-xs group-hover:scale-110 transition-transform`}
                  >
                    <IconComponent className="w-6 h-6" />
                  </div>
                  <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full bg-emerald-50 text-emerald-700 text-xs font-black border border-emerald-200">
                    <TrendingUp className="w-3 h-3" />
                    {card.growth}
                  </span>
                </div>

                <p className="text-[11px] font-extrabold text-slate-400 tracking-wider uppercase">
                  {card.title}
                </p>

                <h3 className="text-2xl font-black text-slate-900 my-1 tracking-tight flex items-center">
                  {card.isCurrency ? (
                    <AnimatedCounter
                      end={card.numericValue}
                      duration={2}
                      separator="."
                      suffix=" ₫"
                    />
                  ) : (
                    <AnimatedCounter
                      end={card.numericValue}
                      duration={1.8}
                      separator="."
                    />
                  )}
                </h3>
                <p className="text-[11px] text-slate-500 font-semibold">{card.subtext}</p>
              </div>
            );
          })}
        </div>
      </div>

      {/* SECTION 2 & 3: Two Column Layout for AI Usage & Subscriptions */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* AI Usage Breakdown */}
        <div className="p-6 rounded-[32px] bg-white border border-slate-100 shadow-md space-y-5 flex flex-col justify-between animate__animated animate__fadeInLeft">
          <div className="space-y-4">
            <div className="flex items-center justify-between border-b pb-3">
              <div>
                <h3 className="font-black text-slate-900 text-base flex items-center gap-2">
                  <Cpu className="w-5 h-5 text-emerald-600" />
                  Lượt Sử Dụng AI theo Tính Năng
                </h3>
              </div>

              {/* Day filter selector */}
              <div className="flex items-center gap-1 bg-slate-100 p-1 rounded-xl">
                <button
                  onClick={() => setAiDays(7)}
                  className={`px-3 py-1 rounded-lg text-xs font-bold transition-all ${
                    aiDays === 7 ? 'bg-white text-emerald-700 shadow-xs' : 'text-slate-600'
                  }`}
                >
                  7 Ngày
                </button>
                <button
                  onClick={() => setAiDays(30)}
                  className={`px-3 py-1 rounded-lg text-xs font-bold transition-all ${
                    aiDays === 30 ? 'bg-white text-emerald-700 shadow-xs' : 'text-slate-600'
                  }`}
                >
                  30 Ngày
                </button>
              </div>
            </div>

            <div className="p-4 rounded-2xl bg-emerald-50/60 border border-emerald-100 flex items-center justify-between">
              <span className="text-xs font-extrabold text-emerald-900">
                Tổng số lượt gọi AI ({aiUsageData?.period || `${aiDays} ngày`}):
              </span>
              <span className="text-xl font-black text-emerald-700 flex items-center gap-1">
                <AnimatedCounter end={aiUsageData?.totalCalls ?? 0} duration={2} separator="." /> lượt
              </span>
            </div>

            {/* Breakdown List */}
            {!aiUsageData?.breakdown || aiUsageData.breakdown.length === 0 ? (
              <div className="py-8 text-center text-slate-400 font-semibold text-xs">
                Chưa có dữ liệu lượt gọi AI trong thời gian này.
              </div>
            ) : (
              <div className="space-y-3">
                {aiUsageData.breakdown.map((item) => {
                  const info = formatFeatureName(item.featureType);
                  const total = aiUsageData.totalCalls || 1;
                  const percent = Math.round((item.count / total) * 100);

                  return (
                    <div
                      key={item.featureType}
                      className="p-3.5 rounded-2xl bg-slate-50 border border-slate-100 space-y-2 animate__animated animate__fadeInUp"
                    >
                      <div className="flex items-center justify-between text-xs">
                        <span className="font-black text-slate-800 flex items-center gap-1.5">
                          <span>{info.icon}</span>
                          <span>{info.name}</span>
                        </span>
                        <span className="font-extrabold text-emerald-700">
                          <AnimatedCounter end={item.count} duration={1.5} separator="." /> lượt ({percent}%)
                        </span>
                      </div>
                      <div className="w-full h-2 rounded-full bg-slate-200 overflow-hidden">
                        <div
                          style={{ width: `${Math.max(percent, 5)}%` }}
                          className="h-full bg-gradient-to-r from-emerald-500 to-teal-600 rounded-full transition-all duration-700 ease-out"
                        />
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>

          <button
            onClick={() => onNavigateTab('ai')}
            className="w-full py-2.5 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold text-xs flex items-center justify-center gap-1 transition-colors cursor-pointer"
          >
            <span>Đến Quản Lý AI Engine</span>
            <ChevronRight className="w-4 h-4" />
          </button>
        </div>

        {/* Subscriptions Breakdown */}
        <div className="p-6 rounded-[32px] bg-white border border-slate-100 shadow-md space-y-5 flex flex-col justify-between animate__animated animate__fadeInRight">
          <div className="space-y-4">
            <div className="flex items-center justify-between border-b pb-3">
              <div>
                <h3 className="font-black text-slate-900 text-base flex items-center gap-2">
                  <PieChart className="w-5 h-5 text-emerald-600" />
                  Phân Bổ Các Gói Đăng Ký (Subscriptions)
                </h3>
              </div>
              <span className="px-3 py-1 rounded-full bg-teal-50 text-teal-700 text-xs font-black border border-teal-200 flex items-center gap-1">
                <AnimatedCounter end={activeSubscriptions} duration={2} separator="." /> Active Users
              </span>
            </div>

            {!subscriptionData || subscriptionData.length === 0 ? (
              <div className="py-12 text-center text-slate-400 font-semibold text-xs">
                Chưa có dữ liệu phân bổ gói cước.
              </div>
            ) : (
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                {subscriptionData.map((sub, idx) => {
                  const planName = sub.plan?.displayName || sub.plan?.name || `Gói #${sub.planId || idx + 1}`;
                  const count = sub.activeSubscribers ?? 0;

                  return (
                    <div
                      key={sub.planId || idx}
                      className="p-4 rounded-2xl bg-gradient-to-br from-slate-50 to-emerald-50/40 border border-slate-200/80 space-y-2 animate__animated animate__zoomIn"
                    >
                      <span className="text-[10px] font-mono font-bold text-slate-400 uppercase tracking-wider block">
                        PLAN #{sub.planId || idx + 1}
                      </span>
                      <h4 className="font-black text-slate-900 text-sm">{planName}</h4>
                      <div className="flex items-center justify-between pt-1">
                        <span className="text-xs text-slate-500 font-semibold">Người dùng Active:</span>
                        <span className="text-lg font-black text-emerald-700 flex items-center gap-1">
                          <AnimatedCounter end={count} duration={1.5} separator="." /> user
                        </span>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>

          <button
            onClick={() => onNavigateTab('users')}
            className="w-full py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs flex items-center justify-center gap-1 transition-colors cursor-pointer shadow-md"
          >
            <span>Đến Quản Lý Danh Sách Người Dùng</span>
            <ChevronRight className="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>
  );
};

export default AdminDashboard;

