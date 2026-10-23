import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PointRuleModel {
  final String id;
  final String name; // "Vỏ chai" hoặc "Pin"
  final String unit; // "Số lượng" hoặc "Kg"
  final int pointsPerUnit; // Số điểm thưởng trên mỗi đơn vị
  final String description; // Mô tả quy đổi
  final String iconName; // "bottle" hoặc "battery"
  final bool isActive; // Trạng thái đang áp dụng hay tạm ngừng

  const PointRuleModel({
    required this.id,
    required this.name,
    required this.unit,
    required this.pointsPerUnit,
    this.description = '',
    this.iconName = 'bottle',
    this.isActive = true,
  });

  factory PointRuleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PointRuleModel(
      id: doc.id,
      name: data['name'] ?? '',
      unit: data['unit'] ?? 'Số lượng',
      pointsPerUnit: (data['pointsPerUnit'] as num?)?.toInt() ?? 1,
      description: data['description'] ?? '',
      iconName: data['iconName'] ?? 'bottle',
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name.trim(),
      'unit': unit.trim(),
      'pointsPerUnit': pointsPerUnit,
      'description': description.trim(),
      'iconName': iconName,
      'isActive': isActive,
    };
  }

  /// Chỉ 2 biểu tượng chuẩn sinh thái: Vỏ chai và Pin
  IconData get iconData {
    if (name.toLowerCase().contains('pin') || iconName == 'battery') {
      return Icons.battery_charging_full_rounded;
    }
    return Icons.local_drink_rounded;
  }
}
