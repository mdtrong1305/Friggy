import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import 'fridge_inventory_screen.dart';
import '../widgets/fridge_members_modal.dart';
import '../data/services/api_service.dart';
import '../data/models/fridge_models.dart';

import '../data/models/user_models.dart';

class FridgeModel {
  String id;
  String name;
  String description;
  int totalItems;
  int expiringItems;
  Color themeColor;
  List<FridgeMemberModel>? _membersList;

  List<FridgeMemberModel> get members => _membersList ??= [];

  set members(List<FridgeMemberModel> val) => _membersList = val;

  FridgeModel({
    required this.id,
    required this.name,
    required this.description,
    required this.totalItems,
    required this.expiringItems,
    required this.themeColor,
    List<FridgeMemberModel>? members,
  }) : _membersList = members;
}

class MyFridgesScreen extends StatefulWidget {
  const MyFridgesScreen({super.key});

  @override
  State<MyFridgesScreen> createState() => _MyFridgesScreenState();
}

class _MyFridgesScreenState extends State<MyFridgesScreen> {
  final ApiService _apiService = ApiService();
  FamilyRoleModel? _familyRole;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final res = await _apiService.getFridgeStats();
      final stats = FridgeStatsModel.fromJson(res);
      FamilyRoleModel? familyRole;
      try {
        final familyRes = await _apiService.getMyFamily();
        familyRole = FamilyRoleModel.fromJson(familyRes);
      } catch (e) {
        debugPrint('Error fetching family in MyFridgesScreen: $e');
      }

