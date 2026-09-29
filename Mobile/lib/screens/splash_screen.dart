import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

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
              begin: Offset(1.0, 0.0),
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

  void _navigateToRegister(BuildContext context) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const RegisterScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: Offset(1.0, 0.0),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final isEn = loc?.locale.languageCode == 'en';
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;

    final topPadding = mediaQuery.padding.top;
    final bottomPadding = mediaQuery.padding.bottom;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0E1611) : Colors.white,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            // ================= 1. TOP & CENTER AREA (MASCOT & TITLE) =================
            Expanded(
              flex: 65,
              child: Container(
                width: double.infinity,
                color: isDark ? const Color(0xFF0E1611) : Colors.white,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Sparkle accents
                    Positioned(
                      top: 75.h,
                      left: 45.w,
                      child: Text(
                        '✦',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFC4EAD0),
                          fontSize: 22.sp,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 140.h,
                      right: 40.w,
                      child: Text(
                        '✦',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFC4EAD0),
                          fontSize: 20.sp,
                        ),
                      ),
                    ),

                    // App Title Header
                    Positioned(
                      top: topPadding + 24,
                      left: 0.w,
                      right: 0.w,
                      child: Column(
                        children: [
                          Text(
                            isEn ? 'Welcome to' : 'Chào mừng tới',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 30.sp,
                              fontWeight: FontWeight.w900,
                              color: isDark ? const Color(0xFF81C784) : const Color(0xFF159936),
                              letterSpacing: 0.5,
                              height: 1.0,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Padding(
                            padding: EdgeInsets.only(left: 35.0.w),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 62.sp,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 3.0,
                                      height: 1.0,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: 'Fri',
                                        style: TextStyle(
                                          color: isDark ? Colors.white : const Color(0xFF19221C),
                                        ),
                                      ),
                                      TextSpan(
                                        text: 'ggy',
                                        style: TextStyle(
                                          color: isDark ? const Color(0xFF81C784) : const Color(0xFF4CAF50),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 4.w),
                                Padding(
                                  padding: EdgeInsets.only(top: 6.0.h),
                                  child: Transform.rotate(
                                    angle: 0.35,
                                    child: Icon(
                                      Icons.eco_rounded,
                                      color: isDark ? const Color(0xFF81C784) : const Color(0xFF4CAF50),
                                      size: 32,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Centered 3D Fridge Mascot Image
                    Positioned(
                      bottom: 20.h,
                      left: 0.w,
                      right: 0.w,
                      child: SizedBox(
                        height: screenHeight * 0.40,
                        child: Image.asset(
                          'assets/images/onboarding_fridge.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Image.asset(
                              'assets/images/cute_mascot.png',
                              fit: BoxFit.contain,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ================= 2. BOTTOM ACTIONS & DESCRIPTION =================
            Expanded(
              flex: 35,
              child: Container(
                width: double.infinity,
                color: isDark ? const Color(0xFF0E1611) : Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Main Headline
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        isEn ? 'Smart Fridge Management' : 'Quản lý Tủ lạnh Thông minh',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 28.sp,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF008435),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),

                    // Subtitle description
                    Text(
                      isEn
                          ? 'Track food, discover recipes & reduce waste every day.'
                          : 'Theo dõi thực phẩm, gợi ý món ăn ngon và giảm lãng phí mỗi ngày.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFD0D7D1) : const Color(0xFF1E8435),
                        height: 1.4,
                      ),
                    ),

                    // Action Button "Get Started ➔"
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () => _navigateToLogin(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shadowColor: AppColors.primary.withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28.r),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isEn ? 'Get Started' : 'Bắt đầu ngay',
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 22,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Footer Link
                    GestureDetector(
                      onTap: () => _navigateToRegister(context),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isEn ? "Don't have an account? " : "Bạn chưa có tài khoản? ",
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: isDark ? const Color(0xFF9DA8A0) : const Color(0xFF1E8435),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            isEn ? 'Register' : 'Đăng ký',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFF81C784) : const Color(0xFF008435),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: bottomPadding > 0 ? bottomPadding : 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
