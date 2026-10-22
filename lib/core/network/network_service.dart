import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkService {
  static final Connectivity _connectivity = Connectivity();

  /// Kiểm tra tức thời xem có kết nối mạng hay không
  static Future<bool> isConnected() async {
    final results = await _connectivity.checkConnectivity();
    return _hasValidConnection(results);
  }

  /// Lắng nghe thay đổi trạng thái kết nối mạng theo thời gian thực
  static Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.map(_hasValidConnection);
  }

  static bool _hasValidConnection(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((result) =>
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.ethernet ||
        result == ConnectivityResult.vpn ||
        result == ConnectivityResult.other);
  }
}
