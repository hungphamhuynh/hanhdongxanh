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
  final int pointsPerUnit; // Điểm quy đổi trên 1 đơn vị
  final int totalPoints; // Tổng điểm nhận được
  final String note;
  final String createdByEmail;
  final String createdByUid;
  final DateTime? createdAt;

  const PointRecordModel({
    required this.id,
    required this.className,
    required this.ruleId,
    required this.categoryName,
    required this.unit,
    required this.quantity,
    required this.pointsPerUnit,
    required this.totalPoints,
    this.note = '',
    required this.createdByEmail,
    required this.createdByUid,
    this.createdAt,
  });

  factory PointRecordModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PointRecordModel(
      id: doc.id,
      className: data['className'] ?? '',
      ruleId: data['ruleId'] ?? '',
      categoryName: data['categoryName'] ?? '',
      unit: data['unit'] ?? 'Số lượng',
      quantity: (data['quantity'] as num?)?.toDouble() ?? 0.0,
      pointsPerUnit: (data['pointsPerUnit'] as num?)?.toInt() ?? 0,
      totalPoints: (data['totalPoints'] as num?)?.toInt() ?? 0,
      note: data['note'] ?? '',
      createdByEmail: data['createdByEmail'] ?? '',
      createdByUid: data['createdByUid'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'className': className.trim(),
      'ruleId': ruleId.trim(),
      'categoryName': categoryName.trim(),
      'unit': unit.trim(),
      'quantity': quantity,
      'pointsPerUnit': pointsPerUnit,
      'totalPoints': totalPoints,
      'note': note.trim(),
      'createdByEmail': createdByEmail.trim(),
      'createdByUid': createdByUid.trim(),
      'createdAt': FieldValue.serverTimestamp(),
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

  IconData get iconData {
    if (isBattery) return Icons.battery_charging_full_rounded;
    if (isCan) return Icons.recycling_rounded;
    if (isPaper) return Icons.newspaper_rounded;
    return Icons.local_drink_rounded;
  }

  Color get categoryColor {
    if (isBattery) return AppColors.warning;
    if (isCan) return AppColors.secondary;
    if (isPaper) return const Color(0xFF8D6E63);
    return AppColors.primary;
  }
}
