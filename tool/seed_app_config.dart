// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

const String apiKey = 'AIzaSyAQL8w6JQ7PdvKqAT48vf_smde-mNxnGAw';
const String projectId = 'tichdiemnth';
const String schoolDomain = 'thcsnguyenthihuong.hcm.edu.vn';

void main() async {
  print('====================================================');
  print('    CẬP NHẬT CẤU HÌNH settings/app_config (FIRESTORE)');
  print('====================================================\n');

  final client = HttpClient();

  // 1. Đăng nhập Admin
  final adminEmail = 'admin@$schoolDomain';
  final authUrl =
      'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$apiKey';
  final authReq = await client.postUrl(Uri.parse(authUrl));
  authReq.headers.contentType = ContentType.json;
  authReq.write(jsonEncode({
    'email': adminEmail,
    'password': adminEmail,
    'returnSecureToken': true,
  }));
  final authResp = await authReq.close();
  final authBody = await authResp.transform(utf8.decoder).join();
  final authData = jsonDecode(authBody) as Map<String, dynamic>;

  final token = authData['idToken'] as String?;
  if (token == null) {
    print('❌ Lỗi đăng nhập Admin!');
    client.close();
    exit(1);
  }
  print('✅ Đăng nhập Admin thành công.');

  // 2. Ghi document settings/app_config
  final docUrl =
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/settings/app_config';
  final patchReq = await client.patchUrl(Uri.parse(docUrl));
  patchReq.headers.set('Authorization', 'Bearer $token');
  patchReq.headers.contentType = ContentType.json;
  patchReq.write(jsonEncode({
    'fields': {
      'apkDownloadUrl': {
        'stringValue':
            'https://github.com/hungphamhuynh/hanhdongxanh/releases/download/v1.0.0/HanhDongXanh.apk',
      },
    },
  }));
  final patchResp = await patchReq.close();
  final patchBody = await patchResp.transform(utf8.decoder).join();

  if (patchResp.statusCode == 200) {
    print('✅ Đã lưu cấu hình vào Firestore settings/app_config:');
    print('   apkDownloadUrl = https://github.com/hungphamhuynh/hanhdongxanh/releases/download/v1.0.0/HanhDongXanh.apk');
  } else {
    print('❌ Lỗi lưu cấu hình: $patchBody');
  }

  client.close();
}
