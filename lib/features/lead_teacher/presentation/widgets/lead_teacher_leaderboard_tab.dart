import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../admin/models/point_rule_model.dart';
import '../../../admin/services/point_rule_service.dart';
import '../../../teacher/presentation/widgets/class_details_sheet.dart';

/// Tab Xếp Hạng dành cho Tổng Phụ Trách
/// Hỗ trợ xếp hạng ĐỘNG:
/// - Mặc định: Xếp hạng theo Tổng Điểm Thi Đua toàn trường.
/// - Chọn danh mục cụ thể (tải động từ point_rules): Xếp hạng theo số lượng thu gom của loại đó (Chai nhựa, Lon nhôm, Giấy, Pin, Bút...).
/// - Lọc theo Khối (Tất cả, Khối 6, 7, 8, 9).
class LeadTeacherLeaderboardTab extends StatefulWidget {
  const LeadTeacherLeaderboardTab({super.key});

  @override
  State<LeadTeacherLeaderboardTab> createState() =>
      _LeadTeacherLeaderboardTabState();
}

class _LeadTeacherLeaderboardTabState extends State<LeadTeacherLeaderboardTab> {
  final PointRuleService _pointRuleService = PointRuleService();

  late final Stream<QuerySnapshot> _classesStream;
  late final Stream<List<PointRuleModel>> _rulesStream;
  late final Stream<QuerySnapshot> _pointRecordsStream;

  int _selectedGradeFilter = 0; // 0: Tất cả, 6: Khối 6, 7: Khối 7...
  String _selectedRuleId = ''; // '' = Tất cả danh mục (Xếp hạng theo tổng điểm)

