import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/services/api_service.dart';
import '../screens/notifications_screen.dart';

class FriggyAppBar extends StatefulWidget implements PreferredSizeWidget {
  final bool showBackButton;
  final VoidCallback? onBackTap;
  final VoidCallback? onNotificationTap;
  final bool hasUnreadNotifications;
  final int? unreadCount;
  final Color? backgroundColor;

  const FriggyAppBar({
    super.key,
    this.showBackButton = true,
    this.onBackTap,
    this.onNotificationTap,
    this.hasUnreadNotifications = true,
    this.unreadCount,
    this.backgroundColor,
  });

  @override
  State<FriggyAppBar> createState() => _FriggyAppBarState();

  @override
  Size get preferredSize => Size.fromHeight(60.h);
}

class _FriggyAppBarState extends State<FriggyAppBar> {
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _fetchUnreadCount();
  }

  @override
  void didUpdateWidget(covariant FriggyAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.unreadCount != null) {
      ApiService.updateUnreadCount(widget.unreadCount!);
    } else {
      _fetchUnreadCount();
    }
  }

  Future<void> _fetchUnreadCount() async {
    await _apiService.getUnreadNotificationCount();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: widget.backgroundColor ?? Colors.transparent,
      padding: EdgeInsets.symmetric(
        horizontal: widget.showBackButton ? 16.w : 0.0,
        vertical: 4.h,
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left Side: Optional Back Button + Friggy Logo
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.showBackButton) ...[
                  IconButton(
                    icon: Icon(
                      Icons.chevron_left_rounded,
                      size: 32.sp,
                      color: isDark ? Colors.white : const Color(0xFF19221C),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(
                      minWidth: 36.w,
                      minHeight: 36.h,
                    ),
                    onPressed: () {
                      if (widget.onBackTap != null) {
                        widget.onBackTap!();
                      } else {
                        Navigator.maybePop(context);
                      }
                    },
                  ),
                  SizedBox(width: 4.w),
                ],

                // Friggy Brand Logo with Leaf Badge
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 28.sp,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
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
                    SizedBox(width: 5.w),
                    Container(
                      padding: EdgeInsets.all(4.5.w),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF81C784) : const Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.eco_rounded,
                        color: isDark ? const Color(0xFF0E1611) : Colors.white,
                        size: 14.sp,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Right Side: Notification Icon with Green Unread Count Badge
            GestureDetector(
              onTap: () async {
                if (widget.onNotificationTap != null) {
                  await Future.sync(() => widget.onNotificationTap!());
                } else {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationsScreen(),
                    ),
                  );
                }
                await _fetchUnreadCount();
              },
              child: Container(
                width: 42.w,
                height: 42.w,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF19271E) : Colors.white,
                  shape: BoxShape.circle,
                  border: isDark
                      ? Border.all(color: const Color(0xFF2E4D36), width: 1.2)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ValueListenableBuilder<int>(
                  valueListenable: ApiService.unreadCountNotifier,
                  builder: (context, count, child) {
                    final displayUnreadCount = widget.unreadCount ?? count;

                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none_rounded,
                          color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
                          size: 22.sp,
                        ),
                        if (widget.hasUnreadNotifications && displayUnreadCount > 0)
                          Positioned(
                            top: 3.h,
                            right: 3.w,
                            child: Container(
                              padding: EdgeInsets.all(2.w),
                              decoration: BoxDecoration(
                                color: const Color(0xFF008435),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark ? const Color(0xFF19271E) : Colors.white,
                                  width: 1.5,
                                ),
                              ),
                              constraints: BoxConstraints(
                                minWidth: 16.w,
                                minHeight: 16.w,
                              ),
                              child: Center(
                                child: Text(
                                  '$displayUnreadCount',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 8.5.sp,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
