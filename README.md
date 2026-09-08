# Robot Nội Địa (com.robot.noidia) - Ứng Dụng iOS Native

> 🎓 **TUYÊN BỐ DỰ ÁN (DISCLAIMER):**  
> Đây là **dự án cá nhân phục vụ mục đích học tập, nghiên cứu kỹ thuật lập trình iOS (SwiftUI, MVVM) và tìm hiểu giao thức IoT/MQTT**.  
> Dự án hoàn toàn phi thương mại, được phát triển nhằm mục đích tự học và ứng dụng quản lý thiết bị cá nhân trong gia đình. Tất cả bản quyền thương hiệu thuộc về nhà sản xuất Ecovacs Robotics.

---

## ⚡ Ưu Điểm Đột Phá: Kết Nối Trực Tiếp (Zero-Server Architecture)

1. **Không cần Server trung gian:**
   - Ứng dụng chạy trực tiếp trên iPhone, kết nối thẳng tới hệ thống đám mây và máy chủ điều khiển Ecovacs (`gl-cn-api.ecovacs.cn`, `portal-ww.ecouser.net`, `iot-cn.ecovacs.com:8883`).
   - Phản hồi lệnh siêu nhanh (độ trễ chỉ tính bằng mili-giây).
   - Không lo server VPS bị sập, không tốn chi phí thuê hosting hay duy trì backend.

2. **Lưu phiên đăng nhập vĩnh viễn trên thiết bị:**
   - Thông tin tài khoản, token và mật khẩu được mã hóa lưu trữ an toàn trong **Apple Keychain & UserDefaults** của máy.
   - Mở app là vào thẳng danh sách Robot, không bao giờ phải đăng nhập lại.
   - Cơ chế **Silent Re-authentication**: Khi token 7 ngày hết hạn, app tự động gia hạn ngầm trong nền mà không làm gián đoạn trải nghiệm của bạn.
   - **Chỉ thoát khi bấm Đăng xuất:** Dữ liệu phiên chỉ bị xoá khi người dùng chủ động bấm nút *"Đăng xuất"* ở góc trên màn hình.

---

## 📱 Các Màn Hình & Tính Năng Chi Tiết

### 1. Màn hình Đăng nhập (LoginView)
- Đăng nhập bằng số điện thoại hoặc email nội địa Trung Quốc (`+86`).
- Chọn khu vực máy chủ (Mặc định: Trung Quốc - `CN`).
- Tự động mã hóa mật khẩu MD5 và tính toán chữ ký bảo mật `authSign` trực tiếp trên iPhone.

### 2. Màn hình Chọn Robot (RobotPickerView)
- Hiển thị danh sách tất cả các robot trong tài khoản (ví dụ: **DEEBOT T10 TURBO**, **DEEBOT T9 AIVI**...).
- Thẻ trực quan sống động:
  - Tên máy, model phần cứng, phiên bản firmware.
  - Mức pin thực tế (kèm màu sắc cảnh báo Xanh / Cam / Đỏ).
  - Trạng thái sạc pin tại trạm.
  - **Robot đang dọn dẹp:** Viền xanh Cyan phát sáng kèm huy hiệu nhấp nháy `ĐANG DỌN DẸP`.
- Chạm vào thẻ bất kỳ để chuyển thẳng sang màn hình điều khiển của robot đó.
- Nút Đăng xuất ở góc phải trên cùng kèm hộp thoại xác nhận an toàn.

### 3. Màn hình Điều khiển Chi Tiết (RobotControlView)
- Nút **`← Đổi Robot`** ở góc trái trên cùng để quay lại danh sách chọn robot bất cứ lúc nào.
- **Thanh tác vụ nhanh:**
  - **Dọn dẹp:** Nút to nổi bật (Bắt đầu dọn / Tạm dừng / Tiếp tục / Dừng hẳn).
  - **Về sạc:** Ra lệnh robot quay về trạm sạc Dock tự động.
  - **Tìm Robot:** Phát tín hiệu âm thanh định vị khi robot bị kẹt trong gầm giường, góc khuất.
  - **Tái định vị:** Định vị lại tọa độ robot trên sơ đồ nhà.
- **3 Tab chức năng chi tiết:**
  - **Tab Điều khiển & Cài đặt:**
    - Lực hút bụi: 4 mức (Yên tĩnh, Tiêu chuẩn, Mạnh, Siêu mạnh Max+).
    - Mức nước lau sàn: 4 mức độ (1 đến 4).
    - Thanh trượt âm lượng giọng nói (0 đến 10).
    - Khóa an toàn trẻ em (Child Lock).
    - Tự động tăng áp lực hút khi leo lên thảm (Carpet Boost).
    - Cảnh báo mã lỗi chi tiết bằng tiếng Việt nếu robot gặp sự cố.
  - **Tab Phụ kiện (Consumables):**
    - Theo dõi thời gian hoạt động và % tuổi thọ của 4 linh kiện: Chổi chính, Chổi ven, Màng lọc HEPA, Cảm biến chống rơi.
    - Nút **"Reset 100%"** cho từng linh kiện kèm hộp thoại xác nhận khi bạn đã vệ sinh hoặc thay mới.
  - **Tab Bản đồ Laser LiDAR:**
    - Hiển thị sơ đồ quét phòng ốc thực tế từ cảm biến Laser LiDAR của robot dưới dạng SVG vector sắc nét.
    - Hỗ trợ thao tác cảm ứng 2 ngón tay thu phóng (Zoom In / Zoom Out) và di chuyển (Pan).
    - Nút **Quét lại** để làm mới bản đồ tức thời từ robot.

