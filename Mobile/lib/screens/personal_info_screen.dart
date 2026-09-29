import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../data/local/storage_service.dart';
import '../data/models/user_models.dart';
import '../data/services/api_exception.dart';
import '../data/services/api_service.dart';
import '../config/app_constants.dart';
import '../l10n/app_localizations.dart';
import '../sqlite/models/local_user_profile_model.dart';
import '../sqlite/services/user_profile_local_service.dart';

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final ApiService _apiService = ApiService();
  final UserProfileLocalService _profileLocalService = UserProfileLocalService();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _dobController = TextEditingController();
  final _bioController = TextEditingController();
  String _selectedGender = 'Nam';
  String? _avatarUrl;
  String? _avatarLocalPath; // đường dẫn ảnh local khi offline
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    // Bước 1: Load SQLite ngay lập tức để hiển thị nhanh (kể cả khi pending)
    final cached = await _profileLocalService.getCachedProfile();
    final hasPending = cached?.syncStatus == 'pending';

    if (cached != null && mounted) {
      setState(() {
        if (cached.name != null) _nameController.text = cached.name!;
        if (cached.email != null) _emailController.text = cached.email!;
        if (cached.dateOfBirth != null) _dobController.text = cached.dateOfBirth!;
        if (cached.bio != null) _bioController.text = cached.bio!;
        if (cached.avatarUrl != null) _avatarUrl = cached.avatarUrl;
        if (cached.avatarLocalPath != null) _avatarLocalPath = cached.avatarLocalPath;
        if (cached.gender != null) {
          final g = cached.gender!.toLowerCase();
          if (g == 'female') {
            _selectedGender = 'Nữ';
          } else if (g == 'other') {
            _selectedGender = 'Khác';
          } else {
            _selectedGender = 'Nam';
          }
        }
      });
      debugPrint('[PersonalInfoScreen] Loaded from SQLite (pending=$hasPending).');
    }

    // Bước 2: Nếu có pending chưa sync → không ghi đè bằng dữ liệu cũ từ server
    if (hasPending) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // Bước 3: Không pending → gọi API lấy dữ liệu mới nhất từ server
    try {
      final meJson = await _apiService.getMe();
      final me = MeModel.fromJson(meJson);

      if (mounted) {
        setState(() {
          if (me.name != null && me.name!.isNotEmpty) {
            _nameController.text = me.name!;
          }
          if (me.email != null && me.email!.isNotEmpty) {
            _emailController.text = me.email!;
          } else if (me.googleEmail != null && me.googleEmail!.isNotEmpty) {
            _emailController.text = me.googleEmail!;
          } else if (me.phone != null && me.phone!.isNotEmpty) {
            _emailController.text = me.phone!;
          }
          if (me.profile?.dateOfBirth != null) {
            _dobController.text = me.profile!.dateOfBirth!;
          }
          if (me.profile?.bio != null) {
            _bioController.text = me.profile!.bio!;
          }
          if (me.profile?.avatarUrl != null) {
            _avatarUrl = me.profile!.avatarUrl!;
            _avatarLocalPath = null; // Dùng URL server thay local path
          }
          if (me.profile?.gender != null) {
            final g = me.profile!.gender!.toLowerCase();
            if (g == 'female') {
              _selectedGender = 'Nữ';
            } else if (g == 'other') {
              _selectedGender = 'Khác';
            } else {
              _selectedGender = 'Nam';
            }
          }
        });
      }
    } catch (e) {
      // Offline hoặc lỗi API → giữ dữ liệu SQLite đã load ở Bước 1
      debugPrint('[PersonalInfoScreen] API error, keeping SQLite data: $e');

      // Nếu chưa có SQLite data → fallback SharedPreferences
      if (cached == null) {
        final storage = await StorageService.getInstance();
        final userDataStr = storage.getUserData();
        if (userDataStr != null && userDataStr.isNotEmpty) {
          final Map<String, dynamic> userMap = jsonDecode(userDataStr);
          final String? name = userMap['name'] ?? userMap['fullName'];
          final String? email = userMap['googleEmail'] ?? userMap['email'];
          if (mounted) {
            setState(() {
              if (name != null && name.trim().isNotEmpty) _nameController.text = name.trim();
              if (email != null && email.trim().isNotEmpty) _emailController.text = email.trim();
            });
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAvatarPickerModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF19271E) : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Cập nhật ảnh đại diện',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF006428),
                ),
              ),
              SizedBox(height: 18.h),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF4CAF50)),
                title: const Text('Chọn từ thư viện ảnh'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadAvatar(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF4CAF50)),
                title: const Text('Chụp ảnh mới'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadAvatar(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (file == null) return;

      setState(() => _isUploadingAvatar = true);

      try {
        // === ONLINE: upload lên server ===
        final res = await _apiService.uploadAvatar(file.path);
        final String? newAvatar = res['avatarUrl'];
        if (newAvatar != null && mounted) {
          setState(() {
            _avatarUrl = newAvatar;
            _avatarLocalPath = null; // xóa local path vì đã có URL server
          });
          // Lưu URL mới vào SQLite
          final cached = await _profileLocalService.getCachedProfile();
          if (cached != null) {
            await _profileLocalService.saveProfileCache(cached.copyWith(
              avatarUrl: newAvatar,
              avatarLocalPath: '',
              syncStatus: 'synced',
            ));
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Đã cập nhật ảnh đại diện thành công!'),
                backgroundColor: Color(0xFF008435),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } catch (uploadError) {
        // === OFFLINE: lưu đường dẫn file local ===
        debugPrint('[PersonalInfoScreen] Avatar upload failed (offline?), saving locally: $uploadError');
        if (mounted) {
          setState(() {
            _avatarLocalPath = file.path; // hiển thị ảnh local ngay
          });
          // Lưu local path vào SQLite để sync sau
          final cached = await _profileLocalService.getCachedProfile();
          if (cached != null) {
            await _profileLocalService.saveProfileCache(cached.copyWith(
              avatarLocalPath: file.path,
              syncStatus: 'pending',
            ));
          } else {
            // Chưa có profile trong SQLite, tạo mới
            await _profileLocalService.saveProfileCache(LocalUserProfileModel(
              id: 'me',
              name: _nameController.text.trim(),
              email: _emailController.text.trim(),
              avatarUrl: _avatarUrl,
              avatarLocalPath: file.path,
              updatedAt: DateTime.now().millisecondsSinceEpoch,
              syncStatus: 'pending',
            ));
          }
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text('Đã lưu ảnh. Sẽ tự động tải lên khi có mạng.')),
                ],
              ),
              backgroundColor: const Color(0xFFFF8C00),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[PersonalInfoScreen] Image picker error: $e');
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _selectDateOfBirth() async {
    DateTime initialDate = DateTime(1995, 8, 15);
    if (_dobController.text.trim().isNotEmpty) {
      try {
        final parts = _dobController.text.trim().split('-');
        if (parts.length == 3) {
          initialDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        }
      } catch (_) {}
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: Color(0xFF81C784),
                    onPrimary: Color(0xFF0E1611),
                    surface: Color(0xFF19271E),
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFF4CAF50),
                    onPrimary: Colors.white,
                  ),
                ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formatted =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      setState(() {
        _dobController.text = formatted;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  String _mapGenderToEnum(String gender) {
    if (gender == 'Nữ' || gender == 'Female') return 'female';
    if (gender == 'Khác' || gender == 'Other') return 'other';
    return 'male';
  }

  void _saveChanges() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isSaving = true;
      });

      final name = _nameController.text.trim();
      final dob = _dobController.text.trim();
      final bio = _bioController.text.trim();
      final gender = _mapGenderToEnum(_selectedGender);
      final now = DateTime.now().millisecondsSinceEpoch;

      try {
        final profileData = <String, dynamic>{
          'name': name,
          'gender': gender,
        };
        if (dob.isNotEmpty) profileData['dateOfBirth'] = dob;
        if (bio.isNotEmpty) profileData['bio'] = bio;

        await _apiService.updateProfile(profileData);

        // === ONLINE: lưu SQLite với sync_status='synced' ===
        await _profileLocalService.saveProfileCache(LocalUserProfileModel(
          id: 'me',
          name: name,
          email: _emailController.text.trim(),
          avatarUrl: _avatarUrl,
          dateOfBirth: dob.isNotEmpty ? dob : null,
          gender: gender,
          bio: bio.isNotEmpty ? bio : null,
          updatedAt: now,
          syncStatus: 'synced',
        ));

        // Update SharedPreferences
        final storage = await StorageService.getInstance();
        final userDataStr = storage.getUserData();
        Map<String, dynamic> userMap = {};
        if (userDataStr != null && userDataStr.isNotEmpty) {
          userMap = jsonDecode(userDataStr);
        }
        userMap['name'] = name;
        await storage.saveUserData(jsonEncode(userMap));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Đã cập nhật thông tin cá nhân thành công!'),
              backgroundColor: const Color(0xFF008435),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
              duration: const Duration(seconds: 2),
            ),
          );
          Navigator.pop(context);
        }
      } on ApiException catch (e) {
        if (e.isNetworkError) {
          // Lỗi mạng → xử lý như offline
          debugPrint('[PersonalInfoScreen] Network error, saving as pending: ${e.message}');
          await _saveOfflinePending(name, dob, bio, gender, now);
        } else {
          // Lỗi server thực sự (4xx/5xx) → hiện lỗi
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(e.message),
                backgroundColor: const Color(0xFFD32F2F),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } catch (e) {
        // Lỗi khác → xử lý như offline
        debugPrint('[PersonalInfoScreen] Unexpected error, saving as pending: $e');
        await _saveOfflinePending(name, dob, bio, gender, now);
      } finally {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
      }
    }
  }

  /// Lưu profile vào SQLite với sync_status='pending' khi offline
  Future<void> _saveOfflinePending(String name, String dob, String bio, String gender, int now) async {
    await _profileLocalService.saveProfileCache(LocalUserProfileModel(
      id: 'me',
      name: name,
      email: _emailController.text.trim(),
      avatarUrl: _avatarUrl,
      dateOfBirth: dob.isNotEmpty ? dob : null,
      gender: gender,
      bio: bio.isNotEmpty ? bio : null,
      updatedAt: now,
      syncStatus: 'pending',
    ));
    // Update SharedPreferences ngay để UI phản ánh thay đổi
    try {
      final storage = await StorageService.getInstance();
      final userDataStr = storage.getUserData();
      Map<String, dynamic> userMap = {};
      if (userDataStr != null && userDataStr.isNotEmpty) {
        userMap = jsonDecode(userDataStr);
      }
      userMap['name'] = name;
      await storage.saveUserData(jsonEncode(userMap));
    } catch (_) {}
    if (!mounted) return;
    Navigator.pop(context);
  }

  String? _getFullAvatarUrl(String? url) {
    return AppConstants.getImageUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final isEn = loc?.locale.languageCode == 'en';
    final fullAvatar = _getFullAvatarUrl(_avatarUrl);

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
                padding: EdgeInsets.symmetric(horizontal: 16.0.w, vertical: 8.0.h),
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
                      isEn ? 'Personal Information' : 'Thông tin cá nhân',
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
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50)))
                    : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 12.0,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        SizedBox(height: 8.h),

                        // Profile Avatar with Camera Edit Icon
                        Center(
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                padding: EdgeInsets.all(4.w),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF81C784) : const Color(0xFF4CAF50),
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 46,
                                  backgroundColor: isDark ? const Color(0xFF233629) : const Color(0xFFE8F5E9),
                                  backgroundImage: _avatarLocalPath != null && _avatarLocalPath!.isNotEmpty
                                      ? FileImage(File(_avatarLocalPath!)) as ImageProvider
                                      : fullAvatar != null
                                          ? NetworkImage(fullAvatar) as ImageProvider
                                          : const AssetImage('assets/images/cute_mascot.png'),
                                  child: _isUploadingAvatar
                                      ? const CircularProgressIndicator(color: Colors.white)
                                      : null,
                                ),
                              ),
                              GestureDetector(
                                onTap: _showAvatarPickerModal,
                                child: Container(
                                  padding: EdgeInsets.all(6.w),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4CAF50),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.2),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 24.h),

                        // Form Container matching BE UpdateProfileDto
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
                              // 1. Full Name
                              _buildValidatedField(
                                label: isEn ? 'Full Name' : 'Họ và tên',
                                controller: _nameController,
                                icon: Icons.person_rounded,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return isEn ? 'Please enter full name' : 'Vui lòng nhập họ và tên';
                                  }
                                  if (val.trim().length < 2) {
                                    return isEn ? 'Full name must be at least 2 characters' : 'Họ và tên phải có ít nhất 2 ký tự';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 16.h),

                              // 2. Email (Read-only Account ID)
                              _buildValidatedField(
                                label: isEn ? 'Account Email' : 'Email tài khoản',
                                controller: _emailController,
                                icon: Icons.email_rounded,
                                readOnly: true,
                                suffixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: Colors.grey),
                                validator: null,
                              ),
                              SizedBox(height: 16.h),

                              // 3. Date of Birth (Interactive DatePicker)
                              GestureDetector(
                                onTap: _selectDateOfBirth,
                                child: AbsorbPointer(
                                  child: _buildValidatedField(
                                    label: isEn ? 'Date of Birth (YYYY-MM-DD)' : 'Ngày sinh (Năm-Tháng-Ngày)',
                                    controller: _dobController,
                                    icon: Icons.calendar_today_rounded,
                                    suffixIcon: const Icon(Icons.arrow_drop_down_rounded, size: 24, color: Color(0xFF4CAF50)),
                                    validator: null,
                                  ),
                                ),
                              ),
                              SizedBox(height: 16.h),

                              // 4. Gender Radio Selection
                              Text(
                                isEn ? 'Gender' : 'Giới tính',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF006428),
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Row(
                                children: (isEn ? ['Male', 'Female', 'Other'] : ['Nam', 'Nữ', 'Khác']).map((gender) {
                                  final isSelected = _selectedGender == gender ||
                                      (gender == 'Male' && _selectedGender == 'Nam') ||
                                      (gender == 'Female' && _selectedGender == 'Nữ') ||
                                      (gender == 'Other' && _selectedGender == 'Khác');
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedGender = gender;
                                      });
                                    },
                                    child: Container(
                                      margin: EdgeInsets.only(right: 12.w),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? (isDark ? const Color(0xFF81C784) : const Color(0xFF4CAF50))
                                            : (isDark ? const Color(0xFF0E1611) : const Color(0xFFF1F8E9)),
                                        borderRadius: BorderRadius.circular(20.r),
                                        border: Border.all(
                                          color: isSelected
                                              ? (isDark ? const Color(0xFF81C784) : const Color(0xFF4CAF50))
                                              : (isDark ? const Color(0xFF2E4D36) : const Color(0xFFA5D6A7)),
                                        ),
                                      ),
                                      child: Text(
                                        gender,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13.5.sp,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected
                                              ? (isDark ? const Color(0xFF0E1611) : Colors.white)
                                              : (isDark ? Colors.white : const Color(0xFF006428)),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              SizedBox(height: 16.h),

                              // 5. Bio (Multi-line Description)
                              Text(
                                isEn ? 'Bio / Personal Motto' : 'Tiểu sử / Khẩu hiệu cá nhân',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF006428),
                                ),
                              ),
                              SizedBox(height: 6.h),
                              TextFormField(
                                controller: _bioController,
                                maxLines: 3,
                                maxLength: 500,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF19221C),
                                ),
                                decoration: InputDecoration(
                                  hintText: isEn ? 'Tell us a bit about yourself...' : 'Viết ngắn gọn sở thích nấu ăn của bạn...',
                                  hintStyle: GoogleFonts.plusJakartaSans(
                                    color: isDark ? const Color(0xFF758579) : const Color(0xFF9E9E9E),
                                  ),
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF0E1611) : const Color(0xFFF5FCF4),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16.r),
                                    borderSide: BorderSide(
                                      color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFA5D6A7),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16.r),
                                    borderSide: BorderSide(
                                      color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFA5D6A7),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16.r),
                                    borderSide: BorderSide(
                                      color: isDark ? const Color(0xFF81C784) : const Color(0xFF4CAF50),
                                      width: 1.8,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 28.h),

                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveChanges,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? const Color(0xFF81C784) : const Color(0xFF4CAF50),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28.r),
                              ),
                            ),
                            child: _isSaving
                                ? SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  )
                                : Text(
                                    isEn ? 'Save Changes' : 'Lưu thay đổi',
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

  Widget _buildValidatedField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool readOnly = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    required String? Function(String?)? validator,
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
          readOnly: readOnly,
          keyboardType: keyboardType,
          validator: validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14.5.sp,
            fontWeight: FontWeight.w700,
            color: readOnly
                ? (isDark ? const Color(0xFF81C784) : const Color(0xFF616161))
                : (isDark ? Colors.white : const Color(0xFF19221C)),
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              color: isDark ? const Color(0xFF81C784) : const Color(0xFF4CAF50),
              size: 20,
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: isDark ? const Color(0xFF0E1611) : const Color(0xFFF5FCF4),
            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
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

