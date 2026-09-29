import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';

class SelectInputMethodScreen extends StatelessWidget {
  final Function(String methodId)? onMethodSelected;

  const SelectInputMethodScreen({
    super.key,
    this.onMethodSelected,
  });

  /// Helper static method to show this screen as a sleek Modal Bottom Sheet
  static Future<void> show(
    BuildContext context, {
    Function(String methodId)? onMethodSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SelectInputMethodScreen(
        onMethodSelected: onMethodSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final isEn = loc?.locale.languageCode == 'en';
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [
                  Color(0xFF19271E),
                  Color(0xFF142017),
                  Color(0xFF0E1611),
                ]
              : const [
                  Color(0xFFE8F5E9),
                  Color(0xFFA5D6A7),
                  Color(0xFF81C784),
                ],
          stops: isDark ? const [0.0, 0.5, 1.0] : const [0.0, 0.6, 1.0],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
        border: isDark
            ? const Border(
                top: BorderSide(color: Color(0xFF2E4D36), width: 1.2),
              )
            : null,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 20.0.w,
            right: 20.0.w,
            top: 16.0.h,
            bottom: bottomPadding > 0 ? bottomPadding + 12 : 24.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Drag Handle Bar
              Center(
                child: Container(
                  width: 42,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2E4D36)
                        : const Color(0xFF2E7D32).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
              ),

              SizedBox(height: 20.h),

              // Title
              Text(
                isEn ? 'Select Input Method' : 'Chọn Phương Thức Nhập',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 27.sp,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF006428),
                  letterSpacing: -0.2,
                ),
              ),

              SizedBox(height: 8.h),

              // Subtitle
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  isEn
                      ? 'Choose the most convenient way to add food to your fridge.'
                      : 'Chọn phương thức thuận tiện nhất để thêm thực phẩm vào tủ.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFFD0D7D1) : const Color(0xFF1B5E20),
                    height: 1.35,
                  ),
                ),
              ),

              SizedBox(height: 24.h),

              // 4 Input Method Cards
              // 1. Manual Entry
              _buildMethodCard(
                context: context,
                id: 'manual',
                title: isEn ? 'Manual Input' : 'Nhập Thủ Công',
                subtitle: isEn ? 'Enter food details manually' : 'Tự nhập thông tin nguyên liệu',
                icon: Icons.edit_note_rounded,
                iconColor: isDark ? const Color(0xFF80CBC4) : const Color(0xFF00695C),
                iconBgColor: isDark ? const Color(0xFF163832) : const Color(0xFFE0F2F1),
              ),

              SizedBox(height: 14.h),

              // 2. Scan Food Photo
              _buildMethodCard(
                context: context,
                id: 'scan_photo',
                title: isEn ? 'Scan Food Photo' : 'Chụp Ảnh Thực Phẩm',
                subtitle: isEn ? 'Take a photo for AI recognition' : 'Chụp ảnh để AI tự nhận diện món ăn',
                icon: Icons.camera_alt_outlined,
                iconColor: isDark ? const Color(0xFFFFB74D) : const Color(0xFFB76E00),
                iconBgColor: isDark ? const Color(0xFF3E2C17) : const Color(0xFFFFF3E0),
              ),

              SizedBox(height: 14.h),

              // 3. Scan Receipt
              _buildMethodCard(
                context: context,
                id: 'scan_receipt',
                title: isEn ? 'Scan Receipt' : 'Quét Hóa Đơn',
                subtitle: isEn ? 'Scan grocery receipts quickly' : 'Quét hóa đơn mua sắm để nhập nhanh',
                icon: Icons.receipt_long_rounded,
                iconColor: isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20),
                iconBgColor: isDark ? const Color(0xFF233629) : const Color(0xFFE8F5E9),
              ),

              SizedBox(height: 14.h),

              // 4. Scan Barcode / QR
              _buildMethodCard(
                context: context,
                id: 'scan_barcode',
                title: isEn ? 'Scan Barcode / QR' : 'Quét Mã Vạch / QR',
                subtitle: isEn ? 'Scan barcode or QR on package' : 'Quét mã vạch hoặc mã QR trên bao bì',
                icon: Icons.qr_code_scanner_rounded,
                iconColor: isDark ? const Color(0xFFE57373) : const Color(0xFFC62828),
                iconBgColor: isDark ? const Color(0xFF3E1D22) : const Color(0xFFFFEBEE),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMethodCard({
    required BuildContext context,
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onMethodSelected?.call(id);
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF19271E) : Colors.white,
          borderRadius: BorderRadius.circular(22.r),
          border: isDark
              ? Border.all(color: const Color(0xFF2E4D36), width: 1.2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left Custom Square Icon Container
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 28,
              ),
            ),

            SizedBox(width: 16.w),

            // Center Title & Subtitle Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF00752B),
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF81C784) : const Color(0xFF55A44B),
                    ),
                  ),
                ],
              ),
            ),

            // Right Chevron Arrow
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white : const Color(0xFF333333),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
