import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../utils/greeting_helper.dart';

class GreetingBanner extends StatelessWidget {
  final String userName;
  final DateTime? currentTime;

  const GreetingBanner({
    super.key,
    this.userName = 'Trần Quốc Lâm',
    this.currentTime,
  });

  @override
  Widget build(BuildContext context) {
    final now = currentTime ?? DateTime.now();
    final imageAsset = GreetingHelper.getGreetingAsset(now);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final isEn = loc?.locale.languageCode == 'en';

    final bannerColors = isDark
        ? const [
            Color(0xFF19271E),
            Color(0xFF1B2E21),
            Color(0xFF223A28),
            Color(0xFF2E4D36),
          ]
        : const [
            Color(0xFFFFFFFF),
            Color(0xFFF2FAF1),
            Color(0xFFB4ECAB),
            Color(0xFF7DD969),
          ];

    final textColorPrimary = isDark ? Colors.white : const Color(0xFF0D4314);
    final textColorSecondary = isDark ? const Color(0xFFA0B5A7) : const Color(0xFF1B5E20);

    return Container(
      width: double.infinity,
      height: 170.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26.r),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: bannerColors,
          stops: const [0.0, 0.48, 0.80, 1.0],
        ),
        border: Border.all(
          color: isDark
              ? const Color(0xFF2E4D36)
              : Colors.white.withValues(alpha: 0.7),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26.r),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Ambient light glow behind character
            Positioned(
              right: 10.w,
              top: 10.h,
              child: Container(
                width: 120.w,
                height: 120.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isDark ? Colors.white : Colors.white).withValues(alpha: isDark ? 0.08 : 0.35),
                ),
              ),
            ),

            // Transparent Mascot Character Asset on the right
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 148.w,
              child: Image.asset(
                imageAsset,
                fit: BoxFit.contain,
                alignment: Alignment.bottomRight,
                errorBuilder: (context, error, stackTrace) {
                  return Image.asset(
                    'assets/images/goodmorning-Photoroom.png',
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomRight,
                  );
                },
              ),
            ),

            // Left Side Text Overlay
            Positioned.fill(
              right: 140.w, // Leave room for mascot character
              child: Padding(
                padding: EdgeInsets.only(left: 16.w, top: 12.h, bottom: 12.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logged-in User Name
                    Text(
                      userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 32.sp,
                        fontWeight: FontWeight.w800,
                        color: textColorPrimary,
                        height: 1.1,
                      ),
                    ),
                    SizedBox(height: 6.h),

                    // Description
                    Expanded(
                      child: Text(
                        isEn
                            ? 'Friggy is ready to help you cook delicious meals & save food!'
                            : 'Friggy đã sẵn sàng giúp bạn nấu những món ăn ngon và tiết kiệm thực phẩm!',
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: textColorSecondary,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
