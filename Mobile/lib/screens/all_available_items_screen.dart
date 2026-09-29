import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/models/ingredient_model.dart';
import '../l10n/app_localizations.dart';
import 'recipe_suggestions_screen.dart';
import '../data/services/api_service.dart';
import '../widgets/ingredient_avatar_widget.dart';
import '../sqlite/services/ingredient_local_service.dart';

class AllAvailableItemsScreen extends StatefulWidget {
  const AllAvailableItemsScreen({super.key});

  @override
  State<AllAvailableItemsScreen> createState() =>
      _AllAvailableItemsScreenState();
}

class _AllAvailableItemsScreenState extends State<AllAvailableItemsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ApiService _apiService = ApiService();
  List<IngredientModel> _availableItems = [];
  bool _isGridView = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    final ingredientLocalService = IngredientLocalService();
    try {
      final res = await _apiService.getFridgeItems();
      final list = res.map((e) => IngredientModel.fromFridgeApi(e)).where((i) => !i.isExpired).toList();
      if (mounted) {
        setState(() {
          _availableItems = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[AllAvailableItemsScreen] Error/Offline loading available items: $e. Loading from SQLite...');
      try {
        final cached = await ingredientLocalService.getCachedIngredients();
        final List<IngredientModel> offlineAvailable = cached
            .where((item) => (item.daysUntilExpiry ?? 5) >= 0)
            .map((item) {
          return IngredientModel(
            id: item.id,
            fridgeId: '1',
            fridgeName: 'Tủ lạnh',
            name: item.name,
            englishName: item.name,
            quantity: '${item.quantity} ${item.unit}',
            unit: item.unit,
            category: 'Thực phẩm',
            storageArea: item.storageLocation,
            daysUntilExpiry: item.daysUntilExpiry ?? 5,
            expiryText: 'Còn ${item.daysUntilExpiry ?? 5} ngày',
            imagePath: item.imagePath ?? '',
            badgeBgColor: const Color(0xFFE8F5E9),
            badgeTextColor: const Color(0xFF2E7D32),
          );
        }).toList();

        if (mounted) {
          setState(() {
            _availableItems = offlineAvailable;
            _isLoading = false;
          });
        }
      } catch (err) {
        debugPrint('[AllAvailableItemsScreen] SQLite read error: $err');
        if (mounted) {
          setState(() {
            _availableItems = [];
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getLocalizedFridgeName(String name, bool isEn) {
    if (!isEn) return name;
    if (name.contains('Gia Đình')) return 'Family Fridge';
    if (name.contains('Phòng Trọ')) return 'Dorm Fridge';
    if (name.contains('Cá Nhân')) return 'Personal Fridge';
    return name;
  }

  String _getLocalizedQuantity(String q, bool isEn) {
    if (!isEn) return q;
    return q.replaceAll('hộp', 'boxes').replaceAll('lít', 'L').replaceAll('quả', 'pcs');
  }

  String _getLocalizedExpiry(String exp, bool isEn) {
    if (!isEn) return exp;
    if (exp.contains('Còn 1 ngày')) return '1 day left';
    if (exp.contains('Còn')) {
      return exp.replaceAll('Còn ', '').replaceAll(' ngày', ' days left');
    }
    return exp;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final isEn = loc?.locale.languageCode == 'en';

    final query = _searchController.text.trim().toLowerCase();
    final filteredItems = _availableItems.where((item) {
      return query.isEmpty ||
          item.name.toLowerCase().contains(query) ||
          item.englishName.toLowerCase().contains(query);
    }).toList();

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
              // 1. Top Header with Back Chevron
              Padding(
                padding: const EdgeInsets.only(
                  left: 8.0,
                  right: 16.0,
                  top: 8.0,
                  bottom: 8.0,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.chevron_left_rounded,
                        size: 34,
                        color: isDark ? Colors.white : const Color(0xFF19221C),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      isEn ? 'Available Ingredients' : 'Nguyên Liệu Sẵn Có',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF006428),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 4),

              // Title & Total Badge Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEn ? 'All Fresh Food' : 'Tất cả thực phẩm tươi',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFF006428),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isEn ? 'Combined from all your fridges' : 'Tổng hợp từ tất cả các tủ lạnh của bạn',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFF9DA8A0)
                                  : const Color(0xFF1B5E20),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF008435),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF008435)
                                .withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        isEn ? '${_availableItems.length} items' : '${_availableItems.length} món',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Quick Action Bar (Meal Suggestions)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RecipeSuggestionsScreen(
                          availableIngredients:
                              _availableItems.map((e) => e.name).toList(),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF19271E) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF2E4D36)
                            : const Color(0xFF008435),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.soup_kitchen_rounded,
                          color: isDark
                              ? const Color(0xFF81C784)
                              : const Color(0xFF008435),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isEn
                              ? 'AI Recipe suggestions from all food'
                              : 'Gợi ý món ăn AI từ tất cả thực phẩm',
                          style: GoogleFonts.outfit(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? const Color(0xFF81C784)
                                : const Color(0xFF008435),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Search Bar & View Mode Toggle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF19271E) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? const Color(0xFF2E4D36) : const Color(0xFF81C784),
                            width: 1.2,
                          ),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() {}),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF19221C),
                          ),
                          decoration: InputDecoration(
                            hintText: isEn ? 'Search ingredients in fridge...' : 'Tìm kiếm nguyên liệu trong tủ...',
                            hintStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              color: isDark ? const Color(0xFF9DA8A0) : const Color(0xFFA5D6A7),
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: isDark ? const Color(0xFF81C784) : const Color(0xFF4CAF50),
                              size: 22,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // View Mode Toggle
                    GestureDetector(
                      onTap: () => setState(() => _isGridView = !_isGridView),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF19271E) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? const Color(0xFF2E4D36) : const Color(0xFF81C784),
                            width: 1.2,
                          ),
                        ),
                        child: Icon(
                          _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                          size: 22,
                          color: isDark ? const Color(0xFF81C784) : const Color(0xFF008435),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Available Items List / Grid Across All Fridges
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF008435)))
                      : _isGridView
                          ? _buildGridView(filteredItems, isEn, isDark)
                          : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          itemCount: filteredItems.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            final name = isEn && item.englishName.isNotEmpty ? item.englishName : item.name;
                            final fName = _getLocalizedFridgeName(item.fridgeName, isEn);
                            final qty = _getLocalizedQuantity(item.quantity, isEn);
                            final exp = _getLocalizedExpiry(item.expiryText, isEn);

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF19271E) : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: isDark
                                    ? Border.all(
                                        color: const Color(0xFF2E4D36), width: 1)
                                    : null,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  IngredientAvatarWidget(item: item, size: 54),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: GoogleFonts.outfit(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? Colors.white : const Color(0xFF19221C),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$fName • $qty',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? const Color(0xFF9DA8A0)
                                                : const Color(0xFF6B786F),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? item.badgeBgColor.withValues(alpha: 0.2)
                                          : item.badgeBgColor,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      exp,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? const Color(0xFF81C784)
                                            : item.badgeTextColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getCategoryDisplayName(String catKey, bool isEn) {
    switch (catKey.toLowerCase()) {
      case 'vegetables':
        return isEn ? 'Vegetables' : 'Rau củ';
      case 'fruit':
      case 'fruits':
        return isEn ? 'Fruits' : 'Trái cây';
      case 'meat':
        return isEn ? 'Meat' : 'Thịt';
      case 'dairy':
        return isEn ? 'Dairy & Eggs' : 'Sữa & Trứng';
      case 'seafood':
        return isEn ? 'Seafood' : 'Hải sản';
      default:
        return isEn ? 'Others' : 'Khác';
    }
  }

  Widget _buildSquareFoodCard(IngredientModel item, bool isEn, bool isDark) {
    final name = isEn && item.englishName.isNotEmpty ? item.englishName : item.name;
    final qty = _getLocalizedQuantity(item.quantity, isEn);
    final exp = _getLocalizedExpiry(item.expiryText, isEn);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF19271E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? const Color(0xFF2E4D36)
              : const Color(0xFFA5E69C).withValues(alpha: 0.8),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 14),
                Expanded(
                  child: Center(
                    child: IngredientAvatarWidget(item: item, size: 54),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF19221C),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  qty,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFF9DA8A0)
                        : const Color(0xFF6B786F),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 7,
            right: 7,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 7,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? item.badgeBgColor.withValues(alpha: 0.25)
                    : item.badgeBgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                exp,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: item.badgeTextColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridView(List<IngredientModel> filteredItems, bool isEn, bool isDark) {
    final Map<String, List<IngredientModel>> categoryMap = {};
    for (var item in filteredItems) {
      categoryMap.putIfAbsent(item.category, () => []).add(item);
    }
    final categories = categoryMap.keys.toList();

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: categories.length,
      itemBuilder: (context, catIdx) {
        final categoryKey = categories[catIdx];
        final items = categoryMap[categoryKey]!;
        final categoryTitle = _getCategoryDisplayName(categoryKey, isEn);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: const Color(0xFF008435),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    categoryTitle,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF19221C),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '(${items.length})',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF9DA8A0) : const Color(0xFF6B786F),
                    ),
                  ),
                ],
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 10,
                childAspectRatio: 0.78,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                return _buildSquareFoodCard(items[index], isEn, isDark);
              },
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}
