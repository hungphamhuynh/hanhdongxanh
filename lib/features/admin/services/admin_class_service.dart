import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../../../../core/constants/user_role.dart';
import '../../../../firebase_options.dart';

class AdminClassService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream danh sách tất cả các lớp học realtime
  Stream<QuerySnapshot> getClassesStream() {
    return _firestore.collection('classes').snapshots();
  }

  /// Thêm lớp học mới đồng thời tự động tạo tài khoản Giáo viên tương ứng
  Future<void> createClassWithTeacher({
    required String className,
    required String teacherEmail,
    required String password,
    required String teacherName,
  }) async {
    final cleanClassName = className.trim().toUpperCase();
    final cleanEmail = teacherEmail.trim().toLowerCase();
    final cleanTeacherName =
        teacherName.trim().isEmpty ? 'GV $cleanClassName' : teacherName.trim();

    // 1. Kiểm tra lớp học đã tồn tại trong Firestore chưa
    final classDoc =
        await _firestore.collection('classes').doc(cleanClassName).get();
    if (classDoc.exists) {
      throw Exception('Lớp $cleanClassName đã tồn tại trên hệ thống!');
    }

    // 2. Tạo tài khoản Giáo viên qua Firebase Auth REST API (giữ nguyên phiên đăng nhập của Admin)
    final apiKey = DefaultFirebaseOptions.currentPlatform.apiKey;
    final authUrl = Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey');

    final response = await http.post(
      authUrl,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': cleanEmail,
        'password': password,
        'returnSecureToken': false,
      }),
    );

    final resData = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      final msg =
          resData['error']?['message'] ?? 'Tạo tài khoản giáo viên thất bại!';
      if (msg.toString().contains('EMAIL_EXISTS')) {
        throw Exception('Email $cleanEmail đã được sử dụng bởi tài khoản khác!');
      }
      throw Exception(msg);
    }

    final newTeacherUid = resData['localId'] as String;

    final batch = _firestore.batch();

    // 3. Tạo Document User cho Giáo viên
    final userRef = _firestore.collection('users').doc(newTeacherUid);
    batch.set(userRef, {
      'uid': newTeacherUid,
      'email': cleanEmail,
      'fullName': cleanTeacherName,
      'role': UserRole.teacher.code,
      'assignedClass': cleanClassName,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 4. Tạo Document trong collection classes/{className}
    final classRef = _firestore.collection('classes').doc(cleanClassName);
    batch.set(classRef, {
      'className': cleanClassName,
      'teacherUid': newTeacherUid,
      'teacherEmail': cleanEmail,
      'teacherName': cleanTeacherName,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Xóa lớp học và xóa tài khoản Giáo viên phụ trách liên quan
  Future<void> deleteClass(String className) async {
    final cleanClassName = className.trim().toUpperCase();
    final classDoc =
        await _firestore.collection('classes').doc(cleanClassName).get();

    if (!classDoc.exists) {
      throw Exception('Lớp học không tồn tại!');
    }

    final data = classDoc.data();
    final teacherUid = data?['teacherUid'] as String?;

    final batch = _firestore.batch();

    // Xóa document lớp học
    batch.delete(_firestore.collection('classes').doc(cleanClassName));

    // Nếu có tài khoản giáo viên phụ trách, xóa tài khoản đó trong Firestore
    if (teacherUid != null && teacherUid.isNotEmpty) {
      batch.delete(_firestore.collection('users').doc(teacherUid));
    }

    await batch.commit();
  }
}
