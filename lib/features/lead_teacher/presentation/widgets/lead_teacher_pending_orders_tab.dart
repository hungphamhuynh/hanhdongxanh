import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../admin/services/reward_service.dart';
import '../../../teacher/models/reward_record_model.dart';

/// Tab Duyệt Đơn Đổi Quà dành cho Tổng phụ trách
class LeadTeacherPendingOrdersTab extends StatefulWidget {
  final User? user;

  const LeadTeacherPendingOrdersTab({
    super.key,
    this.user,
  });

  @override
  State<LeadTeacherPendingOrdersTab> createState() =>
      _LeadTeacherPendingOrdersTabState();
}

class _LeadTeacherPendingOrdersTabState
    extends State<LeadTeacherPendingOrdersTab> {
  final RewardService _rewardService = RewardService();
  late Stream<List<RewardRecordModel>> _ordersStream;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  void _initStream() {
    _ordersStream = _rewardService.getPendingOrdersStream();
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Vừa xong';
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  Future<void> _confirmApproveOrder(
    RewardRecordModel order,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận trao quà'),
        content: Text(
          'Duyệt trao "${order.quantity} ${order.unit} ${order.rewardName}" cho lớp ${order.className}?\n\n'
          '(Lớp đã được trừ ${order.totalPoints} điểm khi tạo yêu cầu).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác Nhận Đã Trao Quà'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _rewardService.approveRewardOrder(
          orderId: order.id,
          approvedByEmail: widget.user?.email ?? 'tongphutrach@nth.com',
          approvedByUid: widget.user?.uid ?? '',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Đã duyệt trao quà cho lớp ${order.className} thành công!',
              ),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _confirmRejectOrder(
    RewardRecordModel order,
  ) async {
    final reasonCtrl = TextEditingController(text: 'Kho tạm hết quà');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Từ chối yêu cầu đổi quà'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Từ chối yêu cầu đổi "${order.quantity} ${order.unit} ${order.rewardName}" của lớp ${order.className}?\n\n'
              'Hệ thống sẽ tự động HOÀN LẠI ${order.totalPoints} điểm cho lớp.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Lý do từ chối *',
                hintText: 'Ví dụ: Tạm hết hàng trong kho, cần gom thêm...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác Nhận & Hoàn Điểm'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _rewardService.rejectRewardOrder(
          orderId: order.id,
          rejectionReason: reasonCtrl.text.trim(),
          rejectedByEmail: widget.user?.email ?? 'tongphutrach@nth.com',
          rejectedByUid: widget.user?.uid ?? '',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Đã từ chối yêu cầu và hoàn lại ${order.totalPoints} điểm cho lớp ${order.className} thành công!',
              ),
              backgroundColor: AppColors.textSecondary,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RewardRecordModel>>(
      stream: _ordersStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Không thể tải danh sách yêu cầu đổi quà',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                    onPressed: () {
                      setState(() {
                        _initStream();
                      });
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Thử Lại'),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = snapshot.data ?? [];
        if (orders.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: AppColors.successLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.task_alt_rounded,
                      size: 48,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Không có yêu cầu đổi quà nào đang chờ duyệt',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Khi các giáo viên gửi yêu cầu đổi quà cho lớp,\nphiếu đổi sẽ xuất hiện tại đây để bạn duyệt & trao thưởng.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0.8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryMint,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Lớp ${order.className}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.warningLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                order.statusLabel,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.warning,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _formatDateTime(order.createdAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC2410C)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            order.iconData,
                            color: const Color(0xFFC2410C),
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.rewardName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Số lượng: ${order.quantity} ${order.unit} (${order.pointsCost}đ/${order.unit})',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '-${order.totalPoints}đ',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFC2410C),
                          ),
                        ),
                      ],
                    ),
                    if (order.note.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Ghi chú: ${order.note}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      'Người gửi: ${order.createdByEmail}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () => _confirmRejectOrder(order),
                            child: const Text('Từ Chối'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () => _confirmApproveOrder(order),
                            child: const Text('Duyệt & Trao Quà'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
