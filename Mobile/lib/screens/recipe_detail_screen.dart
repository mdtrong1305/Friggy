import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_constants.dart';
import '../data/models/recipe_model.dart';
import '../l10n/app_localizations.dart';
import '../widgets/friggy_app_bar.dart';

class RecipeDetailScreen extends StatefulWidget {
  final RecipeModel recipe;
  final String? slotId;

  const RecipeDetailScreen({
    super.key,
    required this.recipe,
    this.slotId,
  });

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late RecipeModel _recipe;

  bool _isLoadingDetail = false;

  @override
  void initState() {
    super.initState();
    _recipe = widget.recipe;
    _loadFullRecipeDetail();
  }

  Future<void> _loadFullRecipeDetail() async {
    final targetId = widget.recipe.id;
    final slotId = widget.slotId;

    if ((targetId.isEmpty || targetId.startsWith('rec_')) &&
        (slotId == null || slotId.isEmpty || slotId.startsWith('rec_'))) {
      return;
    }

    setState(() => _isLoadingDetail = true);
    try {
      final fullDetail = await RecipeRepository.fetchRecipeDetail(targetId, slotId: slotId);
      if (fullDetail != null && mounted) {
        setState(() {
          _recipe = fullDetail;
          _isLoadingDetail = false;
        });
      } else if (mounted) {
        setState(() => _isLoadingDetail = false);
      }
    } catch (e) {
      debugPrint('[RecipeDetailScreen] Error loading recipe detail: $e');
      if (mounted) setState(() => _isLoadingDetail = false);
    }
  }

  String _translateIngredientName(String name, bool isEn) {
    if (!isEn) return name;
    final map = {
      'Trứng gà': 'Eggs',
      'Cà chua bi': 'Cherry Tomatoes',
      'Cà chua': 'Tomatoes',
      'Hành lá': 'Green Onion',
      'Gia vị': 'Seasonings',
      'Gia Vị': 'Seasonings',
      'Dưa chuột': 'Cucumber',
      'Xà lách': 'Lettuce',
      'Ngô': 'Corn',
      'Cà rốt': 'Carrots',
      'Súp lơ': 'Broccoli',
      'Bắp cải': 'Cabbage',
    };
    return map[name] ?? name;
  }

  String _translateQuantity(String q, bool isEn) {
    if (!isEn) return q;
    return q
        .replaceAll('quả', 'pcs')
        .replaceAll('Muối, nước mắm, tiêu', 'Salt, fish sauce, pepper')
        .replaceAll('Sốt mè rang', 'Sesame dressing')
        .replaceAll('Vừa đủ', 'As needed')
        .replaceAll('Đầy đủ', 'In full');
  }

  String _translateStep(String step, bool isEn) {
    if (!isEn) return step;
    if (step.contains('Sơ chế')) return 'Clean and prepare all ingredients.';
    if (step.contains('Chế biến')) return 'Cook and season to taste.';
    if (step.contains('Bày ra')) return 'Plate and serve hot.';
    return step;
  }

  Widget _buildRecipeImage(String path, bool isDark) {
    final cleanPath = path.trim();
    if (cleanPath.isEmpty || cleanPath == 'null') {
      return const SizedBox.shrink();
    }
    if (cleanPath.startsWith('assets/')) {
      return Image.asset(
        cleanPath,
        width: double.infinity,
        height: 220,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      );
    }
    final fullUrl = AppConstants.getImageUrl(cleanPath);
    if (fullUrl != null) {
      return Image.network(
        fullUrl,
        width: double.infinity,
        height: 220,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      );
    }
    return const SizedBox.shrink();
  }



  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final isEn = loc?.locale.languageCode == 'en';

    final detailedIngredients = _recipe.safeDetailedIngredients;
    final steps = _recipe.safeSteps;
    final rawTip = _recipe.safeFriggyTip;
    final friggyTip = isEn
        ? 'Delicious and wholesome meal idea to help you use available fridge ingredients!'
        : rawTip;

    final matchText = (_recipe.matchPercent != null)
        ? (isEn ? '${_recipe.matchPercent}% match' : _recipe.safeMatchText)
        : '';
    final timeText = isEn ? _recipe.safeTimeText.replaceAll('phút', 'mins') : _recipe.safeTimeText;
    final diffText = isEn
        ? (_recipe.safeDifficultyText.contains('Rất') ? 'Very easy' : 'Easy')
        : _recipe.safeDifficultyText;
    final servingsText = isEn
        ? _recipe.safeServingsText.replaceAll('người', 'servings')
        : _recipe.safeServingsText;

