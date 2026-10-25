import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/firebase_error_mapper.dart';
import '../../../../core/utils/string_utils.dart';
import '../../../../core/widgets/large_quantity_confirm_dialog.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../../admin/models/point_rule_model.dart';
import '../../../admin/services/point_rule_service.dart';
import '../../../admin/services/reward_service.dart';
import '../../../auth/services/auth_service.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../teacher/models/point_record_model.dart';
import '../../../teacher/models/reward_record_model.dart';
import '../../../teacher/presentation/widgets/delete_point_record_dialog.dart';
import '../../../teacher/presentation/widgets/edit_point_record_sheet.dart';
import '../../../teacher/services/point_record_service.dart';
import '../widgets/lead_teacher_leaderboard_tab.dart';
import '../widgets/lead_teacher_pending_orders_tab.dart';

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
      0; // 0: Xếp hạng & Thống kê, 1: Duyệt đổi quà, 2: Nhật ký toàn trường
  int _schoolHistoryTabIndex = 0; // 0: Thu gom (+), 1: Đổi quà (-)

  int _pointRecordsLimit = 25;
  int _rewardRecordsLimit = 25;

  late final Stream<List<RewardRecordModel>> _pendingOrdersStream;
  late Stream<QuerySnapshot> _pointRecordsStream;
  late Stream<List<RewardRecordModel>> _allRewardRecordsStream;

  Stream<QuerySnapshot> _buildPointRecordsStream(int limit) {
    return FirebaseFirestore.instance
        .collection('point_records')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  Stream<List<RewardRecordModel>> _buildRewardRecordsStream(int limit) {
    return _rewardService.getAllRewardRecordsStream(limit: limit);
  }

  String get _appBarTitle {
    switch (_currentTabIndex) {
      case 0:
        return 'Xếp Hạng & Thống Kê';
      case 1:
        return 'Duyệt Đổi Quà';
      case 2:
        return 'Nhật Ký Toàn Trường';
      default:
        return 'Tổng Phụ Trách';
    }
  }

  @override
  void initState() {
    super.initState();
    _pendingOrdersStream = _rewardService.getPendingOrdersStream();
    _pointRecordsStream = _buildPointRecordsStream(_pointRecordsLimit);
    _allRewardRecordsStream = _buildRewardRecordsStream(_rewardRecordsLimit);
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
        centerTitle: true,
        title: Text(
          _appBarTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
            icon: Icon(Icons.leaderboard_outlined),
            selectedIcon: Icon(Icons.leaderboard_rounded),
            label: 'Thống Kê & Xếp Hạng',
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
            label: 'Duyệt Đổi Quà',
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
        return const LeadTeacherLeaderboardTab();
      case 1:
        return LeadTeacherPendingOrdersTab(user: user);
      case 2:
        return _buildSchoolHistoryTab();
      default:
        return const LeadTeacherLeaderboardTab();
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
                      child: Center(
                        child: Text(
                          'Thu Gom Phế Liệu',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _schoolHistoryTabIndex == 0
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
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
                      child: Center(
                        child: Text(
                          'Đổi Điểm Lấy Quà',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _schoolHistoryTabIndex == 1
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
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
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Lỗi nạp nhật ký thu gom: ${snapshot.error}',
                          style: const TextStyle(color: AppColors.error),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data?.docs ?? [];
                    final records = docs
                        .map((d) => PointRecordModel.fromFirestore(d))
                        .toList();

                    records.sort((a, b) {
                      final aTime = a.createdAt;
                      final bTime = b.createdAt;
                      if (aTime == null && bTime == null) return 0;
                      if (aTime == null) return 1;
                      if (bTime == null) return -1;
                      return bTime.compareTo(aTime);
                    });

                    if (records.isEmpty) {
                      return const Center(
                        child: Text(
                          'Chưa có lượt thu gom nào được ghi nhận trên hệ thống.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      );
                    }

                    final hasMore = records.length >= _pointRecordsLimit;

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: records.length + (hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == records.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Center(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  side: BorderSide(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.5)),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.expand_more_rounded,
                                    size: 20, color: AppColors.primary),
                                label: Text(
                                  'Tải thêm 25 lượt thu gom cũ hơn (Đang xem ${records.length})',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _pointRecordsLimit += 25;
                                    _pointRecordsStream =
                                        _buildPointRecordsStream(
                                            _pointRecordsLimit);
                                  });
                                },
                              ),
                            ),
                          );
                        }

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
                                    rec.categoryName,
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
                                const SizedBox(height: 4),
                                // 1. Số lượng thu gom
                                Text(
                                  'Số lượng: $formattedQty ${rec.unit}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                // 2. Tỷ lệ quy đổi riêng biệt
                                Text(
                                  'Quy đổi: ${rec.ruleRateText}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                // 3. Thời gian tạo & Nhãn Đã sửa (nếu có)
                                Row(
                                  children: [
                                    Text(
                                      _formatDateTime(rec.createdAt),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    if (rec.isEdited) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 1.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.warning.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Text(
                                          'Đã sửa',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.warning,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                // 4. Email người ghi nhận (xuống hàng riêng biệt)
                                if (rec.createdByEmail.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Người ghi: ${rec.createdByEmail}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                // 5. Ghi chú (nếu có)
                                if (rec.note.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    'Ghi chú: ${rec.note}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '+${rec.totalPoints}đ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: AppColors.success,
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(
                                    Icons.more_vert,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                  tooltip: 'Tùy chọn',
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  onSelected: (val) {
                                    final user =
                                        FirebaseAuth.instance.currentUser;
                                    final email = user?.email ?? '';
                                    final uid = user?.uid ?? '';
                                    if (val == 'edit') {
                                      EditPointRecordSheet.show(
                                        context: context,
                                        record: rec,
                                        userEmail: email,
                                        userUid: uid,
                                      );
                                    } else if (val == 'delete') {
                                      showConfirmDeletePointRecordDialog(
                                        context: context,
                                        record: rec,
                                        userEmail: email,
                                        userUid: uid,
                                      );
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.edit_outlined,
                                            size: 18,
                                            color: AppColors.primary,
                                          ),
                                          SizedBox(width: 8),
                                          Text('Chỉnh sửa'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.delete_outline_rounded,
                                            size: 18,
                                            color: AppColors.error,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Hủy lượt thu gom',
                                            style: TextStyle(
                                              color: AppColors.error,
                                            ),
                                          ),
                                        ],
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
                )
              : StreamBuilder<List<RewardRecordModel>>(
                  stream: _allRewardRecordsStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Lỗi nạp nhật ký đổi quà: ${snapshot.error}',
                          style: const TextStyle(color: AppColors.error),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final orders = snapshot.data ?? [];
                    if (orders.isEmpty) {
                      return const Center(
                        child: Text(
                          'Chưa có yêu cầu đổi quà nào trên toàn trường.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      );
                    }

                    final hasMore = orders.length >= _rewardRecordsLimit;

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: orders.length + (hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == orders.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Center(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  side: BorderSide(
                                      color: const Color(0xFFC2410C)
                                          .withValues(alpha: 0.5)),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.expand_more_rounded,
                                    size: 20, color: Color(0xFFC2410C)),
                                label: Text(
                                  'Tải thêm 25 lượt đổi quà cũ hơn (Đang xem ${orders.length})',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFC2410C)),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _rewardRecordsLimit += 25;
                                    _allRewardRecordsStream =
                                        _buildRewardRecordsStream(
                                            _rewardRecordsLimit);
                                  });
                                },
                              ),
                            ),
                          );
                        }

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
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryDark,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    order.className,
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
                                    order.rewardName,
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
                                const SizedBox(height: 4),
                                // 1. Số lượng đổi (đứng riêng một dòng nổi bật)
                                Text(
                                  'Số lượng: ${order.quantity} ${order.unit}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                // 2. Mức đổi (đứng riêng một dòng rõ ràng)
                                Text(
                                  'Mức đổi: ${order.pointsCost} điểm / ${order.unit}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                // 3. Trạng thái & Thời gian tạo
                                Row(
                                  children: [
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
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatDateTime(order.createdAt),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                // 4. Thông tin duyệt (nếu có)
                                if (order.isApproved &&
                                    order.approvedByEmail != null &&
                                    order.approvedByEmail!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Duyệt bởi: ${order.approvedByEmail}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                                // 5. Thông tin từ chối (nếu có)
                                if (order.isRejected &&
                                    order.rejectionReason.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Lý do từ chối: ${order.rejectionReason}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.error,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                                // 6. Ghi chú của lớp (nếu có)
                                if (order.note.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    'Ghi chú: ${order.note}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                      color: AppColors.textSecondary,
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
  final TextEditingController _qtyCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  String? _selectedClass;
  PointRuleModel? _selectedRule;
  bool _isLoading = false;
  bool _hasInitializedQty = false;
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
              classNames.sort(StringUtils.compareNatural);

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
                  if (rule != null && !_hasInitializedQty) {
                    _hasInitializedQty = true;
                    _qtyCtrl.text = '${rule.unitQuantity}';
                  }

                  final double currentQty =
                      double.tryParse(_qtyCtrl.text.trim()) ?? 0.0;
                  final int estimatedPoints = rule != null
                      ? rule.calculatePoints(currentQty)
                      : 0;
                  final bool isEnough = rule != null &&
                      currentQty >= rule.unitQuantity &&
                      estimatedPoints > 0;
                  final bool isLargeQty = rule != null &&
                      LargeQuantityHelper.isLargePointRecord(
                        quantity: currentQty,
                        isKg: rule.unit.toLowerCase().contains('kg'),
                        calculatedPoints: estimatedPoints,
                      );

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
                            const Text(
                              'Tích Điểm Toàn Trường',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
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
                            ),
                            items: rules.map((r) {
                              return DropdownMenuItem<PointRuleModel>(
                                value: r,
                                child: Text(
                                  '${r.name} (${r.ruleRateText})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedRule = val;
                                  final cur =
                                      double.tryParse(_qtyCtrl.text.trim()) ??
                                          0.0;
                                  if (cur < val.unitQuantity) {
                                    _qtyCtrl.text = '${val.unitQuantity}';
                                  }
                                });
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
                            helperText: rule != null
                                ? 'Tối thiểu: ${rule.unitQuantity} ${rule.unit} (${rule.ruleRateText})'
                                : null,
                            errorText: (rule != null &&
                                    currentQty > 0 &&
                                    !isEnough)
                                ? 'Chưa đủ mốc! Cần tối thiểu ${rule.unitQuantity} ${rule.unit} để được 1 điểm'
                                : null,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        if (rule != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text(
                                'Tăng nhanh:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ...{
                                rule.unitQuantity,
                                rule.unitQuantity * 2,
                                rule.unitQuantity * 5
                              }.map((addQty) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: InkWell(
                                    onTap: () {
                                      final cur = double.tryParse(
                                              _qtyCtrl.text.trim()) ??
                                          0.0;
                                      final next =
                                          (cur <= 0 ? 0 : cur) + addQty;
                                      _qtyCtrl.text = rule.unit
                                              .toLowerCase()
                                              .contains('kg')
                                          ? (next.truncateToDouble() == next
                                              ? next.toInt().toString()
                                              : next.toStringAsFixed(1))
                                          : next.toInt().toString();
                                      setState(() {});
                                    },
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.08),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                        border: Border.all(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.25),
                                        ),
                                      ),
                                      child: Text(
                                        '+$addQty',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryDark,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),

                        // Ghi chú
                        TextField(
                          controller: _noteCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Ghi chú (Tùy chọn)',
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Tóm tắt quy đổi
                        if (rule != null && !isEnough)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.errorLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: AppColors.error,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Chưa đủ số lượng quy đổi! Cần tối thiểu ${rule.unitQuantity} ${rule.unit} để được tính điểm (${rule.ruleRateText}).',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                        if (rule != null && isEnough && isLargeQty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.warning.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  color: Color(0xFFC2410C),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Lưu ý: Số lượng thu gom khá lớn ($currentQty ${rule.unit} = +$estimatedPoints điểm). Hệ thống sẽ yêu cầu xác nhận trước khi lưu.',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF9A3412),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),

                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: isEnough
                                ? AppColors.primary
                                : Colors.grey.shade400,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _isLoading ||
                                  rule == null ||
                                  _selectedClass == null ||
                                  !isEnough
                              ? null
                              : () async {
                                  final qty =
                                      double.tryParse(_qtyCtrl.text.trim()) ??
                                      0.0;
                                  if (qty < rule.unitQuantity ||
                                      estimatedPoints <= 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Chưa đủ số lượng quy đổi! Cần tối thiểu ${rule.unitQuantity} ${rule.unit} để được tính điểm.',
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
                                          'Số lượng vượt quá giới hạn cho phép (tối đa ${LargeQuantityHelper.maxPointRecordQuantity.toInt()} ${rule.unit})! Vui lòng kiểm tra lại.',
                                        ),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                    return;
                                  }

                                  if (isLargeQty) {
                                    final ok = await showConfirmLargePointRecordDialog(
                                      context: context,
                                      className: _selectedClass!,
                                      categoryName: rule.name,
                                      quantity: qty,
                                      unit: rule.unit,
                                      points: estimatedPoints,
                                    );
                                    if (!ok) return;
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
                                              content: Text(
                                                FirebaseErrorMapper
                                                    .getCleanErrorMessage(e),
                                              ),
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
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  isEnough
                                      ? 'Xác Nhận Tích +$estimatedPoints Điểm'
                                      : 'Chưa Đủ Mốc Tối Thiểu (${rule?.unitQuantity ?? 1} ${rule?.unit ?? ""})',
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
