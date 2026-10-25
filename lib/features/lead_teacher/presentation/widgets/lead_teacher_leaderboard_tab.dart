import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/string_utils.dart';
import '../../../admin/models/point_rule_model.dart';
import '../../../admin/presentation/widgets/past_school_years_sheet.dart';
import '../../../admin/services/point_rule_service.dart';
import '../../../teacher/presentation/widgets/class_details_sheet.dart';

/// Tab Hợp Nhất: Xếp Hạng & Thống Kê dành cho Tổng Phụ Trách
/// Kết hợp đầy đủ:
/// - Bộ lọc Thời gian (Năm, Tháng / Cả năm), Khối (6-9), và Danh mục phế liệu động.
/// - Thẻ KPI Tổng hợp số liệu toàn trường trong kỳ.
/// - Bục vinh danh Podium Top 1, Top 2, Top 3 rực rỡ cúp vàng/bạc/đồng.
/// - Bảng tổng sắp chi tiết từng lớp với Tiêu chí phụ (Tie-breaker) và Đồng hạng công bằng.
class LeadTeacherLeaderboardTab extends StatefulWidget {
  const LeadTeacherLeaderboardTab({super.key});

  @override
  State<LeadTeacherLeaderboardTab> createState() =>
      _LeadTeacherLeaderboardTabState();
}

class _LeadTeacherLeaderboardTabState extends State<LeadTeacherLeaderboardTab> {
  final PointRuleService _pointRuleService = PointRuleService();

  late int _selectedYear;
  int _selectedMonth = 0; // 0 = Cả năm, 1..12 = Tháng 1..12
  int _selectedGrade = 0; // 0 = Tất cả các khối, 6..9 = Khối 6..9
  String _selectedRuleId = ''; // '' = Tất cả danh mục (Xếp hạng theo điểm)

  late Stream<QuerySnapshot> _recordsStream;
  late final Stream<List<PointRuleModel>> _rulesStream;

