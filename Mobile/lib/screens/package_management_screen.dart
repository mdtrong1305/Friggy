import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/models/user_models.dart';
import '../data/services/api_service.dart';
import '../l10n/app_localizations.dart';

class PackageManagementScreen extends StatefulWidget {
  final bool onlyFamily;
  const PackageManagementScreen({super.key, this.onlyFamily = false});

  @override
  State<PackageManagementScreen> createState() =>
      _PackageManagementScreenState();
}

class _PackageManagementScreenState extends State<PackageManagementScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  UserSubscriptionModel? _userSub;
  List<SubscriptionPlanModel> _plans = [];

  @override
  void initState() {
    super.initState();
    _fetchSubscriptionData();
  }

  Future<SubscribeResponseModel?> _checkPendingPaymentTransaction() async {
    try {
      final historyRes = await _apiService.getMyPaymentTransactions(page: 1, limit: 1);
      final dataList = historyRes['data'] as List<dynamic>? ?? [];

      if (dataList.isNotEmpty) {
        final item = dataList.first;
        if (item is Map<String, dynamic> && item['status'] == 'pending') {
          final paymentRef = item['paymentRef'] as String?;
          if (paymentRef != null && paymentRef.isNotEmpty) {
            final detail = await _apiService.checkPaymentTransaction(paymentRef);
            final status = detail['status'] as String?;
            if (status == 'pending') {
              final model = SubscribeResponseModel.fromJson(detail);
              if (model.qrCodeUrl.isNotEmpty) {
                return model;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[PackageManagementScreen] Error checking pending transaction: $e');
    }
    return null;
  }

  Future<void> _fetchSubscriptionData() async {
    setState(() => _isLoading = true);
    try {
      final subJson = await _apiService.getMySubscription();
      final plansJson = await _apiService.getSubscriptionPlans();

      final parsedSub = UserSubscriptionModel.fromJson(subJson);
      final parsedPlans = plansJson
          .map((e) => SubscriptionPlanModel.fromJson(e as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _userSub = parsedSub;
          _plans = parsedPlans;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[PackageManagementScreen] Error fetching subscription: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatPrice(int priceVnd) {
    if (priceVnd == 0) return '0 VNĐ';
    final str = priceVnd.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
    return '$str VNĐ';
  }

  String _formatDateString(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Không giới hạn';
    try {
      final parts = dateStr.split('T').first.split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
    } catch (_) {}
    return dateStr;
  }

  void _showAllPlansModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final isEn = loc?.locale.languageCode == 'en';

    final displayedPlans = widget.onlyFamily
        ? _plans
            .where((p) =>
                p.name.toLowerCase().contains('family') ||
                p.displayName.toLowerCase().contains('gia đình'))
            .toList()
        : _plans;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF142017) : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              SizedBox(height: 20.h),
              Row(
                children: [
                  Icon(
                    Icons.workspace_premium_rounded,
                    color: isDark ? Colors.white : const Color(0xFF006428),
                    size: 28,
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    isEn ? 'Friggy Service Plans' : 'Các gói dịch vụ Friggy',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF006428),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 18.h),

              if (displayedPlans.isEmpty)
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0.w),
                    child: Text(
                      isEn ? 'No plans available' : 'Không có gói dịch vụ nào',
                      style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                    ),
                  ),
                )
              else
                ...displayedPlans.map((plan) {
                  final isCurrentPlan = _userSub?.plan.id == plan.id ||
                      (_userSub?.plan.name.toLowerCase() == plan.name.toLowerCase());

                  String buttonText;
                  Color buttonColor;
                  VoidCallback? onTapAction;

                  if (isCurrentPlan) {
                    if (plan.priceVnd > 0) {
                      if (_userSub?.autoRenew == true) {
                        buttonText = isEn ? 'Cancel Auto-Renewal' : 'Hủy gia hạn tự động';
                        buttonColor = const Color(0xFFE53935);
                        onTapAction = () {
                          Navigator.pop(context);
                          _confirmCancelAutoRenewal();
                        };
                      } else {
                        buttonText = isEn ? 'Renew Plan (+1 month)' : 'Gia hạn gói (+1 tháng)';
                        buttonColor = const Color(0xFF008435);
                        onTapAction = () {
                          Navigator.pop(context);
                          _handleRenew();
                        };
                      }
                    } else {
                      buttonText = isEn ? 'Current Default Plan' : 'Gói mặc định hiện tại';
                      buttonColor = Colors.grey.shade400;
                      onTapAction = null;
                    }
                  } else {
                    if (plan.priceVnd > 0) {
                      buttonText = isEn ? 'Upgrade Plan' : 'Nâng cấp gói';
                      buttonColor = const Color(0xFF008435);
                      onTapAction = () {
                        Navigator.pop(context);
                        _handleSubscribe(plan.id);
                      };
                    } else {
                      buttonText = isEn ? 'Default Plan' : 'Gói mặc định';
                      buttonColor = Colors.grey.shade400;
                      onTapAction = null;
                    }
                  }

                  return Padding(
                    padding: EdgeInsets.only(bottom: 16.0.h),
                    child: _buildPlanCard(
                      title: plan.displayName,
                      price: _formatPrice(plan.priceVnd),
                      period: plan.billingCycle == 'monthly' ? (isEn ? '/ month' : '/ tháng') : (isEn ? 'Forever' : 'Mãi mãi'),
                      description: plan.aiUsagePerWeek == -1
                          ? (isEn ? 'Unlimited AI features enabled' : 'Đầy đủ tính năng AI không giới hạn')
                          : (isEn ? 'Up to ${plan.aiUsagePerWeek} AI calls per week' : 'Giới hạn ${plan.aiUsagePerWeek} lượt AI / tuần'),
                      isCurrentPlan: isCurrentPlan,
                      badgeText: isCurrentPlan ? (isEn ? 'Currently Active' : 'Đang sử dụng') : null,
                      features: plan.features,
                      buttonText: buttonText,
                      buttonColor: buttonColor,
                      onTap: onTapAction,
                      isDark: isDark,
                    ),
                  );
                }),

              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubscribe(int planId) async {
    setState(() => _isLoading = true);
    try {
      // 1. Kiểm tra xem có giao dịch đang chờ thanh toán nào không
      final pending = await _checkPendingPaymentTransaction();
      if (pending != null) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚡ Đã khôi phục mã QR thanh toán đang chờ xử lý...'),
              backgroundColor: Color(0xFF2E7D32),
              behavior: SnackBarBehavior.floating,
            ),
          );
          _showQrPaymentModal(pending);
        }
        return;
      }

      // 2. Tạo giao dịch thanh toán mới nếu không có giao dịch pending
      final res = await _apiService.subscribePlan(planId);
      final subscribeData = SubscribeResponseModel.fromJson(res);
      if (mounted) {
        setState(() => _isLoading = false);
        _showQrPaymentModal(subscribeData);
      }
    } catch (e) {
      debugPrint('[PackageManagementScreen] Error subscribing plan: $e');

      // 3. Nếu gặp lỗi do đã có giao dịch, tự động tra cứu và hiển thị mã QR
      final pending = await _checkPendingPaymentTransaction();
      if (pending != null && mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚡ Đã khôi phục mã QR thanh toán đang chờ xử lý...'),
            backgroundColor: Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _showQrPaymentModal(pending);
        return;
      }

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('ApiException: ', '')),
            backgroundColor: const Color(0xFFE53935),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showQrPaymentModal(SubscribeResponseModel data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final isEn = loc?.locale.languageCode == 'en';
    bool isChecking = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        Timer? pollTimer;

        // Auto-poll status every 3s via transaction status & subscription
        pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
          try {
            final tx = await _apiService.checkPaymentTransaction(data.paymentRef);
            final txStatus = tx['status'] as String?;

            if (txStatus == 'paid') {
              timer.cancel();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('🎉 Kích hoạt thành công gói dịch vụ!'),
                    backgroundColor: Color(0xFF2E7D32),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                _fetchSubscriptionData();
              }
              return;
            }

            final subJson = await _apiService.getMySubscription();
            final sub = UserSubscriptionModel.fromJson(subJson);
            if (sub.status == 'active') {
              timer.cancel();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('🎉 Kích hoạt thành công ${sub.plan.displayName}!'),
                    backgroundColor: const Color(0xFF2E7D32),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                _fetchSubscriptionData();
              }
            }
          } catch (_) {}
        });

        return StatefulBuilder(
          builder: (context, setModalState) {
            return PopScope(
              onPopInvokedWithResult: (didPop, result) {
                if (didPop) {
                  pollTimer?.cancel();
                }
              },
              child: Container(
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF19271E) : Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFE2E8E4),
                          borderRadius: BorderRadius.circular(2.r),
                        ),
                      ),
                      SizedBox(height: 18.h),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.qr_code_2_rounded, color: Color(0xFF4CAF50), size: 28),
                          SizedBox(width: 8.w),
                          Text(
                            isEn ? 'Payment QR Code' : 'Mã QR Thanh Toán PayOS',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 22.sp,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF006428),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),

                      Text(
                        isEn
                            ? 'Scan the VietQR code below via Banking / MoMo / VNPay to complete payment'
                            : 'Quét mã QR bên dưới bằng Ngân hàng / MoMo / VNPay để hoàn tất thanh toán',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5.sp,
                          color: isDark ? const Color(0xFFD0D7D1) : const Color(0xFF6B786F),
                        ),
                      ),
                      SizedBox(height: 16.h),

                      // QR Code Image Container
                      Container(
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _buildQrCodeWidget(data.qrCodeUrl),
                      ),
                      SizedBox(height: 18.h),

                      // Info Rows: Amount & Payment Ref
                      Container(
                        padding: EdgeInsets.all(14.w),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF233629) : const Color(0xFFF1F8E9),
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(
                            color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFA5E69C),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  isEn ? 'Amount:' : 'Số tiền thanh toán:',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13.5.sp,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFFD0D7D1) : const Color(0xFF616161),
                                  ),
                                ),
                                Text(
                                  _formatPrice(data.amount),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 17.sp,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? const Color(0xFF81C784) : const Color(0xFF006428),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 6.h),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  isEn ? 'Payment Ref:' : 'Mã tham chiếu:',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13.5.sp,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFFD0D7D1) : const Color(0xFF616161),
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Flexible(
                                  child: Text(
                                    data.paymentRef,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13.5.sp,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : const Color(0xFF19221C),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20.h),

                      // Real Payment Check Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isChecking
                              ? null
                              : () async {
                                  setModalState(() => isChecking = true);
                                  try {
                                    final tx = await _apiService.checkPaymentTransaction(data.paymentRef);
                                    final txStatus = tx['status'] as String?;

                                    if (txStatus == 'paid') {
                                      pollTimer?.cancel();
                                      if (context.mounted) {
                                        setModalState(() => isChecking = false);
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('🎉 Kích hoạt thành công gói dịch vụ!'),
                                            backgroundColor: Color(0xFF2E7D32),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                        _fetchSubscriptionData();
                                      }
                                      return;
                                    }

                                    final subJson = await _apiService.getMySubscription();
                                    final sub = UserSubscriptionModel.fromJson(subJson);

                                    if (context.mounted) {
                                      setModalState(() => isChecking = false);
                                      if (sub.status == 'active') {
                                        pollTimer?.cancel();
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('🎉 Kích hoạt thành công ${sub.plan.displayName}!'),
                                            backgroundColor: const Color(0xFF2E7D32),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                        _fetchSubscriptionData();
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Hệ thống chưa nhận được thanh toán. Vui lòng quét mã QR bằng App Ngân hàng và thử lại!'),
                                            backgroundColor: Color(0xFFE65100),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      setModalState(() => isChecking = false);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Không thể kiểm tra: $e'),
                                          backgroundColor: const Color(0xFFE53935),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF008435),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24.r),
                            ),
                          ),
                          child: isChecking
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.published_with_changes_rounded, size: 20),
                                    SizedBox(width: 6.w),
                                    Flexible(
                                      child: Text(
                                        isEn
                                            ? 'I Have Paid (Check Status)'
                                            : 'Tôi đã thanh toán (Kiểm tra ngay)',
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13.5.sp,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      SizedBox(height: 12.h),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleRenew() async {
    setState(() => _isLoading = true);
    try {
      final pending = await _checkPendingPaymentTransaction();
      if (pending != null) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚡ Đã khôi phục mã QR gia hạn đang chờ xử lý...'),
              backgroundColor: Color(0xFF2E7D32),
              behavior: SnackBarBehavior.floating,
            ),
          );
          _showQrPaymentModal(pending);
        }
        return;
      }

      final res = await _apiService.renewSubscription();
      final subscribeData = SubscribeResponseModel.fromJson(res);
      if (mounted) {
        setState(() => _isLoading = false);
        _showQrPaymentModal(subscribeData);
      }
    } catch (e) {
      debugPrint('[PackageManagementScreen] Error renewing plan: $e');

      final pending = await _checkPendingPaymentTransaction();
      if (pending != null && mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚡ Đã khôi phục mã QR gia hạn đang chờ xử lý...'),
            backgroundColor: Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _showQrPaymentModal(pending);
        return;
      }

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('ApiException: ', '')),
            backgroundColor: const Color(0xFFE53935),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _confirmCancelAutoRenewal() {
    final loc = AppLocalizations.of(context);
    final isEn = loc?.locale.languageCode == 'en';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          title: Text(isEn ? 'Cancel Auto-Renewal?' : 'Hủy gia hạn tự động?'),
          content: Text(
            isEn
                ? 'Your subscription will stay active until expiry date, then automatically revert to Free plan.'
                : 'Gói dịch vụ của bạn vẫn giữ nguyên đến hết ngày hết hạn, sau đó mới chuyển về gói Miễn Phí.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isEn ? 'Keep Auto-Renewal' : 'Giữ gia hạn'),
            ),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                setState(() => _isLoading = true);
                try {
                  final res = await _apiService.cancelAutoRenewal();
                  final msg = res['message']?.toString() ?? 'Đã hủy gia hạn tự động thành công.';
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(msg),
                        backgroundColor: const Color(0xFF008435),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    _fetchSubscriptionData();
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() => _isLoading = false);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(e.toString().replaceAll('ApiException: ', '')),
                        backgroundColor: const Color(0xFFE53935),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
              ),
              child: Text(isEn ? 'Confirm Cancel' : 'Xác nhận hủy gia hạn'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQrCodeWidget(String qrCodeStr) {
    final cleanStr = qrCodeStr.trim();
    if (cleanStr.isEmpty) {
      return const Icon(
        Icons.qr_code_rounded,
        size: 140,
        color: Colors.grey,
      );
    }

    if (cleanStr.startsWith('data:image') || cleanStr.contains('base64,')) {
      try {
        final base64Clean = cleanStr.contains('base64,')
            ? cleanStr.split('base64,').last
            : cleanStr;
        final bytes = base64Decode(base64Clean);
        return Image.memory(
          bytes,
          width: 200,
          height: 200,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.qr_code_rounded,
            size: 140,
            color: Colors.grey,
          ),
        );
      } catch (e) {
        debugPrint('Base64 QR Decode error: $e');
      }
    }

    final String imageUrl =
        (cleanStr.startsWith('http://') || cleanStr.startsWith('https://'))
            ? cleanStr
            : 'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${Uri.encodeComponent(cleanStr)}';

    return Image.network(
      imageUrl,
      width: 200,
      height: 200,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const SizedBox(
          width: 200,
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        if (!cleanStr.startsWith('http://') &&
            !cleanStr.startsWith('https://')) {
          final fallbackUrl =
              'https://quickchart.io/qr?text=${Uri.encodeComponent(cleanStr)}&size=300';
          return Image.network(
            fallbackUrl,
            width: 200,
            height: 200,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.qr_code_rounded,
              size: 140,
              color: Colors.grey,
            ),
          );
        }
        return const Icon(
          Icons.qr_code_rounded,
          size: 140,
          color: Colors.grey,
        );
      },
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    required String period,
    required String description,
    required bool isCurrentPlan,
    String? badgeText,
    required List<String> features,
    required String buttonText,
    required Color buttonColor,
    VoidCallback? onTap,
    bool isDark = false,
  }) {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: isDark
            ? (isCurrentPlan ? const Color(0xFF1E3A25) : const Color(0xFF19271E))
            : (isCurrentPlan ? const Color(0xFFF1F8E9) : Colors.white),
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
          color: isCurrentPlan
              ? const Color(0xFF4CAF50)
              : (isDark ? const Color(0xFF2E4D36) : const Color(0xFFE0E0E0)),
          width: isCurrentPlan ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (badgeText != null) ...[
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: isCurrentPlan
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFFFB74D),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Text(
                badgeText,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(height: 8.h),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF006428),
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      description,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5.sp,
                        color: isDark ? const Color(0xFF9DA8A0) : const Color(0xFF757575),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    price,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w900,
                      color: isDark ? const Color(0xFF81C784) : const Color(0xFF006428),
                    ),
                  ),
                  Text(
                    period,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5.sp,
                      color: isDark ? const Color(0xFF9DA8A0) : const Color(0xFF757575),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ...features.map(
            (feat) => Padding(
              padding: EdgeInsets.only(bottom: 4.h),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_rounded,
                    color: Color(0xFF4CAF50),
                    size: 16,
                  ),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      feat,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF19221C),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 14.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
              child: Text(
                buttonText,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final isEn = loc?.locale.languageCode == 'en';

    final currentPlan = _userSub?.plan;
    final planNameDisplay = currentPlan?.displayName ?? (isEn ? 'Free Plan' : 'Gói Miễn Phí');
    final isPaidPlan = currentPlan != null && currentPlan.priceVnd > 0;
    final priceDisplay = currentPlan != null ? _formatPrice(currentPlan.priceVnd) : '0 VNĐ';

    final startDateDisplay = _formatDateString(_userSub?.startDate);
    final endDateDisplay = _formatDateString(_userSub?.endDate);

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
                  ],
            stops: isDark ? const [0.0, 0.5, 1.0] : const [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar Header
              Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: 16.0.w, vertical: 8.0.h),
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
                    SizedBox(width: 14.w),
                    Text(
                      isEn ? 'Membership Plans' : 'Thông tin gói dịch vụ',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF006428),
                      ),
                    ),
                  ],
                ),
              ),

              if (_isLoading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF008435)),
                  ),
                )
              else
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 12.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 6.h),

                        // 1. Subscription Header Card with package.png Mascot Image
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.only(
                                left: 20.w,
                                right: 120.w,
                                top: 20.h,
                                bottom: 20.h,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(26.r),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: isDark
                                      ? const [
                                          Color(0xFF1E3A25),
                                          Color(0xFF2E5B3B),
                                          Color(0xFF3B724A),
                                        ]
                                      : const [
                                          Color(0xFF7CB342),
                                          Color(0xFF8BC34A),
                                          Color(0xFFC0CA33),
                                        ],
                                ),
                                border: isDark
                                    ? Border.all(color: const Color(0xFF2E4D36), width: 1.5)
                                    : null,
                                boxShadow: [
                                  BoxShadow(
                                    color: (isDark
                                            ? const Color(0xFF1E3A25)
                                            : const Color(0xFF7CB342))
                                        .withValues(alpha: 0.3),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(4.w),
                                        decoration: BoxDecoration(
                                          color: Color(0xFFFFB74D),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.star_rounded,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                      SizedBox(width: 6.w),
                                      Text(
                                        'FRIGGY PREMIUM',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8.h),
                                  Text(
                                    planNameDisplay,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 24.sp,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      height: 1.1,
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    isPaidPlan
                                        ? (isEn ? 'Expires on $endDateDisplay' : 'Hết hạn vào $endDateDisplay')
                                        : (isEn ? 'Free Plan (Forever)' : 'Gói Miễn Phí (Mãi mãi)'),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13.5.sp,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withValues(alpha: 0.95),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Integrated Mascot Image (package.png)
                            Positioned(
                              right: -6,
                              top: -18,
                              bottom: -18,
                              width: 145,
                              child: Image.asset(
                                'assets/images/package.png',
                                fit: BoxFit.contain,
                                alignment: Alignment.centerRight,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                  Icons.card_giftcard_rounded,
                                  size: 64,
                                  color: Colors.white30,
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 20.h),

                        // 2. Timeline Info Box (Ngày mua gói & Ngày kết thúc gói)
                        Container(
                          padding: EdgeInsets.all(18.w),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF19271E) : Colors.white,
                            borderRadius: BorderRadius.circular(22.r),
                            border: Border.all(
                              color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFA5E69C),
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
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildTimelineItem(
                                    icon: Icons.event_available_rounded,
                                    label: isEn ? 'Purchase Date' : 'Ngày bắt đầu',
                                    value: startDateDisplay,
                                    isDark: isDark,
                                  ),
                                  Container(
                                    width: 1,
                                    height: 38,
                                    color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFC8E6C9),
                                  ),
                                  _buildTimelineItem(
                                    icon: Icons.event_busy_rounded,
                                    label: isEn ? 'Expiry Date' : 'Ngày kết thúc gói',
                                    value: endDateDisplay,
                                    isDark: isDark,
                                  ),
                                ],
                              ),
                              Divider(
                                  height: 22,
                                  color: isDark
                                      ? const Color(0xFF2E4D36)
                                      : const Color(0xFFE8F5E9)),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.verified_user_rounded,
                                        color: isDark ? const Color(0xFF81C784) : const Color(0xFF4CAF50),
                                        size: 18,
                                      ),
                                      SizedBox(width: 6.w),
                                      Text(
                                        isEn ? 'Status: ' : 'Trạng thái: ',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? const Color(0xFF9DA8A0) : const Color(0xFF757575),
                                        ),
                                      ),
                                      Text(
                                        _userSub?.status == 'active'
                                            ? (isEn ? 'Active' : 'Đang hoạt động')
                                            : (_userSub?.status ?? 'active'),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? const Color(0xFF81C784) : const Color(0xFF006428),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    priceDisplay,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14.5.sp,
                                      fontWeight: FontWeight.w900,
                                      color: isDark ? const Color(0xFF81C784) : const Color(0xFF006428),
                                    ),
                                  ),
                                ],
                              ),
                              if (isPaidPlan) ...[
                                Divider(
                                    height: 22,
                                    color: isDark
                                        ? const Color(0xFF2E4D36)
                                        : const Color(0xFFE8F5E9)),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _handleRenew,
                                        icon: const Icon(Icons.autorenew_rounded, size: 16),
                                        label: Text(
                                          isEn ? 'Renew (+1 Mo)' : 'Gia hạn gói',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12.5.sp,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF008435),
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(vertical: 8),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12.r),
                                          ),
                                          elevation: 0,
                                        ),
                                      ),
                                    ),
                                    if (_userSub?.autoRenew == true) ...[
                                      SizedBox(width: 8.w),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: _confirmCancelAutoRenewal,
                                          icon: const Icon(Icons.cancel_outlined, size: 16),
                                          label: Text(
                                            isEn ? 'Cancel Auto-Renew' : 'Hủy gia hạn tự động',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(0xFFE53935),
                                            side: const BorderSide(color: Color(0xFFE53935), width: 1.2),
                                            padding: EdgeInsets.symmetric(vertical: 8),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12.r),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(height: 24.h),

                        // 3. Feature Perks Cards Grid
                        Text(
                          isEn ? 'Your Plan Benefits' : 'Đặc quyền gói của bạn',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF006428),
                          ),
                        ),
                        SizedBox(height: 12.h),

                        // Render Features list from plan
                        if (currentPlan != null && currentPlan.features.isNotEmpty)
                          ...currentPlan.features.map(
                            (feat) => Container(
                              margin: EdgeInsets.only(bottom: 10.h),
                              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF19271E) : Colors.white,
                                borderRadius: BorderRadius.circular(16.r),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFA5E69C),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(6.w),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF233629) : const Color(0xFFE8F5E9),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.check_rounded,
                                      color: isDark ? const Color(0xFF81C784) : const Color(0xFF006428),
                                      size: 18,
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: Text(
                                      feat,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : const Color(0xFF19221C),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else ...[
                          _buildWidePerkCard(
                            icon: Icons.qr_code_scanner_rounded,
                            iconBgColor: isDark ? const Color(0xFF233629) : const Color(0xFFC8E6C9),
                            iconColor: isDark ? const Color(0xFF81C784) : const Color(0xFF006428),
                            title: isEn ? 'Unlimited Scan' : 'Scan không giới hạn',
                            subtitle: isEn
                                ? 'Quickly import food with AI camera'
                                : 'Nhập thực phẩm nhanh chóng bằng camera AI',
                            cardBgColor: isDark ? const Color(0xFF19271E) : const Color(0xFFEAF5E1),
                            isDark: isDark,
                          ),
                          SizedBox(height: 12.h),
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _buildSquarePerkCard(
                                    icon: Icons.auto_awesome_rounded,
                                    iconBgColor: isDark ? const Color(0xFF382E1C) : const Color(0xFFFFF1C5),
                                    iconColor: const Color(0xFFFFB74D),
                                    title: isEn ? 'Smart AI\nSuggestions' : 'Gợi ý thông minh\nnâng cao',
                                    cardBgColor: isDark ? const Color(0xFF19271E) : const Color(0xFFFFFDF5),
                                    isDark: isDark,
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: _buildSquarePerkCard(
                                    icon: Icons.show_chart_rounded,
                                    iconBgColor: isDark ? const Color(0xFF1C2D38) : const Color(0xFFE3F2FD),
                                    iconColor: const Color(0xFF64B5F6),
                                    title: isEn ? 'Weekly &\nMonthly Stats' : 'Thống kê\ntuần & tháng',
                                    cardBgColor: isDark ? const Color(0xFF19271E) : const Color(0xFFF5FCF4),
                                    isDark: isDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        SizedBox(height: 28.h),

                        // 4. Action Button: "Xem tất cả các gói dịch vụ"
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _showAllPlansModal,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4CAF50),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28.r),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.explore_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                SizedBox(width: 10.w),
                                Text(
                                  isEn ? 'View All Service Plans' : 'Xem tất cả các gói dịch vụ',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15.5.sp,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: 20.h),
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

  Widget _buildTimelineItem({
    required IconData icon,
    required String label,
    required String value,
    bool isDark = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon,
                color: isDark ? const Color(0xFF81C784) : const Color(0xFF4CAF50),
                size: 16),
            SizedBox(width: 4.w),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF9DA8A0) : const Color(0xFF757575),
              ),
            ),
          ],
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14.5.sp,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF19221C),
          ),
        ),
      ],
    );
  }

  Widget _buildWidePerkCard({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color cardBgColor,
    bool isDark = false,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFA5E69C),
          width: 1.2,
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
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF006428),
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5.sp,
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

  Widget _buildSquarePerkCard({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required Color cardBgColor,
    bool isDark = false,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFA5E69C),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          SizedBox(height: 12.h),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14.5.sp,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF006428),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
