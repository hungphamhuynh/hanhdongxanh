// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

const String apiKey = 'AIzaSyAQL8w6JQ7PdvKqAT48vf_smde-mNxnGAw';
const String projectId = 'tichdiemnth';
const String schoolDomain = 'thcsnguyenthihuong.hcm.edu.vn';

class PointRecordEntry {
  final String className;
  final String ruleId;
  final String categoryName;
  final String unit;
  final double quantity;
  final int unitQuantity;
  final int points;
  final int totalPoints;
  final String note;
  final DateTime createdAt;

  const PointRecordEntry({
    required this.className,
    required this.ruleId,
    required this.categoryName,
    required this.unit,
    required this.quantity,
    required this.unitQuantity,
    required this.points,
    required this.totalPoints,
    required this.note,
    required this.createdAt,
  });
}

void main() async {
  print('==================================================================');
  print('   KHỞI TẠO TÍCH ĐIỂM NGÀY 30-31 THÁNG 8 NĂM 2026 (5 LỚP KHỞI ĐỘNG)');
  print('==================================================================\n');

  final client = HttpClient();

  // 1. Đăng nhập Admin
  final adminEmail = 'admin@$schoolDomain';
  final adminToken = await _loginUser(client, adminEmail, adminEmail);
  if (adminToken == null) {
    print('❌ Lỗi đăng nhập Admin!');
    client.close();
    exit(1);
  }

  // 2. Lấy thông tin tài khoản các lớp
  final classAccounts = await _fetchClassAccounts(client, adminToken);

  // 3. ID 5 thể loại thực tế trên Firestore
  const ruleChai = 'tmAhGd7l5an1cr3NfMfI'; // Chai nhựa (5 Số lượng = 1đ)
  const ruleLon = 'EUlCGsrqkV15R3Dle0Y2'; // Lon nhôm (5 Số lượng = 1đ)
  const ruleGiay = 'FRbDGSgZKhybs2JCCL6Y'; // Giấy vụn & Sách báo (1 Kg = 1đ)
  const rulePin = 'hVCy4KMjQpBFcXWaRg22'; // Pin cũ (5 Số lượng = 1đ)
  const ruleBut = 'VU6K1BkATGhrN7OMpWJd'; // Bút viết cũ (5 Số lượng = 1đ)

  // 4. Danh sách 5 lớp khởi động ngày 30-31/08/2026:
  // - Mỗi lớp chỉ 3 - 4 điểm
  // - Giấy báo CHỈ ĐÚNG 1 LỚP NỘP (1kg = 1đ kèm 10 chai = 2đ => tổng 3đ hoặc 15 lon = 3đ + 1kg giấy = 4đ)
  // - Các lớp khác thu gom chai nhựa, lon nhôm, pin, bút cũ
  final List<PointRecordEntry> records = [
    // 1. Lớp 6A1 (30/08/2026): 15 chai nhựa = 3 điểm
    PointRecordEntry(
      className: '6A1',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 15.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 3,
      note: 'Vỏ chai nước dọn vệ sinh nhận phòng học',
      createdAt: DateTime.utc(2026, 8, 30, 8, 30),
    ),

    // 2. Lớp 7A1 (30/08/2026): 15 lon nhôm = 3 điểm
    PointRecordEntry(
      className: '7A1',
      ruleId: ruleLon,
      categoryName: 'Lon nhôm',
      unit: 'Số lượng',
      quantity: 15.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 3,
      note: 'Vỏ lon nước giải khát tựu trường',
      createdAt: DateTime.utc(2026, 8, 30, 9, 15),
    ),

    // 3. Lớp 8A1 (31/08/2026): Đúng 1kg báo cũ gia đình đem theo (1đ) + 15 chai nhựa (3đ) = 4 điểm
    PointRecordEntry(
      className: '8A1',
      ruleId: ruleGiay,
      categoryName: 'Giấy vụn & Sách báo',
      unit: 'Kg',
      quantity: 1.0,
      unitQuantity: 1,
      points: 1,
      totalPoints: 1,
      note: 'Báo cũ ở nhà đem theo ngày tựu trường (1kg)',
      createdAt: DateTime.utc(2026, 8, 31, 8, 0),
    ),
    PointRecordEntry(
      className: '8A1',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 15.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 3,
      note: 'Vỏ chai nước dọn vệ sinh sân trường',
      createdAt: DateTime.utc(2026, 8, 31, 8, 15),
    ),

    // 4. Lớp 9A1 (31/08/2026): 20 chai nhựa = 4 điểm
    PointRecordEntry(
      className: '9A1',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 20.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 4,
      note: 'Chai nhựa thu gom dọn phòng bộ môn',
      createdAt: DateTime.utc(2026, 8, 31, 10, 0),
    ),

    // 5. Lớp 6A2 (31/08/2026): 15 bút bi cũ = 3 điểm
    PointRecordEntry(
      className: '6A2',
      ruleId: ruleBut,
      categoryName: 'Bút viết cũ',
      unit: 'Số lượng',
      quantity: 15.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 3,
      note: 'Vỏ bút bi hết mực gom từ năm học trước',
      createdAt: DateTime.utc(2026, 8, 31, 14, 0),
    ),
  ];

  print('--- BẮT ĐẦU TẠO PHIẾU TÍCH ĐIỂM NGÀY 30-31/08/2026 ---');
  final Map<String, int> classPointsMap = {};
  final Map<String, DateTime> classLatestTimeMap = {};

  int count = 0;
  for (final rec in records) {
    final acc = classAccounts[rec.className];
    final classEmail = acc?['email'] ?? '${rec.className.toLowerCase()}@$schoolDomain';
    final classUid = acc?['uid'] ?? 'uid_${rec.className.toLowerCase()}';
    final createdIso = rec.createdAt.toIso8601String();

    final ok = await _createPointRecordDoc(
      client: client,
      idToken: adminToken,
      fields: {
        'className': {'stringValue': rec.className},
        'ruleId': {'stringValue': rec.ruleId},
        'categoryName': {'stringValue': rec.categoryName},
        'unit': {'stringValue': rec.unit},
        'quantity': {'doubleValue': rec.quantity},
        'unitQuantity': {'integerValue': '${rec.unitQuantity}'},
        'points': {'integerValue': '${rec.points}'},
        'pointsPerUnit': {'integerValue': '${rec.points}'},
        'totalPoints': {'integerValue': '${rec.totalPoints}'},
        'academicYearId': {'stringValue': '2026-2027'},
        'note': {'stringValue': rec.note},
        'createdByEmail': {'stringValue': classEmail},
        'createdByUid': {'stringValue': classUid},
        'createdAt': {'timestampValue': createdIso},
      },
    );

    if (ok) {
      count++;
      final prev = classPointsMap[rec.className] ?? 0;
      classPointsMap[rec.className] = prev + rec.totalPoints;
      final prevTime = classLatestTimeMap[rec.className];
      if (prevTime == null || rec.createdAt.isAfter(prevTime)) {
        classLatestTimeMap[rec.className] = rec.createdAt;
      }
      print('  ✓ [Phiếu $count] Lớp ${rec.className}: ${rec.categoryName} (${rec.quantity} ${rec.unit}) = +${rec.totalPoints}đ (Người tạo: $classEmail)');
    }
  }

  print('\n--- CẬP NHẬT ĐIỂM VÀ THỜI GIAN VÀO COLLECTION CLASSES ---');
  for (final entry in classPointsMap.entries) {
    final cName = entry.key;
    final totalPts = entry.value;
    final lastTimeIso = classLatestTimeMap[cName]!.toIso8601String();

    await _patchFirestoreDocument(
      client: client,
      idToken: adminToken,
      collection: 'classes',
      docId: cName,
      fields: {
        'totalPoints': {'integerValue': '$totalPts'},
        'lastRecordedAt': {'timestampValue': lastTimeIso},
      },
    );
    print('  ✓ Lớp $cName: $totalPts điểm (Cập nhật lúc: $lastTimeIso)');
  }

  print('\n==================================================================');
  print('   HOÀN TẤT KHỞI TẠO ĐỢT 30-31 THÁNG 8 NĂM 2026!');
  print('==================================================================\n');

  client.close();
  exit(0);
}

