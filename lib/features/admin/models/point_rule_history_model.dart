import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class PointRuleHistoryModel {
  final String id;
  final String ruleId;
  final String ruleName;
  final String action; // "create", "update", "toggle", "delete"
  final Map<String, dynamic> oldValues;
  final Map<String, dynamic> newValues;
  final String changedByEmail;
  final String changedByUid;
  final DateTime? createdAt;

  const PointRuleHistoryModel({
    required this.id,
    required this.ruleId,
    required this.ruleName,
    required this.action,
    required this.oldValues,
    required this.newValues,
    required this.changedByEmail,
    required this.changedByUid,
    this.createdAt,
  });

  factory PointRuleHistoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PointRuleHistoryModel(
      id: doc.id,
      ruleId: data['ruleId'] ?? '',
      ruleName: data['ruleName'] ?? '',
      action: data['action'] ?? 'update',
      oldValues: (data['oldValues'] as Map<String, dynamic>?) ?? {},
      newValues: (data['newValues'] as Map<String, dynamic>?) ?? {},
      changedByEmail: data['changedByEmail'] ?? '',
      changedByUid: data['changedByUid'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ruleId': ruleId,
      'ruleName': ruleName,
      'action': action,
      'oldValues': oldValues,
      'newValues': newValues,
      'changedByEmail': changedByEmail,
      'changedByUid': changedByUid,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  String get actionLabel {
    switch (action) {
      case 'create':
        return 'Tạo mới';
      case 'update':
        return 'Chỉnh sửa';
      case 'toggle':
        final isActive = newValues['isActive'] as bool? ?? true;
        return isActive ? 'Kích hoạt lại' : 'Tạm ngừng';
      case 'delete':
        return 'Xóa thể loại';
      default:
        return 'Thay đổi';
    }
  }

  Color get actionColor {
    switch (action) {
      case 'create':
        return AppColors.success;
      case 'update':
        return AppColors.secondary;
      case 'toggle':
        return AppColors.warning;
      case 'delete':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData get actionIcon {
    switch (action) {
      case 'create':
        return Icons.add_circle_outline_rounded;
      case 'update':
        return Icons.edit_note_rounded;
      case 'toggle':
        final isActive = newValues['isActive'] as bool? ?? true;
        return isActive
            ? Icons.play_circle_outline_rounded
            : Icons.pause_circle_outline_rounded;
      case 'delete':
        return Icons.delete_outline_rounded;
      default:
        return Icons.history_rounded;
    }
  }

  /// Trả về danh sách chuỗi mô tả các trường đã thay đổi (Cũ -> Mới)
  List<String> get diffDetails {
    final List<String> details = [];

    if (action == 'create') {
      final name = newValues['name'] ?? ruleName;
      final unit = newValues['unit'] ?? 'Số lượng';
      final unitQty = newValues['unitQuantity'] ?? 1;
      final pts = newValues['points'] ?? newValues['pointsPerUnit'] ?? 1;
      details.add('Khởi tạo: "$name" ($unitQty $unit = $pts điểm)');
      return details;
    }

    if (action == 'delete') {
      final name = oldValues['name'] ?? ruleName;
      final unit = oldValues['unit'] ?? 'Số lượng';
      final unitQty = oldValues['unitQuantity'] ?? 1;
      final pts = oldValues['points'] ?? oldValues['pointsPerUnit'] ?? 1;
      details.add('Đã xóa: "$name" ($unitQty $unit = $pts điểm)');
      return details;
    }

    if (action == 'toggle') {
      final isActive = newValues['isActive'] as bool? ?? true;
      details.add(isActive ? 'Đã kích hoạt lại thể loại này' : 'Đã tạm ngừng áp dụng thể loại này');
      return details;
    }

    // Với action == 'update'
    if (oldValues.containsKey('name') &&
        newValues.containsKey('name') &&
        oldValues['name'] != newValues['name']) {
      details.add('Tên: "${oldValues['name']}" → "${newValues['name']}"');
    }

    if (oldValues.containsKey('unit') &&
        newValues.containsKey('unit') &&
        oldValues['unit'] != newValues['unit']) {
      details.add('Đơn vị: ${oldValues['unit']} → ${newValues['unit']}');
    }

    final oldQty = oldValues['unitQuantity'] ?? 1;
    final newQty = newValues['unitQuantity'] ?? 1;
    final oldPts = oldValues['points'] ?? oldValues['pointsPerUnit'] ?? 1;
    final newPts = newValues['points'] ?? newValues['pointsPerUnit'] ?? 1;
    final oldUnit = oldValues['unit'] ?? 'đơn vị';
    final newUnit = newValues['unit'] ?? 'đơn vị';

    if (oldQty != newQty || oldPts != newPts) {
      details.add('Tỷ lệ quy đổi: $oldQty $oldUnit = $oldPts đ → $newQty $newUnit = $newPts đ');
    }

    if (oldValues.containsKey('description') &&
        newValues.containsKey('description') &&
        oldValues['description'] != newValues['description']) {
      details.add('Mô tả quy đổi đã được cập nhật');
    }

    if (oldValues.containsKey('iconName') &&
        newValues.containsKey('iconName') &&
        oldValues['iconName'] != newValues['iconName']) {
      details.add('Biểu tượng nhận diện đã được đổi');
    }

    if (details.isEmpty) {
      details.add('Cập nhật thông tin cấu hình');
    }

    return details;
  }
}
