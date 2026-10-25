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
  print('   KHỞI TẠO TÍCH ĐIỂM THÁNG 9 NĂM 2026 (THEO YÊU CẦU ĐÃ CHỈNH)   ');
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

  final List<PointRecordEntry> records = [
    // -------------------------------------------------------------
    // NHÓM 1: TỪ 07/09 ĐẾN 15/09
    // A. 3 lớp cũ tháng 8: Mỗi lớp +2 điểm
    // -------------------------------------------------------------
    PointRecordEntry(
      className: '6A1',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 10.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 2,
      note: 'Chai nhựa thu gom sau lễ khai giảng',
      createdAt: DateTime.utc(2026, 9, 7, 8, 0),
    ),
    PointRecordEntry(
      className: '8A1',
      ruleId: ruleLon,
      categoryName: 'Lon nhôm',
      unit: 'Số lượng',
      quantity: 10.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 2,
      note: 'Vỏ lon nước giải khát tuần 1',
      createdAt: DateTime.utc(2026, 9, 9, 9, 30),
    ),
    PointRecordEntry(
      className: '9A1',
      ruleId: ruleBut,
      categoryName: 'Bút viết cũ',
      unit: 'Số lượng',
      quantity: 10.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 2,
      note: 'Vỏ bút bi hết mực gom đầu năm',
      createdAt: DateTime.utc(2026, 9, 12, 10, 15),
    ),

    // B. 10 lớp MỚI đợt 1: Mỗi lớp tầm 4-5 điểm
    PointRecordEntry(
      className: '6A3',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 20.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 4,
      note: 'Hưởng ứng phong trào lớp học xanh',
      createdAt: DateTime.utc(2026, 9, 8, 8, 30),
    ),
    PointRecordEntry(
      className: '6A4',
      ruleId: ruleLon,
      categoryName: 'Lon nhôm',
      unit: 'Số lượng',
      quantity: 25.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 5,
      note: 'Vỏ lon thu gom sinh hoạt lớp',
      createdAt: DateTime.utc(2026, 9, 8, 14, 0),
    ),
    PointRecordEntry(
      className: '7A2',
      ruleId: ruleBut,
      categoryName: 'Bút viết cũ',
      unit: 'Số lượng',
      quantity: 20.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 4,
      note: 'Thu gom bút bi cũ',
      createdAt: DateTime.utc(2026, 9, 9, 8, 0),
    ),
    PointRecordEntry(
      className: '7A3',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 25.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 5,
      note: 'Chai nước giải khát tái chế',
      createdAt: DateTime.utc(2026, 9, 10, 9, 0),
    ),
    PointRecordEntry(
      className: '8A2',
      ruleId: ruleLon,
      categoryName: 'Lon nhôm',
      unit: 'Số lượng',
      quantity: 20.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 4,
      note: 'Vỏ lon nước ngọt',
      createdAt: DateTime.utc(2026, 9, 11, 8, 15),
    ),
    PointRecordEntry(
      className: '8A3',
      ruleId: rulePin,
      categoryName: 'Pin cũ',
      unit: 'Số lượng',
      quantity: 20.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 4,
      note: 'Thu gom pin cũ ngăn ô nhiễm',
      createdAt: DateTime.utc(2026, 9, 11, 10, 30),
    ),
    PointRecordEntry(
      className: '8A4',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 25.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 5,
      note: 'Vỏ chai nhựa lớp học',
      createdAt: DateTime.utc(2026, 9, 12, 8, 45),
    ),
    PointRecordEntry(
      className: '9A2',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 20.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 4,
      note: 'Chai nhựa tái chế tuần 2',
      createdAt: DateTime.utc(2026, 9, 14, 9, 15),
    ),
    PointRecordEntry(
      className: '9A3',
      ruleId: ruleLon,
      categoryName: 'Lon nhôm',
      unit: 'Số lượng',
      quantity: 25.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 5,
      note: 'Thu gom vỏ lon',
      createdAt: DateTime.utc(2026, 9, 14, 14, 30),
    ),
    PointRecordEntry(
      className: '9A4',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 20.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 4,
      note: 'Chai nhựa thu gom ngày thứ 6 xanh',
      createdAt: DateTime.utc(2026, 9, 15, 8, 0),
    ),

    // -------------------------------------------------------------
    // NHÓM 2: TỪ 15/09 ĐẾN CUỐI THÁNG 9 (30/09)
    // A. 8 lớp MỚI đợt 2: Mỗi lớp tầm 5-6 điểm
    // -------------------------------------------------------------
    PointRecordEntry(
      className: '6A5',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 25.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 5,
      note: 'Chai nhựa thu gom tuần 3',
      createdAt: DateTime.utc(2026, 9, 16, 9, 30),
    ),
    PointRecordEntry(
      className: '6A6',
      ruleId: ruleLon,
      categoryName: 'Lon nhôm',
      unit: 'Số lượng',
      quantity: 30.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 6,
      note: 'Vỏ lon nước tuần 3',
      createdAt: DateTime.utc(2026, 9, 17, 8, 0),
    ),
    PointRecordEntry(
      className: '7A4',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 25.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 5,
      note: 'Chai nhựa tái chế',
      createdAt: DateTime.utc(2026, 9, 18, 10, 0),
    ),
    PointRecordEntry(
      className: '7A5',
      ruleId: ruleLon,
      categoryName: 'Lon nhôm',
      unit: 'Số lượng',
      quantity: 30.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 6,
      note: 'Vỏ lon tái chế sinh hoạt tuần 3',
      createdAt: DateTime.utc(2026, 9, 21, 8, 30),
    ),
    PointRecordEntry(
      className: '8A5',
      ruleId: ruleLon,
      categoryName: 'Lon nhôm',
      unit: 'Số lượng',
      quantity: 25.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 5,
      note: 'Thu gom lon nhôm tuần 4',
      createdAt: DateTime.utc(2026, 9, 22, 9, 15),
    ),
    PointRecordEntry(
      className: '8A6',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 30.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 6,
      note: 'Chai nước giải khát tái chế',
      createdAt: DateTime.utc(2026, 9, 23, 14, 0),
    ),
    PointRecordEntry(
      className: '9A5',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 25.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 5,
      note: 'Chai nhựa khối 9',
      createdAt: DateTime.utc(2026, 9, 25, 8, 0),
    ),
    PointRecordEntry(
      className: '9A6',
      ruleId: ruleLon,
      categoryName: 'Lon nhôm',
      unit: 'Số lượng',
      quantity: 30.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 6,
      note: 'Vỏ lon tái chế',
      createdAt: DateTime.utc(2026, 9, 26, 10, 15),
    ),

    // B. 5 lớp CŨ: Mỗi lớp tăng thêm 1-2 điểm
    PointRecordEntry(
      className: '6A1',
      ruleId: rulePin,
      categoryName: 'Pin cũ',
      unit: 'Số lượng',
      quantity: 10.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 2,
      note: 'Pin đồng hồ và điều khiển cũ',
      createdAt: DateTime.utc(2026, 9, 19, 8, 15),
    ),
    PointRecordEntry(
      className: '7A1',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 10.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 2,
      note: 'Chai nhựa dọn lớp',
      createdAt: DateTime.utc(2026, 9, 22, 8, 45),
    ),
    PointRecordEntry(
      className: '8A1',
      ruleId: ruleBut,
      categoryName: 'Bút viết cũ',
      unit: 'Số lượng',
      quantity: 5.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 1,
      note: 'Vỏ bút bi hết mực',
      createdAt: DateTime.utc(2026, 9, 24, 9, 0),
    ),
    PointRecordEntry(
      className: '6A3',
      ruleId: ruleLon,
      categoryName: 'Lon nhôm',
      unit: 'Số lượng',
      quantity: 10.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 2,
      note: 'Vỏ lon tái chế',
      createdAt: DateTime.utc(2026, 9, 28, 8, 30),
    ),
    PointRecordEntry(
      className: '8A2',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 5.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 1,
      note: 'Chai nước lọc lớp học',
      createdAt: DateTime.utc(2026, 9, 29, 10, 0),
    ),

    // -------------------------------------------------------------
    // NHÓM 3: TỪ 10/09 ĐẾN 28/09 (ĐÃ GIẢM CÒN ĐÚNG 4 LỚP MỚI)
    // Mỗi lớp nộp nhẹ 1-2 điểm
    // -------------------------------------------------------------
    PointRecordEntry(
      className: '6A7',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 5.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 1,
      note: 'Hưởng ứng phong trào chai nhựa',
      createdAt: DateTime.utc(2026, 9, 13, 9, 0),
    ),
    PointRecordEntry(
      className: '7A6',
      ruleId: rulePin,
      categoryName: 'Pin cũ',
      unit: 'Số lượng',
      quantity: 10.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 2,
      note: 'Pin cũ gia đình đem nộp',
      createdAt: DateTime.utc(2026, 9, 17, 14, 30),
    ),
    PointRecordEntry(
      className: '8A7',
      ruleId: ruleBut,
      categoryName: 'Bút viết cũ',
      unit: 'Số lượng',
      quantity: 10.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 2,
      note: 'Bút viết hết mực',
      createdAt: DateTime.utc(2026, 9, 23, 8, 15),
    ),
    PointRecordEntry(
      className: '9A7',
      ruleId: ruleLon,
      categoryName: 'Lon nhôm',
      unit: 'Số lượng',
      quantity: 5.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 1,
      note: 'Vỏ lon nước giải khát',
      createdAt: DateTime.utc(2026, 9, 27, 9, 45),
    ),
  ];

  print('--- BẮT ĐẦU TẠO ${records.length} PHIẾU TÍCH ĐIỂM THÁNG 9/2026 ---');
  final Map<String, int> addedPointsMap = {};
  final Map<String, DateTime> latestTimeMap = {};

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
      final prev = addedPointsMap[rec.className] ?? 0;
      addedPointsMap[rec.className] = prev + rec.totalPoints;
      final prevTime = latestTimeMap[rec.className];
      if (prevTime == null || rec.createdAt.isAfter(prevTime)) {
        latestTimeMap[rec.className] = rec.createdAt;
      }
      print('  ✓ [Phiếu $count] Lớp ${rec.className}: ${rec.categoryName} = +${rec.totalPoints}đ (Tạo lúc: $createdIso - Người tạo: $classEmail)');
    }
  }

  print('\n--- CẬP NHẬT TỔNG ĐIỂM CỘNG DỒN VÀO COLLECTION CLASSES ---');
  // Lấy điểm hiện tại của các lớp từ Firestore để cộng dồn
  for (final entry in addedPointsMap.entries) {
    final cName = entry.key;
    final addedPts = entry.value;
    final lastTimeIso = latestTimeMap[cName]!.toIso8601String();

    final curPoints = await _getCurrentClassPoints(client, adminToken, cName);
    final newTotalPoints = curPoints + addedPts;

    await _patchFirestoreDocument(
      client: client,
      idToken: adminToken,
      collection: 'classes',
      docId: cName,
      fields: {
        'totalPoints': {'integerValue': '$newTotalPoints'},
        'lastRecordedAt': {'timestampValue': lastTimeIso},
      },
    );
    print('  ✓ Lớp $cName: Trước đó $curPoints đ + Thêm $addedPts đ = $newTotalPoints đ (Cập nhật lúc: $lastTimeIso)');
  }

  print('\n==================================================================');
  print('          HOÀN TẤT KHỞI TẠO DỮ LIỆU THÁNG 9 NĂM 2026!             ');
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

Future<int> _getCurrentClassPoints(HttpClient client, String idToken, String className) async {
  try {
    final url = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/classes/$className');
    final req = await client.getUrl(url);
    req.headers.set('Authorization', 'Bearer $idToken');
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode == 200) {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final fields = data['fields'] as Map<String, dynamic>? ?? {};
      final pts = fields['totalPoints']?['integerValue'] as String? ?? '0';
      return int.tryParse(pts) ?? 0;
    }
  } catch (_) {}
  return 0;
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
