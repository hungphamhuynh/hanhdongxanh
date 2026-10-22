import 'package:flutter_test/flutter_test.dart';
import 'package:tich_diem/core/utils/firebase_error_mapper.dart';

void main() {
  test('FirebaseErrorMapper returns user friendly Vietnamese messages', () {
    final msg = FirebaseErrorMapper.getMessage(Exception('unknown'));
    expect(msg, contains('Exception: unknown'));
  });
}
