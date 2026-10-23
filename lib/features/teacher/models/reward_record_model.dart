import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class RewardRecordModel {
  final String id;
  final String className;
  final String rewardId;
  final String rewardName;
  final String unit;
  final int quantity;
  final int pointsCost;
  final int totalPoints; // quantity * pointsCost
  final String note;
  final String status; // "pending", "approved", "rejected"
  final String rejectionReason;
  final String createdByEmail;
  final String createdByUid;
  final String? approvedByEmail;
  final String? approvedByUid;
  final DateTime? createdAt;
  final DateTime? resolvedAt;

  const RewardRecordModel({
    required this.id,
    required this.className,
    required this.rewardId,
    required this.rewardName,
    required this.unit,
    required this.quantity,
    required this.pointsCost,
    required this.totalPoints,
    this.note = '',
    this.status = 'pending',
    this.rejectionReason = '',
    required this.createdByEmail,
    required this.createdByUid,
    this.approvedByEmail,
    this.approvedByUid,
    this.createdAt,
    this.resolvedAt,
  });

  factory RewardRecordModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return RewardRecordModel(
      id: doc.id,
      className: data['className'] ?? '',
      rewardId: data['rewardId'] ?? '',
      rewardName: data['rewardName'] ?? '',
      unit: data['unit'] ?? 'Cái',
      quantity: (data['quantity'] as num?)?.toInt() ?? 1,
      pointsCost: (data['pointsCost'] as num?)?.toInt() ?? 0,
      totalPoints: (data['totalPoints'] as num?)?.toInt() ?? 0,
      note: data['note'] ?? '',
      status: data['status'] ?? 'pending',
      rejectionReason: data['rejectionReason'] ?? '',
      createdByEmail: data['createdByEmail'] ?? '',
      createdByUid: data['createdByUid'] ?? '',
      approvedByEmail: data['approvedByEmail'],
      approvedByUid: data['approvedByUid'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'className': className.trim().toUpperCase(),
      'rewardId': rewardId,
      'rewardName': rewardName.trim(),
      'unit': unit.trim(),
      'quantity': quantity,
      'pointsCost': pointsCost,
      'totalPoints': totalPoints,
      'note': note.trim(),
      'status': status,
      'rejectionReason': rejectionReason.trim(),
      'createdByEmail': createdByEmail.trim(),
      'createdByUid': createdByUid.trim(),
      'approvedByEmail': approvedByEmail,
      'approvedByUid': approvedByUid,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'resolvedAt': resolvedAt != null
          ? Timestamp.fromDate(resolvedAt!)
          : null,
    };
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  String get statusLabel {
    switch (status) {
      case 'approved':
        return 'Đã nhận quà';
      case 'rejected':
        return 'Đã từ chối';
      case 'pending':
      default:
        return 'Chờ duyệt';
    }
  }

  Color get statusColor {
    switch (status) {
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      case 'pending':
      default:
        return AppColors.warning;
    }
  }

  IconData get statusIcon {
    switch (status) {
      case 'approved':
        return Icons.check_circle_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      case 'pending':
      default:
        return Icons.hourglass_top_rounded;
    }
  }

  IconData get iconData {
    final lower = rewardName.toLowerCase();
    if (lower.contains('cây') || lower.contains('sen đá') || lower.contains('hoa')) {
      return Icons.yard_rounded;
    }
    if (lower.contains('vở') || lower.contains('sách') || lower.contains('tập')) {
      return Icons.menu_book_rounded;
    }
    if (lower.contains('bút') || lower.contains('viết')) {
      return Icons.edit_rounded;
    }
    if (lower.contains('bình') || lower.contains('nước')) {
      return Icons.water_drop_rounded;
    }
    if (lower.contains('cờ') || lower.contains('cúp') || lower.contains('thưởng')) {
      return Icons.emoji_events_rounded;
    }
    return Icons.card_giftcard_rounded;
  }
}
