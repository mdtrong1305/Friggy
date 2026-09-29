import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../data/local/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/home_header.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import '../widgets/greeting_banner.dart';
import '../widgets/fridge_summary_cards.dart';
import '../widgets/premium_banner.dart';
import '../widgets/weekly_statistics_section.dart';
import '../widgets/cooking_suggestions_section.dart';
import 'select_input_method_screen.dart';
import 'manual_add_ingredient_screen.dart';
import 'scan_food_photo_screen.dart';
import 'scan_receipt_screen.dart';
import 'scan_barcode_screen.dart';
import 'my_fridges_screen.dart';
import 'fridge_inventory_screen.dart';
import 'all_expired_items_screen.dart';
import 'all_available_items_screen.dart';
import 'ai_chat_screen.dart';
import 'recipe_detail_screen.dart';
import 'ingredient_statistics_screen.dart';
import 'next_week_suggestions_screen.dart';
import 'shopping_reminder_screen.dart';
import 'user_profile_screen.dart';
import 'notifications_screen.dart';
import '../data/services/api_service.dart';
import 'package_management_screen.dart';
import '../widgets/family_plan_modal.dart';
import '../sqlite/services/background_sync_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<WeeklyStatisticsSectionState> _statsKey =
      GlobalKey<WeeklyStatisticsSectionState>();
  final GlobalKey<CookingSuggestionsSectionState> _cookingSuggestionsKey =
      GlobalKey<CookingSuggestionsSectionState>();
  final GlobalKey<UserProfileScreenState> _userProfileKey =
      GlobalKey<UserProfileScreenState>();
  final GlobalKey<FridgeInventoryScreenState> _fridgeKey =
      GlobalKey<FridgeInventoryScreenState>();
  String _userName = 'Trần Quốc Lâm';
  bool _isFamilyPlan = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _wasOffline = false; // Theo dõi trạng thái mạng trước đó

  late AnimationController _animController;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;
  late Animation<double> _bodyFade;
  late Animation<Offset> _bodySlide;
  late Animation<double> _bottomNavFade;
  late Animation<Offset> _bottomNavSlide;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadSubscriptionData();
    // Sync tất cả data vào SQLite ngay khi vào trang chủ (chạy nền, không block UI)
    BackgroundSyncService().syncAll();
    // Lắng nghe thay đổi kết nối mạng để sync pending items khi có mạng trở lại
    _startConnectivityListener();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _headerFade = CurvedAnimation(
      parent: _animController,
      curve: Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(0.0, -0.15),
      end: Offset.zero,
    ).animate(_headerFade);

    _bodyFade = CurvedAnimation(
      parent: _animController,
      curve: Interval(0.15, 0.75, curve: Curves.easeOut),
    );
    _bodySlide = Tween<Offset>(
      begin: const Offset(0.0, 0.08),
      end: Offset.zero,
    ).animate(_bodyFade);

    _bottomNavFade = CurvedAnimation(
      parent: _animController,
      curve: Interval(0.3, 0.85, curve: Curves.easeOut),
    );
    _bottomNavSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.2),
      end: Offset.zero,
    ).animate(_bottomNavFade);

    _animController.forward();
  }

  void _startConnectivityListener() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline && _wasOffline) {
        // Mạng vừa khôi phục → sync các pending items lên server
        debugPrint('[HomeScreen] Network restored → triggering background sync...');
        BackgroundSyncService().forceSync();
      }
      _wasOffline = !isOnline;
    });
  }

  Future<void> _loadUserData() async {
    try {
      final storage = await StorageService.getInstance();
      final userDataStr = storage.getUserData();
      if (userDataStr != null && userDataStr.isNotEmpty) {
        final Map<String, dynamic> userMap = jsonDecode(userDataStr);
        final String? name = userMap['name'] ?? userMap['fullName'];
        if (name != null && name.trim().isNotEmpty) {
          if (mounted) {
            setState(() {
              _userName = name.trim();
            });
          }
        }
      }
    } catch (e) {
      debugPrint('[HomeScreen] Error loading user data: $e');
    }
  }

  Future<void> _loadSubscriptionData() async {
    try {
      final subJson = await ApiService().getMySubscription();
      final planName = subJson['plan']?['name']?.toString().toLowerCase() ?? '';
      final planDisplayName = subJson['plan']?['displayName']?.toString().toLowerCase() ?? '';
      final isFamily = planName.contains('family') || planDisplayName.contains('gia đình');
      if (mounted) {
        setState(() {
          _isFamilyPlan = isFamily;
        });
      }
    } catch (e) {
      debugPrint('[HomeScreen] Error loading subscription: $e');
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _searchController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (index == 2) {
      SelectInputMethodScreen.show(
        context,
        onMethodSelected: (methodId) {
          Widget targetScreen;
          switch (methodId) {
            case 'manual':
              targetScreen = const ManualAddIngredientScreen();
              break;
            case 'scan_photo':
              targetScreen = const ScanFoodPhotoScreen();
              break;
            case 'scan_receipt':
              targetScreen = const ScanReceiptScreen();
              break;
            case 'scan_barcode':
              targetScreen = const ScanBarcodeScreen();
              break;
            default:
              targetScreen = const ManualAddIngredientScreen();
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => targetScreen,
            ),
          ).then((result) {
            _fridgeKey.currentState?.reload();
            if (mounted) {
              setState(() {
                _selectedIndex = 1;
              });
            }
          });
        },
      );
      return;
    }
    setState(() {
      _selectedIndex = index;
    });
    if (index == 0) {
      _cookingSuggestionsKey.currentState?.reload();
    } else if (index == 1) {
      _fridgeKey.currentState?.reload();
    } else if (index == 4) {
      _userProfileKey.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF4FAF2),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppGradients.getBackground(isDark),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // 1. Top Header with Logo, Notification Badge, and Search Input (Shown only on Home Tab)
              if (_selectedIndex == 0)
                FadeTransition(
                  opacity: _headerFade,
                  child: SlideTransition(
                    position: _headerSlide,
                    child: HomeHeader(
                      searchController: _searchController,
                      onNotificationTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NotificationsScreen(),
                          ),
                        );
                        if (mounted) {
                          setState(() {});
                        }
                      },
                      onFilterTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Filter tapped'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ),
                ),

              // 2. Middle Content Area (Slides up & fades in)
              Expanded(
                child: FadeTransition(
                  opacity: _bodyFade,
                  child: SlideTransition(
                    position: _bodySlide,
                    child: IndexedStack(
                      index: _selectedIndex == 2 ? 0 : _selectedIndex,
                      children: [
                        // Index 0: Home Dashboard
                        SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: Column(
                            children: [
                              SizedBox(height: 8.h),
                              GreetingBanner(userName: _userName),
                              SizedBox(height: 16.h),

                              // 2 Summary Cards (Expired & Available Ingredients)
                              FridgeSummaryCards(
                                onExpiringTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const AllExpiredItemsScreen(),
                                    ),
                                  );
                                },
                                onAvailableTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const AllAvailableItemsScreen(),
                                    ),
                                  );
                                },
                              ),
                              SizedBox(height: 16.h),

                              // Premium Friggy Upgrade Banner
                              PremiumBanner(
                                isFamilyPlan: _isFamilyPlan,
                                onTryNowTap: () async {
                                  if (_isFamilyPlan) {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const PackageManagementScreen(),
                                      ),
                                    );
                                    _loadSubscriptionData();
                                  } else {
                                     showFamilySubscriptionModal(
                                       context,
                                       onSuccess: _loadSubscriptionData,
                                     );
                                  }
                                },
                              ),
                              SizedBox(height: 18.h),
                              WeeklyStatisticsSection(
                                key: _statsKey,
                                onDetailTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const IngredientStatisticsScreen(),
                                    ),
                                  );
                                },
                                onMealSuggestionsTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const NextWeekSuggestionsScreen(),
                                    ),
                                  );
                                  _cookingSuggestionsKey.currentState?.reload();
                                  _statsKey.currentState?.reload();
                                },
                                onShoppingReminderTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const ShoppingReminderScreen(),
                                    ),
                                  );
                                },
                              ),
                              SizedBox(height: 24.h),
                              CookingSuggestionsSection(
                                key: _cookingSuggestionsKey,
                                onMealToggled: () {
                                  _statsKey.currentState?.reload();
                                },
                                onUpgradeTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Upgrade to Premium tapped!'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                                onRecipeTap: (recipe) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          RecipeDetailScreen(recipe: recipe),
                                    ),
                                  );
                                },
                              ),
                              SizedBox(height: 28.h),
                            ],
                          ),
                        ),

                        // Index 1: Direct Fridge Inventory Screen
                        FridgeInventoryScreen(
                          key: _fridgeKey,
                          fridge: FridgeModel(
                            id: 'family',
                            name: 'Tủ lạnh',
                            description: 'Tủ lạnh chính',
                            totalItems: 0,
                            expiringItems: 0,
                            themeColor: const Color(0xFF006428),
                          ),
                          onRename: () {},
                          isEmbedded: true,
                        ),

                        // Index 2: Placeholder for Add (modal triggered)
                        const SizedBox.shrink(),

                        // Index 3: AI Chat Screen (Đầu bếp AI)
                        const AiChatScreen(),

                        // Index 4: Profile & Settings Screen
                        UserProfileScreen(key: _userProfileKey),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Custom 5-Item Bottom Navigation Bar (Slides up & fades in)
              FadeTransition(
                opacity: _bottomNavFade,
                child: SlideTransition(
                  position: _bottomNavSlide,
                  child: CustomBottomNavigationBar(
                    selectedIndex: _selectedIndex,
                    onItemTapped: _onItemTapped,
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
