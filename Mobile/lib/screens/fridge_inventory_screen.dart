import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/models/ingredient_model.dart';
import '../data/models/user_models.dart';
import '../l10n/app_localizations.dart';
import '../data/services/api_service.dart';
import 'my_fridges_screen.dart';
import 'recipe_suggestions_screen.dart';
import '../widgets/fridge_members_modal.dart';
import '../widgets/ingredient_avatar_widget.dart';
import '../theme/app_theme.dart';
import '../sqlite/services/ingredient_local_service.dart';
import '../sqlite/models/local_ingredient_model.dart';

class FridgeInventoryScreen extends StatefulWidget {
  final FridgeModel fridge;
  final VoidCallback onRename;
  final bool isEmbedded;

  const FridgeInventoryScreen({
    super.key,
    required this.fridge,
    required this.onRename,
    this.isEmbedded = false,
  });

  @override
  State<FridgeInventoryScreen> createState() => FridgeInventoryScreenState();
}

class FridgeInventoryScreenState extends State<FridgeInventoryScreen> {
  // Compartment Filter: 'All', 'Fridge', 'Freezer', 'Pantry'
  String _selectedStorage = 'All';

  // View Mode: true for Square Grid Cards (as in image 2), false for List rows
  bool _isGridView = true;

  final TextEditingController _searchController = TextEditingController();
  List<IngredientModel> _ingredients = [];
  bool _isLoading = true;
  final ApiService _apiService = ApiService();
  FamilyRoleModel? _familyRole;

  @override
  void initState() {
    super.initState();
    _loadIngredients();
  }

  Future<void> reload() async {
    await _loadIngredients();
  }

