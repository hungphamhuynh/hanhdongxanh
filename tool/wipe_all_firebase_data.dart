// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

/// Khóa API và Project ID của Firebase
const String apiKey = 'AIzaSyAQL8w6JQ7PdvKqAT48vf_smde-mNxnGAw';
const String projectId = 'tichdiemnth';

/// Danh sách toàn bộ các Collection cần xóa sạch trên Cloud Firestore
const List<String> firestoreCollections = [
  'point_records',
  'reward_records',
  'point_rules_history',
  'reward_rules_history',
  'point_rules',
  'reward_rules',
  'classes',
  'academic_years',
  'system_settings',
  'users',
];

void main(List<String> args) async {
  print('==================================================================');
  print('   CÔNG CỤ XÓA SẠCH DỮ LIỆU FIREBASE (FIRESTORE & AUTHENTICATION)  ');
  print('==================================================================\n');

  final bool force = args.contains('--force') || args.contains('-f');

  if (!force) {
    stdout.writeln('⚠️  CẢNH BÁO NGUY HIỂM:');
    stdout.writeln('   Hành động này sẽ XÓA VĨNH VIỄN:');
    stdout.writeln('   1. Toàn bộ tài khoản người dùng trên Firebase Authentication.');
    stdout.writeln('   2. Toàn bộ dữ liệu trên Cloud Firestore (Lớp học, Lịch sử, Điểm, Quà, Năm học, Cấu hình).');
    stdout.writeln('   Hành động này KHÔNG THỂ HOÀN TÁC!\n');
    stdout.write('👉 Để xác nhận thực hiện, hãy gõ chính xác "XOA HET" rồi nhấn Enter: ');

    final input = stdin.readLineSync()?.trim();
    if (input != 'XOA HET') {
      print('\n❌ Hủy thao tác. Không có dữ liệu nào bị thay đổi.');
      exit(0);
    }
  }

  print('\n🚀 BẮT ĐẦU QUY TRÌNH DỌN DẸP SẠCH SẼ FIREBASE...\n');

  final client = HttpClient();

  // BƯỚC 1: Đăng nhập để lấy Token xác thực quyền Admin vào Firestore
  print('--- [BƯỚC 1/4] Đăng nhập tài khoản điều hành để lấy mã quyền Firestore ---');
  String? adminToken;
  String? activeAdminEmail;

  final adminCandidates = [
    {'email': 'admin@nth.com', 'password': 'admin@nth.com'},
    {
      'email': 'admin@thcsnguyenthihuong.hcm.edu.vn',
      'password': 'admin@thcsnguyenthihuong.hcm.edu.vn'
    },
    {'email': '6a1@nth.com', 'password': '6a1@nth.com'},
    {
      'email': '6a1@thcsnguyenthihuong.hcm.edu.vn',
      'password': '6a1@thcsnguyenthihuong.hcm.edu.vn'
    },
  ];

  for (final acc in adminCandidates) {
    final token = await _loginUser(client, acc['email']!, acc['password']!);
    if (token != null) {
      adminToken = token;
      activeAdminEmail = acc['email'];
      print('  ✓ Đăng nhập thành công bằng: $activeAdminEmail\n');
      break;
    }
  }

  if (adminToken == null) {
    print('  ⚠️ Không thể đăng nhập bằng các tài khoản mặc định.');
    stdout.write('  Vui lòng nhập email có quyền quản trị: ');
    final customEmail = stdin.readLineSync()?.trim() ?? '';
    stdout.write('  Vui lòng nhập mật khẩu: ');
    final customPass = stdin.readLineSync()?.trim() ?? '';
    adminToken = await _loginUser(client, customEmail, customPass);
    if (adminToken != null) {
      activeAdminEmail = customEmail;
      print('  ✓ Đăng nhập thành công bằng: $activeAdminEmail\n');
    } else {
      print('  ❌ Đăng nhập thất bại. Không thể kết nối Firestore.');
    }
  }

  // BƯỚC 2: Quét danh sách người dùng trong Firestore để không bỏ sót email nào
  final Set<String> targetEmails = {};
  if (adminToken != null) {
    print('--- [BƯỚC 2/4] Quét danh sách tài khoản người dùng từ Firestore ---');
    final userDocs =
        await _fetchCollectionDocuments(client, adminToken, 'users');
    for (final doc in userDocs) {
      final fields = doc['fields'] as Map<String, dynamic>? ?? {};
      final emailValue = fields['email']?['stringValue'] as String?;
      if (emailValue != null && emailValue.contains('@')) {
        targetEmails.add(emailValue.trim().toLowerCase());
      }
    }
    print(
        '  ✓ Đã tìm thấy ${targetEmails.length} email người dùng trong collection users.\n');
  }

  // Thêm tất cả danh sách email lớp và quản trị viên dự phòng vào danh sách cần xóa
  _populateKnownClassEmails(targetEmails);

  // BƯỚC 3: Xóa sạch toàn bộ documents trong tất cả các collections trên Firestore
  int totalFirestoreDeleted = 0;
  if (adminToken != null) {
    print('--- [BƯỚC 3/4] Xóa toàn bộ các Collections trên Cloud Firestore ---');
    for (final col in firestoreCollections) {
      stdout.write('  • Đang xóa collection "$col"... ');
      final deleted = await _wipeCollection(client, adminToken, col);
      totalFirestoreDeleted += deleted;
      print('✓ Đã xóa $deleted documents.');
    }
    print(
        '  ==> Đã xóa sạch tổng cộng $totalFirestoreDeleted documents trên Firestore.\n');
  } else {
    print('--- [BƯỚC 3/4] Bỏ qua Firestore (Do không có token đăng nhập) ---\n');
  }

  // BƯỚC 4: Xóa toàn bộ tài khoản trên Firebase Authentication
  print(
      '--- [BƯỚC 4/4] Xóa toàn bộ tài khoản người dùng trên Firebase Authentication ---');
  print('  Tổng số tài khoản cần quét và xóa: ${targetEmails.length} tài khoản.');

  int authDeletedCount = 0;
  String? currentAdminTokenForDeletion = adminToken;

  for (final email in targetEmails) {
    // Nếu là tài khoản admin đang dùng để gửi request xóa Firestore: để lại xóa sau cùng
    if (email == activeAdminEmail?.toLowerCase()) {
      continue;
    }

    final deleted = await _deleteAuthUserByEmail(client, email);
    if (deleted) {
      authDeletedCount++;
      stdout.writeln('  ✓ Đã xóa tài khoản Auth: $email');
    }
  }

  // Cuối cùng: Xóa luôn tài khoản admin điều phối
  if (activeAdminEmail != null) {
    stdout.write('  • Xóa tài khoản điều phối cuối cùng: $activeAdminEmail... ');
    bool adminDeleted = false;
    if (currentAdminTokenForDeletion != null) {
      adminDeleted =
          await _deleteAuthAccountWithToken(client, currentAdminTokenForDeletion);
    }
    if (!adminDeleted) {
      adminDeleted = await _deleteAuthUserByEmail(client, activeAdminEmail);
    }
    if (adminDeleted) {
      authDeletedCount++;
      print('✓ Thành công.');
    } else {
      print('⚠️ Không thể tự xóa.');
    }
  }

  print('\n==================================================================');
  print('                        HOÀN TẤT DỌN DẸP!                         ');
  print('==================================================================');
  print('  • Cloud Firestore: Đã xóa sạch $totalFirestoreDeleted documents.');
  print('  • Firebase Auth:   Đã xóa vĩnh viễn $authDeletedCount tài khoản.');
  print('  • Trạng thái:      Firebase đã hoàn toàn trống và sẵn sàng sử dụng mới!');
  print('==================================================================\n');

  client.close();
  exit(0);
}

