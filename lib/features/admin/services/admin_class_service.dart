import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/user_role.dart';
import '../../../../firebase_options.dart';

class AdminClassService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream danh sách tất cả các lớp học realtime
  Stream<QuerySnapshot> getClassesStream() {
    return _firestore.collection('classes').snapshots();
  }

  /// Thêm lớp học mới: Tự động tạo tài khoản tương ứng `<ten_lop>@thcsnguyenthihuong.hcm.edu.vn`
  /// và liên kết chặt chẽ giữa classes/{className} và users/{uid}
  Future<void> createClass({
    required String className,
  }) async {
    final cleanClassName = className.trim().toUpperCase();

    // Kiểm tra cú pháp bắt buộc: Khối + A + Số lớp (Ví dụ: 6A1, 7A5, 8A9, 9A12)
    final classRegex = RegExp(r'^[6-9]A[1-9][0-9]?$');
    if (!classRegex.hasMatch(cleanClassName)) {
      throw Exception(
          'Tên lớp phải đúng cú pháp: Khối (6-9) + A + Số lớp (Ví dụ: 6A1, 7A5, 9A12)!');
    }

    final cleanLower = cleanClassName.toLowerCase();
    final email = '$cleanLower${AppConstants.schoolEmailSuffix}';
    final password = '$cleanLower${AppConstants.schoolEmailSuffix}';
    final fullName = 'Lớp $cleanClassName';

    // 1. Kiểm tra lớp học đã tồn tại trong Firestore chưa
    final classDoc =
        await _firestore.collection('classes').doc(cleanClassName).get();
    if (classDoc.exists) {
      throw Exception('Lớp $cleanClassName đã tồn tại trên hệ thống!');
    }

    // 2. Tạo tài khoản qua Firebase Auth REST API (giữ nguyên phiên đăng nhập của Admin)
    final apiKey = DefaultFirebaseOptions.currentPlatform.apiKey;
    final authUrl = Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey');

    final response = await http.post(
      authUrl,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'returnSecureToken': false,
      }),
    );

    final resData = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      final msg =
          resData['error']?['message'] ?? 'Tạo tài khoản lớp học thất bại!';
      if (msg.toString().contains('EMAIL_EXISTS')) {
        throw Exception('Tài khoản email $email đã tồn tại trên hệ thống!');
      }
      throw Exception(msg);
    }

    final newUid = resData['localId'] as String;

    final batch = _firestore.batch();

    // 3. Tạo Document User cho Lớp học
    final userRef = _firestore.collection('users').doc(newUid);
    batch.set(userRef, {
      'uid': newUid,
      'email': email,
      'fullName': fullName,
      'role': UserRole.teacher.code,
      'assignedClass': cleanClassName,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 4. Tạo Document trong collection classes/{className}
    final classRef = _firestore.collection('classes').doc(cleanClassName);
    batch.set(classRef, {
      'className': cleanClassName,
      'teacherUid': newUid,
      'teacherEmail': email,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Xóa lớp học và xóa tài khoản phụ trách liên quan
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

    // Nếu có tài khoản phụ trách, xóa tài khoản đó trong Firestore
    if (teacherUid != null && teacherUid.isNotEmpty) {
      batch.delete(_firestore.collection('users').doc(teacherUid));
    }

    await batch.commit();
  }
}
