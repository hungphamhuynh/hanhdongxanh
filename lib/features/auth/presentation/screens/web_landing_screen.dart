import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/responsive_container.dart';

class WebLandingScreen extends StatelessWidget {
  final VoidCallback onContinueToLogin;

  const WebLandingScreen({
    super.key,
    required this.onContinueToLogin,
  });

  // Link dự phòng nếu chưa lấy được từ Firestore
  static const String fallbackApkDownloadUrl =
      'https://github.com/hungphamhuynh/hanhdongxanh/releases/download/v1.0.0/HanhDongXanh.apk';

  Future<void> _handleDownloadApk(BuildContext context) async {
    String targetUrl = fallbackApkDownloadUrl;

    // Lấy link tải mới nhất từ Firestore settings/app_config
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('app_config')
          .get();
      if (doc.exists) {
        final data = doc.data();
        final dbUrl = data?['apkDownloadUrl'] as String?;
        if (dbUrl != null && dbUrl.trim().isNotEmpty) {
          targetUrl = dbUrl.trim();
        }
      }
    } catch (_) {
      // Nếu Firestore chưa load kịp hoặc mạng lag thì dùng fallbackApkDownloadUrl
    }

    final uri = Uri.parse(targetUrl);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể tự động tải file. Vui lòng thử lại!'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải file: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleGoToLogin() async {
    // Lưu cờ vào localStorage để nhớ thiết bị này đã từng vào web
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_visited_web', true);
    } catch (_) {}

    onContinueToLogin();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 620,
          alignment: Alignment.center,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Huy hiệu thông điệp
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryMint.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.eco_rounded, size: 16, color: AppColors.primaryDark),
                        SizedBox(width: 6),
                        Text(
                          'CHUNG TAY VÌ MÔI TRƯỜNG',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Logo trường THCS Nguyễn Thị Hương
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/logo_truong.png',
                      width: 84,
                      height: 84,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.eco_rounded,
                          size: 64,
                          color: AppColors.primary,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // 3. Tên trường & Tên phong trào
                const Text(
                  'TRƯỜNG THCS NGUYỄN THỊ HƯƠNG',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Phong Trào "Hành Động Xanh"',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                    fontSize: 27,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Nơi thầy cô và các bạn học sinh cùng chung tay phân loại rác, xây dựng thói quen xanh và giữ gìn môi trường học đường.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),

                // 4. Hai nút hành động chính
                // NÚT 1: SỬ DỤNG TRỰC TIẾP TRÊN WEB
                FilledButton.icon(
                  onPressed: _handleGoToLogin,
                  icon: const Icon(Icons.language_rounded, size: 22),
                  label: const Text(
                    'Sử Dụng Trực Tiếp Trên Web',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                  ),
                ),
                const SizedBox(height: 12),

                // NÚT 2: TẢI ỨNG DỤNG CHO ANDROID (.APK)
                OutlinedButton.icon(
                  onPressed: () => _handleDownloadApk(context),
                  icon: const Icon(Icons.android_rounded, size: 22, color: Color(0xFF15803D)),
                  label: const Text(
                    'Tải Ứng Dụng Android (.APK)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF15803D),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF86EFAC), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // 5. Khối tinh thần phong trào (nhẹ nhàng, tích cực, không cạnh tranh)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.favorite_rounded, color: AppColors.primary, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Tinh Thần Phong Trào',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildPillarItem(
                        icon: Icons.spa_rounded,
                        color: const Color(0xFF16A34A),
                        title: 'Thói Quen Xanh Mỗi Ngày',
                        desc:
                            'Tự giác phân loại rác ngay tại lớp học, để mỗi ngày đến trường là một ngày trong lành và vui vẻ.',
                      ),
                      _buildDivider(),
                      _buildPillarItem(
                        icon: Icons.volunteer_activism_rounded,
                        color: const Color(0xFF0284C7),
                        title: 'Mỗi Đóng Góp Đều Đáng Quý',
                        desc:
                            'Dù là một vỏ chai hay một mẩu giấy báo, mỗi hành động nhỏ của bạn đều góp phần làm sạch không gian chung.',
                      ),
                      _buildDivider(),
                      _buildPillarItem(
                        icon: Icons.diversity_3_rounded,
                        color: const Color(0xFF7C3AED),
                        title: 'Đồng Hành & Cùng Lan Tỏa',
                        desc:
                            'Cùng bạn bè và thầy cô xây dựng một ngôi trường thân thiện, gần gũi với thiên nhiên.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 6. Khung thông điệp chân thành
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.format_quote_rounded, color: AppColors.primary, size: 26),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '“Một hành động nhỏ hôm nay — Vì một trường học luôn xanh, sạch và thân thiện.”',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF166534),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPillarItem({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Divider(height: 1, thickness: 0.5, color: AppColors.border),
    );
  }
}
