import SwiftUI

public enum SheetPosition: CGFloat {
    case collapsed = 440
    case medium = 220
    case expanded = 30
}

public struct RobotControlView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: RobotControlViewModel
    
    @State private var sheetOffset: CGFloat = SheetPosition.collapsed.rawValue
    @State private var dragStartOffset: CGFloat = SheetPosition.collapsed.rawValue
    @State private var showRenameAlert: Bool = false
    @State private var newNameText: String = ""
    @State private var showVideoAlert: Bool = false
    @State private var showHousekeeperAlert: Bool = false
    @State private var showScheduleAlert: Bool = false
    @State private var showSequenceAlert: Bool = false
    @State private var showSmartWashAlert: Bool = false
    
    public init(device: DeviceModel) {
        _viewModel = StateObject(wrappedValue: RobotControlViewModel(device: device))
    }
    
    private var batteryColor: Color {
        let b = viewModel.state.batteryPercent
        if b > 50 { return Color(red: 0.0, green: 0.75, blue: 0.45) }
        if b > 20 { return Color.orange }
        return Color.red
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let screenHeight = geometry.size.height
            let screenWidth = geometry.size.width
            
            ZStack(alignment: .top) {
                // 1. Nền bản đồ (Map Layer)
                Color(red: 0.95, green: 0.96, blue: 0.98)
                    .ignoresSafeArea()
                
                // Bản đồ hiển thị ở giữa
                VStack {
                    Spacer().frame(height: 110)
                    
                    ZStack {
                        if viewModel.isMapLoading {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.09, green: 0.47, blue: 1.0)))
                                    .scaleEffect(1.2)
                                Text("Đang tải bản đồ LiDAR...")
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                            }
                        } else if let svg = viewModel.svgMap, !svg.isEmpty {
                            SVGWebView(svgString: svg)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            // Bản đồ mô phỏng căn hộ LiDAR đẹp mắt chuẩn Ecovacs
                            SimulatedLiDARMapView(state: viewModel.state)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(height: screenHeight - 260)
                    
                    Spacer()
                }
                
                // 2. Các nút chức năng nổi trên bản đồ
                // Bên trái: Nút Quản lý Video
                VStack {
                    Spacer().frame(height: 140)
                    
                    Button(action: {
                        showVideoAlert = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "video.fill")
                                .font(.system(size: 14))
                            Text("Quản lý video")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.95))
                        .clipShape(Capsule())
                        .shadow(color: Color.black.opacity(0.1), radius: 6, y: 3)
                    }
                    .padding(.leading, 16)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Bên phải: 3 nút tròn (3D, Bản đồ / Tầng, Định vị)
                VStack(spacing: 12) {
                    Spacer().frame(height: 140)
                    
                    // Nút 3D
                    Button(action: {
                        viewModel.toastMessage = "Chuyển sang hiển thị 3D"
                        viewModel.showToast = true
                    }) {
                        Image(systemName: "cube.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(white: 0.25))
                            .frame(width: 42, height: 42)
                            .background(Color.white.opacity(0.95))
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.1), radius: 6, y: 3)
                    }
                    
                    // Nút Bản đồ tầng / Phân vùng
                    Button(action: {
                        viewModel.toastMessage = "Chỉnh sửa phân vùng bản đồ"
                        viewModel.showToast = true
                    }) {
                        Image(systemName: "square.3.layers.3d.down.right")
                            .font(.system(size: 16))
                            .foregroundColor(Color(white: 0.25))
                            .frame(width: 42, height: 42)
                            .background(Color.white.opacity(0.95))
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.1), radius: 6, y: 3)
                    }
                    
                    // Nút Định vị vị trí robot
                    Button(action: {
                        viewModel.triggerRelocate()
                    }) {
                        Image(systemName: "location.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                            .frame(width: 42, height: 42)
                            .background(Color.white.opacity(0.95))
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.1), radius: 6, y: 3)
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 16)
                
                // 3. Top Navigation Bar & Banner thông báo
                VStack(spacing: 8) {
                    // Top Bar
                    HStack(alignment: .center) {
                        // Nút Back <
                        Button(action: {
                            appState.navigateToPicker()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color(white: 0.15))
                                .padding(8)
                        }
                        
                        Spacer()
                        
                        // Cụm tên Robot & Pin
                        VStack(spacing: 3) {
                            HStack(spacing: 6) {
                                Text(viewModel.device.displayName)
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(Color(white: 0.15))
                                
                                Button(action: {
                                    newNameText = viewModel.device.displayName
                                    showRenameAlert = true
                                }) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 13))
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            HStack(spacing: 6) {
                                HStack(spacing: 3) {
                                    Image(systemName: viewModel.state.isCharging ? "bolt.fill" : "battery.100")
                                        .font(.system(size: 11))
                                        .foregroundColor(batteryColor)
                                    Text("\(viewModel.state.batteryPercent)%")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(Color(white: 0.35))
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.85))
                                .cornerRadius(6)
                            }
                        }
                        
                        Spacer()
                        
                        // Nút Cài đặt (Gear icon) -> Mở Hình 5
                        Button(action: {
                            viewModel.showMoreSettings = true
                        }) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(Color(white: 0.15))
                                .padding(8)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                    
                    // Banner thông báo trạng thái
                    HStack(spacing: 8) {
                        Image(systemName: viewModel.state.isCharging ? "bolt.circle.fill" : "info.circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                        
                        Text(viewModel.state.isCharging ? "Dọn dẹp hoàn tất. Đã quay lại trạm sạc và bắt đầu sạc." : viewModel.state.cleanStateText)
                            .font(.system(size: 12))
                            .foregroundColor(Color(white: 0.2))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Button(action: {
                            showHousekeeperAlert = true
                        }) {
                            HStack(spacing: 2) {
                                Text("Chế độ quản gia")
                                    .font(.system(size: 11, weight: .semibold))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color.white.opacity(0.92))
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.06), radius: 6, y: 2)
                    .padding(.horizontal, 16)
                }
                
                // 4. Bảng điều khiển vuốt dưới lên (Draggable Bottom Sheet)
                VStack(spacing: 0) {
                    // Thanh gạt (Drag indicator)
                    Capsule()
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: 36, height: 4)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                    
                    // Nội dung cuộn được bên trong Bottom Sheet (Hình 2, 3, 4)
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            // HÌNH 2: 3 Tab Chế độ dọn dẹp: [Khu vực] [TỰ ĐỘNG] [Tùy chỉnh]
                            HStack(spacing: 0) {
                                cleanTabItem(title: "Khu vực", tag: "area")
                                cleanTabItem(title: "TỰ ĐỘNG", tag: "auto")
                                cleanTabItem(title: "Tùy chỉnh", tag: "custom")
                            }
                            .padding(.horizontal, 16)
                            
                            // HÌNH 2: 3 Nút tròn lớn [Quản lý bản đồ] [▶️ TỰ ĐỘNG DỌN DẸP] [Trạm sạc]
                            HStack(spacing: 0) {
                                // Nút Quản lý bản đồ
                                Button(action: {
                                    Task { await viewModel.refreshMap() }
                                }) {
                                    VStack(spacing: 6) {
                                        ZStack {
                                            Circle()
                                                .fill(Color(white: 0.95))
                                                .frame(width: 52, height: 52)
                                            Image(systemName: "map")
                                                .font(.system(size: 20))
                                                .foregroundColor(Color(white: 0.25))
                                        }
                                        Text("Quản lý bản đồ")
                                            .font(.system(size: 11))
                                            .foregroundColor(Color(white: 0.35))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                
                                // Nút chính: TỰ ĐỘNG DỌN DẸP (Play / Pause)
                                Button(action: {
                                    let isCleaning = viewModel.state.cleanState == "clean"
                                    viewModel.triggerClean(action: isCleaning ? .pause : .start)
                                }) {
                                    VStack(spacing: 6) {
                                        ZStack {
                                            Circle()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [Color(red: 0.09, green: 0.52, blue: 1.0), Color(red: 0.05, green: 0.38, blue: 0.95)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 66, height: 66)
                                                .shadow(color: Color(red: 0.09, green: 0.47, blue: 1.0).opacity(0.35), radius: 10, y: 5)
                                            
                                            Image(systemName: viewModel.state.cleanState == "clean" ? "pause.fill" : "play.fill")
                                                .font(.system(size: 26))
                                                .foregroundColor(.white)
                                        }
                                        
                                        Text(viewModel.state.cleanState == "clean" ? "TẠM DỪNG" : "TỰ ĐỘNG DỌN DẸP")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(Color(white: 0.15))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                
                                // Nút Trạm sạc
                                Button(action: {
                                    viewModel.triggerCharge()
                                }) {
                                    VStack(spacing: 6) {
                                        ZStack {
                                            Circle()
                                                .fill(Color(white: 0.95))
                                                .frame(width: 52, height: 52)
                                            Image(systemName: "bolt.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(Color(white: 0.25))
                                        }
                                        Text("Trạm sạc")
                                            .font(.system(size: 11))
                                            .foregroundColor(Color(white: 0.35))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .padding(.top, 4)
                            
                            Divider()
                                .background(Color.gray.opacity(0.15))
                                .padding(.horizontal, 16)
                            
                            // HÌNH 3: Cài đặt Dọn dẹp chi tiết (Khi vuốt lên)
                            VStack(alignment: .leading, spacing: 18) {
                                // 1. Tùy chọn dọn dẹp: [Tiêu chuẩn | Tùy chỉnh]
                                HStack {
                                    Text("Tùy chọn dọn dẹp")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color(white: 0.15))
                                    Spacer()
                                    HStack(spacing: 0) {
                                        segmentedChoice(title: "Tiêu chuẩn", isSelected: viewModel.cleaningPreference == "standard") {
                                            viewModel.cleaningPreference = "standard"
                                        }
                                        segmentedChoice(title: "Tùy chỉnh", isSelected: viewModel.cleaningPreference == "customize") {
                                            viewModel.cleaningPreference = "customize"
                                        }
                                    }
                                    .background(Color(white: 0.94))
                                    .cornerRadius(8)
                                }
                                
                                // 2. Số lần dọn: [x1 | x2]
                                HStack {
                                    Text("Số lần dọn")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color(white: 0.15))
                                    Spacer()
                                    HStack(spacing: 8) {
                                        ForEach([1, 2], id: \.self) { t in
                                            choicePill(title: "\(t) lần", isSelected: viewModel.cleanTimes == t) {
                                                viewModel.setCleanTimes(t)
                                            }
                                        }
                                    }
                                }
                                
                                // 3. Lực hút: [Yên tĩnh | Tiêu chuẩn | Mạnh | Siêu mạnh]
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Lực hút")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color(white: 0.15))
                                    
                                    HStack(spacing: 6) {
                                        choicePill(title: "Yên tĩnh", isSelected: viewModel.state.fanSpeed == "quiet") {
                                            viewModel.setFanSpeed(.quiet)
                                        }
                                        choicePill(title: "Tiêu chuẩn", isSelected: viewModel.state.fanSpeed == "standard") {
                                            viewModel.setFanSpeed(.standard)
                                        }
                                        choicePill(title: "Mạnh", isSelected: viewModel.state.fanSpeed == "max") {
                                            viewModel.setFanSpeed(.max)
                                        }
                                        choicePill(title: "Siêu mạnh", isSelected: viewModel.state.fanSpeed == "max+") {
                                            viewModel.setFanSpeed(.maxPlus)
                                        }
                                    }
                                }
                                
                                // 4. Chế độ lau: [Tiêu chuẩn | Lau sâu]
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Chế độ lau")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color(white: 0.15))
                                    
                                    HStack(spacing: 8) {
                                        choicePill(title: "Tiêu chuẩn", isSelected: viewModel.moppingMode == "standard") {
                                            viewModel.setMoppingMode("standard")
                                        }
                                        choicePill(title: "Lau sâu", isSelected: viewModel.moppingMode == "deep") {
                                            viewModel.setMoppingMode("deep")
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            Divider()
                                .background(Color.gray.opacity(0.15))
                                .padding(.horizontal, 16)
                            
                            // HÌNH 4: Cài đặt nâng cao trong Sheet (Khi vuốt lên tối đa)
                            VStack(spacing: 16) {
                                // Làm sạch sâu góc cạnh (Edge Deep Cleaning)
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Làm sạch sâu góc cạnh")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Color(white: 0.15))
                                        Text("Robot vươn giẻ lau sát tường và các góc chân bàn")
                                            .font(.system(size: 11))
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Toggle("", isOn: Binding(
                                        get: { viewModel.edgeDeepCleaning },
                                        set: { _ in viewModel.toggleEdgeDeepCleaning() }
                                    ))
                                    .labelsHidden()
                                }
                                
                                // Trình tự dọn dẹp
                                Button(action: { showSequenceAlert = true }) {
                                    settingsRow(title: "Trình tự dọn dẹp", subtitle: "Thứ tự các phòng khi làm sạch")
                                }
                                
                                // Giặt sấy giẻ lau thông minh
                                Button(action: { showSmartWashAlert = true }) {
                                    settingsRow(title: "Giặt sấy giẻ lau thông minh", subtitle: "Tần suất về giặt giẻ và thời gian sấy")
                                }
                                
                                // Lịch hẹn dọn dẹp
                                Button(action: { showScheduleAlert = true }) {
                                    settingsRow(title: "Lịch hẹn dọn dẹp", subtitle: "Tự động làm sạch theo thời gian đặt sẵn")
                                }
                                
                                // Âm lượng giọng nói
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Âm lượng giọng nói")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Color(white: 0.15))
                                        Spacer()
                                        Text("\(viewModel.state.volume)")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                                    }
                                    
                                    Slider(
                                        value: Binding(
                                            get: { Double(viewModel.state.volume) },
                                            set: { viewModel.setVolume(Int($0)) }
                                        ),
                                        in: 0...10,
                                        step: 1
                                    )
                                    .accentColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                                }
                                
                                // HÌNH 4: Nút to full-width: CÀI ĐẶT NÂNG CAO > (Bấm mở HÌNH 5)
                                Button(action: {
                                    viewModel.showMoreSettings = true
                                }) {
                                    HStack {
                                        Text("Cài đặt nâng cao")
                                            .font(.system(size: 15, weight: .bold))
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 13, weight: .bold))
                                    }
                                    .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(Color(red: 0.92, green: 0.96, blue: 1.0))
                                    .cornerRadius(12)
                                }
                                .padding(.top, 8)
                            }
                            .padding(.horizontal, 20)
                            
                            Spacer().frame(height: 60)
                        }
                    }
                }
                .frame(width: screenWidth, height: screenHeight)
                .background(Color.white)
                .cornerRadius(24, corners: [.topLeft, .topRight])
                .shadow(color: Color.black.opacity(0.12), radius: 12, y: -4)
                .offset(y: sheetOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let newOffset = dragStartOffset + value.translation.height
                            sheetOffset = max(SheetPosition.expanded.rawValue, min(newOffset, SheetPosition.collapsed.rawValue))
                        }
                        .onEnded { value in
                            let mid1 = (SheetPosition.collapsed.rawValue + SheetPosition.medium.rawValue) / 2
                            let mid2 = (SheetPosition.medium.rawValue + SheetPosition.expanded.rawValue) / 2
                            
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                if sheetOffset > mid1 {
                                    sheetOffset = SheetPosition.collapsed.rawValue
                                } else if sheetOffset > mid2 {
                                    sheetOffset = SheetPosition.medium.rawValue
                                } else {
                                    sheetOffset = SheetPosition.expanded.rawValue
                                }
                                dragStartOffset = sheetOffset
                            }
                        }
                )
                
                // Toast thông báo nổi
                if viewModel.showToast, let msg = viewModel.toastMessage {
                    VStack {
                        CustomToastView(message: msg)
                            .padding(.top, 50)
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.25), value: viewModel.showToast)
                }
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .sheet(isPresented: $viewModel.showMoreSettings) {
            SettingsTabView(viewModel: viewModel)
        }
        .alert("Đổi tên Robot", isPresented: $showRenameAlert) {
            TextField("Nhập tên mới", text: $newNameText)
            Button("Lưu") {
                viewModel.renameRobot(newName: newNameText)
            }
            Button("Hủy", role: .cancel) {}
        } message: {
            Text("Đặt tên gợi nhớ cho robot của bạn.")
        }
        .alert("Trình quản lý Video", isPresented: $showVideoAlert) {
            Button("Đóng", role: .cancel) {}
        } message: {
            Text("Tính năng camera trực tiếp AI AIVI và tuần tra an ninh nhà thông minh đang hoạt động trên robot.")
        }
        .alert("Chế độ quản gia", isPresented: $showHousekeeperAlert) {
            Button("Đóng", role: .cancel) {}
        } message: {
            Text("Chế độ quản gia AI tự động tối ưu chu kỳ hút và lau dựa trên dữ liệu dọn dẹp hàng ngày.")
        }
        .alert("Lịch hẹn dọn dẹp", isPresented: $showScheduleAlert) {
            Button("Đóng", role: .cancel) {}
        } message: {
            Text("Lịch hẹn tự động hàng ngày: 09:00 sáng tự động dọn toàn bộ ngôi nhà.")
        }
        .alert("Trình tự dọn dẹp", isPresented: $showSequenceAlert) {
            Button("Đóng", role: .cancel) {}
        } message: {
            Text("Trình tự mặc định: Phòng khách -> Phòng ăn -> Phòng ngủ -> Ban công.")
        }
        .alert("Giặt sấy giẻ lau thông minh", isPresented: $showSmartWashAlert) {
            Button("Đóng", role: .cancel) {}
        } message: {
            Text("Tự động giặt giẻ sau mỗi 15 phút làm việc và sấy khô bằng khí nóng sau khi hoàn thành.")
        }
    }
    
    // MARK: - Subcomponents
    private func cleanTabItem(title: String, tag: String) -> some View {
        let isSelected = viewModel.cleanModeTab == tag
        return Button(action: {
            viewModel.cleanModeTab = tag
        }) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? Color(red: 0.09, green: 0.47, blue: 1.0) : Color(white: 0.4))
                
                Rectangle()
                    .fill(isSelected ? Color(red: 0.09, green: 0.47, blue: 1.0) : Color.clear)
                    .frame(height: 2)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private func choicePill(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? Color(red: 0.09, green: 0.47, blue: 1.0) : Color(white: 0.35))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color(red: 0.90, green: 0.95, blue: 1.0) : Color(white: 0.95))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color(red: 0.09, green: 0.47, blue: 1.0) : Color.clear, lineWidth: 1)
                )
        }
    }
    
    private func segmentedChoice(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? Color(white: 0.1) : Color(white: 0.45))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.white : Color.clear)
                .cornerRadius(6)
                .shadow(color: isSelected ? Color.black.opacity(0.08) : Color.clear, radius: 2, y: 1)
        }
    }
    
    private func settingsRow(title: String, subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(white: 0.15))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.gray)
        }
    }
}

