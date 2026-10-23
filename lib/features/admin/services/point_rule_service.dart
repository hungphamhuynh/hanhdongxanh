import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/point_rule_history_model.dart';
import '../models/point_rule_model.dart';

class PointRuleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _rulesCollection =>
      _firestore.collection('point_rules');

  CollectionReference get _historyCollection =>
      _firestore.collection('point_rule_history');

  /// Lắng nghe danh sách thể loại đổi phế liệu theo thời gian thực
  Stream<List<PointRuleModel>> getPointRulesStream({bool onlyActive = false}) {
    return _rulesCollection.snapshots().map((snapshot) {
      var list = snapshot.docs
          .map((doc) => PointRuleModel.fromFirestore(doc))
          .toList();
      if (onlyActive) {
        list = list.where((r) => r.isActive).toList();
      }
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    });
  }

  /// Lắng nghe lịch sử thay đổi cấu hình điểm thưởng (toàn bộ hoặc theo thể loại)
  Stream<List<PointRuleHistoryModel>> getRuleHistoryStream({String? ruleId}) {
    Query query = _historyCollection;
    if (ruleId != null && ruleId.isNotEmpty) {
      query = query.where('ruleId', isEqualTo: ruleId);
    }
    return query.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => PointRuleHistoryModel.fromFirestore(doc))
          .toList();
      // Sắp xếp lịch sử mới nhất lên đầu
      list.sort((a, b) {
        final aTime = a.createdAt;
        final bTime = b.createdAt;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });
      return list;
    });
  }

  /// Thêm thể loại phế liệu mới và ghi nhật ký thay đổi
  Future<void> createPointRule({
    required String name,
    required String unit,
    int unitQuantity = 1,
    required int points,
    String description = '',
    String iconName = 'bottle',
    String changedByEmail = 'admin@nth.com',
    String changedByUid = '',
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw Exception('Tên thể loại phế liệu không được để trống!');
    }
    if (unitQuantity <= 0) {
      throw Exception('Số lượng đơn vị quy đổi phải lớn hơn 0!');
    }
    if (points <= 0) {
      throw Exception('Số điểm thưởng phải lớn hơn 0!');
    }

    final cleanUnit = unit.toLowerCase().contains('kg') ? 'Kg' : 'Số lượng';
    final cleanIcon = iconName.trim().isEmpty ? 'bottle' : iconName.trim();

    final newValues = {
      'name': cleanName,
      'unit': cleanUnit,
      'unitQuantity': unitQuantity,
      'points': points,
      'pointsPerUnit': points,
      'description': description.trim(),
      'iconName': cleanIcon,
      'isActive': true,
    };

    final docRef = await _rulesCollection.add(newValues);

    // Ghi nhật ký khởi tạo
    await _historyCollection.add({
      'ruleId': docRef.id,
      'ruleName': cleanName,
      'action': 'create',
      'oldValues': {},
      'newValues': newValues,
      'changedByEmail': changedByEmail,
      'changedByUid': changedByUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Cập nhật thể loại phế liệu và ghi nhật ký so sánh Cũ vs Mới
  Future<void> updatePointRule({
    required String id,
    required String name,
    required String unit,
    int unitQuantity = 1,
    required int points,
    String description = '',
    String iconName = 'bottle',
    PointRuleModel? oldRule,
    String changedByEmail = 'admin@nth.com',
    String changedByUid = '',
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw Exception('Tên thể loại phế liệu không được để trống!');
    }
    if (unitQuantity <= 0) {
      throw Exception('Số lượng đơn vị quy đổi phải lớn hơn 0!');
    }
    if (points <= 0) {
      throw Exception('Số điểm thưởng phải lớn hơn 0!');
    }

    final cleanUnit = unit.toLowerCase().contains('kg') ? 'Kg' : 'Số lượng';
    final cleanIcon = iconName.trim().isEmpty ? 'bottle' : iconName.trim();

    // 1. Thu thập dữ liệu cũ
    Map<String, dynamic> oldValues = {};
    if (oldRule != null) {
      oldValues = {
        'name': oldRule.name,
        'unit': oldRule.unit,
        'unitQuantity': oldRule.unitQuantity,
        'points': oldRule.points,
        'pointsPerUnit': oldRule.points,
        'description': oldRule.description,
        'iconName': oldRule.iconName,
      };
    } else {
      final oldDoc = await _rulesCollection.doc(id).get();
      if (oldDoc.exists) {
        final data = oldDoc.data() as Map<String, dynamic>? ?? {};
        oldValues = {
          'name': data['name'] ?? '',
          'unit': data['unit'] ?? '',
          'unitQuantity': data['unitQuantity'] ?? 1,
          'points': data['points'] ?? data['pointsPerUnit'] ?? 0,
          'pointsPerUnit': data['pointsPerUnit'] ?? 0,
          'description': data['description'] ?? '',
          'iconName': data['iconName'] ?? 'bottle',
        };
      }
    }

    final newValues = {
      'name': cleanName,
      'unit': cleanUnit,
      'unitQuantity': unitQuantity,
      'points': points,
      'pointsPerUnit': points,
      'description': description.trim(),
      'iconName': cleanIcon,
    };

    final batch = _firestore.batch();
    batch.update(_rulesCollection.doc(id), newValues);

    final historyRef = _historyCollection.doc();
    batch.set(historyRef, {
      'ruleId': id,
      'ruleName': cleanName,
      'action': 'update',
      'oldValues': oldValues,
      'newValues': newValues,
      'changedByEmail': changedByEmail,
      'changedByUid': changedByUid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Bật / Tắt trạng thái kích hoạt thể loại và ghi nhật ký
  Future<void> togglePointRuleActive({
    required String id,
    required bool currentActive,
    String ruleName = '',
    String changedByEmail = 'admin@nth.com',
    String changedByUid = '',
  }) async {
    final batch = _firestore.batch();
    batch.update(_rulesCollection.doc(id), {
      'isActive': !currentActive,
    });

    final historyRef = _historyCollection.doc();
    batch.set(historyRef, {
      'ruleId': id,
      'ruleName': ruleName,
      'action': 'toggle',
      'oldValues': {'isActive': currentActive},
      'newValues': {'isActive': !currentActive},
      'changedByEmail': changedByEmail,
      'changedByUid': changedByUid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Xóa thể loại phế liệu và ghi nhật ký
  Future<void> deletePointRule(
    String id, {
    String ruleName = '',
    PointRuleModel? oldRule,
    String changedByEmail = 'admin@nth.com',
    String changedByUid = '',
  }) async {
    final Map<String, dynamic> oldValues = oldRule != null
        ? {
            'name': oldRule.name,
            'unit': oldRule.unit,
            'pointsPerUnit': oldRule.pointsPerUnit,
            'description': oldRule.description,
            'iconName': oldRule.iconName,
          }
        : {'name': ruleName};

    final batch = _firestore.batch();
    batch.delete(_rulesCollection.doc(id));

    final historyRef = _historyCollection.doc();
    batch.set(historyRef, {
      'ruleId': id,
      'ruleName': ruleName.isNotEmpty ? ruleName : (oldRule?.name ?? ''),
      'action': 'delete',
      'oldValues': oldValues,
      'newValues': {},
      'changedByEmail': changedByEmail,
      'changedByUid': changedByUid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Khởi tạo 5 thể loại phế liệu mẫu chuẩn phong trào: Chai nhựa, Lon nhôm, Giấy vụn, Pin cũ, Bút viết cũ
  Future<void> seedDefaultEcoRules({bool overwrite = false}) async {
    final snapshot = await _rulesCollection.get();
    if (snapshot.docs.isNotEmpty && !overwrite) return; // Đã có dữ liệu và không yêu cầu ghi đè

    final defaultCategories = [
      {
        'name': 'Chai nhựa',
        'unit': 'Số lượng',
        'unitQuantity': 5,
        'points': 1,
        'pointsPerUnit': 1,
        'description': 'Thu gom vỏ chai nhựa các loại (5 chai = 1 điểm)',
        'iconName': 'bottle',
        'isActive': true,
      },
      {
        'name': 'Lon nhôm',
        'unit': 'Số lượng',
        'unitQuantity': 5,
        'points': 1,
        'pointsPerUnit': 1,
        'description': 'Vỏ lon nước giải khát bằng nhôm (5 lon = 1 điểm)',
        'iconName': 'can',
        'isActive': true,
      },
      {
        'name': 'Giấy vụn & Sách báo',
        'unit': 'Kg',
        'unitQuantity': 6,
        'points': 1,
        'pointsPerUnit': 1,
        'description': 'Giấy báo cũ, sách vở, bìa carton (6 kg = 1 điểm)',
        'iconName': 'paper',
        'isActive': true,
      },
      {
        'name': 'Pin cũ',
        'unit': 'Số lượng',
        'unitQuantity': 5,
        'points': 1,
        'pointsPerUnit': 1,
        'description': 'Pin đã qua sử dụng ngăn ô nhiễm môi trường (5 viên = 1 điểm)',
        'iconName': 'battery',
        'isActive': true,
      },
      {
        'name': 'Bút viết cũ',
        'unit': 'Số lượng',
        'unitQuantity': 5,
        'points': 1,
        'pointsPerUnit': 1,
        'description': 'Vỏ bút bi, bút dạ, bút viết đã hết mực (5 cây = 1 điểm)',
        'iconName': 'pen',
        'isActive': true,
      },
    ];

    final batch = _firestore.batch();
    if (overwrite && snapshot.docs.isNotEmpty) {
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
    }

    for (final item in defaultCategories) {
      final docRef = _rulesCollection.doc();
      batch.set(docRef, item);
    }
    await batch.commit();
  }
}
