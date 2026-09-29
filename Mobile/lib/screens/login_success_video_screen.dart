import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'home_screen.dart';
import 'onboarding_survey_screen.dart';
import '../data/models/user_models.dart';
import '../data/services/api_service.dart';
import '../data/services/auth_service.dart';
import '../utils/navigation_service.dart';

class LoginSuccessVideoScreen extends StatefulWidget {
  const LoginSuccessVideoScreen({super.key});

  @override
  State<LoginSuccessVideoScreen> createState() =>
      _LoginSuccessVideoScreenState();
}

class _LoginSuccessVideoScreenState extends State<LoginSuccessVideoScreen>
    with TickerProviderStateMixin {
  late VideoPlayerController _controller;
  late AnimationController _textAnimController;
  late Animation<double> _textFadeAnim;
  late Animation<Offset> _textSlideAnim;

  // Fast Hide-Down Exit Controller (220ms)
  late AnimationController _hideDownController;
  late Animation<double> _hideDownFadeAnim;
  late Animation<Offset> _hideDownSlideAnim;

  bool _isInitialized = false;
  bool _hasNavigated = false;
  bool _isHidingDown = false;
  Timer? _safetyTimer;

  @override
  void initState() {
    super.initState();

    // Hide any lingering SnackBars from previous screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }
    });

    // Set transparent status bar & dark icons
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );

    // Text Overlay Animation (Fade & Slide down smoothly)
    _textAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _textFadeAnim = CurvedAnimation(
      parent: _textAnimController,
      curve: Curves.easeOut,
    );

    _textSlideAnim = Tween<Offset>(
      begin: const Offset(0.0, -0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _textAnimController,
        curve: Curves.easeOutCubic,
      ),
    );

    // Fast Hide-Down Exit Animation (220ms)
    _hideDownController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    _hideDownFadeAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _hideDownController,
        curve: Curves.easeInCubic,
      ),
    );

    _hideDownSlideAnim = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.0, 0.25),
    ).animate(
      CurvedAnimation(
        parent: _hideDownController,
        curve: Curves.easeInCubic,
      ),
    );

    _hideDownController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateToHome();
      }
    });

    _initializeAndPlayVideo();
  }

  Future<void> _initializeAndPlayVideo() async {
    _controller = VideoPlayerController.asset('assets/videos/loading_login.mp4');

    try {
      await _controller.initialize();
      if (!mounted) return;

      setState(() {
        _isInitialized = true;
      });

      _controller.setLooping(false);
      _controller.setVolume(1.0);
      await _controller.play();
      _textAnimController.forward();

      _controller.addListener(_onVideoStateChanged);

      // Safety fallback timer matching max video length (~6s)
      final videoDuration = _controller.value.duration;
      final fallbackDelay = videoDuration > Duration.zero
          ? videoDuration + const Duration(milliseconds: 100)
          : const Duration(seconds: 4);

      _safetyTimer = Timer(fallbackDelay, () {
        _triggerHideDown();
      });
    } catch (e) {
      debugPrint('Error playing login video: $e');
      _safetyTimer = Timer(const Duration(seconds: 1), () {
        _triggerHideDown();
      });
    }
  }

  void _onVideoStateChanged() {
    if (!mounted || _hasNavigated || _isHidingDown) return;

    final value = _controller.value;
    if (value.isInitialized && value.duration > Duration.zero) {
      final remainingMs = value.duration.inMilliseconds - value.position.inMilliseconds;
      // Start fast hide-down animation near the video end
      if (remainingMs <= 220 || value.position >= value.duration) {
        _triggerHideDown();
      }
    }
  }

  void _triggerHideDown() {
    if (_isHidingDown || _hasNavigated) return;
    _isHidingDown = true;
    _safetyTimer?.cancel();
    _hideDownController.forward();
  }

  Future<void> _navigateToHome() async {
    if (_hasNavigated) return;
    _hasNavigated = true;

    _controller.removeListener(_onVideoStateChanged);

    if (!mounted) return;

    Widget targetScreen = const HomeScreen();
    try {
      final meJson = await ApiService().getMe();
      final me = MeModel.fromJson(meJson);

      if (!AuthService.isAllowedRole(me.role)) {
        debugPrint('[LoginSuccessVideoScreen] User role "${me.role}" is not authorized for mobile app access.');
        await NavigationService.navigateToLoginAndClearSession();
        return;
      }

      if (!me.isOnboardingCompleted) {
        targetScreen = const OnboardingSurveyScreen();
      }
    } catch (e) {
      debugPrint('[LoginSuccessVideoScreen] Error checking onboarding status: $e');
    }

    if (!mounted) return;

    // Fast 180ms transition right into target screen after hiding down
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          return FadeTransition(
            opacity: curve,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.04),
                end: Offset.zero,
              ).animate(curve),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _safetyTimer?.cancel();
    _controller.removeListener(_onVideoStateChanged);
    _controller.dispose();
    _textAnimController.dispose();
    _hideDownController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;

    final bgColor = isDark ? const Color(0xFF0E1611) : const Color(0xFFE8F5E9);

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: bgColor,
      body: SizedBox.expand(
        child: SafeArea(
          top: false,
          bottom: false,
          child: FadeTransition(
            opacity: _hideDownFadeAnim,
            child: SlideTransition(
              position: _hideDownSlideAnim,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Fullscreen Video Player
                  if (_isInitialized)
                    FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller.value.size.width,
                        height: _controller.value.size.height,
                        child: VideoPlayer(_controller),
                      ),
                    ),

                  // 2. Clean "Friggy" Text & Eco Leaf (Floating gracefully)
                  Positioned(
                    top: topPadding + 16,
                    left: 0.w,
                    right: 0.w,
                    child: FadeTransition(
                      opacity: _textFadeAnim,
                      child: SlideTransition(
                        position: _textSlideAnim,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            RichText(
                              text: TextSpan(
                                style: GoogleFonts.quicksand(
                                  fontSize: 42.sp,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.0,
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
                            Transform.rotate(
                              angle: 0.35,
                              child: Icon(
                                Icons.eco_rounded,
                                color: isDark ? const Color(0xFF81C784) : const Color(0xFF4CAF50),
                                size: 30,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
