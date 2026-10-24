import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RewardRuleModel {
  final String id;
  final String name; // Tên quà tặng (Chậu cây xanh, Tập vở học sinh, Bình giữ nhiệt...)
  final String unit; // "Cái", "Quyển", "Chậu", "Bộ", "Suất"...
  final int pointsCost; // Số điểm cần đổi trên mỗi đơn vị quà
  final String description; // Mô tả phần thưởng
  final String iconName; // "gift", "plant", "book", "pen", "cup", "star"
  final bool isActive; // Đang cho đổi hay tạm hết/tạm dừng

  const RewardRuleModel({
    required this.id,
    required this.name,
    required this.unit,
    required this.pointsCost,
    this.description = '',
    this.iconName = 'gift',
    this.isActive = true,
  });

  factory RewardRuleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return RewardRuleModel(
      id: doc.id,
      name: data['name'] ?? '',
      unit: data['unit'] ?? 'Cái',
      pointsCost: (data['pointsCost'] as num?)?.toInt() ?? 10,
      description: data['description'] ?? '',
      iconName: data['iconName'] ?? 'gift',
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name.trim(),
      'unit': unit.trim(),
      'pointsCost': pointsCost,
      'description': description.trim(),
      'iconName': iconName,
      'isActive': isActive,
    };
  }

  IconData get iconData {
    switch (iconName) {
      case 'plant':
        return Icons.yard_rounded;
      case 'book':
        return Icons.menu_book_rounded;
      case 'pen':
        return Icons.edit_rounded;
      case 'cup':
        return Icons.emoji_events_rounded;
      case 'star':
        return Icons.stars_rounded;
      case 'bottle':
        return Icons.water_drop_rounded;
      case 'gift':
      default:
        return Icons.card_giftcard_rounded;
    }
  }
}
