import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../admin/models/point_rule_model.dart';
import '../../../admin/services/point_rule_service.dart';
import '../../../teacher/presentation/widgets/class_details_sheet.dart';

/// Tab Thống Kê dành cho Tổng Phụ Trách
/// Thống kê ĐỘNG theo Năm, Tháng, Khối, và Danh Mục Phế Liệu:
/// - Mặc định: Thống kê Tổng Điểm Thi Đua toàn trường / khối trong kỳ.
/// - Chọn danh mục cụ thể (tải động từ point_rules): Thống kê theo số lượng thu gom của loại đó.
class LeadTeacherStatisticsTab extends StatefulWidget {
  const LeadTeacherStatisticsTab({super.key});

  @override
  State<LeadTeacherStatisticsTab> createState() =>
      _LeadTeacherStatisticsTabState();
}

class _LeadTeacherStatisticsTabState extends State<LeadTeacherStatisticsTab> {
  final PointRuleService _pointRuleService = PointRuleService();

  late int _selectedYear;
  int _selectedMonth = 0; // 0 = Cả năm, 1..12 = Tháng 1..12
  int _selectedGrade = 0; // 0 = Tất cả các khối, 6..9 = Khối 6..9
  String _selectedRuleId = ''; // '' = Tất cả danh mục

