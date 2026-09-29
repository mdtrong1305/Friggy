import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';

class CustomBottomNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;

  const CustomBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  // Deep Forest Green Accent Color
  static const Color accentColor = Color(0xFF0F5A24);

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    final navBg = isDark
        ? const Color(0xFF142419).withValues(alpha: 0.90)
        : Colors.white.withValues(alpha: 0.15);
    final navBorder = isDark
        ? const Color(0xFF2E4D36).withValues(alpha: 0.8)
        : Colors.white.withValues(alpha: 0.25);

    return Padding(
      padding: EdgeInsets.only(
        left: 16.w,
        right: 16.w,
        bottom: bottomInset > 0 ? bottomInset + 4 : 16.h,
      ),
      child: Container(
        height: 62.h,
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        decoration: BoxDecoration(
          color: navBg,
          borderRadius: BorderRadius.circular(32.r),
          border: Border.all(
            color: navBorder,
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 16,
              spreadRadius: 0,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Tab 0: Home
            _buildTabItem(
              context: context,
              index: 0,
              iconWidget: (color) => Icon(
                Icons.home_rounded,
                size: 26,
                color: color,
              ),
              label: loc?.home ?? 'Trang chủ',
            ),

            // Tab 1: Fridge (Realistic Solid Dual-Door Fridge Icon)
            _buildTabItem(
              context: context,
              index: 1,
              iconWidget: (color) => FridgeIcon(
                size: 24,
                color: color,
              ),
              label: loc?.myFridges ?? 'Tủ lạnh',
            ),

            // Tab 2: Fixed Deep Green Add Button (Enlarged 56x56, NO white border ring!)
            _buildFixedAddButton(),

            // Tab 3: AI Chat (Đầu bếp AI)
            _buildTabItem(
              context: context,
              index: 3,
              iconWidget: (color) => Icon(
                Icons.smart_toy_rounded,
                size: 25,
                color: color,
              ),
              label: 'Đầu bếp AI',
            ),

            // Tab 4: Profile
            _buildTabItem(
              context: context,
              index: 4,
              iconWidget: (color) => Icon(
                Icons.person_rounded,
                size: 26,
                color: color,
              ),
              label: loc?.profile ?? 'Tài khoản',
            ),
          ],
        ),
      ),
    );
  }

  // Fixed Deep Green Add Action Button (Enlarged 56x56, NO white border ring)
  Widget _buildFixedAddButton() {
    final isSelected = selectedIndex == 2;

    return InkWell(
      onTap: () => onItemTapped(2),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 200),
        scale: isSelected ? 1.08 : 1.0,
        child: Container(
          width: 54.w,
          height: 54.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accentColor,
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.35),
                blurRadius: 10,
                spreadRadius: 1,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            Icons.add_rounded,
            color: Colors.white,
            size: 32.sp,
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required BuildContext context,
    required int index,
    required Widget Function(Color color) iconWidget,
    required String label,
  }) {
    final isSelected = selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final selectedColor = isDark ? const Color(0xFF81C784) : accentColor;
    final unselectedColor = isDark ? const Color(0xFF9DA8A0) : Colors.white.withValues(alpha: 0.85);
    final iconColor = isSelected ? selectedColor : unselectedColor;

    return InkWell(
      onTap: () => onItemTapped(index),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 200),
              scale: isSelected ? 1.10 : 1.0,
              child: iconWidget(iconColor),
            ),
            SizedBox(height: 3.h),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.sp,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: iconColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Realistic Solid Dual-Door Refrigerator Vector Icon
class FridgeIcon extends StatelessWidget {
  final double size;
  final Color color;

  const FridgeIcon({
    super.key,
    this.size = 24,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 1.15,
      child: CustomPaint(
        painter: _FridgePainter(color: color),
      ),
    );
  }
}

class _FridgePainter extends CustomPainter {
  final Color color;

  _FridgePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // Top Freezer Door
    final topDoorRect = RRect.fromRectAndCorners(
      Rect.fromLTRB(1.5, 0, w - 1.5, h * 0.38),
      topLeft: Radius.circular(5.r),
      topRight: Radius.circular(5.r),
      bottomLeft: Radius.circular(1.5.r),
      bottomRight: Radius.circular(1.5.r),
    );
    canvas.drawRRect(topDoorRect, paint);

    // Bottom Fridge Door
    final bottomDoorRect = RRect.fromRectAndCorners(
      Rect.fromLTRB(1.5, h * 0.42, w - 1.5, h - 3),
      topLeft: Radius.circular(1.5.r),
      topRight: Radius.circular(1.5.r),
      bottomLeft: Radius.circular(5.r),
      bottomRight: Radius.circular(5.r),
    );
    canvas.drawRRect(bottomDoorRect, paint);

    // Door Handles
    final handlePaint = Paint()
      ..color = color == CustomBottomNavigationBar.accentColor
          ? Colors.white
          : CustomBottomNavigationBar.accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    // Top Handle
    canvas.drawLine(
      Offset(w - 4.5, 4),
      Offset(w - 4.5, h * 0.30),
      handlePaint,
    );

    // Bottom Handle
    canvas.drawLine(
      Offset(w - 4.5, h * 0.48),
      Offset(w - 4.5, h * 0.74),
      handlePaint,
    );

    // Feet at bottom
    final footPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(4, h - 2), Offset(4, h), footPaint);
    canvas.drawLine(Offset(w - 4, h - 2), Offset(w - 4, h), footPaint);
  }

  @override
  bool shouldRepaint(covariant _FridgePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