// MARK: - View Bản đồ LiDAR mô phỏng (Hiển thị căn hộ chuẩn Ecovacs)
public struct SimulatedLiDARMapView: View {
    let state: DeviceState
    
    public var body: some View {
        ZStack {
            // Lưới toạ độ LiDAR mờ
            GeometryReader { geo in
                Path { path in
                    let step: CGFloat = 30
                    var x: CGFloat = 0
                    while x < geo.size.width {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geo.size.height))
                        x += step
                    }
                    var y: CGFloat = 0
                    while y < geo.size.height {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                        y += step
                    }
                }
                .stroke(Color.black.opacity(0.025), lineWidth: 1)
            }
            
            // Các phòng căn hộ (Floor Plan)
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    // Phòng Khách
                    RoomBlock(name: "Phòng khách", area: "28.5 m²", color: Color(red: 0.88, green: 0.94, blue: 1.0))
                    // Phòng Bếp
                    RoomBlock(name: "Nhà bếp", area: "12.0 m²", color: Color(red: 0.94, green: 0.92, blue: 0.98))
                }
                .frame(height: 140)
                
                HStack(spacing: 4) {
                    // Phòng Ngủ Master
                    RoomBlock(name: "Phòng ngủ lớn", area: "18.2 m²", color: Color(red: 0.90, green: 0.96, blue: 0.92))
                    // Phòng Làm việc
                    RoomBlock(name: "Phòng làm việc", area: "10.5 m²", color: Color(red: 0.98, green: 0.94, blue: 0.88))
                }
                .frame(height: 120)
            }
            .padding(20)
            
            // Trạm sạc OMNI trên bản đồ
            VStack {
                Spacer().frame(height: 80)
                HStack {
                    Spacer().frame(width: 80)
                    VStack(spacing: 2) {
                        Image(systemName: "bolt.shield.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                        Text("Trạm sạc")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color(white: 0.3))
                    }
                    Spacer()
                }
                Spacer()
            }
            
            // Robot DEEBOT icon trên bản đồ
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.09, green: 0.47, blue: 1.0).opacity(0.2))
                            .frame(width: 38, height: 38)
                        
                        Circle()
                            .fill(Color(red: 0.09, green: 0.47, blue: 1.0))
                            .frame(width: 24, height: 24)
                            .shadow(color: Color(red: 0.09, green: 0.47, blue: 1.0).opacity(0.4), radius: 4, y: 2)
                        
                        Image(systemName: "arrow.up")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Spacer().frame(width: 110)
                }
                Spacer().frame(height: 120)
            }
        }
    }
}

public struct RoomBlock: View {
    let name: String
    let area: String
    let color: Color
    
    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.65))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color, lineWidth: 1.5)
                )
            
            VStack(spacing: 2) {
                Text(name)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(white: 0.25))
                Text(area)
                    .font(.system(size: 10))
                    .foregroundColor(Color(white: 0.45))
            }
        }
    }
}

// Extension bo góc tùy ý cho SwiftUI
extension View {
    public func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

public struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    public func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
