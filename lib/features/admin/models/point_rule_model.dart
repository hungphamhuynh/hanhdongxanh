import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PointRuleModel {
  final String id;
  final String name; // Tên phế liệu (tự do: Chai nhựa, Lon nhôm, Giấy vụn, Pin cũ...)
  final String unit; // "Số lượng" hoặc "Kg"
  final int pointsPerUnit; // Số điểm thưởng trên mỗi đơn vị
  final String description; // Mô tả quy đổi
  final String iconName; // "bottle", "battery", "can", "paper", "box"
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

  /// Biểu tượng nhận diện các loại phế liệu: Chai, Pin, Lon, Giấy, Carton
  IconData get iconData {
    switch (iconName) {
      case 'battery':
        return Icons.battery_charging_full_rounded;
      case 'can':
        return Icons.recycling_rounded;
      case 'paper':
        return Icons.newspaper_rounded;
      case 'box':
        return Icons.inventory_2_rounded;
      case 'bottle':
        return Icons.local_drink_rounded;
      default:
        final lower = name.toLowerCase();
        if (lower.contains('pin')) return Icons.battery_charging_full_rounded;
        if (lower.contains('lon')) return Icons.recycling_rounded;
        if (lower.contains('giay') || lower.contains('giấy') || lower.contains('sách') || lower.contains('báo')) {
          return Icons.newspaper_rounded;
        }
        if (lower.contains('carton') || lower.contains('thung') || lower.contains('thùng')) {
          return Icons.inventory_2_rounded;
        }
        return Icons.local_drink_rounded;
    }
  }
}
