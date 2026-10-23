import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/point_rule_model.dart';

class PointRuleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _rulesCollection =>
      _firestore.collection('point_rules');

  /// Lắng nghe danh sách thể loại điểm thưởng theo thời gian thực (chỉ Vỏ chai và Pin)
  Stream<List<PointRuleModel>> getPointRulesStream({bool onlyActive = false}) {
    return _rulesCollection.snapshots().map((snapshot) {
      var list = snapshot.docs
          .map((doc) => PointRuleModel.fromFirestore(doc))
          .toList();
      if (onlyActive) {
        list = list.where((r) => r.isActive).toList();
      }
      // Sắp xếp ổn định theo tên (Pin, Vỏ chai)
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    });
  }

  /// Thêm thể loại tích điểm mới (Vỏ chai / Pin, đơn vị: Số lượng / Kg)
  Future<void> createPointRule({
    required String name,
    required String unit,
    required int pointsPerUnit,
    String description = '',
    String iconName = 'bottle',
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw Exception('Tên thể loại tích điểm không được để trống!');
    }
    if (pointsPerUnit <= 0) {
      throw Exception('Số điểm thưởng phải lớn hơn 0!');
    }

    final cleanUnit = unit.toLowerCase().contains('kg') ? 'Kg' : 'Số lượng';
    final cleanIcon = cleanName.toLowerCase().contains('pin') ? 'battery' : 'bottle';

    await _rulesCollection.add({
      'name': cleanName,
      'unit': cleanUnit,
      'pointsPerUnit': pointsPerUnit,
      'description': description.trim(),
      'iconName': cleanIcon,
      'isActive': true,
    });
  }

  /// Cập nhật thể loại tích điểm
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
      throw Exception('Tên thể loại tích điểm không được để trống!');
    }
    if (pointsPerUnit <= 0) {
      throw Exception('Số điểm thưởng phải lớn hơn 0!');
    }

    final cleanUnit = unit.toLowerCase().contains('kg') ? 'Kg' : 'Số lượng';
    final cleanIcon = cleanName.toLowerCase().contains('pin') ? 'battery' : 'bottle';

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

  /// Xóa thể loại tích điểm
  Future<void> deletePointRule(String id) async {
    await _rulesCollection.doc(id).delete();
  }

  /// Khởi tạo 2 thể loại chuẩn sinh thái: Vỏ chai và Pin (đơn vị Số lượng)
  Future<void> seedDefaultEcoRules() async {
    final snapshot = await _rulesCollection.limit(1).get();
    if (snapshot.docs.isNotEmpty) return; // Đã có dữ liệu, không ghi đè

    final defaultCategories = [
      {
        'name': 'Vỏ chai',
        'unit': 'Số lượng',
        'pointsPerUnit': 2,
        'description': 'Thu gom vỏ chai nhựa tái chế',
        'iconName': 'bottle',
        'isActive': true,
      },
      {
        'name': 'Pin',
        'unit': 'Số lượng',
        'pointsPerUnit': 5,
        'description': 'Thu gom pin cũ đã qua sử dụng',
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
