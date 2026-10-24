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

  /// Chỉnh sửa lượt thu gom (cập nhật số lượng, tính lại điểm và bù trừ chênh lệch an toàn)
  Future<void> updateRecord({
    required PointRecordModel oldRecord,
    required double newQuantity,
    String newNote = '',
    required String updatedByEmail,
    required String updatedByUid,
  }) async {
    if (newQuantity <= 0) {
      throw Exception('Số lượng thu gom phải lớn hơn 0!');
    }

    final effectiveUnitQty =
        oldRecord.unitQuantity > 0 ? oldRecord.unitQuantity : 1;
    final calculatedNewPoints =
        ((newQuantity * oldRecord.points) / effectiveUnitQty).round();
    final deltaPoints = calculatedNewPoints - oldRecord.totalPoints;

    final cleanClass = oldRecord.className.trim().toUpperCase();
    final recordRef = _firestore.collection('point_records').doc(oldRecord.id);
    final classRef = _firestore.collection('classes').doc(cleanClass);

    await _firestore.runTransaction((transaction) async {
      final classSnap = await transaction.get(classRef);
      if (!classSnap.exists) {
        throw Exception('Lớp $cleanClass không tồn tại trong hệ thống!');
      }

      final classData = classSnap.data() ?? {};
      final currentPoints = (classData['totalPoints'] as num?)?.toInt() ?? 0;

      // Nếu chỉnh sửa làm giảm điểm (deltaPoints < 0), kiểm tra lớp có đủ điểm để khấu trừ không
      if (deltaPoints < 0 && currentPoints < -deltaPoints) {
        throw Exception(
            'Lớp $cleanClass hiện chỉ còn $currentPoints điểm, không đủ để giảm ${-deltaPoints} điểm (lớp đã sử dụng điểm này để đổi quà)!');
      }

      // 1. Cập nhật điểm chênh lệch vào lớp học
      if (deltaPoints != 0) {
        transaction.update(classRef, {
          'totalPoints': FieldValue.increment(deltaPoints),
          'lastRecordedAt': FieldValue.serverTimestamp(),
        });
      }

      // 2. Cập nhật phiếu thu gom trong point_records
      transaction.update(recordRef, {
        'quantity': newQuantity,
        'totalPoints': calculatedNewPoints,
        'note': newNote.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedByEmail': updatedByEmail.trim(),
        'updatedByUid': updatedByUid.trim(),
      });
    });
  }

  /// Hủy lượt tích điểm (thu hồi điểm lớp và kiểm tra chống âm điểm)
  Future<void> deleteRecord({
    required PointRecordModel record,
    required String userEmail,
    required String userUid,
  }) async {
    final cleanClass = record.className.trim().toUpperCase();
    final recordRef = _firestore.collection('point_records').doc(record.id);
    final classRef = _firestore.collection('classes').doc(cleanClass);

    await _firestore.runTransaction((transaction) async {
      final recordSnap = await transaction.get(recordRef);
      if (!recordSnap.exists) {
        throw Exception('Lượt thu gom này không còn tồn tại!');
      }

      final classSnap = await transaction.get(classRef);
      if (!classSnap.exists) {
        throw Exception('Lớp $cleanClass không tồn tại trong hệ thống!');
      }

      final classData = classSnap.data() ?? {};
      final currentPoints = (classData['totalPoints'] as num?)?.toInt() ?? 0;

      if (currentPoints < record.totalPoints) {
        throw Exception(
            'Lớp $cleanClass hiện chỉ còn $currentPoints điểm, không đủ để thu hồi ${record.totalPoints} điểm (lớp đã sử dụng điểm này để đổi quà)!');
      }

      // 1. Thu hồi lại số điểm của lượt nộp này
      transaction.update(classRef, {
        'totalPoints': FieldValue.increment(-record.totalPoints),
      });

      // 2. Xóa phiếu nộp khỏi point_records
      transaction.delete(recordRef);
    });
  }
}
