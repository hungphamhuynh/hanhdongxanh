import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/firebase_error_mapper.dart';
import '../../../../core/widgets/large_quantity_confirm_dialog.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../../admin/models/point_rule_model.dart';
import '../../../admin/models/reward_rule_model.dart';
import '../../../admin/models/school_year_config_model.dart';
import '../../../admin/services/academic_year_service.dart';
import '../../../admin/services/point_rule_service.dart';
import '../../../admin/services/reward_service.dart';
import '../../../auth/services/auth_service.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../models/point_record_model.dart';
import '../../models/reward_record_model.dart';
import '../../services/point_record_service.dart';
import '../widgets/delete_point_record_dialog.dart';
import '../widgets/edit_point_record_sheet.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  final PointRecordService _pointRecordService = PointRecordService();
  final PointRuleService _pointRuleService = PointRuleService();
  final RewardService _rewardService = RewardService();
  final AcademicYearService _academicYearService = AcademicYearService();
  final AuthService _authService = AuthService();
  int _currentTabIndex = 0; // 0 = Tổng quan, 1 = Tích điểm, 2 = Đổi quà
  bool _isLoadingReward = false;

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Vừa xong';
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  /// Mở modal đổi quà an toàn có khóa chống double-tap và timeout
  Future<void> _handleOpenRewardOrder({
    required BuildContext context,
    required String assignedClass,
    required User user,
  }) async {
    setState(() => _isLoadingReward = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('classes')
          .doc(assignedClass)
          .get()
          .timeout(const Duration(seconds: 4));
      final pts = ((doc.data()?['totalPoints']) as num?)?.toInt() ?? 0;
      if (mounted) {
        setState(() => _isLoadingReward = false);
      }
      if (context.mounted) {
        _showRewardOrderModal(
          context: context,
          className: assignedClass,
          currentClassPoints: pts,
          teacherUid: user.uid,
          teacherEmail: user.email ?? '',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingReward = false);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is TimeoutException
                  ? 'Mạng không ổn định, vui lòng kiểm tra lại kết nối!'
                  : FirebaseErrorMapper.getCleanErrorMessage(e),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String get _appBarTitle {
    switch (_currentTabIndex) {
      case 0:
        return 'Tổng Quan';
      case 1:
        return 'Lịch Sử Tích Điểm';
      case 2:
        return 'Lịch Sử Đổi Điểm';
      default:
        return 'Tổng Quan';
    }
  }

  Widget? _buildFloatingActionButton({
    required BuildContext context,
    required String assignedClass,
    required User user,
  }) {
    if (_currentTabIndex == 1) {
      return FloatingActionButton.extended(
        heroTag: 'fab_teacher_record',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_task_rounded),
        label: const Text(
          'Tích Điểm Mới',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () => _showRecordPointsModal(
          context: context,
          className: assignedClass,
          teacherUid: user.uid,
          teacherEmail: user.email ?? '',
        ),
      );
    } else if (_currentTabIndex == 2) {
      return FloatingActionButton.extended(
        heroTag: 'fab_teacher_reward',
        backgroundColor: const Color(0xFFC2410C),
        foregroundColor: Colors.white,
        icon: _isLoadingReward
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.card_giftcard_rounded),
        label: Text(
          _isLoadingReward ? 'Đang kiểm tra điểm...' : 'Lên Đơn Đổi Quà',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: _isLoadingReward
            ? null
            : () => _handleOpenRewardOrder(
                  context: context,
                  assignedClass: assignedClass,
                  user: user,
                ),
      );
    }
    return null;
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
          body: IndexedStack(
            index: _currentTabIndex,
            children: [
              _buildOverviewTab(
                context: context,
                assignedClass: assignedClass,
                fullName: fullName,
                user: user,
              ),
              _buildPointHistoryTab(
                context: context,
                assignedClass: assignedClass,
                user: user,
              ),
              _buildRewardHistoryTab(
                context: context,
                assignedClass: assignedClass,
                user: user,
              ),
            ],
          ),
          floatingActionButton: _buildFloatingActionButton(
            context: context,
            assignedClass: assignedClass,
            user: user,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentTabIndex,
            onDestinationSelected: (index) =>
                setState(() => _currentTabIndex = index),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
                label: 'Tổng Quan',
              ),
              const NavigationDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history_rounded),
                label: 'Tích Điểm',
              ),
              NavigationDestination(
                icon: StreamBuilder<List<RewardRecordModel>>(
                  stream: _rewardService
                      .getRewardRecordsByClassStream(assignedClass),
                  builder: (context, snapshot) {
                    final pendingCount = (snapshot.data ?? [])
                        .where((o) => o.isPending)
                        .length;
                    return Badge(
                      isLabelVisible: pendingCount > 0,
                      label: Text('$pendingCount'),
                      child: const Icon(Icons.card_giftcard_outlined),
                    );
                  },
                ),
                selectedIcon: StreamBuilder<List<RewardRecordModel>>(
                  stream: _rewardService
                      .getRewardRecordsByClassStream(assignedClass),
                  builder: (context, snapshot) {
                    final pendingCount = (snapshot.data ?? [])
                        .where((o) => o.isPending)
                        .length;
                    return Badge(
                      isLabelVisible: pendingCount > 0,
                      label: Text('$pendingCount'),
                      child: const Icon(Icons.card_giftcard_rounded),
                    );
                  },
                ),
                label: 'Đổi Quà',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOverviewTab({
    required BuildContext context,
    required String assignedClass,
    required String fullName,
    required User user,
  }) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('classes')
          .doc(assignedClass)
          .snapshots(),
      builder: (context, classSnap) {
        final classData = classSnap.data?.data() as Map<String, dynamic>? ?? {};
        final totalPoints = (classData['totalPoints'] as num?)?.toInt() ?? 0;

        return ResponsiveContainer(
          maxWidth: 850,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildEcoOverviewCard(
                  assignedClass: assignedClass,
                  fullName: fullName,
                  totalPoints: totalPoints,
                ),
                const SizedBox(height: 16),
                // Card danh sách thu gom gần nhất
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
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
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight
                                      .withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.history_rounded,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Lượt Thu Gom Gần Đây',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: () =>
                                setState(() => _currentTabIndex = 1),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Xem tất cả',
                                    style: TextStyle(fontSize: 13)),
                                SizedBox(width: 2),
                                Icon(Icons.arrow_forward_ios_rounded, size: 12),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<List<PointRecordModel>>(
                        stream: _pointRecordService
                            .getRecordsByClassStream(assignedClass),
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          final recent = (snap.data ?? []).take(3).toList();
                          if (recent.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.0),
                              child: Center(
                                child: Text(
                                  'Chưa có lượt thu gom nào trong năm học',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            );
                          }
                          return Column(
                            children: recent
                                .map((rec) => _buildRecordCard(
                                      context,
                                      rec,
                                      userEmail: user.email ?? '',
                                      userUid: user.uid,
                                    ))
                                .toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPointHistoryTab({
    required BuildContext context,
    required String assignedClass,
    required User user,
  }) {
    return ResponsiveContainer(
      maxWidth: 850,
      child: StreamBuilder<List<PointRecordModel>>(
        stream: _pointRecordService.getRecordsByClassStream(assignedClass),
        builder: (context, recordsSnap) {
          if (recordsSnap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'Lỗi tải nhật ký: ${recordsSnap.error}',
                  style: const TextStyle(color: AppColors.error),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (recordsSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final records = recordsSnap.data ?? [];

          if (records.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.25),
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
                      'Hãy vận động các bạn học sinh trong lớp gom Vỏ chai, Giấy, Pin để cùng tích lũy điểm sinh thái nhé!',
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
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: records.length,
            itemBuilder: (context, index) {
              final record = records[index];
              return _buildRecordCard(
                context,
                record,
                userEmail: user.email ?? '',
                userUid: user.uid,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildRewardHistoryTab({
    required BuildContext context,
    required String assignedClass,
    required User user,
  }) {
    return ResponsiveContainer(
      maxWidth: 850,
      child: StreamBuilder<List<RewardRecordModel>>(
        stream: _rewardService.getRewardRecordsByClassStream(assignedClass),
        builder: (context, ordersSnap) {
          if (ordersSnap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'Lỗi tải đơn đổi quà: ${ordersSnap.error}',
                  style: const TextStyle(color: AppColors.error),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (ordersSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = ordersSnap.data ?? [];

          if (orders.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC2410C).withValues(alpha: 0.15),
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
                      onPressed: _isLoadingReward
                          ? null
                          : () => _handleOpenRewardOrder(
                                context: context,
                                assignedClass: assignedClass,
                                user: user,
                              ),
                      icon: const Icon(Icons.card_giftcard_rounded),
                      label: const Text('Đổi Quà Ngay'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return _buildRewardOrderCard(context, order);
            },
          );
        },
      ),
    );
  }

  Widget _buildEcoOverviewCard({
    required String assignedClass,
    required String fullName,
    required int totalPoints,
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

          // Khối điểm tích lũy & Các ô thống kê phế liệu ĐỘNG theo niên khóa hiện hành
          StreamBuilder<SchoolYearConfigModel>(
            stream: _academicYearService.getSchoolYearConfigStream(),
            builder: (context, configSnap) {
              final schoolConfig = configSnap.data;
              final yearSubtitle = schoolConfig != null
                  ? 'Năm học ${schoolConfig.currentAcademicYear}'
                  : 'Điểm thi đua phong trào';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Khối điểm tích lũy lớn
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 16),
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TỔNG ĐIỂM SINH THÁI',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                letterSpacing: 0.8,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              yearSubtitle,
                              style: const TextStyle(
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

                  // Các ô thống kê phế liệu ĐỘNG 100% (tính từ các thể loại đang áp dụng và lịch sử thu gom của lớp trong niên khóa hiện tại)
                  StreamBuilder<List<PointRuleModel>>(
                    stream:
                        _pointRuleService.getPointRulesStream(onlyActive: true),
                    builder: (context, rulesSnap) {
                      final rules = rulesSnap.data ?? [];
                      if (rules.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return StreamBuilder<List<PointRecordModel>>(
                        stream: _pointRecordService
                            .getRecordsByClassStream(assignedClass),
                        builder: (context, recordsSnap) {
                          final records = recordsSnap.data ?? [];
                          final Map<String, double> collectedMap = {};
                          for (final rec in records) {
                            // Lọc chỉ tính toán các lượt thu gom phát sinh trong niên khóa hiện hành
                            if (schoolConfig != null &&
                                !schoolConfig.isRecordInCurrentYear(rec)) {
                              continue;
                            }

                            final keyById = rec.ruleId;
                            final keyByName =
                                rec.categoryName.trim().toLowerCase();
                            if (keyById.isNotEmpty) {
                              collectedMap[keyById] =
                                  (collectedMap[keyById] ?? 0.0) +
                                      rec.quantity;
                            }
                            collectedMap[keyByName] =
                                (collectedMap[keyByName] ?? 0.0) +
                                    rec.quantity;
                          }

                          return LayoutBuilder(
                            builder: (context, constraints) {
                              final itemWidth =
                                  (constraints.maxWidth - 8) / 2;
                              return Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: rules.map((rule) {
                                  final qty = collectedMap[rule.id] ??
                                      collectedMap[rule.name
                                          .trim()
                                          .toLowerCase()] ??
                                      0.0;
                                  final isKg = rule.isKg;
                                  final valueStr = isKg
                                      ? (qty > 0
                                          ? '${qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 1)} ${rule.unit}'
                                          : '0 ${rule.unit}')
                                      : '${qty.toInt()} ${rule.unit}';

                                  return SizedBox(
                                    width: itemWidth > 0 ? itemWidth : 160,
                                    child: _buildScrapMiniTile(
                                      icon: rule.iconData,
                                      iconColor: rule.categoryColor,
                                      label: rule.name,
                                      value: valueStr,
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ],
              );
            },
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

  Widget _buildRecordCard(
    BuildContext context,
    PointRecordModel record, {
    required String userEmail,
    required String userUid,
  }) {
    final color = record.categoryColor;
    final isKg = record.isKg;
    final unitDisplay = isKg
        ? '${record.quantity.toStringAsFixed(record.quantity.truncateToDouble() == record.quantity ? 0 : 1)} ${record.unit}'
        : '${record.quantity.toInt()} ${record.unit}';

    // Quyền chỉnh sửa: chính người tạo phiếu và trong vòng 24 giờ
    final isAuthor = record.createdByUid == userUid;
    final difference = record.createdAt != null
        ? DateTime.now().difference(record.createdAt!)
        : Duration.zero;
    final isWithin24h = difference.inHours < 24;
    final canManage = isAuthor && isWithin24h;

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
                  Text(
                    record.categoryName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          unitDisplay,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                      if (record.isEdited)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
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
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatDateTime(record.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Điểm số cộng
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

            // Nút Menu thao tác (Sửa / Hủy)
            if (canManage)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert,
                    size: 20, color: AppColors.textSecondary),
                tooltip: 'Tùy chọn',
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (val) {
                  if (val == 'edit') {
                    EditPointRecordSheet.show(
                      context: context,
                      record: record,
                      userEmail: userEmail,
                      userUid: userUid,
                    );
                  } else if (val == 'delete') {
                    showConfirmDeletePointRecordDialog(
                      context: context,
                      record: record,
                      userEmail: userEmail,
                      userUid: userUid,
                    );
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined,
                            size: 18, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('Chỉnh sửa số lượng'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded,
                            size: 18, color: AppColors.error),
                        SizedBox(width: 8),
                        Text('Hủy lượt thu gom',
                            style: TextStyle(color: AppColors.error)),
                      ],
                    ),
                  ),
                ],
              )
            else if (isAuthor && !isWithin24h)
              const Tooltip(
                message:
                    'Đã quá 24 giờ. Chỉ Tổng phụ trách / Quản trị viên mới có thể chỉnh sửa hoặc hủy phiếu này.',
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Icon(
                    Icons.lock_clock_outlined,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ),
              )
            else
              Tooltip(
                message:
                    'Phiếu do ${record.createdByEmail.isNotEmpty ? record.createdByEmail : "Tổng phụ trách"} ghi nhận.',
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Icon(
                    Icons.info_outline,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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
    const rewardColor = Color(0xFFC2410C);

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
            // Icon quà bên trái
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: rewardColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                order.iconData,
                color: rewardColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),

            // Thông tin quà & trạng thái ở giữa
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.rewardName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: order.statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(order.statusIcon,
                                size: 11, color: order.statusColor),
                            const SizedBox(width: 3),
                            Text(
                              order.statusLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: order.statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: rewardColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${order.quantity} ${order.unit}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: rewardColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    order.isApproved && order.approvedByEmail != null
                        ? '${_formatDateTime(order.createdAt)} • Duyệt: ${order.approvedByEmail}'
                        : _formatDateTime(order.createdAt),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (order.isRejected && order.rejectionReason.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Lý do từ chối: ${order.rejectionReason}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: AppColors.error,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ] else if (order.note.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Ghi chú: ${order.note}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Điểm số trừ ở bên phải
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: rewardColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '-${order.totalPoints}đ',
                    style: const TextStyle(
                      color: rewardColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${order.pointsCost}đ/${order.unit}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
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
  final TextEditingController _qtyCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  PointRuleModel? _selectedRule;
  bool _isLoading = false;
  bool _hasInitializedQty = false;
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

              if (!_hasInitializedQty) {
                _hasInitializedQty = true;
                _qtyCtrl.text = rule.unit.toLowerCase().contains('kg')
                    ? (rule.unitQuantity.truncateToDouble() == rule.unitQuantity
                        ? rule.unitQuantity.toInt().toString()
                        : rule.unitQuantity.toString())
                    : rule.unitQuantity.toInt().toString();
              }

              final double currentQty =
                  double.tryParse(_qtyCtrl.text.trim()) ?? 0.0;
              final int estimatedPoints = rule.calculatePoints(currentQty);
              final bool isEnough =
                  currentQty >= rule.unitQuantity && estimatedPoints > 0;
              final bool isLargeQty = LargeQuantityHelper.isLargePointRecord(
                quantity: currentQty,
                isKg: rule.unit.toLowerCase().contains('kg'),
                calculatedPoints: estimatedPoints,
              );

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
                          setState(() {
                            _selectedRule = val;
                            final cur =
                                double.tryParse(_qtyCtrl.text.trim()) ?? 0.0;
                            if (cur < val.unitQuantity) {
                              _qtyCtrl.text = val.unit.toLowerCase().contains('kg')
                                  ? (val.unitQuantity.truncateToDouble() == val.unitQuantity
                                      ? val.unitQuantity.toInt().toString()
                                      : val.unitQuantity.toString())
                                  : val.unitQuantity.toInt().toString();
                            }
                          });
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
                        helperText:
                            'Tối thiểu: ${rule.unitQuantity} ${rule.unit} (${rule.ruleRateText})',
                        errorText: (currentQty > 0 && !isEnough)
                            ? 'Chưa đủ mốc! Cần tối thiểu ${rule.unitQuantity} ${rule.unit} để được 1 điểm'
                            : null,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),

                    // Tăng nhanh
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
                          rule.unitQuantity * 5,
                        }.map((addQty) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: InkWell(
                              onTap: () {
                                final cur =
                                    double.tryParse(_qtyCtrl.text.trim()) ?? 0.0;
                                final next = (cur <= 0 ? 0 : cur) + addQty;
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
                                  borderRadius: BorderRadius.circular(6),
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

                    // Thẻ tóm tắt tính điểm hoặc cảnh báo chưa đủ mốc
                    if (!isEnough)
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
                    if (isEnough && isLargeQty) ...[
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
                                'Lưu ý: Số lượng thu gom khá lớn ($currentQty ${rule.unit} = $estimatedPoints điểm). Hệ thống sẽ yêu cầu xác nhận trước khi lưu.',
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

                    // Nút xác nhận tích điểm
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: isEnough
                            ? AppColors.primary
                            : Colors.grey.shade400,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isLoading || !isEnough
                          ? null
                          : () async {
                              final qty =
                                  double.tryParse(_qtyCtrl.text.trim()) ?? 0.0;
                              if (qty < rule.unitQuantity || estimatedPoints <= 0) {
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
                                  className: widget.className,
                                  categoryName: rule.name,
                                  quantity: qty,
                                  unit: rule.unit,
                                  points: estimatedPoints,
                                );
                                if (!ok) return;
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
                                      content: Text(
                                        FirebaseErrorMapper.getCleanErrorMessage(e),
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
                        _isLoading
                            ? 'Đang Lưu...'
                            : (!isEnough
                                ? 'Chưa Đủ Mốc Tối Thiểu (${rule.unitQuantity} ${rule.unit})'
                                : 'Xác Nhận Tích Điểm'),
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
          final isLargeReward = LargeQuantityHelper.isLargeRewardOrder(
            quantity: qty,
            totalPointsCost: totalCost,
            currentClassPoints: widget.currentClassPoints,
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
                if (isEnough && isLargeReward) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFC2410C).withValues(alpha: 0.4),
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
                            'Lưu ý: Bạn đang đặt đổi số lượng lớn ($qty ${rule.unit} = -$totalCost điểm). Hệ thống sẽ yêu cầu xác nhận trước khi gửi đơn.',
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
                          if (qty > LargeQuantityHelper.maxRewardOrderQuantity) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Số lượng đổi vượt quá giới hạn (tối đa 1.000 phần)! Vui lòng kiểm tra lại.',
                                ),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }

                          if (isLargeReward) {
                            final ok = await showConfirmLargeRewardOrderDialog(
                              context: context,
                              className: widget.className,
                              rewardName: rule.name,
                              quantity: qty,
                              unit: rule.unit,
                              totalPointsCost: totalCost,
                              remainingPoints: remainingPoints,
                            );
                            if (!ok) return;
                          }

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
                                  content: Text(
                                    FirebaseErrorMapper.getCleanErrorMessage(e),
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
