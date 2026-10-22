import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PointRuleModel {
  final String id;
  final String name; // Ví dụ: "Pin cũ", "Chai nhựa", "Vỏ lon nhôm"...
  final String unit; // Đơn vị tính: "viên", "chai", "kg", "lon", "lần"...
  final int pointsPerUnit; // Số điểm thưởng trên mỗi đơn vị
  final String description; // Mô tả quy đổi
  final String iconName; // Tên mã icon
  final bool isActive; // Trạng thái đang áp dụng hay tạm ngừng
  final DateTime? createdAt;

  const PointRuleModel({
    required this.id,
    required this.name,
    required this.unit,
    required this.pointsPerUnit,
    this.description = '',
    this.iconName = 'eco',
    this.isActive = true,
    this.createdAt,
  });

  factory PointRuleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PointRuleModel(
      id: doc.id,
      name: data['name'] ?? '',
      unit: data['unit'] ?? 'lần',
      pointsPerUnit: (data['pointsPerUnit'] as num?)?.toInt() ?? 1,
      description: data['description'] ?? '',
      iconName: data['iconName'] ?? 'eco',
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
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
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  IconData get iconData {
    switch (iconName) {
      case 'battery':
      case 'battery_charging_full':
        return Icons.battery_charging_full_rounded;
      case 'bottle':
      case 'local_drink':
        return Icons.local_drink_rounded;
      case 'paper':
      case 'newspaper':
        return Icons.newspaper_rounded;
      case 'can':
      case 'recycling':
        return Icons.recycling_rounded;
      case 'tree':
      case 'park':
        return Icons.park_rounded;
      case 'volunteer':
      case 'volunteer_activism':
        return Icons.volunteer_activism_rounded;
      case 'eco':
      default:
        return Icons.eco_rounded;
    }
  }
}
