// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

/// Khóa API và Project ID của Firebase (từ firebase_options.dart)
const String apiKey = 'AIzaSyAQL8w6JQ7PdvKqAT48vf_smde-mNxnGAw';
const String projectId = 'tichdiemnth';
const String schoolDomain = 'thcsnguyenthihuong.hcm.edu.vn';

/// Mốc thời gian khởi tạo bắt buộc: 27/08/2026 (07:00:00 GMT+7 => 2026-08-27T00:00:00.000Z)
final DateTime targetCreationDate = DateTime.utc(2026, 8, 27, 0, 0, 0);
final String targetCreationIso = targetCreationDate.toIso8601String();

void main(List<String> args) async {
  print('==================================================================');
  print('   KHỞI TẠO TÀI KHOẢN VÀ DỮ LIỆU LỚP HỌC HÀNH ĐỘNG XANH - THCS NTH  ');
  print('   MỐC THỜI GIAN KHỞI TẠO: 27/08/2026                             ');
  print('==================================================================\n');

  final client = HttpClient();

  // 1. Danh sách các lớp học cần tạo theo yêu cầu:
  // - Khối 6: 6A1 -> 6A7 (7 lớp)
  // - Khối 7: 7A1 -> 7A7 (7 lớp)
  // - Khối 8: 8A1 -> 8A10 (10 lớp)
  // - Khối 9: 9A1 -> 9A12 (12 lớp)
  final List<String> classNames = [];

  for (int i = 1; i <= 7; i++) {
    classNames.add('6A$i');
  }
  for (int i = 1; i <= 7; i++) {
    classNames.add('7A$i');
  }
  for (int i = 1; i <= 10; i++) {
    classNames.add('8A$i');
  }
  for (int i = 1; i <= 12; i++) {
    classNames.add('9A$i');
  }

  print('📋 Danh sách lớp học chuẩn bị tạo (${classNames.length} lớp):');
  print('   • Khối 6: 6A1 -> 6A7 (7 lớp)');
  print('   • Khối 7: 7A1 -> 7A7 (7 lớp)');
  print('   • Khối 8: 8A1 -> 8A10 (10 lớp)');
  print('   • Khối 9: 9A1 -> 9A12 (12 lớp)');
  print('📋 Tài khoản điều hành:');
  print('   • Quản trị viên: admin@$schoolDomain');
  print('   • Tổng phụ trách: tongphutrach@$schoolDomain');
  print('📅 Ngày khởi tạo áp dụng: 27/08/2026 ($targetCreationIso)\n');

  // BƯỚC 1: Khởi tạo/Đăng nhập tài khoản Quản Trị Viên (Admin) để lấy Token quyền ghi Firestore
  print('--- [BƯỚC 1/4] Khởi tạo & Xác thực tài khoản Admin ---');
  final adminEmail = 'admin@$schoolDomain';
  final adminPass = adminEmail;

  final adminAuth = await _getOrCreateAuthUser(client, adminEmail, adminPass);
  if (adminAuth == null) {
    print('❌ Lỗi nghiêm trọng: Không thể tạo hoặc đăng nhập tài khoản Admin!');
    client.close();
    exit(1);
  }

  final adminUid = adminAuth['uid']!;
  final adminToken = adminAuth['token']!;
  print('  ✓ Tài khoản Admin: $adminEmail (UID: $adminUid)');

  // Lưu document của Admin vào users/{adminUid} với createdAt = 27/08/2026
  await _patchFirestoreDocument(
    client: client,
    idToken: adminToken,
    collection: 'users',
    docId: adminUid,
    fields: {
      'uid': {'stringValue': adminUid},
      'email': {'stringValue': adminEmail},
      'fullName': {'stringValue': 'Quản Trị Viên'},
      'role': {'stringValue': 'admin'},
      'assignedClass': {'stringValue': ''},
      'isActive': {'booleanValue': true},
      'createdAt': {'timestampValue': targetCreationIso},
    },
  );
  print('  ✓ Đã lưu document admin vào Firestore: users/$adminUid (Ngày tạo: 27/08/2026)\n');

  // BƯỚC 2: Khởi tạo tài khoản Tổng Phụ Trách (Lead Teacher)
  print('--- [BƯỚC 2/4] Khởi tạo tài khoản Tổng Phụ Trách ---');
  final leadEmail = 'tongphutrach@$schoolDomain';
  final leadPass = leadEmail;

  final leadAuth = await _getOrCreateAuthUser(client, leadEmail, leadPass);
  if (leadAuth != null) {
    final leadUid = leadAuth['uid']!;
    await _patchFirestoreDocument(
      client: client,
      idToken: adminToken,
      collection: 'users',
      docId: leadUid,
      fields: {
        'uid': {'stringValue': leadUid},
        'email': {'stringValue': leadEmail},
        'fullName': {'stringValue': 'Tổng Phụ Trách'},
        'role': {'stringValue': 'leadTeacher'},
        'assignedClass': {'stringValue': ''},
        'isActive': {'booleanValue': true},
        'createdAt': {'timestampValue': targetCreationIso},
      },
    );
    print('  ✓ Tạo thành công: $leadEmail (UID: $leadUid - Ngày tạo: 27/08/2026)');
  } else {
    print('  ⚠️ Không thể tạo tài khoản Tổng Phụ Trách: $leadEmail');
  }
  print('');

  // BƯỚC 3: Khởi tạo 36 Tài khoản lớp học và 36 Document Classes
  print('--- [BƯỚC 3/4] Khởi tạo 36 Tài khoản & Dữ liệu Lớp học (Ngày tạo: 27/08/2026) ---');
  int successClassCount = 0;

  for (final className in classNames) {
    final lowerName = className.toLowerCase();
    final classEmail = '$lowerName@$schoolDomain';
    final classPassword = classEmail;
    final fullName = 'Lớp $className';

    // 1. Tạo hoặc lấy tài khoản Auth
    final userAuth =
        await _getOrCreateAuthUser(client, classEmail, classPassword);
    if (userAuth == null) {
      print('  ❌ Lỗi tạo Auth cho $classEmail');
      continue;
    }

    final classUid = userAuth['uid']!;

    // 2. Lưu document users/{classUid}
    final userDocOk = await _patchFirestoreDocument(
      client: client,
      idToken: adminToken,
      collection: 'users',
      docId: classUid,
      fields: {
        'uid': {'stringValue': classUid},
        'email': {'stringValue': classEmail},
        'fullName': {'stringValue': fullName},
        'role': {'stringValue': 'teacher'},
        'assignedClass': {'stringValue': className},
        'isActive': {'booleanValue': true},
        'createdAt': {'timestampValue': targetCreationIso},
      },
    );

    // 3. Lưu document classes/{className}
    final classDocOk = await _patchFirestoreDocument(
      client: client,
      idToken: adminToken,
      collection: 'classes',
      docId: className,
      fields: {
        'className': {'stringValue': className},
        'teacherUid': {'stringValue': classUid},
        'teacherEmail': {'stringValue': classEmail},
        'totalPoints': {'integerValue': '0'},
        'totalPointsRedeemed': {'integerValue': '0'},
        'createdAt': {'timestampValue': targetCreationIso},
      },
    );

    if (userDocOk && classDocOk) {
      successClassCount++;
      stdout.write('  ✓ [$successClassCount/${classNames.length}] Lớp $className ($classEmail)\n');
    } else {
      print('  ⚠️ Cảnh báo ghi Firestore cho lớp $className');
    }
  }

  // BƯỚC 4: Khởi tạo cấu hình năm học mặc định system_settings/school_year_config
  print('\n--- [BƯỚC 4/4] Khởi tạo cấu hình năm học hệ thống ---');
  await _patchFirestoreDocument(
    client: client,
    idToken: adminToken,
    collection: 'system_settings',
    docId: 'school_year_config',
    fields: {
      'currentAcademicYear': {'stringValue': '2026-2027'},
      'lastClosedAcademicYear': {'stringValue': ''},
      'currentYearStartedAt': {'timestampValue': targetCreationIso},
      'createdAt': {'timestampValue': targetCreationIso},
    },
  );
  print('  ✓ Đã thiết lập năm học hiện hành: 2026-2027 (system_settings/school_year_config, Ngày bắt đầu: 27/08/2026)');

  print('\n==================================================================');
  print('                     KHỞI TẠO HOÀN TẤT!                          ');
  print('==================================================================');
  print('  • Quản trị viên (Admin):    admin@$schoolDomain (MK: admin@$schoolDomain)');
  print('  • Tổng phụ trách (Lead):    tongphutrach@$schoolDomain (MK: tongphutrach@$schoolDomain)');
  print('  • Tổng số lớp học đã tạo:   $successClassCount / ${classNames.length} lớp');
  print('  • Mật khẩu lớp mặc định:    Trùng với email lớp (Ví dụ: 6a1@$schoolDomain)');
  print('  • Ngày tạo ghi nhận:        27/08/2026');
  print('  • Trạng thái hệ thống:      Sẵn sàng đăng nhập và sử dụng ngay!');
  print('==================================================================\n');

  client.close();
  exit(0);
}

