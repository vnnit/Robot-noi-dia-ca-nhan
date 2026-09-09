# 🤖 Robot Nội Địa (com.robot.noidia)

> 🎓 **Dự án cá nhân phục vụ mục đích học tập, nghiên cứu kỹ thuật lập trình iOS (SwiftUI Native, MVVM, MQTT/IoT, Zero-Server Direct Cloud) và phục vụ nhu cầu điều khiển robot Ecovacs nội địa trong gia đình.**

[![Build & Release iOS IPA](https://github.com/vnnit/Robot-noi-dia-ca-nhan/actions/workflows/build-ios.yml/badge.svg)](https://github.com/vnnit/Robot-noi-dia-ca-nhan/actions/workflows/build-ios.yml)
[![Latest Release](https://img.shields.io/github/v/release/vnnit/Robot-noi-dia-ca-nhan?color=blue&label=B%E1%BA%A3n%20m%E1%BB%9Bi%20nh%E1%BA%A5t)](https://github.com/vnnit/Robot-noi-dia-ca-nhan/releases/latest)

---

## 📌 1. Tổng Quan Dự Án

**Robot Nội Địa** là ứng dụng iOS được viết hoàn toàn bằng **SwiftUI Native**, kết nối trực tiếp không qua server trung gian riêng (*100% Zero-Server*) tới hệ sinh thái máy chủ Ecovacs (Cloud API & MQTT IoT Gateway). Ứng dụng giúp người dùng quản lý và điều khiển các dòng robot hút bụi lau nhà Ecovacs nội địa Trung Quốc (như DEEBOT T10 TURBO, DEEBOT T9 AIVI,...) mượt mà, tiện lợi trên iPhone.

---

## ✨ 2. Các Tính Năng Hiện Tại

### 🔑 Xác Thực & Quản Lý Robot
- **Đăng nhập tài khoản nội địa**: Hỗ trợ đăng nhập bằng tài khoản Ecovacs ID / Số điện thoại, mã hóa mật khẩu MD5 chuẩn Ecovacs Auth API.
- **Tự động lưu phiên (Persistent Session)**: Đăng nhập 1 lần, tự động gia hạn token và vào thẳng bảng điều khiển khi mở app.
- **Màn hình chọn Robot (Robot Picker)**:
  - Hiển thị danh sách toàn bộ robot trong tài khoản.
  - Theo dõi nhanh trạng thái Online/Offline, % Pin thực tế, trạng thái đang sạc hay đang dọn dẹp ngay trên từng thẻ robot mà không cần bấm vào trong.
- **Đổi tên gợi nhớ cho Robot**: Cho phép tùy chỉnh tên hiển thị của robot theo ý thích.

### 🎮 Điều Khiển Dọn Dẹp Toàn Diện
- **Chế độ dọn dẹp linh hoạt**:
  - Dọn dẹp **Tự động (Auto)** toàn bộ sàn nhà.
  - Dọn dẹp **Theo phòng (Room)**: Chọn các phòng cần dọn.
  - Dọn dẹp **Khoanh vùng tùy chỉnh (Custom Area)**: Kéo thả khung dọn dẹp trên bản đồ.
- **Điều khiển trạng thái**: Bắt đầu dọn, Tạm dừng, Tiếp tục, Dừng dọn dẹp, và Lệnh về trạm sạc (**Về dock**).
- **Bộ điều khiển từ xa (Remote D-Pad)**: Lái robot thủ công với 4 hướng di chuyển (Tiến, Lùi, Quay trái, Quay phải).

### ⚙️ Cấu Hình Công Suất & Trạm Thông Minh
- **Lực hút bụi**: 4 mức điều chỉnh (Yên tĩnh, Tiêu chuẩn, Mạnh, Siêu mạnh).
- **Lượng nước lau sàn**: 4 mức độ ẩm khăn lau.
- **Số lượt dọn dẹp**: Chọn 1 lần hoặc 2 lần dọn kỹ.
- **Tính năng nâng cao**: Tự động tăng áp lực hút khi leo lên thảm, Bật/Tắt khóa an toàn trẻ em.
- **Trạm sạc thông minh (OMNI / Turbo / Auto-Empty Station)**:
  - Kích hoạt giặt giẻ lau thủ công hoặc tự động.
  - Bật/tắt sấy khô giẻ lau bằng khí nóng.
  - Kích hoạt gom rác tự động từ hộp bụi robot vào túi rác của trạm sạc.

### 🗺️ Bản Đồ LiDAR & Không Gian Sống
- **Hiển thị bản đồ LiDAR (SVG WebKit)**:
  - Bản đồ vector sắc nét, hỗ trợ thao tác chạm hai ngón phóng to/thu nhỏ (Pinch-to-Zoom) và kéo di chuyển (Pan).
  - Hiển thị vị trí thời gian thực của Robot và Trạm sạc (Dock).
  - Vệt đường đi dọn dẹp (Trajectory Trace) trực quan.
  - Nút **Quét** làm mới bản đồ tức thì: Buộc tải lại DOM bản đồ mới nhất kèm hiệu ứng rung xúc giác và trạng thái xoay loading.
- **Tường ảo & Vùng cấm (Virtual Boundaries)**: Thiết lập và quản lý các đoạn tường ảo hoặc khu vực cấm lau/cấm quét.
- **Sao lưu & Khôi phục bản đồ**: Tạo bản sao lưu trạng thái bản đồ và khôi phục khi robot bị lệch map.

### 📊 Lịch Sử, Tuổi Thọ Phụ Kiện & Đặt Lịch
- **Theo dõi hao mòn linh kiện (Consumables)**: Đọc chính xác % và số giờ hoạt động còn lại của Chổi chính, Chổi ven, Màng lọc HEPA, Giẻ lau sàn; kèm nút reset chu kỳ khi thay mới.
- **Nhật ký dọn dẹp (Cleaning Logs)**: Xem lại danh sách các phiên làm việc, thời gian dọn, diện tích dọn được ($m^2$) và kết quả hoàn thành.
- **Lịch hẹn giờ dọn dẹp (Schedule)**: Lên lịch trình robot tự khởi động dọn dẹp theo các khung giờ và thứ trong tuần.

### 🔔 Hệ Thống Thông Báo iOS (Local Notifications)
- Tích hợp thông báo đẩy nội bộ iOS (Banner + Âm thanh).
- **Cơ chế chống spam thông minh**:
  - Thông báo đúng 1 lần khi robot bắt đầu dọn dẹp, về dock sạc, hoặc dừng hoạt động.
  - Cảnh báo khi pin yếu (< 15%).
  - Cảnh báo các sự cố trạm sạc: Hết nước sạch, bình nước bẩn đã đầy, túi rác trạm sạc đầy.
  - Cảnh báo lỗi phần cứng robot (mắc kẹt, lỗi cảm biến...) đúng 1 lần cho từng mã lỗi phát sinh.

---

### ⚡ Tối ưu phản hồi & Cập nhật Bản đồ Realtime (v1.1.51 - v1.1.53):
- **Tinh chỉnh giao diện Quản lý (v1.1.53)**:
  - Loại bỏ hoàn toàn nhãn "Tức thời" trên thanh tiêu đề Quản lý robot, giúp giao diện tối giản, trực quan và đồng bộ chuẩn ứng dụng native.
- **Hiệu chỉnh chuẩn xác Icon Robot & Trạm Sạc (v1.1.52)**:
  - Khắc phục lỗi đảo vị trí hiển thị: Chấm tròn xanh công nghệ có mũi tên định hướng hiện thị chuẩn xác là **Robot (Deebot)**, biểu tượng pin vàng có tia sét hiển thị chuẩn xác là **Trạm Sạc (Charging Dock)**.
  - Tối ưu hóa đồ họa vector SVG: Tăng cường độ nét, hiệu ứng đổ bóng phát quang và mũi tên hướng di chuyển thời gian thực khi robot quay góc dọn dẹp.
- **Khắc phục triệt để lỗi spam thông báo (v1.1.51)**:
  - Loại bỏ hoàn toàn xung đột trạng thái khiến robot bị nhận diện luân phiên giữa "đang dọn dẹp" và "về trạm sạc".
  - Bổ sung bộ lọc Rate-Limiter 15s cho từng thiết bị và yêu cầu phiên dọn dẹp thực tế tối thiểu trước khi kích hoạt thông báo cập bến trạm sạc.
- **Bản đồ cập nhật tọa độ & đường đi Realtime (2s/lần)**:
  - Khắc phục lỗi đảo ngược trục tung Y giữa hệ tọa độ Cartesian của Robot và hệ tọa độ màn hình SVG (-y / 50.0).
  - Tự động phát lệnh `getPos` trực tiếp qua Socket MQTT siêu tốc mỗi 2 giây khi robot di chuyển dọn dẹp, giúp icon robot lướt mượt mà và vẽ vệt quỹ đạo trực tiếp trên DOM mà không gây chớp giật WebView.
  - Định dạng chuẩn mảng dữ liệu yêu cầu `["chargePos", "deebotPos"]` cho cả cổng MQTT Socket và REST Gateway.

### 🚀 Đang nghiên cứu & cập nhật tiếp theo:
- [x] **Điều khiển trực tiếp 2 chiều qua Socket MQTT & Realtime Map**: Đã hoàn thành trong bản v1.1.51 - v1.1.52.
- [ ] **Giao tiếp mạng nội bộ Local LAN / Wi-Fi**: Tiếp tục khai thác dữ liệu giải mã APK Ecovacs (CoAP, mDNS, Matter/CHIP, UDP) để mở rộng kết nối trực tiếp trong mạng gia đình mà không cần ra Internet.

---

## 📲 4. Hướng Dẫn Cài Đặt (File IPA)

1. Tải bản cài đặt `.ipa` mới nhất tại mục [Releases](https://github.com/vnnit/Robot-noi-dia-ca-nhan/releases).
2. Cài đặt trực tiếp lên iPhone thông qua các công cụ sideload phổ biến:
   - **TrollStore** (Khuyên dùng cho máy có hỗ trợ, không cần gia hạn chứng chỉ 7 ngày)
   - **Scarlet / Esign / GBox**
   - **AltStore / Sideloadly** (Cài đặt qua máy tính cá nhân bằng tài khoản Apple ID miễn phí)

---

## 🛠️ 5. Công Nghệ Sử Dụng

- **Ngôn ngữ**: Swift 5.0
- **Giao diện**: SwiftUI, WebKit (SVG Rendering)
- **Kiến trúc**: MVVM, ObservableObject, Structured Concurrency (`async/await`)
- **Mạng & Giao thức**: URLSession, Network.framework (NWConnection MQTT Client)
- **CI/CD**: GitHub Actions tự động biên dịch và phát hành bản cài đặt IPA

