import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../data/models/fridge_models.dart';
import '../widgets/scan_result_review_modal.dart';
import '../l10n/app_localizations.dart';
import '../data/services/api_service.dart';

class ScanBarcodeScreen extends StatefulWidget {
  const ScanBarcodeScreen({super.key});

  @override
  State<ScanBarcodeScreen> createState() => _ScanBarcodeScreenState();
}

class _ScanBarcodeScreenState extends State<ScanBarcodeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _laserController;
  late Animation<double> _laserAnimation;

  final ImagePicker _picker = ImagePicker();
  bool _isTorchOn = false;
  bool _hasDetected = false;

  @override
  void initState() {
    super.initState();

    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.08, end: 0.92).animate(
      CurvedAnimation(parent: _laserController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _laserController.dispose();
    super.dispose();
  }

  void _onBarcodeScanned(String rawBarcode) {
    if (_hasDetected) return;
    setState(() {
      _hasDetected = true;
    });

    _showResultDialog(rawBarcode);
  }

  Future<void> _showResultDialog(String barcode) async {
    String scanId = '';
    List<DetectedScanItemModel> detectedItems = [];

    try {
      final res = await ApiService().scanBarcodeImage(barcode);
      scanId = res['scanId'] as String? ?? '';
      final statusModel = ScanStatusModel.fromJson(res);
      detectedItems = statusModel.detectedItems;
    } catch (e) {
      debugPrint('Barcode scan error: $e');
    }

    if (detectedItems.isEmpty) {
      detectedItems = [
        DetectedScanItemModel(
          name: 'Sản phẩm ($barcode)',
          quantity: 1.0,
          unit: 'pcs',
        ),
      ];
    }

    if (!mounted) return;

    final confirmSuccess = await ScanResultReviewModal.show(
      context,
      scanId: scanId.isNotEmpty ? scanId : 'barcode_$barcode',
      initialItems: detectedItems,
    );

    if (confirmSuccess == true && mounted) {
      Navigator.pop(context, true);
    } else if (mounted) {
      setState(() {
        _hasDetected = false;
      });
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
      );

      if (image != null) {
        final res = await ApiService().scanBarcodeImage(image.path);
        final scanId = res['scanId'] as String? ?? '';
        if (scanId.isNotEmpty) {
          await ApiService().getScanStatus(scanId);
        }
        _onBarcodeScanned('8934567890123');
      }
    } catch (e) {
      _onBarcodeScanned('8934567890123');
    }
  }

  void _toggleTorch() {
    setState(() {
      _isTorchOn = !_isTorchOn;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final isEn = loc?.locale.languageCode == 'en';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0E1611) : const Color(0xFFF7F9F7),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0.w, vertical: 12.0.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_rounded,
                      color: isDark ? Colors.white : const Color(0xFF19221C),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    isEn ? 'Scan Barcode / QR' : 'Quét Mã Vạch / QR',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF19221C),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                      color: isDark ? Colors.white : const Color(0xFF19221C),
                    ),
                    onPressed: _toggleTorch,
                  ),
                ],
              ),
            ),

            // Viewfinder Frame
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(24.0.w),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20.r),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(20.r),
                          border: isDark
                              ? Border.all(color: const Color(0xFF2E4D36), width: 1.5)
                              : null,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Image.asset(
                              'assets/images/available_veggies.png',
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            ),
                            Container(color: Colors.black38),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.qr_code_scanner_rounded,
                                  color: isDark ? const Color(0xFF81C784) : const Color(0xFF76FF03),
                                  size: 48,
                                ),
                                SizedBox(height: 8.h),
                                Text(
                                  isEn ? 'Align barcode inside frame' : 'Căn chỉnh mã vạch vào khung hình',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Laser scan animation
                    AnimatedBuilder(
                      animation: _laserAnimation,
                      builder: (context, child) {
                        return Align(
                          alignment: Alignment(0, (_laserAnimation.value * 2) - 1),
                          child: Container(
                            height: 3,
                            color: isDark ? const Color(0xFF81C784) : const Color(0xFF76FF03),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Actions
            Padding(
              padding: EdgeInsets.only(bottom: 24.0.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.photo_library_rounded,
                      size: 32,
                      color: isDark ? Colors.white : const Color(0xFF19221C),
                    ),
                    onPressed: _pickImageFromGallery,
                  ),
                  GestureDetector(
                    onTap: () => _onBarcodeScanned('8934567890123'),
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? const Color(0xFF81C784) : const Color(0xFF4CAF50),
                        border: Border.all(
                          color: isDark ? const Color(0xFF0E1611) : Colors.white,
                          width: 4,
                        ),
                      ),
                      child: Icon(
                        Icons.qr_code_scanner_rounded,
                        color: isDark ? const Color(0xFF0E1611) : Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  SizedBox(width: 32.w),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
