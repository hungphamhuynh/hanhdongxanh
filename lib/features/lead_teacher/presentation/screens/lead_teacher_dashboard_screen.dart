import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../../admin/models/point_rule_model.dart';
import '../../../admin/services/point_rule_service.dart';
import '../../../admin/services/reward_service.dart';
import '../../../auth/services/auth_service.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../teacher/models/point_record_model.dart';
import '../../../teacher/models/reward_record_model.dart';
import '../../../teacher/services/point_record_service.dart';
import '../widgets/lead_teacher_leaderboard_tab.dart';
import '../widgets/lead_teacher_statistics_tab.dart';

class LeadTeacherDashboardScreen extends StatefulWidget {
  const LeadTeacherDashboardScreen({super.key});

  @override
  State<LeadTeacherDashboardScreen> createState() =>
      _LeadTeacherDashboardScreenState();
}

class _LeadTeacherDashboardScreenState
    extends State<LeadTeacherDashboardScreen> {
  final AuthService _authService = AuthService();
  final PointRuleService _pointRuleService = PointRuleService();
  final PointRecordService _pointRecordService = PointRecordService();
  final RewardService _rewardService = RewardService();

  int _currentTabIndex =
      0; // 0: Thống kê, 1: Xếp hạng, 2: Đơn đổi quà, 3: Nhật ký
  int _schoolHistoryTabIndex = 0; // 0: Thu gom (+), 1: Đổi quà (-)

  late final Stream<List<RewardRecordModel>> _pendingOrdersStream;
  late final Stream<QuerySnapshot> _pointRecordsStream;
  late final Stream<List<RewardRecordModel>> _allRewardRecordsStream;

  @override
  void initState() {
    super.initState();
    _pendingOrdersStream = _rewardService.getPendingOrdersStream();
    _pointRecordsStream = FirebaseFirestore.instance
        .collection('point_records')
        .snapshots();
    _allRewardRecordsStream = _rewardService.getAllRewardRecordsStream();
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.surfaceVariant,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(
              Icons.workspace_premium_rounded,
              color: AppColors.roleLeadTeacher,
              size: 24,
            ),
            SizedBox(width: 8),
            Text(
              'Trang Tổng Phụ Trách',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Hồ sơ cá nhân',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: () => _authService.signOut(),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTabIndex,
        onDestinationSelected: (index) =>
            setState(() => _currentTabIndex = index),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Thống Kê',
          ),
          const NavigationDestination(
            icon: Icon(Icons.leaderboard_outlined),
            selectedIcon: Icon(Icons.leaderboard_rounded),
            label: 'Xếp Hạng',
          ),
          NavigationDestination(
            icon: StreamBuilder<List<RewardRecordModel>>(
              stream: _pendingOrdersStream,
              builder: (context, snapshot) {
                final count = snapshot.data?.length ?? 0;
                return Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  backgroundColor: const Color(0xFFC2410C),
                  child: const Icon(Icons.pending_actions_outlined),
                );
              },
            ),
            selectedIcon: StreamBuilder<List<RewardRecordModel>>(
              stream: _pendingOrdersStream,
              builder: (context, snapshot) {
                final count = snapshot.data?.length ?? 0;
                return Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  backgroundColor: const Color(0xFFC2410C),
                  child: const Icon(Icons.pending_actions_rounded),
                );
              },
            ),
            label: 'Đơn Đổi Quà',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Nhật Ký',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_task_rounded),
        label: const Text(
          'Tích Điểm Cho Lớp',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () => _showLeadRecordDialog(
          context: context,
          userUid: user?.uid ?? '',
          userEmail: user?.email ?? '',
        ),
      ),
      body: ResponsiveContainer(
        maxWidth: 900,
        child: _buildCurrentTabBody(context, user),
      ),
    );
  }

  /// Dựng nội dung tab đang chọn - Mở tab nào mới nạp tab đó, giải phóng tab cũ
  Widget _buildCurrentTabBody(BuildContext context, User? user) {
    switch (_currentTabIndex) {
      case 0:
        return const LeadTeacherStatisticsTab();
      case 1:
        return const LeadTeacherLeaderboardTab();
      case 2:
        return _buildPendingOrdersTab(context, user);
      case 3:
        return _buildSchoolHistoryTab();
      default:
        return const LeadTeacherStatisticsTab();
    }
  }

  Widget _buildPendingOrdersTab(BuildContext context, User? user) {
    return StreamBuilder<List<RewardRecordModel>>(
      stream: _pendingOrdersStream,
      builder: (context, snapshot) {
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
                    'Không có đơn đổi quà nào đang chờ duyệt',
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
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.hourglass_top_rounded,
                                    size: 13,
                                    color: AppColors.warning,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    order.statusLabel,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                ],
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
                            onPressed: () =>
                                _confirmRejectOrder(context, order, user),
                            child: const Text('Từ Chối'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () =>
                                _confirmApproveOrder(context, order, user),
                            icon: const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 18,
                            ),
                            label: const Text('Duyệt & Trao Quà'),
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

  Future<void> _confirmApproveOrder(
    BuildContext context,
    RewardRecordModel order,
    User? user,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận duyệt & trao quà'),
        content: Text(
          'Duyệt phát "${order.quantity} ${order.unit} ${order.rewardName}" cho lớp ${order.className}?\n\n'
          'Hệ thống sẽ chính thức trừ ${order.totalPoints} điểm thi đua của lớp.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác Nhận & Trừ Điểm'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        await _rewardService.approveRewardOrder(
          orderId: order.id,
          approvedByEmail: user?.email ?? 'tongphutrach@nth.com',
          approvedByUid: user?.uid ?? '',
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Đã duyệt và trừ ${order.totalPoints} điểm của lớp ${order.className} thành công!',
              ),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
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
    BuildContext context,
    RewardRecordModel order,
    User? user,
  ) async {
    final reasonCtrl = TextEditingController(text: 'Kho tạm hết quà');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Từ chối đơn đổi quà'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Từ chối đơn đổi "${order.quantity} ${order.unit} ${order.rewardName}" của lớp ${order.className}?',
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
            child: const Text('Xác Nhận Từ Chối'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        await _rewardService.rejectRewardOrder(
          orderId: order.id,
          rejectionReason: reasonCtrl.text.trim(),
          rejectedByEmail: user?.email ?? 'tongphutrach@nth.com',
          rejectedByUid: user?.uid ?? '',
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã từ chối đơn đổi quà thành công!'),
              backgroundColor: AppColors.textSecondary,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
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

  Widget _buildSchoolHistoryTab() {
    return Column(
      children: [
        // Thanh chọn lịch sử: Thu gom vs Đổi quà
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                    onTap: () => setState(() => _schoolHistoryTabIndex = 0),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _schoolHistoryTabIndex == 0
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
                            color: _schoolHistoryTabIndex == 0
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Thu Gom Phế Liệu (+)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _schoolHistoryTabIndex == 0
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
                    onTap: () => setState(() => _schoolHistoryTabIndex = 1),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _schoolHistoryTabIndex == 1
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
                            color: _schoolHistoryTabIndex == 1
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Đổi Điểm Lấy Quà (-)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _schoolHistoryTabIndex == 1
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

        // Danh sách tương ứng
        Expanded(
          child: _schoolHistoryTabIndex == 0
              ? StreamBuilder<QuerySnapshot>(
                  stream: _pointRecordsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data?.docs ?? [];
                    final records = docs
                        .map((d) => PointRecordModel.fromFirestore(d))
                        .toList();

                    records.sort((a, b) {
                      if (a.createdAt == null) return -1;
                      if (b.createdAt == null) return 1;
                      return b.createdAt!.compareTo(a.createdAt!);
                    });

                    if (records.isEmpty) {
                      return const Center(
                        child: Text(
                          'Chưa có lượt thu gom nào được ghi nhận trên hệ thống.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: records.length,
                      itemBuilder: (context, index) {
                        final rec = records[index];
                        final isBattery = rec.isBattery;
                        final color = isBattery
                            ? AppColors.warning
                            : AppColors.primary;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 0.5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(rec.iconData, color: color, size: 22),
                            ),
                            title: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryDark,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    rec.className,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${rec.categoryName}: ${rec.quantity} ${rec.unit}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2),
                                Text(
                                  '${_formatDateTime(rec.createdAt)} • Người ghi: ${rec.createdByEmail}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                if (rec.note.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    rec.note,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            trailing: Text(
                              '+${rec.totalPoints}đ',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                )
              : StreamBuilder<List<RewardRecordModel>>(
                  stream: _allRewardRecordsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final orders = snapshot.data ?? [];
                    if (orders.isEmpty) {
                      return const Center(
                        child: Text(
                          'Chưa có đơn đổi quà nào trên toàn trường.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: orders.length,
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 0.5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFC2410C)
                                    .withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                order.iconData,
                                color: const Color(0xFFC2410C),
                                size: 24,
                              ),
                            ),
                            title: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Lớp ${order.className}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${order.rewardName} (${order.quantity} ${order.unit})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: order.statusColor.withValues(
                                      alpha: 0.12,
                                    ),
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
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  '${_formatDateTime(order.createdAt)} • Người xin: ${order.createdByEmail}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                if (order.isApproved &&
                                    order.approvedByEmail != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Duyệt bởi: ${order.approvedByEmail}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                                if (order.isRejected &&
                                    order.rejectionReason.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Từ chối: ${order.rejectionReason}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.error,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            trailing: Text(
                              '-${order.totalPoints}đ',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFFC2410C),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showLeadRecordDialog({
    required BuildContext context,
    required String userUid,
    required String userEmail,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LeadRecordPointsSheet(
        userUid: userUid,
        userEmail: userEmail,
        pointRuleService: _pointRuleService,
        pointRecordService: _pointRecordService,
      ),
    );
  }
}

class _LeadRecordPointsSheet extends StatefulWidget {
  final String userUid;
  final String userEmail;
  final PointRuleService pointRuleService;
  final PointRecordService pointRecordService;

  const _LeadRecordPointsSheet({
    required this.userUid,
    required this.userEmail,
    required this.pointRuleService,
    required this.pointRecordService,
  });

  @override
  State<_LeadRecordPointsSheet> createState() => _LeadRecordPointsSheetState();
}

class _LeadRecordPointsSheetState extends State<_LeadRecordPointsSheet> {
  final TextEditingController _qtyCtrl = TextEditingController(text: '1');
  final TextEditingController _noteCtrl = TextEditingController();
  String? _selectedClass;
  PointRuleModel? _selectedRule;
  bool _isLoading = false;
  late final Stream<QuerySnapshot> _classesStream;
  late final Stream<List<PointRuleModel>> _rulesStream;

  @override
  void initState() {
    super.initState();
    _classesStream = FirebaseFirestore.instance
        .collection('classes')
        .snapshots();
    _rulesStream = widget.pointRuleService.getPointRulesStream(
      onlyActive: true,
    );
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: StreamBuilder<QuerySnapshot>(
            stream: _classesStream,
            builder: (context, classesSnap) {
              final classDocs = classesSnap.data?.docs ?? [];
              final classNames = classDocs
                  .map(
                    (d) =>
                        (d.data() as Map<String, dynamic>)['className']
                            as String? ??
                        d.id,
                  )
                  .toList();
              classNames.sort();

              if (classNames.isNotEmpty && _selectedClass == null) {
                _selectedClass = classNames.first;
              }

              return StreamBuilder<List<PointRuleModel>>(
                stream: _rulesStream,
                builder: (context, rulesSnap) {
                  final rules = rulesSnap.data ?? [];

                  if (rules.isNotEmpty && _selectedRule == null) {
                    _selectedRule = rules.first;
                  }

                  final rule = _selectedRule;
                  final double currentQty =
                      double.tryParse(_qtyCtrl.text.trim()) ?? 0.0;
                  final int estimatedPoints = rule != null
                      ? rule.calculatePoints(currentQty)
                      : 0;

                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.stars_rounded,
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Tích Điểm Toàn Trường',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Chọn lớp học được cộng điểm
                        DropdownButtonFormField<String>(
                          initialValue: _selectedClass,
                          decoration: const InputDecoration(
                            labelText: 'Chọn Lớp Được Tích Điểm *',
                            prefixIcon: Icon(Icons.school_rounded),
                          ),
                          items: classNames.map((c) {
                            return DropdownMenuItem<String>(
                              value: c,
                              child: Text('Lớp $c'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedClass = val);
                            }
                          },
                        ),
                        const SizedBox(height: 14),

                        // Chọn thể loại thu gom
                        if (rules.isEmpty)
                          const Text(
                            'Chưa có thể loại thu gom nào được cấu hình.',
                            style: TextStyle(color: AppColors.error),
                          )
                        else
                          DropdownButtonFormField<PointRuleModel>(
                            initialValue: rule,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Thể loại thu gom *',
                              prefixIcon: Icon(Icons.recycling_rounded),
                            ),
                            items: rules.map((r) {
                              return DropdownMenuItem<PointRuleModel>(
                                value: r,
                                child: Row(
                                  children: [
                                    Icon(r.iconData,
                                        size: 20, color: AppColors.primary),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        '${r.name} (${r.ruleRateText})',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedRule = val);
                              }
                            },
                          ),
                        const SizedBox(height: 14),

                        // Nhập số lượng / kg
                        TextField(
                          controller: _qtyCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*'),
                            ),
                          ],
                          decoration: InputDecoration(
                            labelText:
                                'Nhập ${rule?.unit ?? 'số lượng'} thu gom *',
                            suffixText: rule?.unit ?? '',
                            prefixIcon: const Icon(Icons.scale_rounded),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 12),

                        // Ghi chú
                        TextField(
                          controller: _noteCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Ghi chú (Tùy chọn)',
                            prefixIcon: Icon(Icons.notes_rounded),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Tóm tắt quy đổi
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Cộng vào: Lớp ${_selectedClass ?? ''}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryDark,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (rule != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Tỷ lệ: ${rule.ruleRateText} ($currentQty ${rule.unit})',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '+$estimatedPoints điểm',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed:
                              _isLoading ||
                                  rule == null ||
                                  _selectedClass == null
                              ? null
                              : () async {
                                  final qty =
                                      double.tryParse(_qtyCtrl.text.trim()) ??
                                      0.0;
                                  if (qty <= 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Vui lòng nhập số lượng hoặc khối lượng > 0!',
                                        ),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                    return;
                                  }

                                  setState(() => _isLoading = true);
                                  try {
                                    await widget.pointRecordService
                                        .recordPoints(
                                          className: _selectedClass!,
                                          ruleId: rule.id,
                                          categoryName: rule.name,
                                          unit: rule.unit,
                                          quantity: qty,
                                          unitQuantity: rule.unitQuantity,
                                          points: rule.points,
                                          pointsPerUnit: rule.pointsPerUnit,
                                          note: _noteCtrl.text.trim(),
                                          createdByEmail: widget.userEmail,
                                          createdByUid: widget.userUid,
                                        );

                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Đã tích +$estimatedPoints điểm cho lớp ${_selectedClass!} thành công!',
                                          ),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            SnackBar(
                                              content: Text('Lỗi: $e'),
                                              backgroundColor: AppColors.error,
                                            ),
                                          );
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() => _isLoading = false);
                                    }
                                  }
                                },
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline_rounded),
                          label: Text(
                            _isLoading ? 'Đang Lưu...' : 'Xác Nhận Tích Điểm',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
