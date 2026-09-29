import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class CameraPreviewScreen extends StatefulWidget {
  const CameraPreviewScreen({super.key});

  @override
  State<CameraPreviewScreen> createState() => _CameraPreviewScreenState();
}

class _CameraPreviewScreenState extends State<CameraPreviewScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isFlashOn = false;
  bool _isFrontCamera = false;
  bool _isCapturing = false;

  Future<void> _takePhoto() async {
    setState(() {
      _isCapturing = true;
    });

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (!mounted) return;

      if (photo != null) {
        Navigator.pop(context, File(photo.path));
      } else {
        setState(() {
          _isCapturing = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      // Fallback demo food image for emulator
      Navigator.pop(context, 'assets/images/food_tomato.png');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Center Live Camera Area / Simulated viewfinder
            Center(
              child: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: Color(0xFF19221C),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(24.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.camera_alt_rounded,
                        color: Color(0xFF4CAF50),
                        size: 64,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'Camera Ống Kính Thực Tế',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      'Bấm nút bên dưới để chụp ảnh gửi vào cuộc trò chuyện',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.sp,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            // Top Header: Close X Button & Flash Toggle
            Positioned(
              top: 16.h,
              left: 16.w,
              right: 16.w,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // ✕ Close / Exit Camera Mode Button
                  GestureDetector(
                    onTap: () => Navigator.pop(context, null),
                    child: Container(
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 1),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),

                  // Flash Light Button
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isFlashOn = !_isFlashOn;
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 1),
                      ),
                      child: Icon(
                        _isFlashOn
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                        color: _isFlashOn
                            ? const Color(0xFFFFD600)
                            : Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Shutter Action Bar
            Positioned(
              bottom: 30.h,
              left: 0.w,
              right: 0.w,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Exit Text / Hint
                      IconButton(
                        icon: Icon(
                          Icons.photo_library_outlined,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () => Navigator.pop(context, 'GALLERY'),
                      ),

                      // 📷 Big Outer Ring Capture Button
                      GestureDetector(
                        onTap: _isCapturing ? null : _takePhoto,
                        child: Container(
                          width: 76,
                          height: 76,
                          padding: EdgeInsets.all(4.w),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF4CAF50),
                              width: 4,
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: _isCapturing
                                ? Padding(
                                    padding: EdgeInsets.all(16.0.w),
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF4CAF50),
                                      strokeWidth: 3,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),

                      // Flip Camera Button
                      IconButton(
                        icon: Icon(
                          Icons.flip_camera_ios_outlined,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () {
                          setState(() {
                            _isFrontCamera = !_isFrontCamera;
                          });
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Chạm nút tròn để chụp • Chạm ✕ góc trên để thoát',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
