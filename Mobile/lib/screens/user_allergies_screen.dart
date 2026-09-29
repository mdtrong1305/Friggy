import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../data/models/user_models.dart';
import '../data/services/api_exception.dart';
import '../data/services/api_service.dart';
import '../l10n/app_localizations.dart';
import '../sqlite/models/local_allergy_model.dart';
import '../sqlite/models/local_ingredient_catalog_model.dart';
import '../sqlite/services/allergy_local_service.dart';
import '../sqlite/services/ingredient_catalog_local_service.dart';

class UserAllergiesScreen extends StatefulWidget {
  const UserAllergiesScreen({super.key});

  @override
  State<UserAllergiesScreen> createState() => _UserAllergiesScreenState();
}

class _UserAllergiesScreenState extends State<UserAllergiesScreen> {
  final ApiService _apiService = ApiService();
  final AllergyLocalService _allergyLocalService = AllergyLocalService();
  bool _isLoading = true;
  List<AllergyModel> _allergies = [];

  @override
  void initState() {
    super.initState();
    _fetchAllergies();
  }

  Future<void> _fetchAllergies() async {
    // Hiển thị ngay từ SQLite cache trước khi gọi API
    final cachedFirst = await _allergyLocalService.getCachedAllergies();
    if (cachedFirst.isNotEmpty && mounted) {
      setState(() {
        _allergies = cachedFirst.map((c) => AllergyModel(
          id: c.id,
          ingredientId: c.ingredientId,
          ingredientName: c.ingredientName,
          note: c.note,
        )).toList();
        _isLoading = false;
      });
      debugPrint('[UserAllergiesScreen] Pre-loaded ${cachedFirst.length} allergies from SQLite.');
    }

    try {
      final list = await _apiService.getAllergies();
      if (mounted) {
        setState(() {
          _allergies = list.map((item) => AllergyModel.fromJson(item)).toList();
          _isLoading = false;
        });
      }
      // Cập nhật SQLite cache với data mới nhất
      await _allergyLocalService.saveAllergiesCache(
        _allergies.map((a) => LocalAllergyModel(
          id: a.id,
          ingredientId: a.ingredientId,
          ingredientName: a.ingredientName,
          note: a.note,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        )).toList(),
      );
    } catch (e) {
      debugPrint('[UserAllergiesScreen] API error, using SQLite: $e');
      // Nếu trước đó SQLite đã có → giữ nguyên
      if (_allergies.isNotEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // SQLite chưa có (BackgroundSync chưa xong) → đợi 2s rồi thử lại
      await Future.delayed(const Duration(seconds: 2));
      final cached = await _allergyLocalService.getCachedAllergies();
      if (mounted) {
        setState(() {
          if (cached.isNotEmpty) {
            _allergies = cached.map((c) => AllergyModel(
              id: c.id,
              ingredientId: c.ingredientId,
              ingredientName: c.ingredientName,
              note: c.note,
            )).toList();
            debugPrint('[UserAllergiesScreen] Retry: loaded ${cached.length} from SQLite.');
          }
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _removeAllergy(AllergyModel allergy) async {
    // Xóa khỏi UI ngay lập tức (optimistic)
    setState(() {
      _allergies.removeWhere((a) => a.id == allergy.id);
    });

    try {
      await _apiService.removeAllergy(allergy.id);
      // Online: xóa API thành công → xóa luôn khỏi SQLite
      await _allergyLocalService.deleteAllergyFromCache(allergy.id);
      debugPrint('[UserAllergiesScreen] Allergy "${allergy.ingredientName}" deleted from API + SQLite.');
    } on ApiException catch (e) {
      if (e.isNetworkError) {
        // Offline: đánh dấu pending_delete → UI đã ẩn rồi, sẽ xóa server khi online
        await _allergyLocalService.markPendingDelete(allergy.id);
        debugPrint('[UserAllergiesScreen] Offline: allergy "${allergy.ingredientName}" marked pending_delete.');
      } else {
        // Lỗi server → rollback UI và hiện lỗi
        setState(() => _allergies.add(allergy));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Không thể xóa: ${e.message}'),
              backgroundColor: const Color(0xFFD32F2F),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      // Lỗi không xác định → xem như offline
      await _allergyLocalService.markPendingDelete(allergy.id);
      debugPrint('[UserAllergiesScreen] Unexpected error, marked pending_delete: $e');
    }
  }

  void _showAddAllergyModal() {
    showModalBottomSheet<AllergyModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return const _AddAllergyModal();
      },
    ).then((newAllergy) {
      if (newAllergy != null && mounted) {
        setState(() {
          _allergies.add(newAllergy);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã thêm dị ứng "${newAllergy.ingredientName}" thành công!'),
            backgroundColor: const Color(0xFF008435),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final isEn = loc?.locale.languageCode == 'en';

    final titleColor = isDark ? const Color(0xFF81C784) : const Color(0xFF006428);
    final cardBg = isDark ? const Color(0xFF19271E) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF2E4D36) : const Color(0xFFA5E69C);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAllergyModal,
        backgroundColor: isDark ? const Color(0xFF81C784) : const Color(0xFF4CAF50),
        icon: Icon(Icons.add_rounded, color: isDark ? const Color(0xFF0E1611) : Colors.white),
        label: Text(
          isEn ? 'Add Allergy' : 'Thêm dị ứng',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: isDark ? const Color(0xFF0E1611) : Colors.white,
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [Color(0xFF0E1611), Color(0xFF142017), Color(0xFF1B2E21)]
                : const [Color(0xFFFFFFFF), Color(0xFFF5FCF4), Color(0xFFC7EFC2), Color(0xFF86D978)],
            stops: isDark ? const [0.0, 0.5, 1.0] : const [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
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
                          color: cardBg,
                          shape: BoxShape.circle,
                          border: Border.all(color: cardBorder, width: 1.2),
                        ),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: isDark ? const Color(0xFF81C784) : const Color(0xFF006428),
                          size: 22,
                        ),
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Text(
                      isEn ? 'Food Allergies' : 'Dị ứng thực phẩm',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w900,
                        color: titleColor,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50)))
                    : _allergies.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.shield_outlined,
                                  size: 64,
                                  color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFA5D6A7),
                                ),
                                SizedBox(height: 14.h),
                                Text(
                                  isEn ? 'No food allergies recorded' : 'Chưa ghi nhận dị ứng thực phẩm nào',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white70 : const Color(0xFF424242),
                                  ),
                                ),
                                SizedBox(height: 6.h),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 32.0),
                                  child: Text(
                                    isEn
                                        ? 'Add ingredients you are allergic to so Friggy can filter recipes for you!'
                                        : 'Bấm nút "Thêm dị ứng" bên dưới để chọn món dị ứng và được Friggy cảnh báo!',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13.sp,
                                      color: isDark ? const Color(0xFF9DA8A0) : const Color(0xFF757575),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.symmetric(horizontal: 20.0.w, vertical: 12.0.h),
                            itemCount: _allergies.length,
                            itemBuilder: (context, index) {
                              final allergy = _allergies[index];
                              return Container(
                                margin: EdgeInsets.only(bottom: 12.h),
                                padding: EdgeInsets.all(16.w),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(20.r),
                                  border: Border.all(color: cardBorder, width: 1.2),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(10.w),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF3E1E1E) : const Color(0xFFFFEBEE),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.warning_amber_rounded,
                                        color: Color(0xFFD32F2F),
                                        size: 22,
                                      ),
                                    ),
                                    SizedBox(width: 14.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            allergy.ingredientName,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 16.sp,
                                              fontWeight: FontWeight.w800,
                                              color: isDark ? Colors.white : const Color(0xFF19221C),
                                            ),
                                          ),
                                          if (allergy.note != null && allergy.note!.isNotEmpty)
                                            Padding(
                                              padding: EdgeInsets.only(top: 4.0.h),
                                              child: Text(
                                                allergy.note!,
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 13.sp,
                                                  color: isDark ? const Color(0xFF9DA8A0) : const Color(0xFF757575),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFD32F2F)),
                                      onPressed: () => _removeAllergy(allergy),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Ingredient Selector Modal for Adding Allergy
// ----------------------------------------------------------------------------
class _AddAllergyModal extends StatefulWidget {
  const _AddAllergyModal();

  @override
  State<_AddAllergyModal> createState() => _AddAllergyModalState();
}

class _AddAllergyModalState extends State<_AddAllergyModal> {
  final ApiService _apiService = ApiService();
  final AllergyLocalService _allergyLocalService = AllergyLocalService();
  final IngredientCatalogLocalService _catalogService = IngredientCatalogLocalService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  Timer? _debounceTimer;

  bool _isLoadingIngredients = true;
  bool _isSubmitting = false;
  bool _isOffline = false;

  List<dynamic> _allIngredients = [];
  List<dynamic> _filteredIngredients = [];
  Map<String, dynamic>? _selectedIngredient;

  @override
  void initState() {
    super.initState();
    _loadIngredients();
  }

  Future<void> _loadIngredients() async {
    try {
      final list = await _apiService.getIngredients(limit: 100);
      if (mounted) {
        setState(() {
          _allIngredients = list;
          _filteredIngredients = list;
          _isOffline = false;
        });
        // Cache lên SQLite để dùng offline sau
        _catalogService.saveCatalogCache(
          list.cast<Map<String, dynamic>>().map((item) {
            return LocalIngredientCatalogModel(
              id: (item['id'] as num?)?.toInt() ?? 0,
              name: item['name'] as String? ?? '',
              englishName: item['englishName'] as String?,
              defaultUnit: item['defaultUnit'] as String?,
              category: item['category'] as String?,
              imagePath: item['imagePath'] as String?,
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            );
          }).where((i) => i.id > 0 && i.name.isNotEmpty).toList(),
        );
      }
    } catch (e) {
      // Offline: load từ SQLite catalog
      debugPrint('[_AddAllergyModal] Offline, loading from SQLite catalog: $e');
      final cached = await _catalogService.getAllCatalog(limit: 200);
      debugPrint('[_AddAllergyModal] SQLite catalog size: ${cached.length}');
      if (mounted) {
        final catalogList = cached.map((c) => c.toApiFormat()).toList();
        setState(() {
          _allIngredients = catalogList;
          _filteredIngredients = catalogList;
          _isOffline = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingIngredients = false);
      }
    }
  }

  void _filterIngredients(String query) {
    _debounceTimer?.cancel();
    final q = query.trim();
    if (q.isEmpty) {
      setState(() => _filteredIngredients = _allIngredients);
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (_isOffline) {
        // Offline: tìm trong SQLite catalog
        final results = await _catalogService.searchCatalog(q);
        if (mounted) {
          setState(() {
            _filteredIngredients = results.map((c) => c.toApiFormat()).toList();
          });
        }
      } else {
        try {
          final list = await _apiService.getIngredients(search: q, limit: 100);
          if (mounted) {
            setState(() {
              _filteredIngredients = list;
            });
          }
        } catch (e) {
          // Mạng bị mất giữa chừng → fallback SQLite
          final results = await _catalogService.searchCatalog(q);
          if (mounted) {
            setState(() {
              _filteredIngredients = results.map((c) => c.toApiFormat()).toList();
              _isOffline = true;
            });
          }
        }
      }
    });
  }

  Future<void> _submit() async {
    if (_selectedIngredient == null) return;
    final int ingredientId = _selectedIngredient!['id'] as int;
    final String ingredientName = _selectedIngredient!['name'] as String? ?? '';
    final String note = _noteController.text.trim();

    setState(() => _isSubmitting = true);

    if (_isOffline) {
      // === OFFLINE: Lưu vào SQLite với sync_status = 'pending' ===
      final localId = 'local_${const Uuid().v4()}';
      final offlineAllergy = LocalAllergyModel(
        id: localId,
        ingredientId: ingredientId,
        ingredientName: ingredientName,
        note: note.isEmpty ? null : note,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        syncStatus: 'pending',
      );
      await _allergyLocalService.saveOfflineAllergy(offlineAllergy);

      // Trả về AllergyModel để hiển thị ngay trên danh sách
      final pendingAllergy = AllergyModel(
        id: localId,
        ingredientId: ingredientId,
        ingredientName: ingredientName,
        note: note.isEmpty ? null : note,
      );
      if (mounted) {
        Navigator.pop(context, pendingAllergy);
      }
      return;
    }

    // === ONLINE: gọi API bình thường ===
    try {
      final result = await _apiService.addAllergy(
        ingredientId,
        note,
      );
      final newAllergy = AllergyModel.fromJson(result);
      // Lưu vào SQLite (synced)
      await _allergyLocalService.saveOfflineAllergy(LocalAllergyModel(
        id: newAllergy.id,
        ingredientId: newAllergy.ingredientId,
        ingredientName: newAllergy.ingredientName,
        note: newAllergy.note,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        syncStatus: 'synced',
      ));
      if (mounted) {
        Navigator.pop(context, newAllergy);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: const Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể thêm dị ứng nguyên liệu. Vui lòng thử lại!'),
            backgroundColor: Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    final bgColor = isDark ? const Color(0xFF19271E) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF2E4D36) : const Color(0xFFA5E69C);

    return Container(
      height: MediaQuery.of(context).size.height * 0.78 + bottomPadding,
      padding: EdgeInsets.only(
        left: 20.w,
        right: 20.w,
        top: 20.h,
        bottom: bottomPadding + 20,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle indicator
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white30 : Colors.black26,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          SizedBox(height: 16.h),

          Text(
            'Thêm dị ứng nguyên liệu',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF006428),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Chọn nguyên liệu gây dị ứng từ danh sách bên dưới:',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.sp,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          SizedBox(height: 14.h),

          // Search Bar
          TextField(
            controller: _searchController,
            onChanged: _filterIngredients,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: 'Tìm tên món / nguyên liệu (VD: Tôm, Trứng, Sữa...)',
              hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 13.5),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF4CAF50)),
              filled: true,
              fillColor: isDark ? const Color(0xFF0E1611) : const Color(0xFFF5FCF4),
              contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.r),
                borderSide: BorderSide(color: cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.r),
                borderSide: BorderSide(color: cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.r),
                borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 1.8),
              ),
            ),
          ),
          SizedBox(height: 12.h),

          // Ingredients List View
          Expanded(
            child: _isLoadingIngredients
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50)))
                : _filteredIngredients.isEmpty
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24.w),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isOffline ? Icons.wifi_off_rounded : Icons.search_off_rounded,
                                size: 48,
                                color: isDark ? Colors.white30 : Colors.black26,
                              ),
                              SizedBox(height: 12.h),
                              Text(
                                _isOffline
                                    ? 'Chưa có danh sách nguyên liệu offline'
                                    : 'Không tìm thấy nguyên liệu phù hợp',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (_isOffline) ...[
                                SizedBox(height: 8.h),
                                Text(
                                  'Vui lòng kết nối mạng một lần để tải danh sách nguyên liệu vào bộ nhớ máy',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.sp,
                                    color: isDark ? Colors.white38 : Colors.black38,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredIngredients.length,
                        itemBuilder: (context, index) {
                          final item = _filteredIngredients[index];
                          final String name = item['name'] as String? ?? 'Nguyên liệu';
                          final String? unit = item['defaultUnit'] as String?;
                          final bool isSelected = _selectedIngredient?['id'] == item['id'];

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedIngredient = item;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: EdgeInsets.only(bottom: 8.h),
                              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isDark ? const Color(0xFF1E3A26) : const Color(0xFFE8F5E9))
                                    : (isDark ? const Color(0xFF0E1611) : const Color(0xFFF9FBF9)),
                                borderRadius: BorderRadius.circular(16.r),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF4CAF50) : cardBorder,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.restaurant_rounded, color: Color(0xFF4CAF50), size: 20),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15.sp,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                        color: isDark ? Colors.white : const Color(0xFF19221C),
                                      ),
                                    ),
                                  ),
                                  if (unit != null && unit.isNotEmpty)
                                    Text(
                                      '($unit)',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: isDark ? Colors.white38 : Colors.black38,
                                      ),
                                    ),
                                  if (isSelected) ...[
                                    SizedBox(width: 10.w),
                                    const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 22),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          SizedBox(height: 12.h),

          // Note input
          TextField(
            controller: _noteController,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: 'Ghi chú dị ứng (VD: Nổi mề đay, dị ứng nặng...)',
              hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 13),
              filled: true,
              fillColor: isDark ? const Color(0xFF0E1611) : const Color(0xFFF5FCF4),
              contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.r),
                borderSide: BorderSide(color: cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.r),
                borderSide: BorderSide(color: cardBorder),
              ),
            ),
          ),

          SizedBox(height: 16.h),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: (_selectedIngredient == null || _isSubmitting) ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF008435),
                disabledBackgroundColor: Colors.grey.withValues(alpha: 0.3),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
              ),
              child: _isSubmitting
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : Text(
                      _selectedIngredient != null
                          ? 'Thêm dị ứng: ${_selectedIngredient!['name']}'
                          : 'Vui lòng chọn một nguyên liệu',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
