import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';

import '../data/models/user_models.dart';
import '../data/services/api_service.dart';

class NotificationItem {
  final String id;
  final String title;
  final String titleEn;
  final String message;
  final String messageEn;
  final String time;
  final String timeEn;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String category;
  final String categoryEn;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.titleEn,
    required this.message,
    required this.messageEn,
    required this.time,
    required this.timeEn,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.category,
    required this.categoryEn,
    this.isRead = false,
  });

  String displayTitle(bool isEn) => isEn ? titleEn : title;
  String displayMessage(bool isEn) => isEn ? messageEn : message;
  String displayTime(bool isEn) => isEn ? timeEn : time;
  String displayCategory(bool isEn) => isEn ? categoryEn : category;
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiService _apiService = ApiService();
  String _selectedCategoryKey = 'All';
  bool _isLoading = true;
  bool _showAll = false;

  final List<NotificationItem> _notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.getNotifications(page: 1, limit: 50);
      if (res.containsKey('data') && res['data'] is List) {
        final rawList = res['data'] as List;
        if (rawList.isNotEmpty) {
          final models = rawList
              .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
              .toList();
          final items = models.map((m) => _mapModelToItem(m)).toList();
          final unread = items.where((i) => !i.isRead).length;
          ApiService.updateUnreadCount(unread);
          if (mounted) {
            setState(() {
              _notifications.clear();
              _notifications.addAll(items);
              _isLoading = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('[NotificationsScreen] Error fetching notifications: $e');
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  NotificationItem _mapModelToItem(NotificationModel m) {
    IconData icon;
    Color iconColor;
    Color iconBgColor;
    String category;
    String categoryEn;

    switch (m.type) {
      case 'expiry_warning':
        icon = Icons.timer_rounded;
        iconColor = const Color(0xFF008435);
        iconBgColor = const Color(0xFFE8F5E9);
        category = 'Hết hạn';
        categoryEn = 'Expired';
        break;
      case 'shopping':
      case 'shopping_reminder':
      case 'plan_ready':
        icon = Icons.shopping_cart_rounded;
        iconColor = const Color(0xFF4CAF50);
        iconBgColor = const Color(0xFFE8F5E9);
        category = 'Nhắc đi chợ';
        categoryEn = 'Shopping';
        break;
      case 'promo':
        icon = Icons.local_offer_rounded;
        iconColor = const Color(0xFF9C27B0);
        iconBgColor = const Color(0xFFF3E5F5);
        category = 'Khuyến mãi';
        categoryEn = 'Promo';
        break;
      case 'budget_alert':
        icon = Icons.monetization_on_rounded;
        iconColor = const Color(0xFFFF9800);
        iconBgColor = const Color(0xFFFFF3E0);
        category = 'Ngân sách';
        categoryEn = 'Budget';
        break;
      default:
        icon = Icons.workspace_premium_rounded;
        iconColor = const Color(0xFF008435);
        iconBgColor = const Color(0xFFE8F5E9);
        category = 'Hệ thống';
        categoryEn = 'System';
    }

    return NotificationItem(
      id: m.id,
      title: m.title,
      titleEn: m.title,
      message: m.body,
      messageEn: m.body,
      time: _formatTimeString(m.createdAt),
      timeEn: _formatTimeString(m.createdAt),
      icon: icon,
      iconColor: iconColor,
      iconBgColor: iconBgColor,
      category: category,
      categoryEn: categoryEn,
      isRead: m.isRead,
    );
  }

  String _formatTimeString(String dateStr) {
    if (dateStr.isEmpty) return 'Vừa xong';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) {
        return '${diff.inMinutes <= 0 ? 1 : diff.inMinutes} phút trước';
      } else if (diff.inHours < 24) {
        return '${diff.inHours} giờ trước';
      } else if (diff.inDays < 7) {
        return '${diff.inDays} ngày trước';
      } else {
        return '${dt.day}/${dt.month}/${dt.year}';
      }
    } catch (_) {}
    return dateStr;
  }

  Future<void> _markAllAsRead(bool isEn) async {
    setState(() {
      for (var item in _notifications) {
        item.isRead = true;
      }
    });
    ApiService.updateUnreadCount(0);

    try {
      await _apiService.markAllNotificationsRead();
    } catch (e) {
      debugPrint('[NotificationsScreen] Error marking all read: $e');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEn ? 'Marked all notifications as read' : 'Đã đánh dấu tất cả thông báo là đã đọc',
          ),
          backgroundColor: const Color(0xFF008435),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _toggleRead(NotificationItem item) async {
    final previousState = item.isRead;
    setState(() {
      item.isRead = !item.isRead;
    });

    final newUnreadCount = _notifications.where((i) => !i.isRead).length;
    ApiService.updateUnreadCount(newUnreadCount);

    if (!previousState) {
      try {
        await _apiService.markNotificationRead(item.id);
      } catch (e) {
        debugPrint('[NotificationsScreen] Error marking read: $e');
      }
    }
  }

  Future<void> _deleteNotification(String id) async {
    setState(() {
      _notifications.removeWhere((item) => item.id == id);
    });

    final newUnreadCount = _notifications.where((i) => !i.isRead).length;
    ApiService.updateUnreadCount(newUnreadCount);

    try {
      await _apiService.deleteNotification(id);
    } catch (e) {
      debugPrint('[NotificationsScreen] Error deleting notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final isEn = loc?.locale.languageCode == 'en';

    final categories = [
      {'key': 'All', 'label': isEn ? 'All' : 'Tất cả'},
      {'key': 'Expired', 'label': isEn ? 'Expired' : 'Hết hạn'},
      {'key': 'Shopping', 'label': isEn ? 'Shopping' : 'Nhắc đi chợ'},
      {'key': 'System', 'label': isEn ? 'System' : 'Hệ thống'},
    ];

    final filteredList = _selectedCategoryKey == 'All'
        ? _notifications
        : _notifications
            .where((item) =>
                item.categoryEn == _selectedCategoryKey ||
                item.category == _selectedCategoryKey)
            .toList();

    final unreadCount = _notifications.where((item) => !item.isRead).length;

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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
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
                                color: isDark
                                    ? const Color(0xFF2E4D36)
                                    : const Color(0xFFA5E69C),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.arrow_back_rounded,
                              color: isDark ? Colors.white : const Color(0xFF006428),
                              size: 20,
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Text(
                          isEn ? 'Notifications' : 'Thông báo',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF006428),
                          ),
                        ),
                      ],
                    ),

                    // Mark all read button
                    if (unreadCount > 0)
                      GestureDetector(
                        onTap: () => _markAllAsRead(isEn),
                        child: Text(
                          isEn ? 'Mark all as read' : 'Đã đọc tất cả',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFF81C784) : const Color(0xFF006428),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              SizedBox(height: 10.h),

              // Categories Filter Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: categories.map((catObj) {
                    final catKey = catObj['key']!;
                    final catLabel = catObj['label']!;
                    final isSelected = _selectedCategoryKey == catKey;

                    return Padding(
                      padding: EdgeInsets.only(right: 8.0.w),
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedCategoryKey = catKey;
                          _showAll = false;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF008435)
                                : (isDark ? const Color(0xFF19271E) : Colors.white),
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF008435)
                                  : (isDark ? const Color(0xFF2E4D36) : const Color(0xFFA5E69C)),
                              width: 1.2,
                            ),
                          ),
                          child: Text(
                            catLabel,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? Colors.white : const Color(0xFF006428)),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              SizedBox(height: 14.h),

              // Notification List view
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Color(0xFF008435)),
                      )
                    : filteredList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(20.w),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF233629)
                                    : const Color(0xFFE8F5E9),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.notifications_off_rounded,
                                size: 48,
                                color: isDark
                                    ? const Color(0xFF81C784)
                                    : const Color(0xFF4CAF50),
                              ),
                            ),
                            SizedBox(height: 14.h),
                            Text(
                              isEn ? 'No Notifications' : 'Không có thông báo nào',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF006428),
                              ),
                            ),
                            Text(
                              isEn
                                  ? 'You are all caught up with the latest updates!'
                                  : 'Bạn đã cập nhật tất cả thông tin mới nhất!',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.sp,
                                color: isDark
                                    ? const Color(0xFF9DA8A0)
                                    : const Color(0xFF757575),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Builder(
                        builder: (context) {
                          final showExpandButton = filteredList.length > 4 && !_showAll;
                          final displayList = showExpandButton ? filteredList.take(4).toList() : filteredList;

                          return ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            itemCount: displayList.length + (showExpandButton ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (showExpandButton && index == displayList.length) {
                                return Padding(
                                  padding: EdgeInsets.only(top: 4.0.h, bottom: 28.0.h),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _showAll = true;
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(22.r),
                                      child: Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 16,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF19271E) : Colors.white,
                                          borderRadius: BorderRadius.circular(22.r),
                                          border: Border.all(
                                            color: isDark ? const Color(0xFF2E4D36) : const Color(0xFF008435),
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                                              blurRadius: 10,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              isEn
                                                  ? 'View all notifications (${filteredList.length})'
                                                  : 'Xem toàn bộ thông báo (${filteredList.length})',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 15.sp,
                                                fontWeight: FontWeight.w800,
                                                color: isDark ? const Color(0xFF81C784) : const Color(0xFF006428),
                                              ),
                                            ),
                                            SizedBox(width: 8.w),
                                            Icon(
                                              Icons.keyboard_arrow_down_rounded,
                                              size: 24,
                                              color: isDark ? const Color(0xFF81C784) : const Color(0xFF006428),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }

                              final item = displayList[index];
                              return Dismissible(
                                key: Key(item.id),
                                direction: DismissDirection.endToStart,
                                onDismissed: (_) => _deleteNotification(item.id),
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: EdgeInsets.only(right: 20.w),
                                  margin: EdgeInsets.only(bottom: 12.h),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE53935),
                                borderRadius: BorderRadius.circular(20.r),
                              ),
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            child: GestureDetector(
                              onTap: () => _toggleRead(item),
                              child: Container(
                                margin: EdgeInsets.only(bottom: 12.h),
                                padding: EdgeInsets.all(16.w),
                                decoration: BoxDecoration(
                                  color: item.isRead
                                      ? (isDark
                                          ? const Color(0xFF19271E)
                                          : Colors.white.withValues(alpha: 0.9))
                                      : (isDark
                                          ? const Color(0xFF233629)
                                          : const Color(0xFFF1F8E9)),
                                  borderRadius: BorderRadius.circular(22.r),
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF2E4D36)
                                        : (item.isRead
                                            ? const Color(0xFFE0E0E0)
                                            : const Color(0xFF4CAF50)),
                                    width: item.isRead ? 1 : 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black
                                          .withValues(alpha: isDark ? 0.2 : 0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Left Icon with Category Color
                                    Container(
                                      padding: EdgeInsets.all(10.w),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? item.iconBgColor.withValues(alpha: 0.2)
                                            : item.iconBgColor,
                                        borderRadius: BorderRadius.circular(16.r),
                                      ),
                                      child: Icon(
                                        item.icon,
                                        color: item.iconColor,
                                        size: 22,
                                      ),
                                    ),
                                    SizedBox(width: 14.w),

                                    // Content Text
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  item.displayTitle(isEn),
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 15.sp,
                                                    fontWeight: item.isRead
                                                        ? FontWeight.w700
                                                        : FontWeight.w900,
                                                    color: isDark
                                                        ? Colors.white
                                                        : const Color(0xFF006428),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 4.h),
                                          Text(
                                            item.displayMessage(isEn),
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 13.sp,
                                              fontWeight: item.isRead
                                                  ? FontWeight.w500
                                                  : FontWeight.w600,
                                              color: isDark
                                                  ? const Color(0xFFD0D7D1)
                                                  : const Color(0xFF19221C),
                                              height: 1.35,
                                            ),
                                          ),
                                          SizedBox(height: 8.h),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                item.displayTime(isEn),
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                  fontSize: 11.5.sp,
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      const Color(0xFF757575),
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFE8F5E9),
                                                  borderRadius:
                                                      BorderRadius.circular(10.r),
                                                ),
                                                child: Text(
                                                  item.displayCategory(isEn),
                                                  style:
                                                      GoogleFonts.plusJakartaSans(
                                                    fontSize: 11.sp,
                                                    fontWeight: FontWeight.w700,
                                                    color:
                                                        const Color(0xFF006428),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
