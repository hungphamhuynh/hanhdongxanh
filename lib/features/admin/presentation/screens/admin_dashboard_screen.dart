import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import '../../../../core/constants/user_role.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../../auth/services/auth_service.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../services/admin_class_service.dart';
import '../../services/admin_user_service.dart';
import '../../services/point_rule_service.dart';
import '../../services/reward_service.dart';
import '../widgets/admin_classes_tab.dart';
import '../widgets/admin_point_rules_tab.dart';
import '../widgets/admin_reward_rules_tab.dart';
import '../widgets/admin_users_tab.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentTabIndex = 0;
  final _adminUserService = AdminUserService();
  final _adminClassService = AdminClassService();
  final _pointRuleService = PointRuleService();
  final _rewardService = RewardService();

  String get _appBarTitle {
    switch (_currentTabIndex) {
      case 1:
        return 'Quản Lý Người Dùng';
      case 2:
        return 'Quản Lý Lớp Học';
      case 3:
        return 'Quy Tắc Tích Điểm';
      case 4:
        return 'Danh Mục Quà Tặng';
      case 0:
      default:
        return 'Tổng Quan Hệ Thống';
    }
  }

  Widget? _buildFloatingActionButton(BuildContext context) {
    if (_currentTabIndex == 1) {
      return FloatingActionButton.extended(
        onPressed: () => _showAddUserDialog(context),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Thêm Tài Khoản'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      );
    } else if (_currentTabIndex == 2) {
      return FloatingActionButton.extended(
        onPressed: () => _showAddClassDialog(context),
        icon: const Icon(Icons.add_home_work_rounded),
        label: const Text('Thêm Lớp Mới'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      );
    } else if (_currentTabIndex == 3) {
      return FloatingActionButton.extended(
        onPressed: () => _showAddPointRuleDialog(context),
        icon: const Icon(Icons.add_circle_outline_rounded),
        label: const Text('Thêm Thể Loại'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      );
    } else if (_currentTabIndex == 4) {
      return FloatingActionButton.extended(
        onPressed: () => _showAddRewardDialog(context),
        icon: const Icon(Icons.add_circle_outline_rounded),
        label: const Text('Thêm Quà Tặng'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTabIndex,
        onDestinationSelected: (index) =>
            setState(() => _currentTabIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Tổng Quan',
          ),
          NavigationDestination(
            icon: Icon(Icons.manage_accounts_outlined),
            selectedIcon: Icon(Icons.manage_accounts_rounded),
            label: 'Tài Khoản',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school_rounded),
            label: 'Lớp Học',
          ),
          NavigationDestination(
            icon: Icon(Icons.stars_outlined),
            selectedIcon: Icon(Icons.stars_rounded),
            label: 'Điểm Thưởng',
          ),
          NavigationDestination(
            icon: Icon(Icons.card_giftcard_outlined),
            selectedIcon: Icon(Icons.card_giftcard_rounded),
            label: 'Đổi Quà',
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(context),
      body: _buildCurrentTabBody(context),
    );
  }

  /// Dựng nội dung tab đang chọn - Tự động giải phóng (kill) tab cũ khi chuyển tab
  Widget _buildCurrentTabBody(BuildContext context) {
    switch (_currentTabIndex) {
      case 0:
        return _buildOverviewTab(context);
      case 1:
        return const AdminUsersTab();
      case 2:
        return const AdminClassesTab();
      case 3:
        return const AdminPointRulesTab();
      case 4:
        return const AdminRewardRulesTab();
      default:
        return _buildOverviewTab(context);
    }
  }

  Widget _buildOverviewTab(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return ResponsiveContainer(
      maxWidth: 900,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner Chào mừng
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryDark.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.eco_rounded,
                        color: AppColors.primaryContainer,
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'BẢNG ĐIỀU HÀNH TRUNG TÂM',
                        style: TextStyle(
                          color: AppColors.primaryContainer,
                          letterSpacing: 1.2,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user?.email ?? 'Quản Trị Viên',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Hệ thống quản lý hành động xanh & tích điểm trường học',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Danh sách các phân hệ quản lý
            const Text(
              'Phân Hệ Quản Trị',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Module 1: Quản lý tài khoản (Đang có)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .snapshots(),
              builder: (context, snapshot) {
                final count = snapshot.data?.docs.length ?? 0;

                return _buildModuleCard(
                  icon: Icons.manage_accounts_rounded,
                  title: 'Quản Lý Tài Khoản',
                  description:
                      'Cấp phát, chỉnh sửa, khóa và phân quyền người dùng',
                  badgeText: '$count tài khoản',
                  badgeColor: AppColors.primary,
                  onTap: () {
                    setState(() => _currentTabIndex = 1); // Chuyển sang Tab 1
                  },
                );
              },
            ),
            const SizedBox(height: 12),

            // Module 2: Lớp học & Thi đua
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('classes')
                  .snapshots(),
              builder: (context, snapshot) {
                final classCount = snapshot.data?.docs.length ?? 0;

                return _buildModuleCard(
                  icon: Icons.class_outlined,
                  title: 'Quản Lý Lớp Học',
                  description: 'Danh sách lớp học',
                  badgeText: '$classCount lớp học',
                  badgeColor: AppColors.secondary,
                  onTap: () {
                    setState(
                      () => _currentTabIndex = 2,
                    ); // Chuyển sang Tab 2: Lớp Học
                  },
                );
              },
            ),
            const SizedBox(height: 12),

            // Module 3: Cấu hình quy định điểm
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('point_rules')
                  .snapshots(),
              builder: (context, snapshot) {
                final ruleCount = snapshot.data?.docs.length ?? 0;

                return _buildModuleCard(
                  icon: Icons.stars_rounded,
                  title: 'Cấu Hình Điểm Thưởng',
                  description: 'Thiết lập danh mục hành động xanh (pin, chai...) và mức điểm thưởng',
                  badgeText: ruleCount > 0 ? '$ruleCount thể loại' : 'Cấu hình',
                  badgeColor: AppColors.roleLeadTeacher,
                  onTap: () {
                    setState(
                      () => _currentTabIndex = 3,
                    ); // Chuyển sang Tab 3: Điểm Thưởng
                  },
                );
              },
            ),
            const SizedBox(height: 12),

            // Module 4: Cấu hình đổi điểm lấy quà
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reward_rules')
                  .snapshots(),
              builder: (context, snapshot) {
                final rewardCount = snapshot.data?.docs.length ?? 0;

                return _buildModuleCard(
                  icon: Icons.card_giftcard_rounded,
                  title: 'Cấu Hình Đổi Điểm',
                  description: 'Thiết lập danh mục phần thưởng, quà tặng đổi điểm cho các lớp',
                  badgeText: rewardCount > 0 ? '$rewardCount phần thưởng' : 'Cấu hình',
                  badgeColor: const Color(0xFFC2410C),
                  onTap: () {
                    setState(
                      () => _currentTabIndex = 4,
                    ); // Chuyển sang Tab 4: Đổi Điểm
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleCard({
    required IconData icon,
    required String title,
    required String description,
    required String badgeText,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: badgeColor.withValues(alpha: 0.12),
                child: Icon(icon, color: badgeColor, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(
                            badgeText,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: badgeColor,
                          side: BorderSide.none,
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddUserDialog(BuildContext context) {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final classCtrl = TextEditingController();
    UserRole selectedRole = UserRole.teacher;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Thêm Tài Khoản Mới'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email đăng nhập',
                    hintText: 'vidu@nth.com',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu ban đầu (tối thiểu 6 ký tự)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Họ và tên',
                    hintText: 'Thầy/Cô Nguyễn Văn A',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<UserRole>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Vai trò (Role)',
                  ),
                  items: UserRole.values.map((r) {
                    return DropdownMenuItem<UserRole>(
                      value: r,
                      child: Text(r.label),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedRole = val);
                    }
                  },
                ),
                if (selectedRole == UserRole.teacher) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: classCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Lớp phụ trách',
                      hintText: 'Ví dụ: 6A1',
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: isLoading
                  ? null
                  : () async {
                      final email = emailCtrl.text.trim();
                      final pass = passCtrl.text.trim();
                      final name = nameCtrl.text.trim();

                      if (email.isEmpty || pass.length < 6 || name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Vui lòng điền đủ thông tin và mật khẩu >= 6 ký tự!',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isLoading = true);
                      try {
                        await _adminUserService.createUser(
                          email: email,
                          password: pass,
                          fullName: name,
                          role: selectedRole,
                          assignedClass: classCtrl.text.trim(),
                        );
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Đã tạo tài khoản $email thành công!',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Lỗi: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        setDialogState(() => isLoading = false);
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Tạo Tài Khoản'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddClassDialog(BuildContext context) {
    int selectedGrade = 6;
    int selectedClassNum = 1;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final className = '${selectedGrade}A$selectedClassNum';
          final email = '${selectedGrade}a$selectedClassNum@nth.com';

          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            title: const Row(
              children: [
                Icon(Icons.add_home_work_rounded, color: AppColors.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Thêm Lớp Học Mới',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Cú pháp lớp: Khối + A + Số lớp',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Bộ chọn chuẩn hóa: Khối + 'A' + Số lớp (Không cho nhập tự do)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Chọn Khối (6, 7, 8, 9)
                      Expanded(
                        flex: 5,
                        child: DropdownButtonFormField<int>(
                          isExpanded: true,
                          initialValue: selectedGrade,
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'Khối',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                          ),
                          items: [6, 7, 8, 9].map((g) {
                            return DropdownMenuItem<int>(
                              value: g,
                              child: Text(
                                'Khối $g',
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedGrade = val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Ký tự cố định 'A'
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'A',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Chọn Số thứ tự lớp (1 -> 20)
                      Expanded(
                        flex: 5,
                        child: DropdownButtonFormField<int>(
                          isExpanded: true,
                          initialValue: selectedClassNum,
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'Số lớp',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                          ),
                          items: List.generate(20, (i) => i + 1).map((n) {
                            return DropdownMenuItem<int>(
                              value: n,
                              child: Text(
                                'Lớp $n',
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedClassNum = val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Khung xem trước thông tin lớp học và tài khoản tự động sinh
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.verified_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Lớp sẽ tạo: $className',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        Text(
                          '• Tài khoản: $email',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '• Mật khẩu: $email',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Hủy'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                onPressed: isLoading
                    ? null
                    : () async {
                        setDialogState(() => isLoading = true);
                        try {
                          await _adminClassService.createClass(
                            className: className,
                          );

                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Đã tạo lớp $className và cấp tài khoản $email thành công!',
                                ),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('$e'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        } finally {
                          setDialogState(() => isLoading = false);
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Tạo Lớp Học'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddPointRuleDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    String selectedUnit = 'Số lượng';
    final unitQtyCtrl = TextEditingController(text: '1');
    final pointsCtrl = TextEditingController(text: '1');
    final descCtrl = TextEditingController();
    String selectedIcon = 'bottle';
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Thêm Thể Loại Tích Điểm',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Tên thể loại (TỰ VIẾT)
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tên thể loại *',
                    hintText: 'Ví dụ: Vỏ chai nhựa, Pin con thỏ...',
                    prefixIcon: Icon(Icons.edit_note_rounded),
                  ),
                  onChanged: (val) {
                    final lower = val.toLowerCase();
                    if (lower.contains('pin') && selectedIcon != 'battery') {
                      setDialogState(() => selectedIcon = 'battery');
                    } else if (lower.contains('lon') && selectedIcon != 'can') {
                      setDialogState(() => selectedIcon = 'can');
                    } else if ((lower.contains('giay') ||
                            lower.contains('giấy') ||
                            lower.contains('sách') ||
                            lower.contains('báo')) &&
                        selectedIcon != 'paper') {
                      setDialogState(() => selectedIcon = 'paper');
                    } else if ((lower.contains('carton') ||
                            lower.contains('thung') ||
                            lower.contains('thùng') ||
                            lower.contains('hộp')) &&
                        selectedIcon != 'box') {
                      setDialogState(() => selectedIcon = 'box');
                    } else if ((lower.contains('chai') ||
                            lower.contains('lo') ||
                            lower.contains('lọ')) &&
                        selectedIcon != 'bottle') {
                      setDialogState(() => selectedIcon = 'bottle');
                    }
                  },
                ),
                const SizedBox(height: 14),

                // 2. Đơn vị tính (QUÁN TRIỆT - CHỈ CHỌN SỐ LƯỢNG HOẶC KG)
                const Text(
                  'Đơn vị tính (bắt buộc):',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        showCheckmark: false,
                        label: const Center(child: Text('Số lượng')),
                        selected: selectedUnit == 'Số lượng',
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: selectedUnit == 'Số lượng'
                              ? Colors.white
                              : AppColors.textPrimary,
                          fontWeight: selectedUnit == 'Số lượng'
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        onSelected: (_) =>
                            setDialogState(() => selectedUnit = 'Số lượng'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        showCheckmark: false,
                        label: const Center(child: Text('Kg')),
                        selected: selectedUnit == 'Kg',
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: selectedUnit == 'Kg'
                              ? Colors.white
                              : AppColors.textPrimary,
                          fontWeight: selectedUnit == 'Kg'
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        onSelected: (_) =>
                            setDialogState(() => selectedUnit = 'Kg'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 3. Biểu tượng phế liệu (Chai, Lon, Giấy, Carton, Pin)
                const Text(
                  'Biểu tượng phế liệu:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children:
                      [
                        ('bottle', Icons.local_drink_rounded),
                        ('can', Icons.recycling_rounded),
                        ('paper', Icons.newspaper_rounded),
                        ('box', Icons.inventory_2_rounded),
                        ('battery', Icons.battery_charging_full_rounded),
                        ('pen', Icons.edit_rounded),
                      ].map((item) {
                        final key = item.$1;
                        final icon = item.$2;
                        final isSelected = selectedIcon == key;

                        return InkWell(
                          onTap: () => setDialogState(() => selectedIcon = key),
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.border,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Icon(
                              icon,
                              size: 22,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        );
                      }).toList(),
                ),
                const SizedBox(height: 14),

                // 4. Cấu hình tỷ lệ tích điểm
                const Text(
                  'Tỷ lệ quy đổi điểm *:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Đầu 1: Số lượng đơn vị thu gom
                    Expanded(
                      flex: 5,
                      child: TextField(
                        controller: unitQtyCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: InputDecoration(
                          labelText: 'Cứ mỗi',
                          hintText: '1',
                          suffixText: selectedUnit,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    // Đầu 2: Số điểm nhận được tương ứng
                    Expanded(
                      flex: 5,
                      child: TextField(
                        controller: pointsCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Đổi được',
                          hintText: '1',
                          suffixText: 'điểm',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Khung xem trước quy ước
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Quy ước: Cứ ${(int.tryParse(unitQtyCtrl.text.trim()) ?? 0) > 0 ? unitQtyCtrl.text.trim() : '1'} $selectedUnit = ${(int.tryParse(pointsCtrl.text.trim()) ?? 0) > 0 ? pointsCtrl.text.trim() : '1'} điểm',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 5. Mô tả quy đổi
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả quy đổi (Tùy chọn)',
                    hintText: 'Ghi chú quy cách thu gom, tính điểm...',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: isLoading
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      final unitQty =
                          int.tryParse(unitQtyCtrl.text.trim()) ?? 0;
                      final points =
                          int.tryParse(pointsCtrl.text.trim()) ?? 0;

                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Vui lòng nhập tên thể loại!'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }

                      if (unitQty <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Vui lòng nhập số lượng đơn vị quy ước > 0!',
                            ),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }

                      if (points <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Vui lòng nhập số điểm thưởng > 0!'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isLoading = true);
                      final user = FirebaseAuth.instance.currentUser;
                      try {
                        await _pointRuleService.createPointRule(
                          name: name,
                          unit: selectedUnit,
                          unitQuantity: unitQty,
                          points: points,
                          description: descCtrl.text.trim(),
                          iconName: selectedIcon,
                          changedByEmail: user?.email ?? 'admin@nth.com',
                          changedByUid: user?.uid ?? '',
                        );

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Đã thêm thể loại "$name" ($unitQty $selectedUnit = $points điểm) thành công!',
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
                        setDialogState(() => isLoading = false);
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Thêm Thể Loại'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddRewardDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'Cái');
    final pointsCtrl = TextEditingController(text: '10');
    final descCtrl = TextEditingController();
    String selectedIcon = 'gift';
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.card_giftcard_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Thêm Quà Tặng Đổi Điểm',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tên quà tặng / phần thưởng *',
                    hintText: 'Ví dụ: Chậu cây xanh, Tập vở viết...',
                    prefixIcon: Icon(Icons.card_giftcard_rounded),
                  ),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: unitCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Đơn vị tính *',
                    hintText: 'Ví dụ: Cái, Cuốn, Chậu, Bộ, Suất...',
                    prefixIcon: Icon(Icons.category_rounded),
                  ),
                ),
                const SizedBox(height: 14),

                const Text(
                  'Biểu tượng quà tặng:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ('gift', Icons.card_giftcard_rounded),
                    ('plant', Icons.yard_rounded),
                    ('book', Icons.menu_book_rounded),
                    ('pen', Icons.edit_rounded),
                    ('cup', Icons.emoji_events_rounded),
                    ('star', Icons.stars_rounded),
                    ('bottle', Icons.water_drop_rounded),
                  ].map((item) {
                    final key = item.$1;
                    final icon = item.$2;
                    final isSelected = selectedIcon == key;

                    return InkWell(
                      onTap: () => setDialogState(() => selectedIcon = key),
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.border,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Icon(
                          icon,
                          size: 22,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: pointsCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Số điểm cần để đổi 1 đơn vị *',
                    hintText: 'Ví dụ: 10, 20, 30...',
                    prefixIcon: Icon(Icons.stars_rounded),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả phần thưởng (Tùy chọn)',
                    hintText: 'Quy cách quà tặng, tiêu chuẩn nhận...',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: isLoading
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      final unit = unitCtrl.text.trim();
                      final points = int.tryParse(pointsCtrl.text.trim()) ?? 0;

                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Vui lòng nhập tên quà tặng!'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }

                      if (unit.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Vui lòng nhập đơn vị tính!'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }

                      if (points <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Vui lòng nhập số điểm đổi > 0!'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isLoading = true);
                      final user = FirebaseAuth.instance.currentUser;
                      try {
                        await _rewardService.createRewardRule(
                          name: name,
                          unit: unit,
                          pointsCost: points,
                          description: descCtrl.text.trim(),
                          iconName: selectedIcon,
                          changedByEmail: user?.email ?? 'admin@nth.com',
                          changedByUid: user?.uid ?? 'admin',
                        );

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Đã thêm quà tặng "$name" ($points điểm/$unit) thành công!',
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
                        setDialogState(() => isLoading = false);
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Thêm Quà Tặng'),
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildIconChip(
    String iconKey,
    String label,
    IconData iconData,
    String currentSelected,
    void Function(String) onSelect,
  ) {
    return const SizedBox.shrink();
  }
}