Future<String?> _loginUser(HttpClient client, String email, String password) async {
  try {
    final url = Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$apiKey');
    final req = await client.postUrl(url);
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode({
      'email': email.trim().toLowerCase(),
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

Future<Map<String, Map<String, String>>> _fetchClassAccounts(
  HttpClient client,
  String idToken,
) async {
  final Map<String, Map<String, String>> results = {};
  try {
    final url = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/users?pageSize=100');
    final req = await client.getUrl(url);
    req.headers.set('Authorization', 'Bearer $idToken');
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode == 200) {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final docs = data['documents'] as List<dynamic>? ?? [];
      for (final doc in docs) {
        final fields = doc['fields'] as Map<String, dynamic>? ?? {};
        final email = fields['email']?['stringValue'] as String? ?? '';
        final uid = fields['uid']?['stringValue'] as String? ?? '';
        final assignedClass = fields['assignedClass']?['stringValue'] as String? ?? '';
        if (assignedClass.isNotEmpty) {
          results[assignedClass.toUpperCase()] = {
            'uid': uid,
            'email': email,
          };
        }
      }
    }
  } catch (_) {}
  return results;
}

Future<bool> _createPointRecordDoc({
  required HttpClient client,
  required String idToken,
  required Map<String, dynamic> fields,
}) async {
  try {
    final url = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/point_records');
    final req = await client.postUrl(url);
    req.headers.set('Authorization', 'Bearer $idToken');
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode({'fields': fields}));
    final res = await req.close();
    return res.statusCode == 200;
  } catch (_) {
    return false;
  }
}

Future<bool> _patchFirestoreDocument({
  required HttpClient client,
  required String idToken,
  required String collection,
  required String docId,
  required Map<String, dynamic> fields,
}) async {
  try {
    final url = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/$collection/$docId?updateMask.fieldPaths=totalPoints&updateMask.fieldPaths=lastRecordedAt');
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
