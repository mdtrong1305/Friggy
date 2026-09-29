import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/models/user_models.dart';
import '../data/services/api_service.dart';
import '../screens/family_management_screen.dart';

class FridgeMemberModel {
  final String id;
  final String name;
  final String emailOrPhone;
  final String role; // 'Chủ tủ' vs 'Thành viên' vs 'Đang chờ'
  final bool isOwner;
  final Color avatarBgColor;

  FridgeMemberModel({
    required this.id,
    required this.name,
    required this.emailOrPhone,
    required this.role,
    this.isOwner = false,
    this.avatarBgColor = const Color(0xFF4CAF50),
  });
}

void showFridgeMembersModal(
  BuildContext context, {
  required String fridgeName,
  required List<FridgeMemberModel> members,
  required Function(FridgeMemberModel) onAddMember,
  required Function(String) onRemoveMember,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return _FridgeMembersModalContent(
        fridgeName: fridgeName,
        fallbackMembers: members,
        onAddMember: onAddMember,
        onRemoveMember: onRemoveMember,
      );
    },
  );
}

class _FridgeMembersModalContent extends StatefulWidget {
  final String fridgeName;
  final List<FridgeMemberModel> fallbackMembers;
  final Function(FridgeMemberModel) onAddMember;
  final Function(String) onRemoveMember;

  const _FridgeMembersModalContent({
    required this.fridgeName,
    required this.fallbackMembers,
    required this.onAddMember,
    required this.onRemoveMember,
  });

  @override
  State<_FridgeMembersModalContent> createState() => _FridgeMembersModalContentState();
}

class _FridgeMembersModalContentState extends State<_FridgeMembersModalContent> {
  final ApiService _apiService = ApiService();
  final TextEditingController _inviteController = TextEditingController();

  bool _isLoading = true;
  bool _isActionLoading = false;
  FamilyRoleModel? _familyRole;
  List<FridgeMemberModel> _displayMembers = [];

  @override
  void initState() {
    super.initState();
    _fetchFamilyData();
  }

  @override
  void dispose() {
    _inviteController.dispose();
    super.dispose();
  }

  Future<void> _fetchFamilyData() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.getMyFamily();
      final familyRole = FamilyRoleModel.fromJson(res);
      
      List<FridgeMemberModel> list = [];
      if (familyRole.group != null) {
        final group = familyRole.group!;
        // Add Owner
        list.add(
          FridgeMemberModel(
            id: group.owner.id,
            name: group.owner.name ?? 'Chủ gia đình',
            emailOrPhone: 'Chủ tủ',
            role: 'Chủ tủ',
            isOwner: true,
            avatarBgColor: const Color(0xFF006428),
          ),
        );
        // Add Members
        if (!mounted) return;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final colors = [
          isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
          const Color(0xFF8E24AA),
          const Color(0xFF0288D1),
          const Color(0xFFE65100),
          const Color(0xFF00897B),
        ];
        int colorIdx = 0;

        for (final m in group.members) {
          final isPending = m.status == 'pending';
          list.add(
            FridgeMemberModel(
              id: m.id,
              name: m.memberName ?? m.invitedEmail.split('@').first,
              emailOrPhone: m.invitedEmail,
              role: isPending ? 'Đang chờ' : 'Thành viên',
              isOwner: false,
              avatarBgColor: colors[colorIdx % colors.length],
            ),
          );
          colorIdx++;
        }
      } else {
        // Fallback to local passed list if no backend family group found yet
        list = List.from(widget.fallbackMembers);
      }

