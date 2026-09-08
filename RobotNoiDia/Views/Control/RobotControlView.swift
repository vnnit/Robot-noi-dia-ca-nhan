import SwiftUI

public struct RobotControlView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: RobotControlViewModel
    
    // Bottom Sheet offset (tính toán động theo kích thước màn hình)
    @State private var sheetDragTranslation: CGFloat = 0
    @State private var isSheetExpanded: Bool = false
    
    @State private var showRenameAlert: Bool = false
    @State private var newNameText: String = ""
    @State private var showVideoAlert: Bool = false
    @State private var showHousekeeperAlert: Bool = false
    @State private var showScheduleAlert: Bool = false
    @State private var showSequenceAlert: Bool = false
    @State private var showSmartWashAlert: Bool = false
    @State private var showBanner: Bool = true
    
    public init(device: DeviceModel) {
        _viewModel = StateObject(wrappedValue: RobotControlViewModel(device: device))
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let screenHeight = geometry.size.height
            let screenWidth = geometry.size.width
            
            // Chiều cao Bottom Sheet khi thu gọn: 230pt (chừa ~75% màn hình cho Bản đồ)
            let collapsedHeight: CGFloat = 230
            // Chiều cao Bottom Sheet khi mở tối đa
            let expandedHeight: CGFloat = screenHeight - 90
            
            let currentSheetHeight = isSheetExpanded ? expandedHeight : collapsedHeight
            let effectiveHeight = max(collapsedHeight, min(expandedHeight, currentSheetHeight - sheetDragTranslation))
            let sheetOffsetY = screenHeight - effectiveHeight
            
            ZStack(alignment: .top) {
                // 1. NỀN BẢN ĐỒ (Chiếm toàn bộ không gian phía sau)
                Color(red: 0.94, green: 0.96, blue: 0.98)
                    .ignoresSafeArea()
                
                // Bản đồ chính
                VStack(spacing: 0) {
                    Spacer().frame(height: 90)
                    
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
                            // Bản đồ chi tiết kèm đường dọn dẹp chân thực chuẩn Ecovacs
                            RealisticEcovacsMapView(device: viewModel.device, state: viewModel.state)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(height: screenHeight - 240)
                    
                    Spacer()
                }
                
                // 2. CÁC NÚT NỔI TRÊN BẢN ĐỒ (FLOATING OVERLAY)
                // Phía trên bên trái: Chip "Bản đồ hiện tại: Bản đồ 1" & Tên lửa Yiko
                VStack(alignment: .leading, spacing: 10) {
                    Spacer().frame(height: 105)
                    
                    HStack(spacing: 4) {
                        Text("Bản đồ hiện tại: Bản đồ 1")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(white: 0.3))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.85))
                    .cornerRadius(8)
                    
                    if viewModel.device.hasYiko {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.88, green: 0.94, blue: 1.0))
                                .frame(width: 38, height: 38)
                                .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
                            
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                        }
                    }
                    
                    Spacer()
                }
                .padding(.leading, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Phía trên bên phải: Các nút điều khiển bản đồ nổi (Camera, 3D, Layer)
                VStack(spacing: 12) {
                    Spacer().frame(height: 105)
                    
                    // Nút Camera (Chỉ hiện khi robot có hỗ trợ AI Video Manager như T10/X1/AIVI)
                    if viewModel.device.hasCamera {
                        Button(action: { showVideoAlert = true }) {
                            Image(systemName: "video")
                                .font(.system(size: 16))
                                .foregroundColor(Color(white: 0.25))
                                .frame(width: 42, height: 42)
                                .background(Color.white.opacity(0.95))
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.08), radius: 5, y: 2)
                        }
                    }
                    
                    // Nút 3D (Chỉ hiện khi robot hỗ trợ bản đồ 3D)
                    if viewModel.device.has3DMap {
                        Button(action: {
                            viewModel.toastMessage = "Chế độ xem 3D"
                            viewModel.showToast = true
                        }) {
                            Text("3D")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color(white: 0.25))
                                .frame(width: 42, height: 42)
                                .background(Color.white.opacity(0.95))
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.08), radius: 5, y: 2)
                        }
                    }
                    
                    // Nút Lớp bản đồ / Quản lý tầng
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
                            .shadow(color: Color.black.opacity(0.08), radius: 5, y: 2)
                    }
                    
                    Spacer()
                }
                .padding(.trailing, 16)
                .frame(maxWidth: .infinity, alignment: .trailing)
                
                // 3. TOP NAVIGATION BAR
                HStack(alignment: .center) {
                    // Nút Back <
                    Button(action: {
                        appState.navigateToPicker()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundColor(Color(white: 0.15))
                            .padding(8)
                    }
                    
                    Spacer()
                    
                    // Tên Robot & Pin / Chế độ làm việc
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
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Color(red: 0.0, green: 0.75, blue: 0.45))
                            Text("\(viewModel.state.batteryPercent)%")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color(white: 0.35))
                            Text("|")
                                .font(.system(size: 10))
                                .foregroundColor(Color.gray.opacity(0.5))
                            Text("Hút & Lau")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(white: 0.35))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.85))
                        .cornerRadius(6)
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
                
                // 4. FLOATING BANNER TRÊN ĐỈNH BOTTOM SHEET (Dọn dẹp hoàn tất & Quản gia)
                if !isSheetExpanded {
                    VStack(spacing: 8) {
                        Spacer()
                        
                        if showBanner {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(red: 0.0, green: 0.75, blue: 0.45))
                                
                                Text("Dọn dẹp hoàn tất. Nhấn để xem Nhật ký.")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(white: 0.2))
                                
                                Spacer()
                                
                                Button(action: {
                                    withAnimation { showBanner = false }
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(Color.white.opacity(0.95))
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.08), radius: 6, y: 2)
                            .padding(.horizontal, 16)
                        }
                        
                        // Cụm Nút Yiko & Chế độ Quản gia
                        HStack(spacing: 10) {
                            if viewModel.device.hasYiko {
                                ZStack {
                                    Circle()
                                        .fill(Color(red: 0.09, green: 0.47, blue: 1.0))
                                        .frame(width: 36, height: 36)
                                    
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                }
                            }
                            
                            Button(action: { showHousekeeperAlert = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 10))
                                    Text("Chế độ quản gia")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.95))
                                .clipShape(Capsule())
                                .shadow(color: Color.black.opacity(0.08), radius: 6, y: 2)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, collapsedHeight + 8)
                    }
                    .transition(.opacity)
                }
                
                // 5. DRAGGABLE BOTTOM SHEET (Vuốt dưới lên để xem toàn bộ tùy chọn)
                VStack(spacing: 0) {
                    // Thanh gạt (Drag indicator) & Vùng chạm kéo
                    VStack(spacing: 6) {
                        Capsule()
                            .fill(Color.gray.opacity(0.35))
                            .frame(width: 36, height: 4)
                            .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isSheetExpanded.toggle()
                        }
                    }
                    
                    // Nội dung Bottom Sheet
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            // HÌNH 2: 3 Tab Chế độ dọn dẹp: [Khu vực] [TỰ ĐỘNG] [Tùy chỉnh]
                            HStack(spacing: 0) {
                                cleanTabItem(title: "Khu vực", tag: "area")
                                cleanTabItem(title: "TỰ ĐỘNG", tag: "auto")
                                cleanTabItem(title: "Tùy chỉnh", tag: "custom")
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                            
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
                                                .frame(width: 50, height: 50)
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
                                                .frame(width: 50, height: 50)
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
                            
                            // Gợi ý vuốt lên (Peek title "Tùy chọn dọn dẹp")
                            Divider()
                                .background(Color.gray.opacity(0.15))
                                .padding(.horizontal, 16)
                            
                            // HÌNH 3: CÀI ĐẶT DỌN DẸP CHI TIẾT
                            VStack(alignment: .leading, spacing: 18) {
                                // 1. Tùy chọn dọn dẹp: [Tiêu chuẩn | Tùy chỉnh]
                                HStack {
                                    Text("Tùy chọn dọn dẹp")
                                        .font(.system(size: 15, weight: .bold))
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
                                
                                // 2. Số lần dọn: [1 lần | 2 lần]
                                HStack {
                                    Text("Số lần dọn")
                                        .font(.system(size: 14, weight: .semibold))
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
                                
                                // 3. Lực hút bụi: 4 mức
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Lực hút")
                                        .font(.system(size: 14, weight: .semibold))
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
                                        .font(.system(size: 14, weight: .semibold))
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
                            
                            // HÌNH 4: CÀI ĐẶT NÂNG CAO THEO TÍNH NĂNG TỪNG ROBOT
                            VStack(spacing: 16) {
                                // Làm sạch sâu góc cạnh (Chỉ hiện nếu robot hỗ trợ)
                                if viewModel.device.hasEdgeDeepCleaning {
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
                                }
                                
                                // Trình tự dọn dẹp
                                Button(action: { showSequenceAlert = true }) {
                                    settingsRow(title: "Trình tự dọn dẹp", subtitle: "Thứ tự các phòng khi làm sạch")
                                }
                                
                                // Giặt sấy giẻ lau thông minh (Chỉ hiện nếu robot có trạm OMNI/TURBO)
                                if viewModel.device.hasOmniStation {
                                    Button(action: { showSmartWashAlert = true }) {
                                        settingsRow(title: "Giặt sấy giẻ lau thông minh", subtitle: "Tần suất về giặt giẻ và thời gian sấy")
                                    }
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
                                
                                // HÌNH 4: Nút Cài đặt nâng cao > (Bấm mở HÌNH 5)
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
                .frame(width: screenWidth, height: expandedHeight)
                .background(Color.white)
                .cornerRadius(24, corners: [.topLeft, .topRight])
                .shadow(color: Color.black.opacity(0.12), radius: 12, y: -4)
                .offset(y: sheetOffsetY)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            sheetDragTranslation = -value.translation.height
                        }
                        .onEnded { value in
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                if value.translation.height < -60 {
                                    isSheetExpanded = true
                                } else if value.translation.height > 60 {
                                    isSheetExpanded = false
                                }
                                sheetDragTranslation = 0
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

// MARK: - View Bản đồ Chân thực theo đúng mẫu Ecovacs T10 TURBO (Hình người dùng chụp)
public struct RealisticEcovacsMapView: View {
    let device: DeviceModel
    let state: DeviceState
    
    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            ZStack {
                // Toàn bộ nền bản đồ
                Color(red: 0.94, green: 0.96, blue: 0.98)
                
                // 1. Phân vùng các phòng (Rooms Floorplan)
                // Phòng 1 (Room 1): Màu hồng cam nhạt chuẩn Ecovacs
                Path { path in
                    path.move(to: CGPoint(x: w * 0.55, y: h * 0.18))
                    path.addLine(to: CGPoint(x: w * 0.88, y: h * 0.18))
                    path.addLine(to: CGPoint(x: w * 0.88, y: h * 0.58))
                    path.addLine(to: CGPoint(x: w * 0.72, y: h * 0.58))
                    path.addLine(to: CGPoint(x: w * 0.55, y: h * 0.45))
                    path.closeSubpath()
                }
                .fill(Color(red: 1.0, green: 0.68, blue: 0.75).opacity(0.7))
                
                // Phòng 2 (Room 2): Màu xanh ngọc (Mint) chuẩn Ecovacs
                Path { path in
                    path.move(to: CGPoint(x: w * 0.12, y: h * 0.22))
                    path.addLine(to: CGPoint(x: w * 0.55, y: h * 0.22))
                    path.addLine(to: CGPoint(x: w * 0.55, y: h * 0.62))
                    path.addLine(to: CGPoint(x: w * 0.22, y: h * 0.62))
                    path.addLine(to: CGPoint(x: w * 0.12, y: h * 0.55))
                    path.closeSubpath()
                }
                .fill(Color(red: 0.35, green: 0.86, blue: 0.72).opacity(0.7))
                
                // Khung viền bản đồ căn hộ
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(red: 0.72, green: 0.80, blue: 0.92), lineWidth: 2)
                    .frame(width: w * 0.84, height: h * 0.52)
                    .position(x: w * 0.5, y: h * 0.4)
                
                // 2. Vệt đường dọn dẹp màu trắng hình zíc-zắc (Cleaning Path / Trajectory)
                Path { path in
                    let startY = h * 0.20
                    let endY = h * 0.50
                    let startX = w * 0.15
                    let endX = w * 0.84
                    let stepY: CGFloat = 11
                    
                    var currentY = startY
                    var goRight = true
                    
                    path.move(to: CGPoint(x: startX, y: currentY))
                    while currentY < endY {
                        let nextX = goRight ? endX : startX
                        path.addLine(to: CGPoint(x: nextX, y: currentY))
                        currentY += stepY
                        path.addLine(to: CGPoint(x: nextX, y: currentY))
                        goRight.toggle()
                    }
                }
                .stroke(Color.white.opacity(0.9), lineWidth: 1.5)
                
                // Nhãn phòng Room1 & Room2
                VStack(spacing: 2) {
                    Image(systemName: "door.left.hand.closed")
                        .font(.system(size: 11))
                        .foregroundColor(Color(white: 0.35))
                    Text("Phòng 1")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(white: 0.35))
                }
                .position(x: w * 0.75, y: h * 0.48)
                
                VStack(spacing: 2) {
                    Image(systemName: "door.left.hand.closed")
                        .font(.system(size: 11))
                        .foregroundColor(Color(white: 0.35))
                    Text("Phòng 2")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(white: 0.35))
                }
                .position(x: w * 0.38, y: h * 0.54)
                
                // 3. Vị trí Trạm sạc (Charging Station Dock Pin)
                HStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.0, green: 0.78, blue: 0.46))
                            .frame(width: 22, height: 22)
                            .shadow(color: Color.black.opacity(0.15), radius: 3, y: 1)
                        
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                    }
                }
                .position(x: w * 0.86, y: h * 0.38)
                
                // 4. Vị trí Robot DEEBOT trên bản đồ
                ZStack {
                    Circle()
                        .fill(Color(white: 0.15))
                        .frame(width: 22, height: 22)
                        .shadow(color: Color.black.opacity(0.2), radius: 4, y: 2)
                    
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    
                    Circle()
                        .fill(Color(red: 0.09, green: 0.47, blue: 1.0))
                        .frame(width: 8, height: 8)
                }
                .position(x: w * 0.86, y: h * 0.43)
            }
        }
    }
}

// Extension bo góc tùy ý cho SwiftUI
public struct RoundedCornerShape: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    public func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

extension View {
    public func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCornerShape(radius: radius, corners: corners))
    }
}
