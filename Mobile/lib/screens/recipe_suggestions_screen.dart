import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../widgets/cooking_suggestions_section.dart';
import '../widgets/friggy_app_bar.dart';

class RecipeSuggestionsScreen extends StatelessWidget {
  final List<String> availableIngredients;

  const RecipeSuggestionsScreen({
    super.key,
    this.availableIngredients = const ['Tomatoes', 'Bok Choy', 'Minced Pork'],
  });

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
                    Color(0xFFF1F8E9),
                    Colors.white,
                  ],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Friggy Top App Bar with back button
              const FriggyAppBar(
                showBackButton: true,
              ),

              SizedBox(height: 12.h),

              // Title Section
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn ? 'AI Recipe Suggestions' : 'Gợi Ý Món Ăn AI',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28.sp,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF006428),
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      isEn
                          ? 'Prioritizing expiring ingredients'
                          : 'Ưu tiên giải cứu nguyên liệu sắp hết hạn',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFF81C784)
                            : const Color(0xFF1B5E20),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16.h),

              // Reusable Cooking Suggestions Section (Exact same widget as Home Screen)
              Expanded(
                child: SingleChildScrollView(
                  physics: BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 16.0.w, vertical: 4.0.h),
                  child: CookingSuggestionsSection(
                    showHeaderTitle: false,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
