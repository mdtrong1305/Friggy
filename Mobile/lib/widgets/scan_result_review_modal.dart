import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/models/fridge_models.dart';
import '../data/services/api_service.dart';
import '../l10n/app_localizations.dart';

class EditableScanItem {
  int? ingredientId;
  TextEditingController nameController;
  TextEditingController qtyController;
  String unit;
  String storageLocation; // 'fridge', 'freezer', 'pantry'
  bool allergyWarning;

  EditableScanItem({
    this.ingredientId,
    required String name,
    required double quantity,
    required this.unit,
    this.storageLocation = 'fridge',
    this.allergyWarning = false,
  })  : nameController = TextEditingController(text: name),
        qtyController = TextEditingController(
          text: quantity % 1 == 0 ? quantity.toInt().toString() : quantity.toString(),
        );

  factory EditableScanItem.fromDetected(DetectedScanItemModel model) {
    return EditableScanItem(
      ingredientId: model.ingredientId,
      name: model.name,
      quantity: model.quantity,
      unit: model.unit,
      storageLocation: 'fridge',
      allergyWarning: model.allergyWarning,
    );
  }

  void dispose() {
    nameController.dispose();
    qtyController.dispose();
  }
}

class ScanResultReviewModal extends StatefulWidget {
  final String scanId;
  final List<DetectedScanItemModel> initialItems;

  const ScanResultReviewModal({
    super.key,
    required this.scanId,
    required this.initialItems,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String scanId,
    required List<DetectedScanItemModel> initialItems,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ScanResultReviewModal(
        scanId: scanId,
        initialItems: initialItems,
      ),
    );
  }

  @override
  State<ScanResultReviewModal> createState() => _ScanResultReviewModalState();
}

class _ScanResultReviewModalState extends State<ScanResultReviewModal> {
  late List<EditableScanItem> _editableItems;
  bool _isConfirming = false;

  final List<String> _availableUnits = [
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

  @override
  void initState() {
    super.initState();
    _editableItems = widget.initialItems
        .map((it) => EditableScanItem.fromDetected(it))
        .toList();

    if (_editableItems.isEmpty) {
      _addNewItem();
    }
  }

  @override
  void dispose() {
    for (var item in _editableItems) {
      item.dispose();
    }
    super.dispose();
  }

  void _addNewItem() {
    setState(() {
      _editableItems.add(
        EditableScanItem(
          name: '',
          quantity: 1,
          unit: 'kg',
          storageLocation: 'fridge',
        ),
      );
    });
  }

  void _removeItem(int index) {
    setState(() {
      _editableItems[index].dispose();
      _editableItems.removeAt(index);
    });
  }

  Future<void> _confirmAndSave() async {
    final isEn = AppLocalizations.of(context)?.locale.languageCode == 'en';
    final validItems = _editableItems.where((it) => it.nameController.text.trim().isNotEmpty).toList();

    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEn ? 'Please add at least one item' : 'Vui lòng có ít nhất 1 thực phẩm trong danh sách'),
          backgroundColor: const Color(0xFF008435),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isConfirming = true);

