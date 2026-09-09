import SwiftUI

/// Màn hình Danh sách Robot dạng Slider ngang (Hình 1 - Chuẩn Ecovacs Home App)
public struct RobotPickerView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = RobotPickerViewModel()
    
    @State private var selectedIndex: Int = 0
    @State private var showLogoutAlert: Bool = false
    @State private var showRenameAlert: Bool = false
    @State private var renameText: String = ""
    @State private var toastMessage: String? = nil
    @State private var showToast: Bool = false
    
    public init() {}
    
    private var currentRobot: DeviceModel? {
        guard !viewModel.devices.isEmpty, selectedIndex < viewModel.devices.count else { return nil }
        return viewModel.devices[selectedIndex]
    }
    
    public var body: some View {
        ZStack {
            // Nền sáng thanh lịch chuẩn Ecovacs Home App (Hình 1)
            LinearGradient(
                colors: [Color(white: 0.98), Color(white: 0.93)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. Top Header Bar: "Nhà của tôi >" & Nút thông báo
                HStack(alignment: .center) {
                    HStack(spacing: 4) {
                        Text("Nhà của tôi")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.black)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // Nút Thêm Robot Mới (+)
                    Button(action: {
                        HapticManager.shared.light()
                        viewModel.showAddRobotSheet = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .bold))
                            Text("Thêm Robot")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(14)
                    }
                    .padding(.trailing, 10)
                    
                    // Chuông thông báo có chấm đỏ
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell")
                            .font(.system(size: 20))
                            .foregroundColor(.black)
                        
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: -2)
                    }
                    .padding(.trailing, 14)
                    
                    // Nút làm mới danh sách thiết bị
                    Button(action: {
                        viewModel.loadDevices(showLoading: true, forceRefreshAuth: true)
                        showToastNotify("Đang làm mới danh sách...")
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.black)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                
                if viewModel.isLoading && viewModel.devices.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.09, green: 0.47, blue: 1.0)))
                            .scaleEffect(1.3)
                        Text("Đang nạp robot...")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else if viewModel.devices.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        
                        Text(viewModel.errorMessage ?? "Chưa tìm thấy robot nào trong tài khoản.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        
                        VStack(spacing: 12) {
                            Button(action: {
                                HapticManager.shared.light()
                                viewModel.showAddRobotSheet = true
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Thêm Robot Mới")
                                }
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color(red: 0.09, green: 0.47, blue: 1.0))
                                .cornerRadius(10)
                                .shadow(color: Color.blue.opacity(0.3), radius: 6, y: 3)
                            }
                            
                            HStack(spacing: 16) {
                                Button(action: {
                                    viewModel.loadDevices(showLoading: true, forceRefreshAuth: true)
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.clockwise")
                                        Text("Thử lại")
                                    }
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color(white: 0.25))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color(white: 0.92))
                                    .cornerRadius(8)
                                }
                                
                                Button(action: { showLogoutAlert = true }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "rectangle.portrait.and.arrow.right")
                                        Text("Đăng nhập lại")
                                    }
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color(white: 0.25))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color(white: 0.92))
                                    .cornerRadius(8)
                                }
                            }
                        }

                    }
                    Spacer()
                } else {
                    // 2. Tên Robot & Trạng thái Trực tuyến
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(currentRobot?.displayName ?? "DEEBOT")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(.black)
                                    .lineLimit(1)
                                
                                Button(action: {
                                    if let r = currentRobot {
                                        renameText = r.displayName
                                        showRenameAlert = true
                                    }
                                }) {
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.system(size: 17))
                                        .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                                }
                            }
                            
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color(red: 0.0, green: 0.75, blue: 0.45))
                                    .frame(width: 7, height: 7)
                                Text("Trực tuyến")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color(red: 0.0, green: 0.75, blue: 0.45))
                                
                                if let b = currentRobot?.battery {
                                    Text("• Pin: \(b)%")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                                
                                if let ip = currentRobot?.localIp {
                                    Text("• LAN: \(ip)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(Color(red: 0.0, green: 0.65, blue: 0.35))
                                }
                            }

                        }
                        
                        Spacer()
                        
                        // Nút trợ lý YIKO tròn xanh nhạt
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.88, green: 0.94, blue: 1.0))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "sparkles")
                                .font(.system(size: 20))
                                .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    
                    // 3. Carousel Paging Robot Slider (Vuốt ngang trái/phải xem các robot)
                    TabView(selection: $selectedIndex) {
                        ForEach(0..<viewModel.devices.count, id: \.self) { index in
                            let dev = viewModel.devices[index]
                            Button(action: {
                                appState.navigateToControl(device: dev)
                            }) {
                                VStack(spacing: 0) {
                                    RobotHeroImageView(device: dev)
                                        .padding(.top, 10)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: 310)
                    
                    // 4. Ba Nút Tác Vụ Nhanh (Hình vuông bo góc nền trắng)
                    HStack(spacing: 24) {
                        // Nút 1: Trình quản lý Video
                        Button(action: {
                            showToastNotify("Camera AI & Video Manager đang kích hoạt")
                        }) {
                            VStack(spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(Color.white)
                                        .frame(width: 68, height: 68)
                                        .shadow(color: Color.black.opacity(0.06), radius: 8, y: 4)
                                    
                                    Image(systemName: "video.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(Color(white: 0.25))
                                }
                                
                                Text("Quản lý Video")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Color(white: 0.45))
                            }
                        }
                        
                        // Nút 2: Bắt đầu / Tạm dừng (Start Play)
                        Button(action: {
                            guard let dev = currentRobot else { return }
                            Task {
                                let action: CleanAction = dev.isCleaning ? .pause : .start
                                do {
                                    try await EcovacsDeviceService.shared.clean(device: dev, action: action)
                                    showToastNotify(dev.isCleaning ? "Đã tạm dừng dọn dẹp" : "Robot bắt đầu dọn dẹp tự động")
                                    viewModel.loadDevices(showLoading: false)
                                } catch {
                                    showToastNotify("Lỗi: " + error.localizedDescription)
                                }
                            }
                        }) {
                            VStack(spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(Color.white)
                                        .frame(width: 68, height: 68)
                                        .shadow(color: Color.black.opacity(0.06), radius: 8, y: 4)
                                    
                                    Image(systemName: (currentRobot?.isCleaning ?? false) ? "pause.fill" : "play.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                                }
                                
                                Text((currentRobot?.isCleaning ?? false) ? "Tạm dừng" : "Bắt đầu")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Color(white: 0.45))
                            }
                        }
                        
                        // Nút 3: Về Dock (Docking)
                        Button(action: {
                            guard let dev = currentRobot else { return }
                            Task {
                                do {
                                    try await EcovacsDeviceService.shared.charge(device: dev)
                                    showToastNotify("Robot đang quay về trạm sạc")
                                    viewModel.loadDevices(showLoading: false)
                                } catch {
                                    showToastNotify("Lỗi: " + error.localizedDescription)
                                }
                            }
                        }) {
                            VStack(spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(Color.white)
                                        .frame(width: 68, height: 68)
                                        .shadow(color: Color.black.opacity(0.06), radius: 8, y: 4)
                                    
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(Color(white: 0.25))
                                }
                                
                                Text("Về Dock")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Color(white: 0.45))
                            }
                        }
                    }
                    .padding(.top, 10)
                    
                    Spacer()
                    
                    // 5. Page Indicators & Nút "Vào điều khiển >" (Enter)
                    HStack {
                        // Chấm phân trang
                        HStack(spacing: 6) {
                            ForEach(0..<viewModel.devices.count, id: \.self) { idx in
                                Capsule()
                                    .fill(selectedIndex == idx ? Color(white: 0.25) : Color.gray.opacity(0.35))
                                    .frame(width: selectedIndex == idx ? 18 : 6, height: 6)
                                    .animation(.easeInOut(duration: 0.25), value: selectedIndex)
                            }
                        }
                        
                        Spacer()
                        
                        // Nút Vào điều khiển > (Enter >)
                        Button(action: {
                            if let dev = currentRobot {
                                appState.navigateToControl(device: dev)
                            }
                        }) {
                            VStack(alignment: .trailing, spacing: 4) {
                                HStack(spacing: 4) {
                                    Text("Vào điều khiển")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(Color(white: 0.15))
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(Color(white: 0.15))
                                }
                                
                                Rectangle()
                                    .fill(Color(white: 0.15))
                                    .frame(width: 105, height: 2)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
                }
                
                // 6. Bottom Tab Navigation Bar
                Divider()
                    .background(Color.gray.opacity(0.2))
                
                HStack {
                    // Tab 1: Robot (Active)
                    VStack(spacing: 4) {
                        Image(systemName: "fanblades.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                        Text("Robot")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Tab 2: Đổi tên Robot
                    Button(action: {
                        if let r = currentRobot {
                            renameText = r.displayName
                            showRenameAlert = true
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "pencil")
                                .font(.system(size: 19))
                                .foregroundColor(.gray)
                            Text("Đổi tên")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Tab 3: Đăng xuất
                    Button(action: {
                        showLogoutAlert = true
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 18))
                                .foregroundColor(.gray)
                            Text("Đăng xuất")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 8)
                .background(Color.white)
            }
            
            // Toast thông báo nổi
            if showToast, let msg = toastMessage {
                VStack {
                    CustomToastView(message: msg)
                        .padding(.top, 50)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.25), value: showToast)
            }
        }
        .onAppear {
            viewModel.loadDevices()
        }
        .onDisappear {
            viewModel.stopAutoPolling()
        }
        .alert("Đổi tên Robot", isPresented: $showRenameAlert) {
            TextField("Nhập tên mới", text: $renameText)
            Button("Lưu") {
                if let r = currentRobot {
                    viewModel.renameRobot(did: r.did, newName: renameText)
                    showToastNotify("Đã đổi tên robot thành: " + renameText)
                }
            }
            Button("Hủy", role: .cancel) {}
        } message: {
            Text("Đặt tên gợi nhớ cho robot (VD: Robot Tầng 1, Deebot Phòng Khách).")
        }
        .alert(isPresented: $showLogoutAlert) {
            Alert(
                title: Text("Đăng xuất tài khoản?"),
                message: Text("Thông tin đăng nhập đã lưu sẽ bị xoá. Bạn sẽ phải nhập lại tài khoản khi mở lại app."),
                primaryButton: .destructive(Text("Đăng xuất")) {
                    appState.logout()
                },
                secondaryButton: .cancel(Text("Hủy"))
            )
        }
        .sheet(isPresented: $viewModel.showAddRobotSheet) {
            AddRobotSheetView(viewModel: viewModel)
        }
    }

    
    private func showToastNotify(_ msg: String) {
        toastMessage = msg
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            showToast = false
        }
    }
}
