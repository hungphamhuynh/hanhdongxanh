import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class PointRecordModel {
  final String id;
  final String className;
  final String ruleId;
  final String categoryName; // "Vỏ chai" hoặc "Pin"
  final String unit; // "Số lượng" hoặc "Kg"
  final double quantity; // Số lượng hoặc số kg đã gom
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

  IconData get iconData =>
      isBattery ? Icons.battery_charging_full_rounded : Icons.local_drink_rounded;

  Color get categoryColor =>
      isBattery ? AppColors.warning : AppColors.primary;
}
