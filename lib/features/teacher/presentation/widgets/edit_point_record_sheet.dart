import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
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
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
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

  Future<void> _handleSave() async {
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

    final newNote = _noteCtrl.text.trim();
    if (qty == widget.record.quantity && newNote == widget.record.note.trim()) {
      Navigator.pop(context, false);
      return;
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
        final errText = e.toString().replaceAll('Exception: ', '');
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
          child: Column(
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
                  color: _deltaPoints > 0
                      ? AppColors.success.withValues(alpha: 0.08)
                      : _deltaPoints < 0
                          ? AppColors.warning.withValues(alpha: 0.1)
                          : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _deltaPoints > 0
                        ? AppColors.success.withValues(alpha: 0.3)
                        : _deltaPoints < 0
                            ? AppColors.warning.withValues(alpha: 0.4)
                            : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _deltaPoints > 0
                          ? Icons.trending_up_rounded
                          : _deltaPoints < 0
                              ? Icons.trending_down_rounded
                              : Icons.drag_handle_rounded,
                      color: _deltaPoints > 0
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
                            _deltaPoints > 0
                                ? 'Cộng thêm +$_deltaPoints điểm vào quỹ lớp'
                                : _deltaPoints < 0
                                    ? 'Khấu trừ $_deltaPoints điểm từ quỹ lớp'
                                    : 'Điểm không thay đổi',
                            style: TextStyle(
                              fontSize: 11,
                              color: _deltaPoints > 0
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
                        color: _deltaPoints > 0
                            ? AppColors.success
                            : _deltaPoints < 0
                                ? const Color(0xFFC2410C)
                                : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
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
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isLoading ? null : _handleSave,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Lưu Thay Đổi',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
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
