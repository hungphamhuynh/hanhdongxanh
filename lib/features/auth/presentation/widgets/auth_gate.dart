import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/user_role.dart';
import '../../../admin/presentation/screens/admin_dashboard_screen.dart';
import '../../../lead_teacher/presentation/screens/lead_teacher_dashboard_screen.dart';
import '../../../teacher/presentation/screens/teacher_dashboard_screen.dart';
import '../../services/auth_service.dart';
import '../screens/login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (!authSnapshot.hasData || authSnapshot.data == null) {
          return const LoginScreen();
        }

        final user = authSnapshot.data!;

        return StreamBuilder<UserRole>(
          stream: authService.getUserRoleStream(user.uid),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Checking permissions...',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            }

            final role = roleSnapshot.data ?? UserRole.teacher;

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
