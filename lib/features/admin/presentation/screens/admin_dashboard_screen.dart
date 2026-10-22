import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/user_role.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../../auth/services/auth_service.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../services/admin_class_service.dart';
import '../../services/admin_user_service.dart';
import '../widgets/admin_classes_tab.dart';
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

  String get _appBarTitle {
    switch (_currentTabIndex) {
      case 1:
        return 'Quản Lý Tài Khoản';
      case 2:
        return 'Quản Lý Lớp Học';
      case 0:
      default:
        return 'Admin Overview';
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
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle),
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
            tooltip: 'Sign Out',
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTabIndex,
        onDestinationSelected: (index) => setState(() => _currentTabIndex = index),
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
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(context),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          // TAB 0: TỔNG QUAN HỆ THỐNG (ADMIN HUB)
          _buildOverviewTab(context),

          // TAB 1: QUẢN LÝ TÀI KHOẢN CHUYÊN BIỆT
          const AdminUsersTab(),

          // TAB 2: QUẢN LÝ LỚP HỌC & GIÁO VIÊN PHỤ TRÁCH
          const AdminClassesTab(),
        ],
      ),
    );
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
                    Icon(Icons.eco_rounded, color: AppColors.primaryContainer, size: 16),
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
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              final count = snapshot.data?.docs.length ?? 0;

              return _buildModuleCard(
                icon: Icons.manage_accounts_rounded,
                title: 'Quản Lý Tài Khoản',
                description: 'Cấp phát, chỉnh sửa, khóa và phân quyền người dùng',
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
            stream: FirebaseFirestore.instance.collection('classes').snapshots(),
            builder: (context, snapshot) {
              final classCount = snapshot.data?.docs.length ?? 0;

              return _buildModuleCard(
                icon: Icons.class_outlined,
                title: 'Quản Lý Lớp Học',
                description: 'Danh sách 36 lớp học, giáo viên phụ trách',
                badgeText: '$classCount lớp học',
                badgeColor: AppColors.secondary,
                onTap: () {
                  setState(() => _currentTabIndex = 2); // Chuyển sang Tab 2: Lớp Học
                },
              );
            },
          ),
          const SizedBox(height: 12),

          // Module 3: Cấu hình quy định điểm
          _buildModuleCard(
            icon: Icons.stars_rounded,
            title: 'Cấu Hình Điểm Thưởng',
            description: 'Thiết lập danh mục hành động xanh và mức điểm thưởng',
            badgeText: 'Sắp tới',
            badgeColor: AppColors.roleLeadTeacher,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Phân hệ Cấu hình Điểm thưởng sẽ triển khai tiếp theo!')),
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
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                  decoration: const InputDecoration(labelText: 'Vai trò (Role)'),
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
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary),
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
                                'Vui lòng điền đủ thông tin và mật khẩu >= 6 ký tự!'),
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
                              content: Text('Đã tạo tài khoản $email thành công!'),
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
                          strokeWidth: 2, color: Colors.white),
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
            title: const Row(
              children: [
                Icon(Icons.add_home_work_rounded, color: AppColors.primary),
                SizedBox(width: 8),
                Text('Thêm Lớp Học Mới'),
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
                    children: [
                      // Chọn Khối (6, 7, 8, 9)
                      Expanded(
                        flex: 5,
                        child: DropdownButtonFormField<int>(
                          initialValue: selectedGrade,
                          decoration: const InputDecoration(
                            labelText: 'Khối',
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                          ),
                          items: [6, 7, 8, 9].map((g) {
                            return DropdownMenuItem<int>(
                              value: g,
                              child: Text('Khối $g'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedGrade = val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Ký tự cố định 'A'
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.primaryMint,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              width: 1.5),
                        ),
                        child: const Text(
                          'A',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Chọn Số thứ tự lớp (1 -> 20)
                      Expanded(
                        flex: 5,
                        child: DropdownButtonFormField<int>(
                          initialValue: selectedClassNum,
                          decoration: const InputDecoration(
                            labelText: 'Số lớp',
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                          ),
                          items: List.generate(20, (i) => i + 1).map((n) {
                            return DropdownMenuItem<int>(
                              value: n,
                              child: Text('Lớp $n'),
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
                            const Icon(Icons.verified_rounded,
                                size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Lớp sẽ tạo: $className',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
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
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
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
}
