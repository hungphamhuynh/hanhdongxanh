import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/academic_year_model.dart';
import '../../services/academic_year_service.dart';

/// BottomSheet cho phép xem lại Bảng Vàng và Thành Tích các năm học cũ đã đóng sổ
class PastAcademicYearsSheet extends StatefulWidget {
  const PastAcademicYearsSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PastAcademicYearsSheet(),
    );
  }

  @override
  State<PastAcademicYearsSheet> createState() => _PastAcademicYearsSheetState();
}

class _PastAcademicYearsSheetState extends State<PastAcademicYearsSheet> {
  final AcademicYearService _service = AcademicYearService();
  String? _selectedYearId;

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '';
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: StreamBuilder<List<AcademicYearModel>>(
            stream: _service.getPastAcademicYearsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final years = snapshot.data ?? [];

              return Column(
                children: [
                  // Thanh kéo handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.emoji_events_rounded,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Bảng Vàng Các Năm Học Trước',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Nội dung chính
                  Expanded(
                    child: years.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.school_outlined,
                                    size: 56,
                                    color: Colors.grey.shade300,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Chưa có niên khóa nào được đóng sổ',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Khi kết thúc năm học, Quản trị viên sử dụng tính năng "Đóng sổ năm học" để lưu trữ kết quả vào đây.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _buildArchiveContent(context, years, scrollController),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildArchiveContent(
    BuildContext context,
    List<AcademicYearModel> years,
    ScrollController scrollController,
  ) {
    // Mặc định chọn năm học gần nhất
    _selectedYearId ??= years.first.id;

    AcademicYearModel selectedModel;
    try {
      selectedModel = years.firstWhere((y) => y.id == _selectedYearId);
    } catch (_) {
      selectedModel = years.first;
      _selectedYearId = selectedModel.id;
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        // Dropdown chọn Niên khóa
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedYearId,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down_rounded,
                  color: AppColors.primary),
              items: years.map((y) {
                return DropdownMenuItem<String>(
                  value: y.id,
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text(
                        y.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedYearId = val);
              },
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Banner thông tin năm học
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryDark, AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                selectedModel.title.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Đóng sổ ngày: ${_formatDateTime(selectedModel.closedAt)} ${selectedModel.closedByEmail.isNotEmpty ? "• Bởi: ${selectedModel.closedByEmail}" : ""}',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildBannerStat(
                      icon: Icons.stars_rounded,
                      label: 'Tổng Điểm Thi Đua',
                      value: '+${selectedModel.totalSchoolPoints} đ',
                      color: Colors.amberAccent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildBannerStat(
                      icon: Icons.school_rounded,
                      label: 'Số Lớp Tham Gia',
                      value: '${selectedModel.totalClasses} lớp',
                      color: Colors.cyanAccent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Tổng kết sản lượng các loại phế liệu ĐỘNG 100%
        if (selectedModel.categorySummaries.isNotEmpty) ...[
          const Text(
            'Sản Lượng Thu Gom Các Loại (Động)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: selectedModel.categorySummaries.map((cat) {
              final qtyStr = cat.quantity % 1 == 0
                  ? '${cat.quantity.toInt()}'
                  : cat.quantity.toStringAsFixed(1);
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.eco_rounded,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      '${cat.categoryName}: ',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '$qtyStr ${cat.unit}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],

        // Bảng xếp hạng chung cuộc của năm học
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Xếp Hạng Chung Cuộc Các Lớp',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '${selectedModel.topClasses.length} lớp',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        ...selectedModel.topClasses.map((item) {
          final rank = item.rank;
          Color rankColor;
          Widget rankBadge;

          if (rank == 1) {
            rankColor = const Color(0xFFEAB308);
            rankBadge = const Text('🥇', style: TextStyle(fontSize: 20));
          } else if (rank == 2) {
            rankColor = const Color(0xFF94A3B8);
            rankBadge = const Text('🥈', style: TextStyle(fontSize: 20));
          } else if (rank == 3) {
            rankColor = const Color(0xFFD97706);
            rankBadge = const Text('🥉', style: TextStyle(fontSize: 20));
          } else {
            rankColor = AppColors.textSecondary;
            rankBadge = Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            );
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            elevation: 0.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: rank <= 3
                    ? rankColor.withValues(alpha: 0.35)
                    : AppColors.border,
              ),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              leading: rankBadge,
              title: Text(
                'Lớp ${item.className}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${item.totalPoints} đ',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildBannerStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
