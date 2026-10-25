import 'package:flutter_test/flutter_test.dart';
import 'package:tich_diem/core/utils/string_utils.dart';

void main() {
  group('StringUtils.compareNatural', () {
    test('sắp xếp đúng các lớp từ 6A1 đến 6A12 và các khối khác', () {
      final input = [
        '6A12',
        '6A2',
        '6A1',
        '6A10',
        '7A1',
        '6A11',
        '6B1',
        '6A9',
        '6A3',
        '9A12',
        '8A1',
      ];

      input.sort(StringUtils.compareNatural);

      expect(input, [
        '6A1',
        '6A2',
        '6A3',
        '6A9',
        '6A10',
        '6A11',
        '6A12',
        '6B1',
        '7A1',
        '8A1',
        '9A12',
      ]);
    });

    test('xử lý các định dạng lớp dạng dấu gạch chéo 6/1, 6/10', () {
      final input = ['6/10', '6/2', '6/1', '7/1'];
      input.sort(StringUtils.compareNatural);
      expect(input, ['6/1', '6/2', '6/10', '7/1']);
    });

    test('xử lý chuỗi rỗng và chuỗi giống nhau', () {
      expect(StringUtils.compareNatural('6A1', '6A1'), 0);
      expect(StringUtils.compareNatural('', '6A1'), -1);
      expect(StringUtils.compareNatural('6A1', ''), 1);
    });
  });
}
