import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/string_utils.dart';

/// Modal hiển thị Bảng Thành Tích & Xếp Hạng Thi Đua Tháng Này
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

  late final DateTime _now;
  late final Stream<QuerySnapshot> _recordsStream;
  late final Stream<QuerySnapshot> _classesStream;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    final startOfMonth = DateTime(_now.year, _now.month, 1);
    final endOfMonth = _now.month == 12
        ? DateTime(_now.year + 1, 1, 1)
        : DateTime(_now.year, _now.month + 1, 1);

    _recordsStream = FirebaseFirestore.instance
        .collection('point_records')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('createdAt', isLessThan: Timestamp.fromDate(endOfMonth))
        .snapshots();

    _classesStream = FirebaseFirestore.instance.collection('classes').snapshots();
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
          child: Column(
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
                            'Thi Đua Tháng ${_now.month}/${_now.year}',
                            style: const TextStyle(
                              fontSize: 17,
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
                        if (recordsSnap.connectionState == ConnectionState.waiting &&
                            !recordsSnap.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final classDocs = classesSnap.data?.docs ?? [];
                        final recordDocs = recordsSnap.data?.docs ?? [];

                        // 1. Tổng hợp rác thu gom trong tháng
                        int monthlyTotalPoints = 0;
                        double monthlyPaperKg = 0;
                        int monthlyBottles = 0;
                        int monthlyCans = 0;
                        int monthlyBatteries = 0;

                        // Tổng hợp điểm theo từng lớp trong tháng này
                        final Map<String, _ClassMonthStats> classMap = {};

                        // Khởi tạo tất cả các lớp có trong hệ thống
                        for (final cDoc in classDocs) {
                          final cData = cDoc.data() as Map<String, dynamic>;
                          final cName = (cData['className'] as String? ?? cDoc.id).trim();
                          final grade = int.tryParse(cName.isNotEmpty ? cName.substring(0, 1) : '0') ?? 0;
                          classMap[cName] = _ClassMonthStats(className: cName, grade: grade);
                        }

                        // Cộng dồn các phiếu phát sinh trong tháng
                        for (final rDoc in recordDocs) {
                          final rData = rDoc.data() as Map<String, dynamic>;
                          final cName = (rData['className'] as String? ?? '').trim();
                          final pts = (rData['totalPoints'] as num? ?? 0).toInt();
                          final qty = (rData['quantity'] as num? ?? 0).toDouble();
                          final cat = (rData['categoryName'] as String? ?? '').toLowerCase();

                          monthlyTotalPoints += pts;

                          if (cat.contains('giấy') || cat.contains('sách') || cat.contains('báo')) {
                            monthlyPaperKg += qty;
                          } else if (cat.contains('chai') || cat.contains('nhựa')) {
                            monthlyBottles += qty.toInt();
                          } else if (cat.contains('lon') || cat.contains('nhôm')) {
                            monthlyCans += qty.toInt();
                          } else if (cat.contains('pin')) {
                            monthlyBatteries += qty.toInt();
                          }

                          if (classMap.containsKey(cName)) {
                            classMap[cName]!.points += pts;
                            classMap[cName]!.submissionCount += 1;
                          } else if (cName.isNotEmpty) {
                            final grade = int.tryParse(cName.substring(0, 1)) ?? 0;
                            final stat = _ClassMonthStats(className: cName, grade: grade);
                            stat.points = pts;
                            stat.submissionCount = 1;
                            classMap[cName] = stat;
                          }
                        }

                        // Lọc theo Khối
                        final filteredList = classMap.values.where((item) {
                          if (_selectedGrade != 0 && item.grade != _selectedGrade) {
                            return false;
                          }
                          return true;
                        }).toList();

                        // Sắp xếp: Điểm tháng cao nhất -> Lượt nộp nhiều nhất -> Sắp xếp tự nhiên tên lớp
                        filteredList.sort((a, b) {
                          final pComp = b.points.compareTo(a.points);
                          if (pComp != 0) return pComp;
                          final sComp = b.submissionCount.compareTo(a.submissionCount);
                          if (sComp != 0) return sComp;
                          return StringUtils.compareNatural(a.className, b.className);
                        });

                        // Gán thứ hạng hiển thị
                        for (int i = 0; i < filteredList.length; i++) {
                          if (i > 0 &&
                              filteredList[i].points == filteredList[i - 1].points &&
                              filteredList[i].submissionCount == filteredList[i - 1].submissionCount) {
                            filteredList[i].rank = filteredList[i - 1].rank;
                            filteredList[i].isTie = true;
                            filteredList[i - 1].isTie = true;
                          } else {
                            filteredList[i].rank = i + 1;
                          }
                        }

                        return ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          children: [
                            // Thẻ tổng hợp tháng
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
                                  const Text(
                                    'TỔNG KẾT THÁNG NÀY',
                                    style: TextStyle(
                                      color: Color(0xFF86EFAC),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '+$monthlyTotalPoints',
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
                                          'điểm xanh thu gom',
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
                                        label: '${monthlyPaperKg.toStringAsFixed(monthlyPaperKg % 1 == 0 ? 0 : 1)} kg giấy',
                                      ),
                                      _buildSmallChip(
                                        icon: Icons.local_drink_rounded,
                                        label: '$monthlyBottles chai nhựa',
                                      ),
                                      _buildSmallChip(
                                        icon: Icons.recycling_rounded,
                                        label: '$monthlyCans lon nhôm',
                                      ),
                                      _buildSmallChip(
                                        icon: Icons.battery_charging_full_rounded,
                                        label: '$monthlyBatteries viên pin',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

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
                                          fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                          color: isSel ? Colors.white : AppColors.textPrimary,
                                        ),
                                      ),
                                      selected: isSel,
                                      selectedColor: AppColors.primary,
                                      backgroundColor: AppColors.surfaceVariant,
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        side: BorderSide(
                                          color: isSel ? AppColors.primary : Colors.transparent,
                                        ),
                                      ),
                                      onSelected: (_) => setState(() => _selectedGrade = g),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Tiêu đề danh sách
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                    style: TextStyle(color: Colors.grey.shade500),
                                  ),
                                ),
                              )
                            else
                              ...filteredList.map((item) => _buildClassRankItem(item)),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
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

  Widget _buildClassRankItem(_ClassMonthStats item) {
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
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: medalBg,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '#${item.rank}',
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
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
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
                    if (item.isTie && item.points > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
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
                  '${item.submissionCount} lượt thu gom trong tháng',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),

          // Điểm tháng
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
                color: item.points > 0 ? AppColors.primaryDark : Colors.grey.shade500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassMonthStats {
  final String className;
  final int grade;
  int points = 0;
  int submissionCount = 0;
  int rank = 1;
  bool isTie = false;

  _ClassMonthStats({required this.className, required this.grade});
}