    try {
      final List<Map<String, dynamic>> confirmPayload = [];

      for (var item in validItems) {
        final name = item.nameController.text.trim();
        final qty = double.tryParse(item.qtyController.text.trim()) ?? 1.0;

        confirmPayload.add({
          if (item.ingredientId != null && item.ingredientId! > 0)
            'ingredientId': item.ingredientId,
          'name': name,
          'quantity': qty,
          'unit': item.unit,
          'storageLocation': item.storageLocation,
        });
      }

      await ApiService().confirmScan(widget.scanId, confirmPayload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEn
                ? 'Successfully added items to Fridge!'
                : 'Đã thêm thực phẩm vào tủ lạnh thành công!',
          ),
          backgroundColor: const Color(0xFF008435),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Confirm scan error: $e');
      if (!mounted) return;
      setState(() => _isConfirming = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEn ? 'Failed to save items to fridge' : 'Không thể lưu thực phẩm vào tủ lạnh',
          ),
          backgroundColor: const Color(0xFF008435),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final isEn = loc?.locale.languageCode == 'en';
    final mediaQuery = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: mediaQuery.size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF19271E) : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          border: isDark ? Border.all(color: const Color(0xFF2E4D36), width: 1.2) : null,
        ),
        padding: EdgeInsets.only(top: 14.h, left: 20.w, right: 20.w, bottom: 20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Drag Handle Bar
            Center(
              child: Container(
                width: 38,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFC8E6C9),
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
            ),
            SizedBox(height: 14.h),

            // Header Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn ? 'Review & Edit Items' : 'Kiểm Tra & Chỉnh Sửa',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF006428),
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      isEn
                          ? 'Review AI scan results before adding to fridge'
                          : 'Chỉnh sửa lại số lượng, đơn vị trước khi thêm vào tủ',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.sp,
                        color: isDark ? const Color(0xFF9DA8A0) : const Color(0xFF6B786F),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: isDark ? Colors.white : const Color(0xFF6B786F),
                  ),
                  onPressed: () => Navigator.pop(context, false),
                ),
              ],
            ),
            SizedBox(height: 14.h),

            // Editable Item List
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: _editableItems.length,
                separatorBuilder: (context, index) => SizedBox(height: 12.h),
                itemBuilder: (context, index) {
                  final item = _editableItems[index];

                  return Container(
                    padding: EdgeInsets.all(14.w),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0E1611) : const Color(0xFFF4FAF2),
                      borderRadius: BorderRadius.circular(18.r),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFA5E69C),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name & Delete Row
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: item.nameController,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF19221C),
                                ),
                                decoration: InputDecoration(
                                  hintText: isEn ? 'Food name...' : 'Tên thực phẩm...',
                                  isDense: true,
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            if (item.allergyWarning)
                              Padding(
                                padding: EdgeInsets.only(right: 6.w),
                                child: Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                              ),
                            IconButton(
                              icon: Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                              onPressed: () => _removeItem(index),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),

                        // Quantity & Unit Row
                        Row(
                          children: [
                            // Quantity Controls
                            Container(
                              height: 38,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF19271E) : Colors.white,
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFC8E6C9),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.remove_rounded, size: 16),
                                    onPressed: () {
                                      final current = double.tryParse(item.qtyController.text) ?? 1.0;
                                      if (current > 0.5) {
                                        final nextVal = current - (current > 1 ? 1 : 0.5);
                                        item.qtyController.text =
                                            nextVal % 1 == 0 ? nextVal.toInt().toString() : nextVal.toString();
                                        setState(() {});
                                      }
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 38),
                                  ),
                                  SizedBox(
                                    width: 45,
                                    child: TextField(
                                      controller: item.qtyController,
                                      textAlign: TextAlign.center,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : const Color(0xFF006428),
                                      ),
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.add_rounded, size: 16),
                                    onPressed: () {
                                      final current = double.tryParse(item.qtyController.text) ?? 1.0;
                                      final nextVal = current + 1;
                                      item.qtyController.text =
                                          nextVal % 1 == 0 ? nextVal.toInt().toString() : nextVal.toString();
                                      setState(() {});
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 38),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 10.w),

                            // Unit Dropdown
                            Container(
                              height: 38,
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF19271E) : Colors.white,
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF2E4D36) : const Color(0xFFC8E6C9),
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _availableUnits.contains(item.unit) ? item.unit : _availableUnits.first,
                                  isDense: true,
                                  dropdownColor: isDark ? const Color(0xFF19271E) : Colors.white,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF19221C),
                                  ),
                                  onChanged: (newUnit) {
                                    if (newUnit != null) {
                                      setState(() => item.unit = newUnit);
                                    }
                                  },
                                  items: _availableUnits
                                      .map(
                                        (u) => DropdownMenuItem(
                                          value: u,
                                          child: Text(u),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10.h),

                        // Storage Location Pills
                        Row(
                          children: [
                            {'key': 'fridge', 'label': isEn ? 'Cooler' : 'Ngăn mát'},
                            {'key': 'freezer', 'label': isEn ? 'Freezer' : 'Ngăn đông'},
                            {'key': 'pantry', 'label': isEn ? 'Pantry' : 'Tủ khô'},
                          ].map((locOption) {
                            final locKey = locOption['key']!;
                            final locLabel = locOption['label']!;
                            final isSelected = item.storageLocation == locKey;

                            return Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => item.storageLocation = locKey),
                                child: Container(
                                  height: 32,
                                  margin: EdgeInsets.symmetric(horizontal: 2),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF008435)
                                        : (isDark ? const Color(0xFF19271E) : Colors.white),
                                    borderRadius: BorderRadius.circular(10.r),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF008435)
                                          : (isDark ? const Color(0xFF2E4D36) : const Color(0xFF81C784)),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    locLabel,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.bold,
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
                      ],
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 12.h),

            // Add Another Item Button
            TextButton.icon(
              onPressed: _addNewItem,
              icon: Icon(Icons.add_circle_outline_rounded, color: Color(0xFF008435)),
              label: Text(
                isEn ? '+ Add another item' : '+ Thêm thực phẩm khác',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF008435),
                ),
              ),
            ),
            SizedBox(height: 14.h),

            // Confirm Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF008435),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                  elevation: 2,
                ),
                onPressed: _isConfirming ? null : _confirmAndSave,
                child: _isConfirming
                    ? CircularProgressIndicator(color: Colors.white)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 8.w),
                          Text(
                            isEn ? 'Confirm & Add to Fridge' : 'Xác Nhận & Thêm Vào Tủ',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16.sp,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
