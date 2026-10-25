import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/user_role.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../admin/presentation/screens/admin_dashboard_screen.dart';
import '../../../lead_teacher/presentation/screens/lead_teacher_dashboard_screen.dart';
import '../../../teacher/presentation/screens/teacher_dashboard_screen.dart';
import '../../services/auth_service.dart';
import '../screens/login_screen.dart';
import '../screens/web_landing_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _authService = AuthService();
  bool _checkedWebVisit = false;
  bool _showLanding = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _checkWebLanding();
    } else {
      _checkedWebVisit = true;
    }
  }

  Future<void> _checkWebLanding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasVisited = prefs.getBool('has_visited_web') ?? false;
      if (mounted) {
        setState(() {
          _showLanding = !hasVisited;
          _checkedWebVisit = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _showLanding = false;
          _checkedWebVisit = true;
        });
      }
    }
  }

  void _continueToLogin() {
    setState(() {
      _showLanding = false;
    });
  }

  void _openLanding() {
    setState(() {
      _showLanding = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (!authSnapshot.hasData || authSnapshot.data == null) {
          if (kIsWeb) {
            if (!_checkedWebVisit) {
              return const Scaffold(
                backgroundColor: AppColors.background,
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (_showLanding) {
              return WebLandingScreen(
                onContinueToLogin: _continueToLogin,
              );
            }

            return LoginScreen(
              onOpenLanding: _openLanding,
            );
          }

          return const LoginScreen();
        }

        final user = authSnapshot.data!;

        // Lắng nghe tài liệu người dùng thời gian thực để kiểm tra role và isActive
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, docSnapshot) {
            if (docSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Đang kiểm tra quyền truy cập...',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            }

            final data = docSnapshot.data?.data() as Map<String, dynamic>?;
            final isActive = data?['isActive'] as bool? ?? true;

            // NẾU TÀI KHOẢN BỊ KHÓA -> CHẶN NGAY LẬP TỨC
            if (!isActive) {
              return Scaffold(
                body: SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: const BoxDecoration(
                              color: AppColors.errorLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.lock_person_rounded,
                              size: 72,
                              color: AppColors.error,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Tài Khoản Đã Bị Tạm Khóa',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.error,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tài khoản (${user.email}) hiện đang bị tạm khóa bởi Ban Quản Trị hệ thống. Vui lòng liên hệ Quản trị viên để được hỗ trợ mở khóa.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 32),
                          OutlinedButton.icon(
                            onPressed: () => _authService.signOut(),
                            icon: const Icon(Icons.logout),
                            label: const Text('Đăng Xuất'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            final role = UserRole.fromString(data?['role']);

            switch (role) {
              case UserRole.admin:
                return const AdminDashboardScreen();
              case UserRole.leadTeacher:
                return const LeadTeacherDashboardScreen();
              case UserRole.teacher:
                return const TeacherDashboardScreen();
            }
          },
        );
      },
    );
  }
}
