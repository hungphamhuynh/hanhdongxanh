import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class RewardRuleHistoryModel {
  final String id;
  final String ruleId;
  final String ruleName;
  final String action; // "create", "update", "toggle", "delete"
  final Map<String, dynamic> oldValues;
  final Map<String, dynamic> newValues;
  final String changedByEmail;
  final String changedByUid;
  final DateTime? createdAt;

  const RewardRuleHistoryModel({
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

  factory RewardRuleHistoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return RewardRuleHistoryModel(
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
        return isActive ? 'Mở lại' : 'Tạm hết quà';
      case 'delete':
        return 'Đã xóa';
      default:
        return 'Cập nhật';
    }
  }

  Color get actionColor {
    switch (action) {
      case 'create':
        return AppColors.success;
      case 'update':
        return AppColors.primary;
      case 'toggle':
        final isActive = newValues['isActive'] as bool? ?? true;
        return isActive ? AppColors.success : AppColors.warning;
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
        return Icons.edit_rounded;
      case 'toggle':
        final isActive = newValues['isActive'] as bool? ?? true;
        return isActive
            ? Icons.play_circle_outline_rounded
            : Icons.pause_circle_outline_rounded;
      case 'delete':
        return Icons.delete_outline_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  List<String> get diffDetails {
    final list = <String>[];
    if (action == 'create') {
      final unit = newValues['unit'] ?? 'Cái';
      final pts = newValues['pointsCost'] ?? 0;
      final desc = newValues['description'] ?? '';
      list.add('Thiết lập mức đổi: $pts điểm / $unit');
      if (desc.toString().isNotEmpty) {
        list.add('Mô tả: "$desc"');
      }
      return list;
    }

    if (action == 'delete') {
      final unit = oldValues['unit'] ?? '';
      final pts = oldValues['pointsCost'] ?? 0;
      list.add('Đã xóa món quà "$ruleName" (mức cũ: $pts điểm / $unit)');
      return list;
    }

    if (action == 'toggle') {
      final isActive = newValues['isActive'] as bool? ?? true;
      list.add(isActive
          ? 'Mở lại cho phép các lớp đổi món quà này'
          : 'Tạm ngừng / Khóa đổi món quà này (hết quà)');
      return list;
    }

    // So sánh các trường khi action == update
    final oldName = oldValues['name'];
    final newName = newValues['name'];
    if (oldName != null && newName != null && oldName != newName) {
      list.add('Tên quà: "$oldName" ➔ "$newName"');
    }

    final oldUnit = oldValues['unit'];
    final newUnit = newValues['unit'];
    if (oldUnit != null && newUnit != null && oldUnit != newUnit) {
      list.add('Đơn vị: $oldUnit ➔ $newUnit');
    }

    final oldPts = oldValues['pointsCost'];
    final newPts = newValues['pointsCost'];
    if (oldPts != null && newPts != null && oldPts != newPts) {
      list.add('Mức điểm đổi: $oldPts đ ➔ $newPts đ');
    }

    final oldDesc = oldValues['description'];
    final newDesc = newValues['description'];
    if (oldDesc != null && newDesc != null && oldDesc != newDesc) {
      list.add('Mô tả: "$newDesc"');
    }

    final oldIcon = oldValues['iconName'];
    final newIcon = newValues['iconName'];
    if (oldIcon != null && newIcon != null && oldIcon != newIcon) {
      list.add('Biểu tượng quà: $oldIcon ➔ $newIcon');
    }

    if (list.isEmpty) {
      list.add('Cập nhật thông tin phần thưởng');
    }

    return list;
  }
}
