import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../../admin/models/point_rule_model.dart';
import '../../../admin/models/reward_rule_model.dart';
import '../../../admin/services/point_rule_service.dart';
import '../../../admin/services/reward_service.dart';
import '../../../auth/services/auth_service.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../models/point_record_model.dart';
import '../../models/reward_record_model.dart';
import '../../services/point_record_service.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  final PointRecordService _pointRecordService = PointRecordService();
  final PointRuleService _pointRuleService = PointRuleService();
  final RewardService _rewardService = RewardService();
  final AuthService _authService = AuthService();
  int _historyTabIndex = 0; // 0 = Lịch sử tích điểm (+), 1 = Lịch sử đổi quà (-)

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
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, userSnap) {
        if (!userSnap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final userData = userSnap.data?.data() as Map<String, dynamic>? ?? {};
        final assignedClass = (userData['assignedClass'] as String? ?? '')
            .trim()
            .toUpperCase();
        final fullName = userData['fullName'] as String? ?? 'Giáo viên phụ trách';

        if (assignedClass.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Giáo Viên Phụ Trách'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () => _authService.signOut(),
                ),
              ],
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 64,
                      color: AppColors.warning,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Chưa được phân công lớp học',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tài khoản của bạn chưa được liên kết với lớp nào. Vui lòng liên hệ Quản trị viên để kiểm tra.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () => _authService.signOut(),
                      icon: const Icon(Icons.logout),
                      label: const Text('Đăng Xuất'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.surfaceVariant,
          appBar: AppBar(
            centerTitle: true,
            title: Text(
              _historyTabIndex == 0
                  ? 'Lớp $assignedClass • Thu Gom Phế Liệu'
                  : 'Lớp $assignedClass • Đơn Đổi Quà',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.account_circle_outlined),
                tooltip: 'Hồ sơ cá nhân',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ProfileScreen()),
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
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'fab_teacher_action',
            backgroundColor: _historyTabIndex == 0
                ? AppColors.primary
                : const Color(0xFFC2410C),
            foregroundColor: Colors.white,
            icon: Icon(_historyTabIndex == 0
                ? Icons.add_task_rounded
                : Icons.card_giftcard_rounded),
            label: Text(
              _historyTabIndex == 0 ? 'Tích Điểm Thu Gom' : 'Lên Đơn Đổi Quà',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              if (_historyTabIndex == 0) {
                _showRecordPointsModal(
                  context: context,
                  className: assignedClass,
                  teacherUid: user.uid,
                  teacherEmail: user.email ?? '',
                );
              } else {
                // Lấy điểm hiện tại của lớp
                FirebaseFirestore.instance
                    .collection('classes')
                    .doc(assignedClass)
                    .get()
                    .then((doc) {
                  final pts =
                      ((doc.data()?['totalPoints']) as num?)?.toInt() ?? 0;
                  if (context.mounted) {
                    _showRewardOrderModal(
                      context: context,
                      className: assignedClass,
                      currentClassPoints: pts,
                      teacherUid: user.uid,
                      teacherEmail: user.email ?? '',
                    );
                  }
                });
              }
            },
          ),
          body: ResponsiveContainer(
            maxWidth: 850,
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('classes')
                  .doc(assignedClass)
                  .snapshots(),
              builder: (context, classSnap) {
                final classData =
                    classSnap.data?.data() as Map<String, dynamic>? ?? {};
                final totalPoints =
                    (classData['totalPoints'] as num?)?.toInt() ?? 0;
                final bottleCount =
                    (classData['bottleCount'] as num?)?.toInt() ?? 0;
                final canCount =
                    (classData['canCount'] as num?)?.toInt() ?? 0;
                final paperKg =
                    (classData['paperKg'] as num?)?.toDouble() ?? 0.0;
                final batteryCount =
                    (classData['batteryCount'] as num?)?.toInt() ?? 0;

                return CustomScrollView(
                  slivers: [
                    // Thẻ tổng quan điểm số lớp học
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: _buildEcoOverviewCard(
                          assignedClass: assignedClass,
                          fullName: fullName,
                          totalPoints: totalPoints,
                          bottleCount: bottleCount,
                          canCount: canCount,
                          paperKg: paperKg,
                          batteryCount: batteryCount,
                        ),
                      ),
                    ),

                    // Bộ chuyển đổi 2 Tab Lịch sử: Tích điểm (+) và Đổi quà (-)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _historyTabIndex = 0),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 9),
                                    decoration: BoxDecoration(
                                      color: _historyTabIndex == 0
                                          ? AppColors.primary
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_circle_outline_rounded,
                                          size: 16,
                                          color: _historyTabIndex == 0
                                              ? Colors.white
                                              : AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Lịch Sử Tích Điểm (+)',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: _historyTabIndex == 0
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
                                  onTap: () => setState(() => _historyTabIndex = 1),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 9),
                                    decoration: BoxDecoration(
                                      color: _historyTabIndex == 1
                                          ? const Color(0xFFC2410C)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.card_giftcard_rounded,
                                          size: 16,
                                          color: _historyTabIndex == 1
                                              ? Colors.white
                                              : AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Lịch Sử Đổi Điểm (-)',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: _historyTabIndex == 1
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
                    ),

                    // NỘI DUNG LỊCH SỬ TÍCH ĐIỂM (TAB 0)
                    if (_historyTabIndex == 0)
                      StreamBuilder<List<PointRecordModel>>(
                        stream: _pointRecordService
                            .getRecordsByClassStream(assignedClass),
                        builder: (context, recordsSnap) {
                          if (recordsSnap.hasError) {
                            return SliverFillRemaining(
                              child: Center(
                                child: Text(
                                  'Lỗi tải nhật ký: ${recordsSnap.error}',
                                  style: const TextStyle(color: AppColors.error),
                                ),
                              ),
                            );
                          }

                          if (recordsSnap.connectionState ==
                              ConnectionState.waiting) {
                            return const SliverFillRemaining(
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          final records = recordsSnap.data ?? [];

                          if (records.isEmpty) {
                            return SliverFillRemaining(
                              hasScrollBody: false,
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryLight
                                              .withValues(alpha: 0.25),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.eco_rounded,
                                          size: 48,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Chưa có lượt thu gom nào',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Hãy vận động các bạn học sinh trong lớp gom Vỏ chai và Pin để cùng tích lũy điểm sinh thái nhé!',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                        ),
                                        onPressed: () => _showRecordPointsModal(
                                          context: context,
                                          className: assignedClass,
                                          teacherUid: user.uid,
                                          teacherEmail: user.email ?? '',
                                        ),
                                        icon: const Icon(Icons.add),
                                        label: const Text('Tích Điểm Ngay'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          return SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final record = records[index];
                                  return _buildRecordCard(context, record);
                                },
                                childCount: records.length,
                              ),
                            ),
                          );
                        },
                      )
                    // NỘI DUNG LỊCH SỬ ĐỔI ĐIỂM (TAB 1)
                    else
                      StreamBuilder<List<RewardRecordModel>>(
                        stream: _rewardService
                            .getRewardRecordsByClassStream(assignedClass),
                        builder: (context, ordersSnap) {
                          if (ordersSnap.hasError) {
                            return SliverFillRemaining(
                              child: Center(
                                child: Text(
                                  'Lỗi tải đơn đổi quà: ${ordersSnap.error}',
                                  style: const TextStyle(color: AppColors.error),
                                ),
                              ),
                            );
                          }

                          if (ordersSnap.connectionState ==
                              ConnectionState.waiting) {
                            return const SliverFillRemaining(
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          final orders = ordersSnap.data ?? [];

                          if (orders.isEmpty) {
                            return SliverFillRemaining(
                              hasScrollBody: false,
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFC2410C)
                                              .withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.card_giftcard_rounded,
                                          size: 48,
                                          color: Color(0xFFC2410C),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Chưa có đơn đổi quà nào',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Khi lớp đạt đủ điểm thi đua, bạn có thể gửi yêu cầu đổi quà để Tổng phụ trách duyệt và phát thưởng nhé!',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: const Color(0xFFC2410C),
                                        ),
                                        onPressed: () => _showRewardOrderModal(
                                          context: context,
                                          className: assignedClass,
                                          currentClassPoints: totalPoints,
                                          teacherUid: user.uid,
                                          teacherEmail: user.email ?? '',
                                        ),
                                        icon: const Icon(Icons.card_giftcard_rounded),
                                        label: const Text('Đổi Quà Ngay'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          return SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final order = orders[index];
                                  return _buildRewardOrderCard(context, order);
                                },
                                childCount: orders.length,
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildEcoOverviewCard({
    required String assignedClass,
    required String fullName,
    required int totalPoints,
    required int bottleCount,
    required int canCount,
    required double paperKg,
    required int batteryCount,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dòng tiêu đề và huy hiệu lớp
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chi Đội Lớp $assignedClass',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Thu gom phế liệu - Tích điểm thi đua',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.eco_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Khối điểm tích lũy lớn
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TỔNG ĐIỂM SINH THÁI',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Điểm thi đua phong trào',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$totalPoints',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'điểm',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4 ô thống kê phế liệu: Chai, Lon, Giấy, Pin
          Row(
            children: [
              Expanded(
                child: _buildScrapMiniTile(
                  icon: Icons.local_drink_rounded,
                  iconColor: AppColors.primary,
                  label: 'Chai nhựa',
                  value: '$bottleCount chai',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildScrapMiniTile(
                  icon: Icons.recycling_rounded,
                  iconColor: AppColors.secondary,
                  label: 'Lon nhôm',
                  value: '$canCount lon',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildScrapMiniTile(
                  icon: Icons.newspaper_rounded,
                  iconColor: const Color(0xFF8D6E63),
                  label: 'Giấy vụn',
                  value: paperKg > 0 ? '${paperKg.toStringAsFixed(1)} kg' : '0 kg',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildScrapMiniTile(
                  icon: Icons.battery_charging_full_rounded,
                  iconColor: AppColors.warning,
                  label: 'Pin cũ',
                  value: '$batteryCount viên',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScrapMiniTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(BuildContext context, PointRecordModel record) {
    final isBattery = record.isBattery;
    final color = isBattery ? AppColors.warning : AppColors.primary;
    final unitDisplay = record.unit.toLowerCase().contains('kg')
        ? '${record.quantity.toStringAsFixed(1)} kg'
        : '${record.quantity.toInt()} ${record.categoryName.toLowerCase().contains('pin') ? 'viên' : record.categoryName.toLowerCase().contains('lon') ? 'lon' : 'cái'}';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Icon thể loại
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                record.iconData,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),

            // Thông tin thể loại & số lượng
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        record.categoryName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          unitDisplay,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatDateTime(record.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (record.note.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Ghi chú: ${record.note}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Điểm số cộng & Tùy chọn xóa
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '+${record.totalPoints}',
                    style: const TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  record.ruleRateText,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: AppColors.textSecondary),
              tooltip: 'Xóa lượt ghi này',
              onPressed: () => _confirmDeleteRecord(context, record),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteRecord(
      BuildContext context, PointRecordModel record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận hoàn tác điểm'),
        content: Text(
          'Bạn có chắc chắn muốn xóa lượt tích điểm này?\n\n'
          '• Thể loại: ${record.categoryName} (${record.quantity} ${record.unit})\n'
          '• Điểm bị trừ lại: -${record.totalPoints} điểm',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa & Trừ Điểm'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        await _pointRecordService.deleteRecord(record);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Đã hoàn tác và trừ ${record.totalPoints} điểm của lớp!',
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

  void _showRecordPointsModal({
    required BuildContext context,
    required String className,
    required String teacherUid,
    required String teacherEmail,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RecordPointsSheet(
        className: className,
        teacherUid: teacherUid,
        teacherEmail: teacherEmail,
        pointRuleService: _pointRuleService,
        pointRecordService: _pointRecordService,
      ),
    );
  }

  void _showRewardOrderModal({
    required BuildContext context,
    required String className,
    required int currentClassPoints,
    required String teacherUid,
    required String teacherEmail,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RewardOrderSheet(
        className: className,
        currentClassPoints: currentClassPoints,
        teacherUid: teacherUid,
        teacherEmail: teacherEmail,
      ),
    );
  }

  Widget _buildRewardOrderCard(BuildContext context, RewardRecordModel order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Icon quà
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC2410C).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    order.iconData,
                    color: const Color(0xFFC2410C),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),

                // Thông tin quà & số lượng
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              order.rewardName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: order.statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(order.statusIcon,
                                    size: 13, color: order.statusColor),
                                const SizedBox(width: 4),
                                Text(
                                  order.statusLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: order.statusColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
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
                const SizedBox(width: 8),

                // Số điểm trừ
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '-${order.totalPoints}đ',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFC2410C),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (order.note.isNotEmpty ||
                (order.isRejected && order.rejectionReason.isNotEmpty)) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: order.isRejected
                      ? AppColors.errorLight
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  order.isRejected
                      ? 'Lý do từ chối: ${order.rejectionReason}'
                      : 'Ghi chú: ${order.note}',
                  style: TextStyle(
                    fontSize: 12,
                    color: order.isRejected
                        ? AppColors.error
                        : AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDateTime(order.createdAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                if (order.isApproved && order.approvedByEmail != null)
                  Text(
                    'Đã duyệt bởi: ${order.approvedByEmail}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.success,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordPointsSheet extends StatefulWidget {
  final String className;
  final String teacherUid;
  final String teacherEmail;
  final PointRuleService pointRuleService;
  final PointRecordService pointRecordService;

  const _RecordPointsSheet({
    required this.className,
    required this.teacherUid,
    required this.teacherEmail,
    required this.pointRuleService,
    required this.pointRecordService,
  });

  @override
  State<_RecordPointsSheet> createState() => _RecordPointsSheetState();
}

class _RecordPointsSheetState extends State<_RecordPointsSheet> {
  final TextEditingController _qtyCtrl = TextEditingController(text: '1');
  final TextEditingController _noteCtrl = TextEditingController();
  PointRuleModel? _selectedRule;
  bool _isLoading = false;
  late final Stream<List<PointRuleModel>> _rulesStream;

  @override
  void initState() {
    super.initState();
    _rulesStream = widget.pointRuleService.getPointRulesStream(onlyActive: true);
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
          child: StreamBuilder<List<PointRuleModel>>(
            stream: _rulesStream,
            builder: (context, rulesSnap) {
              final rules = rulesSnap.data ?? [];

              if (rulesSnap.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (rules.isEmpty) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.rule_folder_outlined,
                      size: 48,
                      color: AppColors.warning,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Chưa có thể loại tích điểm',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ban Quản Trị chưa cấu hình thể loại thu gom (Vỏ chai, Pin). Vui lòng thông báo Quản trị viên để cấu hình điểm thưởng.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Đóng'),
                    ),
                  ],
                );
              }

              // Gán mặc định quy tắc đầu tiên nếu chưa chọn
              _selectedRule ??= rules.first;
              final rule = _selectedRule!;

              final double currentQty =
                  double.tryParse(_qtyCtrl.text.trim()) ?? 0.0;
              final int estimatedPoints = rule.calculatePoints(currentQty);

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Thanh kéo modal
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
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.eco_rounded,
                                color: AppColors.primary,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Tích Điểm Lớp ${widget.className}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Lựa chọn thể loại thu gom đã cấu hình
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
                    const SizedBox(height: 16),

                    // Ô nhập số lượng hoặc số kg
                    TextField(
                      controller: _qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Nhập ${rule.unit} thu gom *',
                        hintText: rule.unit.toLowerCase().contains('kg')
                            ? 'Ví dụ: 2.5'
                            : 'Ví dụ: 10, 20...',
                        prefixIcon: Icon(
                          rule.unit.toLowerCase().contains('kg')
                              ? Icons.scale_rounded
                              : Icons.format_list_numbered_rounded,
                        ),
                        suffixText: rule.unit,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),

                    // Ô nhập ghi chú
                    TextField(
                      controller: _noteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Ghi chú (Tùy chọn)',
                        hintText: 'Ví dụ: Học sinh nộp sau giờ sinh hoạt...',
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Thẻ tóm tắt tính điểm theo thời gian thực
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(14),
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
                                  'Tỷ lệ: ${rule.ruleRateText}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryDark,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Quy đổi: $currentQty ${rule.unit} → $estimatedPoints điểm',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.add_circle_rounded,
                                    color: AppColors.success,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$estimatedPoints điểm',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Nút xác nhận tích điểm
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isLoading
                          ? null
                          : () async {
                              final qty =
                                  double.tryParse(_qtyCtrl.text.trim()) ?? 0.0;
                              if (qty <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Vui lòng nhập số lượng hoặc khối lượng > 0!'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                                return;
                              }

                              setState(() => _isLoading = true);
                              try {
                                await widget.pointRecordService.recordPoints(
                                  className: widget.className,
                                  ruleId: rule.id,
                                  categoryName: rule.name,
                                  unit: rule.unit,
                                  quantity: qty,
                                  unitQuantity: rule.unitQuantity,
                                  points: rule.points,
                                  pointsPerUnit: rule.pointsPerUnit,
                                  note: _noteCtrl.text.trim(),
                                  createdByEmail: widget.teacherEmail,
                                  createdByUid: widget.teacherUid,
                                );

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Đã tích +$estimatedPoints điểm cho lớp ${widget.className} thành công!',
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RewardOrderSheet extends StatefulWidget {
  final String className;
  final int currentClassPoints;
  final String teacherUid;
  final String teacherEmail;

  const _RewardOrderSheet({
    required this.className,
    required this.currentClassPoints,
    required this.teacherUid,
    required this.teacherEmail,
  });

  @override
  State<_RewardOrderSheet> createState() => _RewardOrderSheetState();
}

class _RewardOrderSheetState extends State<_RewardOrderSheet> {
  final _rewardService = RewardService();
  final _qtyCtrl = TextEditingController(text: '1');
  final _noteCtrl = TextEditingController();
  RewardRuleModel? _selectedRule;
  bool _isLoading = false;
  late final Stream<List<RewardRuleModel>> _rewardsStream;

  @override
  void initState() {
    super.initState();
    _rewardsStream = _rewardService.getRewardRulesStream(activeOnly: true);
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
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: StreamBuilder<List<RewardRuleModel>>(
        stream: _rewardsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              heightFactor: 3,
              child: CircularProgressIndicator(),
            );
          }

          final rules = snapshot.data ?? [];
          if (rules.isEmpty) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                const Icon(Icons.card_giftcard_outlined,
                    size: 48, color: AppColors.textMuted),
                const SizedBox(height: 12),
                const Text(
                  'Hiện chưa có phần thưởng nào đang mở để đổi',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Vui lòng liên hệ Quản trị viên để cấu hình danh mục quà tặng.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Đóng'),
                ),
              ],
            );
          }

          _selectedRule ??= rules.first;
          final rule = _selectedRule!;
          final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
          final totalCost = qty * rule.pointsCost;
          final remainingPoints = widget.currentClassPoints - totalCost;
          final isEnough = widget.currentClassPoints >= totalCost && qty > 0;

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
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.card_giftcard_rounded,
                            color: Color(0xFFC2410C),
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Đổi Quà Lớp ${widget.className}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<RewardRuleModel>(
                  initialValue: rule,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Phần thưởng muốn đổi *',
                    prefixIcon: Icon(Icons.card_giftcard_rounded),
                  ),
                  items: rules.map((r) {
                    return DropdownMenuItem<RewardRuleModel>(
                      value: r,
                      child: Row(
                        children: [
                          Icon(r.iconData,
                              size: 20, color: const Color(0xFFC2410C)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${r.name} (${r.pointsCost}đ/${r.unit})',
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
                const SizedBox(height: 16),

                // Nhập số lượng
                TextField(
                  controller: _qtyCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Số lượng ${rule.unit} muốn đổi *',
                    hintText: 'Ví dụ: 1, 2, 5...',
                    prefixIcon: const Icon(Icons.pin_rounded),
                    suffixText: rule.unit,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),

                // Ghi chú
                TextField(
                  controller: _noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú cho Tổng phụ trách (Tùy chọn)',
                    hintText: 'Ví dụ: Đổi làm phần thưởng tuần cho bạn Hoa...',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: 16),

                // Thẻ tóm tắt tính điểm đổi quà
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isEnough
                        ? AppColors.surfaceVariant
                        : AppColors.errorLight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isEnough
                          ? const Color(0xFFC2410C).withValues(alpha: 0.3)
                          : AppColors.error.withValues(alpha: 0.5),
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
                              'Điểm hiện có: ${widget.currentClassPoints}đ',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Quy đổi: $qty ${rule.unit} × ${rule.pointsCost}đ = $totalCostđ',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isEnough
                                  ? 'Điểm còn lại: $remainingPointsđ'
                                  : 'Không đủ điểm (thiếu ${totalCost - widget.currentClassPoints}đ)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isEnough
                                    ? AppColors.primary
                                    : AppColors.error,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '-$totalCost điểm',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isEnough
                                  ? const Color(0xFFC2410C)
                                  : AppColors.error,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Nút gửi đơn
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC2410C),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isLoading || !isEnough
                      ? null
                      : () async {
                          setState(() => _isLoading = true);
                          try {
                            await _rewardService.createRewardOrder(
                              className: widget.className,
                              rule: rule,
                              quantity: qty,
                              note: _noteCtrl.text.trim(),
                              createdByEmail: widget.teacherEmail,
                              createdByUid: widget.teacherUid,
                            );

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Đã gửi đơn đổi "$qty ${rule.unit} ${rule.name}" thành công (đã trừ $totalCost điểm). Đang chờ Tổng phụ trách trao quà.',
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
                          } finally {
                            if (mounted) {
                              setState(() => _isLoading = false);
                            }
                          }
                        },
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _isLoading ? 'Đang gửi...' : 'Gửi Yêu Cầu Đổi Quà',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
