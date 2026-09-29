import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/services/auth_service.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_text_field.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int _currentStep = 1; // 1: Phone, 2: OTP Verify, 3: Reset Password

  // Step 1 Controllers & State
  final TextEditingController _emailController = TextEditingController();

  // Step 2 Single Controller & FocusNode for 100% bulletproof soft keyboard popup
  final TextEditingController _otpSingleController = TextEditingController();
  final FocusNode _otpSingleFocusNode = FocusNode();
  int _resendTimerSeconds = 60;
  Timer? _resendTimer;
  bool _canResend = false;
  bool _isVerifyingOtp = false;

  // Step 1 Controllers & State
  final _step1FormKey = GlobalKey<FormState>();

  // Step 3 Controllers & State
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final _step3FormKey = GlobalKey<FormState>();
  bool _isObscureNewPassword = true;
  bool _isObscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _otpSingleController.dispose();
    _otpSingleFocusNode.dispose();
    _resendTimer?.cancel();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _resendTimerSeconds = 60;
      _canResend = false;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimerSeconds > 1) {
        setState(() {
          _resendTimerSeconds--;
        });
      } else {
        setState(() {
          _canResend = true;
        });
        timer.cancel();
      }
    });
  }

  void _goToStep2() async {
    if (!(_step1FormKey.currentState?.validate() ?? false)) {
      return;
    }

    final email = _emailController.text.trim();
    setState(() => _isVerifyingOtp = true);

    final success = await AuthService().sendForgotPasswordOtp(context, email);

    if (!mounted) return;
    setState(() => _isVerifyingOtp = false);

    if (success) {
      setState(() {
        _currentStep = 2;
      });
      _startResendTimer();

      void requestOtpFocus() {
        if (mounted && _currentStep == 2) {
          _otpSingleFocusNode.requestFocus();
        }
      }

      WidgetsBinding.instance.addPostFrameCallback((_) => requestOtpFocus());
    }
  }

  void _checkAndVerifyOtp(String otp) {
    if (otp.length == 6 && !_isVerifyingOtp) {
      setState(() {
        _currentStep = 3;
      });
    }
  }

  void _finishResetPassword() async {
    if (_step3FormKey.currentState?.validate() ?? false) {
      final email = _emailController.text.trim();
      final otp = _otpSingleController.text.trim();
      final newPassword = _newPasswordController.text;

      setState(() => _isVerifyingOtp = true);

      final success = await AuthService().resetPasswordWithOtp(
        context,
        email: email,
        otpCode: otp,
        newPassword: newPassword,
      );

      if (!mounted) return;
      setState(() => _isVerifyingOtp = false);

      if (success) {
        _showWelcomeSuccessScreen();
      }
    }
  }

  void _showWelcomeSuccessScreen() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final isEn = loc?.locale.languageCode == 'en';

    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (context, animation, secondaryAnimation) {
          return Scaffold(
            backgroundColor: isDark ? const Color(0xFF0E1611) : Colors.white,
            appBar: AppBar(
              backgroundColor: isDark ? const Color(0xFF0E1611) : Colors.white,
              elevation: 0,
              automaticallyImplyLeading: false,
              titleSpacing: 24,
              centerTitle: false,
              title: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 22.sp,
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
            ),
            body: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const Spacer(),

                    // Animated Particle Sparkle Burst Checkmark (Matching reference video recording)
                    const _SparkleBurstCheckmark(),
                    SizedBox(height: 24.h),

                    // Title "Welcome to Friggy." (Matching reference image #2)
                    Text(
                      isEn ? 'Welcome to Friggy.' : 'Chào mừng đến với Friggy.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 12.h),

                    // Subtitle
                    Text(
                      isEn
                          ? 'Your account is ready.\nStart experiencing now.'
                          : 'Tài khoản của bạn đã sẵn sàng.\nHãy bắt đầu trải nghiệm ngay.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15.sp,
                        color: isDark ? const Color(0xFFD0D7D1) : const Color(0xFF7A867E),
                        height: 1.5,
                      ),
                    ),

                    const Spacer(),

                    // Bottom Pinned "Get started" Button (Matching reference image #2)
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            PageRouteBuilder(
                              transitionDuration: const Duration(milliseconds: 400),
                              pageBuilder: (context, animation, secondaryAnimation) =>
                                  const LoginScreen(),
                              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                            ),
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? const Color(0xFF81C784) : const Color(0xFF1E211F),
                          foregroundColor: isDark ? const Color(0xFF0E1611) : Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                        ),
                        child: Text(
                          isEn ? 'Get Started' : 'Bắt đầu ngay',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFF0E1611) : Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 24.h),
                  ],
                ),
              ),
            ),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0E1611) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0E1611) : Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 24, // Flush to the left matching screenshot
        centerTitle: false,
        title: RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 22.sp,
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
        actions: [
          // Back arrow on the right side ONLY for Step 2 (OTP) to return to Step 1
          if (_currentStep == 2)
            IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: isDark ? Colors.white : AppColors.textPrimary,
                size: 18,
              ),
              onPressed: () {
                setState(() {
                  _currentStep = 1;
                });
              },
            ),
          SizedBox(width: 12.w),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 12.h),
            // 1. Top Step Progress Bar Indicator
            _buildProgressBar(),

            SizedBox(height: 24.h),

            // 2. Main Content Body per Step
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: _buildCurrentStepContent(),
              ),
            ),

            // 3. Bottom Action Buttons / Keypad (Pinned to bottom of screen)
            if (_currentStep == 1) _buildStep1BottomButton(),
            if (_currentStep == 2) _buildStep2BottomSection(),
            if (_currentStep == 3) _buildStep3BottomButton(),
          ],
        ),
      ),
    );
  }

  // --- Step Progress Bar Widget ---
  Widget _buildProgressBar() {
    final loc = AppLocalizations.of(context);
    final isEn = loc?.locale.languageCode == 'en';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          _buildStepCircle(step: 1, label: isEn ? 'PHONE' : 'SỐ ĐT'),
          _buildLine(isCompleted: _currentStep > 1),
          _buildStepCircle(step: 2, label: isEn ? 'VERIFY' : 'XÁC THỰC'),
          _buildLine(isCompleted: _currentStep > 2),
          _buildStepCircle(step: 3, label: isEn ? 'PASSWORD' : 'MẬT KHẨU'),
        ],
      ),
    );
  }

  Widget _buildStepCircle({required int step, required String label}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool isCompleted = _currentStep > step;
    bool isActive = _currentStep == step;

    Color bg;
    Color iconColor;

    if (isCompleted || isActive) {
      bg = isDark ? const Color(0xFF81C784) : Colors.black;
      iconColor = isDark ? const Color(0xFF0E1611) : Colors.white;
    } else {
      bg = isDark ? const Color(0xFF233629) : const Color(0xFFE2E8E4);
      iconColor = isDark ? const Color(0xFF5E6E63) : const Color(0xFF9EA8A1);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bg,
          ),
          child: Center(
            child: Icon(
              Icons.check_rounded,
              size: 16,
              color: iconColor,
            ),
          ),
        ),
        SizedBox(height: 6.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.sp,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: isActive || isCompleted
                ? (isDark ? Colors.white : Colors.black)
                : (isDark ? const Color(0xFF9DA8A0) : const Color(0xFF9EA8A1)),
          ),
        ),
      ],
    );
  }

  Widget _buildLine({required bool isCompleted}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        height: 2,
        margin: EdgeInsets.only(bottom: 18.h, left: 4.w, right: 4.w),
        color: isCompleted
            ? (isDark ? const Color(0xFF81C784) : Colors.black)
            : (isDark ? const Color(0xFF233629) : const Color(0xFFE2E8E4)),
      ),
    );
  }

  // --- Dynamic Content Body for Current Step ---
  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 1:
        return _buildStep1PhoneEmail();
      case 2:
        return _buildStep2Otp();
      case 3:
        return _buildStep3ResetPassword();
      default:
        return Container();
    }
  }

  // STEP 1: Email Address
  Widget _buildStep1PhoneEmail() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final isEn = loc?.locale.languageCode == 'en';

    return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEn ? 'Enter your email.' : 'Nhập email của bạn.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28.sp,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            isEn
                ? "We will send a 6-digit verification code to your email."
                : "Chúng tôi sẽ gửi mã xác thực 6 chữ số tới email của bạn.",
            style: TextStyle(
              fontSize: 14.sp,
              color: isDark ? const Color(0xFFD0D7D1) : const Color(0xFF7A867E),
              height: 1.4,
            ),
          ),
          SizedBox(height: 24.h),

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

          SizedBox(height: 12.h),

          // Security privacy note
          Row(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 14,
                color: isDark ? const Color(0xFF9DA8A0) : const Color(0xFF9EA8A1),
              ),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  isEn
                      ? 'Your information is strictly protected.'
                      : 'Thông tin của bạn được bảo mật tuyệt đối.',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: isDark ? const Color(0xFF9DA8A0) : const Color(0xFF9EA8A1),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // STEP 2: OTP Verification UI (6 OTP digit boxes)
  Widget _buildStep2Otp() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final isEn = loc?.locale.languageCode == 'en';

    String destination = _emailController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          isEn ? 'Enter 6-digit code.' : 'Nhập mã xác thực 6 chữ số.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 28.sp,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 8.h),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(
              fontSize: 14.sp,
              color: isDark ? const Color(0xFFD0D7D1) : const Color(0xFF7A867E),
              height: 1.4,
            ),
            children: [
              TextSpan(
                text: isEn ? "Verification code sent to email\n" : "Mã xác thực đã được gửi tới email\n",
              ),
              TextSpan(
                text: destination,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFF81C784) : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 28.h),

        // 6 Visual OTP digit boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (index) {
            String text = "";
            if (index < _otpSingleController.text.length) {
              text = _otpSingleController.text[index];
            }

            bool isFocused = (index == _otpSingleController.text.length) ||
                (index == 5 && _otpSingleController.text.length == 6);

            return Container(
              width: 44,
              height: 56,
              margin: EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF19271E) : Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: isFocused
                      ? (isDark ? const Color(0xFF81C784) : Colors.black)
                      : (isDark ? const Color(0xFF2E4D36) : const Color(0xFFD4DDD6)),
                  width: isFocused ? 2.0 : 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            );
          }),
        ),

        SizedBox(height: 20.h),

        // Resend Timer
        Center(
          child: _canResend
              ? TextButton(
                  onPressed: () async {
                    _startResendTimer();
                    await AuthService().sendForgotPasswordOtp(context, _emailController.text.trim());
                  },
                  child: Text(
                    isEn ? 'Resend code' : 'Gửi lại mã',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFF81C784) : Colors.black,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                )
              : RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: isDark ? const Color(0xFFD0D7D1) : const Color(0xFF7A867E),
                    ),
                    children: [
                      TextSpan(text: isEn ? "Didn't receive code? " : "Bạn chưa nhận được mã? "),
                      TextSpan(
                        text: isEn ? "Resend ( ${_resendTimerSeconds}s )" : "Gửi lại ( ${_resendTimerSeconds}s )",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFF81C784) : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
        ),

      ],
    );
  }

  // --- Step 2 Pinned Bottom Section (Next Button & Numeric Keypad) ---
  Widget _buildStep2BottomSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final isEn = loc?.locale.languageCode == 'en';
    final isFilled = _otpSingleController.text.length == 6;

    return Container(
      padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 12.h, bottom: 8.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0E1611) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFF0F4F1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Full-width Next Button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                if (_otpSingleController.text.length == 6) {
                  _checkAndVerifyOtp(_otpSingleController.text);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isFilled
                    ? (isDark ? const Color(0xFF81C784) : const Color(0xFF1E211F))
                    : (isDark ? const Color(0xFF233629) : const Color(0xFFD4DDD6)),
                foregroundColor: isFilled
                    ? (isDark ? const Color(0xFF0E1611) : Colors.white)
                    : (isDark ? const Color(0xFF5E6E63) : Colors.white),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
              child: Text(
                isEn ? 'Next' : 'Tiếp theo',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: isFilled
                      ? (isDark ? const Color(0xFF0E1611) : Colors.white)
                      : (isDark ? const Color(0xFF5E6E63) : Colors.white),
                ),
              ),
            ),
          ),

          SizedBox(height: 6.h),

          // Built-in On-Screen Custom Numeric Keypad (Pinned to very bottom!)
          _buildNumericKeypad(),
        ],
      ),
    );
  }

  // --- Built-in Custom On-Screen Numeric Keypad (Always Visible!) ---
  Widget _buildNumericKeypad() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'backspace'],
    ];

    final subLabels = {
      '2': 'ABC',
      '3': 'DEF',
      '4': 'GHI',
      '5': 'JKL',
      '6': 'MNO',
      '7': 'PQRS',
      '8': 'TUV',
      '9': 'WXYZ',
    };

    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: keys.map((row) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row.map((key) {
                if (key.isEmpty) {
                  return const SizedBox(width: 85, height: 48);
                }

                return SizedBox(
                  width: 85,
                  height: 48,
                  child: InkWell(
                    onTap: () {
                      if (key == 'backspace') {
                        if (_otpSingleController.text.isNotEmpty) {
                          setState(() {
                            _otpSingleController.text = _otpSingleController.text
                                .substring(0, _otpSingleController.text.length - 1);
                          });
                        }
                      } else {
                        if (_otpSingleController.text.length < 6) {
                          setState(() {
                            _otpSingleController.text += key;
                          });
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(12.r),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (key == 'backspace')
                          Icon(
                            Icons.backspace_outlined,
                            size: 22,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          )
                        else ...[
                          Text(
                            key,
                            style: TextStyle(
                              fontSize: 22.sp,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                          if (subLabels.containsKey(key))
                            Text(
                              subLabels[key]!,
                              style: TextStyle(
                                fontSize: 9.sp,
                                fontWeight: FontWeight.bold,
                                color: isDark ? const Color(0xFF9DA8A0) : const Color(0xFF9EA8A1),
                                letterSpacing: 0.5,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  // STEP 3: Create your password
  Widget _buildStep3ResetPassword() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final isEn = loc?.locale.languageCode == 'en';

    return Form(
      key: _step3FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEn ? 'Create your password.' : 'Tạo mật khẩu của bạn.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28.sp,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            isEn
                ? 'At least 6 characters. Combine letters,\nnumbers and symbols for better security.'
                : 'Tối thiểu 6 ký tự. Kết hợp chữ cái,\nchữ số và ký hiệu để tăng độ bảo mật.',
            style: TextStyle(
              fontSize: 14.sp,
              color: isDark ? const Color(0xFFD0D7D1) : const Color(0xFF9EA8A1),
              height: 1.4,
            ),
          ),
          SizedBox(height: 24.h),

          Text(
            isEn ? 'Password' : 'Mật khẩu',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8.h),

          // New Password Input Field
          CustomTextField(
            controller: _newPasswordController,
            hintText: '••••••••',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: _isObscureNewPassword,
            onChanged: (val) => setState(() {}),
            suffixIcon: IconButton(
              icon: Icon(
                _isObscureNewPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: isDark ? const Color(0xFF9DA8A0) : AppColors.hintText,
                size: 22,
              ),
              onPressed: () {
                setState(() {
                  _isObscureNewPassword = !_isObscureNewPassword;
                });
              },
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return isEn ? 'Please enter new password' : 'Vui lòng nhập mật khẩu mới';
              }
              if (value.length < 6) {
                return isEn ? 'Password must be at least 6 characters' : 'Mật khẩu phải có ít nhất 6 ký tự';
              }
              return null;
            },
          ),
          
          // 3-Segment Password Strength Indicator (Matching reference screenshot)
          _buildPasswordStrengthMeter(),

          SizedBox(height: 16.h),

          Text(
            isEn ? 'Confirm Password' : 'Nhập lại Mật khẩu',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8.h),

          // Confirm Password Input Field
          CustomTextField(
            controller: _confirmPasswordController,
            hintText: '••••••••',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: _isObscureConfirmPassword,
            onChanged: (val) => setState(() {}),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_confirmPasswordController.text.isNotEmpty &&
                    _confirmPasswordController.text ==
                        _newPasswordController.text) ...[
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF81C784) : Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: isDark ? const Color(0xFF0E1611) : Colors.white,
                      size: 14,
                    ),
                  ),
                  SizedBox(width: 4.w),
                ],
                IconButton(
                  icon: Icon(
                    _isObscureConfirmPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: isDark ? const Color(0xFF9DA8A0) : AppColors.hintText,
                    size: 22,
                  ),
                  onPressed: () {
                    setState(() {
                      _isObscureConfirmPassword = !_isObscureConfirmPassword;
                    });
                  },
                ),
              ],
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return isEn ? 'Please confirm password' : 'Vui lòng xác nhận mật khẩu';
              }
              if (value != _newPasswordController.text) {
                return isEn ? 'Confirm password does not match' : 'Mật khẩu xác nhận không khớp';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  // --- 3-Segment Password Strength Meter (Matching Screenshot) ---
  int _calculatePasswordStrength(String password) {
    if (password.isEmpty) return 0;
    int score = 0;
    if (password.length >= 6) score++;
    if (password.contains(RegExp(r'[A-Z]')) || password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')) && password.length >= 8) score++;
    return score.clamp(1, 3);
  }

  String _getPasswordStrengthLabel(int score) {
    final loc = AppLocalizations.of(context);
    final isEn = loc?.locale.languageCode == 'en';

    switch (score) {
      case 1:
        return isEn ? 'Weak' : 'Yếu';
      case 2:
        return isEn ? 'Fair' : 'Trung bình';
      case 3:
        return isEn ? 'Strong' : 'Mạnh';
      default:
        return '';
    }
  }

  Color _getPasswordStrengthColor(int score) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (score) {
      case 1:
        return const Color(0xFFE53935); // Red
      case 2:
        return isDark ? const Color(0xFFFFB74D) : const Color(0xFF19221C); // Amber/Orange in dark mode
      case 3:
        return isDark ? const Color(0xFF81C784) : AppColors.primary; // Green for Strong
      default:
        return isDark ? const Color(0xFF233629) : const Color(0xFFE2E8E4);
    }
  }

  Widget _buildPasswordStrengthMeter() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String password = _newPasswordController.text;
    int strength = _calculatePasswordStrength(password);
    String label = _getPasswordStrengthLabel(strength);
    Color color = _getPasswordStrengthColor(strength);

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
                  color: isFilled
                      ? color
                      : (isDark ? const Color(0xFF233629) : const Color(0xFFE2E8E4)),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            );
          }),
        ),
        SizedBox(height: 6.h),
        if (password.isNotEmpty)
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
      ],
    );
  }

  // --- Step 1 Bottom Buttons (Back & Next) ---
  Widget _buildStep1BottomButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final isEn = loc?.locale.languageCode == 'en';

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0E1611) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFF0F4F1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : AppColors.textPrimary,
                  side: BorderSide(
                    color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFE2E8E4),
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
                child: Text(
                  isEn ? 'Back' : 'Quay lại',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _goToStep2,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF81C784) : const Color(0xFF1E211F),
                  foregroundColor: isDark ? const Color(0xFF0E1611) : Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
                child: Text(
                  isEn ? 'Next' : 'Tiếp theo',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFF0E1611) : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Step 3 Single Bottom Button ("Create Password") ---
  Widget _buildStep3BottomButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final isEn = loc?.locale.languageCode == 'en';

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0E1611) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFF0F4F1),
            width: 1,
          ),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _finishResetPassword,
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? const Color(0xFF81C784) : const Color(0xFF1E211F),
            foregroundColor: isDark ? const Color(0xFF0E1611) : Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
          ),
          child: Text(
            isEn ? 'Create Password' : 'Tạo mật khẩu',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFF0E1611) : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _SparkleBurstCheckmark extends StatefulWidget {
  const _SparkleBurstCheckmark();

  @override
  State<_SparkleBurstCheckmark> createState() => _SparkleBurstCheckmarkState();
}

class _SparkleBurstCheckmarkState extends State<_SparkleBurstCheckmark>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _burstAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    _scaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, 0.55, curve: Curves.easeOutBack),
      ),
    );

    _burstAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.15, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: 180,
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Radiating particle sparkles matching reference screen recording
              ...List.generate(14, (index) {
                final angle = (index * (360 / 14)) * (math.pi / 180);
                const maxRadius = 60.0;
                final currentRadius = 38.0 + (_burstAnimation.value * maxRadius);
                final dx = currentRadius * math.cos(angle);
                final dy = currentRadius * math.sin(angle);
                final dotSize = index % 2 == 0 ? 5.0 : 3.5;

                return Transform.translate(
                  offset: Offset(dx, dy),
                  child: Opacity(
                    opacity: _opacityAnimation.value,
                    child: Container(
                      width: dotSize,
                      height: dotSize,
                      decoration: BoxDecoration(
                        color: Color(0xFF6B786F),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),

              // Center Black Checkmark Circle
              Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: Color(0xFF1E211F),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 42,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