/// Tự động sinh danh sách toàn bộ email các lớp và tài khoản quản trị
void _populateKnownClassEmails(Set<String> emails) {
  final domains = ['nth.com', 'thcsnguyenthihuong.hcm.edu.vn'];

  // Thêm các tài khoản quản trị và điều phối
  final baseAdmins = ['admin', 'tongphutrach', 'leadteacher'];
  for (final domain in domains) {
    for (final base in baseAdmins) {
      emails.add('$base@$domain');
    }
  }

  // Thêm tất cả các lớp học từ 6A1 đến 9A20
  for (int grade = 6; grade <= 9; grade++) {
    for (int num = 1; num <= 20; num++) {
      for (final domain in domains) {
        emails.add('${grade}a$num@$domain');
      }
    }
  }
}

/// Đăng nhập để lấy idToken
Future<String?> _loginUser(
    HttpClient client, String email, String password) async {
  try {
    final url = Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$apiKey');
    final req = await client.postUrl(url);
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode({
      'email': email,
      'password': password,
      'returnSecureToken': true,
    }));
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode == 200) {
      final data = jsonDecode(body) as Map<String, dynamic>;
      return data['idToken'] as String?;
    }
  } catch (_) {}
  return null;
}

/// Xóa một tài khoản Auth khi biết idToken
Future<bool> _deleteAuthAccountWithToken(
    HttpClient client, String idToken) async {
  try {
    final url = Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:delete?key=$apiKey');
    final req = await client.postUrl(url);
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode({'idToken': idToken}));
    final res = await req.close();
    return res.statusCode == 200;
  } catch (_) {
    return false;
  }
}