/// Tạo mới tài khoản Firebase Auth hoặc đăng nhập nếu đã tồn tại
Future<Map<String, String>?> _getOrCreateAuthUser(
  HttpClient client,
  String email,
  String password,
) async {
  // Thử tạo tài khoản mới trước
  try {
    final signUpUrl = Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey');
    final req = await client.postUrl(signUpUrl);
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode({
      'email': email.trim().toLowerCase(),
      'password': password,
      'returnSecureToken': true,
    }));
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    final data = jsonDecode(body) as Map<String, dynamic>;

    if (res.statusCode == 200) {
      return {
        'uid': data['localId'] as String,
        'token': data['idToken'] as String,
      };
    }

    // Nếu email đã tồn tại -> Đăng nhập để lấy localId và idToken
    final errorMsg = data['error']?['message']?.toString() ?? '';
    if (errorMsg.contains('EMAIL_EXISTS')) {
      return await _signInAuthUser(client, email, password);
    }
  } catch (_) {}

  return await _signInAuthUser(client, email, password);
}

/// Đăng nhập tài khoản Firebase Auth để lấy localId và idToken
Future<Map<String, String>?> _signInAuthUser(
  HttpClient client,
  String email,
  String password,
) async {
  try {
    final signInUrl = Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$apiKey');
    final req = await client.postUrl(signInUrl);
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode({
      'email': email.trim().toLowerCase(),
      'password': password,
      'returnSecureToken': true,
    }));
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    final data = jsonDecode(body) as Map<String, dynamic>;

    if (res.statusCode == 200) {
      return {
        'uid': data['localId'] as String,
        'token': data['idToken'] as String,
      };
    }
  } catch (_) {}
  return null;
}

/// Ghi hoặc cập nhật một document trên Cloud Firestore qua REST API
Future<bool> _patchFirestoreDocument({
  required HttpClient client,
  required String idToken,
  required String collection,
  required String docId,
  required Map<String, dynamic> fields,
}) async {
  try {
    final url = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/$collection/$docId');
    final req = await client.patchUrl(url);
    req.headers.set('Authorization', 'Bearer $idToken');
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode({'fields': fields}));
    final res = await req.close();
    return res.statusCode == 200;
  } catch (_) {
    return false;
  }
}
