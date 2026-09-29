import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'splash_screen.dart';
import 'login_success_video_screen.dart';
import '../data/services/auth_service.dart';
import '../sqlite/services/background_sync_service.dart';

class InitialLoadingScreen extends StatefulWidget {
  const InitialLoadingScreen({super.key});

  @override
  State<InitialLoadingScreen> createState() => _InitialLoadingScreenState();
}

class _InitialLoadingScreenState extends State<InitialLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Staggered Sequential Animations
  late Animation<double> _imageScaleAnimation;
  late Animation<double> _imageFadeAnimation;
  late Animation<double> _titleFadeAnimation;
  late Animation<Offset> _titleSlideAnimation;
  late Animation<double> _progressFadeAnimation;
  late Animation<double> _progressValueAnimation;

  bool? _isAutoLoginValid;

  @override
  void initState() {
    super.initState();

    // Set transparent status bar
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );

    // Total animation timeline: 3.6 seconds for snappy progress
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );

    // Start background auto-login check (calls POST /api/v1/auth/refresh if refresh token exists)
    _startAutoLoginCheck();

    // ================= STEP 1: Wait 0.5s, then 3D Mascot Scales Up (0.5s - 1.5s) =================
    _imageFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.14, 0.38, curve: Curves.easeOut),
      ),
    );

    _imageScaleAnimation = Tween<double>(begin: 0.25, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.14, 0.41, curve: Curves.easeOutBack),
      ),
    );

    // ================= STEP 2: "Friggy" Text Slides Up from Below (1.6s - 2.4s) =================
    _titleFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.44, 0.65, curve: Curves.easeOut),
      ),
    );

    _titleSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.6),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.44, 0.65, curve: Curves.easeOutCubic),
      ),
    );

    // ================= STEP 3: Progress Bar Fades In & Fills Fast (0.75s fill duration) =================
    _progressFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.67, 0.74, curve: Curves.easeIn),
      ),
    );

    // Fast & smooth progress bar filling 0% -> 100% in ~0.75s
    _progressValueAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.68, 0.89, curve: Curves.easeInOutCubic),
      ),
    );

    _controller.forward();

    // Trigger smooth transition when progress animation is complete
    _controller.addStatusListener((status) async {
      if (status == AnimationStatus.completed) {
        // Wait up to 1.5s if token refresh check is still processing over slow network
        int retryCount = 0;
        while (_isAutoLoginValid == null && retryCount < 15) {
          await Future.delayed(const Duration(milliseconds: 100));
          retryCount++;
        }

        if (mounted) {
          if (_isAutoLoginValid == true) {
            _navigateToVideoLoadingScreen();
          } else {
            _navigateToSplashScreen();
          }
        }
      }
    });
  }

  Future<void> _startAutoLoginCheck() async {
    try {
      final isValid = await AuthService().checkAndRefreshToken();
      if (isValid) {
        // Bắt đầu sync SQLite ngay sau khi xác nhận token hợp lệ
        BackgroundSyncService().syncAll();
      }
      if (mounted) {
        setState(() {
          _isAutoLoginValid = isValid;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAutoLoginValid = false;
        });
      }
    }
  }

  void _navigateToVideoLoadingScreen() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 550),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginSuccessVideoScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  void _navigateToSplashScreen() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 550),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const SplashScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0E1611) : Colors.white,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final progressValue = _progressValueAnimation.value;
              final showImage = _controller.value >= 0.16;
              final showTitle = _controller.value >= 0.43;
              final showProgress = _controller.value >= 0.66;

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),

                  // ================= STEP 1: 3D Mascot Image (Scales Up from Small) =================
                  SizedBox(
                    width: 210,
                    height: 210,
                    child: showImage
                        ? FadeTransition(
                            opacity: _imageFadeAnimation,
                            child: ScaleTransition(
                              scale: _imageScaleAnimation,
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
                          )
                        : const SizedBox.shrink(),
                  ),

                  SizedBox(height: 18.h),

                  // ================= STEP 2: "Friggy" Text (Slides Up) =================
                  SizedBox(
                    height: 56,
                    child: showTitle
                        ? FadeTransition(
                            opacity: _titleFadeAnimation,
                            child: SlideTransition(
                              position: _titleSlideAnimation,
                              child: Padding(
                                padding: EdgeInsets.only(left: 35.0.w),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    RichText(
                                      text: TextSpan(
                                        style: GoogleFonts.quicksand(
                                          fontSize: 48.sp,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 2.5,
                                          height: 1.0,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: 'Fri',
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.white
                                                  : const Color(0xFF19221C),
                                            ),
                                          ),
                                          TextSpan(
                                            text: 'ggy',
                                            style: TextStyle(
                                              color: isDark
                                                  ? const Color(0xFF81C784)
                                                  : const Color(0xFF4CAF50),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 4.w),
                                    Padding(
                                      padding: EdgeInsets.only(top: 4.0.h),
                                      child: Transform.rotate(
                                        angle: 0.35,
                                        child: Icon(
                                          Icons.eco_rounded,
                                          color: isDark
                                              ? const Color(0xFF81C784)
                                              : const Color(0xFF4CAF50),
                                          size: 28,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  SizedBox(height: 32.h),

                  // ================= STEP 3 & 4: Progress Bar (Faster Fill 0% -> 100%) =================
                  SizedBox(
                    height: 44,
                    child: showProgress
                        ? FadeTransition(
                            opacity: _progressFadeAnimation,
                            child: Column(
                              children: [
                                Container(
                                  width: 170,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF233629)
                                        : const Color(0xFFE9F4DA),
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                  child: Stack(
                                    children: [
                                      FractionallySizedBox(
                                        widthFactor: progressValue,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF81C784)
                                                : const Color(0xFF4CAF50),
                                            borderRadius:
                                                BorderRadius.circular(10.r),
                                            boxShadow: [
                                              BoxShadow(
                                                color: (isDark
                                                        ? const Color(0xFF81C784)
                                                        : const Color(0xFF4CAF50))
                                                    .withValues(alpha: 0.35),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                Text(
                                  '${(progressValue * 100).toInt()}%',
                                  style: GoogleFonts.quicksand(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? const Color(0xFF81C784)
                                        : const Color(0xFF4CAF50),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  const Spacer(flex: 4),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
