import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Các tiện ích kiểm tra và hộp thoại xác nhận khi nhập hoặc đổi số lượng lớn
class LargeQuantityHelper {
  /// Ngưỡng tối đa tuyệt đối cho thu gom tích điểm (chống gõ tràn số)
  static const double maxPointRecordQuantity = 10000.0;

  /// Ngưỡng tối đa tuyệt đối cho đổi quà (chống gõ tràn số)
  static const int maxRewardOrderQuantity = 1000;

  /// Kiểm tra số lượng thu gom có lớn bất thường cần xác nhận không
  /// - Nếu đơn vị kg: >= 50 kg
  /// - Nếu đơn vị đếm (cái, chai, lon, cuốn, vỏ...): >= 100 đơn vị
  /// - Hoặc số điểm quy đổi: >= 300 điểm
  static bool isLargePointRecord({
    required double quantity,
    required bool isKg,
    required int calculatedPoints,
  }) {
    if (quantity <= 0) return false;
    if (isKg && quantity >= 50.0) return true;
    if (!isKg && quantity >= 100.0) return true;
    if (calculatedPoints >= 300) return true;
    return false;
  }

  /// Kiểm tra đơn đổi quà có số lượng hoặc số điểm lớn cần xác nhận không
  /// - Số lượng đổi: >= 10 món
  /// - Hoặc tổng điểm trừ: >= 300 điểm
  /// - Hoặc tiêu hơn 70% số điểm hiện có của lớp (nếu chi phí >= 150 điểm)
  static bool isLargeRewardOrder({
    required int quantity,
    required int totalPointsCost,
    required int currentClassPoints,
  }) {
    if (quantity <= 0) return false;
    if (quantity >= 10) return true;
    if (totalPointsCost >= 300) return true;
    if (currentClassPoints > 0 &&
        totalPointsCost >= 150 &&
        (totalPointsCost / currentClassPoints) >= 0.7) {
      return true;
    }
    return false;
  }
}

/// Hộp thoại xác nhận trước khi lưu lượt tích điểm số lượng lớn
Future<bool> showConfirmLargePointRecordDialog({
  required BuildContext context,
  required String className,
  required String categoryName,
  required double quantity,
  required String unit,
  required int points,
  bool isEdit = false,
}) async {
  final cleanQty = quantity.truncateToDouble() == quantity
      ? quantity.toInt().toString()
      : quantity.toString();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.warning,
              size: 26,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isEdit
                  ? 'Xác Nhận Số Lượng Sửa Lớn'
                  : 'Xác Nhận Thu Gom Số Lượng Lớn',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEdit
                ? 'Bạn đang cập nhật số lượng khá lớn cho lớp $className:'
                : 'Bạn đang ghi nhận số lượng thu gom khá lớn cho lớp $className:',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• Thể loại: $categoryName',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '• Số lượng: $cleanQty $unit',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '• Điểm tích lũy: +$points điểm',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Vui lòng kiểm tra lại để tránh nhập nhầm (ví dụ: gõ thừa số 0). Bạn có chắc chắn muốn tiếp tục lưu?',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Kiểm Tra Lại'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Xác Nhận Lưu'),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}

/// Hộp thoại xác nhận trước khi gửi đơn đổi quà số lượng lớn
Future<bool> showConfirmLargeRewardOrderDialog({
  required BuildContext context,
  required String className,
  required String rewardName,
  required int quantity,
  required String unit,
  required int totalPointsCost,
  required int remainingPoints,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFC2410C).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFC2410C),
              size: 26,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Xác Nhận Đổi Quà Số Lượng Lớn',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bạn đang tạo yêu cầu đổi quà có số lượng lớn cho lớp $className:',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• Phần thưởng: $rewardName',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '• Số lượng đổi: $quantity $unit',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '• Tổng điểm trừ: -$totalPointsCost điểm',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC2410C),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '• Điểm còn lại của lớp: $remainingPoints điểm',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Vui lòng kiểm tra lại để tránh nhầm số lượng trước khi gửi yêu cầu lên Tổng phụ trách.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Kiểm Tra Lại'),
        ),
        FilledButton(
          style:
              FilledButton.styleFrom(backgroundColor: const Color(0xFFC2410C)),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Xác Nhận Gửi Yêu Cầu'),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}
