import 'package:flutter/material.dart';

import '../../../auth/services/auth_service.dart';

class LeadTeacherDashboardScreen extends StatelessWidget {
  const LeadTeacherDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lead Teacher'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),
      body: const SizedBox.expand(),
    );
  }
}
