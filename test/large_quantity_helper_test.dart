import 'package:flutter_test/flutter_test.dart';
import 'package:tich_diem/core/widgets/large_quantity_confirm_dialog.dart';

void main() {
  group('LargeQuantityHelper Tests', () {
    test('isLargePointRecord: nhận diện chính xác các trường hợp thu gom lớn', () {
      // Dưới ngưỡng bình thường
      expect(
        LargeQuantityHelper.isLargePointRecord(
          quantity: 10,
          isKg: true,
          calculatedPoints: 20,
        ),
        isFalse,
      );
      expect(
        LargeQuantityHelper.isLargePointRecord(
          quantity: 50,
          isKg: false,
          calculatedPoints: 50,
        ),
        isFalse,
      );

      // Khối lượng kg >= 50
      expect(
        LargeQuantityHelper.isLargePointRecord(
          quantity: 50,
          isKg: true,
          calculatedPoints: 100,
        ),
        isTrue,
      );

      // Số lượng đếm >= 100
      expect(
        LargeQuantityHelper.isLargePointRecord(
          quantity: 100,
          isKg: false,
          calculatedPoints: 100,
        ),
        isTrue,
      );

      // Điểm quy đổi >= 300
      expect(
        LargeQuantityHelper.isLargePointRecord(
          quantity: 30,
          isKg: true,
          calculatedPoints: 300,
        ),
        isTrue,
      );
    });

    test('isLargeRewardOrder: nhận diện chính xác các trường hợp đổi quà lớn', () {
      // Đơn nhỏ bình thường
      expect(
        LargeQuantityHelper.isLargeRewardOrder(
          quantity: 2,
          totalPointsCost: 40,
          currentClassPoints: 500,
        ),
        isFalse,
      );

      // Số lượng đổi >= 10 món
      expect(
        LargeQuantityHelper.isLargeRewardOrder(
          quantity: 10,
          totalPointsCost: 100,
          currentClassPoints: 1000,
        ),
        isTrue,
      );

      // Tổng điểm trừ >= 300 điểm
      expect(
        LargeQuantityHelper.isLargeRewardOrder(
          quantity: 3,
          totalPointsCost: 300,
          currentClassPoints: 1000,
        ),
        isTrue,
      );

      // Tiêu hơn 70% số điểm của lớp khi chi phí >= 150
      expect(
        LargeQuantityHelper.isLargeRewardOrder(
          quantity: 4,
          totalPointsCost: 160,
          currentClassPoints: 200, // 160 / 200 = 80% > 70%
        ),
        isTrue,
      );
    });
  });
}
