import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../admin/services/reward_service.dart';
import '../../models/point_record_model.dart';
import '../../models/reward_record_model.dart';
import '../../services/point_record_service.dart';

class ClassDetailsSheet extends StatefulWidget {
  final String className;

  const ClassDetailsSheet({
    super.key,
    required this.className,
  });

  static void show(BuildContext context, String className) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClassDetailsSheet(className: className),
    );
  }

  @override
  State<ClassDetailsSheet> createState() => _ClassDetailsSheetState();
}

class _ClassDetailsSheetState extends State<ClassDetailsSheet> {
  final _pointRecordService = PointRecordService();
  final _rewardService = RewardService();
  int _tabIndex = 0; // 0 = Tích điểm (+), 1 = Đổi quà (-)

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Vừa xong';
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final cleanClass = widget.className.trim().toUpperCase();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('classes')
                .doc(cleanClass)
                .snapshots(),
            builder: (context, classSnap) {
              final classData =
                  classSnap.data?.data() as Map<String, dynamic>? ?? {};
              final totalPoints =
                  (classData['totalPoints'] as num?)?.toInt() ?? 0;
              final teacherEmail =
                  classData['teacherEmail'] as String? ?? 'Chưa phân công';

              return Column(
                children: [
                  // Thanh kéo modal
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header chi tiết lớp
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryMint,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.school_rounded,
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Chi Đội Lớp $cleanClass',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'GV: $teacherEmail',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$totalPoints đ',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bộ chuyển đổi Tab: Lịch sử Tích điểm vs Lịch sử Đổi quà
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _tabIndex = 0),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _tabIndex == 0
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_circle_outline_rounded,
                                      size: 15,
                                      color: _tabIndex == 0
                                          ? Colors.white
                                          : AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Tích Điểm',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: _tabIndex == 0
                                            ? Colors.white
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _tabIndex = 1),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _tabIndex == 1
                                      ? const Color(0xFFC2410C)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.card_giftcard_rounded,
                                      size: 15,
                                      color: _tabIndex == 1
                                          ? Colors.white
                                          : AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Đổi Quà',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: _tabIndex == 1
                                            ? Colors.white
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Divider(height: 1),

                  // Nội dung danh sách theo Tab
                  Expanded(
                    child: _tabIndex == 0
                        ? _buildPointHistoryList(cleanClass, scrollController)
                        : _buildRewardHistoryList(cleanClass, scrollController),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPointHistoryList(
      String className, ScrollController scrollController) {
    return StreamBuilder<List<PointRecordModel>>(
      stream: _pointRecordService.getRecordsByClassStream(className),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final records = snapshot.data ?? [];
        if (records.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'Lớp này chưa có lượt tích điểm nào.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          );
        }

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final rec = records[index];
            final color = rec.categoryColor;
            final formattedQty = rec.isKg
                ? (rec.quantity.truncateToDouble() == rec.quantity
                    ? rec.quantity.toInt().toString()
                    : rec.quantity.toString())
                : rec.quantity.toInt().toString();

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.border),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(rec.iconData, color: color, size: 22),
                ),
                title: Text(
                  rec.categoryName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Text(
                      '$formattedQty ${rec.unit} • Tỷ lệ: ${rec.ruleRateText}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    Text(
                      _formatDateTime(rec.createdAt),
                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                    ),
                  ],
                ),
                trailing: Text(
                  '+${rec.totalPoints}đ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRewardHistoryList(
      String className, ScrollController scrollController) {
    return StreamBuilder<List<RewardRecordModel>>(
      stream: _rewardService.getRewardRecordsByClassStream(className),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = snapshot.data ?? [];
        if (orders.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'Lớp này chưa có lượt đổi quà nào.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          );
        }

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC2410C)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(order.iconData,
                              color: const Color(0xFFC2410C), size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.rewardName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: order.statusColor
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      order.statusLabel,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: order.statusColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'SL: ${order.quantity} ${order.unit} • ${_formatDateTime(order.createdAt)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '-${order.totalPoints}đ',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFC2410C),
                          ),
                        ),
                      ],
                    ),
                    if (order.isRejected && order.rejectionReason.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Lý do từ chối: ${order.rejectionReason}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.error,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
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