  late final Stream<QuerySnapshot> _recordsStream;
  late final Stream<List<PointRuleModel>> _rulesStream;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month; // Mặc định mở tháng hiện tại
    _recordsStream =
        FirebaseFirestore.instance.collection('point_records').snapshots();
    _rulesStream = _pointRuleService.getPointRulesStream(onlyActive: true);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PointRuleModel>>(
      stream: _rulesStream,
      builder: (context, rulesSnap) {
        final rules = rulesSnap.data ?? [];

        return StreamBuilder<QuerySnapshot>(
          stream: _recordsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data?.docs ?? [];

            // 1. Xác định rule đang chọn (nếu có)
            PointRuleModel? selectedRule;
            if (_selectedRuleId.isNotEmpty) {
              try {
                selectedRule = rules.firstWhere((r) => r.id == _selectedRuleId);
              } catch (_) {
                selectedRule = null;
              }
            }

            // 2. Lọc và tổng hợp dữ liệu theo bộ lọc động
            int totalPeriodPoints = 0;
            double totalCategoryQty = 0.0;
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

              final ruleId = data['ruleId'] as String? ?? '';
              final categoryName =
                  (data['categoryName'] as String? ?? '').trim();
              final points = (data['totalPoints'] as num?)?.toInt() ?? 0;
              final qty = (data['quantity'] as num?)?.toDouble() ?? 0.0;

              // Nếu đang lọc theo 1 Danh mục cụ thể
              if (selectedRule != null) {
                final isMatch = (ruleId.isNotEmpty &&
                        ruleId == selectedRule.id) ||
                    categoryName.toLowerCase() ==
                        selectedRule.name.toLowerCase();
                if (!isMatch) continue;

                totalCategoryQty += qty;
              }

              totalPeriodPoints += points;

              // Gom nhóm dữ liệu theo từng lớp
              final stats = classMap.putIfAbsent(
                className,
                () => _ClassPeriodStats(className: className, grade: grade),
              );

              stats.totalPoints += points;
              stats.categoryQuantity += qty;
            }

            // Sắp xếp danh sách lớp
            final rankedClasses = classMap.values.toList();
            if (selectedRule == null) {
              rankedClasses
                  .sort((a, b) => b.totalPoints.compareTo(a.totalPoints));
            } else {
              rankedClasses.sort((a, b) {
                final cmp = b.categoryQuantity.compareTo(a.categoryQuantity);
                if (cmp != 0) return cmp;
                return b.totalPoints.compareTo(a.totalPoints);
              });
            }

            final currentYear = DateTime.now().year;
            final availableYears =
                List.generate(5, (i) => currentYear - 2 + i);

            return CustomScrollView(
              slivers: [
                // 1. Thẻ Bộ Lọc (Năm, Tháng, Khối, Danh Mục)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                    child: _buildFilterCard(availableYears, rules),
                  ),
                ),

                // 2. Thẻ TỔNG SỐ (Banner KPI Động)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildTotalKpiCard(
                      selectedRule: selectedRule,
                      totalPeriodPoints: totalPeriodPoints,
                      totalCategoryQty: totalCategoryQty,
                      activeClassesCount: rankedClasses.length,
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
                              'Trong ${_selectedMonth == 0 ? "năm $_selectedYear" : "tháng $_selectedMonth/$_selectedYear"} ${_selectedGrade != 0 ? "của Khối $_selectedGrade" : ""} chưa có dữ liệu thu gom.',
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
                          return _buildRankedClassCard(
                            context,
                            index + 1,
                            item,
                            selectedRule: selectedRule,
                          );
                        },
                        childCount: rankedClasses.length,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  /// Khung bộ lọc Năm, Tháng, Khối và Danh Mục dạng Select
  Widget _buildFilterCard(
    List<int> availableYears,
    List<PointRuleModel> rules,
  ) {
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
              // Chọn Năm
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

          // Dòng 2: Chọn Khối và Chọn Danh Mục
          Row(
            children: [
              // Chọn Khối
              Expanded(
                flex: 4,
                child: DropdownButtonFormField<int>(
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
                        'Tất cả khối',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
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
              ),
              const SizedBox(width: 10),

              // Chọn Danh Mục Phế Liệu
              Expanded(
                flex: 6,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedRuleId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Danh mục',
                    isDense: true,
                    prefixIcon: Icon(Icons.category_rounded, size: 16),
                    prefixIconConstraints:
                        BoxConstraints(minWidth: 32, minHeight: 32),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text(
                        'Tất cả danh mục',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ...rules.map((rule) {
                      return DropdownMenuItem<String>(
                        value: rule.id,
                        child: Text(
                          '${rule.name} (${rule.unit})',
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedRuleId = val);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Khung TỔNG SỐ - Banner KPI Động không hard text
  Widget _buildTotalKpiCard({
    required PointRuleModel? selectedRule,
    required int totalPeriodPoints,
    required double totalCategoryQty,
    required int activeClassesCount,
  }) {
    final isAll = selectedRule == null;

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
          // Tiêu đề Banner
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAll
                    ? 'TỔNG SỐ THI ĐUA TRONG KỲ'
                    : 'TỔNG THU GOM: ${selectedRule.name.toUpperCase()}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
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
          const SizedBox(height: 14),

          // 2 ô chỉ số KPI Động
          Row(
            children: [
              if (isAll) ...[
                Expanded(
                  child: _buildKpiStatTile(
                    icon: Icons.stars_rounded,
                    label: 'Tổng Điểm Thi Đua',
                    value: '+$totalPeriodPoints đ',
                    iconColor: Colors.amberAccent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildKpiStatTile(
                    icon: Icons.school_rounded,
                    label: 'Số Lớp Tham Gia',
                    value: '$activeClassesCount lớp',
                    iconColor: Colors.cyanAccent,
                  ),
                ),
              ] else ...[
                Expanded(
                  child: _buildKpiStatTile(
                    icon: selectedRule.iconData,
                    label: 'Tổng Thu Gom',
                    value: totalCategoryQty % 1 == 0
                        ? '${totalCategoryQty.toInt()} ${selectedRule.unit}'
                        : '${totalCategoryQty.toStringAsFixed(1)} ${selectedRule.unit}',
                    iconColor: Colors.amberAccent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildKpiStatTile(
                    icon: Icons.school_rounded,
                    label: 'Số Lớp Đã Nộp',
                    value: '$activeClassesCount lớp',
                    iconColor: Colors.cyanAccent,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiStatTile({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Thẻ lớp xếp hạng theo kỳ thống kê (Động theo Danh Mục)
  Widget _buildRankedClassCard(
    BuildContext context,
    int rank,
    _ClassPeriodStats stats, {
    required PointRuleModel? selectedRule,
  }) {
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

    final isAll = selectedRule == null;

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
          child: Row(
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
                    const SizedBox(height: 2),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isAll
                      ? '+${stats.totalPoints} đ'
                      : (stats.categoryQuantity % 1 == 0
                          ? '${stats.categoryQuantity.toInt()} ${selectedRule.unit}'
                          : '${stats.categoryQuantity.toStringAsFixed(1)} ${selectedRule.unit}'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassPeriodStats {
  final String className;
  final int grade;
  int totalPoints = 0;
  double categoryQuantity = 0.0;

  _ClassPeriodStats({
    required this.className,
    required this.grade,
  });
}
