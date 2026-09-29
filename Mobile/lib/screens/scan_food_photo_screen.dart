import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../data/services/api_service.dart';
import '../data/models/fridge_models.dart';
import '../widgets/scan_result_review_modal.dart';
import '../l10n/app_localizations.dart';

class ScanFoodPhotoScreen extends StatefulWidget {
  const ScanFoodPhotoScreen({super.key});

  @override
  State<ScanFoodPhotoScreen> createState() => _ScanFoodPhotoScreenState();
}

class _ScanFoodPhotoScreenState extends State<ScanFoodPhotoScreen> {
  final ImagePicker _picker = ImagePicker();
  final ApiService _apiService = ApiService();
  File? _capturedImage;
  bool _isFlashOn = false;
  bool _isAnalyzing = false;

  Future<void> _takePhotoWithCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
      );
      if (photo != null) {
        final file = File(photo.path);
        setState(() {
          _capturedImage = file;
        });
        await _processScan(file);
      }
    } catch (e) {
      debugPrint('Take picture error: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      if (image != null) {
        final file = File(image.path);
        setState(() {
          _capturedImage = file;
        });
        await _processScan(file);
      }
    } catch (e) {
      debugPrint('Pick gallery error: $e');
    }
  }

  Future<void> _processScan(File file) async {
    setState(() => _isAnalyzing = true);
    try {
      final scanRes = await _apiService.scanFoodImage(file.path);
      final scanId = scanRes['scanId'] as String? ?? '';
      String status = scanRes['status'] as String? ?? 'pending';

      // Poll status every 2 seconds if pending
      int attempts = 0;
      Map<String, dynamic> statusRes = scanRes;
      while ((status == 'pending' || status == 'processing') && attempts < 10) {
        await Future.delayed(const Duration(seconds: 2));
        attempts++;
        if (scanId.isNotEmpty) {
          statusRes = await _apiService.getScanStatus(scanId);
          status = statusRes['status'] as String? ?? 'done';
        }
      }

      if (!mounted) return;
      setState(() => _isAnalyzing = false);

      final statusModel = ScanStatusModel.fromJson(statusRes);
      final confirmSuccess = await ScanResultReviewModal.show(
        context,
        scanId: scanId,
        initialItems: statusModel.detectedItems,
      );

      if (confirmSuccess == true && mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Scan error: $e');
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
    }
  }



  void _toggleFlash() {
    setState(() => _isFlashOn = !_isFlashOn);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final isEn = loc?.locale.languageCode == 'en';

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
                    Color(0xFFE8F5E9),
                    Color(0xFFA5D6A7),
                    Color(0xFF81C784),
                  ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
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
                      isEn ? 'Take Food Photo' : 'Chụp Ảnh Thực Phẩm',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF19221C),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                        color: isDark ? Colors.white : const Color(0xFF19221C),
                      ),
                      onPressed: _toggleFlash,
                    ),
                  ],
                ),
              ),

              // Viewfinder
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
                            borderRadius: BorderRadius.circular(20.r),
                            border: isDark
                                ? Border.all(color: const Color(0xFF2E4D36), width: 1.5)
                                : null,
                          ),
                          child: _capturedImage != null
                              ? Image.file(
                                  _capturedImage!,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                )
                              : Image.asset(
                                  'assets/images/available_veggies.png',
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: isDark ? const Color(0xFF19271E) : const Color(0xFF1E3A23),
                                    child: Center(
                                      child: Icon(
                                        Icons.eco_rounded,
                                        size: 80,
                                        color: isDark ? const Color(0xFF81C784) : const Color(0xFF4CAF50),
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      if (_isAnalyzing)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: isDark ? const Color(0xFF81C784) : const Color(0xFF4CAF50),
                            ),
                          ),
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
                      onPressed: _pickFromGallery,
                    ),
                    GestureDetector(
                      onTap: _takePhotoWithCamera,
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
                          Icons.camera_alt_rounded,
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
      ),
    );
  }
}
