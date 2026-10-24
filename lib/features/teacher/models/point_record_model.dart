import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class PointRecordModel {
  final String id;
  final String className;
  final String ruleId;
  final String categoryName; // "Chai nhựa", "Lon nhôm", "Giấy vụn", "Pin cũ"...
  final String unit; // "Số lượng" hoặc "Kg"
  final double quantity; // Số lượng hoặc số kg đã đổi
  final int unitQuantity; // Số lượng đơn vị theo tỷ lệ (Đầu 1: ví dụ 5)
  final int points; // Số điểm nhận theo tỷ lệ (Đầu 2: ví dụ 1)
  final int pointsPerUnit; // Giữ để tương thích ngược
  final int totalPoints; // Tổng điểm nhận được
  final String note;
  final String createdByEmail;
  final String createdByUid;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? updatedByEmail;
  final String? updatedByUid;

  const PointRecordModel({
    required this.id,
    required this.className,
    required this.ruleId,
    required this.categoryName,
    required this.unit,
    required this.quantity,
    this.unitQuantity = 1,
    required this.points,
    required this.pointsPerUnit,
    required this.totalPoints,
    this.note = '',
    required this.createdByEmail,
    required this.createdByUid,
    this.createdAt,
    this.updatedAt,
    this.updatedByEmail,
    this.updatedByUid,
  });

  bool get isEdited => updatedAt != null;

  /// Chuỗi hiển thị tỷ lệ quy đổi (Ví dụ: "5 Số lượng = 1 điểm")
  String get ruleRateText => '$unitQuantity $unit = $points điểm';

  factory PointRecordModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final unitQty = (data['unitQuantity'] as num?)?.toInt() ?? 1;
    final pts = (data['points'] as num?)?.toInt() ??
        (data['pointsPerUnit'] as num?)?.toInt() ??
        0;

    return PointRecordModel(
      id: doc.id,
      className: data['className'] ?? '',
      ruleId: data['ruleId'] ?? '',
      categoryName: data['categoryName'] ?? '',
      unit: data['unit'] ?? 'Số lượng',
      quantity: (data['quantity'] as num?)?.toDouble() ?? 0.0,
      unitQuantity: unitQty > 0 ? unitQty : 1,
      points: pts,
      pointsPerUnit: (data['pointsPerUnit'] as num?)?.toInt() ?? pts,
      totalPoints: (data['totalPoints'] as num?)?.toInt() ?? 0,
      note: data['note'] ?? '',
      createdByEmail: data['createdByEmail'] ?? '',
      createdByUid: data['createdByUid'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      updatedByEmail: data['updatedByEmail'] as String?,
      updatedByUid: data['updatedByUid'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'className': className.trim(),
      'ruleId': ruleId.trim(),
      'categoryName': categoryName.trim(),
      'unit': unit.trim(),
      'quantity': quantity,
      'unitQuantity': unitQuantity,
      'points': points,
      'pointsPerUnit': pointsPerUnit,
      'totalPoints': totalPoints,
      'note': note.trim(),
      'createdByEmail': createdByEmail.trim(),
      'createdByUid': createdByUid.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      if (updatedAt != null) 'updatedAt': updatedAt,
      if (updatedByEmail != null) 'updatedByEmail': updatedByEmail,
      if (updatedByUid != null) 'updatedByUid': updatedByUid,
    };
  }

  bool get isBattery =>
      categoryName.toLowerCase().contains('pin') ||
      categoryName.toLowerCase().contains('battery');

  bool get isCan =>
      categoryName.toLowerCase().contains('lon') ||
      categoryName.toLowerCase().contains('nhôm') ||
      categoryName.toLowerCase().contains('can');

  bool get isPaper =>
      categoryName.toLowerCase().contains('giấy') ||
      categoryName.toLowerCase().contains('giay') ||
      categoryName.toLowerCase().contains('carton') ||
      categoryName.toLowerCase().contains('sách') ||
      categoryName.toLowerCase().contains('báo');

  bool get isPen =>
      categoryName.toLowerCase().contains('bút') ||
      categoryName.toLowerCase().contains('pen');

  bool get isKg => unit.toLowerCase().contains('kg');

  IconData get iconData {
    if (isBattery) return Icons.battery_charging_full_rounded;
    if (isCan) return Icons.recycling_rounded;
    if (isPaper) return Icons.newspaper_rounded;
    if (isPen) return Icons.edit_rounded;
    return Icons.eco_rounded;
  }

  Color get categoryColor {
    if (isBattery) return AppColors.warning;
    if (isCan) return AppColors.secondary;
    if (isPaper) return const Color(0xFF8D6E63);
    if (isPen) return const Color(0xFF7C3AED);
    return AppColors.primary;
  }
}
