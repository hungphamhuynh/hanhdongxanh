import 'package:cloud_firestore/cloud_firestore.dart';

/// Lưu trữ thông tin xếp hạng của một lớp tại thời điểm đóng sổ
class ClassRankSnapshot {
  final int rank;
  final String className;
  final int totalPoints;

  const ClassRankSnapshot({
    required this.rank,
    required this.className,
    required this.totalPoints,
  });

  factory ClassRankSnapshot.fromMap(Map<String, dynamic> map) {
    return ClassRankSnapshot(
      rank: (map['rank'] as num?)?.toInt() ?? 0,
      className: map['className'] as String? ?? '',
      totalPoints: (map['totalPoints'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'rank': rank,
      'className': className,
      'totalPoints': totalPoints,
    };
  }
}

/// Lưu trữ số lượng và đơn vị thu gom của từng danh mục phế liệu (ĐỘNG 100%)
class CategorySummarySnapshot {
  final String categoryName;
  final double quantity;
  final String unit;
  final int points;

  const CategorySummarySnapshot({
    required this.categoryName,
    required this.quantity,
    required this.unit,
    this.points = 0,
  });

  factory CategorySummarySnapshot.fromMap(
      String name, Map<String, dynamic> map) {
    return CategorySummarySnapshot(
      categoryName: name,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] as String? ?? '',
      points: (map['points'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'quantity': quantity,
      'unit': unit,
      'points': points,
    };
  }
}

/// Model niên khóa đã đóng sổ
class AcademicYearModel {
  final String id; // Ví dụ: "2025-2026"
  final String title; // Ví dụ: "Năm học 2025 - 2026"
  final DateTime? closedAt;
  final String closedByEmail;
  final String closedByUid;
  final int totalClasses;
  final int totalSchoolPoints;
  final List<ClassRankSnapshot> topClasses;
  final List<CategorySummarySnapshot> categorySummaries;

  const AcademicYearModel({
    required this.id,
    required this.title,
    this.closedAt,
    required this.closedByEmail,
    required this.closedByUid,
    required this.totalClasses,
    required this.totalSchoolPoints,
    required this.topClasses,
    required this.categorySummaries,
  });

  factory AcademicYearModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // 1. Parse top classes
    final rawTop = data['topClasses'] as List<dynamic>? ?? [];
    final parsedTop = rawTop
        .map((e) => ClassRankSnapshot.fromMap(e as Map<String, dynamic>))
        .toList();

    // 2. Parse category summaries động 100%
    final rawCategories =
        data['categorySummaries'] as Map<String, dynamic>? ?? {};
    final parsedCategories = rawCategories.entries.map((entry) {
      final val = entry.value as Map<String, dynamic>? ?? {};
      return CategorySummarySnapshot.fromMap(entry.key, val);
    }).toList();

    return AcademicYearModel(
      id: doc.id,
      title: data['title'] as String? ?? 'Năm học ${doc.id}',
      closedAt: (data['closedAt'] as Timestamp?)?.toDate(),
      closedByEmail: data['closedByEmail'] as String? ?? '',
      closedByUid: data['closedByUid'] as String? ?? '',
      totalClasses: (data['totalClasses'] as num?)?.toInt() ?? 0,
      totalSchoolPoints: (data['totalSchoolPoints'] as num?)?.toInt() ?? 0,
      topClasses: parsedTop,
      categorySummaries: parsedCategories,
    );
  }

  Map<String, dynamic> toMap() {
    final catMap = <String, dynamic>{};
    for (var cat in categorySummaries) {
      catMap[cat.categoryName] = cat.toMap();
    }

    return {
      'title': title,
      'closedAt': FieldValue.serverTimestamp(),
      'closedByEmail': closedByEmail,
      'closedByUid': closedByUid,
      'totalClasses': totalClasses,
      'totalSchoolPoints': totalSchoolPoints,
      'topClasses': topClasses.map((c) => c.toMap()).toList(),
      'categorySummaries': catMap,
    };
  }
}
