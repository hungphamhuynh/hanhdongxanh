import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/firebase_error_mapper.dart';
import '../../../../core/widgets/large_quantity_confirm_dialog.dart';
import '../../models/point_record_model.dart';
import '../../services/point_record_service.dart';

/// BottomSheet cho phép Giáo viên hoặc Tổng phụ trách chỉnh sửa số lượng / ghi chú của lượt thu gom
class EditPointRecordSheet extends StatefulWidget {
  final PointRecordModel record;
  final String userEmail;
  final String userUid;

  const EditPointRecordSheet({
    super.key,
    required this.record,
    required this.userEmail,
    required this.userUid,
  });

  /// Phương thức tĩnh tiện lợi để hiển thị Sheet
  static Future<bool?> show({
    required BuildContext context,
    required PointRecordModel record,
    required String userEmail,
    required String userUid,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditPointRecordSheet(
        record: record,
        userEmail: userEmail,
        userUid: userUid,
      ),
    );
  }

  @override
  State<EditPointRecordSheet> createState() => _EditPointRecordSheetState();
}

class _EditPointRecordSheetState extends State<EditPointRecordSheet> {
  final PointRecordService _pointRecordService = PointRecordService();
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _noteCtrl;
  late final Stream<DocumentSnapshot> _classStream;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final cleanClass = widget.record.className.trim().toUpperCase();
    _classStream = FirebaseFirestore.instance
        .collection('classes')
        .doc(cleanClass)
        .snapshots();

    final qty = widget.record.quantity;
    final formattedQty = widget.record.isKg
        ? (qty.truncateToDouble() == qty ? qty.toInt().toString() : qty.toString())
        : qty.toInt().toString();

    _qtyCtrl = TextEditingController(text: formattedQty);
    _noteCtrl = TextEditingController(text: widget.record.note);