    final allAvailable = detailedIngredients.every((i) => i.isAvailable);
    final hasImage = _recipe.imagePath.trim().isNotEmpty && _recipe.imagePath.trim() != 'null';

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
              const FriggyAppBar(),
              if (_isLoadingDetail)
                const LinearProgressIndicator(
                  color: Color(0xFF008435),
                  minHeight: 3,
                ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      if (hasImage) ...[
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: _buildRecipeImage(_recipe.imagePath, isDark),
                            ),
                            if (matchText.isNotEmpty)
                              Positioned(
                                top: 14,
                                right: 14,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF233629)
                                        : const Color(0xFFDCEDC8),
                                    borderRadius: BorderRadius.circular(20),
                                    border: isDark
                                        ? Border.all(
                                            color: const Color(0xFF2E4D36),
                                            width: 1)
                                        : null,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                            alpha: isDark ? 0.2 : 0.1),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.stars_rounded,
                                        color: isDark
                                            ? const Color(0xFF81C784)
                                            : const Color(0xFF006428),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        matchText,
                                        style: GoogleFonts.outfit(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w900,
                                          color: isDark
                                              ? const Color(0xFF81C784)
                                              : const Color(0xFF006428),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Title
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              _recipe.safeTitle,
                              style: GoogleFonts.outfit(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : const Color(0xFF006428),
                              ),
                            ),
                          ),
                          if (!hasImage && matchText.isNotEmpty) ...[
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF233629)
                                    : const Color(0xFFDCEDC8),
                                borderRadius: BorderRadius.circular(20),
                                border: isDark
                                    ? Border.all(
                                        color: const Color(0xFF2E4D36),
                                        width: 1)
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.stars_rounded,
                                    color: isDark
                                        ? const Color(0xFF81C784)
                                        : const Color(0xFF006428),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    matchText,
                                    style: GoogleFonts.outfit(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w900,
                                      color: isDark
                                          ? const Color(0xFF81C784)
                                          : const Color(0xFF006428),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isDark ? const Color(0xFF19271E) : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: isDark
                              ? Border.all(
                                  color: const Color(0xFF2E4D36), width: 1)
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                  alpha: isDark ? 0.2 : 0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    color: isDark
                                        ? const Color(0xFF81C784)
                                        : const Color(0xFF2E7D32),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    timeText,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? const Color(0xFF81C784)
                                          : const Color(0xFF2E7D32),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              height: 28,
                              width: 1,
                              color: isDark
                                  ? const Color(0xFF2E4D36)
                                  : const Color(0xFFE0E0E0),
                            ),
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.bar_chart_rounded,
                                    color: isDark
                                        ? const Color(0xFF81C784)
                                        : const Color(0xFF2E7D32),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    diffText,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? const Color(0xFF81C784)
                                          : const Color(0xFF2E7D32),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              height: 28,
                              width: 1,
                              color: isDark
                                  ? const Color(0xFF2E4D36)
                                  : const Color(0xFFE0E0E0),
                            ),
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.people_alt_outlined,
                                    color: isDark
                                        ? const Color(0xFF81C784)
                                        : const Color(0xFF2E7D32),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    servingsText,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? const Color(0xFF81C784)
                                          : const Color(0xFF2E7D32),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14.0,
                          vertical: 12.0,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF19271E)
                              : const Color(0xFFEAF5E1),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF2E4D36)
                                : const Color(0xFFC8E6C9),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 76,
                              height: 76,
                              child: ClipRect(
                                child: Transform.scale(
                                  scale: 1.85,
                                  child: Image.asset(
                                    'assets/images/mascot.png',
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(
                                        Icons.face_rounded,
                                        size: 60,
                                        color: isDark
                                            ? const Color(0xFF81C784)
                                            : const Color(0xFF4CAF50),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '"$friggyTip"',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? const Color(0xFFD0D7D1)
                                      : const Color(0xFF4A3800),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isEn ? 'Ingredients' : 'Nguyên liệu',
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF006428),
                            ),
                          ),
                          Row(
                            children: [
                              Icon(
                                allAvailable
                                    ? Icons.check_circle_rounded
                                    : Icons.info_outline_rounded,
                                color: allAvailable
                                    ? (isDark
                                        ? const Color(0xFF81C784)
                                        : const Color(0xFF006428))
                                    : (isDark
                                        ? const Color(0xFFFFB74D)
                                        : const Color(0xFFE65100)),
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                allAvailable
                                    ? (isEn ? 'You have enough' : 'Bạn đã có đủ')
                                    : (isEn ? 'Some missing' : 'Còn thiếu nguyên liệu'),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: allAvailable
                                      ? (isDark
                                          ? const Color(0xFF81C784)
                                          : const Color(0xFF006428))
                                      : (isDark
                                          ? const Color(0xFFFFB74D)
                                          : const Color(0xFFE65100)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...detailedIngredients.map((ingredient) {
                        final ingName = _translateIngredientName(ingredient.name, isEn);
                        final ingQty = _translateQuantity(ingredient.quantity, isEn);
                        final isAvail = ingredient.isAvailable;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF19271E)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: isDark
                                ? Border.all(
                                    color: const Color(0xFF2E4D36), width: 1)
                                : null,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                    alpha: isDark ? 0.2 : 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              decoration: BoxDecoration(
                                border: ingredient.isExpiringSoon
                                    ? const Border(
                                        left: BorderSide(
                                          color: Color(0xFFE57373),
                                          width: 4,
                                        ),
                                      )
                                    : null,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF233629)
                                          : const Color(0xFFF5F8F2),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      _getIngredientIcon(ingredient.name),
                                      color: ingredient.isExpiringSoon
                                          ? (isDark
                                              ? const Color(0xFFFF8A80)
                                              : const Color(0xFFD32F2F))
                                          : (isAvail
                                              ? (isDark
                                                  ? const Color(0xFF81C784)
                                                  : const Color(0xFF2E7D32))
                                              : (isDark
                                                  ? const Color(0xFF9DA8A0)
                                                  : const Color(0xFF757575))),
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          ingName,
                                          style: GoogleFonts.outfit(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF19221C),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          ingQty,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? const Color(0xFF9DA8A0)
                                                : const Color(0xFF666666),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isAvail
                                              ? (isDark
                                                  ? const Color(0xFF233629)
                                                  : const Color(0xFFDCEDC8))
                                              : (isDark
                                                  ? const Color(0xFF332B1E)
                                                  : const Color(0xFFFFF3E0)),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          isAvail
                                              ? (isEn ? 'In stock' : 'Đã có')
                                              : (isEn ? 'Missing' : 'Còn thiếu'),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: isAvail
                                                ? (isDark
                                                    ? const Color(0xFF81C784)
                                                    : const Color(0xFF2E7D32))
                                                : (isDark
                                                    ? const Color(0xFFFFB74D)
                                                    : const Color(0xFFE65100)),
                                          ),
                                        ),
                                      ),
                                      if (ingredient.isExpiringSoon) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          isEn ? 'Expiring soon' : 'Sắp hết hạn',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: isDark
                                                ? const Color(0xFFFF8A80)
                                                : const Color(0xFFD32F2F),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 20),
                      Text(
                        isEn ? 'Instructions' : 'Cách chế biến',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF006428),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...List.generate(steps.length, (index) {
                        final isLast = index == steps.length - 1;
                        final stepText = _translateStep(steps[index], isEn);
                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF233629)
                                          : const Color(0xFF008435),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: isDark
                                              ? const Color(0xFF81C784)
                                              : Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (!isLast)
                                    Expanded(
                                      child: Container(
                                        width: 2,
                                        color: isDark
                                            ? const Color(0xFF2E4D36)
                                            : const Color(0xFFA5D6A7),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 16.0),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF19271E)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(18),
                                      border: isDark
                                          ? Border.all(
                                              color: const Color(0xFF2E4D36),
                                              width: 1)
                                          : null,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                              alpha: isDark ? 0.2 : 0.04),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      stepText,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF19221C),
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 30),
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

  IconData _getIngredientIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('dưa') || lower.contains('quả')) {
      return Icons.radio_button_unchecked_rounded;
    } else if (lower.contains('cà chua')) {
      return Icons.circle_outlined;
    } else if (lower.contains('xà lách') ||
        lower.contains('rau') ||
        lower.contains('hành')) {
      return Icons.eco_outlined;
    } else if (lower.contains('gia vị') || lower.contains('sốt')) {
      return Icons.tune_rounded;
    } else if (lower.contains('trứng')) {
      return Icons.egg_outlined;
    } else if (lower.contains('thịt')) {
      return Icons.set_meal_outlined;
    }
    return Icons.restaurant_menu_rounded;
  }
}
