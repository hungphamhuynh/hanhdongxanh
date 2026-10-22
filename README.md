# Hành Động Xanh (Green Action)

Ứng dụng Flutter tích điểm thưởng cho các hành động bảo vệ môi trường và lối sống xanh.

## Tính năng hiện tại
- **Đa nền tảng (Cross-platform):** Hỗ trợ Android, iOS và Web với cấu hình Firebase tập trung (`lib/firebase_options.dart`).
- **Xác thực Firebase Auth:** Đăng ký, Đăng nhập bảo mật bằng Email & Mật khẩu.
- **Giám sát kết nối mạng (Network Connectivity):** 
  - Tự động phát hiện và hiển thị thanh cảnh báo ngoại tuyến thời gian thực khi mất mạng.
  - Chặn và thông báo rõ ràng khi người dùng cố gắng đăng nhập/đăng ký mà chưa có Internet.
- **Đồng bộ Điểm thưởng Realtime:** Tự động tạo hồ sơ khách hàng mới và lắng nghe số điểm tích lũy trực tiếp từ Cloud Firestore.
- **Tự động chuyển trang thông minh (Auth Gate):** Lắng nghe trạng thái đăng nhập tự động điều hướng giữa Đăng nhập và Trang chủ.
