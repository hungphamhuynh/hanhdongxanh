import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PointRuleModel {
  final String id;
  final String name; // Tên thể loại (tự do)
  final String unit; // "Số lượng" hoặc "Kg"
  final int pointsPerUnit; // Số điểm thưởng trên mỗi đơn vị
  final String description; // Mô tả quy đổi
  final String iconName; // Mã icon
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

  /// Trả về IconData tương ứng với mã icon đã chọn
  IconData get iconData {
    switch (iconName) {
      case 'battery':
        return Icons.battery_charging_full_rounded;
      case 'bottle':
        return Icons.local_drink_rounded;
      case 'can':
        return Icons.recycling_rounded;
      case 'paper':
        return Icons.newspaper_rounded;
      case 'box':
        return Icons.inventory_2_rounded;
      case 'tree':
        return Icons.park_rounded;
      case 'clean':
        return Icons.cleaning_services_rounded;
      case 'volunteer':
        return Icons.volunteer_activism_rounded;
      case 'star':
        return Icons.stars_rounded;
      case 'eco':
      default:
        if (name.toLowerCase().contains('pin')) {
          return Icons.battery_charging_full_rounded;
        }
        return Icons.local_drink_rounded;
    }
  }
}
