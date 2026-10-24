import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/point_record_model.dart';

class PointRecordService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream danh sách các lượt đổi phế liệu lấy điểm của một lớp cụ thể
  Stream<List<PointRecordModel>> getRecordsByClassStream(String className) {
    return _firestore
        .collection('point_records')
        .where('className', isEqualTo: className.trim().toUpperCase())
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => PointRecordModel.fromFirestore(doc))
          .toList();
      // Sắp xếp thời gian giảm dần (mới nhất lên đầu)
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

  /// Thực hiện đổi phế liệu lấy điểm và cập nhật tổng điểm lớp học
  Future<void> recordPoints({
    required String className,
    required String ruleId,
    required String categoryName,
    required String unit,
    required double quantity,
    int unitQuantity = 1,
    int? points,
    int? pointsPerUnit,
    String note = '',
    required String createdByEmail,
    required String createdByUid,
  }) async {
    final cleanClass = className.trim().toUpperCase();
    final effectiveUnitQty = unitQuantity > 0 ? unitQuantity : 1;
    final effectivePoints = points ?? pointsPerUnit ?? 0;
    final calculatedPoints =
        ((quantity * effectivePoints) / effectiveUnitQty).round();

    final recordRef = _firestore.collection('point_records').doc();
    final classRef = _firestore.collection('classes').doc(cleanClass);

    final batch = _firestore.batch();

    // 1. Tạo bản ghi chi tiết trong collection point_records (Mỗi giao dịch là 1 document riêng biệt)
    batch.set(recordRef, {
      'className': cleanClass,
      'ruleId': ruleId,
      'categoryName': categoryName,
      'unit': unit,
      'quantity': quantity,
      'unitQuantity': effectiveUnitQty,
      'points': effectivePoints,
      'pointsPerUnit': effectivePoints,
      'totalPoints': calculatedPoints,
      'note': note.trim(),
      'createdByEmail': createdByEmail.trim(),
      'createdByUid': createdByUid.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Chỉ cập nhật tổng điểm thi đua và thời gian ghi nhận của lớp trong collection classes
    final Map<String, dynamic> classUpdates = {
      'totalPoints': FieldValue.increment(calculatedPoints),
      'lastRecordedAt': FieldValue.serverTimestamp(),
    };

    batch.set(classRef, classUpdates, SetOptions(merge: true));
    await batch.commit();
  }

  /// Xóa lượt tích điểm (hoàn tác điểm nếu nhập nhầm)
  Future<void> deleteRecord(PointRecordModel record) async {
    final recordRef = _firestore.collection('point_records').doc(record.id);
    final classRef = _firestore.collection('classes').doc(record.className);

    final batch = _firestore.batch();
    batch.delete(recordRef);

    final Map<String, dynamic> classUpdates = {
      'totalPoints': FieldValue.increment(-record.totalPoints),
    };

    batch.set(classRef, classUpdates, SetOptions(merge: true));
    await batch.commit();
  }
}
