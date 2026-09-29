import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../config/app_constants.dart';
import '../local/storage_service.dart';
import 'api_exception.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _apiService;
  final GoogleSignIn _googleSignIn;

  static final AuthService _instance = AuthService._internal();

  factory AuthService({ApiService? apiService, GoogleSignIn? googleSignIn}) {
    return _instance;
  }

  AuthService._internal()
      : _apiService = ApiService(),
        _googleSignIn = GoogleSignIn(
          scopes: ['email', 'profile'],
          serverClientId: AppConstants.googleClientId,
        );

  /// Checks whether a user role is allowed to access the Mobile app (only 'user' or 'users' allowed).
  static bool isAllowedRole(dynamic role) {
    if (role == null) return false;
    final String r = (role is Map ? role['name'] : role).toString().trim().toLowerCase();
    return r == 'user' || r == 'users';
  }

  /// Handles full Google Sign-In workflow:
  /// 1. Prompts user to select Google account via SDK
  /// 2. Retrieves Google ID Token
  /// 3. Sends POST /api/v1/auth/google via Dio
  /// 4. Validates user.role == 'user' / 'users'
  /// 5. Persists accessToken, refreshToken & user data in SharedPreferences
  Future<bool> signInWithGoogle(BuildContext context) async {
    try {
      // 1. Sign out first to ensure fresh account selection prompt
      await _googleSignIn.signOut();

      // 2. Trigger native Google Sign-In prompt
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled sign-in flow
        debugPrint('[AuthService] User canceled Google sign in');
        return false;
      }

      // 3. Obtain authentication tokens
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null || idToken.isEmpty) {
        if (context.mounted) {
          _showSnackBar(context, 'Không lấy được Google ID Token từ thiết bị', isError: true);
        }
        return false;
      }

      debugPrint('[AuthService] Obtained Google ID Token successfully: ${idToken.substring(0, 20)}...');

      // 4. Call Backend API POST /api/v1/auth/google
      final dynamic apiResult = await _apiService.loginWithGoogle(idToken);

      final Map<String, dynamic> result = (apiResult is Map<String, dynamic>) ? apiResult : {};
      final payload = (result.containsKey('data') && result['data'] is Map<String, dynamic>)
          ? result['data'] as Map<String, dynamic>
          : result;

      final String? accessToken = payload['accessToken'] as String?;
      final String? refreshToken = payload['refreshToken'] as String?;
      final Map<String, dynamic>? user = (payload['user'] is Map<String, dynamic>)
          ? payload['user'] as Map<String, dynamic>
          : null;

      final dynamic userRole = user?['role'];
      if (!isAllowedRole(userRole)) {
        final String roleDisplay = (userRole is Map ? userRole['name'] : userRole)?.toString() ?? 'Khác';
        debugPrint('[AuthService] Rejected Google Login: User role "$roleDisplay" is not allowed.');
        if (context.mounted) {
          _showSnackBar(
            context,
            'Tài khoản của bạn ($roleDisplay) không có quyền truy cập ứng dụng di động (Chỉ dành cho tài khoản User).',
            isError: true,
          );
        }
        return false;
      }

      if (accessToken != null && accessToken.isNotEmpty) {
        final storage = await StorageService.getInstance();
        await storage.saveAccessToken(accessToken);
        if (refreshToken != null) await storage.saveRefreshToken(refreshToken);

        final Map<String, dynamic> userDataToSave = user ?? {};
        if (userDataToSave['name'] == null || (userDataToSave['name'] as String).trim().isEmpty) {
          userDataToSave['name'] = googleUser.displayName ?? googleUser.email.split('@').first;
        }
        if (userDataToSave['email'] == null || (userDataToSave['email'] as String).trim().isEmpty) {
          userDataToSave['email'] = googleUser.email;
        }

        if (userDataToSave['id'] != null) await storage.saveUserId(userDataToSave['id'].toString());
        await storage.saveUserData(jsonEncode(userDataToSave));

        debugPrint('[AuthService] Google Login successful. User (${userDataToSave['name']}) saved in StorageService.');
        return true;
      } else {
        if (context.mounted) {
          _showSnackBar(context, 'Đăng nhập không thành công. Vui lòng thử lại', isError: true);
        }
        return false;
      }
    } on MissingPluginException catch (_) {
      debugPrint('[AuthService] MissingPluginException: Native Google Sign-In plugin not compiled into running APK.');
      if (context.mounted) {
        _showSnackBar(
          context,
          'Vui lòng tắt ứng dụng và bấm RUN lại (Rebuild) để nạp plugin Native Google!',
          isError: true,
        );
      }
      return false;
    } on PlatformException catch (e) {
      debugPrint('[AuthService] PlatformException during Google login: ${e.code} - ${e.message}');
      if (context.mounted) {
        final isDevError = e.message?.contains('10') == true || e.code == 'sign_in_failed';
        final msg = isDevError
            ? 'Lỗi 10 (DEVELOPER_ERROR): Cần thêm SHA-1 fingerprint vào Google Cloud Console'
            : 'Lỗi Google Sign-In: ${e.message}';
        _showSnackBar(context, msg, isError: true);
      }
      return false;
    } on ApiException catch (e) {
      debugPrint('[AuthService] ApiException during Google login: ${e.message}');
      if (context.mounted) {
        _showSnackBar(context, e.message, isError: true);
      }
      return false;
    } catch (e) {
      debugPrint('[AuthService] Unexpected error during Google login: $e');
      if (context.mounted) {
        _showSnackBar(context, 'Đã xảy ra lỗi khi đăng nhập bằng Google', isError: true);
      }
      return false;
    }
  }

  /// Helper to save authentication result to StorageService
  Future<bool> _handleAuthResult(BuildContext context, dynamic apiResult, String logTag) async {
    final Map<String, dynamic> result = (apiResult is Map<String, dynamic>) ? apiResult : {};
    final payload = (result.containsKey('data') && result['data'] is Map<String, dynamic>)
        ? result['data'] as Map<String, dynamic>
        : result;

    final String? accessToken = payload['accessToken'] as String?;
    final String? refreshToken = payload['refreshToken'] as String?;
    final Map<String, dynamic>? user = (payload['user'] is Map<String, dynamic>)
        ? payload['user'] as Map<String, dynamic>
        : null;

    final dynamic userRole = user?['role'];
    if (!isAllowedRole(userRole)) {
      final String roleDisplay = (userRole is Map ? userRole['name'] : userRole)?.toString() ?? 'Khác';
      debugPrint('[$logTag] Rejected Auth: User role "$roleDisplay" is not allowed.');
      if (context.mounted) {
        _showSnackBar(
          context,
          'Tài khoản của bạn ($roleDisplay) không có quyền truy cập ứng dụng di động (Chỉ dành cho tài khoản User).',
          isError: true,
        );
      }
      return false;
    }

    if (accessToken != null && accessToken.isNotEmpty) {
      final storage = await StorageService.getInstance();
      await storage.saveAccessToken(accessToken);
      if (refreshToken != null) await storage.saveRefreshToken(refreshToken);

      final Map<String, dynamic> userDataToSave = user ?? {};
      if (userDataToSave['id'] != null) await storage.saveUserId(userDataToSave['id'].toString());
      await storage.saveUserData(jsonEncode(userDataToSave));

      debugPrint('[$logTag] Login/Auth successful. User saved in StorageService.');
      return true;
    } else {
      if (context.mounted) {
        _showSnackBar(context, 'Xác thực không thành công. Vui lòng thử lại', isError: true);
      }
      return false;
    }
  }

  /// Handles Email + Password Login
  Future<bool> loginWithEmail(BuildContext context, String email, String password) async {
    try {
      final dynamic apiResult = await _apiService.emailLogin(email, password);
      if (!context.mounted) return false;
      return await _handleAuthResult(context, apiResult, 'AuthService:EmailLogin');
    } on ApiException catch (e) {
      debugPrint('[AuthService] ApiException during Email login: ${e.message}');
      if (context.mounted) {
        _showSnackBar(context, e.message, isError: true);
      }
      return false;
    } catch (e) {
      debugPrint('[AuthService] Unexpected error during Email login: $e');
      if (context.mounted) {
        _showSnackBar(context, 'Đã xảy ra lỗi khi đăng nhập', isError: true);
      }
      return false;
    }
  }

  /// Step 1: Request OTP for Email registration
  Future<bool> registerEmailSendOtp(BuildContext context, String email) async {
    try {
      final res = await _apiService.emailRegister(email);
      final msg = res['message']?.toString() ?? 'Mã OTP đã được gửi đến email của bạn';
      if (context.mounted) {
        _showSnackBar(context, msg, isError: false);
      }
      return true;
    } on ApiException catch (e) {
      debugPrint('[AuthService] ApiException during Email register OTP send: ${e.message}');
      if (context.mounted) {
        _showSnackBar(context, e.message, isError: true);
      }
      return false;
    } catch (e) {
      debugPrint('[AuthService] Unexpected error during Email register OTP send: $e');
      if (context.mounted) {
        _showSnackBar(context, 'Đã xảy ra lỗi khi gửi mã OTP đăng ký', isError: true);
      }
      return false;
    }
  }

  /// Step 2: Verify Email OTP, activate account & receive JWT session
  Future<bool> verifyEmailOtpAndRegister(
    BuildContext context, {
    required String email,
    required String otpCode,
    required String password,
    String? name,
  }) async {
    try {
      final dynamic apiResult = await _apiService.verifyEmailOtp(
        email: email,
        otpCode: otpCode,
        password: password,
        name: name,
      );
      if (!context.mounted) return false;
      return await _handleAuthResult(context, apiResult, 'AuthService:VerifyEmailOtp');
    } on ApiException catch (e) {
      debugPrint('[AuthService] ApiException during Verify Email OTP: ${e.message}');
      if (context.mounted) {
        _showSnackBar(context, e.message, isError: true);
      }
      return false;
    } catch (e) {
      debugPrint('[AuthService] Unexpected error during Verify Email OTP: $e');
      if (context.mounted) {
        _showSnackBar(context, 'Mã OTP không hợp lệ hoặc đã hết hạn', isError: true);
      }
      return false;
    }
  }

  /// Forgot Password Step 1: Send OTP to Email
  Future<bool> sendForgotPasswordOtp(BuildContext context, String email) async {
    try {
      final res = await _apiService.forgotPassword(email);
      final msg = res['message']?.toString() ?? 'Mã OTP đã được gửi đến email của bạn';
      if (context.mounted) {
        _showSnackBar(context, msg, isError: false);
      }
      return true;
    } on ApiException catch (e) {
      debugPrint('[AuthService] ApiException during Forgot Password OTP send: ${e.message}');
      if (context.mounted) {
        _showSnackBar(context, e.message, isError: true);
      }
      return false;
    } catch (e) {
      debugPrint('[AuthService] Unexpected error during Forgot Password OTP send: $e');
      if (context.mounted) {
        _showSnackBar(context, 'Đã xảy ra lỗi khi gửi OTP quên mật khẩu', isError: true);
      }
      return false;
    }
  }

  /// Forgot Password Step 2: Reset password using OTP + new password
  Future<bool> resetPasswordWithOtp(
    BuildContext context, {
    required String email,
    required String otpCode,
    required String newPassword,
  }) async {
    try {
      final res = await _apiService.resetPassword(
        email: email,
        otpCode: otpCode,
        newPassword: newPassword,
      );
      final msg = res['message']?.toString() ?? 'Đặt lại mật khẩu thành công';
      if (context.mounted) {
        _showSnackBar(context, msg, isError: false);
      }
      return true;
    } on ApiException catch (e) {
      debugPrint('[AuthService] ApiException during Reset Password: ${e.message}');
      if (context.mounted) {
        _showSnackBar(context, e.message, isError: true);
      }
      return false;
    } catch (e) {
      debugPrint('[AuthService] Unexpected error during Reset Password: $e');
      if (context.mounted) {
        _showSnackBar(context, 'Đã xảy ra lỗi khi đặt lại mật khẩu', isError: true);
      }
      return false;
    }
  }

  /// Change Password for logged-in user
  Future<bool> changePassword(
    BuildContext context, {
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final res = await _apiService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      final msg = res['message']?.toString() ?? 'Đổi mật khẩu thành công';
      if (context.mounted) {
        _showSnackBar(context, msg, isError: false);
      }
      return true;
    } on ApiException catch (e) {
      debugPrint('[AuthService] ApiException during Change Password: ${e.message}');
      if (context.mounted) {
        _showSnackBar(context, e.message, isError: true);
      }
      return false;
    } catch (e) {
      debugPrint('[AuthService] Unexpected error during Change Password: $e');
      if (context.mounted) {
        _showSnackBar(context, 'Đã xảy ra lỗi khi đổi mật khẩu', isError: true);
      }
      return false;
    }
  }

  /// Handles Phone OTP verification & login:
  /// 1. Calls backend POST /api/v1/auth/phone/verify
  /// 2. Verifies user.role == 'user' / 'users'
  /// 3. Saves session & user data
  Future<bool> verifyPhoneOtpAndLogin(BuildContext context, String phone, String otpCode) async {
    try {
      final dynamic apiResult = await _apiService.verifyPhoneOtp(phone, otpCode);

      final Map<String, dynamic> result = (apiResult is Map<String, dynamic>) ? apiResult : {};
      final payload = (result.containsKey('data') && result['data'] is Map<String, dynamic>)
          ? result['data'] as Map<String, dynamic>
          : result;

      final String? accessToken = payload['accessToken'] as String?;
      final String? refreshToken = payload['refreshToken'] as String?;
      final Map<String, dynamic>? user = (payload['user'] is Map<String, dynamic>)
          ? payload['user'] as Map<String, dynamic>
          : null;

      final dynamic userRole = user?['role'];
      if (!isAllowedRole(userRole)) {
        final String roleDisplay = (userRole is Map ? userRole['name'] : userRole)?.toString() ?? 'Khác';
        debugPrint('[AuthService] Rejected Phone Login: User role "$roleDisplay" is not allowed.');
        if (context.mounted) {
          _showSnackBar(
            context,
            'Tài khoản của bạn ($roleDisplay) không có quyền truy cập ứng dụng di động (Chỉ dành cho tài khoản User).',
            isError: true,
          );
        }
        return false;
      }

      if (accessToken != null && accessToken.isNotEmpty) {
        final storage = await StorageService.getInstance();
        await storage.saveAccessToken(accessToken);
        if (refreshToken != null) await storage.saveRefreshToken(refreshToken);

        final Map<String, dynamic> userDataToSave = user ?? {};
        if (userDataToSave['id'] != null) await storage.saveUserId(userDataToSave['id'].toString());
        await storage.saveUserData(jsonEncode(userDataToSave));

        debugPrint('[AuthService] Phone Login successful. User saved in StorageService.');
        return true;
      } else {
        if (context.mounted) {
          _showSnackBar(context, 'Xác minh không thành công. Vui lòng thử lại', isError: true);
        }
        return false;
      }
    } on ApiException catch (e) {
      debugPrint('[AuthService] ApiException during Phone verify: ${e.message}');
      if (context.mounted) {
        _showSnackBar(context, e.message, isError: true);
      }
      return false;
    } catch (e) {
      debugPrint('[AuthService] Unexpected error during Phone verify: $e');
      if (context.mounted) {
        _showSnackBar(context, 'Đã xảy ra lỗi khi xác minh OTP', isError: true);
      }
      return false;
    }
  }

  /// Checks if stored session/refreshToken is valid by attempting token refresh
  Future<bool> checkAndRefreshToken() async {
    try {
      final storage = await StorageService.getInstance();
      final refreshToken = storage.getRefreshToken();
      final accessToken = storage.getAccessToken();

      if ((refreshToken == null || refreshToken.isEmpty) &&
          (accessToken == null || accessToken.isEmpty)) {
        debugPrint('[AuthService] No stored tokens found.');
        return false;
      }

      final dio = Dio(BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ));

      final response = await dio.post(
        AppConstants.epAuthRefreshToken,
        data: {'refreshToken': refreshToken ?? ''},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        Map<String, dynamic>? payload;
        if (data is Map<String, dynamic>) {
          if (data.containsKey('data') && data['data'] is Map<String, dynamic>) {
            payload = data['data'] as Map<String, dynamic>;
          } else {
            payload = data;
          }
        }

        if (payload != null) {
          final newAccessToken = payload['accessToken'] as String?;
          final newRefreshToken = payload['refreshToken'] as String?;
          final user = payload['user'] as Map<String, dynamic>?;

          if (newAccessToken != null && newAccessToken.isNotEmpty) {
            await storage.saveAccessToken(newAccessToken);
            if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
              await storage.saveRefreshToken(newRefreshToken);
            }
            if (user != null) {
              await storage.saveUserData(jsonEncode(user));
            }
            debugPrint('[AuthService] Auto-login refresh token succeeded!');
            return true;
          }
        }
      }
    } on DioException catch (e) {
      debugPrint('[AuthService] DioException during auto-login refresh: ${e.type} - ${e.message}');
      // If network error/timeout occurs (device is offline), but user has local tokens, allow offline session!
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.error.toString().contains('SocketException')) {
        final storage = await StorageService.getInstance();
        final token = storage.getAccessToken() ?? storage.getRefreshToken();
        if (token != null && token.isNotEmpty) {
          debugPrint('[AuthService] Device is offline. Valid local session found -> Allowing Offline App Access!');
          return true;
        }
      }
    } catch (e) {
      debugPrint('[AuthService] Auto-login checkAndRefreshToken error: $e');
      final storage = await StorageService.getInstance();
      final token = storage.getAccessToken() ?? storage.getRefreshToken();
      if (token != null && token.isNotEmpty) {
        debugPrint('[AuthService] Unexpected offline error. Valid local session found -> Allowing Offline App Access!');
        return true;
      }
    }
    return false;
  }

  /// Handles full Logout workflow:
  /// 1. Calls Backend POST /api/v1/auth/logout with stored refreshToken
  /// 2. Signs out of GoogleSignIn SDK
  /// 3. Clears local SharedPreferences session
  Future<void> logout() async {
    try {
      final storage = await StorageService.getInstance();
      final refreshToken = storage.getRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _apiService.logout(refreshToken);
        debugPrint('[AuthService] Successfully revoked refresh token on backend.');
      }
    } catch (e) {
      debugPrint('[AuthService] Exception during backend logout call: $e');
    } finally {
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        debugPrint('[AuthService] Error signing out from Google SDK: $e');
      }
      final storage = await StorageService.getInstance();
      await storage.clearSession();
      debugPrint('[AuthService] Local session cleared.');
    }
  }

  void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFE53935) : const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
