import 'package:cloud_firestore/cloud_firestore.dart';

import '../../teacher/models/point_record_model.dart';

/// Model cấu hình năm học của hệ thống (lưu trong `system_settings/school_year_config`)
class SchoolYearConfigModel {
  /// Niên khóa mặc định của hệ thống
  static const String defaultAcademicYear = '2026-2027';

  /// Niên khóa đang vận hành (Ví dụ: "2026-2027")
  final String currentAcademicYear;

  /// Niên khóa vừa được đóng sổ gần nhất (nếu có)
  final String? lastClosedAcademicYear;

  /// Mốc thời gian bắt đầu năm học hiện tại (hoặc thời điểm đóng sổ năm trước)
  final DateTime? currentYearStartedAt;

  /// Thời điểm đóng sổ gần nhất
  final DateTime? lastClosedAt;

  const SchoolYearConfigModel({
    required this.currentAcademicYear,
    this.lastClosedAcademicYear,
    this.currentYearStartedAt,
    this.lastClosedAt,
  });

  factory SchoolYearConfigModel.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists || doc.data() == null) {
      return const SchoolYearConfigModel(currentAcademicYear: defaultAcademicYear);
    }

    final data = doc.data() as Map<String, dynamic>;
    final rawYear = data['currentAcademicYear'] as String?;

    return SchoolYearConfigModel(
      currentAcademicYear: (rawYear != null && rawYear.trim().isNotEmpty)
          ? rawYear.trim()
          : defaultAcademicYear,
      lastClosedAcademicYear: data['lastClosedAcademicYear'] as String?,
      currentYearStartedAt:
          (data['currentYearStartedAt'] as Timestamp?)?.toDate(),
      lastClosedAt: (data['lastClosedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Kiểm tra xem một lượt ghi điểm có thuộc niên khóa hiện hành không:
  /// 1. Nếu phiếu có `academicYearId`: so khớp trực tiếp với `currentAcademicYear`.
  /// 2. Nếu phiếu cũ chưa có `academicYearId` (tương thích ngược 100%):
  ///    - Nếu đã từng đóng sổ (`currentYearStartedAt != null`): so sánh `createdAt > currentYearStartedAt`.
  ///    - Nếu chưa từng đóng sổ (năm học đầu tiên của trường): mặc định thuộc năm học hiện tại.
  bool isRecordInCurrentYear(PointRecordModel rec) {
    if (rec.academicYearId.isNotEmpty) {
      return rec.academicYearId == currentAcademicYear;
    }
    if (currentYearStartedAt != null && rec.createdAt != null) {
      return rec.createdAt!.isAfter(currentYearStartedAt!);
    }
    // Nếu hệ thống chưa từng đóng sổ lần nào -> toàn bộ phiếu cũ thuộc niên khóa ban đầu
    return true;
  }
}
