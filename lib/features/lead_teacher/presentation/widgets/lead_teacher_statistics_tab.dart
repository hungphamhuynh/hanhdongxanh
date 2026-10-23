import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../teacher/presentation/widgets/class_details_sheet.dart';

class LeadTeacherStatisticsTab extends StatefulWidget {
  const LeadTeacherStatisticsTab({super.key});

  @override
  State<LeadTeacherStatisticsTab> createState() =>
      _LeadTeacherStatisticsTabState();
}

class _LeadTeacherStatisticsTabState extends State<LeadTeacherStatisticsTab> {
  late int _selectedYear;
  int _selectedMonth = 0; // 0 = Cả năm, 1..12 = Tháng 1..12
  int _selectedGrade = 0; // 0 = Tất cả, 6..9 = Khối 6..9

  late final Stream<QuerySnapshot> _recordsStream;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month; // Mặc định mở tháng hiện tại
    _recordsStream =
        FirebaseFirestore.instance.collection('point_records').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _recordsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        // 1. Lọc và tổng hợp dữ liệu theo bộ lọc
        int totalPeriodPoints = 0;
        int totalBottles = 0;
        int totalCans = 0;
        double totalPaperKg = 0.0;
        int totalBatteries = 0;
        int totalPens = 0;

        final Map<String, _ClassPeriodStats> classMap = {};

        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
          if (createdAt == null) continue;

          // Lọc theo Năm
          if (createdAt.year != _selectedYear) continue;

          // Lọc theo Tháng
          if (_selectedMonth != 0 && createdAt.month != _selectedMonth) {
            continue;
          }

          final className =
              (data['className'] as String? ?? '').trim().toUpperCase();
          if (className.isEmpty) continue;

          // Lấy Khối từ ký tự đầu
          final grade = int.tryParse(className[0]) ?? 0;
          if (_selectedGrade != 0 && grade != _selectedGrade) continue;

          final points = (data['totalPoints'] as num?)?.toInt() ?? 0;
          final qty = (data['quantity'] as num?)?.toDouble() ?? 0.0;
          final cat = (data['categoryName'] as String? ?? '').toLowerCase();

          totalPeriodPoints += points;

          bool isBattery = cat.contains('pin');
          bool isPen = cat.contains('bút') ||
              cat.contains('viết') ||
              cat.contains('pen');
          bool isCan = cat.contains('lon') || cat.contains('nhôm');
          bool isPaper = cat.contains('giấy') ||
              cat.contains('giay') ||
              cat.contains('carton') ||
              cat.contains('sách') ||
              cat.contains('báo');

          if (isBattery) {
            totalBatteries += qty.toInt();
          } else if (isPen) {
            totalPens += qty.toInt();
          } else if (isCan) {
            totalCans += qty.toInt();
          } else if (isPaper) {
            totalPaperKg += qty;
          } else {
            totalBottles += qty.toInt();
          }

          // Gom nhóm theo từng lớp
          final stats = classMap.putIfAbsent(
            className,
            () => _ClassPeriodStats(className: className, grade: grade),
          );