  @override
  void initState() {
    super.initState();
    _classesStream =
        FirebaseFirestore.instance.collection('classes').snapshots();
    _rulesStream = _pointRuleService.getPointRulesStream(onlyActive: true);
    _pointRecordsStream =
        FirebaseFirestore.instance.collection('point_records').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PointRuleModel>>(
      stream: _rulesStream,
      builder: (context, rulesSnap) {
        final rules = rulesSnap.data ?? [];

        return StreamBuilder<QuerySnapshot>(
          stream: _classesStream,
          builder: (context, classesSnap) {
            if (classesSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final classDocs = classesSnap.data?.docs ?? [];

            return StreamBuilder<QuerySnapshot>(
              stream: _pointRecordsStream,
              builder: (context, recordsSnap) {
                final recordDocs = recordsSnap.data?.docs ?? [];

                return _buildLeaderboardContent(
                  context,
                  rules: rules,
                  classDocs: classDocs,
                  recordDocs: recordDocs,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildLeaderboardContent(
    BuildContext context, {
    required List<PointRuleModel> rules,
    required List<QueryDocumentSnapshot> classDocs,
    required List<QueryDocumentSnapshot> recordDocs,
  }) {
    // 1. Xác định rule đang chọn (nếu có)
    PointRuleModel? selectedRule;
    if (_selectedRuleId.isNotEmpty) {
      try {
        selectedRule = rules.firstWhere((r) => r.id == _selectedRuleId);
      } catch (_) {
        selectedRule = null;
      }
    }

    // 2. Thu thập dữ liệu từng lớp
    final Map<String, _ClassRankData> classDataMap = {};

    // Khởi tạo tất cả lớp từ collection `classes`
    for (var doc in classDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final className = (data['className'] as String? ?? doc.id).toUpperCase();
      final totalPts = (data['totalPoints'] as num?)?.toInt() ?? 0;
      int grade =
          int.tryParse(className.isNotEmpty ? className[0] : '0') ?? 0;

      classDataMap[className] = _ClassRankData(
        className: className,
        grade: grade,
        totalPoints: totalPts,
      );
    }

    // Tổng hợp số liệu từ collection `point_records`
    int totalSchoolPoints = 0;
    double totalSelectedCategoryQty = 0.0;
    int activeClassesForCategory = 0;

    for (var doc in recordDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final className =
          (data['className'] as String? ?? '').trim().toUpperCase();
      if (className.isEmpty) continue;

      final ruleId = data['ruleId'] as String? ?? '';
      final categoryName = (data['categoryName'] as String? ?? '').trim();
      final quantity = (data['quantity'] as num?)?.toDouble() ?? 0.0;
      final totalPts = (data['totalPoints'] as num?)?.toInt() ?? 0;

      totalSchoolPoints += totalPts;

      // Đảm bảo lớp có trong map kể cả khi collection `classes` chưa có
      if (!classDataMap.containsKey(className)) {
        int grade =
            int.tryParse(className.isNotEmpty ? className[0] : '0') ?? 0;
        classDataMap[className] = _ClassRankData(
          className: className,
          grade: grade,
          totalPoints: totalPts,
        );
      }

      final classItem = classDataMap[className]!;
      classItem.submissionCount++;

      // Kiểm tra xem bản ghi này có khớp với danh mục đang chọn không
      if (selectedRule != null) {
        final isMatchRule = (ruleId.isNotEmpty && ruleId == selectedRule.id) ||
            categoryName.toLowerCase() == selectedRule.name.toLowerCase();

        if (isMatchRule) {
          classItem.categoryQuantity += quantity;
          classItem.categoryPoints += totalPts;
          totalSelectedCategoryQty += quantity;
        }
      }
    }

    // Đếm số lớp có tham gia danh mục đang chọn
    if (selectedRule != null) {
      activeClassesForCategory = classDataMap.values
          .where((c) => c.categoryQuantity > 0)
          .length;
    }

    // 3. Sắp xếp danh sách lớp
    List<_ClassRankData> rankedList = classDataMap.values.toList();

    if (selectedRule == null) {
      // Xếp hạng theo Tổng Điểm Thi Đua
      rankedList.sort((a, b) {
        final cmp = b.totalPoints.compareTo(a.totalPoints);
        if (cmp != 0) return cmp;
        return a.className.compareTo(b.className);
      });
    } else {
      // Xếp hạng theo Số Lượng Thu Gom của danh mục được chọn
      rankedList.sort((a, b) {
        final cmp = b.categoryQuantity.compareTo(a.categoryQuantity);
        if (cmp != 0) return cmp;
        final ptsCmp = b.categoryPoints.compareTo(a.categoryPoints);
        if (ptsCmp != 0) return ptsCmp;
        return a.className.compareTo(b.className);
      });
    }

    // 4. Lọc theo Khối
    if (_selectedGradeFilter != 0) {
      rankedList =
          rankedList.where((c) => c.grade == _selectedGradeFilter).toList();
    }

    return CustomScrollView(
      slivers: [
        // 1. BỘ CHỌN DANH MỤC & KHỐI DẠNG SELECT
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: [
                // Ô 1: Chọn Danh Mục
                Expanded(
                  flex: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedRuleId,
                        isExpanded: true,
                        icon: const Icon(
                          Icons.arrow_drop_down_rounded,
                          color: AppColors.primary,
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.stars_rounded,
                                  color: AppColors.primary,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Tất cả danh mục',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...rules.map((rule) {
                            return DropdownMenuItem<String>(
                              value: rule.id,
                              child: Row(
                                children: [
                                  Icon(
                                    rule.iconData,
                                    color: AppColors.primary,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${rule.name} (${rule.unit})',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedRuleId = val);
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Ô 2: Chọn Khối
                Expanded(
                  flex: 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedGradeFilter,
                        isExpanded: true,
                        icon: const Icon(
                          Icons.arrow_drop_down_rounded,
                          color: AppColors.primary,
                        ),
                        items: const [
                          DropdownMenuItem<int>(
                            value: 0,
                            child: Text(
                              'Tất cả khối',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem<int>(
                            value: 6,
                            child: Text(
                              'Khối 6',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem<int>(
                            value: 7,
                            child: Text(
                              'Khối 7',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem<int>(
                            value: 8,
                            child: Text(
                              'Khối 8',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem<int>(
                            value: 9,
                            child: Text(
                              'Khối 9',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedGradeFilter = val);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 2. BANNER THỐNG KÊ TỔNG QUAN THEO DANH MỤC ĐÃ CHỌN
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: _buildBanner(
              selectedRule: selectedRule,
              totalSchoolPoints: totalSchoolPoints,
              totalSelectedCategoryQty: totalSelectedCategoryQty,
              activeClassesCount: selectedRule == null
                  ? classDataMap.length
                  : activeClassesForCategory,
            ),
          ),
        ),

        // 4. DANH SÁCH XẾP HẠNG CÁC LỚP
        if (rankedList.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Không có lớp nào trong khối này.',
                  style: TextStyle(color: AppColors.textSecondary),
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
                  final item = rankedList[index];
                  return _buildClassRankItem(
                    context,
                    rank: index + 1,
                    item: item,
                    selectedRule: selectedRule,
                  );
                },
                childCount: rankedList.length,
              ),
            ),
          ),
      ],
    );
  }

  /// Banner tổng quan
  Widget _buildBanner({
    required PointRuleModel? selectedRule,
    required int totalSchoolPoints,
    required double totalSelectedCategoryQty,
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
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                          ? 'Bảng Xếp Hạng Toàn Trường'
                          : 'Xếp Hạng: ${selectedRule.name}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isAll
                          ? 'Tổng hợp điểm thi đua các lớp'
                          : 'Tổng hợp số lượng thu gom các lớp',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
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

          // Các ô thống kê nhanh
          Row(
            children: [
              if (isAll) ...[
                Expanded(
                  child: _buildStatTile(
                    icon: Icons.stars_rounded,
                    label: 'Tổng Điểm',
                    value: '$totalSchoolPoints đ',
                    iconColor: Colors.amberAccent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatTile(
                    icon: Icons.school_rounded,
                    label: 'Số Lớp Tham Gia',
                    value: '$activeClassesCount lớp',
                    iconColor: Colors.cyanAccent,
                  ),
                ),
              ] else ...[
                Expanded(
                  child: _buildStatTile(
                    icon: selectedRule.iconData,
                    label: 'Tổng Thu Gom',
                    value: totalSelectedCategoryQty % 1 == 0
                        ? '${totalSelectedCategoryQty.toInt()} ${selectedRule.unit}'
                        : '${totalSelectedCategoryQty.toStringAsFixed(1)} ${selectedRule.unit}',
                    iconColor: Colors.amberAccent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatTile(
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

  Widget _buildStatTile({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Thẻ xếp hạng từng lớp
  Widget _buildClassRankItem(
    BuildContext context, {
    required int rank,
    required _ClassRankData item,
    required PointRuleModel? selectedRule,
  }) {
    Widget rankBadge;
    if (rank == 1) {
      rankBadge = Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: Color(0xFFFFD700),
          shape: BoxShape.circle,
        ),
        child: const Center(child: Text('🥇', style: TextStyle(fontSize: 16))),
      );
    } else if (rank == 2) {
      rankBadge = Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: Color(0xFFC0C0C0),
          shape: BoxShape.circle,
        ),
        child: const Center(child: Text('🥈', style: TextStyle(fontSize: 16))),
      );
    } else if (rank == 3) {
      rankBadge = Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: Color(0xFFCD7F32),
          shape: BoxShape.circle,
        ),
        child: const Center(child: Text('🥉', style: TextStyle(fontSize: 16))),
      );
    } else {
      rankBadge = Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            '$rank',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
              fontSize: 14,
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
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: ListTile(
        onTap: () => ClassDetailsSheet.show(context, item.className),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: rankBadge,
        title: Text(
          'Lớp ${item.className}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          'Khối ${item.grade}',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            isAll
                ? '${item.totalPoints} đ'
                : (item.categoryQuantity % 1 == 0
                    ? '${item.categoryQuantity.toInt()} ${selectedRule.unit}'
                    : '${item.categoryQuantity.toStringAsFixed(1)} ${selectedRule.unit}'),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.primaryDark,
            ),
          ),
        ),
      ),
    );
  }
}

class _ClassRankData {
  final String className;
  final int grade;
  final int totalPoints;
  int submissionCount = 0;
  double categoryQuantity = 0.0;
  int categoryPoints = 0;

  _ClassRankData({
    required this.className,
    required this.grade,
    required this.totalPoints,
  });
}
