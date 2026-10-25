// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

/// Khóa API và Project ID của Firebase
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
  print('   KHỞI TẠO DỮ LIỆU TÍCH ĐIỂM THỰC TẾ (30/08/2026 -> 22/10/2026) ');
  print('==================================================================\n');

  final client = HttpClient();

  // 1. Đăng nhập Admin để lấy token thao tác Firestore
  print('--- [BƯỚC 1/4] Đăng nhập Admin lấy quyền quản trị ---');
  final adminEmail = 'admin@$schoolDomain';
  final adminToken = await _loginUser(client, adminEmail, adminEmail);
  if (adminToken == null) {
    print('❌ Không thể đăng nhập tài khoản Admin ($adminEmail)!');
    client.close();
    exit(1);
  }
  print('  ✓ Đăng nhập Admin thành công.\n');

  // 2. Lấy thông tin tài khoản của các lớp học từ Firestore (users collection)
  print('--- [BƯỚC 2/4] Quét mapping tài khoản từng lớp học ---');
  final classAccounts = await _fetchClassAccounts(client, adminToken);
  print('  ✓ Đã nạp thông tin ${classAccounts.length} tài khoản lớp học.\n');

  // 3. ID 5 thể loại rác thu gom thực tế trên Firestore
  const ruleChai = 'tmAhGd7l5an1cr3NfMfI'; // Chai nhựa (5 Số lượng = 1đ)
  const ruleLon = 'EUlCGsrqkV15R3Dle0Y2'; // Lon nhôm (5 Số lượng = 1đ)
  const ruleGiay = 'FRbDGSgZKhybs2JCCL6Y'; // Giấy vụn & Sách báo (1 Kg = 1đ)
  const rulePin = 'hVCy4KMjQpBFcXWaRg22'; // Pin cũ (5 Số lượng = 1đ)
  const ruleBut = 'VU6K1BkATGhrN7OMpWJd'; // Bút viết cũ (5 Số lượng = 1đ)

  // 4. Danh sách 22 phiếu thu gom rải rác theo tuần (Lớp cao nhất đạt 27 điểm <= 30 điểm)
  final List<PointRecordEntry> records = [
    // TUẦN 1 (30/08 - 05/09/2026): Khởi động trước thềm khai giảng (chỉ 2 lớp tiên phong)
    PointRecordEntry(
      className: '6A1',
      ruleId: ruleGiay,
      categoryName: 'Giấy vụn & Sách báo',
      unit: 'Kg',
      quantity: 5.0,
      unitQuantity: 1,
      points: 1,
      totalPoints: 5,
      note: 'Dọn dẹp sách báo cũ nhận phòng học đầu năm',
      createdAt: DateTime.utc(2026, 8, 31, 8, 30),
    ),
    PointRecordEntry(
      className: '8A1',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 25.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 5,
      note: 'Thu gom chai nước dọn vệ sinh sân trường',
      createdAt: DateTime.utc(2026, 9, 4, 9, 15),
    ),

    // TUẦN 2 (06/09 - 12/09/2026): Tuần lễ khai giảng, thêm 2 lớp
    PointRecordEntry(
      className: '7A1',
      ruleId: ruleLon,
      categoryName: 'Lon nhôm',
      unit: 'Số lượng',
      quantity: 20.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 4,
      note: 'Vỏ lon nước ngọt sau lễ khai giảng',
      createdAt: DateTime.utc(2026, 9, 7, 7, 45),
    ),
    PointRecordEntry(
      className: '9A1',
      ruleId: ruleGiay,
      categoryName: 'Giấy vụn & Sách báo',
      unit: 'Kg',
      quantity: 8.0,
      unitQuantity: 1,
      points: 1,
      totalPoints: 8,
      note: 'Giấy nháp và báo cũ khối 9 đợt 1',
      createdAt: DateTime.utc(2026, 9, 11, 10, 0),
    ),

    // TUẦN 3 (13/09 - 19/09/2026):
    PointRecordEntry(
      className: '6A2',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 20.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 4,
      note: 'Hưởng ứng phong trào lớp học xanh tuần 3',
      createdAt: DateTime.utc(2026, 9, 14, 8, 0),
    ),
    PointRecordEntry(
      className: '6A1',
      ruleId: ruleBut,
      categoryName: 'Bút viết cũ',
      unit: 'Số lượng',
      quantity: 15.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 3,
      note: 'Gom vỏ bút bi đã hết mực',
      createdAt: DateTime.utc(2026, 9, 18, 9, 30),
    ),

    // TUẦN 4 (20/09 - 26/09/2026):
    PointRecordEntry(
      className: '8A2',
      ruleId: ruleLon,
      categoryName: 'Lon nhôm',
      unit: 'Số lượng',
      quantity: 25.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 5,
      note: 'Thu gom vỏ lon tuần 4',
      createdAt: DateTime.utc(2026, 9, 21, 7, 30),
    ),
    PointRecordEntry(
      className: '7A2',
      ruleId: ruleGiay,
      categoryName: 'Giấy vụn & Sách báo',
      unit: 'Kg',
      quantity: 6.0,
      unitQuantity: 1,
      points: 1,
      totalPoints: 6,
      note: 'Kế hoạch nhỏ giấy vụn',
      createdAt: DateTime.utc(2026, 9, 25, 10, 15),
    ),

    // TUẦN 5 (27/09 - 03/10/2026):
    PointRecordEntry(
      className: '9A2',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 30.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 6,
      note: 'Chai nhựa nước giải khát',
      createdAt: DateTime.utc(2026, 9, 28, 8, 15),
    ),
    PointRecordEntry(
      className: '8A1',
      ruleId: ruleGiay,
      categoryName: 'Giấy vụn & Sách báo',
      unit: 'Kg',
      quantity: 9.0,
      unitQuantity: 1,
      points: 1,
      totalPoints: 9,
      note: 'Bìa carton và giấy vụn cuối tháng 9',
      createdAt: DateTime.utc(2026, 10, 2, 9, 0),
    ),

    // TUẦN 6 (04/10 - 10/10/2026):
    PointRecordEntry(
      className: '6A1',
      ruleId: ruleGiay,
      categoryName: 'Giấy vụn & Sách báo',
      unit: 'Kg',
      quantity: 10.0,
      unitQuantity: 1,
      points: 1,
      totalPoints: 10,
      note: 'Đợt thu gom giấy vụn tập trung đầu tháng 10',
      createdAt: DateTime.utc(2026, 10, 5, 8, 45),
    ),
    PointRecordEntry(
      className: '7A1',
      ruleId: rulePin,
      categoryName: 'Pin cũ',
      unit: 'Số lượng',
      quantity: 15.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 3,
      note: 'Thu gom pin cũ bảo vệ môi trường',
      createdAt: DateTime.utc(2026, 10, 7, 7, 50),
    ),
    PointRecordEntry(
      className: '8A3',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 25.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 5,
      note: 'Chai nhựa thu gom lớp học',
      createdAt: DateTime.utc(2026, 10, 9, 10, 30),
    ),

    // TUẦN 7 (11/10 - 17/10/2026):
    PointRecordEntry(
      className: '9A1',
      ruleId: ruleLon,
      categoryName: 'Lon nhôm',
      unit: 'Số lượng',
      quantity: 30.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 6,
      note: 'Vỏ lon nhôm tuần sinh hoạt 7',
      createdAt: DateTime.utc(2026, 10, 12, 8, 0),
    ),
    PointRecordEntry(
      className: '7A3',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 20.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 4,
      note: 'Thu gom chai nhựa',
      createdAt: DateTime.utc(2026, 10, 14, 9, 20),
    ),
    PointRecordEntry(
      className: '8A1',
      ruleId: ruleLon,
      categoryName: 'Lon nhôm',
      unit: 'Số lượng',
      quantity: 25.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 5,
      note: 'Vỏ lon tái chế',
      createdAt: DateTime.utc(2026, 10, 16, 7, 40),
    ),
    PointRecordEntry(
      className: '6A3',
      ruleId: rulePin,
      categoryName: 'Pin cũ',
      unit: 'Số lượng',
      quantity: 10.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 2,
      note: 'Pin đồng hồ và đồ chơi cũ',
      createdAt: DateTime.utc(2026, 10, 17, 10, 0),
    ),

    // TUẦN 8 (18/10 - 22/10/2026): Chặng đua nước rút cuối đợt
    PointRecordEntry(
      className: '6A1',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 45.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 9,
      note: 'Chai nhựa tái chế ngày thứ 6 xanh',
      createdAt: DateTime.utc(2026, 10, 19, 8, 30),
    ),
    PointRecordEntry(
      className: '8A1',
      ruleId: ruleGiay,
      categoryName: 'Giấy vụn & Sách báo',
      unit: 'Kg',
      quantity: 8.0,
      unitQuantity: 1,
      points: 1,
      totalPoints: 8,
      note: 'Giấy báo cũ thi đua tuần',
      createdAt: DateTime.utc(2026, 10, 20, 9, 15),
    ),
    PointRecordEntry(
      className: '7A1',
      ruleId: ruleGiay,
      categoryName: 'Giấy vụn & Sách báo',
      unit: 'Kg',
      quantity: 10.0,
      unitQuantity: 1,
      points: 1,
      totalPoints: 10,
      note: 'Thu gom sách báo cũ',
      createdAt: DateTime.utc(2026, 10, 21, 8, 0),
    ),
    PointRecordEntry(
      className: '9A1',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 40.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 8,
      note: 'Chai nhựa tổng kết đợt 22/10',
      createdAt: DateTime.utc(2026, 10, 22, 10, 30),
    ),
    PointRecordEntry(
      className: '6A2',
      ruleId: ruleLon,
      categoryName: 'Lon nhôm',
      unit: 'Số lượng',
      quantity: 15.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 3,
      note: 'Vỏ lon nhôm đợt 2',
      createdAt: DateTime.utc(2026, 10, 22, 11, 0),
    ),
  ];

  print('--- [BƯỚC 3/4] Lưu ${records.length} phiếu tích điểm vào point_records ---');

  // Thống kê tổng điểm và thời gian nộp mới nhất cho từng lớp
  final Map<String, int> classPointsMap = {};
  final Map<String, DateTime> classLatestTimeMap = {};

  int countCreated = 0;
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
      countCreated++;
      final prevPts = classPointsMap[rec.className] ?? 0;
      classPointsMap[rec.className] = prevPts + rec.totalPoints;

      final prevTime = classLatestTimeMap[rec.className];
      if (prevTime == null || rec.createdAt.isAfter(prevTime)) {
        classLatestTimeMap[rec.className] = rec.createdAt;
      }
    }
  }
  print('  ✓ Đã tạo thành công $countCreated / ${records.length} phiếu thu gom.\n');

  // 4. Đồng bộ tổng điểm và thời gian thu gom mới nhất vào classes collection
  print('--- [BƯỚC 4/4] Cập nhật tổng điểm và thời gian nộp vào collection classes ---');
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
    print('  ✓ Lớp $cName: $totalPts điểm (Lượt gần nhất: $lastTimeIso)');
  }

  print('\n==================================================================');
  print('                    HOÀN TẤT KHỞI TẠO DỮ LIỆU!                    ');
  print('==================================================================');
  print('  • Tổng số phiếu tạo:        $countCreated phiếu');
  print('  • Khoảng thời gian:         30/08/2026 -> 22/10/2026');
  print('  • Người tạo từng phiếu:     Chính tài khoản của lớp tương ứng');
  print('  • Bảng xếp hạng dẫn đầu:');
  print('      - Lớp 6A1: 27 điểm (Top 1 Khối 6 & Toàn trường)');
  print('      - Lớp 8A1: 27 điểm (Top 1 Khối 8)');
  print('      - Lớp 9A1: 22 điểm (Top 1 Khối 9)');
  print('      - Lớp 7A1: 17 điểm (Top 1 Khối 7)');
  print('      - Lớp 6A2: 7 điểm');
  print('      - Lớp 7A2: 6 điểm');
  print('      - Lớp 9A2: 6 điểm');
  print('      - Lớp 8A2: 5 điểm');
  print('      - Lớp 8A3: 5 điểm');
  print('      - Lớp 7A3: 4 điểm');
  print('      - Lớp 6A3: 2 điểm');
  print('      - 25 lớp còn lại: 0 điểm (chưa nộp đợt nào, rất tự nhiên)');
  print('==================================================================\n');

  client.close();
  exit(0);
}

/// Đăng nhập tài khoản lấy idToken
Future<String?> _loginUser(
  HttpClient client,
  String email,
  String password,
) async {
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

/// Lấy mapping className -> { 'uid', 'email' } từ users collection
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

/// Tạo document mới trong point_records
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

/// Cập nhật document trên Firestore qua PATCH
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
