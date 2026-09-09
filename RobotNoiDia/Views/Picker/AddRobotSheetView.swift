import SwiftUI

/// Màn hình Thêm Robot Mới vào Ứng Dụng (Đồng bộ Cloud & Cài đặt Wi-Fi mới trực tiếp)
public struct AddRobotSheetView: View {
    @ObservedObject var viewModel: RobotPickerViewModel
    @StateObject private var provService = EcovacsProvisioningService.shared
    @StateObject private var wifiDetector = WifiDetector.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: Int = 0 // 0: Đồng Bộ Cloud, 1: Kích Hoạt Wi-Fi Mới
    
    // Wi-Fi credentials for Provisioning - Tự động nhớ cả SSID & Mật khẩu
    @AppStorage("saved_provision_ssid") private var wifiSSID: String = ""
    @AppStorage("saved_provision_pwd") private var wifiPassword: String = ""
    @State private var isPasswordVisible: Bool = false
    
    // Cloud Sync feedback
    @State private var syncStatusMessage: String? = nil
    @State private var isSyncSuccess: Bool = true
    
    public init(viewModel: RobotPickerViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(white: 0.96)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 1. Tab Bar chuyển chế độ có độ tương phản cao
                    tabSelector
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            if selectedTab == 0 {
                                cloudSyncTab
                            } else {
                                wifiProvisioningTab
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle(selectedTab == 0 ? "Thêm Robot Mới" : "Cài Đặt Wi-Fi Cho Robot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        HapticManager.shared.light()
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color.gray.opacity(0.7))
                    }
                }
            }
        }
        .preferredColorScheme(.light)
        .presentationDetents([.fraction(0.92), .large])
        .onAppear {
            autoDetectWifi()
        }
        .onChange(of: selectedTab) { newTab in
            if newTab == 1 {
                autoDetectWifi()
            }
        }
    }
    
    private func autoDetectWifi() {
        wifiDetector.scanCurrentWifi { foundSSID in
            if self.wifiSSID.isEmpty {
                self.wifiSSID = foundSSID
            }
        }
    }
    
    // MARK: - Tab Selector Bar
    private var tabSelector: some View {
        HStack(spacing: 0) {
            Button(action: {
                HapticManager.shared.light()
                withAnimation(.easeInOut(duration: 0.15)) { selectedTab = 0 }
            }) {
                Text("Đồng Bộ Cloud")
                    .font(.system(size: 13, weight: selectedTab == 0 ? .bold : .medium))
                    .foregroundColor(selectedTab == 0 ? .white : Color(red: 0.3, green: 0.3, blue: 0.35))
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(selectedTab == 0 ? Color(red: 0.09, green: 0.47, blue: 1.0) : Color.clear)
                    .cornerRadius(10)
            }
            
            Button(action: {
                HapticManager.shared.light()
                withAnimation(.easeInOut(duration: 0.15)) { selectedTab = 1 }
            }) {
                Text("Cài Đặt Wi-Fi Mới")
                    .font(.system(size: 13, weight: selectedTab == 1 ? .bold : .medium))
                    .foregroundColor(selectedTab == 1 ? .white : Color(red: 0.3, green: 0.3, blue: 0.35))
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(selectedTab == 1 ? Color(red: 0.09, green: 0.47, blue: 1.0) : Color.clear)
                    .cornerRadius(10)
            }
        }
        .padding(4)
        .background(Color(white: 0.90))
        .cornerRadius(14)
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }
    
    // MARK: - Tab 1: Đồng Bộ Cloud (Bypass Geofencing)
    private var cloudSyncTab: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 76, height: 76)
                    
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.system(size: 42))
                        .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                }
                .padding(.top, 10)
                
                Text("Đồng Bộ Từ Tài Khoản Ecovacs")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.12))
                
                Text("Tự động quét tài khoản Ecovacs của bạn để phát hiện robot mới đã được nạp Wi-Fi, nạp cấu hình và điều khiển ngay lập tức mà không bị hạn chế vùng (Bypass geofencing nội địa Trung Quốc).")
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.4))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 10)
            }
            .padding(20)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
            
            if let msg = syncStatusMessage {
                HStack(spacing: 10) {
                    Image(systemName: isSyncSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundColor(isSyncSuccess ? .green : .red)
                    Text(msg)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isSyncSuccess ? Color(red: 0.1, green: 0.5, blue: 0.2) : .red)
                    Spacer()
                }
                .padding(14)
                .background(isSyncSuccess ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                .cornerRadius(12)
            }
            
            Button(action: {
                HapticManager.shared.medium()
                Task {
                    let res = await viewModel.syncCloudRobots()
                    if res.success {
                        HapticManager.shared.success()
                        syncStatusMessage = res.message
                        isSyncSuccess = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            dismiss()
                        }
                    } else {
                        HapticManager.shared.error()
                        syncStatusMessage = res.message
                        isSyncSuccess = false
                    }
                }
            }) {
                HStack(spacing: 8) {
                    if viewModel.isSyncingCloud {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                        Text("Đang quét tài khoản...")
                    } else {
                        Image(systemName: "arrow.clockwise")
                        Text("Quét & Đồng Bộ Ngay")
                    }
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color(red: 0.09, green: 0.47, blue: 1.0))
                .cornerRadius(14)
                .shadow(color: Color.blue.opacity(0.3), radius: 6, y: 3)
            }
            .disabled(viewModel.isSyncingCloud)
        }
    }
    
    // MARK: - Tab 2: Cài Đặt Wi-Fi Mới Cho Robot (SoftAP & AliGetSCSync)
    private var wifiProvisioningTab: some View {
        VStack(spacing: 16) {
            // Card 1: Hướng dẫn tổng quan
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "wifi.badge.plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.orange)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kích Hoạt Wi-Fi Trực Tiếp")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.12))
                    Text("Dùng chuẩn ghép đôi SoftAP & AliGetSCSync gốc của Ecovacs")
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.45))
                }
                Spacer()
            }
            .padding(14)
            .background(Color.white)
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(0.03), radius: 4, y: 1)
            
            // Card 2: Nhập thông tin Wi-Fi nhà bạn (Quét tự động & cho phép chỉnh sửa)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("1. Thông tin Wi-Fi nhà bạn (2.4GHz)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.12))
                    
                    Spacer()
                    
                    // Nút quét lại Wi-Fi
                    Button(action: {
                        HapticManager.shared.light()
                        wifiDetector.scanCurrentWifi { foundSSID in
                            self.wifiSSID = foundSSID
                        }
                    }) {
                        HStack(spacing: 4) {
                            if wifiDetector.isDetecting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.09, green: 0.47, blue: 1.0)))
                                    .scaleEffect(0.65)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            Text("Quét Wi-Fi")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
                
                // Cảnh báo nếu iPhone đang nối vào Wi-Fi Robot thay vì Wi-Fi nhà
                if wifiDetector.isRobotAP {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.orange)
                            .padding(.top, 2)
                        
                        Text("iPhone đang nối vào Wi-Fi Robot (\(wifiDetector.currentSSID)). Hãy điền hoặc giữ nguyên tên Wi-Fi nhà bạn bên dưới để Robot kết nối vào.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(red: 0.4, green: 0.25, blue: 0.0))
                            .lineSpacing(2)
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.12))
                    .cornerRadius(8)
                }
                
                VStack(spacing: 10) {
                    // Tên Wi-Fi (SSID) - Tự động điền & Có thể chỉnh sửa tự do
                    HStack(spacing: 10) {
                        Image(systemName: "wifi")
                            .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                            .frame(width: 20)
                        
                        TextField("Tên Wi-Fi nhà (SSID)", text: $wifiSSID)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        if !wifiSSID.isEmpty {
                            Button(action: {
                                wifiSSID = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 15))
                                    .foregroundColor(Color.gray.opacity(0.7))
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(white: 0.96))
                    .cornerRadius(10)
                    
                    // Mật khẩu Wi-Fi - Tự động ghi nhớ vĩnh viễn trên máy
                    HStack(spacing: 10) {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.gray)
                            .frame(width: 20)
                        
                        if isPasswordVisible {
                            TextField("Mật khẩu Wi-Fi (để trống nếu không có)", text: $wifiPassword)
                                .font(.system(size: 14))
                                .foregroundColor(.black)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        } else {
                            SecureField("Mật khẩu Wi-Fi (để trống nếu không có)", text: $wifiPassword)
                                .font(.system(size: 14))
                                .foregroundColor(.black)
                        }
                        
                        Button(action: {
                            isPasswordVisible.toggle()
                        }) {
                            Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(Color.gray.opacity(0.8))
                        }
                    }
                    .padding(12)
                    .background(Color(white: 0.96))
                    .cornerRadius(10)
                }
                
                Text("Lưu ý: Robot Ecovacs chỉ hỗ trợ sóng 2.4GHz. Bạn có thể sửa trực tiếp tên Wi-Fi ở trên nếu muốn dùng mạng khác.")
                    .font(.system(size: 11))
                    .foregroundColor(Color.gray)
                    .lineSpacing(2)
            }
            .padding(14)
            .background(Color.white)
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(0.03), radius: 4, y: 1)
            
            // Card 3: Hướng dẫn kết nối Wi-Fi Robot
            VStack(alignment: .leading, spacing: 12) {
                Text("2. Đưa Robot vào chế độ ghép đôi")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.12))
                
                VStack(alignment: .leading, spacing: 8) {
                    guideStepRow(
                        num: "a",
                        text: "Bật công tắc nguồn màu đỏ (I) bên dưới nắp lưng robot."
                    )
                    guideStepRow(
                        num: "b",
                        text: "Bấm giữ nút Reset Wi-Fi 1 giây cho đến khi robot phát tiếng bíp và đèn Wi-Fi nhấp nháy."
                    )
                    guideStepRow(
                        num: "c",
                        text: "Vào Cài đặt Wi-Fi iPhone, kết nối vào mạng có tên bắt đầu bằng ECOVACS_xxxx."
                    )
                }
                
                Button(action: {
                    HapticManager.shared.light()
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "gear")
                        Text("Mở Cài Đặt Wi-Fi iPhone")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(8)
                }
                .padding(.top, 4)
            }
            .padding(14)
            .background(Color.white)
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(0.03), radius: 4, y: 1)
            
            // Card 4: Tiến trình thực thi
            if provService.isBusy || provService.step != .idle {
                provisioningStatusCard
            }
            
            // Card 5: Nút bấm nạp Wi-Fi
            Button(action: {
                HapticManager.shared.medium()
                Task {
                    await provService.executeFullProvisioningFlow(ssid: wifiSSID, password: wifiPassword)
                    if case .success = provService.step {
                        HapticManager.shared.success()
                        _ = await viewModel.syncCloudRobots()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            dismiss()
                        }
                    } else if case .failed = provService.step {
                        HapticManager.shared.error()
                    }
                }
            }) {
                HStack(spacing: 8) {
                    if provService.isBusy {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                        Text("Đang xử lý nạp Wi-Fi...")
                    } else {
                        Image(systemName: "bolt.horizontal.circle.fill")
                            .font(.system(size: 18))
                        Text("Nạp Wi-Fi & Kích Hoạt Robot")
                    }
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(provService.isBusy ? Color.gray : Color(red: 0.0, green: 0.65, blue: 0.35))
                .cornerRadius(14)
                .shadow(color: Color.green.opacity(0.3), radius: 6, y: 3)
            }
            .disabled(provService.isBusy || wifiSSID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
    
    // MARK: - Trạng thái tiến trình nạp Wi-Fi
    private var provisioningStatusCard: some View {
        VStack(spacing: 12) {
            switch provService.step {
            case .idle:
                EmptyView()
            case .sendingToRobot(let msg), .waitingRobotOnline(let msg), .obtainingToken(let msg), .bindingDevice(let msg):
                HStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    Text(msg)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.12))
                    Spacer()
                }
                .padding(14)
                .background(Color.blue.opacity(0.08))
                .cornerRadius(12)
                
            case .success(let name):
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Kích Hoạt Thành Công!")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(Color(red: 0.1, green: 0.5, blue: 0.2))
                            Text("Đã gán '\(name)' vào tài khoản và sẵn sàng điều khiển.")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                }
                .padding(14)
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
                
            case .failed(let err):
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.red)
                        Text(err)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.red)
                        Spacer()
                    }
                    
                    Button(action: {
                        provService.reset()
                    }) {
                        Text("Thử Lại")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color.red)
                            .cornerRadius(6)
                    }
                }
                .padding(14)
                .background(Color.red.opacity(0.08))
                .cornerRadius(12)
            }
        }
    }
    
    private func guideStepRow(num: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(num)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 18, height: 18)
                .background(Color.gray.opacity(0.7))
                .clipShape(Circle())
                .padding(.top, 1)
            
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.28))
                .lineSpacing(2)
            
            Spacer()
        }
    }
}
