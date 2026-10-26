import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/string_utils.dart';
import '../../../admin/models/school_year_config_model.dart';
import '../../../admin/services/academic_year_service.dart';
import '../../../teacher/models/point_record_model.dart';

/// Modal hiển thị Bảng Thành Tích & Xếp Hạng Thi Đua Công Khai
/// Hỗ trợ xem Cả năm học (mặc định) và theo Tháng.
/// Dành cho Học sinh, Phụ huynh và Giáo viên xem nhanh ngay tại màn hình đăng nhập.
class MonthlyAchievementsSheet extends StatefulWidget {
  const MonthlyAchievementsSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const MonthlyAchievementsSheet(),
    );
  }

  @override
  State<MonthlyAchievementsSheet> createState() => _MonthlyAchievementsSheetState();
}

class _MonthlyAchievementsSheetState extends State<MonthlyAchievementsSheet> {
  int _selectedGrade = 0; // 0 = Toàn trường, 6..9 = Khối 6 đến Khối 9
  bool _isYearly = true; // Mặc định: Xem cả năm học

  late final DateTime _now;
  late final Stream<SchoolYearConfigModel> _schoolYearConfigStream;
  late final Stream<QuerySnapshot> _recordsStream;
  late final Stream<QuerySnapshot> _classesStream;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _schoolYearConfigStream = AcademicYearService().getSchoolYearConfigStream();
    _recordsStream =
        FirebaseFirestore.instance.collection('point_records').snapshots();
    _classesStream =
        FirebaseFirestore.instance.collection('classes').snapshots();
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
          child: StreamBuilder<SchoolYearConfigModel>(
            stream: _schoolYearConfigStream,
            builder: (context, configSnap) {
              final schoolConfig = configSnap.data;
              final academicYearName =
                  schoolConfig?.currentAcademicYear ?? '${_now.year}';

              return Column(
                children: [
                  // Thanh kéo drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header tiêu đề
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 12, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.emoji_events_rounded,
                            color: Color(0xFFD97706),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isYearly
                                    ? 'Bảng Xếp Hạng Năm Học $academicYearName'
                                    : 'Thi Đua Tháng ${_now.month}/${_now.year}',
                                style: const TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Phong trào Hành Động Xanh • THCS Nguyễn Thị Hương',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
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
                  ),
                  const Divider(height: 1),

                  // Nội dung dữ liệu thời gian thực
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _classesStream,
                      builder: (context, classesSnap) {
                        return StreamBuilder<QuerySnapshot>(
                          stream: _recordsStream,
                          builder: (context, recordsSnap) {
                            if (recordsSnap.connectionState ==
                                    ConnectionState.waiting &&
                                !recordsSnap.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final classDocs = classesSnap.data?.docs ?? [];
                            final recordDocs = recordsSnap.data?.docs ?? [];

                            // 1. Tổng hợp rác thu gom trong kỳ đang chọn
                            int totalPeriodPoints = 0;
                            double totalPaperKg = 0;
                            int totalBottles = 0;
                            int totalCans = 0;
                            int totalBatteries = 0;

                            // Bảng thống kê từng lớp
                            final Map<String, _ClassRankStats> classMap = {};

                            // Khởi tạo tất cả các lớp có trong trường
                            for (final cDoc in classDocs) {
                              final cData = cDoc.data() as Map<String, dynamic>;
                              final cName =
                                  (cData['className'] as String? ?? cDoc.id)
                                      .trim();
                              final grade = int.tryParse(
                                    cName.isNotEmpty
                                        ? cName.substring(0, 1)
                                        : '0',
                                  ) ??
                                  0;
                              classMap[cName] = _ClassRankStats(
                                className: cName,
                                grade: grade,
                              );
                            }

                            // Cộng dồn các phiếu thuộc kỳ đang lọc
                            for (final rDoc in recordDocs) {
                              final rec = PointRecordModel.fromFirestore(rDoc);

                              // Lọc phiếu thuộc niên khóa hiện hành
                              if (schoolConfig != null &&
                                  !schoolConfig.isRecordInCurrentYear(rec)) {
                                continue;
                              }

                              // Nếu chọn xem Tháng này: lọc đúng tháng hiện tại
                              if (!_isYearly) {
                                final createdAt = rec.createdAt;
                                if (createdAt == null ||
                                    createdAt.year != _now.year ||
                                    createdAt.month != _now.month) {
                                  continue;
                                }
                              }

                              final cName = rec.className.trim().toUpperCase();
                              final pts = rec.totalPoints;
                              final qty = rec.quantity;
                              final cat = rec.categoryName.toLowerCase();

                              totalPeriodPoints += pts;

                              if (cat.contains('giấy') ||
                                  cat.contains('sách') ||
                                  cat.contains('báo')) {
                                totalPaperKg += qty;
                              } else if (cat.contains('chai') ||
                                  cat.contains('nhựa')) {
                                totalBottles += qty.toInt();
                              } else if (cat.contains('lon') ||
                                  cat.contains('nhôm')) {
                                totalCans += qty.toInt();
                              } else if (cat.contains('pin')) {
                                totalBatteries += qty.toInt();
                              }

                              // Khớp tên lớp (không phân biệt chữ hoa/thường)
                              String? matchedKey;
                              for (final k in classMap.keys) {
                                if (k.toUpperCase() == cName) {
                                  matchedKey = k;
                                  break;
                                }
                              }

                              if (matchedKey != null) {
                                classMap[matchedKey]!.points += pts;
                                classMap[matchedKey]!.submissionCount += 1;
                              } else if (cName.isNotEmpty) {
                                final grade =
                                    int.tryParse(cName.substring(0, 1)) ?? 0;
                                final stat = _ClassRankStats(
                                  className: cName,
                                  grade: grade,
                                );
                                stat.points = pts;
                                stat.submissionCount = 1;
                                classMap[cName] = stat;
                              }
                            }

                            // Lọc theo Khối
                            final filteredList = classMap.values.where((item) {
                              if (_selectedGrade != 0 &&
                                  item.grade != _selectedGrade) {
                                return false;
                              }
                              return true;
                            }).toList();

                            // Sắp xếp:
                            // 1. Điểm cao nhất -> đứng trước
                            // 2. Tiêu chí phụ: Số lượt thu gom nhiều hơn -> đứng trước
                            // 3. Tên lớp tự nhiên (ví dụ 6A1, 6A2...)
                            filteredList.sort((a, b) {
                              final pComp = b.points.compareTo(a.points);
                              if (pComp != 0) return pComp;
                              final sComp =
                                  b.submissionCount.compareTo(a.submissionCount);
                              if (sComp != 0) return sComp;
                              return StringUtils.compareNatural(
                                  a.className, b.className);
                            });

                            // Gán thứ hạng hiển thị chuẩn DENSE RANKING
                            // (Ví dụ: #1, #2, #2 (đồng hạng), #3 — Tuyệt đối không bao giờ nhảy cóc sang #4)
                            int currentRank = 0;
                            int? previousPoints;

                            for (int i = 0; i < filteredList.length; i++) {
                              final item = filteredList[i];
                              if (previousPoints == null ||
                                  item.points != previousPoints) {
                                currentRank++;
                                previousPoints = item.points;
                              }
                              item.rank = currentRank;
                            }

                            // Đánh dấu Đồng hạng cho các lớp bằng điểm nhau (chỉ hiển thị nhãn khi có điểm > 0)
                            for (int i = 0; i < filteredList.length; i++) {
                              final hasSameRankBefore = i > 0 &&
                                  filteredList[i].rank ==
                                      filteredList[i - 1].rank;
                              final hasSameRankAfter =
                                  i < filteredList.length - 1 &&
                                      filteredList[i].rank ==
                                          filteredList[i + 1].rank;
                              filteredList[i].isTie =
                                  (hasSameRankBefore || hasSameRankAfter) &&
                                      filteredList[i].points > 0;
                            }

                            return ListView(
                              controller: scrollController,
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                              children: [
                                // Thẻ tổng hợp số liệu kỳ
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        AppColors.primaryDark,
                                        AppColors.primary
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.25),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _isYearly
                                            ? 'TỔNG KẾT NĂM HỌC $academicYearName'
                                            : 'TỔNG KẾT THÁNG ${_now.month}/${_now.year}',
                                        style: const TextStyle(
                                          color: Color(0xFF86EFAC),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '+$totalPeriodPoints',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 26,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Padding(
                                            padding: EdgeInsets.only(bottom: 3),
                                            child: Text(
                                              'điểm xanh thu gom toàn trường',
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _buildSmallChip(
                                            icon: Icons.newspaper_rounded,
                                            label:
                                                '${totalPaperKg.toStringAsFixed(totalPaperKg % 1 == 0 ? 0 : 1)} kg giấy',
                                          ),
                                          _buildSmallChip(
                                            icon: Icons.local_drink_rounded,
                                            label: '$totalBottles chai nhựa',
                                          ),
                                          _buildSmallChip(
                                            icon: Icons.recycling_rounded,
                                            label: '$totalCans lon nhôm',
                                          ),
                                          _buildSmallChip(
                                            icon: Icons
                                                .battery_charging_full_rounded,
                                            label: '$totalBatteries viên pin',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Bộ lọc Kỳ (Cả năm / Tháng này)
                                Row(
                                  children: [
                                    _buildFilterTab(
                                      label: 'Cả năm học',
                                      isSelected: _isYearly,
                                      onTap: () =>
                                          setState(() => _isYearly = true),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildFilterTab(
                                      label: 'Tháng ${_now.month}/${_now.year}',
                                      isSelected: !_isYearly,
                                      onTap: () =>
                                          setState(() => _isYearly = false),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Bộ lọc Khối
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [0, 6, 7, 8, 9].map((g) {
                                      final isSel = _selectedGrade == g;
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 6),
                                        child: ChoiceChip(
                                          showCheckmark: false,
                                          label: Text(
                                            g == 0 ? 'Toàn trường' : 'Khối $g',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: isSel
                                                  ? FontWeight.bold
                                                  : FontWeight.w500,
                                              color: isSel
                                                  ? Colors.white
                                                  : AppColors.textPrimary,
                                            ),
                                          ),
                                          selected: isSel,
                                          selectedColor: AppColors.primary,
                                          backgroundColor:
                                              AppColors.surfaceVariant,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4, vertical: 0),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            side: BorderSide(
                                              color: isSel
                                                  ? AppColors.primary
                                                  : Colors.transparent,
                                            ),
                                          ),
                                          onSelected: (_) => setState(
                                              () => _selectedGrade = g),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Tiêu đề danh sách
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _selectedGrade == 0
                                          ? 'Bảng Xếp Hạng (${filteredList.length} Lớp)'
                                          : 'Bảng Xếp Hạng Khối $_selectedGrade (${filteredList.length} Lớp)',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'Cập nhật: Hôm nay',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Danh sách xếp hạng các lớp
                                if (filteredList.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Center(
                                      child: Text(
                                        'Chưa có dữ liệu thi đua của khối này.',
                                        style: TextStyle(
                                            color: Colors.grey.shade500),
                                      ),
                                    ),
                                  )
                                else
                                  ...filteredList
                                      .map((item) => _buildClassRankItem(item)),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildFilterTab({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryDark : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryDark : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildSmallChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassRankItem(_ClassRankStats item) {
    Color medalBg;
    Color medalText;

    if (item.points > 0 && item.rank == 1) {
      medalBg = const Color(0xFFFEF3C7);
      medalText = const Color(0xFFD97706);
    } else if (item.points > 0 && item.rank == 2) {
      medalBg = const Color(0xFFE2E8F0);
      medalText = const Color(0xFF475569);
    } else if (item.points > 0 && item.rank == 3) {
      medalBg = const Color(0xFFFFEDD5);
      medalText = const Color(0xFFC2410C);
    } else {
      medalBg = AppColors.surfaceVariant;
      medalText = AppColors.textSecondary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          // Thứ hạng
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: medalBg,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                item.points > 0 ? '#${item.rank}' : '-',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: medalText,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Tên lớp & Khối
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Lớp ${item.className}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'K${item.grade}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (item.isTie) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primaryMint,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Đồng hạng',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  _isYearly
                      ? '${item.submissionCount} lượt thu gom trong năm'
                      : '${item.submissionCount} lượt thu gom trong tháng',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),

          // Điểm trong kỳ
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: item.points > 0
                  ? AppColors.primary.withValues(alpha: 0.08)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              item.points > 0 ? '+${item.points} đ' : '0 đ',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: item.points > 0
                    ? AppColors.primaryDark
                    : Colors.grey.shade500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassRankStats {
  final String className;
  final int grade;
  int points = 0;
  int submissionCount = 0;
  int rank = 1;
  bool isTie = false;

  _ClassRankStats({required this.className, required this.grade});
}
