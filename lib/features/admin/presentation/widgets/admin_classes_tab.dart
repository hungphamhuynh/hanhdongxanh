import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/string_utils.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../../teacher/presentation/widgets/class_details_sheet.dart';
import '../../services/admin_class_service.dart';
import 'close_school_year_dialog.dart';
import 'past_school_years_sheet.dart';

class AdminClassesTab extends StatefulWidget {
  const AdminClassesTab({super.key});

  @override
  State<AdminClassesTab> createState() => _AdminClassesTabState();
}

class _AdminClassesTabState extends State<AdminClassesTab> {
  final _adminClassService = AdminClassService();

  String _searchQuery = '';
  String? _selectedGradeFilter; // null = Tất cả, '6', '7', '8', '9'
  late final Stream<QuerySnapshot> _classesStream;

  @override
  void initState() {
    super.initState();
    _classesStream = _adminClassService.getClassesStream();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _classesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.school_outlined, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                const Text(
                  'Chưa có lớp học nào trong hệ thống.',
                  style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        }

        final allClasses = snapshot.data!.docs;
        final totalClasses = allClasses.length;

        // Phân loại số lượng theo khối
        int countGrade(String prefix) => allClasses.where((doc) {
              final name = (doc.data() as Map<String, dynamic>)['className'] as String? ?? '';
              return name.startsWith(prefix);
            }).length;

        final grade6Count = countGrade('6');
        final grade7Count = countGrade('7');
        final grade8Count = countGrade('8');
        final grade9Count = countGrade('9');

        // Lọc danh sách lớp theo tìm kiếm & khối
        final filteredClasses = allClasses.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final className = (data['className'] as String? ?? '').toLowerCase();
          final teacherEmail = (data['teacherEmail'] as String? ?? '').toLowerCase();

          final matchesSearch = _searchQuery.isEmpty ||
              className.contains(_searchQuery.toLowerCase()) ||
              teacherEmail.contains(_searchQuery.toLowerCase());

          final matchesGrade = _selectedGradeFilter == null ||
              className.startsWith(_selectedGradeFilter!.toLowerCase());

          return matchesSearch && matchesGrade;
        }).toList();

        // Sắp xếp lớp học theo thứ tự tự nhiên (ví dụ 6A1, 6A2 ... 6A12 ... 9A12)
        filteredClasses.sort((a, b) {
          final nameA = (a.data() as Map<String, dynamic>)['className'] as String? ?? '';
          final nameB = (b.data() as Map<String, dynamic>)['className'] as String? ?? '';
          return StringUtils.compareNatural(nameA, nameB);
        });

        return ResponsiveContainer(
          maxWidth: 950,
          child: CustomScrollView(
            slivers: [
              // Thống kê nhanh số lượng lớp
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          title: 'Tổng số lớp',
                          count: '$totalClasses',
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          title: 'Khối 6 & 7',
                          count: '${grade6Count + grade7Count}',
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          title: 'Khối 8 & 9',
                          count: '${grade8Count + grade9Count}',
                          color: AppColors.roleLeadTeacher,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Thanh công cụ Niên khóa: Xem Bảng Vàng & Đóng Sổ Năm Học
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                vertical: 11, horizontal: 10),
                            side: BorderSide(
                                color: AppColors.primary.withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.emoji_events_outlined,
                              size: 18, color: AppColors.primary),
                          label: const Text(
                            'Bảng Vàng Năm Cũ',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          onPressed: () =>
                              PastAcademicYearsSheet.show(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFC2410C),
                            padding: const EdgeInsets.symmetric(
                                vertical: 11, horizontal: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.archive_outlined, size: 18),
                          label: const Text(
                            'Đóng Sổ Năm Học',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () {
                            final user = FirebaseAuth.instance.currentUser;
                            CloseSchoolYearDialog.show(
                              context: context,
                              userEmail: user?.email ?? '',
                              userUid: user?.uid ?? '',
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Thanh tìm kiếm lớp học
              // Thanh tìm kiếm và bộ lọc Khối dạng Select (Mỗi mục 1 dòng độc lập)
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      // Dòng 1: Ô Tìm kiếm lớp (Full width)
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Tìm lớp (6A1, 9A12...) hoặc giáo viên...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () =>
                                      setState(() => _searchQuery = ''),
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          isDense: true,
                        ),
                        onChanged: (val) =>
                            setState(() => _searchQuery = val.trim()),
                      ),
                      const SizedBox(height: 8),

                      // Dòng 2: Ô Select Khối (Full width rõ ràng)
                      DropdownButtonFormField<String?>(
                        initialValue: _selectedGradeFilter,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Lọc theo khối lớp',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          prefixIcon: Icon(Icons.school_rounded, size: 18),
                          prefixIconConstraints:
                              BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text(
                              'Tất cả các khối',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                          DropdownMenuItem<String?>(
                            value: '6',
                            child: Text(
                              'Khối 6 ($grade6Count lớp)',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          DropdownMenuItem<String?>(
                            value: '7',
                            child: Text(
                              'Khối 7 ($grade7Count lớp)',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          DropdownMenuItem<String?>(
                            value: '8',
                            child: Text(
                              'Khối 8 ($grade8Count lớp)',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          DropdownMenuItem<String?>(
                            value: '9',
                            child: Text(
                              'Khối 9 ($grade9Count lớp)',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                        onChanged: (val) =>
                            setState(() => _selectedGradeFilter = val),
                      ),
                    ],
                  ),
                ),
              ),

              // Danh sách lớp học
              if (filteredClasses.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Text(
                        'Không tìm thấy lớp học nào phù hợp.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final doc = filteredClasses[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final className = data['className'] ?? doc.id;
                        final teacherEmail = data['teacherEmail'] ?? 'Chưa có email';
                        final totalPoints = (data['totalPoints'] as num?)?.toInt() ?? 0;

                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            onTap: () => ClassDetailsSheet.show(context, className),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.primaryMint,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  className,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  'Lớp $className',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Text(
                                    'Khối ${className.isNotEmpty ? className[0] : ''}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Row(
                                children: [
                                  const Icon(Icons.account_circle_outlined,
                                      size: 15, color: AppColors.textMuted),
                                  const SizedBox(width: 5),
                                  Text(
                                    teacherEmail,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: totalPoints > 0
                                        ? AppColors.primaryMint
                                        : AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$totalPoints đ',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: totalPoints > 0
                                          ? AppColors.primaryDark
                                          : AppColors.textMuted,
                                    ),
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert),
                                  tooltip: 'Tùy chọn',
                                  onSelected: (action) {
                                    if (action == 'delete') {
                                      _confirmDeleteClass(
                                        context: context,
                                        className: className,
                                        teacherEmail: teacherEmail,
                                      );
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline,
                                              size: 20, color: AppColors.error),
                                          SizedBox(width: 10),
                                          Text(
                                            'Xóa lớp học',
                                            style: TextStyle(color: AppColors.error),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: filteredClasses.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteClass({
    required BuildContext context,
    required String className,
    required String teacherEmail,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Xác nhận xóa lớp $className'),
        content: Text(
          'Bạn có chắc chắn muốn xóa lớp $className không?\n\n'
          '⚠️ Thao tác này sẽ xóa đồng thời tài khoản $teacherEmail liên kết với lớp.',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa lớp & Tài khoản'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _adminClassService.deleteClass(className);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã xóa lớp $className và tài khoản liên quan thành công!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi khi xóa lớp: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}
