import 'dart:async';
import 'package:flutter/material.dart';
import '../network/network_service.dart';
import '../theme/app_colors.dart';

class NetworkConnectivityListener extends StatefulWidget {
  final Widget child;

  const NetworkConnectivityListener({
    super.key,
    required this.child,
  });

  @override
  State<NetworkConnectivityListener> createState() =>
      _NetworkConnectivityListenerState();
}

class _NetworkConnectivityListenerState
    extends State<NetworkConnectivityListener> {
  StreamSubscription<bool>? _subscription;
  bool _isOffline = false;
  bool _showBackOnline = false;

  @override
  void initState() {
    super.initState();
    _checkInitialState();
    _subscription = NetworkService.onConnectivityChanged.listen((hasNet) {
      if (!hasNet && !_isOffline) {
        setState(() {
          _isOffline = true;
          _showBackOnline = false;
        });
      } else if (hasNet && _isOffline) {
        setState(() {
          _isOffline = false;
          _showBackOnline = true;
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _showBackOnline = false;
            });
          }
        });
      }
    });
  }

  Future<void> _checkInitialState() async {
    final hasNet = await NetworkService.isConnected();
    if (!hasNet && mounted) {
      setState(() => _isOffline = true);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedCrossFade(
          firstChild: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: AppColors.error,
            child: const SafeArea(
              bottom: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Không có kết nối mạng. Vui lòng kiểm tra Internet!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          secondChild: _showBackOnline
              ? Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  color: AppColors.primary,
                  child: const SafeArea(
                    bottom: false,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Đã khôi phục kết nối mạng!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
          crossFadeState: _isOffline
              ? CrossFadeState.showFirst
              : (_showBackOnline
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showSecond),
          duration: const Duration(milliseconds: 300),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}
