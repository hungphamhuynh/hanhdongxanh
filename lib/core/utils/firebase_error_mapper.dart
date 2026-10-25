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
        case 'requires-recent-login':
          return 'Phiên làm việc đã hết hạn bảo mật. Vui lòng đăng xuất và đăng nhập lại trước khi đổi mật khẩu.';
        default:
          return error.message ?? 'Đã xảy ra lỗi (${error.code}).';
      }
    }

    final errStr = error.toString();
    if (errStr.contains('requires-recent-login')) {
      return 'Phiên làm việc đã hết hạn bảo mật. Vui lòng đăng xuất và đăng nhập lại trước khi đổi mật khẩu.';
    }
    if (errStr.contains('network') || errStr.contains('SocketException')) {
      return 'Chưa kết nối mạng! Vui lòng kiểm tra lại Wi-Fi hoặc 4G/5G.';
    }

    return errStr;
  }

  /// Trích xuất thông điệp lỗi tiếng Việt thân thiện, lọc sạch stack trace và các mã lỗi kỹ thuật
  static String getCleanErrorMessage(Object error) {
    if (error is SocketException) {
      return error.message;
    }

    if (error is FirebaseAuthException) {
      return getMessage(error);
    }

    String msg = '';
    if (error is FirebaseException) {
      msg = error.message ?? error.toString();
    } else {
      msg = error.toString();
    }

    // Nếu chứa dòng stack trace, chỉ lấy dòng thông điệp đầu tiên
    if (msg.contains('\n')) {
      msg = msg.split('\n').first;
    }

    // Lọc sạch các tiền tố kỹ thuật của Firebase & Transaction
    msg = msg
        .replaceAll(RegExp(r'^\[.*?\]\s*'), '')
        .replaceAll('Transaction failed:', '')
        .replaceAll('Exception:', '')
        .trim();

    if (msg.contains('requires-recent-login')) {
      return 'Phiên làm việc đã hết hạn bảo mật. Vui lòng đăng xuất và đăng nhập lại trước khi đổi mật khẩu.';
    }

    if (msg.contains('network') || msg.contains('SocketException')) {
      return 'Chưa kết nối mạng! Vui lòng kiểm tra lại Wi-Fi hoặc 4G/5G.';
    }

    return msg.isNotEmpty ? msg : 'Đã có lỗi xảy ra. Vui lòng thử lại!';
  }
}
