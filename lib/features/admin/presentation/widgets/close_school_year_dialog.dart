import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/academic_year_model.dart';
import '../../services/academic_year_service.dart';

/// Hộp thoại Đóng Sổ & Khởi Tạo Năm Học Mới dành cho Quản Trị Viên
class CloseSchoolYearDialog extends StatefulWidget {
  final String userEmail;
  final String userUid;

  const CloseSchoolYearDialog({
    super.key,
    required this.userEmail,
    required this.userUid,
  });

  static Future<bool?> show({
    required BuildContext context,
    required String userEmail,
    required String userUid,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CloseSchoolYearDialog(
        userEmail: userEmail,
        userUid: userUid,
      ),
    );
  }

  @override
  State<CloseSchoolYearDialog> createState() => _CloseSchoolYearDialogState();
}

class _CloseSchoolYearDialogState extends State<CloseSchoolYearDialog> {
  final AcademicYearService _service = AcademicYearService();

  late final TextEditingController _closingYearCtrl;
  late final TextEditingController _nextYearCtrl;

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  int _pendingCount = 0;
  int _totalClasses = 0;
  int _totalSchoolPoints = 0;
  List<ClassRankSnapshot> _topClasses = [];
  List<CategorySummarySnapshot> _categorySummaries = [];

  @override
  void initState() {
    super.initState();
    _closingYearCtrl = TextEditingController();
    _nextYearCtrl = TextEditingController();
    _loadInitialData();
  }

