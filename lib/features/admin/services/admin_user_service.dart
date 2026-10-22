import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../../../../core/constants/user_role.dart';
import '../../../../firebase_options.dart';

class AdminUserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Tạo tài khoản mới trực tiếp qua Firebase REST API
  /// (Đảm bảo KHÔNG làm mất phiên đăng nhập của Admin trên thiết bị)
  Future<void> createUser({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    String? assignedClass,
  }) async {
    final apiKey = DefaultFirebaseOptions.currentPlatform.apiKey;
    final authUrl = Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey');

    final response = await http.post(
      authUrl,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
        'returnSecureToken': false,
      }),
    );

    final resData = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      final msg = resData['error']?['message'] ?? 'Tạo tài khoản thất bại';
      if (msg.toString().contains('EMAIL_EXISTS')) {
        throw Exception('Email này đã tồn tại trên hệ thống!');
      }
      throw Exception(msg);
    }

    final newUid = resData['localId'] as String;

    // Lưu vào Cloud Firestore
    await _firestore.collection('users').doc(newUid).set({
      'uid': newUid,
      'email': email.trim(),
      'fullName': fullName.trim(),
      'role': role.code,
      'assignedClass': (role == UserRole.teacher && assignedClass != null)
          ? assignedClass.trim()
          : '',
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Cập nhật thông tin tài khoản
  Future<void> updateUser({
    required String uid,
    required String fullName,
    required UserRole role,
    String? assignedClass,
  }) async {
    await _firestore.collection('users').doc(uid).update({
      'fullName': fullName.trim(),
      'role': role.code,
      'assignedClass': (role == UserRole.teacher && assignedClass != null)
          ? assignedClass.trim()
          : '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Khóa hoặc Mở khóa tài khoản (Toggle isActive)
  Future<void> toggleUserLock({
    required String uid,
    required bool currentIsActive,
  }) async {
    await _firestore.collection('users').doc(uid).update({
      'isActive': !currentIsActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Xóa tài khoản khỏi Firestore
  Future<void> deleteUser(String uid) async {
    await _firestore.collection('users').doc(uid).delete();
  }
}
