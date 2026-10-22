import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum UserRole {
  admin,
  leadTeacher,
  teacher;

  static UserRole fromString(String? role) {
    switch (role) {
      case 'admin':
        return UserRole.admin;
      case 'leadTeacher':
        return UserRole.leadTeacher;
      case 'teacher':
      default:
        return UserRole.teacher;
    }
  }

  String get code {
    switch (this) {
      case UserRole.admin:
        return 'admin';
      case UserRole.leadTeacher:
        return 'leadTeacher';
      case UserRole.teacher:
        return 'teacher';
    }
  }

  String get label {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.leadTeacher:
        return 'Lead Teacher';
      case UserRole.teacher:
        return 'Teacher';
    }
  }

  Color get color {
    switch (this) {
      case UserRole.admin:
        return AppColors.roleAdmin;
      case UserRole.leadTeacher:
        return AppColors.roleLeadTeacher;
      case UserRole.teacher:
        return AppColors.roleTeacher;
    }
  }

  Color get lightColor {
    switch (this) {
      case UserRole.admin:
        return AppColors.roleAdminLight;
      case UserRole.leadTeacher:
        return AppColors.roleLeadTeacherLight;
      case UserRole.teacher:
        return AppColors.roleTeacherLight;
    }
  }
}
