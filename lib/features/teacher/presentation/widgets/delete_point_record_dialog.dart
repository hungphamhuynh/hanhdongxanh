import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/firebase_error_mapper.dart';
import '../../models/point_record_model.dart';
import '../../services/point_record_service.dart';

/// Hộp thoại xác nhận hủy lượt thu gom an toàn với Transaction chống âm điểm
Future<bool> showConfirmDeletePointRecordDialog({
  required BuildContext context,
  required PointRecordModel record,
  required String userEmail,
  required String userUid,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 26),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Hủy Lượt Thu Gom',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bạn có chắc chắn muốn hủy phiếu thu gom của lớp ${record.className}?',
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• Thể loại: ${record.categoryName} (${record.quantity} ${record.unit})',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  '• Tỷ lệ: ${record.ruleRateText}',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  '• Điểm thu hồi: -${record.totalPoints} điểm',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Lưu ý: Quỹ điểm của lớp sẽ bị trừ lại tương ứng. Nếu lớp không đủ điểm bù trừ (do đã dùng để đổi quà), hệ thống sẽ tự động chặn hủy.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Giữ lại'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Xác Nhận Hủy'),
        ),
      ],
    ),
  );

  if (confirmed == true && context.mounted) {
    try {
      await PointRecordService().deleteRecord(
        record: record,
        userEmail: userEmail,
        userUid: userUid,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã hủy lượt thu gom và thu hồi ${record.totalPoints} điểm của lớp ${record.className}!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        final errText = FirebaseErrorMapper.getCleanErrorMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể hủy phiếu: $errText'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return false;
    }
  }

  return false;
}
