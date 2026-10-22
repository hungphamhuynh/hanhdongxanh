import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/user_role.dart';
import '../../../../core/network/network_service.dart';
import '../../../../core/utils/firebase_error_mapper.dart';
import '../../../auth/services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _user = FirebaseAuth.instance.currentUser;
  final _authService = AuthService();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isEditingInfo = false;
  bool _isSavingInfo = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _updateProfileInfo() async {
    final hasNet = await NetworkService.isConnected();
    if (!hasNet) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa kết nối mạng! Không thể cập nhật thông tin.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Họ và tên không được để trống!')),
      );
      return;
    }

    setState(() => _isSavingInfo = true);
    try {
      if (_user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_user.uid)
            .update({
          'fullName': newName,
          'phoneNumber': _phoneController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Cập nhật cả displayName trên Firebase Auth
        await _user.updateDisplayName(newName);
      }

      if (mounted) {
        setState(() => _isEditingInfo = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã cập nhật thông tin cá nhân thành công!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(FirebaseErrorMapper.getMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingInfo = false);
    }
  }

  void _showChangePasswordDialog() {
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.lock_reset_rounded, color: Colors.green),
              SizedBox(width: 8),
              Text('Đổi Mật Khẩu'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: newPassController,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu mới',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureNew ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setDialogState(() => obscureNew = !obscureNew);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPassController,
                  obscureText: obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Xác nhận mật khẩu mới',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirm
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setDialogState(() => obscureConfirm = !obscureConfirm);
                      },
                    ),
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
              style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
              onPressed: isLoading
                  ? null
                  : () async {
                      final newPass = newPassController.text;
                      final confirmPass = confirmPassController.text;

                      if (newPass.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Mật khẩu mới phải có tối thiểu 6 ký tự!'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (newPass != confirmPass) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Mật khẩu xác nhận không khớp!'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isLoading = true);
                      try {
                        await _user?.updatePassword(newPass);
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đổi mật khẩu thành công!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(FirebaseErrorMapper.getMessage(e)),
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
                  : const Text('Lưu Mật Khẩu'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const Scaffold(
        body: Center(child: Text('Chưa có thông tin người dùng')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông Tin Cá Nhân'),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(_user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final fullName = data['fullName'] ?? _user.displayName ?? 'Chưa đặt tên';
          final email = data['email'] ?? _user.email ?? '';
          final role = UserRole.fromString(data['role']);
          final assignedClass = data['assignedClass'] as String?;
          final phoneNumber = data['phoneNumber'] ?? '';

          if (!_isEditingInfo) {
            _nameController.text = fullName;
            _phoneController.text = phoneNumber;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Avatar & Tên & Role Badge
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 46,
                        backgroundColor: _getRoleColor(role).withOpacity(0.15),
                        child: Icon(
                          _getRoleIcon(role),
                          size: 48,
                          color: _getRoleColor(role),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        fullName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Chip(
                        label: Text(
                          role.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: _getRoleColor(role),
                        side: BorderSide.none,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Card Thông tin cá nhân
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Hồ sơ của bạn',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                _isEditingInfo ? Icons.close : Icons.edit,
                                size: 20,
                              ),
                              tooltip: _isEditingInfo ? 'Hủy sửa' : 'Chỉnh sửa',
                              onPressed: () {
                                setState(() {
                                  _isEditingInfo = !_isEditingInfo;
                                  if (!_isEditingInfo) {
                                    _nameController.text = fullName;
                                    _phoneController.text = phoneNumber;
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                        const Divider(),
                        const SizedBox(height: 8),

                        // Họ và tên
                        if (_isEditingInfo) ...[
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Họ và tên',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Số điện thoại',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                              ),
                              onPressed: _isSavingInfo ? null : _updateProfileInfo,
                              child: _isSavingInfo
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Lưu Thay Đổi'),
                            ),
                          ),
                        ] else ...[
                          _buildInfoRow(
                            icon: Icons.person_outline,
                            label: 'Họ và tên',
                            value: fullName,
                          ),
                          const SizedBox(height: 14),
                          _buildInfoRow(
                            icon: Icons.email_outlined,
                            label: 'Email (Cố định)',
                            value: email,
                          ),
                          const SizedBox(height: 14),
                          _buildInfoRow(
                            icon: Icons.phone_outlined,
                            label: 'Số điện thoại',
                            value: phoneNumber.isNotEmpty ? phoneNumber : 'Chưa cập nhật',
                          ),
                          if (assignedClass != null && assignedClass.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            _buildInfoRow(
                              icon: Icons.class_outlined,
                              label: 'Lớp phụ trách',
                              value: assignedClass,
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Card Bảo mật & Đổi mật khẩu
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade50,
                      child: const Icon(Icons.lock_outline, color: Colors.blue),
                    ),
                    title: const Text(
                      'Đổi Mật Khẩu',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Cập nhật mật khẩu mới cho tài khoản'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _showChangePasswordDialog,
                  ),
                ),
                const SizedBox(height: 18),

                // Nút Đăng xuất
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: Colors.red.shade50,
                      child: const Icon(Icons.logout, color: Colors.red),
                    ),
                    title: const Text(
                      'Đăng Xuất',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    subtitle: const Text('Thoát khỏi phiên đăng nhập hiện tại'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Xác nhận đăng xuất'),
                          content: const Text('Bạn có chắc chắn muốn đăng xuất không?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Hủy'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: Colors.red),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Đăng xuất'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await _authService.signOut();
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
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

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Icons.admin_panel_settings;
      case UserRole.leadTeacher:
        return Icons.campaign;
      case UserRole.teacher:
        return Icons.school;
    }
  }
}