  Stream<QuerySnapshot> _buildRecordsStream(int year, int month) {
    final collection = FirebaseFirestore.instance.collection('point_records');
    if (month == 0) {
      // Cả năm: từ 01/01/year đến 01/01/(year+1)
      final start = DateTime(year, 1, 1);
      final end = DateTime(year + 1, 1, 1);
      return collection
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThan: Timestamp.fromDate(end))
          .snapshots();
    } else {
      // Tháng cụ thể: từ 01/month/year đến 01/(month+1)/year
      final start = DateTime(year, month, 1);
      final end = month == 12
          ? DateTime(year + 1, 1, 1)
          : DateTime(year, month + 1, 1);
      return collection
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThan: Timestamp.fromDate(end))
          .snapshots();
    }
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month; // Mặc định mở tháng thi đua hiện tại
    _recordsStream = _buildRecordsStream(_selectedYear, _selectedMonth);
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

            // 1. Xác định quy tắc đang chọn (nếu có)
            PointRuleModel? selectedRule;
            if (_selectedRuleId.isNotEmpty) {
              try {
                selectedRule = rules.firstWhere((r) => r.id == _selectedRuleId);
              } catch (_) {
                selectedRule = null;
              }
            }

            // 2. Thu thập và tổng hợp số liệu theo các bộ lọc
            int totalPeriodPoints = 0;
            double totalCategoryQty = 0.0;
            final Map<String, _ClassStatsData> classMap = {};

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

              // Lấy Khối từ ký tự đầu tên lớp
              final grade = int.tryParse(className[0]) ?? 0;
              if (_selectedGrade != 0 && grade != _selectedGrade) continue;

              final ruleId = data['ruleId'] as String? ?? '';
              final categoryName =
                  (data['categoryName'] as String? ?? '').trim();
              final points = (data['totalPoints'] as num?)?.toInt() ?? 0;
              final qty = (data['quantity'] as num?)?.toDouble() ?? 0.0;

              // Nếu đang lọc theo danh mục cụ thể
              if (selectedRule != null) {
                final isMatch = (ruleId.isNotEmpty &&
                        ruleId == selectedRule.id) ||
                    categoryName.toLowerCase() ==
                        selectedRule.name.toLowerCase();
                if (!isMatch) continue;

                totalCategoryQty += qty;
              }

              totalPeriodPoints += points;

              final stats = classMap.putIfAbsent(
                className,
                () => _ClassStatsData(className: className, grade: grade),
              );

              stats.totalPoints += points;
              stats.categoryQuantity += qty;
              stats.submissionCount++;
              if (stats.latestSubmissionTime == null ||
                  createdAt.isAfter(stats.latestSubmissionTime!)) {
                stats.latestSubmissionTime = createdAt;
              }
            }

            // 3. Sắp xếp thứ hạng kèm Tiêu chí phụ (Tie-breaker)
            final rankedClasses = classMap.values.toList();
            if (selectedRule == null) {
              // Xếp theo Tổng Điểm Thi Đua
              rankedClasses.sort((a, b) {
                // Tiêu chí 1: Điểm số cao hơn xếp trước
                final cmpPts = b.totalPoints.compareTo(a.totalPoints);
                if (cmpPts != 0) return cmpPts;

                // Tiêu chí phụ 1: Lớp có số lượt thu gom nhiều hơn (phong trào chăm chỉ hơn)
                final cmpCount = b.submissionCount.compareTo(a.submissionCount);
                if (cmpCount != 0) return cmpCount;

                // Tiêu chí phụ 2: Lớp đạt mốc sớm hơn (thời gian ghi nhận gần nhất nhỏ hơn)
                if (a.latestSubmissionTime != null &&
                    b.latestSubmissionTime != null) {
                  final cmpTime =
                      a.latestSubmissionTime!.compareTo(b.latestSubmissionTime!);
                  if (cmpTime != 0) return cmpTime;
                }

                return StringUtils.compareNatural(a.className, b.className);
              });
            } else {
              // Xếp theo Số Lượng Thu Gom của danh mục được chọn
              rankedClasses.sort((a, b) {
                // Tiêu chí 1: Số lượng thu gom cao hơn
                final cmpQty = b.categoryQuantity.compareTo(a.categoryQuantity);
                if (cmpQty != 0) return cmpQty;

                // Tiêu chí 2: Điểm số tương ứng
                final cmpPts = b.totalPoints.compareTo(a.totalPoints);
                if (cmpPts != 0) return cmpPts;

                // Tiêu chí phụ 1: Số lượt tham gia
                final cmpCount = b.submissionCount.compareTo(a.submissionCount);
                if (cmpCount != 0) return cmpCount;

                // Tiêu chí phụ 2: Đạt mốc sớm hơn
                if (a.latestSubmissionTime != null &&
                    b.latestSubmissionTime != null) {
                  final cmpTime =
                      a.latestSubmissionTime!.compareTo(b.latestSubmissionTime!);
                  if (cmpTime != 0) return cmpTime;
                }

                return StringUtils.compareNatural(a.className, b.className);
              });
            }

            // 4. Gán thứ hạng hiển thị có xử lý Đồng Hạng (Tie rank)
            int currentRank = 1;
            for (int i = 0; i < rankedClasses.length; i++) {
              if (i > 0) {
                final prev = rankedClasses[i - 1];
                final curr = rankedClasses[i];
                final isTie = selectedRule == null
                    ? (curr.totalPoints == prev.totalPoints &&
                        curr.submissionCount == prev.submissionCount)
                    : (curr.categoryQuantity == prev.categoryQuantity &&
                        curr.totalPoints == prev.totalPoints &&
                        curr.submissionCount == prev.submissionCount);

                if (isTie) {
                  curr.isTieWithPrevious = true;
                  curr.displayRank = prev.displayRank;
                } else {
                  currentRank = i + 1;
                  curr.displayRank = currentRank;
                }
              } else {
                rankedClasses[i].displayRank = 1;
              }
            }

            final currentYear = DateTime.now().year;
            final availableYears =
                List.generate(5, (i) => currentYear - 2 + i);

            return CustomScrollView(
              slivers: [
                // 1. Thẻ Bộ Lọc Đồng Nhất (Năm, Tháng, Khối, Danh Mục)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: _buildFilterCard(availableYears, rules),
                  ),
                ),

                // 2. Thẻ Tóm Tắt KPI Toàn Trường
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildKpiBanner(
                      selectedRule: selectedRule,
                      totalPeriodPoints: totalPeriodPoints,
                      totalCategoryQty: totalCategoryQty,
                      activeClassesCount: rankedClasses.length,
                    ),
                  ),
                ),

                // 3. Tiêu đề Bảng Xếp Hạng
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Bảng Xếp Hạng Các Lớp (${rankedClasses.length})',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Row(
                          children: [
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Bảng vàng năm cũ',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              onPressed: () =>
                                  PastAcademicYearsSheet.show(context),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _selectedMonth == 0
                                  ? 'Năm $_selectedYear'
                                  : 'Tháng $_selectedMonth/$_selectedYear',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // 5. Danh Sách Chi Tiết Từng Lớp
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
                              'Chưa có dữ liệu thu gom trong đợt này',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Trong ${_selectedMonth == 0 ? "năm $_selectedYear" : "tháng $_selectedMonth/$_selectedYear"} ${_selectedGrade != 0 ? "của Khối $_selectedGrade" : ""} chưa phát sinh lượt thu gom nào.',
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

  /// Khung bộ lọc Năm, Tháng, Khối và Danh Mục
  Widget _buildFilterCard(
    List<int> availableYears,
    List<PointRuleModel> rules,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
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
          // Dòng 1: Năm & Tháng
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
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: availableYears.map((y) {
                    return DropdownMenuItem<int>(
                      value: y,
                      child: Text(
                        'Năm $y',
                        style: const TextStyle(fontSize: 14),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedYear = val;
                        _recordsStream =
                            _buildRecordsStream(_selectedYear, _selectedMonth);
                      });
                    }
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
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: [
                    const DropdownMenuItem<int>(
                      value: 0,
                      child: Text(
                        'Cả năm',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ...List.generate(12, (i) {
                      final month = i + 1;
                      return DropdownMenuItem<int>(
                        value: month,
                        child: Text(
                          'Tháng $month',
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedMonth = val;
                        _recordsStream =
                            _buildRecordsStream(_selectedYear, _selectedMonth);
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Dòng 2: Khối học
          DropdownButtonFormField<int>(
            initialValue: _selectedGrade,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Khối Lớp',
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: const [
              DropdownMenuItem<int>(
                value: 0,
                child: Text('Tất cả các khối', style: TextStyle(fontSize: 14)),
              ),
              DropdownMenuItem<int>(
                value: 6,
                child: Text('Khối 6', style: TextStyle(fontSize: 14)),
              ),
              DropdownMenuItem<int>(
                value: 7,
                child: Text('Khối 7', style: TextStyle(fontSize: 14)),
              ),
              DropdownMenuItem<int>(
                value: 8,
                child: Text('Khối 8', style: TextStyle(fontSize: 14)),
              ),
              DropdownMenuItem<int>(
                value: 9,
                child: Text('Khối 9', style: TextStyle(fontSize: 14)),
              ),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedGrade = val);
            },
          ),
          const SizedBox(height: 10),

          // Dòng 3: Danh Mục Thu Gom (Điểm hoặc cụ thể theo phế liệu)
          DropdownButtonFormField<String>(
            initialValue: _selectedRuleId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Danh Mục Xếp Hạng',
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: [
              const DropdownMenuItem<String>(
                value: '',
                child: Text(
                  'Tất cả danh mục (Xếp theo điểm)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              ...rules.map((rule) {
                return DropdownMenuItem<String>(
                  value: rule.id,
                  child: Text(
                    '${rule.name} (${rule.unit})',
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedRuleId = val);
            },
          ),
        ],
      ),
    );
  }

  /// Banner Tóm Tắt KPI
  Widget _buildKpiBanner({
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
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAll
                          ? 'TỔNG KẾT THU GOM'
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
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$activeClassesCount Lớp',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 2 ô chỉ số KPI
          Row(
            children: [
              if (isAll) ...[
                Expanded(
                  child: _buildKpiStatTile(
                    label: 'Tổng Điểm Đã Tích',
                    value: '+$totalPeriodPoints đ',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildKpiStatTile(
                    label: 'Số Lớp Tham Gia',
                    value: '$activeClassesCount lớp',
                  ),
                ),
              ] else ...[
                Expanded(
                  child: _buildKpiStatTile(
                    label: 'Tổng Thu Gom',
                    value: totalCategoryQty % 1 == 0
                        ? '${totalCategoryQty.toInt()} ${selectedRule.unit}'
                        : '${totalCategoryQty.toStringAsFixed(1)} ${selectedRule.unit}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildKpiStatTile(
                    label: 'Số Lớp Đã Nộp',
                    value: '$activeClassesCount lớp',
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
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Thẻ chi tiết từng lớp trong bảng tổng sắp
  Widget _buildRankedClassCard(
    BuildContext context,
    _ClassStatsData stats, {
    required PointRuleModel? selectedRule,
  }) {
    final rank = stats.displayRank;
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
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            '$rank',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    final isAll = selectedRule == null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: rank <= 3
              ? rankColor.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      child: ListTile(
        onTap: () => ClassDetailsSheet.show(context, stats.className),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: rankBadge,
        title: Row(
          children: [
            Text(
              'Lớp ${stats.className}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Khối ${stats.grade}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (stats.isTieWithPrevious) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Đồng hạng',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          '${stats.submissionCount} lượt thu gom',
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            isAll
                ? '+${stats.totalPoints} đ'
                : (stats.categoryQuantity % 1 == 0
                    ? '${stats.categoryQuantity.toInt()} ${selectedRule.unit}'
                    : '${stats.categoryQuantity.toStringAsFixed(1)} ${selectedRule.unit}'),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppColors.primaryDark,
            ),
          ),
        ),
      ),
    );
  }
}

class _ClassStatsData {
  final String className;
  final int grade;
  int totalPoints = 0;
  double categoryQuantity = 0.0;
  int submissionCount = 0;
  DateTime? latestSubmissionTime;
  int displayRank = 1;
  bool isTieWithPrevious = false;

  _ClassStatsData({
    required this.className,
    required this.grade,
  });
}
