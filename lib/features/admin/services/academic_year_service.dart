import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/string_utils.dart';
import '../models/academic_year_model.dart';
import '../models/school_year_config_model.dart';

class AcademicYearService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Đếm số đơn đổi quà đang chờ duyệt (pending)
  Future<int> countPendingRewardOrders() async {
    final snap = await _firestore
        .collection('reward_records')
        .where('status', isEqualTo: 'pending')
        .get();
    return snap.docs.length;
  }

  /// Stream cấu hình năm học thời gian thực
  Stream<SchoolYearConfigModel> getSchoolYearConfigStream() {
    return _firestore
        .collection('system_settings')
        .doc('school_year_config')
        .snapshots()
        .map((doc) => SchoolYearConfigModel.fromFirestore(doc));
  }

  /// Lấy cấu hình năm học bất đồng bộ
  Future<SchoolYearConfigModel> getSchoolYearConfig() async {
    try {
      final doc = await _firestore
          .collection('system_settings')
          .doc('school_year_config')
          .get();
      return SchoolYearConfigModel.fromFirestore(doc);
    } catch (_) {
      final now = DateTime.now();
      final defaultYear = now.month >= 8
          ? '${now.year}-${now.year + 1}'
          : '${now.year - 1}-${now.year}';
      return SchoolYearConfigModel(currentAcademicYear: defaultYear);
    }
  }

  /// Lấy niên khóa hiện hành được cấu hình trong hệ thống
  Future<String> getCurrentAcademicYear() async {
    final config = await getSchoolYearConfig();
    return config.currentAcademicYear;
  }

  /// Stream danh sách các niên khóa đã đóng sổ trong quá khứ
  Stream<List<AcademicYearModel>> getPastAcademicYearsStream() {
    return _firestore
        .collection('academic_years')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => AcademicYearModel.fromFirestore(doc))
          .toList();

      list.sort((a, b) {
        final aTime = a.closedAt;
        final bTime = b.closedAt;
        if (aTime == null && bTime == null) return b.id.compareTo(a.id);
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      return list;
    });
  }

  /// Lấy dữ liệu xem trước (Preview) trước khi bấm xác nhận đóng sổ
  /// - [targetAcademicYear]: Niên khóa cần đóng sổ (nếu truyền vào)
  Future<Map<String, dynamic>> previewClosureData({
    String? targetAcademicYear,
  }) async {
    // 1. Kiểm tra đơn pending
    final pendingCount = await countPendingRewardOrders();

    // 2. Thu thập dữ liệu các lớp
    final classesSnap = await _firestore.collection('classes').get();
    final classDocs = classesSnap.docs;

    final List<Map<String, dynamic>> rawClassList = [];
    int totalSchoolPoints = 0;

    for (var doc in classDocs) {
      final data = doc.data();
      final className = (data['className'] as String? ?? doc.id).toUpperCase();
      final pts = (data['totalPoints'] as num?)?.toInt() ?? 0;
      totalSchoolPoints += pts;

      rawClassList.add({
        'className': className,
        'totalPoints': pts,
      });
    }

    // Sắp xếp thứ tự các lớp
    rawClassList.sort((a, b) {
      final cmp =
          (b['totalPoints'] as int).compareTo(a['totalPoints'] as int);
      if (cmp != 0) return cmp;
      return StringUtils.compareNatural(
        a['className'] as String,
        b['className'] as String,
      );
    });

    final List<ClassRankSnapshot> rankedSnapshots = [];
    for (int i = 0; i < rawClassList.length; i++) {
      rankedSnapshots.add(ClassRankSnapshot(
        rank: i + 1,
        className: rawClassList[i]['className'] as String,
        totalPoints: rawClassList[i]['totalPoints'] as int,
      ));
    }

    // 3. Tổng hợp danh mục phế liệu phát sinh ĐỘNG 100% từ point_records thuộc niên khóa cần đóng sổ
    final config = await getSchoolYearConfig();
    final effectiveYear = (targetAcademicYear != null && targetAcademicYear.trim().isNotEmpty)
        ? targetAcademicYear.trim()
        : config.currentAcademicYear;
    final lastClosedAt = config.lastClosedAt;

    final recordsSnap = await _firestore.collection('point_records').get();
    final Map<String, Map<String, dynamic>> categoryMap = {};

    for (var doc in recordsSnap.docs) {
      final data = doc.data();
      final recordYear = (data['academicYearId'] as String? ?? '').trim();
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

      // Kiểm tra tính hợp lệ của niên khóa (ưu tiên academicYearId, fallback mốc thời gian)
      final bool belongsToYear;
      if (recordYear.isNotEmpty) {
        belongsToYear = recordYear == effectiveYear;
      } else if (lastClosedAt != null && createdAt != null) {
        belongsToYear = createdAt.isAfter(lastClosedAt);
      } else {
        // Chưa có academicYearId và chưa từng có mốc đóng sổ trước đó -> thuộc niên khóa đầu tiên
        belongsToYear = true;
      }

      if (!belongsToYear) continue;

      final categoryName =
          (data['categoryName'] as String? ?? '').trim();
      if (categoryName.isEmpty) continue;

      final unit = (data['unit'] as String? ?? '').trim();
      final qty = (data['quantity'] as num?)?.toDouble() ?? 0.0;
      final pts = (data['totalPoints'] as num?)?.toInt() ?? 0;

      final current = categoryMap.putIfAbsent(
        categoryName,
        () => {
          'categoryName': categoryName,
          'quantity': 0.0,
          'unit': unit,
          'points': 0,
        },
      );

      current['quantity'] = (current['quantity'] as double) + qty;
      current['points'] = (current['points'] as int) + pts;
      if (unit.isNotEmpty) current['unit'] = unit;
    }

    final List<CategorySummarySnapshot> categorySummaries = categoryMap.entries
        .map((e) => CategorySummarySnapshot(
              categoryName: e.key,
              quantity: (e.value['quantity'] as num).toDouble(),
              unit: e.value['unit'] as String,
              points: e.value['points'] as int,
            ))
        .toList();

    return {
      'pendingCount': pendingCount,
      'totalClasses': classDocs.length,
      'totalSchoolPoints': totalSchoolPoints,
      'topClasses': rankedSnapshots,
      'categorySummaries': categorySummaries,
    };
  }

  /// Thực hiện Đóng Sổ & Chuyển Giao Năm Học:
  /// - Kiểm tra chặn nếu còn đơn đổi quà pending
  /// - Lưu Snapshot kết quả toàn trường vào academic_years/{academicYearId}
  /// - Cập nhật niên khóa hiện hành = nextAcademicYearId
  /// - Reset totalPoints = 0 cho toàn bộ các lớp trong collection classes
  Future<void> closeAcademicYear({
    required String academicYearId,
    required String nextAcademicYearId,
    required String userEmail,
    required String userUid,
  }) async {
    // 1. Kiểm tra an toàn đơn quà
    final pendingCount = await countPendingRewardOrders();
    if (pendingCount > 0) {
      throw Exception(
          'Hiện vẫn còn $pendingCount đơn đổi quà đang chờ duyệt! Vui lòng duyệt hoặc từ chối các đơn này trước khi đóng sổ năm học.');
    }

    final cleanYearId = academicYearId.trim();
    if (cleanYearId.isEmpty) {
      throw Exception('Vui lòng nhập mã niên khóa cần đóng sổ (ví dụ: 2025-2026)!');
    }

    // Kiểm tra xem niên khóa này đã từng đóng sổ chưa
    final existingDoc =
        await _firestore.collection('academic_years').doc(cleanYearId).get();
    if (existingDoc.exists) {
      throw Exception(
          'Niên khóa $cleanYearId đã được đóng sổ trước đó! Vui lòng chọn hoặc nhập mã niên khóa khác.');
    }

    // 2. Thu thập dữ liệu snapshot của riêng niên khóa đang đóng sổ
    final preview = await previewClosureData(targetAcademicYear: cleanYearId);
    final totalClasses = preview['totalClasses'] as int;
    final totalSchoolPoints = preview['totalSchoolPoints'] as int;
    final topClasses = preview['topClasses'] as List<ClassRankSnapshot>;
    final categorySummaries =
        preview['categorySummaries'] as List<CategorySummarySnapshot>;

    final yearModel = AcademicYearModel(
      id: cleanYearId,
      title: 'Năm học $cleanYearId',
      closedAt: DateTime.now(),
      closedByEmail: userEmail,
      closedByUid: userUid,
      totalClasses: totalClasses,
      totalSchoolPoints: totalSchoolPoints,
      topClasses: topClasses,
      categorySummaries: categorySummaries,
    );

    // 3. Thực hiện lưu Snapshot và Reset điểm qua Batch
    final classesSnap = await _firestore.collection('classes').get();
    final batch = _firestore.batch();

    // Lưu snapshot vào academic_years
    final yearRef = _firestore.collection('academic_years').doc(cleanYearId);
    batch.set(yearRef, yearModel.toMap());

    // Cập nhật cấu hình năm học mới & lưu mốc thời gian bắt đầu năm học mới
    final configRef =
        _firestore.collection('system_settings').doc('school_year_config');
    batch.set(
      configRef,
      {
        'currentAcademicYear': nextAcademicYearId.trim(),
        'lastClosedAcademicYear': cleanYearId,
        'lastClosedAt': FieldValue.serverTimestamp(),
        'currentYearStartedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedByEmail': userEmail.trim(),
        'updatedByUid': userUid.trim(),
      },
      SetOptions(merge: true),
    );

    // Reset totalPoints = 0 cho toàn bộ các lớp (giữ nguyên tài khoản, mã lớp, teacherEmail, teacherUid)
    for (var doc in classesSnap.docs) {
      batch.update(doc.reference, {
        'totalPoints': 0,
        'lastRecordedAt': null,
      });
    }

    await batch.commit();
  }
}
