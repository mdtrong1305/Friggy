import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { useNavigate } from 'react-router-dom';
import { User, Lock, Eye, EyeOff, ArrowLeft, Sparkles, ShieldCheck, CheckCircle2 } from 'lucide-react';
import cuteMascotImg from '../../../assets/images/cute_mascot.png';
import qrMascotImg from '../../../assets/images/QR.png';
import mascotImg from '../../../assets/images/mascot.png';
import suggestImg from '../../../assets/images/suggest.png';
import { adminAccount, initialUsers } from '../../../data/adminMockData';
import { emailLoginApi, googleAuthApi } from '../../../services/authService';
import { showToast } from '../../../components/common/Toast';

export const Login = ({ onBack, onLoginSuccess }) => {
  const navigate = useNavigate();
  const [showPassword, setShowPassword] = useState(false);
  const [formData, setFormData] = useState({
    username: '',
    password: '',
    remember: true,
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleBack = () => {
    if (onBack) {
      onBack();
    } else {
      navigate('/');
    }
  };

  const handleChange = (e) => {
    const { name, value, type, checked } = e.target;
    setFormData((prev) => ({
      ...prev,
      [name]: type === 'checkbox' ? checked : value,
    }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');

    const inputEmail = formData.username.trim();
    const inputPass = formData.password.trim();

    if (!inputEmail || !inputPass) {
      setError('Vui lòng nhập đầy đủ Email và Mật khẩu.');
      return;
    }

    setLoading(true);

    try {
      // Gọi API POST /api/v1/auth/email/login
      const res = await emailLoginApi(inputEmail, inputPass);
      const authData = res.data || res;

      // Lưu accessToken & refreshToken vào localStorage với tiền tố friggy_
      if (authData.accessToken) {
        localStorage.setItem('friggy_access_token', authData.accessToken);
        localStorage.setItem('accessToken', authData.accessToken);
      }
      if (authData.refreshToken) {
        localStorage.setItem('friggy_refresh_token', authData.refreshToken);
        localStorage.setItem('refreshToken', authData.refreshToken);
      }
      if (authData.user) {
        localStorage.setItem('friggy_user', JSON.stringify(authData.user));
        localStorage.setItem('user', JSON.stringify(authData.user));
      }

      showToast.success(`Đăng nhập thành công! Chào mừng ${authData.user?.name || authData.user?.email || inputEmail}`);

      const userRole = String(
        authData.user?.role?.name || authData.user?.role || ''
      ).toLowerCase();
      const isAdmin = userRole === 'admin' || userRole.includes('admin');

      if (isAdmin) {
        navigate('/admin/dashboard', { replace: true });
        if (onLoginSuccess) onLoginSuccess(authData.user);
      } else {
        navigate('/', { replace: true });
        if (onLoginSuccess) onLoginSuccess(authData.user);
      }
    } catch (err) {
      console.error('Email Login Error:', err);

      // Fallback kiểm tra tài khoản Mock nếu backend offline hoặc dùng account admin mock
      const validAccounts = [
        adminAccount,
        ...initialUsers.map((u) => ({
          ...u,
          password: u.password || '123456',
        })),
      ];

      const matchedAccount = validAccounts.find((acc) => {
        const matchesUser =
          acc.username === inputEmail ||
          acc.phone === inputEmail ||
          acc.email === inputEmail;
        const matchesPass = acc.password === inputPass;
        return matchesUser && matchesPass;
      });

      if (matchedAccount) {
        const roleLower = String(matchedAccount.role || '').toLowerCase();
        const isAdmin = roleLower === 'admin' || roleLower.includes('admin');

        showToast.success(`Đăng nhập thành công! Chào mừng ${matchedAccount.name || matchedAccount.username}`);
        if (isAdmin) {
          navigate('/admin/dashboard', { replace: true });
          if (onLoginSuccess) onLoginSuccess(matchedAccount);
        } else {
          navigate('/', { replace: true });
          if (onLoginSuccess) onLoginSuccess(matchedAccount);
        }
        return;
      }

      const errMsg = err.message || 'Tên đăng nhập hoặc mật khẩu không chính xác!';
      setError(errMsg);
      showToast.error(errMsg);
    } finally {
      setLoading(false);
    }
  };

  const handleGoogleSignIn = async () => {
    setError('');
    setLoading(true);

    try {
      const clientId =
        import.meta.env.VITE_GOOGLE_CLIENT_ID ||
        '717739810642-4neqbd4q4v3i65hup78shtn557u80d3s.apps.googleusercontent.com';

      if (!window.google?.accounts?.id) {
        showToast.error('Thư viện Google SDK đang được tải, vui lòng bấm lại sau 2 giây!');
        setLoading(false);
        return;
      }

      window.google.accounts.id.initialize({
        client_id: clientId,
        callback: async (googleRes) => {
          try {
            const idToken = googleRes.credential;
            if (!idToken) {
              showToast.error('Không lấy được Google ID Token!');
              setLoading(false);
              return;
            }

            // Gọi API POST /api/v1/auth/google
            const res = await googleAuthApi(idToken);
            const authData = res.data || res;

            // Lưu accessToken & refreshToken vào localStorage với tiền tố friggy_
            if (authData.accessToken) {
              localStorage.setItem('friggy_access_token', authData.accessToken);
              localStorage.setItem('accessToken', authData.accessToken);
            }
            if (authData.refreshToken) {
              localStorage.setItem('friggy_refresh_token', authData.refreshToken);
              localStorage.setItem('refreshToken', authData.refreshToken);
            }
            if (authData.user) {
              localStorage.setItem('friggy_user', JSON.stringify(authData.user));
              localStorage.setItem('user', JSON.stringify(authData.user));
            }

            showToast.success('Đăng nhập thành công với Google!');

            // Check role: nếu role là admin -> chuyển trang chủ admin, nếu user -> trang người dùng
            const userRole = String(
              authData.user?.role?.name || authData.user?.role || ''
            ).toLowerCase();

            if (userRole === 'admin' || userRole.includes('admin')) {
              navigate('/admin/dashboard', { replace: true });
              if (onLoginSuccess) onLoginSuccess(authData.user);
            } else {
              navigate('/', { replace: true });
              if (onLoginSuccess) onLoginSuccess(authData.user);
            }
          } catch (err) {
            console.error('Google Auth API Error:', err);
            const errMsg = err.message || 'Đăng nhập Google thất bại!';
            setError(errMsg);
            showToast.error(errMsg);
          } finally {
            setLoading(false);
          }
        },
      });

      // Mở hộp thoại chọn tài khoản Google (Google One-Tap Prompt)
      window.google.accounts.id.prompt((notification) => {
        if (notification.isNotDisplayed() || notification.isSkippedMoment()) {
          // Fallback: Tự động giả lập hoặc mở giao diện popup nút Google
          const btnWrapper = document.createElement('div');
          btnWrapper.style.position = 'fixed';
          btnWrapper.style.top = '-9999px';
          document.body.appendChild(btnWrapper);
          window.google.accounts.id.renderButton(btnWrapper, { theme: 'outline', size: 'large' });
          const googleBtnEl = btnWrapper.querySelector('div[role="button"]');
          if (googleBtnEl) {
            googleBtnEl.click();
          } else {
            showToast.error('Hãy cho phép hiển thị cửa sổ Google Login trên trình duyệt.');
            setLoading(false);
          }
          setTimeout(() => btnWrapper.remove(), 3000);
        }
      });
    } catch (err) {
      console.error('Google Auth Error:', err);
      showToast.error('Đã xảy ra lỗi khi đăng nhập bằng Google.');
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen w-full bg-gradient-to-br from-[#c8ebd9] via-[#b2e5cb] to-[#99dcba] flex items-center justify-center p-4 sm:p-6 lg:p-8 relative overflow-hidden select-none">
      {/* Background Decorative Radial Glow Blobs */}
      <div className="absolute top-1/4 left-1/4 -translate-x-1/2 -translate-y-1/2 w-[650px] h-[650px] bg-white/40 rounded-full blur-3xl pointer-events-none" />
      <div className="absolute bottom-10 right-10 w-[600px] h-[600px] bg-emerald-300/30 rounded-full blur-3xl pointer-events-none" />

      {/* Back to Home Button */}
      <button
        onClick={handleBack}
        className="absolute top-6 left-6 z-30 flex items-center gap-2 bg-white/95 hover:bg-emerald-600 text-emerald-950 hover:text-white shadow-md border border-emerald-300/80 px-4.5 py-2.5 rounded-2xl text-xs sm:text-sm font-bold transition-all duration-200 cursor-pointer group"
      >
        <ArrowLeft className="w-4 h-4 group-hover:-translate-x-1 transition-transform" />
        <span>Quay lại trang chủ</span>
      </button>

      {/* Main Glassmorphic Container */}
      <motion.div
        initial={{ opacity: 0, scale: 0.94, y: 20 }}
        animate={{ opacity: 1, scale: 1, y: 0 }}
        transition={{ duration: 0.6, ease: [0.25, 1, 0.5, 1] }}
        className="w-full max-w-4xl bg-white/95 backdrop-blur-2xl rounded-[36px] shadow-2xl shadow-emerald-950/15 border border-white overflow-hidden grid grid-cols-1 lg:grid-cols-12 relative z-20"
      >
        {/* ================= LEFT SIDE: SHOWCASE BANNER (5 cols - Light Pastel Green Theme) ================= */}
        <div className="lg:col-span-5 bg-gradient-to-b from-emerald-50 via-emerald-100/70 to-teal-100/50 p-8 sm:p-10 border-r border-emerald-100/80 relative overflow-hidden flex flex-col justify-between hidden lg:flex">
          {/* Decorative soft glowing blur */}
          <div className="absolute -top-12 -left-12 w-48 h-48 bg-emerald-300/30 rounded-full blur-2xl pointer-events-none" />
          <div className="absolute -bottom-10 -right-10 w-52 h-52 bg-teal-200/40 rounded-full blur-2xl pointer-events-none" />

          {/* Logo & Brand Header */}
          <div className="relative z-10 space-y-2">
            <div className="flex items-center gap-3">
              <div className="w-11 h-11 rounded-2xl overflow-hidden bg-gradient-to-tr from-emerald-500 to-green-400 p-0.5 shadow-md flex items-center justify-center">
                <img src={cuteMascotImg} alt="Friggy Logo" className="w-full h-full object-cover rounded-xl bg-white" />
              </div>
              <div className="flex items-baseline">
                <span className="text-3xl font-black text-emerald-950">Fri</span>
                <span className="text-3xl font-black text-emerald-600">ggy</span>
                <span className="w-2.5 h-2.5 rounded-full bg-emerald-600 inline-block ml-1 shadow-xs"></span>
              </div>
            </div>
            <p className="text-xs text-emerald-900/75 font-semibold">Trợ lý quản lý tủ lạnh AI thông minh</p>
          </div>

          {/* Center Mascot Image & Greeting */}
          <div className="relative z-10 my-auto py-6 flex flex-col items-center text-center space-y-4">
            <motion.div
              animate={{ y: [0, -12, 0] }}
              transition={{ duration: 3.0, repeat: Infinity, ease: 'easeInOut' }}
              className="relative"
            >
              <div className="absolute inset-0 bg-emerald-300/40 rounded-full blur-2xl pointer-events-none" />
              <img
                src={qrMascotImg}
                alt="Friggy QR Mascot"
                className="w-48 sm:w-52 h-auto object-contain relative z-10 drop-shadow-xl"
              />
            </motion.div>

            <div className="space-y-1.5 max-w-xs">
              <h3 className="text-lg font-black text-emerald-950 tracking-tight">
                Chào Mừng Bạn Trở Lại!
              </h3>
              <p className="text-xs text-emerald-900/75 font-medium leading-relaxed">
                Giảm 100% lãng phí thực phẩm & nhận gợi ý món ăn ngon từ AI Friggy Chef mỗi ngày.
              </p>
            </div>
          </div>

          {/* Bottom Bullet Benefits */}
          <div className="relative z-10 space-y-2 pt-4 border-t border-emerald-200/70">
            <div className="flex items-center gap-2.5 bg-white/80 border border-emerald-200/60 p-2.5 rounded-2xl shadow-xs">
              <ShieldCheck className="w-4 h-4 text-emerald-600 flex-shrink-0" />
              <span className="text-xs font-bold text-emerald-950">Bảo mật dữ liệu gia đình 100%</span>
            </div>
            <div className="flex items-center gap-2.5 bg-white/80 border border-emerald-200/60 p-2.5 rounded-2xl shadow-xs">
              <Sparkles className="w-4 h-4 text-emerald-600 flex-shrink-0" />
              <span className="text-xs font-bold text-emerald-950">Gợi ý thực đơn thông minh chuẩn Chef</span>
            </div>
          </div>
        </div>

        {/* ================= RIGHT SIDE: LOGIN FORM (7 cols) ================= */}
        <div className="lg:col-span-7 p-8 sm:p-10 lg:p-12 flex flex-col justify-center space-y-6 bg-white relative">
          {/* Header Mobile Logo (visible on small screens) */}
          <div className="lg:hidden flex items-center justify-center gap-2.5 mb-2">
            <img src={cuteMascotImg} alt="Friggy Logo" className="w-9 h-9 object-cover rounded-xl" />
            <div className="flex items-baseline">
              <span className="text-2xl font-black text-emerald-950">Fri</span>
              <span className="text-2xl font-black text-emerald-600">ggy</span>
              <span className="w-2 h-2 rounded-full bg-emerald-600 inline-block ml-1"></span>
            </div>
          </div>

          {/* Extra Large Floating Mascot Decor flush at top-right corner */}
          <motion.div
            animate={{ y: [0, -10, 0] }}
            transition={{ duration: 3.0, repeat: Infinity, ease: 'easeInOut' }}
            className="absolute -top-4 -right-4 sm:-top-6 sm:-right-6 z-10 pointer-events-none"
          >
            <div className="relative">
              <div className="absolute inset-0 bg-emerald-300/30 rounded-full blur-2xl pointer-events-none" />
              <img
                src={mascotImg}
                alt="Friggy Mascot Decor"
                className="w-40 sm:w-48 h-40 sm:h-48 object-contain relative z-10 drop-shadow-2xl"
              />
            </div>
          </motion.div>

          {/* Header Section */}
          <div className="space-y-1.5 border-b border-emerald-100/80 pb-5 relative z-20">
            <h2 className="text-2xl sm:text-3xl font-black text-emerald-950 tracking-tight whitespace-nowrap">
              Đăng Nhập Friggy
            </h2>
            <p className="text-xs sm:text-sm text-emerald-900/65 font-medium max-w-xs sm:max-w-sm">
              Nhập thông tin tài khoản của bạn để tiếp tục sử dụng ứng dụng.
            </p>
          </div>

          {/* Error Banner */}
          {error && (
            <motion.div
              initial={{ opacity: 0, y: -10 }}
              animate={{ opacity: 1, y: 0 }}
              className="p-3.5 rounded-2xl bg-rose-50 border border-rose-200 text-rose-700 text-xs sm:text-sm font-semibold flex items-center gap-2"
            >
              <div className="w-2 h-2 rounded-full bg-rose-500 animate-ping flex-shrink-0" />
              <span>{error}</span>
            </motion.div>
          )}

          {/* Form Inputs */}
          <form onSubmit={handleSubmit} className="space-y-5">
            {/* Username Input Field */}
            <div className="space-y-1.5 relative">
              <label className="block text-xs font-bold text-emerald-950 uppercase tracking-wider">
                Tên Đăng Nhập
              </label>
              <div className="relative">
                <div className="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-emerald-600">
                  <User className="w-4 h-4" />
                </div>
                <input
                  type="text"
                  name="username"
                  value={formData.username}
                  onChange={handleChange}
                  placeholder="Nhập tên đăng nhập hoặc số điện thoại"
                  className="w-full pl-10 pr-4 py-3.5 bg-white border-2 border-emerald-200 hover:border-emerald-400 rounded-2xl text-sm font-semibold text-emerald-950 placeholder-emerald-800/35 focus:outline-none focus:border-emerald-500 focus:ring-4 focus:ring-emerald-500/10 transition-all shadow-2xs"
                />
              </div>
            </div>

            {/* Password Input Field */}
            <div className="space-y-1.5 relative">
              <label className="block text-xs font-bold text-emerald-950 uppercase tracking-wider">
                Mật Khẩu
              </label>
              <div className="relative">
                <div className="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-emerald-600">
                  <Lock className="w-4 h-4" />
                </div>
                <input
                  type={showPassword ? 'text' : 'password'}
                  name="password"
                  value={formData.password}
                  onChange={handleChange}
                  placeholder="••••••••"
                  className="w-full pl-10 pr-11 py-3.5 bg-white border-2 border-emerald-200 hover:border-emerald-400 rounded-2xl text-sm font-semibold text-emerald-950 placeholder-emerald-800/35 focus:outline-none focus:border-emerald-500 focus:ring-4 focus:ring-emerald-500/10 transition-all shadow-2xs"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute inset-y-0 right-0 pr-3.5 flex items-center text-emerald-600/70 hover:text-emerald-800 cursor-pointer"
                >
                  {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                </button>
              </div>
            </div>

            {/* Remember Me Checkbox */}
            <div className="flex items-center justify-between pt-1">
              <label className="flex items-center gap-2 cursor-pointer group select-none">
                <input
                  type="checkbox"
                  name="remember"
                  checked={formData.remember}
                  onChange={handleChange}
                  className="w-4 h-4 rounded-md text-emerald-600 border-emerald-300 focus:ring-emerald-500 accent-emerald-600 cursor-pointer"
                />
                <span className="text-xs font-semibold text-emerald-900/75 group-hover:text-emerald-950">
                  Ghi nhớ đăng nhập
                </span>
              </label>
            </div>

            {/* Main Submit Button */}
            <button
              type="submit"
              disabled={loading}
              className="w-full py-4 px-6 bg-gradient-to-r from-emerald-500 via-green-600 to-teal-600 hover:from-emerald-600 hover:to-teal-700 text-white font-extrabold text-sm sm:text-base rounded-2xl shadow-lg shadow-emerald-500/25 hover:shadow-emerald-500/40 hover:scale-[1.01] active:scale-[0.99] transition-all duration-200 cursor-pointer flex items-center justify-center gap-2 disabled:opacity-50 mt-3"
            >
              {loading ? (
                <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin" />
              ) : (
                <span>Đăng Nhập Ngay</span>
              )}
            </button>

            {/* Divider */}
            <div className="relative flex items-center justify-center pt-2 pb-1">
              <div className="w-full border-t border-emerald-100"></div>
              <span className="absolute px-3 bg-white text-[11px] font-bold uppercase text-emerald-800/60 tracking-wider">
                hoặc
              </span>
            </div>

            {/* Google Login Button */}
            <button
              type="button"
              onClick={handleGoogleSignIn}
              disabled={loading}
              className="w-full py-3.5 px-6 bg-white hover:bg-emerald-50/60 text-emerald-950 font-bold text-sm rounded-2xl border-2 border-emerald-200 hover:border-emerald-400 shadow-xs hover:shadow-md active:scale-[0.99] transition-all duration-200 cursor-pointer flex items-center justify-center gap-3 group disabled:opacity-50"
            >
              <svg className="w-5 h-5 group-hover:scale-110 transition-transform flex-shrink-0" viewBox="0 0 24 24">
                <path
                  fill="#4285F4"
                  d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
                />
                <path
                  fill="#34A853"
                  d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
                />
                <path
                  fill="#FBBC05"
                  d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.63z"
                />
                <path
                  fill="#EA4335"
                  d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z"
                />
              </svg>
              <span>Đăng nhập bằng Google</span>
            </button>
          </form>
        </div>
      </motion.div>
    </div>
  );
};

export default Login;

