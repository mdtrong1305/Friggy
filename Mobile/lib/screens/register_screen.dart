import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/services/auth_service.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/social_button.dart';
import 'login_screen.dart';
import 'login_success_video_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isObscurePassword = true;
  bool _isObscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  int _calculatePasswordStrength(String password) {
    if (password.isEmpty) return 0;
    int score = 0;
    if (password.length >= 6) score++;
    if (password.contains(RegExp(r'[A-Z]')) || password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')) && password.length >= 8) score++;
    return score.clamp(1, 3);
  }

  String _getPasswordStrengthLabel(int score) {
    switch (score) {
      case 1:
        return 'Weak';
      case 2:
        return 'Fair';
      case 3:
        return 'Strong';
      default:
        return '';
    }
  }

  Color _getPasswordStrengthColor(int score) {
    switch (score) {
      case 1:
        return const Color(0xFFE53935);
      case 2:
        return const Color(0xFF19221C);
      case 3:
        return AppColors.primary;
      default:
        return const Color(0xFFE2E8E4);
    }
  }

  Widget _buildPasswordStrengthMeter() {
    String password = _passwordController.text;
    int strength = _calculatePasswordStrength(password);
    String label = _getPasswordStrengthLabel(strength);
    Color color = _getPasswordStrengthColor(strength);

    if (password.isEmpty) return SizedBox(height: 10.h);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 8.h),
        Row(
          children: List.generate(3, (index) {
            bool isFilled = index < strength;
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: index < 2 ? 6 : 0),
                decoration: BoxDecoration(
                  color: isFilled ? color : const Color(0xFFE2E8E4),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            );
          }),
        ),
        SizedBox(height: 6.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 10.h),
      ],
    );
  }

  void _navigateToLogin(BuildContext context) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: Offset(-1.0, 0.0), // Slide in from left to right
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: FadeTransition(
              opacity: curvedAnimation,
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _handleRegister() async {
    if (_formKey.currentState?.validate() ?? false) {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final fullName = _fullNameController.text.trim();
      setState(() => _isLoading = true);

      final success = await AuthService().registerEmailSendOtp(context, email);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (success) {
        _showOtpVerificationModal(email, password, fullName);
      }
    }
  }

  void _showOtpVerificationModal(String email, String password, String name) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final isEn = loc?.locale.languageCode == 'en';
    final otpController = TextEditingController();
    bool isVerifying = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF19271E) : Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFE2E8E4),
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                    SizedBox(height: 20.h),
                    Text(
                      isEn ? 'Enter OTP Code' : 'Nhập mã OTP',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      isEn
                          ? '6-digit verification OTP code was sent to $email'
                          : 'Mã OTP 6 chữ số đã được gửi đến $email',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: isDark ? const Color(0xFFD0D7D1) : const Color(0xFF6B786F),
                      ),
                    ),
                    SizedBox(height: 20.h),
                    CustomTextField(
                      controller: otpController,
                      hintText: isEn ? 'Enter 6-digit OTP (e.g. 123456)' : 'Nhập mã OTP 6 chữ số (VD: 123456)',
                      prefixIcon: Icons.security_rounded,
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 20.h),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isVerifying
                            ? null
                            : () async {
                                final otp = otpController.text.trim();
                                if (otp.length != 6) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(isEn ? 'OTP must be 6 digits' : 'Mã OTP phải đúng 6 chữ số'),
                                      backgroundColor: AppColors.error,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }

                                setModalState(() => isVerifying = true);

                                final success = await AuthService().verifyEmailOtpAndRegister(
                                  context,
                                  email: email,
                                  otpCode: otp,
                                  password: password,
                                  name: name.isNotEmpty ? name : null,
                                );

                                if (context.mounted) {
                                  setModalState(() => isVerifying = false);
                                  if (success) {
                                    Navigator.pop(context); // close modal
                                    Navigator.of(context).pushReplacement(
                                      PageRouteBuilder(
                                        transitionDuration: const Duration(milliseconds: 500),
                                        pageBuilder: (context, animation, secondaryAnimation) =>
                                            const LoginSuccessVideoScreen(),
                                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                          return FadeTransition(
                                            opacity: CurvedAnimation(
                                              parent: animation,
                                              curve: Curves.easeInOut,
                                            ),
                                            child: child,
                                          );
                                        },
                                      ),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24.r),
                          ),
                        ),
                        child: isVerifying
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                isEn ? 'Verify & Register' : 'Xác nhận & Đăng ký',
                                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                    SizedBox(height: 12.h),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final isEn = loc?.locale.languageCode == 'en';
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final topPadding = mediaQuery.padding.top;
    final topHeaderHeight = screenHeight * 0.27 + topPadding;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0E1611) : AppColors.accentGreen,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        top: false,
        bottom: false,
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. Top Curved Decorative Background
              Positioned(
                top: 0.h,
                left: 0.w,
                right: 0.w,
                height: topHeaderHeight + 60,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isDark
                          ? const [
                              Color(0xFF0E1611),
                              Color(0xFF142017),
                              Color(0xFF1B2E21),
                            ]
                          : const [
                              Color(0xFFFFFFFF),
                              Color(0xFFF5FCF4),
                              Color(0xFFC7EFC2),
                              Color(0xFF86D978),
                            ],
                      stops: isDark
                          ? const [0.0, 0.5, 1.0]
                          : const [0.0, 0.3, 0.7, 1.0],
                    ),
                  ),
                ),
              ),

              // 2. Mascot Header Image
              Positioned(
                top: topPadding + 52,
                right: 0.w,
                width: 193,
                height: topHeaderHeight - 60,
                child: Image.asset(
                  'assets/images/mascot_login.png',
                  fit: BoxFit.contain,
                ),
              ),

              // 3. Top-Left App Title "< Friggy"
              Positioned(
                top: topPadding + 12,
                left: 16.w,
                child: GestureDetector(
                  onTap: () => _navigateToLogin(context),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          size: 18,
                        ),
                        SizedBox(width: 4.w),
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 26.sp,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                            children: [
                              TextSpan(
                                text: 'Fri',
                                style: TextStyle(
                                  color: isDark ? Colors.white : AppColors.textPrimary,
                                ),
                              ),
                              TextSpan(
                                text: 'ggy',
                                style: TextStyle(
                                  color: isDark ? const Color(0xFF81C784) : AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 4. Bottom Card Container
              Container(
                margin: EdgeInsets.only(top: topHeaderHeight),
                width: double.infinity,
                constraints: BoxConstraints(
                  minHeight: screenHeight - topHeaderHeight + 100,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0E1611) : Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(36.r),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
                      blurRadius: 16,
                      offset: Offset(0, -6),
                    ),
                  ],
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 24,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        isEn ? 'Create Account' : 'Tạo tài khoản',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 30.sp,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 14.h),

                      // 1. Full Name Input Field
                      CustomTextField(
                        controller: _fullNameController,
                        hintText: isEn ? 'Full Name' : 'Họ và tên',
                        prefixIcon: Icons.person_outline_rounded,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return isEn ? 'Please enter your full name' : 'Vui lòng nhập họ và tên của bạn';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 10.h),

                      // 2. Email Address Input Field
                      CustomTextField(
                        controller: _emailController,
                        hintText: isEn ? 'Email address' : 'Địa chỉ email',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return isEn ? 'Please enter email address' : 'Vui lòng nhập địa chỉ email';
                          }
                          final input = value.trim();
                          final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                          if (!emailRegex.hasMatch(input)) {
                            return isEn ? 'Invalid email address' : 'Email không hợp lệ';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 10.h),

                      // 3. Password Input Field
                      CustomTextField(
                        controller: _passwordController,
                        hintText: isEn ? 'Password' : 'Mật khẩu',
                        prefixIcon: Icons.lock_outline_rounded,
                        obscureText: _isObscurePassword,
                        onChanged: (val) => setState(() {}),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isObscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: isDark ? const Color(0xFF9DA8A0) : AppColors.hintText,
                            size: 22,
                          ),
                          onPressed: () {
                            setState(() {
                              _isObscurePassword = !_isObscurePassword;
                            });
                          },
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return isEn ? 'Please enter password' : 'Vui lòng nhập mật khẩu';
                          }
                          if (value.length < 6) {
                            return isEn ? 'Password must be at least 6 characters' : 'Mật khẩu phải có ít nhất 6 ký tự';
                          }
                          return null;
                        },
                      ),

                      // 3-Segment Password Strength Indicator
                      _buildPasswordStrengthMeter(),

                      // 4. Confirm Password Input Field
                      CustomTextField(
                        controller: _confirmPasswordController,
                        hintText: isEn ? 'Confirm Password' : 'Xác nhận mật khẩu',
                        prefixIcon: Icons.lock_outline_rounded,
                        obscureText: _isObscureConfirmPassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isObscureConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: isDark ? const Color(0xFF9DA8A0) : AppColors.hintText,
                            size: 22,
                          ),
                          onPressed: () {
                            setState(() {
                              _isObscureConfirmPassword =
                                  !_isObscureConfirmPassword;
                            });
                          },
                        ),
                        validator: (value) {
                          if (value != _passwordController.text) {
                            return isEn ? 'Confirm password does not match' : 'Mật khẩu xác nhận không khớp';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 18.h),

                      // 6. Main Sign Up Button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shadowColor: AppColors.primary.withValues(alpha: 0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28.r),
                            ),
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Text(
                                  isEn ? 'Register' : 'Đăng ký',
                                  style: TextStyle(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(height: 14.h),

                      // 7. Social Login Divider ("Or Sign Up With")
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: isDark
                                  ? const Color(0xFF2E4D36)
                                  : const Color(0xFFE8ECE9),
                              thickness: 1,
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              isEn ? 'Or register with' : 'Hoặc đăng ký bằng',
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w500,
                                color: isDark ? const Color(0xFF9DA8A0) : AppColors.hintText,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: isDark
                                  ? const Color(0xFF2E4D36)
                                  : const Color(0xFFE8ECE9),
                              thickness: 1,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 14.h),

                      // 8. Social Button (Google Full Width)
                      Row(
                        children: [
                          SocialButton(
                            type: SocialType.google,
                            onPressed: () async {
                              final success = await AuthService().signInWithGoogle(context);
                              if (success && context.mounted) {
                                ScaffoldMessenger.of(context).clearSnackBars();
                                Navigator.of(context).pushReplacement(
                                  PageRouteBuilder(
                                    transitionDuration: const Duration(milliseconds: 500),
                                    pageBuilder: (context, animation, secondaryAnimation) =>
                                        const LoginSuccessVideoScreen(),
                                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                      return FadeTransition(
                                        opacity: CurvedAnimation(
                                          parent: animation,
                                          curve: Curves.easeInOut,
                                        ),
                                        child: child,
                                      );
                                    },
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 18.h),

                      // 9. Footer Link: "Already have an account? Log In"
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isEn ? 'Already have an account? ' : 'Bạn đã có tài khoản? ',
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: isDark ? const Color(0xFF9DA8A0) : const Color(0xFF6B786F),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _navigateToLogin(context),
                              child: Text(
                                isEn ? 'Log In' : 'Đăng nhập',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFF81C784) : AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20.h),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
