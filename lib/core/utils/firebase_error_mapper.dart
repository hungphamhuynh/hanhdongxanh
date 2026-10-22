import 'package:firebase_auth/firebase_auth.dart';
import '../../features/auth/services/auth_service.dart';

class FirebaseErrorMapper {
  static String getMessage(Object error) {
    if (error is SocketException) {
      return error.message;
    }

    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'Địa chỉ email không đúng định dạng.';
        case 'user-disabled':
          return 'Tài khoản này đã bị tạm khóa.';
        case 'user-not-found':
          return 'Không tìm thấy tài khoản với email này.';
        case 'wrong-password':
          return 'Mật khẩu không chính xác.';
        case 'invalid-credential':
          return 'Email hoặc mật khẩu không chính xác.';
        case 'email-already-in-use':
          return 'Email này đã được sử dụng cho một tài khoản khác.';
        case 'operation-not-allowed':
          return 'Phương thức đăng nhập này chưa được kích hoạt trên Firebase Console.';
        case 'weak-password':
          return 'Mật khẩu quá yếu, cần tối thiểu 6 ký tự.';
        case 'too-many-requests':
          return 'Quá nhiều lần thử thất bại. Vui lòng đợi một lát rồi thử lại.';
        case 'network-request-failed':
          return 'Không có kết nối mạng. Vui lòng kiểm tra lại Internet (Wi-Fi hoặc 4G/5G).';
        default:
          return error.message ?? 'Đã xảy ra lỗi (${error.code}).';
      }
    }

    final errStr = error.toString();
    if (errStr.contains('network') || errStr.contains('SocketException')) {
      return 'Chưa kết nối mạng! Vui lòng kiểm tra lại Wi-Fi hoặc 4G/5G.';
    }

    return errStr;
  }
}