    _qtyCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  double get _enteredQty =>
      double.tryParse(_qtyCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;

  int get _effectiveUnitQty =>
      widget.record.unitQuantity > 0 ? widget.record.unitQuantity : 1;

  int get _calculatedNewPoints =>
      ((_enteredQty * widget.record.points) / _effectiveUnitQty).round();

  int get _deltaPoints => _calculatedNewPoints - widget.record.totalPoints;

  bool get _isLargeQty => LargeQuantityHelper.isLargePointRecord(
        quantity: _enteredQty,
        isKg: widget.record.isKg,
        calculatedPoints: _calculatedNewPoints,
      );

  Future<void> _handleSave(int currentClassPoints) async {
    final qty = _enteredQty;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Vui lòng nhập ${widget.record.isKg ? "khối lượng" : "số lượng"} lớn hơn 0!',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (qty < _effectiveUnitQty || _calculatedNewPoints <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Chưa đủ số lượng quy đổi! Cần tối thiểu $_effectiveUnitQty ${widget.record.unit} để được tính điểm.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (qty > LargeQuantityHelper.maxPointRecordQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Số lượng vượt quá giới hạn cho phép (tối đa ${LargeQuantityHelper.maxPointRecordQuantity.toInt()} ${widget.record.unit})! Vui lòng kiểm tra lại.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_deltaPoints < 0 && currentClassPoints < -_deltaPoints) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Lớp ${widget.record.className} hiện chỉ còn $currentClassPoints điểm, không đủ để giảm ${-_deltaPoints} điểm (lớp đã sử dụng điểm này để đổi quà)!',
          ),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    final newNote = _noteCtrl.text.trim();
    if (qty == widget.record.quantity && newNote == widget.record.note.trim()) {
      Navigator.pop(context, false);
      return;
    }

    if (_isLargeQty) {
      final ok = await showConfirmLargePointRecordDialog(
        context: context,
        className: widget.record.className,
        categoryName: widget.record.categoryName,
        quantity: qty,
        unit: widget.record.unit,
        points: _calculatedNewPoints,
        isEdit: true,
      );
      if (!ok) return;
    }

    setState(() => _isLoading = true);

    try {
      await _pointRecordService.updateRecord(
        oldRecord: widget.record,
        newQuantity: qty,
        newNote: newNote,
        updatedByEmail: widget.userEmail,
        updatedByUid: widget.userUid,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cập nhật lượt thu gom thành công! ${_deltaPoints != 0 ? "(${_deltaPoints > 0 ? "+" : ""}$_deltaPoints điểm cho lớp ${widget.record.className})" : ""}',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final errText = FirebaseErrorMapper.getCleanErrorMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể cập nhật: $errText'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rec = widget.record;
    final color = rec.categoryColor;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: StreamBuilder<DocumentSnapshot>(
            stream: _classStream,
            builder: (context, classSnap) {
              final classData =
                  classSnap.data?.data() as Map<String, dynamic>? ?? {};
              final currentClassPoints =
                  (classData['totalPoints'] as num?)?.toInt() ?? 0;
              final isInsufficient =
                  _deltaPoints < 0 && currentClassPoints < -_deltaPoints;
              final isBelowMinimum =
                  _enteredQty < _effectiveUnitQty || _calculatedNewPoints <= 0;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Thanh kéo drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Tiêu đề & Nút đóng
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(rec.iconData, color: color, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Chỉnh Sửa Lượt Thu Gom',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Lớp ${rec.className} • ${rec.categoryName}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: AppColors.textSecondary),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Thẻ thông tin tỷ lệ quy đổi
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Tỷ lệ quy đổi:',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              rec.ruleRateText,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Dữ liệu ban đầu:',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              '${rec.quantity} ${rec.unit} ➔ +${rec.totalPoints} điểm',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Ô nhập số lượng mới
                  TextField(
                    controller: _qtyCtrl,
                    keyboardType: rec.isKg
                        ? const TextInputType.numberWithOptions(decimal: true)
                        : TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        rec.isKg ? RegExp(r'^\d*\.?\d*') : RegExp(r'^\d*'),
                      ),
                    ],
                    decoration: InputDecoration(
                      labelText: rec.isKg ? 'Khối lượng mới' : 'Số lượng mới',
                      hintText: 'Nhập số lượng chính xác...',
                      suffixText: rec.unit,
                      prefixIcon: const Icon(Icons.pin_outlined),
                      helperText:
                          'Tối thiểu: $_effectiveUnitQty ${rec.unit} (${rec.ruleRateText})',
                      errorText: (isBelowMinimum && _enteredQty > 0)
                          ? 'Chưa đủ mốc tối thiểu ($_effectiveUnitQty ${rec.unit})'
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Bảng xem trước chênh lệch điểm
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isInsufficient
                          ? AppColors.errorLight.withValues(alpha: 0.5)
                          : _deltaPoints > 0
                              ? AppColors.success.withValues(alpha: 0.08)
                              : _deltaPoints < 0
                                  ? AppColors.warning.withValues(alpha: 0.1)
                                  : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isInsufficient
                            ? AppColors.error.withValues(alpha: 0.5)
                            : _deltaPoints > 0
                                ? AppColors.success.withValues(alpha: 0.3)
                                : _deltaPoints < 0
                                    ? AppColors.warning.withValues(alpha: 0.4)
                                    : AppColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isInsufficient
                              ? Icons.error_outline_rounded
                              : _deltaPoints > 0
                                  ? Icons.trending_up_rounded
                                  : _deltaPoints < 0
                                      ? Icons.trending_down_rounded
                                      : Icons.drag_handle_rounded,
                          color: isInsufficient
                              ? AppColors.error
                              : _deltaPoints > 0
                                  ? AppColors.success
                                  : _deltaPoints < 0
                                      ? AppColors.warning
                                      : AppColors.textSecondary,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Điểm mới: $_calculatedNewPoints điểm',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isInsufficient
                                    ? 'Quỹ lớp chỉ còn $currentClassPoints điểm, không đủ giảm ${-_deltaPoints} điểm'
                                    : _deltaPoints > 0
                                        ? 'Cộng thêm +$_deltaPoints điểm vào quỹ lớp'
                                        : _deltaPoints < 0
                                            ? 'Khấu trừ $_deltaPoints điểm từ quỹ lớp'
                                            : 'Điểm không thay đổi',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isInsufficient
                                      ? AppColors.error
                                      : _deltaPoints > 0
                                          ? AppColors.success
                                          : _deltaPoints < 0
                                              ? const Color(0xFFC2410C)
                                              : AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _deltaPoints > 0
                              ? '+$_deltaPoints'
                              : _deltaPoints < 0
                                  ? '$_deltaPoints'
                                  : '0',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isInsufficient
                                ? AppColors.error
                                : _deltaPoints > 0
                                    ? AppColors.success
                                    : _deltaPoints < 0
                                        ? const Color(0xFFC2410C)
                                        : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Cảnh báo số lượng chưa đủ mốc tối thiểu
                  if (isBelowMinimum) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: AppColors.error,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Số lượng chưa đủ mốc quy đổi! Cần tối thiểu $_effectiveUnitQty ${rec.unit} để được tính điểm (${rec.ruleRateText}).',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.error,
                                height: 1.35,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Cảnh báo số lượng điều chỉnh lớn
                  if (!isBelowMinimum && _isLargeQty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: Color(0xFFC2410C),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Lưu ý: Số lượng điều chỉnh khá lớn ($_enteredQty ${rec.unit} = +$_calculatedNewPoints điểm). Hệ thống sẽ yêu cầu xác nhận trước khi lưu.',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF9A3412),
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Cảnh báo không đủ điểm do lớp đã dùng điểm đổi quà
                  if (isInsufficient) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.error,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Lớp ${rec.className} hiện chỉ còn $currentClassPoints điểm, không đủ để giảm ${-_deltaPoints} điểm (lớp đã sử dụng điểm này để đổi quà).',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.error,
                                height: 1.35,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Ô nhập ghi chú điều chỉnh
                  TextField(
                    controller: _noteCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Lý do / Ghi chú điều chỉnh',
                      hintText: 'Ví dụ: Cân lại bị nhầm, nhập thừa số lượng...',
                      prefixIcon: const Icon(Icons.note_alt_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Nút xác nhận lưu
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: (isInsufficient || isBelowMinimum)
                          ? Colors.grey.shade400
                          : AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isLoading || isInsufficient || isBelowMinimum
                        ? null
                        : () => _handleSave(currentClassPoints),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            isInsufficient
                                ? 'Không Đủ Điểm Để Giảm'
                                : (isBelowMinimum
                                    ? 'Chưa Đủ Mốc Tối Thiểu ($_effectiveUnitQty ${rec.unit})'
                                    : 'Lưu Thay Đổi'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
