import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PointRuleModel {
  final String id;
  final String name; // Tên phế liệu (Chai nhựa, Lon nhôm, Giấy vụn, Pin cũ...)
  final String unit; // "Số lượng" hoặc "Kg"
  final int unitQuantity; // Số lượng đơn vị (Đầu 1: ví dụ 5 chai, 10 lon, 2 kg)
  final int points; // Số điểm nhận được tương ứng (Đầu 2: ví dụ 1 điểm, 5 điểm)
  final String description; // Mô tả quy đổi
  final String iconName; // "bottle", "battery", "can", "paper", "box"
  final bool isActive; // Trạng thái đang áp dụng hay tạm ngừng

  const PointRuleModel({
    required this.id,
    required this.name,
    required this.unit,
    this.unitQuantity = 1,
    required this.points,
    this.description = '',
    this.iconName = 'bottle',
    this.isActive = true,
  });

  /// Getter giữ tương thích ngược với code cũ
  int get pointsPerUnit => points;

  /// Công thức tính điểm từ số lượng thu gom theo tỷ lệ 2 đầu
  int calculatePoints(double quantity) {
    if (quantity <= 0 || unitQuantity <= 0) return 0;
    return ((quantity * points) / unitQuantity).round();
  }

  /// Chuỗi hiển thị tỷ lệ quy đổi (Ví dụ: "5 Số lượng = 1 điểm")
  String get ruleRateText => '$unitQuantity $unit = $points điểm';

  factory PointRuleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final unitQty = (data['unitQuantity'] as num?)?.toInt() ?? 1;
    final pts = (data['points'] as num?)?.toInt() ??
        (data['pointsPerUnit'] as num?)?.toInt() ??
        1;

    return PointRuleModel(
      id: doc.id,
      name: data['name'] ?? '',
      unit: data['unit'] ?? 'Số lượng',
      unitQuantity: unitQty > 0 ? unitQty : 1,
      points: pts > 0 ? pts : 1,
      description: data['description'] ?? '',
      iconName: data['iconName'] ?? 'bottle',
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name.trim(),
      'unit': unit.trim(),
      'unitQuantity': unitQuantity,
      'points': points,
      'pointsPerUnit': points, // Giữ tương thích ngược
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
        if (lower.contains('giay') ||
            lower.contains('giấy') ||
            lower.contains('sách') ||
            lower.contains('báo')) {
          return Icons.newspaper_rounded;
        }
        if (lower.contains('carton') ||
            lower.contains('thung') ||
            lower.contains('thùng')) {
          return Icons.inventory_2_rounded;
        }
        return Icons.local_drink_rounded;
    }
  }
}
