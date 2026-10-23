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
    int totalSchoolSubmissions = 0;
    int totalSchoolPoints = 0;
    double totalSelectedCategoryQty = 0.0;
    int totalSelectedCategoryPoints = 0;
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

      totalSchoolSubmissions++;
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
          totalSelectedCategoryPoints += totalPts;
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
        // 1. THANH CHỌN DANH MỤC ĐỘNG (Lấy từ point_rules)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.category_rounded,
                        size: 16, color: AppColors.primary),
                    SizedBox(width: 6),
                    Text(
                      'Xếp hạng theo danh mục:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Tất cả danh mục
                      _buildCategoryChip(
                        label: 'Tất cả danh mục',
                        icon: Icons.stars_rounded,
                        isSelected: _selectedRuleId.isEmpty,
                        onTap: () => setState(() => _selectedRuleId = ''),
                      ),
                      const SizedBox(width: 8),

                      // Danh sách các danh mục động từ Admin
                      ...rules.map((rule) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildCategoryChip(
                            label: rule.name,
                            icon: rule.iconData,
                            isSelected: _selectedRuleId == rule.id,
                            onTap: () =>
                                setState(() => _selectedRuleId = rule.id),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // 2. BANNER THỐNG KÊ TỔNG QUAN THEO DANH MỤC ĐÃ CHỌN
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: _buildBanner(
              selectedRule: selectedRule,
              totalSchoolPoints: totalSchoolPoints,
              totalSchoolSubmissions: totalSchoolSubmissions,
              totalSelectedCategoryQty: totalSelectedCategoryQty,
              totalSelectedCategoryPoints: totalSelectedCategoryPoints,
              activeClassesCount: selectedRule == null
                  ? classDataMap.length
                  : activeClassesForCategory,
            ),
          ),
        ),

        // 3. THANH LỌC KHỐI
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildGradeChip(label: 'Tất Cả Khối', grade: 0),
                  const SizedBox(width: 8),
                  _buildGradeChip(label: 'Khối 6', grade: 6),
                  const SizedBox(width: 8),
                  _buildGradeChip(label: 'Khối 7', grade: 7),
                  const SizedBox(width: 8),
                  _buildGradeChip(label: 'Khối 8', grade: 8),
                  const SizedBox(width: 8),
                  _buildGradeChip(label: 'Khối 9', grade: 9),
                ],
              ),
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

  /// Chip chọn danh mục
  Widget _buildCategoryChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Chip lọc khối
  Widget _buildGradeChip({required String label, required int grade}) {
    final isSelected = _selectedGradeFilter == grade;
    return ChoiceChip(
      selected: isSelected,
      label: Text(label),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : AppColors.textPrimary,
      ),
      onSelected: (_) => setState(() => _selectedGradeFilter = grade),
    );
  }

  /// Banner tổng quan
  Widget _buildBanner({
    required PointRuleModel? selectedRule,
    required int totalSchoolPoints,
    required int totalSchoolSubmissions,
    required double totalSelectedCategoryQty,
    required int totalSelectedCategoryPoints,
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
                          : 'Tỷ lệ quy đổi: ${selectedRule.ruleRateText}',
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
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatTile(
                    icon: Icons.assignment_turned_in_rounded,
                    label: 'Đợt Thu Gom',
                    value: '$totalSchoolSubmissions đợt',
                    iconColor: Colors.lightGreenAccent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatTile(
                    icon: Icons.school_rounded,
                    label: 'Lớp Tham Gia',
                    value: '$activeClassesCount lớp',
                    iconColor: Colors.cyanAccent,
                  ),
                ),
              ] else ...[
                Expanded(
                  child: _buildStatTile(
                    icon: selectedRule.iconData,
                    label: 'Đã Thu Gom',
                    value: totalSelectedCategoryQty % 1 == 0
                        ? '${totalSelectedCategoryQty.toInt()} ${selectedRule.unit}'
                        : '${totalSelectedCategoryQty.toStringAsFixed(1)} ${selectedRule.unit}',
                    iconColor: Colors.amberAccent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatTile(
                    icon: Icons.stars_rounded,
                    label: 'Điểm Đã Tích',
                    value: '+$totalSelectedCategoryPoints đ',
                    iconColor: Colors.lightGreenAccent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatTile(
                    icon: Icons.group_rounded,
                    label: 'Lớp Đã Nộp',
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
          isAll
              ? 'Khối ${item.grade} • ${item.submissionCount} đợt nộp'
              : 'Đã gom: ${item.categoryQuantity % 1 == 0 ? item.categoryQuantity.toInt() : item.categoryQuantity.toStringAsFixed(1)} ${selectedRule.unit} • +${item.categoryPoints} đ',
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
