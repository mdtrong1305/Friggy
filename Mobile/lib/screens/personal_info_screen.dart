import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../data/local/storage_service.dart';
import '../data/models/user_models.dart';
import '../data/services/api_exception.dart';
import '../data/services/api_service.dart';
import '../config/app_constants.dart';
import '../l10n/app_localizations.dart';

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _dobController = TextEditingController();
  final _bioController = TextEditingController();
  String _selectedGender = 'Nam';
  String? _avatarUrl;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
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
      debugPrint('[PersonalInfoScreen] Error loading from API, fallback to storage: $e');
      final storage = await StorageService.getInstance();
      final userDataStr = storage.getUserData();
      if (userDataStr != null && userDataStr.isNotEmpty) {
        final Map<String, dynamic> userMap = jsonDecode(userDataStr);
        final String? name = userMap['name'] ?? userMap['fullName'];
        final String? email = userMap['googleEmail'] ?? userMap['email'];

        if (name != null && name.trim().isNotEmpty) _nameController.text = name.trim();
        if (email != null && email.trim().isNotEmpty) _emailController.text = email.trim();
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
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF19271E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Cập nhật ảnh đại diện',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF006428),
                ),
              ),
              const SizedBox(height: 18),
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
      if (file != null) {
        setState(() => _isUploadingAvatar = true);
        final res = await _apiService.uploadAvatar(file.path);
        final String? newAvatar = res['avatarUrl'];
        if (newAvatar != null && mounted) {
          setState(() {
            _avatarUrl = newAvatar;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã cập nhật ảnh đại diện thành công!'),
              backgroundColor: Color(0xFF008435),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[PersonalInfoScreen] Error uploading avatar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tải ảnh đại diện lên thất bại. Vui lòng thử lại!'),
            backgroundColor: Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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

      try {
        final profileData = <String, dynamic>{
          'name': _nameController.text.trim(),
          'gender': _mapGenderToEnum(_selectedGender),
        };

        if (_dobController.text.trim().isNotEmpty) {
          profileData['dateOfBirth'] = _dobController.text.trim();
        }

        if (_bioController.text.trim().isNotEmpty) {
          profileData['bio'] = _bioController.text.trim();
        }

        await _apiService.updateProfile(profileData);

        // Update local storage
        final storage = await StorageService.getInstance();
        final userDataStr = storage.getUserData();
        Map<String, dynamic> userMap = {};
        if (userDataStr != null && userDataStr.isNotEmpty) {
          userMap = jsonDecode(userDataStr);
        }
        userMap['name'] = _nameController.text.trim();
        await storage.saveUserData(jsonEncode(userMap));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Đã cập nhật thông tin cá nhân thành công!'),
              backgroundColor: const Color(0xFF008435),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              duration: const Duration(seconds: 2),
            ),
          );
          Navigator.pop(context);
        }
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: const Color(0xFFD32F2F),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không thể cập nhật thông tin. Vui lòng thử lại'),
              backgroundColor: Color(0xFFD32F2F),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
      }
    }
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
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                    const SizedBox(width: 14),
                    Text(
                      isEn ? 'Personal Information' : 'Thông tin cá nhân',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 12.0,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const SizedBox(height: 8),

                        // Profile Avatar with Camera Edit Icon
                        Center(
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
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
                                  backgroundImage: fullAvatar != null
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
                                  padding: const EdgeInsets.all(6),
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

                        const SizedBox(height: 24),

                        // Form Container matching BE UpdateProfileDto
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF19271E) : Colors.white,
                            borderRadius: BorderRadius.circular(24),
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
                              const SizedBox(height: 16),

                              // 2. Email (Read-only Account ID)
                              _buildValidatedField(
                                label: isEn ? 'Account Email' : 'Email tài khoản',
                                controller: _emailController,
                                icon: Icons.email_rounded,
                                readOnly: true,
                                suffixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: Colors.grey),
                                validator: null,
                              ),
                              const SizedBox(height: 16),

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
                              const SizedBox(height: 16),

                              // 4. Gender Radio Selection
                              Text(
                                isEn ? 'Gender' : 'Giới tính',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF006428),
                                ),
                              ),
                              const SizedBox(height: 8),
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
                                      margin: const EdgeInsets.only(right: 12),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? (isDark ? const Color(0xFF81C784) : const Color(0xFF4CAF50))
                                            : (isDark ? const Color(0xFF0E1611) : const Color(0xFFF1F8E9)),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isSelected
                                              ? (isDark ? const Color(0xFF81C784) : const Color(0xFF4CAF50))
                                              : (isDark ? const Color(0xFF2E4D36) : const Color(0xFFA5D6A7)),
                                        ),
                                      ),
                                      child: Text(
                                        gender,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13.5,
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
                              const SizedBox(height: 16),

                              // 5. Bio (Multi-line Description)
                              Text(
                                isEn ? 'Bio / Personal Motto' : 'Tiểu sử / Khẩu hiệu cá nhân',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF006428),
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _bioController,
                                maxLines: 3,
                                maxLength: 500,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
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
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFA5D6A7),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFA5D6A7),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
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

                        const SizedBox(height: 28),

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
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  )
                                : Text(
                                    isEn ? 'Save Changes' : 'Lưu thay đổi',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: isDark ? const Color(0xFF0E1611) : Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),
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
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF006428),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          keyboardType: keyboardType,
          validator: validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14.5,
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFA5D6A7),
                width: 1.2,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFA5D6A7),
                width: 1.2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF81C784) : const Color(0xFF4CAF50),
                width: 1.8,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1.8),
            ),
            errorStyle: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFD32F2F),
            ),
          ),
        ),
      ],
    );
  }
}

