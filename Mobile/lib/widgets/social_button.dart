import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_theme.dart';

enum SocialType { google, apple }

class SocialButton extends StatelessWidget {
  final SocialType type;
  final VoidCallback onPressed;

  const SocialButton({
    super.key,
    required this.type,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isGoogle = type == SocialType.google;
    final label = isGoogle ? 'Google' : 'Apple';

    return Expanded(
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 16),
          backgroundColor: isDark ? const Color(0xFF19271E) : const Color(0xFFF2F5F3),
          foregroundColor: isDark ? Colors.white : AppColors.textPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28.r), // Pill shape
            side: BorderSide(
              color: isDark ? const Color(0xFF2E4D36) : Colors.transparent,
              width: 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            isGoogle
                ? _buildGoogleIcon()
                : Icon(
                    Icons.apple,
                    color: isDark ? Colors.white : AppColors.appleBlack,
                    size: 24,
                  ),
            SizedBox(width: 10.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleIcon() {
    return const SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(
        painter: _GoogleGLogoPainter(),
      ),
    );
  }
}

class _GoogleGLogoPainter extends CustomPainter {
  const _GoogleGLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double outerR = size.width / 2;
    final double innerR = size.width * 0.26;
    final Rect outerRect = Rect.fromCircle(center: Offset(cx, cy), radius: outerR);
    final Rect innerRect = Rect.fromCircle(center: Offset(cx, cy), radius: innerR);

    // Paints
    final Paint redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final Paint yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final Paint greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final Paint bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // 1. Red Top Arc (from -45° to 150° counter-clockwise)
    final Path redPath = Path();
    redPath.arcTo(outerRect, -0.785, -2.443, false); // -45° to -185°
    redPath.arcTo(innerRect, -0.785 - 2.443, 2.443, false);
    redPath.close();
    canvas.drawPath(redPath, redPaint);

    // 2. Yellow Left Arc (from 150° to 225° counter-clockwise)
    final Path yellowPath = Path();
    yellowPath.arcTo(outerRect, 2.356, 0.785, false); // 135° to 180°
    yellowPath.arcTo(innerRect, 3.141, -0.785, false);
    yellowPath.close();
    canvas.drawPath(yellowPath, yellowPaint);

    // 3. Green Bottom Arc (from 45° to 135° counter-clockwise)
    final Path greenPath = Path();
    greenPath.arcTo(outerRect, 0.45, 1.95, false); // 25° to 137°
    greenPath.arcTo(innerRect, 2.4, -1.95, false);
    greenPath.close();
    canvas.drawPath(greenPath, greenPaint);

    // 4. Blue Right Arc & Horizontal Bar
    final Path bluePath = Path();
    bluePath.arcTo(outerRect, -0.785, 1.25, false); // -45° to +25°
    // Draw horizontal bar extending from center right to outer right
    bluePath.lineTo(cx + outerR, cy);
    bluePath.lineTo(cx, cy);
    bluePath.lineTo(cx, cy - (outerR - innerR));
    bluePath.arcTo(innerRect, -0.785, 1.25, false);
    bluePath.close();
    canvas.drawPath(bluePath, bluePaint);

    // Precise Google G horizontal blue bar cutout fill
    final Rect barRect = Rect.fromLTRB(cx - 1, cy - (outerR - innerR) / 2, cx + outerR, cy + (outerR - innerR) / 2);
    canvas.drawRect(barRect, bluePaint);

    // Clear center hole
    final Paint holePaint = Paint()
      ..color = const Color(0xFFF2F5F3)
      ..style = PaintingStyle.fill;
    final Path holePath = Path();
    holePath.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: innerR));
    canvas.drawPath(holePath, holePaint);

    // Re-draw horizontal bar in blue
    final Rect centerBar = Rect.fromLTRB(cx, cy - (outerR - innerR) / 2.2, cx + outerR, cy + (outerR - innerR) / 2.2);
    canvas.drawRect(centerBar, bluePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
