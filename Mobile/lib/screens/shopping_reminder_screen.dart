import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/services/api_service.dart';
import '../l10n/app_localizations.dart';
import '../widgets/friggy_app_bar.dart';
import '../sqlite/services/shopping_local_service.dart';
import '../sqlite/models/local_shopping_model.dart';

class ShoppingItemModel {
  int? backendItemId;
  String id;
  String name;
  String? quantity;
  bool isChecked;

  ShoppingItemModel({
    this.backendItemId,
    required this.id,
    required this.name,
    this.quantity,
    this.isChecked = false,
  });
}

class ShoppingReminderScreen extends StatefulWidget {
  const ShoppingReminderScreen({super.key});

  @override
  State<ShoppingReminderScreen> createState() => _ShoppingReminderScreenState();
}

class _ShoppingReminderScreenState extends State<ShoppingReminderScreen> {
  final TextEditingController _addItemController = TextEditingController();

  bool _isLoading = true;
  String? _currentListId;
  List<ShoppingItemModel> _shoppingList = [];

  @override
  void initState() {
    super.initState();
    _fetchShoppingLists();
  }

  Future<void> _fetchShoppingLists() async {
    setState(() {
      _isLoading = true;
    });

    final shoppingLocalService = ShoppingLocalService();

    try {
      final lists = await ApiService().getShoppingLists();
      if (lists.isNotEmpty) {
        final firstList = lists.first as Map<String, dynamic>;
        final listId = firstList['id']?.toString();
        final rawItems = firstList['items'] as List<dynamic>? ?? [];

        final List<ShoppingItemModel> loadedItems = [];
        final List<LocalShoppingItemModel> localItems = [];

        for (final item in rawItems) {
          final itemMap = item as Map<String, dynamic>;
          final bId = itemMap['id'] as int?;
          final name = itemMap['ingredientName']?.toString() ?? 'Nguyên liệu';
          final qtyNum = itemMap['quantity'];
          final unitStr = itemMap['unit']?.toString() ?? '';
          final qtyStr = qtyNum != null ? '$qtyNum $unitStr'.trim() : null;
          final isPurchased = itemMap['isPurchased'] as bool? ?? false;

          loadedItems.add(
            ShoppingItemModel(
              backendItemId: bId,
              id: bId?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
              name: name,
              quantity: qtyStr,
              isChecked: isPurchased,
            ),
          );

          localItems.add(
            LocalShoppingItemModel(
              id: bId?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
              ingredientId: itemMap['ingredientId'] as int? ?? 0,
              ingredientName: name,
              quantity: (qtyNum as num?)?.toDouble() ?? 1.0,
              unit: unitStr,
              isPurchased: isPurchased,
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );
        }

        // Save to SQLite
        await shoppingLocalService.saveShoppingItemsOverwrite(localItems);

        if (mounted) {
          setState(() {
            _currentListId = listId;
            _shoppingList = loadedItems;
            _isLoading = false;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('[ShoppingReminderScreen] Error/Offline fetching shopping lists: $e. Loading from SQLite...');
      try {
        final cached = await shoppingLocalService.getCachedShoppingItems();
        if (cached.isNotEmpty) {
          final List<ShoppingItemModel> offlineItems = cached.map((item) {
            return ShoppingItemModel(
              id: item.id,
              name: item.ingredientName,
              quantity: '${item.quantity} ${item.unit}',
              isChecked: item.isPurchased,
            );
          }).toList();

          if (mounted) {
            setState(() {
              _shoppingList = offlineItems;
              _isLoading = false;
            });
            return;
          }
        }
      } catch (err) {
        debugPrint('[ShoppingReminderScreen] SQLite read error: $err');
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _generateShoppingListFromLatestPlan() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final plans = await ApiService().getMealPlans();
      if (plans.isNotEmpty && plans.first['id'] != null) {
        final planId = plans.first['id'].toString();
        await ApiService().createShoppingList(
          weeklyPlanId: planId,
          title: 'Danh sách mua sắm tuần này',
        );
        await _fetchShoppingLists();
        return;
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Chưa có thực đơn tuần. Vui lòng tạo thực đơn trước!'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[ShoppingReminderScreen] Error creating shopping list: $e');
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _addItemController.dispose();
    super.dispose();
  }

  void _addNewItem(String name) {
    final loc = AppLocalizations.of(context);
    final isEn = loc?.locale.languageCode == 'en';
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _shoppingList.insert(
        0,
        ShoppingItemModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: trimmed,
          isChecked: false,
        ),
      );
      _addItemController.clear();
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isEn ? 'Added "$trimmed" to shopping list!' : 'Đã thêm "$trimmed" vào danh sách cần mua!'),
        backgroundColor: const Color(0xFF008435),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _toggleCheckItem(ShoppingItemModel item) async {
    setState(() {
      item.isChecked = !item.isChecked;
    });

    if (_currentListId != null && item.backendItemId != null) {
      try {
        await ApiService().toggleShoppingListItem(
          listId: _currentListId!,
          itemId: item.backendItemId!,
        );
      } catch (e) {
        debugPrint('[ShoppingReminderScreen] Error toggling item: $e');
      }
    }
  }

  void _deleteItem(ShoppingItemModel item) {
    final loc = AppLocalizations.of(context);
    final isEn = loc?.locale.languageCode == 'en';
    setState(() {
      _shoppingList.removeWhere((element) => element.id == item.id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isEn ? 'Deleted "${item.name}" from list!' : 'Đã xóa "${item.name}" khỏi danh sách!'),
        backgroundColor: const Color(0xFFD32F2F),
        duration: const Duration(seconds: 2),
      ),
    );
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
                    Color(0xFFFFFFFF),
                    Color(0xFFF5FCF4),
                    Color(0xFFC7EFC2),
                    Color(0xFF86D978),
                    Color(0xFF4CB93E),
                  ],
            stops: isDark ? const [0.0, 0.5, 1.0] : const [0.0, 0.24, 0.42, 0.72, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const FriggyAppBar(),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),

                      Text(
                        isEn ? 'Shopping Reminder' : 'Nhắc đi chợ',
                        style: GoogleFonts.outfit(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF006428),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isEn
                            ? 'Create your shopping list for next week with Friggy!'
                            : 'Lên danh sách mua sắm cho tuần tới cùng Friggy nhé!',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                          color: isDark
                              ? const Color(0xFF9DA8A0)
                              : const Color(0xFF1B5E20),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 12),

                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.only(
                                  left: 18,
                                  right: 105,
                                  top: 22,
                                  bottom: 22,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1E3A25)
                                      : const Color(0xFF52B756),
                                  borderRadius: BorderRadius.circular(24),
                                  border: isDark
                                      ? Border.all(
                                          color: const Color(0xFF2E4D36),
                                          width: 1.5)
                                      : null,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black
                                          .withValues(alpha: isDark ? 0.2 : 0.08),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  isEn
                                      ? 'Friggy prepared a few\nshopping suggestions for you!'
                                      : 'Friggy đã chuẩn bị danh sách\nmua sắm từ thực đơn AI nè!',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1.35,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              Text(
                                isEn ? 'Add to update' : 'Nhập thêm để cập nhật',
                                style: GoogleFonts.outfit(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF006428),
                                ),
                              ),
                              const SizedBox(height: 8),

                              Padding(
                                padding: const EdgeInsets.only(right: 96.0),
                                child: Container(
                                  height: 48,
                                  padding: const EdgeInsets.only(left: 14, right: 4),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF19271E)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(28),
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(0xFF2E4D36)
                                          : const Color(0xFF81C784),
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: isDark ? 0.2 : 0.04),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _addItemController,
                                          onSubmitted: _addNewItem,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white : const Color(0xFF19221C),
                                          ),
                                          decoration: InputDecoration(
                                            hintText: isEn
                                                ? 'Enter item you want to buy'
                                                : 'Nhập thực phẩm bạn muốn mua',
                                            hintStyle: GoogleFonts.plusJakartaSans(
                                              fontSize: 12.5,
                                              color: isDark
                                                  ? const Color(0xFF9DA8A0)
                                                  : const Color(0xFFA5D6A7),
                                            ),
                                            border: InputBorder.none,
                                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                          ),
                                        ),
                                      ),
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () => _addNewItem(_addItemController.text),
                                          borderRadius: BorderRadius.circular(20),
                                          child: Container(
                                            width: 40,
                                            height: 40,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF4CAF50),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.add_rounded,
                                              color: Colors.white,
                                              size: 26,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          Positioned(
                            right: -2,
                            top: -2,
                            bottom: -18,
                            width: 136,
                            child: Image.asset(
                              'assets/images/suggest.png',
                              fit: BoxFit.contain,
                              alignment: Alignment.centerRight,
                              errorBuilder: (context, error, stackTrace) => const Icon(
                                Icons.shopping_bag_rounded,
                                size: 64,
                                color: Colors.white30,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 22),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isEn ? 'Shopping List' : 'Danh sách cần mua',
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFF006428),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _generateShoppingListFromLatestPlan,
                            icon: const Icon(Icons.auto_awesome, size: 16),
                            label: Text(
                              isEn ? 'Sync Plan' : 'Tạo từ AI',
                              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF008435),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: CircularProgressIndicator(color: Color(0xFF008435)),
                          ),
                        )
                      else if (_shoppingList.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF19271E) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.shopping_cart_outlined,
                                size: 48,
                                color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                isEn
                                    ? 'No shopping list yet. Tap "Sync Plan" to generate!'
                                    : 'Chưa có danh sách cần mua. Bấm "Tạo từ AI" để tổng hợp!',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : const Color(0xFF2E7D32),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _shoppingList.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = _shoppingList[index];
                            return _buildShoppingItemCard(item, isDark);
                          },
                        ),

                      const SizedBox(height: 24),

                      Center(
                        child: Image.asset(
                          'assets/images/market.png',
                          width: double.infinity,
                          height: 210,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.storefront_rounded,
                            size: 100,
                            color: Colors.white30,
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),
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

  Widget _buildShoppingItemCard(ShoppingItemModel item, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF19271E) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? const Color(0xFF2E4D36)
              : (item.isChecked ? const Color(0xFFA5D6A7) : const Color(0xFF81C784)),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _toggleCheckItem(item),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: item.isChecked ? const Color(0xFF4CAF50) : Colors.transparent,
                border: Border.all(
                  color: item.isChecked
                      ? const Color(0xFF4CAF50)
                      : (isDark ? const Color(0xFF6B786F) : const Color(0xFF9E9E9E)),
                  width: 2,
                ),
              ),
              child: item.isChecked
                  ? const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 14),

          Expanded(
            child: Text(
              item.name,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: item.isChecked
                    ? (isDark ? const Color(0xFF6B786F) : const Color(0xFF757575))
                    : (isDark ? Colors.white : const Color(0xFF19221C)),
                decoration: item.isChecked ? TextDecoration.lineThrough : null,
              ),
            ),
          ),

          if (item.quantity != null && item.quantity!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF233629) : const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                item.quantity!,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              color: isDark ? const Color(0xFFE57373) : const Color(0xFFD32F2F),
              size: 20,
            ),
            onPressed: () => _deleteItem(item),
          ),
        ],
      ),
    );
  }
}
