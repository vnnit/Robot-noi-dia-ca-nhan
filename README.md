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

## ⚠️ 3. Nhược Điểm Hiện Tại & Kế Hoạch Cập Nhật Tiếp Theo

### ⚠️ Nhược điểm hiện tại:
- **Độ trễ khi phát lệnh điều khiển**: Ứng dụng hiện đang gửi các lệnh điều khiển (bắt đầu, dừng, về dock, đổi chế độ...) thông qua giao thức **REST HTTP API (`devmanager.do`)** lên cổng Cloud Gateway của Ecovacs. Do luồng HTTP phải thực hiện bắt tay (handshake) và đi vòng qua máy chủ đám mây rồi mới truyền về robot, nên tốc độ phản hồi có độ trễ nhất định (thường mất từ **1 - 3 giây** tùy tốc độ mạng), **chưa đạt được tốc độ phản hồi tức thời (instant)** như mong muốn.

### 🚀 Đang nghiên cứu & cập nhật thêm:
- [ ] **Điều khiển trực tiếp 2 chiều qua Socket MQTT**: Chuyển đổi toàn bộ việc phát lệnh sang cơ chế Publish trực tiếp qua kênh Socket MQTT (`iot-cn.ecovacs.com`) thay vì gọi qua REST HTTP API để giảm độ trễ về mức mili-giây.
- [ ] **Giao tiếp mạng nội bộ Local LAN / Wi-Fi**: Nghiên cứu bắt gói và điều khiển robot trực tiếp qua mạng Wi-Fi gia đình (Local P2P / XMPP / UDP) khi điện thoại cùng lớp mạng với robot, giúp ra lệnh hoàn toàn tức thời và hoạt động ngay cả khi rớt mạng Internet.

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

