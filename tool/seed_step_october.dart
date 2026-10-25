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
  print('   KHỞI TẠO TÍCH ĐIỂM THÁNG 10 NĂM 2026 (BAO PHỦ 36/36 LỚP)       ');
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
    // NHÓM A: 7 LỚP ĐẠT TẦM 3 - 4 ĐIỂM
    // -------------------------------------------------------------
    PointRecordEntry(
      className: '6A7',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 10.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 2,
      note: 'Chai nhựa tuần sinh hoạt tháng 10',
      createdAt: DateTime.utc(2026, 10, 5, 8, 30),
    ),
    PointRecordEntry(
      className: '9A7',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 10.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 2,
      note: 'Vỏ chai nước thu gom lớp học',
      createdAt: DateTime.utc(2026, 10, 7, 9, 15),
    ),
    PointRecordEntry(
      className: '7A7',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 15.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 3,
      note: 'Hưởng ứng phong trào đợt tháng 10',
      createdAt: DateTime.utc(2026, 10, 6, 8, 0),
    ),
    PointRecordEntry(
      className: '8A10',
      ruleId: ruleBut,
      categoryName: 'Bút viết cũ',
      unit: 'Số lượng',
      quantity: 15.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 3,
      note: 'Vỏ bút bi hết mực gom từ lớp',
      createdAt: DateTime.utc(2026, 10, 9, 10, 0),
    ),
    PointRecordEntry(
      className: '7A6',
      ruleId: ruleLon,
      categoryName: 'Lon nhôm',
      unit: 'Số lượng',
      quantity: 10.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 2,
      note: 'Vỏ lon nước giải khát tái chế',
      createdAt: DateTime.utc(2026, 10, 12, 8, 45),
    ),
    PointRecordEntry(
      className: '8A7',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 10.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 2,
      note: 'Chai nhựa tái chế',
      createdAt: DateTime.utc(2026, 10, 14, 9, 30),
    ),
    PointRecordEntry(
      className: '9A12',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 20.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 4,
      note: 'Chai nhựa lớp nộp đợt giữa tháng 10',
      createdAt: DateTime.utc(2026, 10, 16, 8, 15),
    ),

    // -------------------------------------------------------------
    // NHÓM B: 7 LỚP ĐẠT TẦM 5 - 6 ĐIỂM
    // -------------------------------------------------------------
    PointRecordEntry(
      className: '6A2',
      ruleId: ruleLon,
      categoryName: 'Lon nhôm',
      unit: 'Số lượng',
      quantity: 10.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 2,
      note: 'Vỏ lon nước ngọt nộp đợt 2',
      createdAt: DateTime.utc(2026, 10, 8, 9, 0),
    ),
    PointRecordEntry(
      className: '7A2',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 5.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 1,
      note: 'Chai nhựa dọn vệ sinh lớp',
      createdAt: DateTime.utc(2026, 10, 13, 8, 0),
    ),
    PointRecordEntry(
      className: '8A3',
      ruleId: ruleLon,
      categoryName: 'Lon nhôm',
      unit: 'Số lượng',
      quantity: 10.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 2,
      note: 'Vỏ lon thu gom sinh hoạt',
      createdAt: DateTime.utc(2026, 10, 15, 10, 30),
    ),
    PointRecordEntry(
      className: '9A2',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 10.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 2,
      note: 'Chai nhựa nước giải khát',
      createdAt: DateTime.utc(2026, 10, 17, 9, 15),
    ),
    PointRecordEntry(
      className: '8A8',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 25.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 5,
      note: 'Hưởng ứng phong trào nộp chai nhựa',
      createdAt: DateTime.utc(2026, 10, 10, 8, 30),
    ),
    PointRecordEntry(
      className: '8A9',
      ruleId: ruleLon,
      categoryName: 'Lon nhôm',
      unit: 'Số lượng',
      quantity: 25.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 5,
      note: 'Vỏ lon tái chế lớp 8A9',
      createdAt: DateTime.utc(2026, 10, 14, 14, 0),
    ),
    PointRecordEntry(
      className: '9A11',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 30.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 6,
      note: 'Chai nhựa dọn vệ sinh khuôn viên lớp',
      createdAt: DateTime.utc(2026, 10, 19, 8, 0),
    ),

    // -------------------------------------------------------------
    // NHÓM C: 3 LỚP ĐẠT TẦM 20 ĐIỂM (TOP 1 TOÀN TRƯỜNG & KHỐI)
    // -------------------------------------------------------------
    // Lớp 6A1 (đã có 7đ -> thêm 6đ + 7đ = 20đ)
    PointRecordEntry(
      className: '6A1',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 30.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 6,
      note: 'Chai nhựa thu gom tuần đầu tháng 10',
      createdAt: DateTime.utc(2026, 10, 5, 9, 30),
    ),
    PointRecordEntry(
      className: '6A1',
      ruleId: ruleLon,
      categoryName: 'Lon nhôm',
      unit: 'Số lượng',
      quantity: 35.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 7,
      note: 'Vỏ lon nhôm thi đua nước rút ngày 19/10',
      createdAt: DateTime.utc(2026, 10, 19, 9, 0),
    ),

    // Lớp 8A1 (đã có 7đ -> thêm 6đ + 7đ = 20đ)
    PointRecordEntry(
      className: '8A1',
      ruleId: ruleLon,
      categoryName: 'Lon nhôm',
      unit: 'Số lượng',
      quantity: 30.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 6,
      note: 'Vỏ lon nhôm đợt 1 tháng 10',
      createdAt: DateTime.utc(2026, 10, 8, 8, 15),
    ),
    PointRecordEntry(
      className: '8A1',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 35.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 7,
      note: 'Chai nhựa tái chế thi đua tuần 20/10',
      createdAt: DateTime.utc(2026, 10, 20, 8, 30),
    ),

    // Lớp 9A1 (đã có 6đ -> thêm 7đ + 7đ = 20đ)
    PointRecordEntry(
      className: '9A1',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 35.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 7,
      note: 'Chai nhựa thu gom khối 9 đợt 1 tháng 10',
      createdAt: DateTime.utc(2026, 10, 9, 8, 45),
    ),
    PointRecordEntry(
      className: '9A1',
      ruleId: ruleLon,
      categoryName: 'Lon nhôm',
      unit: 'Số lượng',
      quantity: 35.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 7,
      note: 'Vỏ lon nhôm tổng kết đợt 21/10',
      createdAt: DateTime.utc(2026, 10, 21, 9, 15),
    ),

    // -------------------------------------------------------------
    // NHÓM D: 19 LỚP CÒN LẠI RẢI RÁC TỪ 7 - 16 ĐIỂM
    // -------------------------------------------------------------
    // 7A1: 5đ + 6đ + 5đ = 16đ (Top 1 Khối 7)
    PointRecordEntry(
      className: '7A1',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 30.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 6,
      note: 'Chai nhựa tái chế đợt 1 tháng 10',
      createdAt: DateTime.utc(2026, 10, 6, 9, 30),
    ),
    PointRecordEntry(
      className: '7A1',
      ruleId: ruleLon,
      categoryName: 'Lon nhôm',
      unit: 'Số lượng',
      quantity: 25.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 5,
      note: 'Vỏ lon nhôm tuần sinh hoạt ngày 18/10',
      createdAt: DateTime.utc(2026, 10, 18, 8, 30),
    ),

    // 6A3: 6đ + 5đ + 4đ = 15đ
    PointRecordEntry(
      className: '6A3',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 25.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 5,
      note: 'Chai nhựa thu gom tuần 1 tháng 10',
      createdAt: DateTime.utc(2026, 10, 7, 8, 15),
    ),
    PointRecordEntry(
      className: '6A3',
      ruleId: ruleLon,
      categoryName: 'Lon nhôm',
      unit: 'Số lượng',
      quantity: 20.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 4,
      note: 'Vỏ lon nước tái chế',
      createdAt: DateTime.utc(2026, 10, 20, 10, 0),
    ),

    // 8A2: 5đ + 5đ + 4đ = 14đ
    PointRecordEntry(
      className: '8A2',
      ruleId: ruleLon,
      categoryName: 'Lon nhôm',
      unit: 'Số lượng',
      quantity: 25.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 5,
      note: 'Vỏ lon nhôm đợt 2 tháng 10',
      createdAt: DateTime.utc(2026, 10, 12, 9, 0),
    ),
    PointRecordEntry(
      className: '8A2',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 20.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 4,
      note: 'Chai nhựa tái chế lớp 8A2',
      createdAt: DateTime.utc(2026, 10, 21, 8, 15),
    ),

    // 9A3: 5đ + 5đ + 3đ = 13đ
    PointRecordEntry(
      className: '9A3',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 25.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 5,
      note: 'Chai nhựa thu gom giữa tháng 10',
      createdAt: DateTime.utc(2026, 10, 13, 9, 30),
    ),
    PointRecordEntry(
      className: '9A3',
      ruleId: rulePin,
      categoryName: 'Pin cũ',
      unit: 'Số lượng',
      quantity: 15.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 3,
      note: 'Thu gom pin cũ bảo vệ môi trường',
      createdAt: DateTime.utc(2026, 10, 22, 10, 0),
    ),

    // 6A6: 6đ + 6đ = 12đ
    PointRecordEntry(
      className: '6A6',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 30.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 6,
      note: 'Chai nhựa lớp nộp đợt 2',
      createdAt: DateTime.utc(2026, 10, 14, 8, 15),
    ),

    // 7A5: 6đ + 5đ = 11đ
    PointRecordEntry(
      className: '7A5',
      ruleId: ruleLon,
      categoryName: 'Lon nhôm',
      unit: 'Số lượng',
      quantity: 25.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 5,
      note: 'Vỏ lon tái chế',
      createdAt: DateTime.utc(2026, 10, 15, 8, 45),
    ),

    // 8A6: 6đ + 5đ = 11đ
    PointRecordEntry(
      className: '8A6',
      ruleId: ruleLon,
      categoryName: 'Lon nhôm',
      unit: 'Số lượng',
      quantity: 25.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 5,
      note: 'Lon nhôm thu gom tuần 3 tháng 10',
      createdAt: DateTime.utc(2026, 10, 16, 9, 15),
    ),

    // 9A6: 6đ + 5đ = 11đ
    PointRecordEntry(
      className: '9A6',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 25.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 5,
      note: 'Chai nhựa dọn lớp học',
      createdAt: DateTime.utc(2026, 10, 19, 10, 0),
    ),

    // 6A4: 5đ + 5đ = 10đ
    PointRecordEntry(
      className: '6A4',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 25.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 5,
      note: 'Chai nhựa tái chế ngày thứ 6',
      createdAt: DateTime.utc(2026, 10, 11, 8, 0),
    ),

    // 7A3: 5đ + 5đ = 10đ
    PointRecordEntry(
      className: '7A3',
      ruleId: ruleLon,
      categoryName: 'Lon nhôm',
      unit: 'Số lượng',
      quantity: 25.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 5,
      note: 'Vỏ lon nước giải khát tái chế',
      createdAt: DateTime.utc(2026, 10, 16, 14, 0),
    ),

    // 8A4: 5đ + 5đ = 10đ
    PointRecordEntry(
      className: '8A4',
      ruleId: ruleLon,
      categoryName: 'Lon nhôm',
      unit: 'Số lượng',
      quantity: 25.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 5,
      note: 'Vỏ lon nhôm thu gom đợt 2',
      createdAt: DateTime.utc(2026, 10, 18, 9, 45),
    ),

    // 9A4: 4đ + 5đ = 9đ
    PointRecordEntry(
      className: '9A4',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 25.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 5,
      note: 'Chai nhựa dọn vệ sinh phòng học',
      createdAt: DateTime.utc(2026, 10, 15, 9, 30),
    ),

    // 6A5: 5đ + 4đ = 9đ
    PointRecordEntry(
      className: '6A5',
      ruleId: ruleLon,
      categoryName: 'Lon nhôm',
      unit: 'Số lượng',
      quantity: 20.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 4,
      note: 'Vỏ lon nước giải khát',
      createdAt: DateTime.utc(2026, 10, 17, 8, 30),
    ),

    // 7A4: 5đ + 4đ = 9đ
    PointRecordEntry(
      className: '7A4',
      ruleId: rulePin,
      categoryName: 'Pin cũ',
      unit: 'Số lượng',
      quantity: 20.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 4,
      note: 'Thu gom pin cũ ngăn ô nhiễm',
      createdAt: DateTime.utc(2026, 10, 20, 8, 15),
    ),

    // 8A5: 5đ + 3đ = 8đ
    PointRecordEntry(
      className: '8A5',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 15.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 3,
      note: 'Chai nhựa nước giải khát',
      createdAt: DateTime.utc(2026, 10, 21, 10, 0),
    ),

    // 9A5: 5đ + 3đ = 8đ
    PointRecordEntry(
      className: '9A5',
      ruleId: ruleLon,
      categoryName: 'Lon nhôm',
      unit: 'Số lượng',
      quantity: 15.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 3,
      note: 'Lon nhôm tái chế đợt 2',
      createdAt: DateTime.utc(2026, 10, 22, 9, 0),
    ),

    // 9A8: 0đ + 4đ + 4đ = 8đ
    PointRecordEntry(
      className: '9A8',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 20.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 4,
      note: 'Chai nhựa thu gom đợt 1',
      createdAt: DateTime.utc(2026, 10, 11, 10, 0),
    ),
    PointRecordEntry(
      className: '9A8',
      ruleId: ruleLon,
      categoryName: 'Lon nhôm',
      unit: 'Số lượng',
      quantity: 20.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 4,
      note: 'Vỏ lon tái chế ngày 21/10',
      createdAt: DateTime.utc(2026, 10, 21, 14, 0),
    ),

    // 9A9: 0đ + 7đ = 7đ
    PointRecordEntry(
      className: '9A9',
      ruleId: ruleChai,
      categoryName: 'Chai nhựa',
      unit: 'Số lượng',
      quantity: 35.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 7,
      note: 'Chai nhựa khối 9 tổng gom giữa tháng 10',
      createdAt: DateTime.utc(2026, 10, 13, 8, 30),
    ),

    // 9A10: 0đ + 7đ = 7đ
    PointRecordEntry(
      className: '9A10',
      ruleId: ruleLon,
      categoryName: 'Lon nhôm',
      unit: 'Số lượng',
      quantity: 35.0,
      unitQuantity: 5,
      points: 1,
      totalPoints: 7,
      note: 'Vỏ lon nhôm phong trào kế hoạch nhỏ',
      createdAt: DateTime.utc(2026, 10, 17, 10, 30),
    ),
  ];

  print('--- BẮT ĐẦU TẠO ${records.length} PHIẾU TÍCH ĐIỂM THÁNG 10/2026 ---');
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
    print('  ✓ Lớp $cName: Trước $curPoints đ + Thêm $addedPts đ = $newTotalPoints đ (Cập nhật: $lastTimeIso)');
  }

  print('\n==================================================================');
  print('          HOÀN TẤT KHỞI TẠO DỮ LIỆU THÁNG 10 NĂM 2026!            ');
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
