import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/point_rule_model.dart';

class PointRuleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _rulesCollection =>
      _firestore.collection('point_rules');

  /// Lắng nghe danh sách thể loại điểm thưởng theo thời gian thực
  Stream<List<PointRuleModel>> getPointRulesStream({bool onlyActive = false}) {
    Query query = _rulesCollection.orderBy('createdAt', descending: false);
    if (onlyActive) {
      query = query.where('isActive', isEqualTo: true);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => PointRuleModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Thêm thể loại tích điểm mới
  Future<void> createPointRule({
    required String name,
    required String unit,
    required int pointsPerUnit,
    String description = '',
    String iconName = 'eco',
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw Exception('Tên thể loại tích điểm không được để trống!');
    }
    if (pointsPerUnit <= 0) {
      throw Exception('Số điểm thưởng phải lớn hơn 0!');
    }

    await _rulesCollection.add({
      'name': cleanName,
      'unit': unit.trim().isEmpty ? 'lần' : unit.trim(),
      'pointsPerUnit': pointsPerUnit,
      'description': description.trim(),
      'iconName': iconName,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Cập nhật thể loại tích điểm
  Future<void> updatePointRule({
    required String id,
    required String name,
    required String unit,
    required int pointsPerUnit,
    String description = '',
    String iconName = 'eco',
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw Exception('Tên thể loại tích điểm không được để trống!');
    }
    if (pointsPerUnit <= 0) {
      throw Exception('Số điểm thưởng phải lớn hơn 0!');
    }

    await _rulesCollection.doc(id).update({
      'name': cleanName,
      'unit': unit.trim().isEmpty ? 'lần' : unit.trim(),
      'pointsPerUnit': pointsPerUnit,
      'description': description.trim(),
      'iconName': iconName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Bật / Tắt trạng thái kích hoạt thể loại
  Future<void> togglePointRuleActive({
    required String id,
    required bool currentActive,
  }) async {
    await _rulesCollection.doc(id).update({
      'isActive': !currentActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Xóa thể loại tích điểm
  Future<void> deletePointRule(String id) async {
    await _rulesCollection.doc(id).delete();
  }

  /// Khởi tạo các thể loại mẫu chuẩn phong trào "Hành Động Xanh"
  Future<void> seedDefaultEcoRules() async {
    final snapshot = await _rulesCollection.limit(1).get();
    if (snapshot.docs.isNotEmpty) return; // Đã có dữ liệu, không ghi đè

    final defaultCategories = [
      {
        'name': 'Pin cũ thu gom',
        'unit': 'viên',
        'pointsPerUnit': 5,
        'description': 'Thu gom pin đã qua sử dụng ngăn rò rỉ kim loại nặng',
        'iconName': 'battery',
      },
      {
        'name': 'Chai nhựa tái chế',
        'unit': 'chai',
        'pointsPerUnit': 2,
        'description': 'Chai nhựa nước khoáng, nước ngọt rửa sạch',
        'iconName': 'bottle',
      },
      {
        'name': 'Vỏ lon nhôm',
        'unit': 'lon',
        'pointsPerUnit': 3,
        'description': 'Vỏ lon nước giải khát, nước yến, sữa',
        'iconName': 'can',
      },
      {
        'name': 'Giấy vụn & Thùng carton',
        'unit': 'kg',
        'pointsPerUnit': 10,
        'description': 'Giấy báo cũ, sách vở không còn sử dụng, thùng carton',
        'iconName': 'paper',
      },
      {
        'name': 'Trồng & Chăm sóc cây xanh',
        'unit': 'cây',
        'pointsPerUnit': 20,
        'description': 'Trồng mới hoặc chăm sóc bồn hoa, cây cảnh sân trường',
        'iconName': 'tree',
      },
    ];

    final batch = _firestore.batch();
    for (final item in defaultCategories) {
      final docRef = _rulesCollection.doc();
      batch.set(docRef, {
        ...item,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }
}
