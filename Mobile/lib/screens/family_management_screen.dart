import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/models/user_models.dart';
import '../data/services/api_service.dart';
import '../l10n/app_localizations.dart';
import '../config/app_constants.dart';
import '../widgets/family_plan_modal.dart';

class FamilyManagementScreen extends StatefulWidget {
  final String? initialInviteToken;
  const FamilyManagementScreen({super.key, this.initialInviteToken});

  @override
  State<FamilyManagementScreen> createState() => _FamilyManagementScreenState();
}

class _FamilyManagementScreenState extends State<FamilyManagementScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  FamilyRoleModel? _familyRole;

  final TextEditingController _inviteEmailController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();

  bool _isActionLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFamilyInfo();
    if (widget.initialInviteToken != null && widget.initialInviteToken!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleAcceptInviteToken(widget.initialInviteToken!);
      });
    }
  }

  @override
  void dispose() {
    _inviteEmailController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _loadFamilyInfo() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.getMyFamily();
      final familyRole = FamilyRoleModel.fromJson(res);
      if (mounted) {
        setState(() {
          _familyRole = familyRole;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[FamilyManagementScreen] Error loading family info: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleInviteMember() async {
    final email = _inviteEmailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnackBar('Vui lòng nhập địa chỉ email hợp lệ', isError: true);
      return;
    }

    setState(() => _isActionLoading = true);
    try {
      await _apiService.inviteFamilyMember(email);
      if (mounted) {
        Navigator.pop(context);
        _inviteEmailController.clear();
        _showSnackBar('Đã gửi lời mời tham gia tới $email');
        _loadFamilyInfo();
      }
    } catch (e) {
      debugPrint('[FamilyManagementScreen] Error inviting member: $e');
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

  Future<void> _handleRemoveMember(FamilyMemberModel member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final displayName = member.memberName ?? member.invitedEmail;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF19271E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          title: Text(
            'Xóa thành viên',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF19221C),
            ),
          ),
          content: Text(
            'Bạn có chắc chắn muốn xóa $displayName khỏi nhóm gia đình?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14.sp,
              color: isDark ? const Color(0xFFD0D7D1) : const Color(0xFF616161),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Hủy',
                style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isActionLoading = true);
    try {
      await _apiService.removeFamilyMember(member.id);
      if (mounted) {
        _showSnackBar('Đã xóa thành viên thành công');
        _loadFamilyInfo();
      }
    } catch (e) {
      debugPrint('[FamilyManagementScreen] Error removing member: $e');
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

  Future<void> _handleDissolveGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF19271E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFE53935)),
              SizedBox(width: 8.w),
              Text(
                'Giải tán gia đình',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFE53935),
                ),
              ),
            ],
          ),
          content: Text(
            'Tất cả thành viên sẽ rời khỏi nhóm và nhận thông báo. Bạn có chắc chắn muốn giải tán nhóm gia đình này không?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14.sp,
              color: isDark ? const Color(0xFFD0D7D1) : const Color(0xFF616161),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Hủy',
                style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              child: const Text('Giải tán'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isActionLoading = true);
    try {
      await _apiService.dissolveFamilyGroup();
      if (mounted) {
        _showSnackBar('Đã giải tán nhóm gia đình');
        _loadFamilyInfo();
      }
    } catch (e) {
      debugPrint('[FamilyManagementScreen] Error dissolving group: $e');
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

  Future<void> _handleAcceptInviteToken(String token) async {
    setState(() => _isActionLoading = true);
    try {
      await _apiService.acceptFamilyInvite(token);
      if (mounted) {
        _tokenController.clear();
        _showSnackBar('Chúc mừng! Bạn đã tham gia nhóm gia đình thành công 🎉');
        _loadFamilyInfo();
      }
    } catch (e) {
      debugPrint('[FamilyManagementScreen] Error accepting invite token: $e');
      if (mounted) {
        _showSnackBar(
          'Không thể chấp nhận lời mời: ${e.toString().replaceAll('ApiException: ', '')}',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleRejectInviteToken(String token) async {
    setState(() => _isActionLoading = true);
    try {
      await _apiService.rejectFamilyInvite(token);
      if (mounted) {
        _tokenController.clear();
        _showSnackBar('Đã từ chối lời mời gia đình');
        _loadFamilyInfo();
      }
    } catch (e) {
      debugPrint('[FamilyManagementScreen] Error rejecting invite token: $e');
      if (mounted) {
        _showSnackBar(
          'Không thể từ chối lời mời: ${e.toString().replaceAll('ApiException: ', '')}',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  void _showInviteDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF19271E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          title: Text(
            'Mời thành viên mới',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF006428),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nhập địa chỉ email người thân để gửi lời mời tham gia gói gia đình (tối đa 5 người):',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.sp,
                  color: isDark ? const Color(0xFFD0D7D1) : const Color(0xFF616161),
                ),
              ),
              SizedBox(height: 14.h),
              TextField(
                controller: _inviteEmailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Email người được mời',
                  hintText: 'vi-du@gmail.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF233629) : const Color(0xFFF5F5F5),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Hủy',
                style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
              ),
            ),
            ElevatedButton(
              onPressed: _isActionLoading ? null : _handleInviteMember,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF008435),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              child: _isActionLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Gửi lời mời'),
            ),
          ],
        );
      },
    );
  }

  void _showTokenInputDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF19271E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          title: Text(
            'Nhập Token lời mời',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF006428),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nếu bạn nhận được mã Token lời mời từ Email, nhập mã vào đây để tham gia:',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.sp,
                  color: isDark ? const Color(0xFFD0D7D1) : const Color(0xFF616161),
                ),
              ),
              SizedBox(height: 14.h),
              TextField(
                controller: _tokenController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Mã Token lời mời',
                  hintText: 'Dán mã token từ email',
                  prefixIcon: const Icon(Icons.key_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF233629) : const Color(0xFFF5F5F5),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Hủy',
                style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
              ),
            ),
            OutlinedButton(
              onPressed: () {
                final token = _tokenController.text.trim();
                if (token.isNotEmpty) {
                  Navigator.pop(context);
                  _handleRejectInviteToken(token);
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE53935),
                side: const BorderSide(color: Color(0xFFE53935)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              child: const Text('Từ chối'),
            ),
            ElevatedButton(
              onPressed: () {
                final token = _tokenController.text.trim();
                if (token.isNotEmpty) {
                  Navigator.pop(context);
                  _handleAcceptInviteToken(token);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF008435),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              child: const Text('Tham gia'),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFE53935) : const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String? _getFullAvatarUrl(String? url) {
    return AppConstants.getImageUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final isEn = loc?.locale.languageCode == 'en';

    final bgGradient = isDark
        ? LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0C1610), Color(0xFF142017)],
          )
        : LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF4F7F5), Color(0xFFE8EFEA)],
          );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          isEn ? 'Family Group' : 'Nhóm Gia Đình',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF006428),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadFamilyInfo,
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: bgGradient),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadFamilyInfo,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(20.w),
                  child: _buildContent(isDark, isEn),
                ),
              ),
      ),
    );
  }

  Widget _buildContent(bool isDark, bool isEn) {
    final role = _familyRole?.role ?? 'none';
    final group = _familyRole?.group;

    if (role == 'none' || group == null) {
      return _buildNoGroupView(isDark, isEn);
    }

    final isOwner = role == 'owner';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Banner Card
        _buildGroupHeaderCard(group, isOwner, isDark, isEn),
        SizedBox(height: 24.h),

        // Owner Info Card
        _buildOwnerCard(group.owner, isDark, isEn),
        SizedBox(height: 24.h),

        // Members List Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isEn
                  ? 'Members (${group.members.length})'
                  : 'Thành viên (${group.members.length})',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF006428),
              ),
            ),
            if (isOwner && group.activeCount < group.maxMembers)
              ElevatedButton.icon(
                onPressed: _showInviteDialog,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: Text(
                  isEn ? 'Invite' : 'Mời người dùng',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.sp,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF008435),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                ),
              ),
          ],
        ),
        SizedBox(height: 12.h),

        // Members List
        if (group.members.isEmpty)
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF19271E) : Colors.white,
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Center(
              child: Text(
                isEn
                    ? 'No other members in family group yet.'
                    : 'Chưa có thành viên nào khác trong gia đình.',
                style: TextStyle(
                  color: isDark ? const Color(0xFF9DA8A0) : const Color(0xFF757575),
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: group.members.length,
            separatorBuilder: (context, index) => SizedBox(height: 10.h),
            itemBuilder: (context, index) {
              final member = group.members[index];
              return _buildMemberTile(member, isOwner, isDark, isEn);
            },
          ),

        SizedBox(height: 32.h),

        // Token Input Button for accepting invite via token manually
        Center(
          child: TextButton.icon(
            onPressed: _showTokenInputDialog,
            icon: const Icon(Icons.vpn_key_outlined, size: 18),
            label: Text(
              isEn ? 'Enter invitation token' : 'Nhập mã Token lời mời',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),

        SizedBox(height: 16.h),

        // Dissolve Group Button for Owner
        if (isOwner)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _isActionLoading ? null : _handleDissolveGroup,
              icon: const Icon(Icons.delete_forever_rounded, color: Color(0xFFE53935)),
              label: Text(
                isEn ? 'Dissolve Family Group' : 'Giải tán nhóm gia đình',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFE53935),
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE53935), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNoGroupView(bool isDark, bool isEn) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(height: 40.h),
        Container(
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E3A25) : const Color(0xFFE8F5E9),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.family_restroom_rounded,
            size: 80,
            color: isDark ? const Color(0xFF81C784) : const Color(0xFF006428),
          ),
        ),
        SizedBox(height: 24.h),
        Text(
          isEn ? 'No Family Group Yet' : 'Chưa có nhóm gia đình',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 24.sp,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF006428),
          ),
        ),
        SizedBox(height: 12.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            isEn
                ? 'Upgrade to the Family Plan to create a family group and share smart fridge & AI features with up to 5 members.'
                : 'Đăng ký Gói Gia Đình để tạo nhóm và chia sẻ tính năng tủ lạnh thông minh & AI với tối đa 5 người thân.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14.sp,
              color: isDark ? const Color(0xFFD0D7D1) : const Color(0xFF616161),
              height: 1.4,
            ),
          ),
        ),
        SizedBox(height: 32.h),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () {
              showFamilySubscriptionModal(context, onSuccess: () {
                _loadFamilyInfo();
              });
            },
            icon: const Icon(Icons.workspace_premium_rounded),
            label: Text(
              isEn ? 'Upgrade to Family Plan' : 'Nâng cấp Gói Gia Đình',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF008435),
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
            ),
          ),
        ),
        SizedBox(height: 16.h),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: _showTokenInputDialog,
            icon: const Icon(Icons.vpn_key_rounded, color: Color(0xFF4CAF50)),
            label: Text(
              isEn ? 'Have an invitation code?' : 'Bạn có mã Token lời mời?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF006428),
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFA5E69C),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupHeaderCard(
    FamilyGroupModel group,
    bool isOwner,
    bool isDark,
    bool isEn,
  ) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.r),
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E3A25), const Color(0xFF142017)]
              : [const Color(0xFF008435), const Color(0xFF2E7D32)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.family_restroom_rounded, color: Colors.white, size: 28),
                  SizedBox(width: 10.w),
                  Text(
                    isEn ? 'Family Plan' : 'Gói Gia Đình',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: isOwner ? const Color(0xFFFFB74D) : const Color(0xFF81C784),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  isOwner ? (isEn ? 'Owner' : 'Chủ nhóm') : (isEn ? 'Member' : 'Thành viên'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isEn ? 'Active slots:' : 'Số thành viên đang dùng:',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.sp,
                  color: Colors.white70,
                ),
              ),
              Text(
                '${group.activeCount} / ${group.maxMembers}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(6.r),
            child: LinearProgressIndicator(
              value: group.activeCount / group.maxMembers,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              color: const Color(0xFFFFD54F),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerCard(FamilyOwnerModel owner, bool isDark, bool isEn) {
    final avatar = _getFullAvatarUrl(owner.avatar);
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF19271E) : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFA5E69C),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: isDark ? const Color(0xFF2E4D36) : const Color(0xFFE8F5E9),
            backgroundImage: avatar != null ? NetworkImage(avatar) : null,
            child: avatar == null
                ? Text(
                    (owner.name ?? 'U').substring(0, 1).toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF006428),
                    ),
                  )
                : null,
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      owner.name ?? (isEn ? 'Family Owner' : 'Chủ gia đình'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF19221C),
                      ),
                    ),
                    SizedBox(width: 6.w),
                    const Icon(Icons.star_rounded, color: Color(0xFFFFB74D), size: 16),
                  ],
                ),
                SizedBox(height: 2.h),
                Text(
                  isEn ? 'Group Creator / Subscription Owner' : 'Trưởng nhóm / Chủ gói dịch vụ',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.sp,
                    color: isDark ? const Color(0xFF9DA8A0) : const Color(0xFF757575),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberTile(
    FamilyMemberModel member,
    bool isOwner,
    bool isDark,
    bool isEn,
  ) {
    final avatar = _getFullAvatarUrl(member.memberAvatar);
    final isPending = member.status == 'pending';
    final displayName = member.memberName ?? member.invitedEmail;

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF19271E) : Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: isDark ? const Color(0xFF233629) : const Color(0xFFE0E0E0),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: isDark ? const Color(0xFF233629) : const Color(0xFFF1F8E9),
            backgroundImage: avatar != null ? NetworkImage(avatar) : null,
            child: avatar == null
                ? Text(
                    displayName.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF006428),
                    ),
                  )
                : null,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF19221C),
                  ),
                ),
                if (member.memberName != null)
                  Text(
                    member.invitedEmail,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: isDark ? const Color(0xFF9DA8A0) : const Color(0xFF757575),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 8.w),

          // Status Badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: isPending
                  ? const Color(0xFFFFF3E0)
                  : (isDark ? const Color(0xFF1E3A25) : const Color(0xFFE8F5E9)),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Text(
              isPending
                  ? (isEn ? 'Pending' : 'Đang chờ')
                  : (isEn ? 'Active' : 'Đang tham gia'),
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
                color: isPending ? const Color(0xFFE65100) : const Color(0xFF2E7D32),
              ),
            ),
          ),

          // Action Button for Owner
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFFE53935)),
              onPressed: _isActionLoading ? null : () => _handleRemoveMember(member),
              tooltip: isEn ? 'Remove member' : 'Xóa thành viên',
            ),
        ],
      ),
    );
  }
}
