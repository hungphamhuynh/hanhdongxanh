import 'package:flutter_test/flutter_test.dart';
import 'package:tich_diem/features/admin/models/school_year_config_model.dart';
import 'package:tich_diem/features/teacher/models/point_record_model.dart';

void main() {
  group('SchoolYearConfigModel Tests', () {
    const config = SchoolYearConfigModel(
      currentAcademicYear: '2025-2026',
      lastClosedAcademicYear: '2024-2025',
    );

    PointRecordModel createTestRecord({
      String academicYearId = '',
      DateTime? createdAt,
      double quantity = 10,
    }) {
      return PointRecordModel(
        id: 'rec_1',
        className: '6A1',
        ruleId: 'rule_1',
        categoryName: 'Chai nhựa',
        unit: 'Chai',
        quantity: quantity,
        points: 1,
        pointsPerUnit: 1,
        totalPoints: 10,
        academicYearId: academicYearId,
        createdByEmail: 'test@school.com',
        createdByUid: 'uid_1',
        createdAt: createdAt,
      );
    }

    test('isRecordInCurrentYear: khớp chính xác khi phiếu có academicYearId', () {
      final matchRecord = createTestRecord(academicYearId: '2025-2026');
      final pastRecord = createTestRecord(academicYearId: '2024-2025');

      expect(config.isRecordInCurrentYear(matchRecord), isTrue);
      expect(config.isRecordInCurrentYear(pastRecord), isFalse);
    });

    test(
        'isRecordInCurrentYear: phiếu cũ (chưa có academicYearId) lọc theo currentYearStartedAt',
        () {
      final configWithStartDate = SchoolYearConfigModel(
        currentAcademicYear: '2025-2026',
        lastClosedAcademicYear: '2024-2025',
        currentYearStartedAt: DateTime(2025, 8, 1),
      );

      // Phiếu cũ tạo trong năm học mới (sau mốc đóng sổ)
      final newRecord = createTestRecord(
        academicYearId: '',
        createdAt: DateTime(2025, 9, 15),
      );

      // Phiếu cũ tạo trong năm học cũ (trước mốc đóng sổ)
      final oldRecord = createTestRecord(
        academicYearId: '',
        createdAt: DateTime(2025, 5, 20),
      );

      expect(configWithStartDate.isRecordInCurrentYear(newRecord), isTrue);
      expect(configWithStartDate.isRecordInCurrentYear(oldRecord), isFalse);
    });

    test(
        'isRecordInCurrentYear: khi hệ thống chưa từng đóng sổ (năm đầu), toàn bộ phiếu cũ được tính',
        () {
      const initialConfig = SchoolYearConfigModel(
        currentAcademicYear: '2025-2026',
        currentYearStartedAt: null,
      );

      final legacyRecord = createTestRecord(
        academicYearId: '',
        createdAt: DateTime(2025, 3, 10),
      );

      expect(initialConfig.isRecordInCurrentYear(legacyRecord), isTrue);
    });
  });
}
