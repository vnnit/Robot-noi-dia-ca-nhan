import SwiftUI

/// Màn hình Thêm Robot Mới vào Ứng Dụng (Cloud Sync, Hướng dẫn Wi-Fi, Thêm thủ công)
public struct AddRobotSheetView: View {
    @ObservedObject var viewModel: RobotPickerViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: Int = 0 // 0: Cloud Sync, 1: Wi-Fi Guide, 2: Manual Add
    
    // Manual Add states
    @State private var selectedPreset: PresetRobotModel = PresetRobotModel.presets.first!
    @State private var didText: String = ""
    @State private var customNameText: String = ""
    
    // Status feedback
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
                    // 1. Segmented Control Switcher
                    Picker("Chế độ thêm", selection: $selectedTab) {
                        Text("Đồng Bộ Cloud").tag(0)
                        Text("Ghép Nối Wi-Fi").tag(1)
                        Text("Thêm Thủ Công").tag(2)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            if selectedTab == 0 {
                                cloudSyncTab
                            } else if selectedTab == 1 {
                                wifiGuideTab
                            } else {
                                manualAddTab
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
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
        .presentationDetents([.fraction(0.85), .large])
    }
    
    // MARK: - Tab 1: Đồng Bộ Cloud
    private var cloudSyncTab: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                }
                .padding(.top, 10)
                
                Text("Đồng Bộ Từ Tài Khoản Ecovacs")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.12))
                
                Text("Nếu bạn vừa kết nối một robot Ecovacs mới trên ứng dụng gốc, chỉ cần bấm nút bên dưới để tự động phát hiện và nạp robot vào app mà không bị khóa vùng.")
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
    
    // MARK: - Tab 2: Hướng Dẫn Ghép Nối Wi-Fi
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
                    desc: "Sau khi robot đã kết nối Wi-Fi qua tài khoản, quay lại bấm nút 'Đồng bộ Cloud' để hoàn tất."
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
    
    // MARK: - Tab 3: Thêm Thủ Công
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
