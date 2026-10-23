import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/reward_rule_history_model.dart';
import '../models/reward_rule_model.dart';
import '../../teacher/models/reward_record_model.dart';

class RewardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _rulesCol => _firestore.collection('reward_rules');
  CollectionReference get _historyCol => _firestore.collection('reward_rule_history');
  CollectionReference get _recordsCol => _firestore.collection('reward_records');
  CollectionReference get _classesCol => _firestore.collection('classes');

  // ==========================================
  // CẤU HÌNH ĐỔI ĐIỂM (REWARD RULES)
  // ==========================================

  /// Lắng nghe danh sách phần thưởng đổi điểm
  Stream<List<RewardRuleModel>> getRewardRulesStream({bool activeOnly = false}) {
    Query query = _rulesCol;
    if (activeOnly) {
      query = query.where('isActive', isEqualTo: true);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => RewardRuleModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Lắng nghe lịch sử thay đổi cấu hình phần thưởng
  Stream<List<RewardRuleHistoryModel>> getRewardRuleHistoryStream({String? ruleId}) {
    Query query = _historyCol.orderBy('createdAt', descending: true);
    if (ruleId != null && ruleId.isNotEmpty) {
      query = query.where('ruleId', isEqualTo: ruleId);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => RewardRuleHistoryModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Thêm phần thưởng đổi điểm mới
  Future<void> createRewardRule({
    required String name,
    required String unit,
    required int pointsCost,
    String description = '',
    String iconName = 'gift',
    required String changedByEmail,
    required String changedByUid,
  }) async {
    if (pointsCost <= 0) {
      throw Exception('Số điểm đổi phải lớn hơn 0!');
    }

    final docRef = _rulesCol.doc();
    final newRule = RewardRuleModel(
      id: docRef.id,
      name: name,
      unit: unit,
      pointsCost: pointsCost,
      description: description,
      iconName: iconName,
      isActive: true,
    );

    final batch = _firestore.batch();
    batch.set(docRef, newRule.toMap());

    final historyRef = _historyCol.doc();
    batch.set(historyRef, {
      'ruleId': docRef.id,
      'ruleName': name.trim(),
      'action': 'create',
      'oldValues': {},
      'newValues': newRule.toMap(),
      'changedByEmail': changedByEmail.trim(),
      'changedByUid': changedByUid.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Chỉnh sửa thông tin phần thưởng đổi điểm
  Future<void> updateRewardRule({
    required String id,
    required String name,
    required String unit,
    required int pointsCost,
    String description = '',
    String iconName = 'gift',
    required RewardRuleModel oldRule,
    required String changedByEmail,
    required String changedByUid,
  }) async {
    if (pointsCost <= 0) {
      throw Exception('Số điểm đổi phải lớn hơn 0!');
    }

    final docRef = _rulesCol.doc(id);
    final updatedData = {
      'name': name.trim(),
      'unit': unit.trim(),
      'pointsCost': pointsCost,
      'description': description.trim(),
      'iconName': iconName,
      'isActive': oldRule.isActive,
    };

    final batch = _firestore.batch();
    batch.update(docRef, updatedData);

    final historyRef = _historyCol.doc();
    batch.set(historyRef, {
      'ruleId': id,
      'ruleName': name.trim(),
      'action': 'update',
      'oldValues': oldRule.toMap(),
      'newValues': updatedData,
      'changedByEmail': changedByEmail.trim(),
      'changedByUid': changedByUid.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Bật / Tắt trạng thái áp dụng phần thưởng
  Future<void> toggleRewardRuleActive({
    required String id,
    required bool currentActive,
    required RewardRuleModel oldRule,
    required String changedByEmail,
    required String changedByUid,
  }) async {
    final nextActive = !currentActive;
    final batch = _firestore.batch();

    batch.update(_rulesCol.doc(id), {'isActive': nextActive});

    final historyRef = _historyCol.doc();
    batch.set(historyRef, {
      'ruleId': id,
      'ruleName': oldRule.name,
      'action': 'toggle',
      'oldValues': {'isActive': currentActive},
      'newValues': {'isActive': nextActive},
      'changedByEmail': changedByEmail.trim(),
      'changedByUid': changedByUid.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Xóa phần thưởng đổi điểm
  Future<void> deleteRewardRule(
    String id, {
    required String ruleName,
    required RewardRuleModel oldRule,
    required String changedByEmail,
    required String changedByUid,
  }) async {
    final batch = _firestore.batch();
    batch.delete(_rulesCol.doc(id));

    final historyRef = _historyCol.doc();
    batch.set(historyRef, {
      'ruleId': id,
      'ruleName': ruleName,
      'action': 'delete',
      'oldValues': oldRule.toMap(),
      'newValues': {},
      'changedByEmail': changedByEmail.trim(),
      'changedByUid': changedByUid.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Khởi tạo 4 phần thưởng mẫu ban đầu
  Future<void> seedDefaultRewardRules({
    String changedByEmail = 'admin@nth.com',
    String changedByUid = 'system',
  }) async {
    final sampleRewards = [
      {
        'name': 'Chậu sen đá mini',
        'unit': 'Chậu',
        'pointsCost': 30,
        'description': 'Cây xanh để bàn học tập rèn luyện lối sống xanh',
        'iconName': 'plant',
      },
      {
        'name': 'Tập vở học sinh tái chế',
        'unit': 'Cuốn',
        'pointsCost': 15,
        'description': 'Vở 96 trang sản xuất từ giấy tái chế thân thiện môi trường',
        'iconName': 'book',
      },
      {
        'name': 'Bộ bút bi xanh bảo vệ môi trường',
        'unit': 'Bộ',
        'pointsCost': 20,
        'description': 'Bộ 3 bút bi mực xanh chất lượng cao',
        'iconName': 'pen',
      },
      {
        'name': 'Bình nước giữ nhiệt sinh thái',
        'unit': 'Cái',
        'pointsCost': 60,
        'description': 'Bình nước cá nhân 500ml hạn chế sử dụng chai nhựa 1 lần',
        'iconName': 'bottle',
      },
    ];

    for (final item in sampleRewards) {
      await createRewardRule(
        name: item['name'] as String,
        unit: item['unit'] as String,
        pointsCost: item['pointsCost'] as int,
        description: item['description'] as String,
        iconName: item['iconName'] as String,
        changedByEmail: changedByEmail,
        changedByUid: changedByUid,
      );
    }
  }

  // ==========================================
  // QUY TRÌNH ĐỔI ĐIỂM: LÊN ĐƠN & DUYỆT ĐƠN
  // ==========================================

  /// 1. Giáo viên chủ nhiệm LÊN ĐƠN đổi quà cho lớp
  Future<void> createRewardOrder({
    required String className,
    required RewardRuleModel rule,
    required int quantity,
    String note = '',
    required String createdByEmail,
    required String createdByUid,
  }) async {
    if (quantity <= 0) {
      throw Exception('Số lượng đổi phải lớn hơn 0!');
    }

    final cleanClass = className.trim().toUpperCase();
    final classDoc = await _classesCol.doc(cleanClass).get();
    if (!classDoc.exists) {
      throw Exception('Lớp $cleanClass không tồn tại trong hệ thống!');
    }

    final classData = classDoc.data() as Map<String, dynamic>? ?? {};
    final currentPoints = (classData['totalPoints'] as num?)?.toInt() ?? 0;
    final totalCost = quantity * rule.pointsCost;

    if (currentPoints < totalCost) {
      throw Exception('Điểm hiện tại của lớp ($currentPoints đ) không đủ để đổi ($totalCost đ)!');
    }

    final recordRef = _recordsCol.doc();
    final newRecord = RewardRecordModel(
      id: recordRef.id,
      className: cleanClass,
      rewardId: rule.id,
      rewardName: rule.name,
      unit: rule.unit,
      quantity: quantity,
      pointsCost: rule.pointsCost,
      totalPoints: totalCost,
      note: note.trim(),
      status: 'pending',
      createdByEmail: createdByEmail.trim(),
      createdByUid: createdByUid.trim(),
    );

    await recordRef.set(newRecord.toMap());
  }

  /// 2. Tổng phụ trách DUYỆT & TRAO QUÀ (Trừ điểm lớp thi đua)
  Future<void> approveRewardOrder({
    required String orderId,
    required String approvedByEmail,
    required String approvedByUid,
  }) async {
    await _firestore.runTransaction((transaction) async {
      final orderRef = _recordsCol.doc(orderId);
      final orderSnap = await transaction.get(orderRef);
      if (!orderSnap.exists) {
        throw Exception('Phiếu đổi quà không tồn tại!');
      }

      final orderData = orderSnap.data() as Map<String, dynamic>;
      final status = orderData['status'] as String? ?? 'pending';
      if (status != 'pending') {
        throw Exception('Phiếu đổi quà này đã được xử lý từ trước!');
      }

      final className = (orderData['className'] as String? ?? '').trim().toUpperCase();
      final totalPointsToDeduct = (orderData['totalPoints'] as num?)?.toInt() ?? 0;

      final classRef = _classesCol.doc(className);
      final classSnap = await transaction.get(classRef);
      if (!classSnap.exists) {
        throw Exception('Lớp $className không tồn tại!');
      }

      final classData = classSnap.data() as Map<String, dynamic>;
      final currentPoints = (classData['totalPoints'] as num?)?.toInt() ?? 0;

      if (currentPoints < totalPointsToDeduct) {
        throw Exception(
            'Lớp $className hiện chỉ còn $currentPoints điểm, không đủ $totalPointsToDeduct điểm để duyệt!');
      }

      // 1. Trừ điểm của lớp
      transaction.update(classRef, {
        'totalPoints': FieldValue.increment(-totalPointsToDeduct),
        'totalPointsRedeemed': FieldValue.increment(totalPointsToDeduct),
        'lastRedeemedAt': FieldValue.serverTimestamp(),
      });

      // 2. Cập nhật phiếu đổi quà thành đã duyệt & trao quà
      transaction.update(orderRef, {
        'status': 'approved',
        'approvedByEmail': approvedByEmail.trim(),
        'approvedByUid': approvedByUid.trim(),
        'resolvedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// 3. Tổng phụ trách TỪ CHỐI ĐƠN (Hết hàng / Lý do khác, không trừ điểm)
  Future<void> rejectRewardOrder({
    required String orderId,
    required String rejectionReason,
    required String rejectedByEmail,
    required String rejectedByUid,
  }) async {
    final orderRef = _recordsCol.doc(orderId);
    final orderSnap = await orderRef.get();
    if (!orderSnap.exists) {
      throw Exception('Phiếu đổi quà không tồn tại!');
    }

    final data = orderSnap.data() as Map<String, dynamic>;
    if (data['status'] != 'pending') {
      throw Exception('Phiếu đổi quà này đã được xử lý từ trước!');
    }

    await orderRef.update({
      'status': 'rejected',
      'rejectionReason': rejectionReason.trim(),
      'approvedByEmail': rejectedByEmail.trim(),
      'approvedByUid': rejectedByUid.trim(),
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stream danh sách đơn đổi quà RIÊNG CỦA MỘT LỚP
  Stream<List<RewardRecordModel>> getRewardRecordsByClassStream(String className) {
    return _recordsCol
        .where('className', isEqualTo: className.trim().toUpperCase())
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => RewardRecordModel.fromFirestore(doc))
          .toList();
      list.sort((a, b) {
        if (a.createdAt == null) return -1;
        if (b.createdAt == null) return 1;
        return b.createdAt!.compareTo(a.createdAt!);
      });
      return list;
    });
  }

  /// Stream các đơn ĐANG CHỜ DUYỆT (Dành cho Tổng phụ trách)
  Stream<List<RewardRecordModel>> getPendingOrdersStream() {
    return _recordsCol
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => RewardRecordModel.fromFirestore(doc))
          .toList();
      list.sort((a, b) {
        if (a.createdAt == null) return -1;
        if (b.createdAt == null) return 1;
        return b.createdAt!.compareTo(a.createdAt!);
      });
      return list;
    });
  }

  /// Stream tất cả các đơn đổi quà TOÀN TRƯỜNG
  Stream<List<RewardRecordModel>> getAllRewardRecordsStream() {
    return _recordsCol.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => RewardRecordModel.fromFirestore(doc))
          .toList();
      list.sort((a, b) {
        if (a.createdAt == null) return -1;
        if (b.createdAt == null) return 1;
        return b.createdAt!.compareTo(a.createdAt!);
      });
      return list;
    });
  }
}
