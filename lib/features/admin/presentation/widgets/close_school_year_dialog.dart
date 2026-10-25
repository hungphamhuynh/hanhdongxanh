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

  String _currentAcademicYear = '';
  String _nextAcademicYear = '';

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
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final currentYear = await _service.getCurrentAcademicYear();
      final preview =
          await _service.previewClosureData(targetAcademicYear: currentYear);

      // Tự động tính niên khóa kế tiếp (+1 năm) từ currentYear (Ví dụ: "2026-2027" -> "2027-2028")
      String nextYear = '';
      final parts = currentYear.split('-');
      if (parts.length == 2) {
        final start = int.tryParse(parts[0].trim());
        final end = int.tryParse(parts[1].trim());
        if (start != null && end != null) {
          nextYear = '${start + 1}-${end + 1}';
        }
      }
      if (nextYear.isEmpty) {
        nextYear = '2027-2028';
      }

      if (mounted) {
        setState(() {
          _currentAcademicYear = currentYear;
          _nextAcademicYear = nextYear;

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

  Future<void> _editNextAcademicYear() async {
    final ctrl = TextEditingController(text: _nextAcademicYear);
    final customYear = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Tùy chỉnh niên khóa mới',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Niên khóa mới',
            hintText: 'VD: 2027-2028',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (customYear != null && customYear.isNotEmpty && mounted) {
      setState(() {
        _nextAcademicYear = customYear;
      });
    }
  }

  Future<void> _handleConfirm() async {
    final closingYear = _currentAcademicYear.trim();
    final nextYear = _nextAcademicYear.trim();

    if (closingYear.isEmpty || nextYear.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy thông tin niên khóa hợp lệ!'),
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
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
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Đóng Sổ Năm Học',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'Lưu trữ Bảng Vàng và khởi tạo điểm năm học mới',
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
                              tooltip: 'Đóng',
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    color: AppColors.error, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Có $_pendingCount đơn đổi quà đang chờ duyệt! Vui lòng hoàn tất duyệt hoặc từ chối trước khi đóng sổ.',
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
                          const SizedBox(height: 16),
                        ],

                        // Thẻ chuyển giao niên khóa tự động (lấy trực tiếp từ database)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Niên khóa đóng sổ',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _currentAcademicYear.isNotEmpty
                                          ? _currentAcademicYear
                                          : '...',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  color: AppColors.primary,
                                  size: 18,
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          'Niên khóa mới',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        InkWell(
                                          onTap: _editNextAcademicYear,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          child: const Padding(
                                            padding: EdgeInsets.all(2),
                                            child: Icon(
                                              Icons.edit_outlined,
                                              size: 13,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _nextAcademicYear.isNotEmpty
                                          ? _nextAcademicYear
                                          : '...',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
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
                              const Text(
                                'Tóm tắt thành tích niên khóa',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 10),

                              // 2 ô chỉ số KPI tự co giãn responsive
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        border: Border.all(
                                            color: AppColors.border),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Quy mô',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '$_totalClasses lớp',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        border: Border.all(
                                            color: AppColors.border),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Tổng điểm toàn trường',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '+$_totalSchoolPoints đ',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // Top 3 dẫn đầu dùng Wrap
                              if (_topClasses.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                const Text(
                                  'Top 3 lớp dẫn đầu:',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    _buildTopBadge(
                                      '🥇',
                                      _topClasses[0].className,
                                      _topClasses[0].totalPoints,
                                    ),
                                    if (_topClasses.length > 1)
                                      _buildTopBadge(
                                        '🥈',
                                        _topClasses[1].className,
                                        _topClasses[1].totalPoints,
                                      ),
                                    if (_topClasses.length > 2)
                                      _buildTopBadge(
                                        '🥉',
                                        _topClasses[2].className,
                                        _topClasses[2].totalPoints,
                                      ),
                                  ],
                                ),
                              ],

                              // Danh mục thu gom dùng Wrap
                              if (_categorySummaries.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                const Text(
                                  'Tổng thu gom theo loại:',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: _categorySummaries.map((cat) {
                                    final qtyStr = cat.quantity % 1 == 0
                                        ? '${cat.quantity.toInt()}'
                                        : cat.quantity.toStringAsFixed(1);
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(6),
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Lưu ý: Dữ liệu tài khoản giáo viên và các lớp được giữ nguyên 100%. Sau khi đóng sổ, điểm thi đua của các lớp sẽ được đặt lại về 0 để bắt đầu niên khóa mới.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              height: 1.35,
                            ),
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
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                              ),
                              onPressed: (_isSubmitting || _pendingCount > 0)
                                  ? null
                                  : _handleConfirm,
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Đóng Sổ & Reset Điểm',
                                      style: TextStyle(
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