      if (mounted) {
        setState(() {
          _fridges[0].totalItems = stats.totalItems;
          _fridges[0].expiringItems = stats.expiringSoonCount;
          _familyRole = familyRole;
        });
      }
    } catch (e) {
      debugPrint('Error fetching stats in MyFridgesScreen: $e');
    }
  }

  final List<FridgeModel> _fridges = [
    FridgeModel(
      id: 'family',
      name: 'Tủ Lạnh Gia Đình',
      description: 'Chia sẻ với gia đình',
      totalItems: 3,
      expiringItems: 1,
      themeColor: const Color(0xFF008435),
    ),
    FridgeModel(
      id: 'roommates',
      name: 'Tủ Lạnh Phòng Trọ',
      description: 'Chia sẻ với bạn cùng phòng',
      totalItems: 2,
      expiringItems: 1,
      themeColor: const Color(0xFF2E7D32),
    ),
    FridgeModel(
      id: 'personal',
      name: 'Tủ Lạnh Cá Nhân',
      description: 'Đồ ăn vặt & nước uống phòng ngủ',
      totalItems: 2,
      expiringItems: 0,
      themeColor: const Color(0xFF52B756),
    ),
  ];

  // Beautiful BottomSheet Modal to Rename an existing Fridge (Name-Only)
  void _showRenameDialog(FridgeModel fridge) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameController = TextEditingController(text: fridge.name);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF19271E) : Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
              border: isDark ? Border.all(color: const Color(0xFF2E4D36), width: 1.2) : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Handle Drag Indicator
                Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2E4D36) : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                SizedBox(height: 20.h),

                // Top Mascot Thumbnail Banner
                Container(
                  width: 72,
                  height: 72,
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF233629) : const Color(0xFFE8F5E9),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? const Color(0xFF81C784) : const Color(0xFFA5E69C),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4CAF50).withValues(alpha: isDark ? 0.2 : 0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/onboarding_fridge.png',
                    fit: BoxFit.contain,
                  ),
                ),

                SizedBox(height: 14.h),

                // Title & Subtitle
                Text(
                  'Đổi tên tủ lạnh',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF006428),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Nhập tên mới để dễ dàng quản lý thực phẩm',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFFD0D7D1) : const Color(0xFF757575),
                  ),
                ),

                SizedBox(height: 20.h),

                // Styled Input Field (Name Only)
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0E1611) : const Color(0xFFF5FCF4),
                    borderRadius: BorderRadius.circular(18.r),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFA5D6A7),
                      width: 1.2,
                    ),
                  ),
                  child: TextField(
                    controller: nameController,
                    autofocus: true,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15.5.sp,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF19221C),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Tên tủ lạnh...',
                      hintStyle: TextStyle(
                        color: isDark ? const Color(0xFF9DA8A0) : const Color(0xFF9EA8A1),
                      ),
                      prefixIcon: Icon(
                        Icons.edit_outlined,
                        color: isDark ? const Color(0xFF81C784) : const Color(0xFF4CAF50),
                        size: 22,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 24.h),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                        ),
                        child: Text(
                          'Hủy',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFFD0D7D1) : const Color(0xFF757575),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final newName = nameController.text.trim();
                          if (newName.isNotEmpty) {
                            setState(() {
                              fridge.name = newName;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('Đã đổi tên tủ lạnh thành "$newName"!'),
                                backgroundColor: const Color(0xFF008435),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14.r),
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                          Navigator.pop(context);
                        },
                        icon: Icon(
                          Icons.check_rounded,
                          color: isDark ? const Color(0xFF0E1611) : Colors.white,
                          size: 20,
                        ),
                        label: Text(
                          'Lưu tên mới',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w900,
                            color: isDark ? const Color(0xFF0E1611) : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
              ],
            ),
          ),
        );
      },
    );
  }

  // Dialog to Add a New Fridge (Modern Bottom Sheet)
  void _showAddFridgeDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameController = TextEditingController();
    final memberController = TextEditingController();
    final List<String> memberList = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void addMember() {
              final text = memberController.text.trim();
              if (text.isNotEmpty && !memberList.contains(text)) {
                setModalState(() {
                  memberList.add(text);
                });
                memberController.clear();
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF19271E) : Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
                  border: isDark
                      ? const Border(top: BorderSide(color: Color(0xFF2E4D36), width: 1.2))
                      : null,
                ),
                padding: EdgeInsets.only(
                  left: 24.w,
                  right: 24.w,
                  top: 14.h,
                  bottom: 24.h,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Drag Handle Bar
                    Center(
                      child: Container(
                        width: 42,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFC8E6C9),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                    ),

                    SizedBox(height: 18.h),

                    // Header Row: Icon Badge, Title, Subtitle, Close Button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF233629) : const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          child: Icon(
                            Icons.kitchen_rounded,
                            color: isDark ? const Color(0xFF81C784) : const Color(0xFF008435),
                            size: 26,
                          ),
                        ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Thêm Tủ Lạnh Mới',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 22.sp,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF006428),
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                'Tạo không gian lưu trữ và chia sẻ cùng người thân',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? const Color(0xFFD0D7D1) : const Color(0xFF55A44B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            Icons.close_rounded,
                            color: isDark ? const Color(0xFF9DA8A0) : const Color(0xFF757575),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 20.h),

                    // Field 1: Fridge Name
                    Text(
                      'TÊN TỦ LẠNH',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFF81C784) : const Color(0xFF006428),
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0E1611) : const Color(0xFFF7FAF8),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFA5E69C),
                          width: 1.2,
                        ),
                      ),
                      child: TextField(
                        controller: nameController,
                        autofocus: true,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF19221C),
                        ),
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.kitchen_outlined,
                            color: isDark ? const Color(0xFF81C784) : const Color(0xFF008435),
                            size: 22,
                          ),
                          hintText: 'vd: Tủ công ty, Tủ nhà riêng...',
                          hintStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFF9DA8A0) : const Color(0xFF9EA8A1),
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 18.h),

                    // Field 2: Add Members
                    Text(
                      'THÊM THÀNH VIÊN (SĐT HOẶC EMAIL)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFF81C784) : const Color(0xFF006428),
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0E1611) : const Color(0xFFF7FAF8),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFA5E69C),
                          width: 1.2,
                        ),
                      ),
                      child: TextField(
                        controller: memberController,
                        onSubmitted: (_) => addMember(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.5.sp,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF19221C),
                        ),
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.person_add_alt_1_rounded,
                            color: isDark ? const Color(0xFF81C784) : const Color(0xFF008435),
                            size: 20,
                          ),
                          hintText: 'vd: friend@email.com...',
                          hintStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFF9DA8A0) : const Color(0xFF9EA8A1),
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          suffixIcon: Padding(
                            padding: EdgeInsets.all(6.0.w),
                            child: GestureDetector(
                              onTap: addMember,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF81C784) : const Color(0xFF008435),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.add_rounded,
                                      size: 18,
                                      color: isDark ? const Color(0xFF0E1611) : Colors.white,
                                    ),
                                    SizedBox(width: 4.w),
                                    Text(
                                      'Thêm',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? const Color(0xFF0E1611) : Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Added Member Chips
                    if (memberList.isNotEmpty) ...[
                      SizedBox(height: 12.h),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: memberList.map((mem) {
                          return Container(
                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF233629) : const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(20.r),
                              border: Border.all(
                                color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFA5D6A7),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF81C784) : const Color(0xFF008435),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      mem[0].toUpperCase(),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w900,
                                        color: isDark ? const Color(0xFF0E1611) : Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Text(
                                  mem,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF006428),
                                  ),
                                ),
                                SizedBox(width: 6.w),
                                GestureDetector(
                                  onTap: () {
                                    setModalState(() {
                                      memberList.remove(mem);
                                    });
                                  },
                                  child: Icon(
                                    Icons.cancel_rounded,
                                    size: 18,
                                    color: isDark ? const Color(0xFF9DA8A0) : const Color(0xFF757575),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                    SizedBox(height: 24.h),

                    // Submit Button
                    GestureDetector(
                      onTap: () {
                        final newName = nameController.text.trim();
                        if (memberController.text.trim().isNotEmpty) {
                          final pendingText = memberController.text.trim();
                          if (!memberList.contains(pendingText)) {
                            memberList.add(pendingText);
                          }
                        }

                        if (newName.isNotEmpty) {
                          final createdMembers = <FridgeMemberModel>[
                            FridgeMemberModel(
                              id: 'owner',
                              name: 'Trần Quốc Lâm',
                              emailOrPhone: 'lam.tran@friggy.app',
                              role: 'Chủ tủ',
                              isOwner: true,
                              avatarBgColor: const Color(0xFF006428),
                            ),
                          ];

                          final colors = [
                            const Color(0xFF8E24AA),
                            const Color(0xFF1976D2),
                            const Color(0xFFE65100),
                            const Color(0xFF00897B),
                          ];

                          for (int i = 0; i < memberList.length; i++) {
                            final item = memberList[i];
                            createdMembers.add(
                              FridgeMemberModel(
                                id: 'm_added_$i',
                                name: item.contains('@') ? item.split('@').first : item,
                                emailOrPhone: item,
                                role: 'Thành viên',
                                avatarBgColor: colors[i % colors.length],
                              ),
                            );
                          }

                          setState(() {
                            _fridges.add(
                              FridgeModel(
                                id: 'fridge_${DateTime.now().millisecondsSinceEpoch}',
                                name: newName,
                                description: 'Tủ lạnh dùng chung',
                                totalItems: 0,
                                expiringItems: 0,
                                themeColor: const Color(0xFF008435),
                                members: createdMembers,
                              ),
                            );
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Đã tạo tủ "$newName"${memberList.isNotEmpty ? ' với ${memberList.length} thành viên' : ''}!',
                              ),
                              backgroundColor: const Color(0xFF008435),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14.r),
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF81C784) : const Color(0xFF008435),
                          borderRadius: BorderRadius.circular(28.r),
                          boxShadow: [
                            BoxShadow(
                              color: (isDark ? const Color(0xFF81C784) : const Color(0xFF008435))
                                  .withValues(alpha: 0.3),
                              blurRadius: 10,
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
                              size: 22,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              'Tạo Tủ Lạnh',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 17.sp,
                                fontWeight: FontWeight.w800,
                                color: isDark ? const Color(0xFF0E1611) : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 8.h),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final isEn = loc?.locale.languageCode == 'en';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 12.h),

          // Header Title matching HomeHeader 100%
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 32.sp,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                      children: isEn
                          ? [
                              TextSpan(
                                text: 'My ',
                                style: TextStyle(
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF19221C)),
                              ),
                              TextSpan(
                                text: 'Fridges',
                                style: TextStyle(
                                    color: isDark
                                        ? const Color(0xFF81C784)
                                        : const Color(0xFF4CAF50)),
                              ),
                            ]
                          : [
                              TextSpan(
                                text: 'Tủ ',
                                style: TextStyle(
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF19221C)),
                              ),
                              TextSpan(
                                text: 'lạnh',
                                style: TextStyle(
                                    color: isDark
                                        ? const Color(0xFF81C784)
                                        : const Color(0xFF4CAF50)),
                              ),
                            ],
                    ),
                  ),
                  Text(
                    isEn ? 'Long press a fridge card to rename' : 'Đề giữ vào tủ để sửa tên',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFF9DA8A0)
                          : const Color(0xFF757575),
                    ),
                  ),
                ],
              ),

              // Add New Fridge Circle Button
              GestureDetector(
                onTap: _showAddFridgeDialog,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF19271E)
                        : Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    border: isDark
                        ? Border.all(color: const Color(0xFF2E4D36), width: 1.2)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
                    size: 26,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 20.h),

          // Grid Display of Fridges with onboarding_fridge.png & Name below!
          Expanded(
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 18,
                childAspectRatio: 0.9,
              ),
              itemCount: _fridges.length,
              itemBuilder: (context, index) {
                final fridge = _fridges[index];

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FridgeInventoryScreen(
                          fridge: fridge,
                          onRename: () => _showRenameDialog(fridge),
                        ),
                      ),
                    );
                  },
                  onLongPress: () {
                    Feedback.forLongPress(context);
                    _showRenameDialog(fridge);
                  },
                  child: Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        height: double.infinity,
                        padding: EdgeInsets.all(14.w),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF19271E) : Colors.white,
                          borderRadius: BorderRadius.circular(24.r),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF2E4D36)
                                : const Color(0xFFA5E69C),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(height: 12.h),

                            // 1. Fridge Image (assets/images/onboarding_fridge.png)
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.all(4.0.w),
                                child: Image.asset(
                                  'assets/images/onboarding_fridge.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),

                            SizedBox(height: 10.h),

                            // 2. Fridge Name (Below the image)
                            Text(
                              fridge.name,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15.5.sp,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : const Color(0xFF006428),
                                height: 1.15,
                              ),
                            ),
                            SizedBox(height: 4.h),
                          ],
                        ),
                      ),

                      // Top Right Circular Member Icon Button (👥)
                      if (_familyRole?.group != null && (_familyRole?.role == 'owner' || _familyRole?.role == 'member'))
                        Positioned(
                        top: 8.h,
                        right: 8.w,
                        child: GestureDetector(
                          onTap: () {
                            showFridgeMembersModal(
                              context,
                              fridgeName: fridge.name,
                              members: fridge.members,
                              onAddMember: (newMem) {
                                setState(() {
                                  fridge.members.add(newMem);
                                });
                              },
                              onRemoveMember: (memId) {
                                setState(() {
                                  fridge.members
                                      .removeWhere((m) => m.id == memId);
                                });
                              },
                            );
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF233629)
                                  : const Color(0xFFE8F5E9),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF2E4D36)
                                    : const Color(0xFFA5D6A7),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.group_rounded,
                              size: 16,
                              color: isDark
                                  ? const Color(0xFF81C784)
                                  : const Color(0xFF006428),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
