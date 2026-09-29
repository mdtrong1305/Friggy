import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../data/models/user_models.dart';
import '../data/services/api_service.dart';
import '../l10n/app_localizations.dart';
import '../l10n/language_provider.dart';
import '../theme/theme_provider.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _pushNotifications = true;
  bool _shoppingReminder = false;
  bool _expiryAlert = true;

  @override
  void initState() {
    super.initState();
    _fetchNotificationSettings();
  }

  Future<void> _fetchNotificationSettings() async {
    try {
      final res = await _apiService.getNotificationSettings();
      final settings = NotificationSettingsModel.fromJson(res);
      if (mounted) {
        setState(() {
          _pushNotifications = settings.pushNotifications;
          _shoppingReminder = settings.shoppingReminder;
          _expiryAlert = settings.expiryAlert;
        });
      }
    } catch (e) {
      debugPrint('[AppSettingsScreen] Error fetching notification settings: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateSettings({bool? push, bool? shopping, bool? expiry}) async {
    final newPush = push ?? _pushNotifications;
    final newShopping = shopping ?? _shoppingReminder;
    final newExpiry = expiry ?? _expiryAlert;

    setState(() {
      _pushNotifications = newPush;
      _shoppingReminder = newShopping;
      _expiryAlert = newExpiry;
    });

    try {
      await _apiService.updateNotificationSettings({
        'pushNotifications': newPush,
        'shoppingReminder': newShopping,
        'expiryAlert': newExpiry,
      });
    } catch (e) {
      debugPrint('[AppSettingsScreen] Error updating notification settings: $e');
    }
  }

  void _showLanguageSelectionModal(BuildContext context, bool isDark) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final currentCode = languageProvider.locale.languageCode;
    final loc = AppLocalizations.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF19271E) : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
            border: isDark
                ? const Border(top: BorderSide(color: Color(0xFF2E4D36), width: 1.2))
                : null,
          ),
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Drag Handle Bar
              Center(
                child: Container(
                  width: 42,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFC8E6C9),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
              ),

              SizedBox(height: 18.h),

              // Title
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF233629) : const Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.language_rounded,
                      color: isDark ? const Color(0xFF81C784) : const Color(0xFF008435),
                      size: 22,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    loc?.selectLanguage ?? 'Chọn ngôn ngữ ứng dụng',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF006428),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 20.h),

              // Option 1: Tiếng Việt
              _buildLanguageOption(
                context: context,
                isDark: isDark,
                flag: '🇻🇳',
                title: 'Tiếng Việt',
                subtitle: 'Tiếng Việt (Vietnamese)',
                isSelected: currentCode == 'vi',
                onTap: () {
                  languageProvider.setLocale(const Locale('vi'));
                  Navigator.pop(context);
                },
              ),

              SizedBox(height: 10.h),

              // Option 2: English
              _buildLanguageOption(
                context: context,
                isDark: isDark,
                flag: '🇬🇧',
                title: 'English',
                subtitle: 'English (United States)',
                isSelected: currentCode == 'en',
                onTap: () {
                  languageProvider.setLocale(const Locale('en'));
                  Navigator.pop(context);
                },
              ),

              SizedBox(height: 24.h),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption({
    required BuildContext context,
    required bool isDark,
    required String flag,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF233629) : const Color(0xFFE8F5E9))
              : (isDark ? const Color(0xFF0E1611) : const Color(0xFFF7FAF8)),
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: isSelected
                ? (isDark ? const Color(0xFF81C784) : const Color(0xFF008435))
                : (isDark ? const Color(0xFF2E4D36) : const Color(0xFFE2E8E4)),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Text(
              flag,
              style: TextStyle(fontSize: 26),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF19221C),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5.sp,
                      color: isDark ? const Color(0xFF9DA8A0) : const Color(0xFF757575),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: isDark ? const Color(0xFF81C784) : const Color(0xFF008435),
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final loc = AppLocalizations.of(context);
    final isDark = themeProvider.isDarkMode;

    // Adapt background and card colors dynamically based on light/dark mode
    final bgColor1 = isDark ? const Color(0xFF0E1611) : const Color(0xFFFFFFFF);
    final bgColor2 = isDark ? const Color(0xFF142017) : const Color(0xFFF5FCF4);
    final bgColor3 = isDark ? const Color(0xFF1B2E21) : const Color(0xFFC7EFC2);
    final bgColor4 = isDark ? const Color(0xFF1E3A25) : const Color(0xFF86D978);

    final cardBg = isDark ? const Color(0xFF19271E) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF2E4D36) : const Color(0xFFA5E69C);
    final titleColor = isDark ? const Color(0xFF81C784) : const Color(0xFF006428);
    final itemTextColor = isDark ? Colors.white : const Color(0xFF19221C);
    final itemSubtextColor = isDark ? const Color(0xFF9DA8A0) : const Color(0xFF757575);
    final iconBgColor = isDark ? const Color(0xFF233629) : const Color(0xFFE8F5E9);
    final iconColor = isDark ? const Color(0xFF81C784) : const Color(0xFF008435);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgColor1, bgColor2, bgColor3, bgColor4],
            stops: const [0.0, 0.3, 0.7, 1.0],
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
                          color: cardBg,
                          shape: BoxShape.circle,
                          border: Border.all(color: cardBorder, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: iconColor,
                          size: 22,
                        ),
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Text(
                      loc?.settings ?? 'Cài đặt',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w900,
                        color: titleColor,
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
                      horizontal: 20.0.w, vertical: 16.0.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section 1: Notifications & Reminders
                      _buildSectionTitle(
                        loc?.notificationsReminders ?? 'Thông báo & Nhắc nhở',
                        titleColor,
                      ),
                      SizedBox(height: 8.h),
                      _buildCard(cardBg, cardBorder, [
                        _buildSwitchTile(
                          icon: Icons.notifications_rounded,
                          title: loc?.appNotifications ?? 'Thông báo ứng dụng',
                          subtitle: loc?.appNotificationsSub ?? 'Bật nhận tất cả thông báo đẩy',
                          value: _pushNotifications,
                          onChanged: (val) => _updateSettings(push: val),
                          iconBgColor: iconBgColor,
                          iconColor: iconColor,
                          itemTextColor: itemTextColor,
                          itemSubtextColor: itemSubtextColor,
                        ),
                        _buildDivider(isDark),
                        _buildSwitchTile(
                          icon: Icons.shopping_bag_rounded,
                          title: loc?.weeklyShoppingReminder ?? 'Nhắc đi chợ hàng tuần',
                          subtitle: loc?.weeklyShoppingReminderSub ?? 'Cảnh báo chuẩn bị thực phẩm tuần tới',
                          value: _shoppingReminder,
                          onChanged: (val) => _updateSettings(shopping: val),
                          iconBgColor: iconBgColor,
                          iconColor: iconColor,
                          itemTextColor: itemTextColor,
                          itemSubtextColor: itemSubtextColor,
                        ),
                        _buildDivider(isDark),
                        _buildSwitchTile(
                          icon: Icons.access_time_filled_rounded,
                          title: loc?.expiryAlert ?? 'Cảnh báo hết hạn thực phẩm',
                          subtitle: loc?.expiryAlertSub ?? 'Thông báo trước 2 ngày khi hết hạn',
                          value: _expiryAlert,
                          onChanged: (val) => _updateSettings(expiry: val),
                          iconBgColor: iconBgColor,
                          iconColor: iconColor,
                          itemTextColor: itemTextColor,
                          itemSubtextColor: itemSubtextColor,
                        ),
                      ]),

                      SizedBox(height: 20.h),

                      // Section 2: Appearance & Dark Mode
                      _buildSectionTitle(
                        loc?.appearanceDarkMode ?? 'Giao diện & Chế độ tối',
                        titleColor,
                      ),
                      SizedBox(height: 8.h),
                      _buildCard(cardBg, cardBorder, [
                        _buildSwitchTile(
                          icon: Icons.dark_mode_rounded,
                          title: loc?.darkMode ?? 'Chế độ tối (Dark Mode)',
                          subtitle: isDark
                              ? (loc?.darkModeOn ?? 'Đang bật (Giao diện tối)')
                              : (loc?.darkModeOff ?? 'Đang tắt (Giao diện sáng)'),
                          value: isDark,
                          onChanged: (val) {
                            themeProvider.toggleDarkMode(val);
                          },
                          iconBgColor: iconBgColor,
                          iconColor: iconColor,
                          itemTextColor: itemTextColor,
                          itemSubtextColor: itemSubtextColor,
                        ),
                      ]),

                      SizedBox(height: 20.h),

                      // Section 3: Language
                      _buildSectionTitle(loc?.language ?? 'Ngôn ngữ', titleColor),
                      SizedBox(height: 8.h),
                      _buildCard(cardBg, cardBorder, [
                        ListTile(
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16.w, vertical: 4.h),
                          leading: Container(
                            padding: EdgeInsets.all(10.w),
                            decoration: BoxDecoration(
                              color: iconBgColor,
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                            child: Icon(
                              Icons.language_rounded,
                              color: iconColor,
                              size: 22,
                            ),
                          ),
                          title: Text(
                            loc?.appLanguage ?? 'Ngôn ngữ ứng dụng',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                              color: itemTextColor,
                            ),
                          ),
                          subtitle: Text(
                            languageProvider.currentLanguageName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.sp,
                              color: isDark
                                  ? const Color(0xFF81C784)
                                  : const Color(0xFF558B2F),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12.w, vertical: 6.h),
                            decoration: BoxDecoration(
                              color: iconBgColor,
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Text(
                              loc?.change ?? 'Đổi',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w800,
                                color: iconColor,
                              ),
                            ),
                          ),
                          onTap: () => _showLanguageSelectionModal(context, isDark),
                        ),
                      ]),

                      SizedBox(height: 24.h),
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

  Widget _buildSectionTitle(String title, Color color) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 16.sp,
        fontWeight: FontWeight.w900,
        color: color,
      ),
    );
  }

  Widget _buildCard(Color bg, Color borderColor, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      height: 1,
      color: isDark ? const Color(0xFF253B2D) : const Color(0xFFE8F5E9),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color iconBgColor,
    required Color iconColor,
    required Color itemTextColor,
    required Color itemSubtextColor,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      onTap: () => onChanged(!value),
      leading: Container(
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: iconBgColor,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15.sp,
          fontWeight: FontWeight.w700,
          color: itemTextColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12.5.sp,
          color: itemSubtextColor,
        ),
      ),
      trailing: Switch(
        value: value,
        activeTrackColor: const Color(0xFF4CAF50),
        onChanged: onChanged,
      ),
    );
  }
}
