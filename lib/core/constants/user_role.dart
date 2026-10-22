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
}
