import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../data/services/api_service.dart';
import '../sqlite/helpers/sync_helper.dart';
import '../sqlite/models/local_ingredient_model.dart';
import '../sqlite/models/local_ingredient_catalog_model.dart';
import '../sqlite/services/ingredient_catalog_local_service.dart';
import '../sqlite/services/ingredient_local_service.dart';

class ManualAddIngredientScreen extends StatefulWidget {
  const ManualAddIngredientScreen({super.key});

  @override
  State<ManualAddIngredientScreen> createState() =>
      _ManualAddIngredientScreenState();
}

class _ManualAddIngredientScreenState
    extends State<ManualAddIngredientScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController =
      TextEditingController(text: '0');
  String _selectedUnit = 'kg';
  String _selectedStorageArea = 'Fridge'; // 'Fridge', 'Freezer', 'Pantry'
  DateTime? _selectedExpirationDate;

  final List<String> _units = [
    'kg',
    'gram',
    'g',
    'ml',
    'lít',
    'quả',
    'củ',
    'bó',
    'miếng',
    'gói',
    'hộp',
    'chai',
    'con',
    'bắp',
    'pcs',
  ];

  List<Map<String, dynamic>> _suggestions = [];
  bool _showSuggestions = false;
  int? _selectedIngredientId;
  final IngredientCatalogLocalService _catalogLocalService = IngredientCatalogLocalService();
  final IngredientLocalService _ingredientLocalService = IngredientLocalService();

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onNameChanged);
    _prefetchCatalog(); // Cache danh mục nguyên liệu khi vào màn hình
  }

  /// Tiẻn tải danh mục nguyên liệu vào SQLite (nếu chưa có)
  Future<void> _prefetchCatalog() async {
    try {
      final hasCached = await _catalogLocalService.hasCatalogData();
      if (!hasCached) {
        // Chưa có cache → tải từ API và lưu SQLite
        final res = await ApiService().getIngredients(search: '');
        final items = res.cast<Map<String, dynamic>>().map((item) {
          return LocalIngredientCatalogModel(
            id: (item['id'] as num?)?.toInt() ?? 0,
            name: item['name'] as String? ?? '',
            englishName: item['englishName'] as String?,
            defaultUnit: item['defaultUnit'] as String?,
            category: item['category'] as String?,
            imagePath: item['imagePath'] as String?,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          );
        }).where((i) => i.id > 0 && i.name.isNotEmpty).toList();
        await _catalogLocalService.saveCatalogCache(items);
        debugPrint('[ManualAdd] Cached ${items.length} ingredient catalog items.');
      }
    } catch (e) {
      debugPrint('[ManualAdd] Could not prefetch catalog (offline?): $e');
    }
  }

  void _onNameChanged() async {
    final val = _nameController.text.trim();
    if (val.isEmpty) {
      if (mounted) setState(() => _showSuggestions = false);
      return;
    }
    try {
      // Thử tìm từ API trước
      final res = await ApiService().getIngredients(search: val);
      if (mounted) {
        // Cập nhật SQLite cache với kết quả mới
        final freshItems = res.cast<Map<String, dynamic>>().map((item) {
          return LocalIngredientCatalogModel(
            id: (item['id'] as num?)?.toInt() ?? 0,
            name: item['name'] as String? ?? '',
            englishName: item['englishName'] as String?,
            defaultUnit: item['defaultUnit'] as String?,
            category: item['category'] as String?,
            imagePath: item['imagePath'] as String?,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          );
        }).where((i) => i.id > 0 && i.name.isNotEmpty).toList();
        if (freshItems.isNotEmpty) {
          await _catalogLocalService.saveCatalogCache(freshItems);
        }
        setState(() {
          _suggestions = res.cast<Map<String, dynamic>>();
          _showSuggestions = _suggestions.isNotEmpty;
        });
      }
    } catch (e) {
      // Offline: fallback tìm trong SQLite
      debugPrint('[ManualAdd] API error, searching SQLite catalog: $e');
      final cached = await _catalogLocalService.searchCatalog(val);
      if (mounted) {
        setState(() {
          _suggestions = cached.map((c) => c.toApiFormat()).toList();
          _showSuggestions = _suggestions.isNotEmpty;
        });
      }
    }
  }

  void _selectSuggestion(Map<String, dynamic> item) {
    setState(() {
      _nameController.text = item['name'] as String? ?? '';
      _selectedIngredientId = item['id'] as int?;
      if (item['defaultUnit'] != null) {
        _selectedUnit = item['defaultUnit'] as String;
      }
      _showSuggestions = false;
    });
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }



  // Beautiful Custom Modal for Unit Selection
  void _showUnitPicker(bool isEn) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF19271E) : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
            border: isDark ? Border.all(color: const Color(0xFF2E4D36), width: 1.2) : null,
          ),
          padding: EdgeInsets.only(
            left: 20.w,
            right: 20.w,
            top: 14.h,
            bottom: 24.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Drag Handle Bar
              Center(
                child: Container(
                  width: 38,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFC8E6C9),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
              ),

              SizedBox(height: 16.h),

              // Title Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEn ? 'Select Unit' : 'Chọn Đơn Vị',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 21.sp,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF006428),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark ? Colors.white : const Color(0xFF6B786F),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              SizedBox(height: 14.h),

              // Unit Chips Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 2.2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: _units.length,
                itemBuilder: (context, index) {
                  final unit = _units[index];
                  final isSelected = unit == _selectedUnit;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedUnit = unit;
                      });
                      Navigator.pop(context);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark ? const Color(0xFF81C784) : const Color(0xFF008435))
                            : (isDark ? const Color(0xFF0E1611) : const Color(0xFFF1F8E9)),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: isSelected
                              ? (isDark ? const Color(0xFF81C784) : const Color(0xFF008435))
                              : (isDark ? const Color(0xFF2E4D36) : const Color(0xFF81C784)),
                          width: 1.2,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF008435)
                                      .withValues(alpha: isDark ? 0.4 : 0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : [],
                      ),
                      child: Text(
                        unit,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? (isDark ? const Color(0xFF0E1611) : Colors.white)
                              : (isDark ? Colors.white : const Color(0xFF008435)),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Beautiful Custom On-Screen Keypad & Quantity Picker Modal
  void _showQuantityPickerModal(bool isEn) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void updateVal(String newVal) {
              setModalState(() {});
              setState(() {
                _quantityController.text = newVal;
              });
            }

            final currentText = _quantityController.text.trim();

            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF19271E) : Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
                border: isDark ? Border.all(color: const Color(0xFF2E4D36), width: 1.2) : null,
              ),
              padding: EdgeInsets.only(
                left: 20.w,
                right: 20.w,
                top: 14.h,
                bottom: 24.h,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Drag Handle Bar
                  Center(
                    child: Container(
                      width: 38,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFC8E6C9),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                  ),

                  SizedBox(height: 14.h),

                  // Title Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEn ? 'Select Quantity' : 'Chọn Số Lượng',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 21.sp,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF006428),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: isDark ? Colors.white : const Color(0xFF6B786F),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),

                  SizedBox(height: 10.h),

                  // Large Display Number Box
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0E1611) : const Color(0xFFF1F8E9),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2E4D36) : const Color(0xFF81C784),
                        width: 1.4,
                      ),
                    ),
                    child: Text(
                      currentText.isEmpty ? '0' : currentText,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 34.sp,
                        fontWeight: FontWeight.w900,
                        color: isDark ? const Color(0xFF81C784) : const Color(0xFF008435),
                      ),
                    ),
                  ),

                  SizedBox(height: 14.h),

                  // Quick Preset Chips (1, 2, 3, 5, 10, 12, 20)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children:
                        ['1', '2', '3', '5', '10', '12', '20'].map((numStr) {
                      final isSel = currentText == numStr;
                      return GestureDetector(
                        onTap: () => updateVal(numStr),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: isSel
                                ? (isDark ? const Color(0xFF81C784) : const Color(0xFF008435))
                                : (isDark ? const Color(0xFF233629) : const Color(0xFFE8F5E9)),
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          child: Text(
                            numStr,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14.5.sp,
                              fontWeight: FontWeight.w700,
                              color: isSel
                                  ? (isDark ? const Color(0xFF0E1611) : Colors.white)
                                  : (isDark ? Colors.white : const Color(0xFF008435)),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  SizedBox(height: 18.h),

                  // On-Screen Keypad Grid (1-9, Backspace, 0, Done)
                  GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 3,
                    childAspectRatio: 2.2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      ...'123456789'.split('').map((digit) {
                        return GestureDetector(
                          onTap: () {
                            if (currentText == '0') {
                              updateVal(digit);
                            } else {
                              updateVal(currentText + digit);
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0E1611) : const Color(0xFFF4F7F4),
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                            child: Center(
                              child: Text(
                                digit,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 22.sp,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF19221C),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),

                      // Backspace ⌫
                      GestureDetector(
                        onTap: () {
                          if (currentText.isNotEmpty) {
                            final nextText = currentText.substring(
                              0,
                              currentText.length - 1,
                            );
                            updateVal(nextText.isEmpty ? '0' : nextText);
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF3E1D22) : const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.backspace_outlined,
                              color: isDark ? const Color(0xFFE57373) : const Color(0xFFD32F2F),
                              size: 22,
                            ),
                          ),
                        ),
                      ),

                      // 0
                      GestureDetector(
                        onTap: () {
                          if (currentText != '0') {
                            updateVal('${currentText}0');
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0E1611) : const Color(0xFFF4F7F4),
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          child: Center(
                            child: Text(
                              '0',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 22.sp,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF19221C),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Done ✔ Button
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF81C784) : const Color(0xFF008435),
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.check_rounded,
                              color: isDark ? const Color(0xFF0E1611) : Colors.white,
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Date Picker
  Future<void> _pickExpirationDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedExpirationDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 3)),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: Color(0xFF81C784),
                    onPrimary: Color(0xFF0E1611),
                    surface: Color(0xFF19271E),
                    onSurface: Colors.white,
                  )
                : const ColorScheme.light(
                    primary: Color(0xFF008435),
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Color(0xFF19221C),
                  ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedExpirationDate = picked;
      });
    }
  }

  void _saveIngredient() async {
    final isEn = AppLocalizations.of(context)?.locale.languageCode == 'en';
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEn ? 'Please enter ingredient name' : 'Vui lòng nhập tên nguyên liệu'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    final qtyNum = double.tryParse(_quantityController.text.trim()) ?? 1.0;

    String storageLoc = 'fridge';
    if (_selectedStorageArea == 'Freezer') storageLoc = 'freezer';
    if (_selectedStorageArea == 'Pantry') storageLoc = 'pantry';

    final expiresAtStr = _selectedExpirationDate != null
        ? _selectedExpirationDate!.toIso8601String().split('T')[0]
        : null;

    // Kiểm tra kết nối mạng
    final isOnline = await SyncHelper.instance.checkCurrentConnection();

    if (!isOnline) {
      // ─── OFFLINE: lưu thẳng vào SQLite với sync_status='pending' ───
      final localId = 'pending_${DateTime.now().millisecondsSinceEpoch}';
      final offlineItem = LocalIngredientModel(
        id: localId,
        ingredientId: _selectedIngredientId ?? 0,
        name: name,
        quantity: qtyNum,
        unit: _selectedUnit,
        storageLocation: storageLoc,
        expiresAt: expiresAtStr,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        syncStatus: 'pending',
      );
      await _ingredientLocalService.saveOfflineIngredient(offlineItem);

      if (!mounted) return;
      Navigator.pop(context, true); // true = có thay đổi, reload danh sách
      return;
    }

    // ─── ONLINE: gọi API như cũ ───
    try {
      await ApiService().addFridgeItem({
        if (_selectedIngredientId != null && _selectedIngredientId! > 0)
          'ingredientId': _selectedIngredientId,
        'name': name,
        'quantity': qtyNum,
        'unit': _selectedUnit,
        if (expiresAtStr != null) 'expiresAt': expiresAtStr,
        'storageLocation': storageLoc,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEn ? 'Added $name to fridge!' : 'Đã thêm $name vào tủ lạnh thành công!',
          ),
          backgroundColor: const Color(0xFF008435),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Add fridge item error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEn ? 'Failed to add item to fridge' : 'Không thể thêm nguyên liệu vào tủ',
          ),
          backgroundColor: const Color(0xFF008435),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
      );
    }
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
              // 1. Top Bar Header (Back Icon + Friggy Logo)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0.w, vertical: 8.0.h),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF19271E) : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFA5E69C),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: isDark ? Colors.white : const Color(0xFF006428),
                          size: 22,
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),

                    // Friggy Brand Title with Leaf
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Row(
                        children: [
                          RichText(
                            text: TextSpan(
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 26.sp,
                                fontWeight: FontWeight.w900,
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
                          SizedBox(width: 4.w),
                          Icon(
                            Icons.eco_rounded,
                            color: isDark ? const Color(0xFF81C784) : const Color(0xFF4CAF50),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Main Scrollable Form Area
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 16.h),

                      // Mascot Greeting Card Banner
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E3A25) : const Color(0xFF4CB93E),
                          borderRadius: BorderRadius.circular(26.r),
                          border: isDark
                              ? Border.all(color: const Color(0xFF2E4D36), width: 1.2)
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.1),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Larger Mascot Image
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20.r),
                              child: Image.asset(
                                'assets/images/QR.png',
                                width: 110,
                                height: 110,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 110,
                                    height: 110,
                                    color: Colors.white24,
                                    child: const Icon(
                                      Icons.face_rounded,
                                      size: 55,
                                      color: Colors.white,
                                    ),
                                  );
                                },
                              ),
                            ),
                            SizedBox(width: 18.w),
                            Expanded(
                              child: Text(
                                isEn ? 'Add quickly, let Friggy handle the rest!' : 'Nhập nhanh chóng, để Friggy lo phần còn lại!',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 28.h),

                      // 1. Ingredient Name Field
                      _buildFieldTitle(isEn ? 'Ingredient Name' : 'Tên Nguyên Liệu'),
                      SizedBox(height: 8.h),
                      _buildTextField(
                        controller: _nameController,
                        hintText: isEn ? 'e.g. Red Apple, Fresh Milk...' : 'vd: Táo đỏ, Sữa tươi...',
                      ),

                      if (_showSuggestions) ...[
                        SizedBox(height: 8.h),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 180),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF19271E) : Colors.white,
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(
                              color: isDark ? const Color(0xFF2E4D36) : const Color(0xFF81C784),
                            ),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.symmetric(vertical: 4),
                            itemCount: _suggestions.length,
                            separatorBuilder: (context, index) => Divider(
                              height: 1,
                              color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFE8F5E9),
                            ),
                            itemBuilder: (context, index) {
                              final sug = _suggestions[index];
                              final sugName = sug['name'] as String? ?? '';
                              final sugUnit = sug['defaultUnit'] as String? ?? '';
                              return ListTile(
                                dense: true,
                                title: Text(
                                  sugName,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14.5.sp,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF19221C),
                                  ),
                                ),
                                subtitle: Text(
                                  isEn ? 'Default unit: $sugUnit' : 'Đơn vị mặc định: $sugUnit',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5.sp,
                                    color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
                                  ),
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                                onTap: () => _selectSuggestion(sug),
                              );
                            },
                          ),
                        ),
                      ],

                      SizedBox(height: 24.h),

                      // 2. Row: Quantity & Unit
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldTitle(isEn ? 'Quantity' : 'Số Lượng'),
                                SizedBox(height: 8.h),
                                _buildQuantityStepperField(isEn),
                              ],
                            ),
                          ),
                          SizedBox(width: 16.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldTitle(isEn ? 'Unit' : 'Đơn Vị'),
                                SizedBox(height: 8.h),
                                _buildSelectField(
                                  value: _selectedUnit,
                                  onTap: () => _showUnitPicker(isEn),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 24.h),

                      // 3. Expiration Date (Auto-calculated or custom picker)
                      _buildFieldTitle(isEn ? 'Expiration Date' : 'Ngày Hết Hạn (Tùy chọn)'),
                      SizedBox(height: 8.h),
                      GestureDetector(
                        onTap: _pickExpirationDate,
                        child: Container(
                          height: 56,
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF19271E) : Colors.white,
                            borderRadius: BorderRadius.circular(18.r),
                            border: Border.all(
                              color: isDark ? const Color(0xFF2E4D36) : const Color(0xFF81C784),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedExpirationDate == null
                                      ? (isEn ? 'Tap to set date (Optional)' : 'Bấm để chọn ngày (Không bắt buộc)')
                                      : '${_selectedExpirationDate!.day.toString().padLeft(2, '0')}/${_selectedExpirationDate!.month.toString().padLeft(2, '0')}/${_selectedExpirationDate!.year}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14.5.sp,
                                    fontWeight: FontWeight.w600,
                                    color: _selectedExpirationDate == null
                                        ? (isDark ? const Color(0xFF9DA8A0) : const Color(0xFFA5D6A7))
                                        : (isDark ? Colors.white : const Color(0xFF19221C)),
                                  ),
                                ),
                              ),
                              if (_selectedExpirationDate != null)
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedExpirationDate = null;
                                    });
                                  },
                                  child: Padding(
                                    padding: EdgeInsets.only(right: 8.0.w),
                                    child: Icon(
                                      Icons.cancel_rounded,
                                      size: 18,
                                      color: isDark ? Colors.white54 : Colors.grey.shade400,
                                    ),
                                  ),
                                ),
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 20,
                                color: isDark ? const Color(0xFF81C784) : const Color(0xFF4CAF50),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 24.h),

                      // 4. Storage Area (Pills: Fridge, Freezer, Pantry)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          _buildFieldTitle(isEn ? 'Storage Area' : 'Vị Trí Lưu Trữ'),
                        ],
                      ),
                      SizedBox(height: 10.h),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStoragePill('Fridge', isEn ? 'Cooler' : 'Ngăn mát'),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: _buildStoragePill('Freezer', isEn ? 'Freezer' : 'Ngăn đông'),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: _buildStoragePill('Pantry', isEn ? 'Pantry' : 'Tủ khô'),
                          ),
                        ],
                      ),

                      SizedBox(height: 36.h),

                      // 6. Save / Add Button
                      GestureDetector(
                        onTap: _saveIngredient,
                        child: Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF81C784) : const Color(0xFF008435),
                            borderRadius: BorderRadius.circular(28.r),
                            boxShadow: [
                              BoxShadow(
                                color: (isDark ? const Color(0xFF81C784) : const Color(0xFF008435))
                                    .withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_circle_outline_rounded,
                                color: isDark ? const Color(0xFF0E1611) : Colors.white,
                                size: 24,
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                isEn ? 'Add to Fridge' : 'Thêm Vào Tủ Lạnh',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? const Color(0xFF0E1611) : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 32.h),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldTitle(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 15.5.sp,
        fontWeight: FontWeight.w800,
        color: isDark ? Colors.white : const Color(0xFF006428),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF19271E) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? const Color(0xFF2E4D36) : const Color(0xFF81C784),
          width: 1.2,
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14.5.sp,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : const Color(0xFF19221C),
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFF9DA8A0) : const Color(0xFFA5D6A7),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }

  void _incrementQuantity() {
    final current = int.tryParse(_quantityController.text.trim()) ?? 0;
    setState(() {
      _quantityController.text = (current + 1).toString();
    });
  }

  void _decrementQuantity() {
    final current = int.tryParse(_quantityController.text.trim()) ?? 0;
    if (current > 0) {
      setState(() {
        _quantityController.text = (current - 1).toString();
      });
    }
  }

  Widget _buildQuantityStepperField(bool isEn) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF19271E) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? const Color(0xFF2E4D36) : const Color(0xFF81C784),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          // Minus Button (-)
          GestureDetector(
            onTap: _decrementQuantity,
            child: Container(
              width: 34,
              height: 34,
              margin: EdgeInsets.only(left: 6.w),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF233629) : const Color(0xFFF1F8E9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.remove_rounded,
                size: 18,
                color: isDark ? const Color(0xFF81C784) : const Color(0xFF008435),
              ),
            ),
          ),

          // Tapping middle area opens Custom On-Screen Keypad & Quantity Picker Modal
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showQuantityPickerModal(isEn),
              child: Container(
                height: 52,
                alignment: Alignment.center,
                child: Text(
                  _quantityController.text.isEmpty
                      ? '0'
                      : _quantityController.text,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF19221C),
                  ),
                ),
              ),
            ),
          ),

          // Plus Button (+)
          GestureDetector(
            onTap: _incrementQuantity,
            child: Container(
              width: 34,
              height: 34,
              margin: EdgeInsets.only(right: 6.w),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF233629) : const Color(0xFFF1F8E9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_rounded,
                size: 18,
                color: isDark ? const Color(0xFF81C784) : const Color(0xFF008435),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectField({
    required String value,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF19271E) : Colors.white,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: isDark ? const Color(0xFF2E4D36) : const Color(0xFF81C784),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 20,
                color: isDark ? const Color(0xFF81C784) : const Color(0xFF008435),
              ),
              SizedBox(width: 8.w),
            ],
            Expanded(
              child: Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.5.sp,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF19221C),
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: isDark ? const Color(0xFF81C784) : const Color(0xFF4CAF50),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoragePill(String key, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedStorageArea == key;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStorageArea = key;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF81C784) : const Color(0xFF008435))
              : (isDark ? const Color(0xFF19271E) : Colors.white),
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(
            color: isSelected
                ? (isDark ? const Color(0xFF81C784) : const Color(0xFF008435))
                : (isDark ? const Color(0xFF2E4D36) : const Color(0xFF81C784)),
            width: 1.4,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF008435)
                        .withValues(alpha: isDark ? 0.4 : 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : [],
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5.sp,
            fontWeight: FontWeight.w700,
            color: isSelected
                ? (isDark ? const Color(0xFF0E1611) : Colors.white)
                : (isDark ? Colors.white : const Color(0xFF008435)),
          ),
        ),
      ),
    );
  }
}
