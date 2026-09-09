import SwiftUI

/// Màn hình Thêm Robot Mới vào Ứng Dụng (Cloud Sync, Quét LAN nội bộ, Hướng dẫn Wi-Fi, Thêm thủ công)
public struct AddRobotSheetView: View {
    @ObservedObject var viewModel: RobotPickerViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: Int = 0 // 0: Cloud Sync, 1: Quét LAN, 2: Ghép Nối Wi-Fi, 3: Thêm Thủ Công
    
    // Manual Add states
    @State private var selectedPreset: PresetRobotModel = PresetRobotModel.presets.first!
    @State private var didText: String = ""
    @State private var customNameText: String = ""
    
    // Status feedback
    @State private var syncStatusMessage: String? = nil
    @State private var isSyncSuccess: Bool = true
    
    // LAN Direct IP test states
    @State private var manualIpText: String = ""
    @State private var isTestingManualIp: Bool = false
    @State private var testIpResultText: String? = nil
    @State private var testIpIsSuccess: Bool = false
    
    public init(viewModel: RobotPickerViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(white: 0.96)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 1. Segmented Control Switcher
                    Picker("Chế độ thêm", selection: $selectedTab) {
                        Text("Cloud").tag(0)
                        Text("Quét LAN").tag(1)
                        Text("Ghép Wi-Fi").tag(2)
                        Text("Thủ Công").tag(3)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 10)
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            if selectedTab == 0 {
                                cloudSyncTab
                            } else if selectedTab == 1 {
                                localLanTab
                            } else if selectedTab == 2 {
                                wifiGuideTab
                            } else {
                                manualAddTab
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Thêm Robot Mới")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        HapticManager.shared.light()
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color.gray.opacity(0.6))
                    }
                }
            }
        }
        .presentationDetents([.fraction(0.88), .large])
    }
    
    // MARK: - Tab 1: Đồng Bộ Cloud
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
                
                Text("Tự động quét tài khoản Ecovacs của bạn để phát hiện robot mới đã được kết nối Wi-Fi, nạp cấu hình và điều khiển ngay lập tức mà không bị hạn chế vùng (Bypass geofencing).")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
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
                    syncStatusMessage = res.message
                    isSyncSuccess = res.success
                    if res.success {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                            dismiss()
                        }
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
    
    // MARK: - Tab 2: Quét Mạng Nội Bộ (Local LAN Discovery)
    private var localLanTab: some View {
        VStack(spacing: 16) {
            // Header card
            VStack(spacing: 12) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color(red: 0.0, green: 0.65, blue: 0.35))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Quét Dải Mạng Wi-Fi Gia Đình")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.12))
                        
                        if let wifiInfo = LocalNetworkScannerService.shared.getLocalWifiIPAddress() {
                            Text("Dải mạng: \(wifiInfo.subnetPrefix).x (IP máy: \(wifiInfo.ip))")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        } else {
                            Text("Đang kết nối Wi-Fi...")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                }
                
                Text("Dò tìm trực tiếp các thiết bị Robot Ecovacs đang mở cổng dịch vụ nội bộ (80, 8080, 8883, 5222) trên mạng Wi-Fi của nhà bạn.")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .lineSpacing(2)
                
                if viewModel.isScanningLAN {
                    VStack(spacing: 6) {
                        ProgressView(value: viewModel.scanProgress, total: 1.0)
                            .progressViewStyle(LinearProgressViewStyle(tint: Color(red: 0.0, green: 0.65, blue: 0.35)))
                        HStack {
                            Text("Đang quét dải IP...")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                            Spacer()
                            Text("\(Int(viewModel.scanProgress * 100))%")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(red: 0.0, green: 0.65, blue: 0.35))
                        }
                    }
                    .padding(.top, 4)
                }
                
                Button(action: {
                    viewModel.startLANScan()
                }) {
                    HStack(spacing: 8) {
                        if viewModel.isScanningLAN {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.85)
                            Text("Đang Quét Mạng...")
                        } else {
                            Image(systemName: "dot.radiowaves.left.and.right")
                            Text("Bắt Đầu Quét Mạng LAN")
                        }
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color(red: 0.0, green: 0.65, blue: 0.35))
                    .cornerRadius(12)
                    .shadow(color: Color.green.opacity(0.25), radius: 5, y: 2)
                }
                .disabled(viewModel.isScanningLAN)
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
            
            // Danh sách thiết bị phát hiện
            if !viewModel.discoveredDevices.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("THIẾT BỊ PHÁT HIỆN TRÊN LAN (\(viewModel.discoveredDevices.count))")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    
                    ForEach(viewModel.discoveredDevices) { dev in
                        discoveredDeviceRow(dev: dev)
                    }
                }
            } else if !viewModel.isScanningLAN && viewModel.scanProgress >= 1.0 {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 28))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("Chưa tìm thấy robot nào có cổng mở trong dải IP này.\nBạn có thể thử nhập IP thủ công bên dưới.")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(Color.white)
                .cornerRadius(14)
            }
            
            // Nhập IP thủ công & Test trực tiếp
            VStack(alignment: .leading, spacing: 12) {
                Text("Kiểm Tra Nhanh Địa Chỉ IP Trực Tiếp")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.12))
                
                HStack {
                    Image(systemName: "network")
                        .foregroundColor(.gray)
                    TextField("Nhập IP Robot (VD: 192.168.1.45)", text: $manualIpText)
                        .font(.system(size: 13))
                        .keyboardType(.numbersAndPunctuation)
                        .autocapitalization(.none)
                    
                    Button(action: {
                        testManualIp()
                    }) {
                        if isTestingManualIp {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Kiểm tra")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                        }
                    }
                    .disabled(manualIpText.trimmingCharacters(in: .whitespaces).isEmpty || isTestingManualIp)
                }
                .padding(12)
                .background(Color(white: 0.95))
                .cornerRadius(10)
                
                if let res = testIpResultText {
                    HStack(spacing: 8) {
                        Image(systemName: testIpIsSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundColor(testIpIsSuccess ? .green : .orange)
                        Text(res)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(testIpIsSuccess ? Color(red: 0.1, green: 0.5, blue: 0.2) : .orange)
                        Spacer()
                        
                        if testIpIsSuccess {
                            Button("Thêm Ngay") {
                                addManualIpRobot()
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .cornerRadius(8)
                        }
                    }
                    .padding(10)
                    .background(testIpIsSuccess ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                    .cornerRadius(10)
                }
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
        }
    }
    
    private func discoveredDeviceRow(dev: DiscoveredLocalDevice) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(dev.isEcovacsLikely ? Color.blue.opacity(0.12) : Color.gray.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: dev.isEcovacsLikely ? "sparkles" : "network")
                    .font(.system(size: 18))
                    .foregroundColor(dev.isEcovacsLikely ? Color.blue : Color.gray)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(dev.modelHint)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.12))
                    
                    if dev.isEcovacsLikely {
                        Text("Ecovacs")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .cornerRadius(4)
                    }
                }
                
                HStack(spacing: 6) {
                    Text("IP: \(dev.ip):\(dev.port)")
                    Text("•")
                    Text("\(dev.latencyMs)ms")
                        .foregroundColor(Color.green)
                }
                .font(.system(size: 11))
                .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button(action: {
                HapticManager.shared.success()
                let preset = PresetRobotModel.presets.first(where: { dev.modelHint.contains($0.name) }) ?? PresetRobotModel.presets.first!
                viewModel.addDiscoveredRobot(discovered: dev, name: dev.modelHint, preset: preset)
                dismiss()
            }) {
                Text("Thêm")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.09, green: 0.47, blue: 1.0))
                    .cornerRadius(8)
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 3, y: 1)
    }
    
    private func testManualIp() {
        let ip = manualIpText.trimmingCharacters(in: .whitespacesAndNewlines)
        isTestingManualIp = true
        testIpResultText = nil
        HapticManager.shared.light()
        
        Task {
            let res = await LocalNetworkScannerService.shared.testSpecificIP(ip: ip)
            isTestingManualIp = false
            testIpIsSuccess = res.isOnline
            if res.isOnline {
                testIpResultText = "Trực tuyến (\(res.latencyMs)ms) - \(res.hint)"
                HapticManager.shared.success()
            } else {
                testIpResultText = "Không có phản hồi từ \(ip). Kiểm tra lại Wi-Fi/IP."
                HapticManager.shared.error()
            }
        }
    }
    
    private func addManualIpRobot() {
        let ip = manualIpText.trimmingCharacters(in: .whitespacesAndNewlines)
        let dev = DiscoveredLocalDevice(ip: ip, port: 80, latencyMs: 5, modelHint: "DEEBOT Robot (LAN)", isEcovacsLikely: true)
        viewModel.addDiscoveredRobot(discovered: dev, name: "DEEBOT (LAN \(ip))", preset: PresetRobotModel.presets.first!)
        dismiss()
    }
    
    // MARK: - Tab 3: Hướng Dẫn Ghép Nối Wi-Fi
    private var wifiGuideTab: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Quy Trình Kết Nối Wi-Fi Cho Robot Nội Địa")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.12))
                
                Text("Thực hiện lần lượt 4 bước sau để đưa robot vào chế độ ghép đôi:")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                
                Divider()
                
                pairingStepRow(
                    step: 1,
                    icon: "power",
                    title: "Bật nguồn Robot",
                    desc: "Mở nắp trên thân robot, tìm công tắc màu đỏ và gạt sang vị trí 'I' (BẬT). Đợi robot phát nhạc khởi động."
                )
                
                pairingStepRow(
                    step: 2,
                    icon: "dot.radiowaves.left.and.right",
                    title: "Nhấn giữ nút Reset Wi-Fi",
                    desc: "Bấm giữ nút Reset nhỏ bên cạnh công tắc nguồn trong 1-2 giây cho đến khi phát tiếng 'Bíp' và đèn Wi-Fi nhấp nháy."
                )
                
                pairingStepRow(
                    step: 3,
                    icon: "wifi",
                    title: "Kết nối Wi-Fi 2.4GHz",
                    desc: "Đảm bảo điện thoại đang kết nối vào mạng Wi-Fi gia đình ở tần số 2.4GHz (robot không hỗ trợ 5GHz)."
                )
                
                pairingStepRow(
                    step: 4,
                    icon: "checkmark.seal.fill",
                    title: "Đồng bộ vào App",
                    desc: "Sau khi robot đã kết nối Wi-Fi qua tài khoản, quay lại bấm nút 'Đồng bộ Cloud' hoặc 'Quét LAN' để hoàn tất."
                )
            }
            .padding(18)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
            
            Button(action: {
                HapticManager.shared.light()
                selectedTab = 0
            }) {
                HStack {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("Chuyển Sang Đồng Bộ Cloud")
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.white)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1.2)
                )
            }
        }
    }
    
    private func pairingStepRow(step: Int, icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.09, green: 0.47, blue: 1.0))
                    .frame(width: 28, height: 28)
                
                Text("\(step)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.12))
                }
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundColor(Color.gray)
                    .lineSpacing(2)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Tab 4: Thêm Thủ Công
    private var manualAddTab: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Chọn Dòng Robot")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.12))
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(PresetRobotModel.presets) { preset in
                            Button(action: {
                                HapticManager.shared.light()
                                selectedPreset = preset
                            }) {
                                VStack(spacing: 6) {
                                    Text(preset.name)
                                        .font(.system(size: 13, weight: selectedPreset.id == preset.id ? .bold : .medium))
                                        .foregroundColor(selectedPreset.id == preset.id ? .white : Color(red: 0.2, green: 0.2, blue: 0.25))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(selectedPreset.id == preset.id ? Color(red: 0.09, green: 0.47, blue: 1.0) : Color(white: 0.94))
                                .cornerRadius(12)
                            }
                        }
                    }
                }
                
                Divider()
                    .padding(.vertical, 4)
                
                // Nhập DID
                Text("Mã Thiết Bị (DID / Serial)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.12))
                
                HStack {
                    Image(systemName: "barcode.viewfinder")
                        .foregroundColor(.gray)
                    TextField("Nhập mã DID (VD: 98a34bc...)", text: $didText)
                        .font(.system(size: 14))
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    if !didText.isEmpty {
                        Button(action: { didText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(12)
                .background(Color(white: 0.95))
                .cornerRadius(10)
                
                // Nhập tên gợi nhớ
                Text("Tên Gợi Nhớ (Tùy chọn)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.12))
                
                HStack {
                    Image(systemName: "pencil")
                        .foregroundColor(.gray)
                    TextField("VD: Robot Tầng 2, Deebot Bếp...", text: $customNameText)
                        .font(.system(size: 14))
                }
                .padding(12)
                .background(Color(white: 0.95))
                .cornerRadius(10)
            }
            .padding(18)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
            
            Button(action: {
                HapticManager.shared.success()
                viewModel.addManualRobot(did: didText, name: customNameText, preset: selectedPreset)
                dismiss()
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Thêm Robot Vào Danh Sách")
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(didText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray.opacity(0.5) : Color(red: 0.09, green: 0.47, blue: 1.0))
                .cornerRadius(14)
                .shadow(color: Color.blue.opacity(0.3), radius: 6, y: 3)
            }
            .disabled(didText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}