      if (mounted) {
        setState(() {
          _familyRole = familyRole;
          _displayMembers = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[FridgeMembersModal] Error fetching family data: $e');
      if (mounted) {
        setState(() {
          _displayMembers = List.from(widget.fallbackMembers);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleAddMember() async {
    final text = _inviteController.text.trim();
    if (text.isEmpty) {
      _showSnackBar('Vui lòng nhập Email thành viên!', isError: true);
      return;
    }

    if (!text.contains('@')) {
      _showSnackBar('Địa chỉ email không hợp lệ!', isError: true);
      return;
    }

    setState(() => _isActionLoading = true);
    try {
      await _apiService.inviteFamilyMember(text);
      if (mounted) {
        _inviteController.clear();
        FocusScope.of(context).unfocus();
        _showSnackBar('Đã gửi lời mời tham gia gia đình tới "$text"!');
        await _fetchFamilyData();
      }
    } catch (e) {
      debugPrint('[FridgeMembersModal] Error inviting member: $e');
      // If error occurs (e.g. backend error or local test), try fallback local addition if role is none
      final errorMsg = e.toString().replaceAll('ApiException: ', '');
      if (_familyRole?.group == null) {
        final newMember = FridgeMemberModel(
          id: 'member_${DateTime.now().millisecondsSinceEpoch}',
          name: text.split('@').first,
          emailOrPhone: text,
          role: 'Thành viên',
          isOwner: false,
        );
        widget.onAddMember(newMember);
        _inviteController.clear();
        if (mounted) FocusScope.of(context).unfocus();
        await _fetchFamilyData();
        _showSnackBar('Đã thêm thành viên "$text" vào tủ!');
      } else if (mounted) {
        _showSnackBar(errorMsg, isError: true);
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleRemoveMember(FridgeMemberModel member) async {
    setState(() => _isActionLoading = true);
    try {
      if (_familyRole?.group != null) {
        await _apiService.removeFamilyMember(member.id);
        if (mounted) {
          _showSnackBar('Đã xóa thành viên "${member.name}"!');
          await _fetchFamilyData();
        }
      } else {
        widget.onRemoveMember(member.id);
        if (mounted) {
          _showSnackBar('Đã xóa thành viên "${member.name}"!');
          await _fetchFamilyData();
        }
      }
    } catch (e) {
      debugPrint('[FridgeMembersModal] Error removing member: $e');
      if (mounted) {
        _showSnackBar(
          e.toString().replaceAll('ApiException: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFD32F2F) : const Color(0xFF008435),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOwner = _familyRole?.role == 'owner' || _familyRole?.role == 'none';

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF19271E) : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
          border: isDark
              ? const Border(top: BorderSide(color: Color(0xFF2E4D36), width: 1.2))
              : null,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Drag Indicator
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2E4D36) : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
              ),

              SizedBox(height: 18.h),

              // Header Title & Manage Button
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF233629) : const Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.group_rounded,
                      color: isDark ? const Color(0xFF81C784) : const Color(0xFF006428),
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thành viên dùng chung',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF006428),
                          ),
                        ),
                        Text(
                          widget.fridgeName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF81C784) : const Color(0xFF558B2F),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FamilyManagementScreen(),
                        ),
                      );
                    },
                    icon: Icon(Icons.settings_outlined, size: 16),
                    label: Text('Quản lý'),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? const Color(0xFF81C784) : const Color(0xFF008435),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 20.h),

              // Loading State
              if (_isLoading)
                Padding(
                  padding: EdgeInsets.all(30.0.w),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                // Section 1: Current Members List
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Danh sách thành viên',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF006428),
                      ),
                    ),
                    if (_familyRole?.group != null)
                      Text(
                        '${_familyRole!.group!.activeCount}/${_familyRole!.group!.maxMembers} người',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFF81C784) : const Color(0xFF006428),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 10.h),

                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0E1611) : const Color(0xFFF5FCF4),
                    borderRadius: BorderRadius.circular(22.r),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFA5E69C),
                      width: 1.2,
                    ),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _displayMembers.length,
                    separatorBuilder: (context, index) => Container(
                      margin: EdgeInsets.symmetric(horizontal: 16),
                      height: 1,
                      color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFE8F5E9),
                    ),
                    itemBuilder: (context, index) {
                      final member = _displayMembers[index];
                      final isPending = member.role == 'Đang chờ';
                      return ListTile(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: member.avatarBgColor,
                              child: Text(
                                member.name.isEmpty
                                    ? 'U'
                                    : member.name.characters.first.toUpperCase(),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (member.isOwner)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  padding: EdgeInsets.all(2.w),
                                  decoration: BoxDecoration(
                                    color: Color(0xFFFFB74D),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.star_rounded,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                member.name,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14.5.sp,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF19221C),
                                ),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: member.isOwner
                                    ? (isDark ? const Color(0xFF3E2C17) : const Color(0xFFFFF3E0))
                                    : (isPending
                                        ? const Color(0xFFFFF3E0)
                                        : (isDark ? const Color(0xFF233629) : const Color(0xFFE8F5E9))),
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(
                                  color: member.isOwner
                                      ? const Color(0xFFFFB74D)
                                      : (isPending
                                          ? const Color(0xFFFFB74D)
                                          : (isDark ? const Color(0xFF2E4D36) : const Color(0xFFA5E69C))),
                                ),
                              ),
                              child: Text(
                                member.role,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w800,
                                  color: member.isOwner
                                      ? (isDark ? const Color(0xFFFFB74D) : const Color(0xFFE65100))
                                      : (isPending
                                          ? const Color(0xFFE65100)
                                          : (isDark ? const Color(0xFF81C784) : const Color(0xFF006428))),
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          member.emailOrPhone,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5.sp,
                            color: isDark ? const Color(0xFF9DA8A0) : const Color(0xFF757575),
                          ),
                        ),
                        trailing: !member.isOwner && isOwner
                            ? IconButton(
                                icon: Icon(
                                  Icons.remove_circle_outline_rounded,
                                  color: isDark ? const Color(0xFFE57373) : const Color(0xFFE53935),
                                  size: 20,
                                ),
                                onPressed: _isActionLoading
                                    ? null
                                    : () => _handleRemoveMember(member),
                              )
                            : null,
                      );
                    },
                  ),
                ),

                SizedBox(height: 22.h),

                // Section 2: Add New Member Form
                Text(
                  'Thêm thành viên mới',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF006428),
                  ),
                ),
                SizedBox(height: 10.h),

                // Input Field & Direct Add Button Row
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0E1611) : const Color(0xFFF5FCF4),
                          borderRadius: BorderRadius.circular(18.r),
                          border: Border.all(
                            color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFA5E69C),
                            width: 1.2,
                          ),
                        ),
                        child: TextField(
                          controller: _inviteController,
                          keyboardType: TextInputType.emailAddress,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF19221C),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Nhập Email thành viên...',
                            hintStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 13.sp,
                              color: isDark ? const Color(0xFF9DA8A0) : const Color(0xFF9E9E9E),
                            ),
                            prefixIcon: Icon(
                              Icons.person_add_alt_1_rounded,
                              color: isDark ? const Color(0xFF81C784) : const Color(0xFF4CAF50),
                              size: 20,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 13,
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(width: 10.w),

                    // Direct Add Button
                    ElevatedButton(
                      onPressed: _isActionLoading ? null : _handleAddMember,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF81C784) : const Color(0xFF4CAF50),
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18.r),
                        ),
                      ),
                      child: _isActionLoading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Row(
                              children: [
                                Icon(
                                  Icons.add_rounded,
                                  color: isDark ? const Color(0xFF0E1611) : Colors.white,
                                  size: 20,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  'Thêm',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? const Color(0xFF0E1611) : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),

                SizedBox(height: 16.h),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
