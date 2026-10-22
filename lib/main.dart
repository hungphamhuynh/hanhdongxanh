import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/widgets/network_connectivity_listener.dart';
import 'features/auth/presentation/widgets/auth_gate.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const HanhDongXanhApp());
}

class HanhDongXanhApp extends StatelessWidget {
  const HanhDongXanhApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hành động xanh',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32), // Màu xanh lá sinh thái
          brightness: Brightness.light,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      builder: (context, child) {
        // Lắng nghe và hiển thị trạng thái kết nối mạng toàn cục
        return NetworkConnectivityListener(
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const AuthGate(),
    );
  }
}
