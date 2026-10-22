import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/user_role.dart';
import '../../services/admin_user_service.dart';

class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({super.key});

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  final _adminUserService = AdminUserService();
  final _currentUid = FirebaseAuth.instance.currentUser?.uid;

  String _searchQuery = '';
  UserRole? _selectedRoleFilter;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Chưa có tài khoản nào trên hệ thống.'));
        }

        final allUsers = snapshot.data!.docs;
        final totalCount = allUsers.length;
        final activeCount = allUsers.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return (data['isActive'] as bool? ?? true) == true;
        }).length;
        final lockedCount = totalCount - activeCount;

        final filteredUsers = allUsers.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final email = (data['email'] as String? ?? '').toLowerCase();
          final name = (data['fullName'] as String? ?? '').toLowerCase();
          final role = UserRole.fromString(data['role'] as String?);

          final matchesSearch = _searchQuery.isEmpty ||
              email.contains(_searchQuery.toLowerCase()) ||
              name.contains(_searchQuery.toLowerCase());

          final matchesRole =
              _selectedRoleFilter == null || role == _selectedRoleFilter;

          return matchesSearch && matchesRole;
        }).toList();

        return CustomScrollView(
          slivers: [
            // Thống kê nhanh
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        title: 'Tổng số',
                        count: '$totalCount',
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        title: 'Hoạt động',
                        count: '$activeCount',
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        title: 'Đã khóa',
                        count: '$lockedCount',
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Tìm kiếm
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Tìm theo email, họ tên...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                ),
              ),
            ),

            // Bộ lọc Role
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('Tất cả'),
                      selected: _selectedRoleFilter == null,
                      onSelected: (_) =>
                          setState(() => _selectedRoleFilter = null),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Admin'),
                      selected: _selectedRoleFilter == UserRole.admin,
                      onSelected: (_) =>
                          setState(() => _selectedRoleFilter = UserRole.admin),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Lead Teacher'),
                      selected: _selectedRoleFilter == UserRole.leadTeacher,
                      onSelected: (_) => setState(
                          () => _selectedRoleFilter = UserRole.leadTeacher),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Teacher'),
                      selected: _selectedRoleFilter == UserRole.teacher,
                      onSelected: (_) =>
                          setState(() => _selectedRoleFilter = UserRole.teacher),
                    ),
                  ],
                ),
              ),
            ),

            // Danh sách tài khoản
            if (filteredUsers.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: Text(
                      'Không tìm thấy tài khoản phù hợp.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final doc = filteredUsers[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final uid = doc.id;
                      final email = data['email'] ?? '';
                      final fullName = data['fullName'] ?? 'Chưa đặt tên';
                      final role = UserRole.fromString(data['role']);
                      final assignedClass = data['assignedClass'] as String?;
                      final isActive = data['isActive'] as bool? ?? true;
                      final isSelf = uid == _currentUid;

                      return Card(
                        elevation: 1,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: isActive
                                ? Colors.transparent
                                : Colors.red.shade200,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  fullName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isActive ? null : Colors.grey,
                                    decoration: isActive
                                        ? null
                                        : TextDecoration.lineThrough,
                                  ),
                                ),
                              ),
                              if (isSelf)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.indigo.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Bạn',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.indigo,
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
                                email,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Chip(
                                    label: Text(
                                      role.label,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    backgroundColor: _getRoleColor(role),
                                    side: BorderSide.none,
                                    padding: EdgeInsets.zero,
                                  ),
                                  if (assignedClass != null &&
                                      assignedClass.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Chip(
                                      label: Text(
                                        'Lớp $assignedClass',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      backgroundColor: Colors.grey.shade200,
                                      side: BorderSide.none,
                                      padding: EdgeInsets.zero,
                                    ),
                                  ],
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? Colors.green.shade50
                                          : Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isActive
                                            ? Colors.green.shade300
                                            : Colors.red.shade300,
                                      ),
                                    ),
                                    child: Text(
                                      isActive ? 'Hoạt động' : 'Đã khóa',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isActive
                                            ? Colors.green.shade800
                                            : Colors.red.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert),
                            tooltip: 'Tùy chọn',
                            onSelected: (action) {
                              switch (action) {
                                case 'edit':
                                  _showEditUserDialog(
                                    context: context,
                                    uid: uid,
                                    currentName: fullName,
                                    currentRole: role,
                                    currentClass: assignedClass ?? '',
                                  );
                                  break;
                                case 'lock':
                                  if (isSelf) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Không thể tự khóa tài khoản của chính mình!'),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                    return;
                                  }
                                  _confirmToggleLock(
                                    context: context,
                                    uid: uid,
                                    email: email,
                                    currentStatus: isActive,
                                  );
                                  break;
                                case 'delete':
                                  if (isSelf) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Không thể xóa tài khoản của chính mình!'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }
                                  _confirmDeleteUser(
                                    context: context,
                                    uid: uid,
                                    email: email,
                                  );
                                  break;
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined, size: 20),
                                    SizedBox(width: 10),
                                    Text('Chỉnh sửa'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'lock',
                                child: Row(
                                  children: [
                                    Icon(
                                      isActive
                                          ? Icons.lock_outline
                                          : Icons.lock_open_outlined,
                                      size: 20,
                                      color: isActive
                                          ? Colors.orange.shade800
                                          : Colors.green,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(isActive
                                        ? 'Khóa tài khoản'
                                        : 'Mở khóa tài khoản'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline,
                                        size: 20, color: Colors.red),
                                    SizedBox(width: 10),
                                    Text('Xóa tài khoản',
                                        style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: filteredUsers.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Colors.indigo;
      case UserRole.leadTeacher:
        return Colors.orange.shade800;
      case UserRole.teacher:
        return Colors.green.shade700;
    }
  }

  void _showEditUserDialog({
    required BuildContext context,
    required String uid,
    required String currentName,
    required UserRole currentRole,
    required String currentClass,
  }) {
    final nameCtrl = TextEditingController(text: currentName);
    final classCtrl = TextEditingController(text: currentClass);
    UserRole selectedRole = currentRole;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Chỉnh Sửa Tài Khoản'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Họ và tên'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<UserRole>(
                  value: selectedRole,
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
              onPressed: isLoading
                  ? null
                  : () async {
                      setDialogState(() => isLoading = true);
                      try {
                        await _adminUserService.updateUser(
                          uid: uid,
                          fullName: nameCtrl.text.trim(),
                          role: selectedRole,
                          assignedClass: classCtrl.text.trim(),
                        );
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã cập nhật tài khoản thành công!'),
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
              child: const Text('Lưu Thay Đổi'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmToggleLock({
    required BuildContext context,
    required String uid,
    required String email,
    required bool currentStatus,
  }) async {
    final actionName = currentStatus ? 'khóa' : 'mở khóa';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Xác nhận $actionName tài khoản'),
        content: Text(
          currentStatus
              ? 'Tài khoản ($email) sẽ bị khóa và không thể thao tác trên hệ thống.'
              : 'Bạn có chắc muốn mở khóa cho tài khoản ($email)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: currentStatus ? Colors.orange.shade800 : Colors.green,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Đồng ý $actionName'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _adminUserService.toggleUserLock(
        uid: uid,
        currentIsActive: currentStatus,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã $actionName tài khoản $email thành công!'),
            backgroundColor: currentStatus ? Colors.orange.shade800 : Colors.green,
          ),
        );
      }
    }
  }

  void _confirmDeleteUser({
    required BuildContext context,
    required String uid,
    required String email,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa tài khoản'),
        content: Text(
          'Hành động này sẽ xóa vĩnh viễn hồ sơ của ($email). Dữ liệu sau khi xóa không thể khôi phục!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa vĩnh viễn'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _adminUserService.deleteUser(uid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xóa tài khoản $email thành công!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
