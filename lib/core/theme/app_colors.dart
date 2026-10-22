import 'package:flutter/material.dart';

/// Bảng màu chuẩn cho toàn bộ ứng dụng "Hành Động Xanh"
/// Thiết kế theo chủ đề Sinh Thái / Thiên Nhiên / Trường Học Xanh
class AppColors {
  // === TÔNG MÀU CHÍNH (PRIMARY - FOREST & LEAF GREEN) ===
  /// Xanh lá rừng đậm - Màu nhận diện thương hiệu chủ đạo, trang nhã, chuyên nghiệp
  static const Color primary = Color(0xFF1B5E20);

  /// Xanh rừng thẫm - Dùng cho Header, Gradient đậm, Text tiêu đề chính
  static const Color primaryDark = Color(0xFF0F3E13);

  /// Xanh chồi non / lá cây tươi sáng - Dùng cho điểm nhấn, trạng thái tích cực
  static const Color primaryLight = Color(0xFF2E7D32);

  /// Xanh bạc hà nhẹ dịu (Mint 50) - Nền icon, banner, badge nhẹ
  static const Color primaryMint = Color(0xFFE8F5E9);

  /// Xanh ngọc container (Mint 100) - Khung viền hoặc điểm nhấn nhẹ
  static const Color primaryContainer = Color(0xFFC8E6C9);

  // === TÔNG MÀU PHỤ (SECONDARY & ACCENT - EMERALD & SAGE) ===
  /// Xanh ngọc bích / Teal thiên nhiên
  static const Color secondary = Color(0xFF00796B);

  /// Nền xanh ngọc nhạt
  static const Color secondaryLight = Color(0xFFE0F2F1);

  /// Xanh xô thơm (Sage Green)
  static const Color sage = Color(0xFF388E3C);

  // === TÔNG NỀN & BỀ MẶT (SURFACE & ECO BACKGROUND) ===
  /// Nền toàn app: Trắng ngà ánh xanh sinh thái, rất dịu và mát mắt
  static const Color background = Color(0xFFF7FAF7);

  /// Bề mặt card, popup, dialog: Trắng tinh khiết
  static const Color surface = Colors.white;

  /// Bề mặt phụ: Trắng ánh ngọc nhẹ
  static const Color surfaceVariant = Color(0xFFF0F7F1);

  /// Viền card / khung nhập liệu: Viền xanh ngọc rất mảnh tinh tế
  static const Color border = Color(0xFFDCE7DC);

  // === MÀU PHÂN QUYỀN VAI TRÒ (HARMONIZED ECO ROLES) ===
  /// Admin: Xanh đại thụ sẫm (Forest Pine) - Uy quyền, tin cậy
  static const Color roleAdmin = Color(0xFF065F46);
  static const Color roleAdminLight = Color(0xFFD1FAE5);

  /// Lead Teacher (Tổng phụ trách): Nắng mai / Hổ phách sinh thái (Warm Amber)
  static const Color roleLeadTeacher = Color(0xFFD97706);
  static const Color roleLeadTeacherLight = Color(0xFFFEF3C7);

  /// Teacher (Giáo viên chủ nhiệm): Chồi non tươi tắn (Fresh Leaf)
  static const Color roleTeacher = Color(0xFF16A34A);
  static const Color roleTeacherLight = Color(0xFFDCFCE7);

  // === MÀU NGHIỆP VỤ & TRẠNG THÁI (SEMANTIC) ===
  /// Thành công / Đang hoạt động
  static const Color success = Color(0xFF16A34A);
  static const Color successLight = Color(0xFFDCFCE7);

  /// Cảnh báo / Nhắc nhở
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);

  /// Lỗi / Đã khóa / Đăng xuất
  static const Color error = Color(0xFFDC2626);
  static const Color errorLight = Color(0xFFFEE2E2);

  // === MÀU CHỮ & TRUNG TÍNH (NEUTRALS) ===
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color divider = Color(0xFFE5E7EB);
}
