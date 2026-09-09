# 🤖 Robot Nội Địa (com.robot.noidia)

> Ứng dụng iOS (SwiftUI Native) điều khiển trực tiếp robot hút bụi lau nhà Ecovacs nội địa (T10 Turbo, T9 AIVI, X1,...) không qua server trung gian.

[![Latest Release](https://img.shields.io/github/v/release/vnnit/Robot-noi-dia-ca-nhan?color=blue&label=B%E1%BA%A3n%20m%E1%BB%9Bi%20nh%E1%BA%A5t)](https://github.com/vnnit/Robot-noi-dia-ca-nhan/releases/latest)

---

## ✨ Tính Năng Cơ Bản

- **Quản lý thiết bị**: Đăng nhập tài khoản Ecovacs, tự lưu phiên, xem trạng thái pin/sạc và đổi tên robot.
- **Điều khiển dọn dẹp**:
  - Dọn dẹp tự động (Auto), theo phòng (Room) hoặc khoanh vùng tùy chỉnh (Custom Area).
  - Tạm dừng, tiếp tục, kết thúc và gọi robot về trạm sạc.
  - Điều khiển thủ công 4 hướng (Remote D-Pad).
- **Bản đồ LiDAR thời gian thực**:
  - Xem bản đồ LiDAR sắc nét (hỗ trợ zoom và kéo bản đồ).
  - Hiển thị vị trí robot, trạm sạc và vẽ quỹ đạo di chuyển trực tiếp.
  - Thiết lập tường ảo và vùng cấm dọn dẹp.
  - Sao lưu và khôi phục bản đồ đa tầng.
- **Giao tiếp mạng nội bộ (Local LAN Wi-Fi)**:
  - Tự động dò tìm robot qua mDNS Bonjour (`_ecvs-iot._tcp`, `_matter._tcp`).
  - Phản hồi vị trí và trạng thái tức thời qua mạng Wi-Fi gia đình (~8ms).
- **Tùy chỉnh công suất**:
  - 4 mức lực hút bụi và 4 mức cấp nước lau sàn.
  - Tùy chọn dọn 1 lần hoặc 2 lần chuyên sâu.
  - Tự động tăng lực hút khi lên thảm, khóa trẻ em.
- **Trạm sạc thông minh**: Điều khiển giặt sấy giẻ lau và tự động gom rác vào túi bụi trạm.
- **Linh kiện & Thống kê**:
  - Theo dõi tuổi thọ linh kiện (chổi, màng lọc, giẻ lau) kèm nút reset khi thay mới.
  - Xem nhật ký và lịch sử dọn dẹp.
- **Lên lịch tự động**: Đặt lịch hẹn giờ dọn dẹp theo ngày và giờ trong tuần.
- **Thông báo iOS**: Nhận thông báo khi hoàn thành dọn, pin yếu hoặc cảnh báo lỗi trạm/robot.

---

## 📲 Cài Đặt (File IPA)

1. Tải file `.ipa` mới nhất tại mục [Releases](https://github.com/vnnit/Robot-noi-dia-ca-nhan/releases).
2. Cài đặt lên iPhone bằng:
   - **TrollStore** (Khuyên dùng)
   - **Scarlet / Esign / GBox**
   - **AltStore / Sideloadly** (Cài qua máy tính)
