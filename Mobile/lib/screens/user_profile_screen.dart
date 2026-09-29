import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../data/local/storage_service.dart';
import '../data/models/user_models.dart';
import '../data/services/api_service.dart';
import '../data/services/auth_service.dart';
import '../config/app_constants.dart';
import '../l10n/app_localizations.dart';
import 'login_screen.dart';
import 'personal_info_screen.dart';
import 'change_password_screen.dart';
import 'app_settings_screen.dart';
import 'user_preferences_screen.dart';
import 'user_allergies_screen.dart';
import 'family_management_screen.dart';
import 'package:friggy/screens/package_management_screen.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => UserProfileScreenState();
}

class UserProfileScreenState extends State<UserProfileScreen> {
  final ApiService _apiService = ApiService();
  String _userName = 'Người dùng Friggy';
  String _userContact = '';
  String? _bio;
  String? _avatarUrl;
  AiUsageModel? _aiUsage;
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchAiUsage();
  }

  void reload() {
    _loadUserData();
    _fetchAiUsage();
  }

  Future<void> _loadUserData() async {
    _fetchAiUsage();
    try {
      final meJson = await _apiService.getMe();
      final me = MeModel.fromJson(meJson);

      if (mounted) {
        setState(() {
          if (me.name != null && me.name!.isNotEmpty) {
            _userName = me.name!;
          }
          if (me.email != null && me.email!.isNotEmpty) {
            _userContact = me.email!;
          } else if (me.googleEmail != null && me.googleEmail!.isNotEmpty) {
            _userContact = me.googleEmail!;
          } else if (me.phone != null && me.phone!.isNotEmpty) {
            _userContact = me.phone!;
          }
          if (me.profile?.avatarUrl != null) {
            _avatarUrl = me.profile!.avatarUrl!;
          }
          if (me.profile?.bio != null) {
            _bio = me.profile!.bio!;
          }
        });
      }
    } catch (e) {
      debugPrint('[UserProfileScreen] API getMe error, falling back to local storage: $e');
      final storage = await StorageService.getInstance();
      final userDataStr = storage.getUserData();
      if (userDataStr != null && userDataStr.isNotEmpty) {
        final Map<String, dynamic> userMap = jsonDecode(userDataStr);
        final String? name = userMap['name'] ?? userMap['fullName'];
        final String? email = userMap['googleEmail'] ?? userMap['email'];
        final String? phone = userMap['phone'] ?? userMap['emailOrPhone'];

        String parsedName = 'Người dùng Friggy';
        if (name != null && name.trim().isNotEmpty) parsedName = name.trim();

        String parsedContact = '';
        if (email != null && email.trim().isNotEmpty) {
          parsedContact = email.trim();
        } else if (phone != null && phone.trim().isNotEmpty) {
          parsedContact = phone.trim();
        }

        if (mounted) {
          setState(() {
            _userName = parsedName;
            _userContact = parsedContact;
          });
        }
      }
    }
  }

  Future<void> _fetchAiUsage() async {
    try {
      final res = await _apiService.getAiUsage();
      if (mounted) {
        setState(() {
          _aiUsage = AiUsageModel.fromJson(res);
        });
      }
    } catch (e) {
      debugPrint('[UserProfileScreen] Error fetching AI usage: $e');
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
      debugPrint('[UserProfileScreen] Error uploading avatar: $e');
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

  void _performLogout() async {
    await AuthService().logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
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

    final nameColor = isDark ? Colors.white : const Color(0xFF006428);
    final emailColor = isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32);
    final sectionTitleColor = isDark ? const Color(0xFF81C784) : const Color(0xFF006428);
    final cardBg = isDark ? const Color(0xFF19271E) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF2E4D36) : const Color(0xFFA5E69C);
    final defaultTitleColor = isDark ? Colors.white : const Color(0xFF19221C);
    final defaultIconBg = isDark ? const Color(0xFF233629) : const Color(0xFFE8F5E9);
    final defaultIconColor = isDark ? const Color(0xFF81C784) : const Color(0xFF006428);

    final String aiUsageText;
    final String remainingText;

    if (_aiUsage != null) {
      if (_aiUsage!.limit == -1) {
        aiUsageText = isEn
            ? 'Unlimited AI'
            : 'Không giới hạn AI';
        remainingText = isEn
            ? 'Unlimited AI features enabled'
            : 'Không giới hạn lượt AI tuần này';
      } else {
        aiUsageText = isEn
            ? 'AI Used: ${_aiUsage!.used}/${_aiUsage!.limit} this week'
            : 'Đã dùng ${_aiUsage!.used}/${_aiUsage!.limit} lượt AI tuần này';
        remainingText = isEn
            ? 'Remaining ${_aiUsage!.remaining} AI calls this week'
            : 'Còn lại ${_aiUsage!.remaining} lượt AI tuần này';
      }
    } else {
      aiUsageText = isEn ? 'Personal Plan' : 'Gói Cá Nhân';
      remainingText = isEn ? 'Manage Plan' : 'Quản lý gói dịch vụ';
    }

    final fullAvatar = _getFullAvatarUrl(_avatarUrl);

    return RefreshIndicator(
      onRefresh: () async {
        await _loadUserData();
        await _fetchAiUsage();
      },
      color: const Color(0xFF008435),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 28),

          // 2. User Avatar & Info Section
          Center(
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF4CAF50),
                          width: 3.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.1),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 58,
                        backgroundColor: defaultIconBg,
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
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  _userName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: nameColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _userContact,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: emailColor,
                  ),
                ),
                if (_bio != null && _bio!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, left: 24, right: 24),
                    child: Text(
                      '“$_bio”',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontStyle: FontStyle.italic,
                        color: isDark ? const Color(0xFFB0BEC5) : const Color(0xFF616161),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 3. Subscription Package & AI Usage Card
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PackageManagementScreen(),
                ),
              ).then((_) => reload());
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                border: isDark
                    ? Border.all(
                        color: const Color(0xFF2E4D36),
                        width: 1.2,
                      )
                    : null,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? const [
                          Color(0xFF1E3A25),
                          Color(0xFF142017),
                          Color(0xFF192C1E),
                        ]
                      : const [
                          Color(0xFF7CB342),
                          Color(0xFF8BC34A),
                          Color(0xFFC0CA33),
                        ],
                  stops: isDark ? const [0.0, 0.5, 1.0] : const [0.0, 0.5, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.25)
                        : const Color(0xFF7CB342).withValues(alpha: 0.3),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFB74D),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.star_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isEn ? 'AI PLAN' : 'GÓI AI FRIGGY',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: isDark ? const Color(0xFFFFB74D) : Colors.white,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        if (_aiUsage != null && _aiUsage!.limit == -1) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                isEn ? 'Unlimited AI ' : 'Không giới hạn AI ',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                              ),
                              Transform.translate(
                                offset: const Offset(0, -4),
                                child: Text(
                                  '∞',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 60,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    height: 0.8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          Text(
                            aiUsageText,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.15,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),

                        Text(
                          remainingText,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFD0D7D1) : Colors.white.withValues(alpha: 0.95),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF233629)
                          : const Color(0xFF8BC34A).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF81C784)
                            : Colors.white.withValues(alpha: 0.4),
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      isEn ? 'Manage Plan' : 'Quản lý gói',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFF81C784) : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // 4. Account Settings Menu List Section
          Text(
            isEn ? 'Account & Settings' : 'Tài khoản & Ứng dụng',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: sectionTitleColor,
            ),
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: cardBorder,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                // 1. Personal Info
                _buildMenuItem(
                  icon: Icons.person_outline_rounded,
                  title: loc?.personalInfo ?? 'Thông tin cá nhân',
                  titleColor: defaultTitleColor,
                  iconColor: defaultIconColor,
                  iconBgColor: defaultIconBg,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PersonalInfoScreen(),
                      ),
                    ).then((_) => _loadUserData());
                  },
                ),
                _buildDivider(isDark),

                // 2. Family Group Management
                _buildMenuItem(
                  icon: Icons.family_restroom_rounded,
                  title: isEn ? 'Family Group' : 'Nhóm gia đình',
                  titleColor: defaultTitleColor,
                  iconColor: defaultIconColor,
                  iconBgColor: defaultIconBg,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FamilyManagementScreen(),
                      ),
                    );
                  },
                ),
                _buildDivider(isDark),

                // 2. Culinary & Dietary Preferences (NEW)
                _buildMenuItem(
                  icon: Icons.restaurant_menu_rounded,
                  title: isEn ? 'Culinary & Dietary Preferences' : 'Tùy chọn ăn uống & Kỹ năng',
                  titleColor: defaultTitleColor,
                  iconColor: defaultIconColor,
                  iconBgColor: defaultIconBg,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UserPreferencesScreen(),
                      ),
                    );
                  },
                ),
                _buildDivider(isDark),

                // 3. Food Allergies (NEW)
                _buildMenuItem(
                  icon: Icons.no_food_rounded,
                  title: isEn ? 'Food Allergies' : 'Dị ứng thực phẩm',
                  titleColor: defaultTitleColor,
                  iconColor: defaultIconColor,
                  iconBgColor: defaultIconBg,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UserAllergiesScreen(),
                      ),
                    );
                  },
                ),
                _buildDivider(isDark),

                // 4. Change Password
                _buildMenuItem(
                  icon: Icons.lock_outline_rounded,
                  title: loc?.changePassword ?? 'Đổi mật khẩu',
                  titleColor: defaultTitleColor,
                  iconColor: defaultIconColor,
                  iconBgColor: defaultIconBg,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChangePasswordScreen(),
                      ),
                    );
                  },
                ),
                _buildDivider(isDark),

                // 5. Settings
                _buildMenuItem(
                  icon: Icons.settings_outlined,
                  title: loc?.settings ?? 'Cài đặt',
                  titleColor: defaultTitleColor,
                  iconColor: defaultIconColor,
                  iconBgColor: defaultIconBg,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AppSettingsScreen(),
                      ),
                    );
                  },
                ),
                _buildDivider(isDark),

                // 6. Logout
                _buildMenuItem(
                  icon: Icons.logout_rounded,
                  title: loc?.logout ?? 'Đăng xuất',
                  titleColor: const Color(0xFFD32F2F),
                  iconColor: const Color(0xFFD32F2F),
                  iconBgColor: isDark ? const Color(0xFF4A1F1F) : const Color(0xFFFFEBEE),
                  showChevron: false,
                  onTap: _performLogout,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    ),
  );
}

  Widget _buildDivider(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 1,
      color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFE8F5E9),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Color titleColor = const Color(0xFF19221C),
    Color subtitleColor = const Color(0xFF757575),
    Color iconColor = const Color(0xFF006428),
    Color iconBgColor = const Color(0xFFE8F5E9),
    bool showChevron = true,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconBgColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: titleColor,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                color: subtitleColor,
              ),
            )
          : null,
      trailing: showChevron
          ? const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF757575),
              size: 20,
            )
          : null,
    );
  }
}
