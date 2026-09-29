import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/services/auth_service.dart';
import '../l10n/app_localizations.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  int _calculatePasswordStrength(String password) {
    if (password.isEmpty) return 0;
    int score = 0;

    final hasMinLength = password.length >= 8;
    final hasLetterOrDigit = password.contains(RegExp(r'[A-Za-z0-9]'));
    final hasSpecialChar =
        password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')) ||
            password.contains(RegExp(r'[A-Z]'));

    if (hasMinLength) score++;
    if (hasLetterOrDigit) score++;
    if (hasSpecialChar) score++;

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
        return const Color(0xFF4CAF50);
      default:
        return const Color(0xFFE2E8E4);
    }
  }

  Widget _buildPasswordStrengthMeter() {
    final password = _newPasswordController.text;
    if (password.isEmpty) return const SizedBox.shrink();

    final strength = _calculatePasswordStrength(password);
    final label = _getPasswordStrengthLabel(strength);
    final color = _getPasswordStrengthColor(strength);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 10.h),
        Row(
          children: List.generate(3, (index) {
            final isFilled = index < strength;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 5,
                margin: EdgeInsets.only(right: index < 2 ? 6 : 0),
                decoration: BoxDecoration(
                  color: isFilled ? color : const Color(0xFFE2E8E4),
                  borderRadius: BorderRadius.circular(3.r),
                ),
              ),
            );
          }),
        ),
        SizedBox(height: 6.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Độ mạnh mật khẩu:',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF757575),
              ),
            ),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRuleItem(String text, bool isSatisfied) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.0.h),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: EdgeInsets.all(2.w),
            decoration: BoxDecoration(
              color: isSatisfied
                  ? const Color(0xFF008435)
                  : const Color(0xFFE0E0E0),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSatisfied ? Icons.check_rounded : Icons.close_rounded,
              size: 12,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5.sp,
                fontWeight: isSatisfied ? FontWeight.w700 : FontWeight.w500,
                color: isSatisfied
                    ? const Color(0xFF006428)
                    : const Color(0xFF757575),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updatePassword() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    final success = await AuthService().changePassword(
      context,
      currentPassword: _oldPasswordController.text,
      newPassword: _newPasswordController.text,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      if (success) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final isEn = loc?.locale.languageCode == 'en';
    final newPassword = _newPasswordController.text;
    final hasMinLength = newPassword.length >= 8;
    final hasLetterOrDigit = newPassword.contains(RegExp(r'[A-Z0-9a-z]'));
    final hasSpecialChar =
        newPassword.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')) ||
            newPassword.contains(RegExp(r'[A-Z]'));

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
            stops: isDark ? const [0.0, 0.5, 1.0] : const [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar Header
              Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: 16.0.w, vertical: 8.0.h),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF19271E) : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFA5E69C),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: isDark ? Colors.white : const Color(0xFF006428),
                          size: 22,
                        ),
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Text(
                      isEn ? 'Change Password' : 'Đổi mật khẩu',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF006428),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 16.0,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        SizedBox(height: 4.h),

                        // Shield Security Header Icon
                        Center(
                          child: Container(
                            padding: EdgeInsets.all(18.w),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF233629) : const Color(0xFFE8F5E9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.lock_reset_rounded,
                              size: 52,
                              color: isDark ? const Color(0xFF81C784) : const Color(0xFF4CAF50),
                            ),
                          ),
                        ),

                        SizedBox(height: 18.h),

                        // Form Container with Validation & Strength Meter
                        Container(
                          padding: EdgeInsets.all(20.w),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF19271E) : Colors.white,
                            borderRadius: BorderRadius.circular(24.r),
                            border: Border.all(
                              color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFA5E69C),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Mật khẩu hiện tại
                              _buildValidatedPasswordField(
                                label: isEn ? 'Current Password' : 'Mật khẩu hiện tại',
                                controller: _oldPasswordController,
                                obscureText: _obscureOld,
                                onToggleObscure: () {
                                  setState(() {
                                    _obscureOld = !_obscureOld;
                                  });
                                },
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return isEn ? 'Please enter current password' : 'Vui lòng nhập mật khẩu hiện tại';
                                  }
                                  return null;
                                },
                              ),

                              SizedBox(height: 16.h),

                              // Mật khẩu mới
                              _buildValidatedPasswordField(
                                label: isEn ? 'New Password' : 'Mật khẩu mới',
                                controller: _newPasswordController,
                                obscureText: _obscureNew,
                                onToggleObscure: () {
                                  setState(() {
                                    _obscureNew = !_obscureNew;
                                  });
                                },
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return isEn ? 'Please enter new password' : 'Vui lòng nhập mật khẩu mới';
                                  }
                                  if (val.length < 8) {
                                    return isEn ? 'New password must be at least 8 characters' : 'Mật khẩu mới phải có ít nhất 8 ký tự';
                                  }
                                  return null;
                                },
                              ),

                              // Live Strength Progress Meter (Like Register Screen)
                              _buildPasswordStrengthMeter(),

                              SizedBox(height: 16.h),

                              // Xác nhận mật khẩu mới
                              _buildValidatedPasswordField(
                                label: isEn ? 'Confirm New Password' : 'Xác nhận mật khẩu mới',
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirm,
                                onToggleObscure: () {
                                  setState(() {
                                    _obscureConfirm = !_obscureConfirm;
                                  });
                                },
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return isEn ? 'Please confirm new password' : 'Vui lòng xác nhận mật khẩu mới';
                                  }
                                  if (val != _newPasswordController.text) {
                                    return isEn ? 'Confirm password does not match' : 'Mật khẩu xác nhận không khớp';
                                  }
                                  return null;
                                },
                              ),

                              SizedBox(height: 16.h),

                              // Requirements Checklist (Like Register Screen)
                              Container(
                                padding: EdgeInsets.all(12.w),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF233629) : const Color(0xFFF5FCF4),
                                  borderRadius: BorderRadius.circular(16.r),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFA5D6A7),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isEn ? 'Password requirements:' : 'Yêu cầu mật khẩu:',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? const Color(0xFF81C784) : const Color(0xFF006428),
                                      ),
                                    ),
                                    SizedBox(height: 8.h),
                                    _buildRuleItem(
                                      isEn ? '8 characters or more' : 'Từ 8 ký tự trở lên',
                                      hasMinLength,
                                    ),
                                    _buildRuleItem(
                                      isEn ? 'Contains letters or numbers' : 'Chứa chữ cái hoặc chữ số',
                                      hasLetterOrDigit,
                                    ),
                                    _buildRuleItem(
                                      isEn ? 'Uppercase or special char (!@#\$)' : 'Chứa chữ in hoa hoặc ký tự đặc biệt (!@#\$)',
                                      hasSpecialChar,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 28.h),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _updatePassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? const Color(0xFF81C784) : const Color(0xFF4CAF50),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28.r),
                              ),
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    isEn ? 'Update Password' : 'Cập nhật mật khẩu',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w900,
                                      color: isDark ? const Color(0xFF0E1611) : Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        SizedBox(height: 20.h),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildValidatedPasswordField({
    required String label,
    required TextEditingController controller,
    required bool obscureText,
    required VoidCallback onToggleObscure,
    required String? Function(String?) validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14.sp,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF006428),
          ),
        ),
        SizedBox(height: 6.h),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          validator: validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14.5.sp,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF19221C),
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(
              Icons.key_rounded,
              color: isDark ? const Color(0xFF81C784) : const Color(0xFF4CAF50),
              size: 20,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscureText
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: isDark ? const Color(0xFF9DA8A0) : const Color(0xFF757575),
                size: 20,
              ),
              onPressed: onToggleObscure,
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF0E1611) : const Color(0xFFF5FCF4),
            contentPadding:
                EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFA5D6A7),
                width: 1.2,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFA5D6A7),
                width: 1.2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF81C784) : const Color(0xFF4CAF50),
                width: 1.8,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1.8),
            ),
            errorStyle: GoogleFonts.plusJakartaSans(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFD32F2F),
            ),
          ),
        ),
      ],
    );
  }
}
