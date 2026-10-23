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
        if (a.createdAt == null) return -1;
        if (b.createdAt == null) return 1;
        return b.createdAt!.compareTo(a.createdAt!);
      });
      return list;
    });
  }

  /// Thêm thể loại phế liệu mới và ghi nhật ký thay đổi
  Future<void> createPointRule({
    required String name,
    required String unit,
    required int pointsPerUnit,
    String description = '',
    String iconName = 'bottle',
    String changedByEmail = 'admin@nth.com',
    String changedByUid = '',
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw Exception('Tên thể loại phế liệu không được để trống!');
    }
    if (pointsPerUnit <= 0) {
      throw Exception('Số điểm thưởng phải lớn hơn 0!');
    }

    final cleanUnit = unit.toLowerCase().contains('kg') ? 'Kg' : 'Số lượng';
    final cleanIcon = iconName.trim().isEmpty ? 'bottle' : iconName.trim();

    final newValues = {
      'name': cleanName,
      'unit': cleanUnit,
      'pointsPerUnit': pointsPerUnit,
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
    required int pointsPerUnit,
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
    if (pointsPerUnit <= 0) {
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
        'pointsPerUnit': oldRule.pointsPerUnit,
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
          'pointsPerUnit': data['pointsPerUnit'] ?? 0,
          'description': data['description'] ?? '',
          'iconName': data['iconName'] ?? 'bottle',
        };
      }
    }

    final newValues = {
      'name': cleanName,
      'unit': cleanUnit,
      'pointsPerUnit': pointsPerUnit,
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

  /// Khởi tạo 4 thể loại phế liệu mẫu chuẩn phong trào: Chai nhựa, Lon nhôm, Giấy vụn, Pin cũ
  Future<void> seedDefaultEcoRules() async {
    final snapshot = await _rulesCollection.limit(1).get();
    if (snapshot.docs.isNotEmpty) return; // Đã có dữ liệu, không ghi đè

    final defaultCategories = [
      {
        'name': 'Chai nhựa',
        'unit': 'Số lượng',
        'pointsPerUnit': 2,
        'description': 'Thu gom vỏ chai nhựa nước uống các loại',
        'iconName': 'bottle',
        'isActive': true,
      },
      {
        'name': 'Lon nhôm',
        'unit': 'Số lượng',
        'pointsPerUnit': 3,
        'description': 'Vỏ lon nước giải khát, nước ngọt bằng nhôm',
        'iconName': 'can',
        'isActive': true,
      },
      {
        'name': 'Giấy vụn & Sách báo',
        'unit': 'Kg',
        'pointsPerUnit': 10,
        'description': 'Giấy báo cũ, sách vở đã qua sử dụng, thùng carton',
        'iconName': 'paper',
        'isActive': true,
      },
      {
        'name': 'Pin cũ',
        'unit': 'Số lượng',
        'pointsPerUnit': 5,
        'description': 'Thu gom pin đã qua sử dụng ngăn ô nhiễm môi trường',
        'iconName': 'battery',
        'isActive': true,
      },
    ];

    final batch = _firestore.batch();
    for (final item in defaultCategories) {
      final docRef = _rulesCollection.doc();
      batch.set(docRef, item);
    }
    await batch.commit();
  }
}