---

## 🛠 Hướng Dẫn Mở & Cài Đặt Lên iPhone

### Cách 1: Chạy trực tiếp qua Xcode (Khuyên dùng)
1. Mở thư mục `RobotNoiDia_iOS/` trên máy Mac.
2. Nhấp đúp chuột vào file `RobotNoiDia.xcodeproj` để mở trong **Xcode**.
3. Kết nối iPhone với máy Mac qua cáp Lightning/Type-C.
4. Trong mục **Signing & Capabilities**, chọn tài khoản Apple ID của bạn (Personal Team miễn phí hoặc Apple Developer).
5. Chọn thiết bị đích là iPhone của bạn và bấm **Run (Cmd + R)**.

### Cách 2: Cài đặt IPA qua Sideloadly / AltStore / TrollStore
1. Trong Xcode, chọn `Product` -> `Archive` -> `Distribute App` -> `Ad Hoc / Development`.
2. Xuất file `RobotNoiDia.ipa`.
3. Mở phần mềm **Sideloadly** hoặc **AltStore** trên máy tính, kéo thả file `.ipa` vào và nhập Apple ID để cài trực tiếp vào iPhone mà không cần qua App Store.

---

## 📂 Cấu Trúc Mã Nguồn

```text
RobotNoiDia/
├── App/
│   ├── RobotNoiDiaApp.swift        # Điểm khởi chạy app (@main)
│   └── AppState.swift              # Quản lý luồng màn hình & phiên vĩnh viễn
├── Core/
│   ├── Constants.swift             # Hằng số API, mã lỗi tiếng Việt & model
│   ├── CryptoHelper.swift          # Thuật toán băm MD5 & authSign (Swift thuần)
│   └── KeychainManager.swift       # Lưu trữ phiên an toàn trên Apple Keychain
├── Models/
│   ├── DeviceModel.swift           # Đối tượng Robot Ecovacs
│   ├── DeviceState.swift           # Trạng thái pin, sạc, dọn dẹp & cài đặt
│   ├── Consumables.swift           # Tuổi thọ phụ kiện & bảo dưỡng
│   └── AuthCredentials.swift       # Thông tin phiên xác thực
├── Services/
│   ├── EcovacsAuthService.swift    # Đăng nhập trực tiếp & Silent auto-refresh
│   ├── EcovacsDeviceService.swift  # Gửi lệnh điều khiển trực tiếp qua REST
│   └── EcovacsMQTTService.swift    # Kết nối TLS MQTT nhận sự kiện tức thì
├── ViewModels/
│   ├── LoginViewModel.swift        # Xử lý form đăng nhập
│   ├── RobotPickerViewModel.swift  # Quản lý danh sách robot & cập nhật thẻ
│   └── RobotControlViewModel.swift # Xử lý các lệnh điều khiển & cài đặt
└── Views/
    ├── Login/LoginView.swift        # Màn hình đăng nhập
    ├── Picker/
    │   ├── RobotPickerView.swift   # Màn hình chọn robot
    │   └── RobotCardView.swift     # Thẻ robot trực quan
    ├── Control/
    │   ├── RobotControlView.swift  # Màn hình điều khiển chính
    │   ├── ControlActionBar.swift  # Bộ nút tác vụ nhanh
    │   ├── SettingsTabView.swift   # Chỉnh lực hút, nước, âm lượng, khóa
    │   ├── ConsumablesTabView.swift# Theo dõi và Reset phụ kiện
    │   └── MapTabView.swift        # Xem bản đồ Laser LiDAR
    └── Components/
        ├── SVGWebView.swift        # Bộ render bản đồ SVG có pinch zoom
        ├── StatusBadgeView.swift   # Huy hiệu trạng thái
        └── CustomToastView.swift   # Thông báo nổi (Toast)
```

---

## 🎓 Mục Đích Học Tập & Nghiên Cứu Kỹ Thuật

Dự án này được tạo ra nhằm mục đích cá nhân để tự học và nghiên cứu các kỹ thuật sau:
1. **SwiftUI & Modern Concurrency:** Áp dụng `async/await`, `Actor`, `@MainActor`, `ObservableObject` trong kiến trúc MVVM sạch.
2. **Lập trình Mạng Cấp Thấp (Low-Level Networking):** Sử dụng `Network.framework` (`NWConnection`) để hiện thực giao thức MQTT 3.1.1 qua TLS Socket trực tiếp trên iOS.
3. **Bảo Mật & Mật Mã:** Tận dụng Apple `CryptoKit` và thuật toán băm RFC 1321 để tạo chữ ký xác thực API (`authSign`), lưu trữ phiên vĩnh viễn với `Security.framework` (Keychain Services).
4. **Tích hợp Tự động hóa CI/CD:** Thiết lập GitHub Actions với máy ảo macOS để tự động hóa quy trình đóng gói và phát hành ứng dụng iOS.

> *Dự án mang tính chất chia sẻ kiến thức, tự học và phục vụ nhu cầu gia đình cá nhân.*