          stats.totalPoints += points;
          stats.submissions += 1;
          if (isBattery) {
            stats.batteries += qty.toInt();
          } else if (isPen) {
            stats.pens += qty.toInt();
          } else if (isCan) {
            stats.cans += qty.toInt();
          } else if (isPaper) {
            stats.paperKg += qty;
          } else {
            stats.bottles += qty.toInt();
          }
        }

        // Danh sách các lớp có thành tích trong kỳ, sắp xếp theo điểm giảm dần
        final rankedClasses = classMap.values.toList()
          ..sort((a, b) => b.totalPoints.compareTo(a.totalPoints));

        final currentYear = DateTime.now().year;
        final availableYears = List.generate(5, (i) => currentYear - 2 + i);

        return CustomScrollView(
          slivers: [
            // 1. Thẻ Bộ Lọc (Năm, Tháng, Khối)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: _buildFilterCard(availableYears),
              ),
            ),

            // 2. Thẻ TỔNG SỐ (KPI Tổng quan thu gom)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildTotalKpiCard(
                  totalPeriodPoints: totalPeriodPoints,
                  totalBottles: totalBottles,
                  totalCans: totalCans,
                  totalPaperKg: totalPaperKg,
                  totalBatteries: totalBatteries,
                  totalPens: totalPens,
                ),
              ),
            ),

            // 3. Tiêu đề Bảng Chi Tiết Thành Tích
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.leaderboard_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Chi Tiết Thành Tích Từng Lớp (${rankedClasses.length})',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _selectedMonth == 0
                          ? 'Cả năm $_selectedYear'
                          : 'Tháng $_selectedMonth/$_selectedYear',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 4. Danh sách các lớp đạt thành tích trong kỳ
            if (rankedClasses.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceVariant,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.eco_outlined,
                            size: 48,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Không có dữ liệu thu gom',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Trong ${_selectedMonth == 0 ? "năm $_selectedYear" : "tháng $_selectedMonth/$_selectedYear"} ${_selectedGrade != 0 ? "của Khối $_selectedGrade" : ""} chưa có lớp nào nộp phế liệu.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = rankedClasses[index];
                      return _buildRankedClassCard(context, index + 1, item);
                    },
                    childCount: rankedClasses.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Khung bộ lọc Năm, Tháng, Khối
  Widget _buildFilterCard(List<int> availableYears) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dòng 1: Chọn Năm và Chọn Tháng
          Row(
            children: [
              // Chọn Năm (mở rộng ngang bằng tháng, chống tràn pixel)
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _selectedYear,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Năm',
                    isDense: true,
                    prefixIcon: Icon(Icons.calendar_today_rounded, size: 16),
                    prefixIconConstraints:
                        BoxConstraints(minWidth: 32, minHeight: 32),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  items: availableYears.map((y) {
                    return DropdownMenuItem<int>(
                      value: y,
                      child: Text(
                        'Năm $y',
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedYear = val);
                  },
                ),
              ),
              const SizedBox(width: 10),

              // Chọn Tháng
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _selectedMonth,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Tháng',
                    isDense: true,
                    prefixIcon: Icon(Icons.date_range_rounded, size: 16),
                    prefixIconConstraints:
                        BoxConstraints(minWidth: 32, minHeight: 32),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem<int>(
                      value: 0,
                      child: Text(
                        'Cả năm',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ...List.generate(12, (i) => i + 1).map((m) {
                      return DropdownMenuItem<int>(
                        value: m,
                        child: Text(
                          'Tháng $m',
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedMonth = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Dòng 2: Lọc Khối dạng Select (Dropdown)
          DropdownButtonFormField<int>(
            initialValue: _selectedGrade,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Khối lớp',
              isDense: true,
              prefixIcon: Icon(Icons.school_rounded, size: 16),
              prefixIconConstraints:
                  BoxConstraints(minWidth: 32, minHeight: 32),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            items: const [
              DropdownMenuItem<int>(
                value: 0,
                child: Text(
                  'Tất cả các khối',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem<int>(
                value: 6,
                child: Text(
                  'Khối 6',
                  style: TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem<int>(
                value: 7,
                child: Text(
                  'Khối 7',
                  style: TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem<int>(
                value: 8,
                child: Text(
                  'Khối 8',
                  style: TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem<int>(
                value: 9,
                child: Text(
                  'Khối 9',
                  style: TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedGrade = val);
            },
          ),
        ],
      ),
    );
  }

  /// Khung TỔNG SỐ - Báo cáo KPI toàn trường trong kỳ
  Widget _buildTotalKpiCard({
    required int totalPeriodPoints,
    required int totalBottles,
    required int totalCans,
    required double totalPaperKg,
    required int totalBatteries,
    required int totalPens,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TỔNG SỐ THU GOM TRONG KỲ',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _selectedMonth == 0
                        ? 'Năm $_selectedYear ${_selectedGrade != 0 ? "• Khối $_selectedGrade" : "• Toàn trường"}'
                        : 'Tháng $_selectedMonth/$_selectedYear ${_selectedGrade != 0 ? "• Khối $_selectedGrade" : "• Toàn trường"}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tổng điểm lớn nổi bật
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.stars_rounded, color: Colors.amberAccent, size: 28),
                    SizedBox(width: 8),
                    Text(
                      'Tổng điểm thi đua:',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  '+$totalPeriodPoints đ',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Lưới 5 ô thống kê các loại phế liệu
          Row(
            children: [
              Expanded(
                child: _buildScrapCountTile(
                  icon: Icons.local_drink_rounded,
                  iconColor: Colors.lightBlueAccent,
                  label: 'Chai nhựa',
                  value: '$totalBottles',
                  unit: 'chai',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildScrapCountTile(
                  icon: Icons.recycling_rounded,
                  iconColor: Colors.orangeAccent,
                  label: 'Lon nhôm',
                  value: '$totalCans',
                  unit: 'lon',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildScrapCountTile(
                  icon: Icons.newspaper_rounded,
                  iconColor: const Color(0xFFFFCC80),
                  label: 'Giấy vụn',
                  value: totalPaperKg > 0
                      ? totalPaperKg.toStringAsFixed(1)
                      : '0',
                  unit: 'kg',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildScrapCountTile(
                  icon: Icons.battery_charging_full_rounded,
                  iconColor: Colors.amberAccent,
                  label: 'Pin cũ',
                  value: '$totalBatteries',
                  unit: 'viên',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildScrapCountTile(
                  icon: Icons.edit_note_rounded,
                  iconColor: Colors.purpleAccent,
                  label: 'Bút viết cũ',
                  value: '$totalPens',
                  unit: 'cây',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScrapCountTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String unit,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$value $unit',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  /// Thẻ lớp xếp hạng theo kỳ thống kê
  Widget _buildRankedClassCard(
      BuildContext context, int rank, _ClassPeriodStats stats) {
    Color rankColor;
    Widget rankBadge;

    if (rank == 1) {
      rankColor = const Color(0xFFEAB308);
      rankBadge = const Text('🥇', style: TextStyle(fontSize: 22));
    } else if (rank == 2) {
      rankColor = const Color(0xFF94A3B8);
      rankBadge = const Text('🥈', style: TextStyle(fontSize: 22));
    } else if (rank == 3) {
      rankColor = const Color(0xFFD97706);
      rankBadge = const Text('🥉', style: TextStyle(fontSize: 22));
    } else {
      rankColor = AppColors.textSecondary;
      rankBadge = Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
        alignment: Alignment.center,
        child: Text(
          '#$rank',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: rankColor,
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0.8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: rank <= 3
              ? rankColor.withValues(alpha: 0.5)
              : AppColors.border,
          width: rank <= 3 ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          // Mở bảng chi tiết lịch sử riêng của lớp
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => ClassDetailsSheet(className: stats.className),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  rankBadge,
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lớp ${stats.className}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Khối ${stats.grade}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '+${stats.totalPoints} đ',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),

              // Chi tiết các loại phế liệu lớp đã nộp trong kỳ
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (stats.bottles > 0)
                    _buildMiniBadge(Icons.local_drink_rounded,
                        '${stats.bottles} chai', AppColors.primary),
                  if (stats.cans > 0)
                    _buildMiniBadge(Icons.recycling_rounded,
                        '${stats.cans} lon', AppColors.secondary),
                  if (stats.paperKg > 0)
                    _buildMiniBadge(Icons.newspaper_rounded,
                        '${stats.paperKg.toStringAsFixed(1)} kg giấy', const Color(0xFF8D6E63)),
                  if (stats.batteries > 0)
                    _buildMiniBadge(Icons.battery_charging_full_rounded,
                        '${stats.batteries} pin', AppColors.warning),
                  if (stats.pens > 0)
                    _buildMiniBadge(Icons.edit_note_rounded,
                        '${stats.pens} bút', Colors.purple.shade600),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassPeriodStats {
  final String className;
  final int grade;
  int totalPoints = 0;
  int bottles = 0;
  int cans = 0;
  double paperKg = 0.0;
  int batteries = 0;
  int pens = 0;
  int submissions = 0;

  _ClassPeriodStats({required this.className, required this.grade});
}
