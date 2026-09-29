import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/services/api_service.dart';
import '../l10n/app_localizations.dart';
import 'home_screen.dart';

class OnboardingSurveyScreen extends StatefulWidget {
  const OnboardingSurveyScreen({super.key});

  @override
  State<OnboardingSurveyScreen> createState() => _OnboardingSurveyScreenState();
}

class _OnboardingSurveyScreenState extends State<OnboardingSurveyScreen> {
  final ApiService _apiService = ApiService();
  final PageController _pageController = PageController();

  int _currentStep = 0;
  bool _isSubmitting = false;

  // Survey Data matching BE OnboardingDto
  String _primaryGoal = 'save_money';
  String _cookingFrequency = 'daily';
  String _dietaryStyle = 'omnivore';
  String _activityLevel = 'moderate';
  int _householdSize = 2;
  final TextEditingController _heightController = TextEditingController(text: '170');
  final TextEditingController _weightController = TextEditingController(text: '65');

  // Allergy Data
  List<dynamic> _availableIngredients = [];
  List<dynamic> _searchedIngredients = [];
  final List<Map<String, dynamic>> _selectedAllergies = [];
  bool _isLoadingIngredients = false;
  final TextEditingController _allergySearchController = TextEditingController();
  Timer? _allergySearchDebounce;

  @override
  void initState() {
    super.initState();
    _fetchIngredients();
  }

  Future<void> _fetchIngredients({String search = ''}) async {
    if (!mounted) return;
    setState(() => _isLoadingIngredients = true);
    try {
      final list = await _apiService.getIngredients(search: search.isEmpty ? null : search, limit: 60);
      if (mounted) {
        setState(() {
          _searchedIngredients = list;
          if (search.isEmpty) {
            _availableIngredients = list;
          }
        });
      }
    } catch (e) {
      debugPrint('[OnboardingSurveyScreen] Error fetching ingredients: $e');
    } finally {
      if (mounted) setState(() => _isLoadingIngredients = false);
    }
  }

  void _onAllergySearchChanged(String query) {
    _allergySearchDebounce?.cancel();
    final q = query.trim();
    if (q.isEmpty) {
      setState(() => _searchedIngredients = _availableIngredients);
      return;
    }
    _allergySearchDebounce = Timer(const Duration(milliseconds: 300), () {
      _fetchIngredients(search: q);
    });
  }

  void _toggleAllergyIngredient(int id, String name) {
    setState(() {
      final idx = _selectedAllergies.indexWhere((a) => a['id'] == id);
      if (idx >= 0) {
        _selectedAllergies.removeAt(idx);
      } else {
        _selectedAllergies.add({
          'id': id,
          'name': name,
          'note': null,
        });
      }
    });
  }

  Future<void> _toggleQuickTag(String keyword) async {
    final existingIdx = _selectedAllergies.indexWhere(
      (a) => (a['name'] as String).toLowerCase().contains(keyword.toLowerCase()),
    );

    if (existingIdx >= 0) {
      setState(() {
        _selectedAllergies.removeAt(existingIdx);
      });
      return;
    }

    dynamic match;
    for (final item in _availableIngredients) {
      final String itemName = (item['name'] as String? ?? '').toLowerCase();
      if (itemName.contains(keyword.toLowerCase())) {
        match = item;
        break;
      }
    }

    if (match != null) {
      _toggleAllergyIngredient(match['id'] as int, match['name'] as String? ?? keyword);
    } else {
      try {
        final results = await _apiService.getIngredients(search: keyword, limit: 5);
        if (results.isNotEmpty && mounted) {
          final first = results.first;
          _toggleAllergyIngredient(first['id'] as int, first['name'] as String? ?? keyword);
        }
      } catch (e) {
        debugPrint('[OnboardingSurveyScreen] Error searching quick tag ingredient: $e');
      }
    }
  }

