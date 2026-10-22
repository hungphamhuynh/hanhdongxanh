import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../models/point_rule_model.dart';
import '../../services/point_rule_service.dart';

class AdminPointRulesTab extends StatefulWidget {
  const AdminPointRulesTab({super.key});

  @override
  State<AdminPointRulesTab> createState() => _AdminPointRulesTabState();
}

class _AdminPointRulesTabState extends State<AdminPointRulesTab> {
  final _pointRuleService = PointRuleService();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PointRuleModel>>(
      stream: _pointRuleService.getPointRulesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allRules = snapshot.data ?? [];

        // Nếu chưa có thể loại nào, hiển thị nút tạo danh mục mẫu
        if (allRules.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: AppColors.primaryMint,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.stars_rounded,
                      size: 64,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Chưa có thể loại tích điểm nào',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Bạn có thể khởi tạo nhanh danh mục mẫu chuẩn phong trào xanh (Pin cũ, Chai nhựa, Vỏ lon, Giấy vụn, Trồng cây) để giáo viên bắt đầu tích điểm.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () async {
                      try {
                        await _pointRuleService.seedDefaultEcoRules();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã khởi tạo danh mục mẫu thành công!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Lỗi: $e'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Khởi Tạo Danh Mục Mẫu Ngay'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final totalCount = allRules.length;
        final activeCount = allRules.where((r) => r.isActive).length;
        final inactiveCount = totalCount - activeCount;

        final filteredRules = allRules.where((r) {
          final query = _searchQuery.toLowerCase();
          return _searchQuery.isEmpty ||
              r.name.toLowerCase().contains(query) ||
              r.unit.toLowerCase().contains(query) ||
              r.description.toLowerCase().contains(query);
        }).toList();

        return ResponsiveContainer(
          maxWidth: 950,
          child: CustomScrollView(
            slivers: [
              // Thống kê nhanh
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          title: 'Tổng thể loại',
                          count: '$totalCount',
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          title: 'Đang áp dụng',
                          count: '$activeCount',
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          title: 'Tạm ngừng',
                          count: '$inactiveCount',
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Tìm kiếm
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Tìm theo tên thể loại, đơn vị...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  ),
                ),
              ),

              // Danh sách thể loại
              if (filteredRules.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Text(
                        'Không tìm thấy thể loại nào phù hợp.',
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
                        final rule = filteredRules[index];

                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: rule.isActive
                                    ? AppColors.primaryMint
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                rule.iconData,
                                color: rule.isActive
                                    ? AppColors.primary
                                    : Colors.grey.shade500,
                                size: 26,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    rule.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: rule.isActive
                                          ? AppColors.textPrimary
                                          : Colors.grey,
                                      decoration: rule.isActive
                                          ? null
                                          : TextDecoration.lineThrough,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: rule.isActive
                                        ? AppColors.primaryContainer
                                        : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '+${rule.pointsPerUnit} điểm / ${rule.unit}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: rule.isActive
                                          ? AppColors.primaryDark
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                rule.description.isEmpty
                                    ? 'Quy đổi: 1 ${rule.unit} = ${rule.pointsPerUnit} điểm tích lũy'
                                    : rule.description,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            trailing: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              tooltip: 'Tùy chọn',
                              onSelected: (action) {
                                switch (action) {
                                  case 'edit':
                                    _showEditRuleDialog(context, rule);
                                    break;
                                  case 'toggle':
                                    _pointRuleService.togglePointRuleActive(
                                      id: rule.id,
                                      currentActive: rule.isActive,
                                    );
                                    break;
                                  case 'delete':
                                    _confirmDeleteRule(context, rule);
                                    break;
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined, size: 20),
                                      SizedBox(width: 10),
                                      Text('Chỉnh sửa'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'toggle',
                                  child: Row(
                                    children: [
                                      Icon(
                                        rule.isActive
                                            ? Icons.pause_circle_outline
                                            : Icons.play_circle_outline,
                                        size: 20,
                                        color: rule.isActive
                                            ? AppColors.warning
                                            : AppColors.success,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(rule.isActive
                                          ? 'Tạm ngừng áp dụng'
                                          : 'Kích hoạt áp dụng'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline,
                                          size: 20, color: AppColors.error),
                                      SizedBox(width: 10),
                                      Text(
                                        'Xóa thể loại',
                                        style: TextStyle(color: AppColors.error),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: filteredRules.length,
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

  void _showEditRuleDialog(BuildContext context, PointRuleModel rule) {
    final nameCtrl = TextEditingController(text: rule.name);
    final unitCtrl = TextEditingController(text: rule.unit);
    final pointsCtrl = TextEditingController(text: '${rule.pointsPerUnit}');
    final descCtrl = TextEditingController(text: rule.description);
    String selectedIcon = rule.iconName;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Chỉnh Sửa Thể Loại Tích Điểm'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tên thể loại *',
                    hintText: 'Ví dụ: Pin cũ, Chai nhựa...',
                    prefixIcon: Icon(Icons.stars_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: TextField(
                        controller: unitCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Đơn vị tính *',
                          hintText: 'viên, chai, kg...',
                          prefixIcon: Icon(Icons.straighten_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 5,
                      child: TextField(
                        controller: pointsCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          labelText: 'Điểm thưởng *',
                          hintText: '5, 10...',
                          prefixIcon: Icon(Icons.add_circle_outline),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả quy đổi',
                    hintText: 'Ghi chú thêm về quy định thu gom...',
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Chọn biểu tượng nhận diện:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildIconOption(
                      iconName: 'battery',
                      label: 'Pin',
                      iconData: Icons.battery_charging_full_rounded,
                      isSelected: selectedIcon == 'battery',
                      onTap: () => setDialogState(() => selectedIcon = 'battery'),
                    ),
                    _buildIconOption(
                      iconName: 'bottle',
                      label: 'Chai',
                      iconData: Icons.local_drink_rounded,
                      isSelected: selectedIcon == 'bottle',
                      onTap: () => setDialogState(() => selectedIcon = 'bottle'),
                    ),
                    _buildIconOption(
                      iconName: 'can',
                      label: 'Lon',
                      iconData: Icons.recycling_rounded,
                      isSelected: selectedIcon == 'can',
                      onTap: () => setDialogState(() => selectedIcon = 'can'),
                    ),
                    _buildIconOption(
                      iconName: 'paper',
                      label: 'Giấy',
                      iconData: Icons.newspaper_rounded,
                      isSelected: selectedIcon == 'paper',
                      onTap: () => setDialogState(() => selectedIcon = 'paper'),
                    ),
                    _buildIconOption(
                      iconName: 'tree',
                      label: 'Cây',
                      iconData: Icons.park_rounded,
                      isSelected: selectedIcon == 'tree',
                      onTap: () => setDialogState(() => selectedIcon = 'tree'),
                    ),
                    _buildIconOption(
                      iconName: 'eco',
                      label: 'Khác',
                      iconData: Icons.eco_rounded,
                      isSelected: selectedIcon == 'eco',
                      onTap: () => setDialogState(() => selectedIcon = 'eco'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: isLoading
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      final unit = unitCtrl.text.trim();
                      final points = int.tryParse(pointsCtrl.text.trim()) ?? 0;

                      if (name.isEmpty || points <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Vui lòng điền tên và số điểm > 0!'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isLoading = true);
                      try {
                        await _pointRuleService.updatePointRule(
                          id: rule.id,
                          name: name,
                          unit: unit,
                          pointsPerUnit: points,
                          description: descCtrl.text.trim(),
                          iconName: selectedIcon,
                        );

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Đã cập nhật $name thành công!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$e'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      } finally {
                        setDialogState(() => isLoading = false);
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Lưu Thay Đổi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconOption({
    required String iconName,
    required String label,
    required IconData iconData,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      selected: isSelected,
      avatar: Icon(
        iconData,
        size: 16,
        color: isSelected ? Colors.white : AppColors.primary,
      ),
      label: Text(label),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (_) => onTap(),
    );
  }

  Future<void> _confirmDeleteRule(
      BuildContext context, PointRuleModel rule) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Xác nhận xóa thể loại: ${rule.name}'),
        content: Text(
          'Bạn có chắc chắn muốn xóa "${rule.name}" khỏi danh mục điểm thưởng không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa thể loại'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _pointRuleService.deletePointRule(rule.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã xóa ${rule.name} thành công!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}