  @override
  void dispose() {
    _closingYearCtrl.dispose();
    _nextYearCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final currentYear = await _service.getCurrentAcademicYear();
      final preview =
          await _service.previewClosureData(targetAcademicYear: currentYear);

      // Tính năm học kế tiếp từ currentYear (Ví dụ: "2025-2026" -> "2026-2027")
      String nextYear = '';
      final parts = currentYear.split('-');
      if (parts.length == 2) {
        final start = int.tryParse(parts[0]);
        final end = int.tryParse(parts[1]);
        if (start != null && end != null) {
          nextYear = '${start + 1}-${end + 1}';
        }
      }

      if (mounted) {
        setState(() {
          _closingYearCtrl.text = currentYear;
          _nextYearCtrl.text = nextYear.isNotEmpty ? nextYear : currentYear;

          _pendingCount = preview['pendingCount'] as int;
          _totalClasses = preview['totalClasses'] as int;
          _totalSchoolPoints = preview['totalSchoolPoints'] as int;
          _topClasses = preview['topClasses'] as List<ClassRankSnapshot>;
          _categorySummaries =
              preview['categorySummaries'] as List<CategorySummarySnapshot>;

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleConfirm() async {
    final closingYear = _closingYearCtrl.text.trim();
    final nextYear = _nextYearCtrl.text.trim();

    if (closingYear.isEmpty || nextYear.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập đầy đủ niên khóa cũ và niên khóa mới!'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (closingYear == nextYear) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Niên khóa mới phải khác niên khóa vừa đóng sổ!'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Hộp thoại xác nhận lần cuối
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
            SizedBox(width: 8),
            Text('Xác Nhận Đóng Sổ', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Text(
          'Hành động này sẽ:\n\n'
          '1. Lưu trữ kết quả năm học $closingYear vào Bảng Vàng.\n'
          '2. Khởi tạo niên khóa mới: $nextYear.\n'
          '3. Đặt lại toàn bộ điểm thi đua của $_totalClasses lớp về 0.\n\n'
          'Tài khoản đăng nhập và liên kết giáo viên được giữ nguyên 100%.\n\n'
          'Bạn có chắc chắn muốn thực hiện?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Xem lại'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác Nhận & Đóng Sổ'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isSubmitting = true);

    try {
      await _service.closeAcademicYear(
        academicYearId: closingYear,
        nextAcademicYearId: nextYear,
        userEmail: widget.userEmail,
        userUid: widget.userUid,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đóng sổ năm học $closingYear thành công! Đã khởi tạo năm học mới $nextYear.',
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        final errText = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $errText'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: _isLoading
            ? const Padding(
                padding: EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Đang chuẩn bị dữ liệu tổng kết năm học...',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              )
            : _errorMessage != null
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 48, color: AppColors.error),
                        const SizedBox(height: 12),
                        Text(
                          'Không thể nạp dữ liệu: $_errorMessage',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.error),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Đóng'),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Tiêu đề Dialog
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.school_rounded,
                                color: AppColors.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Đóng Sổ & Khởi Tạo Năm Học Mới',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Lưu trữ Bảng Vàng và đặt lại điểm thi đua về 0',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Cảnh báo nếu còn đơn pending
                        if (_pendingCount > 0) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.errorLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    color: AppColors.error, size: 24),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Có $_pendingCount đơn đổi quà đang chờ duyệt! Vui lòng vào duyệt hoặc từ chối các đơn này trước khi đóng sổ.',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // 2 ô nhập niên khóa
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _closingYearCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Niên khóa đóng sổ',
                                  hintText: '2025-2026',
                                  prefixIcon:
                                      Icon(Icons.archive_outlined, size: 18),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _nextYearCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Niên khóa mới',
                                  hintText: '2026-2027',
                                  prefixIcon:
                                      Icon(Icons.start_rounded, size: 18),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Thẻ tóm tắt kết quả thành tích năm cũ
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.insights_rounded,
                                      size: 18, color: AppColors.primary),
                                  SizedBox(width: 6),
                                  Text(
                                    'Dữ liệu sẽ được lưu vào Bảng Vàng',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '• Tổng số lớp học: $_totalClasses lớp',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    '• Tổng điểm thi đua: +$_totalSchoolPoints đ',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Top 3 dẫn đầu
                              if (_topClasses.isNotEmpty) ...[
                                const Text(
                                  'Top 3 lớp dẫn đầu năm học:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (_topClasses.isNotEmpty)
                                      _buildTopBadge(
                                        '🥇',
                                        _topClasses[0].className,
                                        _topClasses[0].totalPoints,
                                      ),
                                    if (_topClasses.length > 1) ...[
                                      const SizedBox(width: 6),
                                      _buildTopBadge(
                                        '🥈',
                                        _topClasses[1].className,
                                        _topClasses[1].totalPoints,
                                      ),
                                    ],
                                    if (_topClasses.length > 2) ...[
                                      const SizedBox(width: 6),
                                      _buildTopBadge(
                                        '🥉',
                                        _topClasses[2].className,
                                        _topClasses[2].totalPoints,
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 8),
                              ],

                              // Danh mục thu gom động 100%
                              if (_categorySummaries.isNotEmpty) ...[
                                const Text(
                                  'Tổng sản lượng thu gom các loại (Động):',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: _categorySummaries.map((cat) {
                                    final qtyStr = cat.quantity % 1 == 0
                                        ? '${cat.quantity.toInt()}'
                                        : cat.quantity.toStringAsFixed(1);
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: AppColors.border),
                                      ),
                                      child: Text(
                                        '${cat.categoryName}: $qtyStr ${cat.unit}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Nhắc nhở an toàn
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.shield_outlined,
                                  size: 18, color: AppColors.primary),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Tất cả tài khoản và liên kết giáo viên (6A1, 7A2, email...) được giữ nguyên 100%. Toàn bộ điểm thi đua của các lớp sẽ được đặt lại về 0.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Các nút hành động
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : () => Navigator.pop(context),
                              child: const Text('Hủy'),
                            ),
                            const SizedBox(width: 10),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 12),
                              ),
                              onPressed: (_isSubmitting || _pendingCount > 0)
                                  ? null
                                  : _handleConfirm,
                              icon: _isSubmitting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.archive_outlined, size: 18),
                              label: Text(
                                _isSubmitting
                                    ? 'Đang xử lý...'
                                    : 'Đóng Sổ & Reset Điểm',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildTopBadge(String medal, String className, int points) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(medal, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            className,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '($pointsđ)',
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
