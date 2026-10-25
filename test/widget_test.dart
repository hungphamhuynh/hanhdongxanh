import 'package:flutter_test/flutter_test.dart';
import 'package:tich_diem/core/utils/firebase_error_mapper.dart';

void main() {
  test('FirebaseErrorMapper returns user friendly Vietnamese messages', () {
    final msg = FirebaseErrorMapper.getMessage(Exception('unknown'));
    expect(msg, contains('Exception: unknown'));

    final recentLoginMsg = FirebaseErrorMapper.getMessage(
      Exception('[firebase_auth/requires-recent-login] This operation is sensitive'),
    );
    expect(
      recentLoginMsg,
      'Phiên làm việc đã hết hạn bảo mật. Vui lòng đăng xuất và đăng nhập lại trước khi đổi mật khẩu.',
    );
  });
}