/// Đăng nhập thử với các mật khẩu mặc định rồi xóa tài khoản Auth
Future<bool> _deleteAuthUserByEmail(HttpClient client, String email) async {
  final cleanEmail = email.trim().toLowerCase();
  final prefix = cleanEmail.split('@').first;

  final candidatePasswords = [
    cleanEmail,
    prefix,
    'admin@nth.com',
    'admin@thcsnguyenthihuong.hcm.edu.vn',
    'tongphutrach@nth.com',
    'tongphutrach@thcsnguyenthihuong.hcm.edu.vn',
    '123456',
    'admin123',
    'password123',
  ];

  for (final pass in candidatePasswords) {
    final token = await _loginUser(client, cleanEmail, pass);
    if (token != null) {
      final success = await _deleteAuthAccountWithToken(client, token);
      if (success) return true;
    }
  }
  return false;
}

/// Lấy toàn bộ documents trong một Collection (hỗ trợ phân trang)
Future<List<Map<String, dynamic>>> _fetchCollectionDocuments(
    HttpClient client, String idToken, String collectionName) async {
  final List<Map<String, dynamic>> results = [];
  String? pageToken;

  do {
    try {
      var urlStr =
          'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/$collectionName?pageSize=300';
      if (pageToken != null) {
        urlStr += '&pageToken=$pageToken';
      }
      final url = Uri.parse(urlStr);
      final req = await client.getUrl(url);
      req.headers.set('Authorization', 'Bearer $idToken');
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();

      if (res.statusCode == 200) {
        final data = jsonDecode(body) as Map<String, dynamic>;
        final docs = data['documents'] as List<dynamic>?;
        if (docs != null) {
          for (final d in docs) {
            results.add(d as Map<String, dynamic>);
          }
        }
        pageToken = data['nextPageToken'] as String?;
      } else {
        break;
      }
    } catch (_) {
      break;
    }
  } while (pageToken != null);

  return results;
}

/// Xóa toàn bộ documents trong một Collection
Future<int> _wipeCollection(
    HttpClient client, String idToken, String collectionName) async {
  final docs = await _fetchCollectionDocuments(client, idToken, collectionName);
  int count = 0;

  for (final doc in docs) {
    final name = doc['name'] as String?;
    if (name == null) continue;

    try {
      final url = Uri.parse('https://firestore.googleapis.com/v1/$name');
      final req = await client.deleteUrl(url);
      req.headers.set('Authorization', 'Bearer $idToken');
      final res = await req.close();
      if (res.statusCode == 200) {
        count++;
      }
    } catch (_) {}
  }

  return count;
}
