import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/point_rule_model.dart';

class PointRuleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _rulesCollection =>
      _firestore.collection('point_rules');

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

  /// Thêm thể loại phế liệu mới (Chai, Pin, Lon, Giấy..., đơn vị: Số lượng / Kg)
  Future<void> createPointRule({
    required String name,
    required String unit,
    required int pointsPerUnit,
    String description = '',
    String iconName = 'bottle',
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

    await _rulesCollection.add({
      'name': cleanName,
      'unit': cleanUnit,
      'pointsPerUnit': pointsPerUnit,
      'description': description.trim(),
      'iconName': cleanIcon,
      'isActive': true,
    });
  }

  /// Cập nhật thể loại phế liệu
  Future<void> updatePointRule({
    required String id,
    required String name,
    required String unit,
    required int pointsPerUnit,
    String description = '',
    String iconName = 'bottle',
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

    await _rulesCollection.doc(id).update({
      'name': cleanName,
      'unit': cleanUnit,
      'pointsPerUnit': pointsPerUnit,
      'description': description.trim(),
      'iconName': cleanIcon,
    });
  }

  /// Bật / Tắt trạng thái kích hoạt thể loại
  Future<void> togglePointRuleActive({
    required String id,
    required bool currentActive,
  }) async {
    await _rulesCollection.doc(id).update({
      'isActive': !currentActive,
    });
  }

  /// Xóa thể loại phế liệu
  Future<void> deletePointRule(String id) async {
    await _rulesCollection.doc(id).delete();
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