  Future<void> _loadIngredients() async {
    setState(() => _isLoading = true);
    final ingredientLocalService = IngredientLocalService();

    try {
      final res = await _apiService.getFridgeItems();
      final list = res.map((e) => IngredientModel.fromFridgeApi(e, widget.fridge.id, widget.fridge.name)).toList();
      
      // Save to SQLite
      final List<LocalIngredientModel> localItems = list.map((item) {
        return LocalIngredientModel(
          id: item.id,
          ingredientId: 0,
          name: item.name,
          quantity: double.tryParse(item.quantity.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 1.0,
          unit: item.unit,
          storageLocation: item.storageArea,
          expiresAt: null,
          daysUntilExpiry: item.daysUntilExpiry,
          imagePath: item.imagePath,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
      }).toList();
      await ingredientLocalService.saveIngredientsCache(localItems);

      FamilyRoleModel? familyRole;
      try {
        final familyRes = await _apiService.getMyFamily();
        familyRole = FamilyRoleModel.fromJson(familyRes);
      } catch (e) {
        debugPrint('Error loading family role in FridgeInventoryScreen: $e');
      }

      if (mounted) {
        setState(() {
          _ingredients = list;
          _familyRole = familyRole;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[FridgeInventoryScreen] Error/Offline loading fridge items: $e. Loading from SQLite...');
      try {
        final cached = await ingredientLocalService.getCachedIngredients();
        final List<IngredientModel> offlineList = cached.map((item) {
          return IngredientModel(
            id: item.id,
            fridgeId: widget.fridge.id,
            fridgeName: widget.fridge.name,
            name: item.name,
            englishName: item.name,
            quantity: '${item.quantity} ${item.unit}',
            unit: item.unit,
            category: 'Thực phẩm',
            storageArea: item.storageLocation,
            daysUntilExpiry: item.daysUntilExpiry ?? 5,
            expiryText: (item.daysUntilExpiry ?? 5) < 0
                ? 'Quá hạn ${(item.daysUntilExpiry ?? 5).abs()} ngày'
                : 'Còn ${item.daysUntilExpiry ?? 5} ngày',
            imagePath: item.imagePath ?? '',
            badgeBgColor: const Color(0xFFE8F5E9),
            badgeTextColor: const Color(0xFF2E7D32),
          );
        }).toList();

        if (mounted) {
          setState(() {
            _ingredients = offlineList;
            _isLoading = false;
          });
        }
      } catch (err) {
        debugPrint('[FridgeInventoryScreen] SQLite read error: $err');
        if (mounted) {
          setState(() {
            _ingredients = [];
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

  // Open Quantity Update Modal Dialog with Numeric Keyboard & +/- Controls
  void _showUpdateQuantityDialog(IngredientModel item, bool isEn) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final qtyNumberController = TextEditingController(
      text: item.quantity.replaceAll(RegExp(r'[^0-9.]'), ''),
    );
    String selectedUnit = item.unit.isNotEmpty
        ? item.unit
        : item.quantity.contains('gram')
            ? 'gram'
            : item.quantity.contains('g')
                ? 'g'
                : item.quantity.contains('kg')
                    ? 'kg'
                    : item.quantity.contains('ml')
                        ? 'ml'
                        : item.quantity.contains('lít') || item.quantity.contains('L')
                            ? 'lít'
                            : 'kg';

    final List<String> availableUnits = [
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
    if (!availableUnits.contains(selectedUnit)) {
      availableUnits.insert(0, selectedUnit);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            double currentVal =
                double.tryParse(qtyNumberController.text) ?? 1.0;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF19271E) : Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  border: isDark
                      ? Border.all(color: const Color(0xFF2E4D36), width: 1.2)
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        IngredientAvatarWidget(item: item, size: 48),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEn ? 'Update Quantity' : 'Cập nhật số lượng',
                                style: GoogleFonts.outfit(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF006428),
                                ),
                              ),
                              Text(
                                item.displayName(isEn),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? const Color(0xFF9DA8A0)
                                      : const Color(0xFF6B786F),
                                ),
                              ),
                            ],
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

                    const SizedBox(height: 20),

                    // Numeric Keyboard & +/- Stepper Row
                    Row(
                      children: [
                        // Minus Button
                        GestureDetector(
                          onTap: () {
                            if (currentVal > 1) {
                              setModalState(() {
                                currentVal -= (selectedUnit == 'g' || selectedUnit == 'gram' || selectedUnit == 'ml' ? 50 : 1);
                                if (currentVal < 0) currentVal = 0;
                                qtyNumberController.text =
                                    currentVal.toInt().toString();
                              });
                            }
                          },
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF233629)
                                  : const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.remove_rounded,
                              color: isDark
                                  ? const Color(0xFF81C784)
                                  : const Color(0xFF008435),
                              size: 26,
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Quantity Numeric TextField (Bàn phím số)
                        Expanded(
                          child: TextField(
                            controller: qtyNumberController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: isDark
                                  ? const Color(0xFF81C784)
                                  : const Color(0xFF006428),
                            ),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? const Color(0xFF2E4D36)
                                      : const Color(0xFF81C784),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? const Color(0xFF81C784)
                                      : const Color(0xFF008435),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Plus Button
                        GestureDetector(
                          onTap: () {
                            setModalState(() {
                              currentVal += (selectedUnit == 'g' || selectedUnit == 'gram' || selectedUnit == 'ml' ? 50 : 1);
                              qtyNumberController.text =
                                  currentVal.toInt().toString();
                            });
                          },
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF81C784)
                                  : const Color(0xFF008435),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              color: isDark
                                  ? const Color(0xFF0E1611)
                                  : Colors.white,
                              size: 26,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Unit Selection Pills (Horizontal Scroll)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: availableUnits.map((unit) {
                          final isSel = selectedUnit == unit;
                          final displayUnit = (unit == 'lít' && isEn) ? 'L' : unit;
                          return GestureDetector(
                            onTap: () {
                              setModalState(() {
                                selectedUnit = unit;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? (isDark
                                        ? const Color(0xFF81C784)
                                        : const Color(0xFF008435))
                                    : (isDark
                                        ? const Color(0xFF233629)
                                        : const Color(0xFFF1F8E9)),
                                borderRadius: BorderRadius.circular(14),
                                border: isSel
                                    ? null
                                    : Border.all(
                                        color: isDark
                                            ? const Color(0xFF2E4D36)
                                            : const Color(0xFFC8E6C9),
                                      ),
                              ),
                              child: Center(
                                child: Text(
                                  displayUnit,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isSel
                                        ? (isDark
                                            ? const Color(0xFF0E1611)
                                            : Colors.white)
                                        : (isDark
                                            ? Colors.white
                                            : const Color(0xFF008435)),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark
                              ? const Color(0xFF81C784)
                              : const Color(0xFF008435),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: () async {
                          final valStr = qtyNumberController.text.trim();
                          if (valStr.isNotEmpty) {
                            final numVal = double.tryParse(valStr) ?? 1.0;
                            try {
                              await _apiService.updateFridgeItem(item.id, {
                                'quantity': numVal,
                                'unit': selectedUnit,
                              });
                            } catch (e) {
                              debugPrint('API Update quantity error: $e');
                            }
                            _loadIngredients();
                          }
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: Text(
                          isEn ? 'Save' : 'Lưu thay đổi',
                          style: GoogleFonts.outfit(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? const Color(0xFF0E1611)
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: Color(0xFF4CAF50)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF4CAF50), size: 18),
                            label: Text(
                              isEn ? 'Used All' : 'Đã dùng hết',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF4CAF50),
                              ),
                            ),
                            onPressed: () async {
                              try {
                                await _apiService.consumeFridgeItem(item.id);
                              } catch (e) {
                                debugPrint('API Consume item error: $e');
                              }
                              _loadIngredients();
                              if (context.mounted) Navigator.pop(context);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: Color(0xFFE57373)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE57373), size: 18),
                            label: Text(
                              isEn ? 'Delete' : 'Xóa khỏi tủ',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFE57373),
                              ),
                            ),
                            onPressed: () async {
                              try {
                                await _apiService.deleteFridgeItem(item.id);
                              } catch (e) {
                                debugPrint('API Delete item error: $e');
                              }
                              _loadIngredients();
                              if (context.mounted) Navigator.pop(context);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _translateFridgeName(String name, bool isEn) {
    return isEn ? 'Fridge' : 'Tủ lạnh';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final isEn = loc?.locale.languageCode == 'en';
    final canPop = Navigator.canPop(context);

    final fridgeDisplayName = _translateFridgeName(widget.fridge.name, isEn);

    final validItems = _ingredients.where((i) => !i.isExpired).toList();
    final currentList = validItems;

    final query = _searchController.text.trim().toLowerCase();
    final filteredItems = currentList.where((item) {
      final matchesStorage =
          _selectedStorage == 'All' || item.storageArea == _selectedStorage;
      final matchesSearch = query.isEmpty ||
          item.name.toLowerCase().contains(query) ||
          item.englishName.toLowerCase().contains(query);
      return matchesStorage && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: widget.isEmbedded
            ? null
            : BoxDecoration(
                gradient: AppGradients.getBackground(isDark),
              ),
        child: SafeArea(
          child: Column(
            children: [
              // 1. Top App Bar Header
              Padding(
                padding: const EdgeInsets.only(
                  left: 20.0,
                  right: 20.0,
                  top: 10.0,
                  bottom: 12.0,
                ),
                child: Row(
                  children: [
                    if (canPop) ...[
                      // Back Glass Button
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF19271E)
                                : Colors.white.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF2E4D36)
                                  : const Color(0xFFA5E69C).withValues(alpha: 0.6),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.chevron_left_rounded,
                            size: 26,
                            color: isDark ? Colors.white : const Color(0xFF006428),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                ),
                                children: isEn
                                    ? [
                                        TextSpan(
                                          text: 'Fri',
                                          style: TextStyle(
                                            color: isDark ? Colors.white : const Color(0xFF19221C),
                                          ),
                                        ),
                                        TextSpan(
                                          text: 'dge',
                                          style: TextStyle(
                                            color: isDark ? const Color(0xFF81C784) : const Color(0xFF4CAF50),
                                          ),
                                        ),
                                      ]
                                    : [
                                        TextSpan(
                                          text: 'Tủ ',
                                          style: TextStyle(
                                            color: isDark ? Colors.white : const Color(0xFF19221C),
                                          ),
                                        ),
                                        TextSpan(
                                          text: 'lạnh',
                                          style: TextStyle(
                                            color: isDark ? const Color(0xFF81C784) : const Color(0xFF4CAF50),
                                          ),
                                        ),
                                      ],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Group Members Pill Badge
                    if (_familyRole?.group != null && (_familyRole?.role == 'owner' || _familyRole?.role == 'member'))
                      GestureDetector(
                        onTap: () {
                          showFridgeMembersModal(
                            context,
                            fridgeName: fridgeDisplayName,
                            members: widget.fridge.members,
                            onAddMember: (newMem) {
                              setState(() {
                                widget.fridge.members.add(newMem);
                              });
                            },
                            onRemoveMember: (memId) {
                              setState(() {
                                widget.fridge.members
                                    .removeWhere((m) => m.id == memId);
                              });
                            },
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF19271E)
                                : Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF2E4D36)
                                  : const Color(0xFFA5E69C),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.group_rounded,
                                size: 15,
                                color: isDark
                                    ? const Color(0xFF81C784)
                                    : const Color(0xFF008435),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${_familyRole!.group!.activeCount}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: isDark
                                      ? const Color(0xFF81C784)
                                      : const Color(0xFF008435),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // 2. Premium Search Bar (Left) & Glowing AI Recipe Button (Right)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  children: [
                    // Crisp Search Pill Bar
                    Expanded(
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF19271E) : Colors.white,
                          borderRadius: BorderRadius.circular(23),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF2E4D36)
                                : const Color(0xFFA5D6A7),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() {}),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF19221C),
                          ),
                          decoration: InputDecoration(
                            hintText: isEn ? 'Search items...' : 'Tìm thực phẩm...',
                            hintStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: isDark
                                  ? const Color(0xFF9DA8A0)
                                  : const Color(0xFFA5D6A7),
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: isDark
                                  ? const Color(0xFF81C784)
                                  : const Color(0xFF008435),
                              size: 20,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Glowing Solid Emerald Gradient AI "Gợi Ý Món Ăn" Button
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RecipeSuggestionsScreen(
                              availableIngredients: validItems
                                  .map((e) => e.name)
                                  .toList(),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? const [Color(0xFF2E7D32), Color(0xFF1B5E20)]
                                : const [Color(0xFF009639), Color(0xFF006428)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(23),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF008435).withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.auto_awesome_rounded,
                              color: Colors.white,
                              size: 17,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isEn ? 'Recipes' : 'Gợi Ý Món Ăn',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 5. Compartment Filter Pills & View Mode Toggle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          {'key': 'All', 'label': isEn ? 'All' : 'Tất cả'},
                          {'key': 'Fridge', 'label': isEn ? 'Cooler' : 'Ngăn mát'},
                          {'key': 'Freezer', 'label': isEn ? 'Freezer' : 'Ngăn đông'},
                          {'key': 'Pantry', 'label': isEn ? 'Pantry' : 'Tủ khô'},
                        ].map((item) {
                          final key = item['key']!;
                          final label = item['label']!;
                          final isSelected = _selectedStorage == key;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedStorage = key),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                height: 36,
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF008435)
                                      : (isDark ? const Color(0xFF19271E) : Colors.white),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF008435)
                                        : (isDark ? const Color(0xFF2E4D36) : const Color(0xFF81C784)),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  label,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.0,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark ? Colors.white : const Color(0xFF008435)),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // View Mode Toggle (Grid / List)
                    GestureDetector(
                      onTap: () => setState(() => _isGridView = !_isGridView),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF19271E) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? const Color(0xFF2E4D36) : const Color(0xFF81C784),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                          size: 20,
                          color: isDark ? const Color(0xFF81C784) : const Color(0xFF008435),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 6. Food Items Display (Square Cards Grid / List View)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: RefreshIndicator(
                    color: const Color(0xFF008435),
                    onRefresh: _loadIngredients,
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF008435),
                            ),
                          )
                        : filteredItems.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(
                                    height: MediaQuery.of(context).size.height * 0.4,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.kitchen_outlined,
                                          size: 56,
                                          color: Colors.white.withValues(alpha: 0.6),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          isEn ? 'No food items found' : 'Không tìm thấy thực phẩm nào',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : _isGridView
                                ? _buildGridView(filteredItems, isEn, isDark)
                              : ListView.separated(
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.only(bottom: 120),
                                  itemCount: filteredItems.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final item = filteredItems[index];

                                    return GestureDetector(
                                      onTap: () => _showUpdateQuantityDialog(item, isEn),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF19271E) : Colors.white,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFA5E69C),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            // Food Image Avatar
                                            IngredientAvatarWidget(item: item, size: 54),

                                            const SizedBox(width: 14),

                                            // Food Name & Quantity
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        item.displayName(isEn),
                                                        style: GoogleFonts.outfit(
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color: isDark
                                                              ? Colors.white
                                                              : const Color(0xFF19221C),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      const Icon(
                                                        Icons.edit_rounded,
                                                        size: 14,
                                                        color: Color(0xFF81C784),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    item.quantity,
                                                    style:
                                                        GoogleFonts.plusJakartaSans(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                      color: isDark
                                                          ? const Color(0xFF9DA8A0)
                                                          : const Color(0xFF6B786F),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Expiry Status Badge Pill
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 7,
                                              ),
                                              decoration: BoxDecoration(
                                                color: item.badgeBgColor,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                item.expiryStatusText(isEn),
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: item.badgeTextColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
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
    return GestureDetector(
      onTap: () => _showUpdateQuantityDialog(item, isEn),
      child: Container(
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
                    item.displayName(isEn),
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
                    item.quantity,
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
                  item.expiryStatusText(isEn),
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
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.only(bottom: 120),
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