  @override
  void dispose() {
    _allergySearchDebounce?.cancel();
    _allergySearchController.dispose();
    _pageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentStep < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _submitOnboarding();
    }
  }

  void _previousPage() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _submitOnboarding() async {
    setState(() => _isSubmitting = true);

    try {
      final heightVal = int.tryParse(_heightController.text.trim()) ?? 170;
      final weightVal = int.tryParse(_weightController.text.trim()) ?? 65;

      final onboardingData = <String, dynamic>{
        'primaryGoal': _primaryGoal,
        'cookingFrequency': _cookingFrequency,
        'dietaryStyle': _dietaryStyle,
        'activityLevel': _activityLevel,
        'householdSize': _householdSize,
        'height': heightVal,
        'weight': weightVal,
      };

      // 1. Submit onboarding survey preferences
      await _apiService.completeOnboarding(onboardingData);

      // 2. Save food allergies if selected
      for (final allergy in _selectedAllergies) {
        try {
          await _apiService.addAllergy(allergy['id'] as int, allergy['note'] as String?);
        } catch (e) {
          debugPrint('[OnboardingSurveyScreen] Failed to add allergy ${allergy['name']}: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    'Chào mừng bạn đến với Friggy!',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF008435),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
          ),
        );

        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 400),
            pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      }
    } catch (e) {
      debugPrint('[OnboardingSurveyScreen] Error submitting onboarding: $e');
      if (mounted) {
        // Fallback to HomeScreen if offline or backend error
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final isEn = loc?.locale.languageCode == 'en';

    final bgColor1 = isDark ? const Color(0xFF0E1611) : const Color(0xFFFFFFFF);
    final bgColor2 = isDark ? const Color(0xFF142017) : const Color(0xFFF5FCF4);
    final bgColor3 = isDark ? const Color(0xFF1B2E21) : const Color(0xFFC7EFC2);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgColor1, bgColor2, bgColor3],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar Header & Progress
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0.w, vertical: 12.0.h),
                child: Row(
                  children: [
                    if (_currentStep > 0)
                      GestureDetector(
                        onTap: _previousPage,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF19271E) : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFA5E69C),
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: isDark ? Colors.white : const Color(0xFF006428),
                            size: 20,
                          ),
                        ),
                      )
                    else
                      SizedBox(width: 38.w),

                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            isEn ? 'Personalize Friggy' : 'Tùy chỉnh khảo sát',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFF81C784) : const Color(0xFF006428),
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Bước ${_currentStep + 1} / 5',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(width: 38.w),
                  ],
                ),
              ),

              // Progress Bar Indicator
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0.w, vertical: 4.0.h),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10.r),
                  child: LinearProgressIndicator(
                    value: (_currentStep + 1) / 5,
                    minHeight: 6,
                    backgroundColor: isDark ? const Color(0xFF233629) : const Color(0xFFE0E0E0),
                    color: const Color(0xFF4CAF50),
                  ),
                ),
              ),

              SizedBox(height: 12.h),

              // Survey Steps View
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (step) {
                    setState(() => _currentStep = step);
                  },
                  children: [
                    _buildStep1Goal(isDark, isEn),
                    _buildStep2Cooking(isDark, isEn),
                    _buildStep3Diet(isDark, isEn),
                    _buildStep4Allergies(isDark, isEn),
                    _buildStep5Health(isDark, isEn),
                  ],
                ),
              ),

              // Bottom Action Button
              Padding(
                padding: EdgeInsets.all(20.0.w),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF008435),
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18.r),
                      ),
                    ),
                    child: _isSubmitting
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _currentStep == 4
                                    ? (isEn ? 'Complete Survey' : 'Hoàn tất & Khám phá Friggy')
                                    : (isEn ? 'Continue' : 'Tiếp tục'),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 17.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Icon(
                                _currentStep == 4
                                    ? Icons.rocket_launch_rounded
                                    : Icons.arrow_forward_rounded,
                                size: 20,
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // STEP 1: Primary Goal
  // --------------------------------------------------------------------------
  Widget _buildStep1Goal(bool isDark, bool isEn) {
    final goals = [
      {
        'id': 'save_money',
        'title': isEn ? 'Save Money' : 'Tiết kiệm chi phí thực phẩm',
        'desc': isEn ? 'Optimize shopping & reduce unnecessary expenses' : 'Tối ưu hóa mua sắm và quản lý chi tiêu ăn uống',
        'icon': '💰',
      },
      {
        'id': 'reduce_waste',
        'title': isEn ? 'Reduce Food Waste' : 'Giảm thiểu lãng phí thức ăn',
        'desc': isEn ? 'Get reminders before items expire in fridge' : 'Nhắc nhở hết hạn, tận dụng tối đa đồ trong tủ lạnh',
        'icon': '♻️',
      },
      {
        'id': 'eat_healthy',
        'title': isEn ? 'Eat Healthy' : 'Ăn uống lành mạnh & khoa học',
        'desc': isEn ? 'Nutritious meal plans & balanced calorie suggestions' : 'Đề xuất thực đơn đủ chất, cân bằng dinh dưỡng',
        'icon': '🥗',
      },
      {
        'id': 'convenience',
        'title': isEn ? 'Quick & Easy Cooking' : 'Nấu ăn nhanh chóng & tiện lợi',
        'desc': isEn ? 'Quick recipes based on what you already have' : 'Gợi ý món ngon dễ làm từ nguyên liệu sẵn có',
        'icon': '⚡',
      },
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEn ? 'What is your primary goal?' : 'Mục tiêu chính của bạn là gì?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF006428),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            isEn
                ? 'Friggy will customize AI meal plans & fridge alerts for you.'
                : 'Friggy sẽ dựa vào mục tiêu này để đưa ra gợi ý AI phù hợp nhất.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5.sp,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          SizedBox(height: 20.h),

          ...goals.map((g) {
            final isSelected = _primaryGoal == g['id'];
            return GestureDetector(
              onTap: () => setState(() => _primaryGoal = g['id'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.only(bottom: 12.h),
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? const Color(0xFF1E3A26) : const Color(0xFFE8F5E9))
                      : (isDark ? const Color(0xFF19271E) : Colors.white),
                  borderRadius: BorderRadius.circular(18.r),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF4CAF50) : (isDark ? const Color(0xFF2E4D36) : const Color(0xFFE0E0E0)),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(g['icon'] as String, style: TextStyle(fontSize: 28)),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            g['title'] as String,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF19221C),
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            g['desc'] as String,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5.sp,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 24),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // STEP 2: Cooking Frequency & Household Size
  // --------------------------------------------------------------------------
  Widget _buildStep2Cooking(bool isDark, bool isEn) {
    final frequencies = [
      {'id': 'daily', 'title': isEn ? 'Daily' : 'Hàng ngày', 'icon': '🍳'},
      {'id': 'few_times_week', 'title': isEn ? 'A few times a week' : 'Vài lần một tuần', 'icon': '🍲'},
      {'id': 'weekends', 'title': isEn ? 'Weekends only' : 'Chỉ nấu cuối tuần', 'icon': '🍕'},
      {'id': 'rarely', 'title': isEn ? 'Rarely' : 'Hiếm khi nấu ăn', 'icon': '🥡'},
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEn ? 'Cooking & Household' : 'Tần suất nấu ăn & Gia đình',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF006428),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            isEn
                ? 'How often do you cook and for how many people?'
                : 'Bạn thường nấu ăn với tần suất như thế nào và cho mấy người?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5.sp,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          SizedBox(height: 20.h),

          Text(
            isEn ? 'Cooking Frequency' : 'Tần suất nấu ăn',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFF81C784) : const Color(0xFF006428),
            ),
          ),
          SizedBox(height: 10.h),

          ...frequencies.map((f) {
            final isSelected = _cookingFrequency == f['id'];
            return GestureDetector(
              onTap: () => setState(() => _cookingFrequency = f['id'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.only(bottom: 10.h),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? const Color(0xFF1E3A26) : const Color(0xFFE8F5E9))
                      : (isDark ? const Color(0xFF19271E) : Colors.white),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF4CAF50) : (isDark ? const Color(0xFF2E4D36) : const Color(0xFFE0E0E0)),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(f['icon'] as String, style: TextStyle(fontSize: 22)),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Text(
                        f['title'] as String,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF19221C),
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 22),
                  ],
                ),
              ),
            );
          }),

          SizedBox(height: 20.h),

          // Household Size Picker
          Text(
            isEn ? 'Household Members' : 'Số người trong gia đình',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFF81C784) : const Color(0xFF006428),
            ),
          ),
          SizedBox(height: 10.h),
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF19271E) : Colors.white,
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFE0E0E0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.people_alt_rounded, color: Color(0xFF4CAF50), size: 24),
                    SizedBox(width: 12.w),
                    Text(
                      '$_householdSize ${isEn ? 'people' : 'thành viên'}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF19221C),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: _householdSize > 1
                          ? () => setState(() => _householdSize--)
                          : null,
                      icon: Icon(Icons.remove_circle_outline_rounded),
                      color: const Color(0xFF4CAF50),
                    ),
                    Text(
                      '$_householdSize',
                      style: GoogleFonts.plusJakartaSans(fontSize: 18.sp, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: _householdSize < 15
                          ? () => setState(() => _householdSize++)
                          : null,
                      icon: Icon(Icons.add_circle_outline_rounded),
                      color: const Color(0xFF4CAF50),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // STEP 3: Dietary Style & Activity Level
  // --------------------------------------------------------------------------
  Widget _buildStep3Diet(bool isDark, bool isEn) {
    final diets = [
      {'id': 'omnivore', 'title': isEn ? 'Omnivore' : 'Ăn tạp / Thông thường', 'icon': '🥩'},
      {'id': 'vegetarian', 'title': isEn ? 'Vegetarian' : 'Ăn chay (Trứng/Sữa)', 'icon': '🥦'},
      {'id': 'vegan', 'title': isEn ? 'Vegan' : 'Ăn chay thuần thực vật', 'icon': '🌿'},
      {'id': 'keto', 'title': isEn ? 'Keto / Low-carb' : 'Keto / Giảm Carb', 'icon': '🥑'},
    ];

    final activities = [
      {'id': 'sedentary', 'title': isEn ? 'Sedentary' : 'Ít vận động (Ngồi nhiều)', 'icon': '🛋️'},
      {'id': 'light', 'title': isEn ? 'Lightly Active' : 'Vận động nhẹ (Đi bộ)', 'icon': '🚶'},
      {'id': 'moderate', 'title': isEn ? 'Moderately Active' : 'Vận động vừa (Tập 3-5 ngày/tuần)', 'icon': '🏃'},
      {'id': 'active', 'title': isEn ? 'Very Active' : 'Năng động / Thể thao', 'icon': '🚴'},
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEn ? 'Diet & Activity Level' : 'Chế độ ăn & Vận động',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF006428),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            isEn
                ? 'Select your dietary preferences and daily physical activity level.'
                : 'Lựa chọn chế độ ăn thích hợp để Friggy đề xuất món ăn tối ưu.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5.sp,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          SizedBox(height: 18.h),

          Text(
            isEn ? 'Dietary Preference' : 'Chế độ ăn chính',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFF81C784) : const Color(0xFF006428),
            ),
          ),
          SizedBox(height: 8.h),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: diets.map((d) {
              final isSelected = _dietaryStyle == d['id'];
              return ChoiceChip(
                label: Text('${d['icon']} ${d['title']}'),
                selected: isSelected,
                selectedColor: const Color(0xFF4CAF50),
                backgroundColor: isDark ? const Color(0xFF19271E) : Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                  fontWeight: FontWeight.bold,
                ),
                onSelected: (selected) {
                  if (selected) setState(() => _dietaryStyle = d['id'] as String);
                },
              );
            }).toList(),
          ),

          SizedBox(height: 22.h),

          Text(
            isEn ? 'Daily Activity Level' : 'Mức độ vận động hàng ngày',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFF81C784) : const Color(0xFF006428),
            ),
          ),
          SizedBox(height: 10.h),

          ...activities.map((a) {
            final isSelected = _activityLevel == a['id'];
            return GestureDetector(
              onTap: () => setState(() => _activityLevel = a['id'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.only(bottom: 10.h),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? const Color(0xFF1E3A26) : const Color(0xFFE8F5E9))
                      : (isDark ? const Color(0xFF19271E) : Colors.white),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF4CAF50) : (isDark ? const Color(0xFF2E4D36) : const Color(0xFFE0E0E0)),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(a['icon'] as String, style: TextStyle(fontSize: 20)),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        a['title'] as String,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.5.sp,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF19221C),
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 20),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // STEP 4: Food & Ingredient Allergies
  // --------------------------------------------------------------------------
  Widget _buildStep4Allergies(bool isDark, bool isEn) {
    final commonAllergens = [
      {'name': 'Tôm', 'icon': '🦐'},
      {'name': 'Cua', 'icon': '🦀'},
      {'name': 'Trứng', 'icon': '🥚'},
      {'name': 'Sữa', 'icon': '🥛'},
      {'name': 'Đậu phụng', 'icon': '🥜'},
      {'name': 'Cá', 'icon': '🐟'},
      {'name': 'Thịt bò', 'icon': '🥩'},
      {'name': 'Đậu nành', 'icon': '🫘'},
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isEn ? 'Food & Ingredient Allergies' : 'Dị ứng món ăn & nguyên liệu',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF006428),
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF233629) : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.5)),
                ),
                child: Text(
                  isEn ? 'Optional' : 'Tùy chọn',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF4CAF50),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            isEn
                ? 'Select ingredients you are allergic to so Friggy AI can exclude them from your recipe recommendations.'
                : 'Chọn các nguyên liệu gây dị ứng để Friggy tự động loại trừ khỏi thực đơn và cảnh báo cho bạn.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5.sp,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          SizedBox(height: 18.h),

          // Selected Allergies Chip List
          if (_selectedAllergies.isNotEmpty) ...[
            Text(
              isEn ? 'Selected Allergies (${_selectedAllergies.length}):' : 'Danh sách đã chọn (${_selectedAllergies.length}):',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFF81C784) : const Color(0xFF006428),
              ),
            ),
            SizedBox(height: 8.h),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedAllergies.map((allergy) {
                final int id = allergy['id'] as int;
                final String name = allergy['name'] as String;
                return Chip(
                  avatar: Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
                  label: Text(
                    name,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 13.sp,
                    ),
                  ),
                  backgroundColor: const Color(0xFFD32F2F),
                  deleteIcon: Icon(Icons.cancel_rounded, color: Colors.white70, size: 18),
                  onDeleted: () => _toggleAllergyIngredient(id, name),
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                );
              }).toList(),
            ),
            SizedBox(height: 18.h),
          ] else ...[
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF19271E) : const Color(0xFFF5FCF4),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFA5E69C)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, color: Color(0xFF4CAF50), size: 20),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      isEn
                          ? 'No allergies selected (You can skip this if you have none).'
                          : 'Chưa chọn dị ứng nào (Bỏ qua nếu bạn không có dị ứng thực phẩm).',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5.sp,
                        color: isDark ? Colors.white70 : const Color(0xFF2E7D32),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 18.h),
          ],

          // Quick Popular Allergen Badges
          Text(
            isEn ? 'Common Allergens:' : 'Nguyên liệu dị ứng phổ biến:',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFF81C784) : const Color(0xFF006428),
            ),
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: commonAllergens.map((item) {
              final String name = item['name']!;
              final String icon = item['icon']!;
              final bool isSelected = _selectedAllergies.any(
                (a) => (a['name'] as String).toLowerCase().contains(name.toLowerCase()),
              );

              return InkWell(
                onTap: () => _toggleQuickTag(name),
                borderRadius: BorderRadius.circular(20.r),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFD32F2F)
                        : (isDark ? const Color(0xFF19271E) : Colors.white),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFD32F2F)
                          : (isDark ? const Color(0xFF2E4D36) : const Color(0xFFE0E0E0)),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(icon, style: TextStyle(fontSize: 16)),
                      SizedBox(width: 6.w),
                      Text(
                        name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                      if (isSelected) ...[
                        SizedBox(width: 4.w),
                        Icon(Icons.check_rounded, color: Colors.white, size: 16),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          SizedBox(height: 20.h),

          // Search Field for Any Ingredient
          Text(
            isEn ? 'Search Other Ingredients:' : 'Tìm nguyên liệu khác:',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFF81C784) : const Color(0xFF006428),
            ),
          ),
          SizedBox(height: 8.h),
          TextField(
            controller: _allergySearchController,
            onChanged: _onAllergySearchChanged,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: isEn ? 'Type ingredient name (e.g. Peanut, Shrimp...)' : 'Gõ tên nguyên liệu (VD: Nấm, Mực, Đậu...)',
              hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF4CAF50)),
              suffixIcon: _allergySearchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _allergySearchController.clear();
                        _onAllergySearchChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: isDark ? const Color(0xFF19271E) : Colors.white,
              contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.r),
                borderSide: BorderSide(color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFE0E0E0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.r),
                borderSide: BorderSide(color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFE0E0E0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.r),
                borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 1.8),
              ),
            ),
          ),

          SizedBox(height: 12.h),

          // Ingredient Search Results List
          if (_isLoadingIngredients)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50))),
            )
          else if (_searchedIngredients.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  isEn ? 'No ingredients found' : 'Không tìm thấy nguyên liệu phù hợp',
                  style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _searchedIngredients.length > 15 ? 15 : _searchedIngredients.length,
              itemBuilder: (context, index) {
                final item = _searchedIngredients[index];
                final int id = item['id'] as int;
                final String name = item['name'] as String? ?? 'Nguyên liệu';
                final isSelected = _selectedAllergies.any((a) => a['id'] == id);

                return Container(
                  margin: EdgeInsets.only(bottom: 6.h),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark ? const Color(0xFF2D1B1B) : const Color(0xFFFFEBEE))
                        : (isDark ? const Color(0xFF19271E) : Colors.white),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFE53935)
                          : (isDark ? const Color(0xFF2E4D36) : const Color(0xFFE0E0E0)),
                    ),
                  ),
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 2.h),
                    title: Text(
                      name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? const Color(0xFFE53935)
                            : (isDark ? Colors.white : const Color(0xFF19221C)),
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle_rounded, color: Color(0xFFE53935), size: 22)
                        : Icon(Icons.add_circle_outline_rounded, color: Color(0xFF4CAF50), size: 22),
                    onTap: () => _toggleAllergyIngredient(id, name),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // STEP 5: Body Metrics (Optional)
  // --------------------------------------------------------------------------
  Widget _buildStep5Health(bool isDark, bool isEn) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEn ? 'Body Metrics (Optional)' : 'Chỉ số sức khỏe (Tùy chọn)',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF006428),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            isEn
                ? 'Providing your height and weight helps AI compute accurate daily calories.'
                : 'Chiều cao & cân nặng giúp AI tính toán chính xác lượng calo phù hợp mỗi ngày cho bạn.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5.sp,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          SizedBox(height: 24.h),

          // Height Field
          Text(
            isEn ? 'Height (cm)' : 'Chiều cao (cm)',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF006428),
            ),
          ),
          SizedBox(height: 6.h),
          TextField(
            controller: _heightController,
            keyboardType: TextInputType.number,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.height_rounded, color: Color(0xFF4CAF50)),
              filled: true,
              fillColor: isDark ? const Color(0xFF19271E) : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.r),
                borderSide: BorderSide(color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFE0E0E0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.r),
                borderSide: BorderSide(color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFE0E0E0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.r),
                borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
              ),
            ),
          ),

          SizedBox(height: 20.h),

          // Weight Field
          Text(
            isEn ? 'Weight (kg)' : 'Cân nặng (kg)',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF006428),
            ),
          ),
          SizedBox(height: 6.h),
          TextField(
            controller: _weightController,
            keyboardType: TextInputType.number,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.monitor_weight_rounded, color: Color(0xFF4CAF50)),
              filled: true,
              fillColor: isDark ? const Color(0xFF19271E) : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.r),
                borderSide: BorderSide(color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFE0E0E0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.r),
                borderSide: BorderSide(color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFE0E0E0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.r),
                borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
              ),
            ),
          ),

          SizedBox(height: 30.h),

          Center(
            child: Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF19271E) : const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: Color(0xFF4CAF50)),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      isEn
                          ? 'All set! Tap the button below to finish onboarding.'
                          : 'Tất cả đã sẵn sàng! Bấm nút bên dưới để hoàn tất khảo sát.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF1B5E20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
