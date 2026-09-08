import SwiftUI

public struct RobotControlView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: RobotControlViewModel
    
    // Quản lý Bottom Sheet kéo vuốt mượt mà
    @State private var dragOffset: CGFloat = 0
    @State private var isSheetExpanded: Bool = false
    
    @State private var showRenameAlert: Bool = false
    @State private var newNameText: String = ""
    @State private var showBanner: Bool = true
    
    public init(device: DeviceModel) {
        _viewModel = StateObject(wrappedValue: RobotControlViewModel(device: device))
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let screenHeight = geometry.size.height
            let screenWidth = geometry.size.width
            
            // Chiều cao Bottom Sheet: thu gọn 240pt, mở rộng sát đỉnh (còn 90pt cho Top Bar)
            let collapsedHeight: CGFloat = 240
            let expandedHeight: CGFloat = screenHeight - 90
            let collapsedOffsetY = screenHeight - collapsedHeight
            let expandedOffsetY: CGFloat = 90
            
            let baseOffsetY = isSheetExpanded ? expandedOffsetY : collapsedOffsetY
            let currentSheetOffsetY = max(expandedOffsetY, min(collapsedOffsetY, baseOffsetY + dragOffset))
            
            // Cử chỉ kéo vuốt Bottom Sheet dùng chung
            let sheetDragGesture = DragGesture(minimumDistance: 5)
                .onChanged { value in
                    dragOffset = value.translation.height
                }
                .onEnded { value in
                    let velocity = value.predictedEndTranslation.height
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        if isSheetExpanded {
                            // Đang mở: kéo xuống > 35pt hoặc vuốt mạnh xuống thì thu gọn
                            if value.translation.height > 35 || velocity > 120 {
                                isSheetExpanded = false
                            }
                        } else {
                            // Đang thu gọn: kéo lên < -35pt hoặc vuốt mạnh lên thì mở rộng
                            if value.translation.height < -35 || velocity < -120 {
                                isSheetExpanded = true
                            }
                        }
                        dragOffset = 0
                    }
                }
            
            ZStack(alignment: .top) {
                // 1. NỀN BẢN ĐỒ
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
                                .cornerRadius(18)
                                .padding(.horizontal, 8)
                                .shadow(color: Color.black.opacity(0.18), radius: 8, y: 3)
                        } else {
                            // Radar quét LiDAR chân thực khi chưa có hoặc đang đồng bộ bản đồ
                            LiDARRadarScanningView(device: viewModel.device, state: viewModel.state) {
                                Task { await viewModel.refreshMap() }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(height: screenHeight - 230)
                    
                    Spacer()
                }
                
                // 2. CÁC NÚT NỔI TRÊN BẢN ĐỒ
                // Phía trên bên trái: Tên bản đồ & ID thực tế
                VStack(alignment: .leading, spacing: 8) {
                    Spacer().frame(height: 105)
                    
                    HStack(spacing: 5) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.cyan)
                        Text(viewModel.device.friendlyModelName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color.white)
                        if let mid = viewModel.mapId, !mid.isEmpty {
                            Text("• \(mid)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color.cyan)
                        }
                        if let cov = viewModel.mapCoverageM2, cov > 0 {
                            Text("• \(cov) m²")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(red: 0.0, green: 0.85, blue: 0.45))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.65))
                    .cornerRadius(8)
                    .shadow(color: Color.black.opacity(0.15), radius: 4, y: 2)
                    
                    Spacer()
                }
                .padding(.leading, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Phía trên bên phải: Các nút bản đồ
                VStack(spacing: 12) {
                    Spacer().frame(height: 105)
                    
                    // Nút làm mới bản đồ
                    Button(action: {
                        Task { await viewModel.refreshMap() }
                        viewModel.toastMessage = "Đang quét lại bản đồ..."
                        viewModel.showToast = true
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(white: 0.25))
                            .frame(width: 42, height: 42)
                            .background(Color.white.opacity(0.95))
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.08), radius: 5, y: 2)
                    }
                    
                    // Nút định vị robot
                    Button(action: {
                        viewModel.triggerRelocate()
                    }) {
                        Image(systemName: "location.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
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
                    
                    // Tên Robot & Pin
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
                            Image(systemName: viewModel.state.isCharging ? "bolt.fill" : "battery.100")
                                .font(.system(size: 10))
                                .foregroundColor(Color(red: 0.0, green: 0.75, blue: 0.45))
                            Text("\(viewModel.state.batteryPercent)%")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color(white: 0.35))
                            Text("|")
                                .font(.system(size: 10))
                                .foregroundColor(Color.gray.opacity(0.5))
                            Text(viewModel.state.cleanStateText)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(white: 0.35))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.85))
                        .cornerRadius(6)
                    }
                    
                    Spacer()
                    
                    // Nút Cài đặt (Gear icon)
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
                
                // 4. FLOATING BANNER TRÊN ĐỈNH BOTTOM SHEET
                if !isSheetExpanded && showBanner {
                    VStack {
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                            
                            Text(viewModel.state.cleanState == "clean" ? "Robot đang thực hiện dọn dẹp tự động." : "Robot đang ở trạng thái chờ lệnh.")
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
                        .padding(.bottom, collapsedHeight + 8)
                    }
                    .transition(.opacity)
                }
                
                // 5. DRAGGABLE BOTTOM SHEET (Chỉ giữ TỰ ĐỘNG, vuốt lên để xem cài đặt)
                VStack(spacing: 0) {
                    // Thanh gạt (Drag indicator) & Chỉ dẫn vuốt/chạm
                    VStack(spacing: 4) {
                        Capsule()
                            .fill(Color.gray.opacity(0.35))
                            .frame(width: 40, height: 5)
                            .padding(.top, 8)
                        
                        HStack(spacing: 4) {
                            Image(systemName: isSheetExpanded ? "chevron.down" : "chevron.up")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                            Text(isSheetExpanded ? "Thu gọn" : "Vuốt lên xem cài đặt")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(white: 0.45))
                        }
                        .padding(.bottom, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            isSheetExpanded.toggle()
                        }
                    }
                    .highPriorityGesture(sheetDragGesture)
                    
                    // Nội dung Bottom Sheet
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            // Badge Chế độ TỰ ĐỘNG duy nhất
                            HStack {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                                Text("CHẾ ĐỘ DỌN DẸP TỰ ĐỘNG")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color(red: 0.92, green: 0.96, blue: 1.0))
                            .cornerRadius(20)
                            .padding(.top, 2)
                            
                            // 3 Nút tác vụ chính: [Quét lại bản đồ] [▶ TỰ ĐỘNG DỌN DẸP] [Trạm sạc]
                            HStack(spacing: 0) {
                                // Nút 1: Quét lại bản đồ
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
                                        Text("Bản đồ")
                                            .font(.system(size: 11))
                                            .foregroundColor(Color(white: 0.35))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                
                                // Nút 2: TỰ ĐỘNG DỌN DẸP / TẠM DỪNG (Play / Pause)
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
                                        
                                        Text(viewModel.state.cleanState == "clean" ? "TẠM DỪNG" : "BẮT ĐẦU")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(Color(white: 0.2))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                
                                // Nút 3: Trạm sạc (Quay về sạc)
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
                            .padding(.top, 2)
                            
                            // Gợi ý vuốt lên
                            Divider()
                                .background(Color.gray.opacity(0.15))
                                .padding(.horizontal, 16)
                            
                            // CÁC TÍNH NĂNG ĐIỀU KHIỂN THẬT (Khi vuốt lên)
                            VStack(alignment: .leading, spacing: 18) {
                                // 1. Số lần dọn: [1 lần | 2 lần]
                                HStack {
                                    Text("Số lần dọn dẹp")
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
                                
                                // 2. Lực hút bụi: 4 mức
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Lực hút bụi")
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
                                
                                // 3. Lượng nước lau sàn: 4 mức
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Lượng nước lau sàn")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Color(white: 0.15))
                                    
                                    HStack(spacing: 8) {
                                        ForEach(1...4, id: \.self) { level in
                                            choicePill(title: "Mức \(level)", isSelected: viewModel.state.waterAmount == level) {
                                                viewModel.setWaterAmount(level)
                                            }
                                        }
                                    }
                                }
                                
                                // 4. Tự tăng áp khi leo lên thảm
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Tự động tăng áp thảm")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Color(white: 0.15))
                                        Text("Tăng lực hút tối đa khi cảm biến phát hiện thảm")
                                            .font(.system(size: 11))
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Toggle("", isOn: Binding(
                                        get: { viewModel.state.carpetAutoBoost },
                                        set: { _ in viewModel.toggleCarpetBoost() }
                                    ))
                                    .labelsHidden()
                                }
                                
                                // 5. Khóa an toàn trẻ em
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Khóa an toàn trẻ em")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Color(white: 0.15))
                                        Text("Khóa các nút bấm vật lý trên thân robot")
                                            .font(.system(size: 11))
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Toggle("", isOn: Binding(
                                        get: { viewModel.state.childLock },
                                        set: { _ in viewModel.toggleChildLock() }
                                    ))
                                    .labelsHidden()
                                }
                                
                                // 6. Âm lượng giọng nói robot
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
                                
                                // 7. Nút Tìm DEEBOT của tôi
                                Button(action: {
                                    viewModel.triggerPlaySound()
                                }) {
                                    HStack {
                                        Image(systemName: "speaker.wave.3.fill")
                                            .font(.system(size: 14))
                                        Text("Tìm DEEBOT của tôi (Phát chuông)")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(Color(red: 0.92, green: 0.96, blue: 1.0))
                                    .cornerRadius(10)
                                }
                                
                                // 8. Nút Cài đặt nâng cao > (Mở Hình 5)
                                Button(action: {
                                    viewModel.showMoreSettings = true
                                }) {
                                    HStack {
                                        Text("Cài đặt nâng cao")
                                            .font(.system(size: 15, weight: .bold))
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 13, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(Color(red: 0.09, green: 0.47, blue: 1.0))
                                    .cornerRadius(12)
                                }
                                .padding(.top, 4)
                            }
                            .padding(.horizontal, 20)
                            Spacer().frame(height: 100)
                        }
                    }
                    .scrollDisabled(!isSheetExpanded)
                }
                .frame(width: screenWidth, height: expandedHeight)
                .background(Color.white)
                .cornerRadius(24, corners: [.topLeft, .topRight])
                .shadow(color: Color.black.opacity(0.12), radius: 12, y: -4)
                .offset(y: currentSheetOffsetY)
                .simultaneousGesture(sheetDragGesture)
                
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
    }
    
    // MARK: - Subcomponents
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
}

// MARK: - View Radar quét LiDAR thực tế (khi chưa tải xong bản đồ)
public struct LiDARRadarScanningView: View {
    let device: DeviceModel
    let state: DeviceState
    let onRefresh: () -> Void
    
    @State private var isRotating: Bool = false
    
    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let radius = min(w, h) * 0.35
            
            ZStack {
                Color(red: 0.94, green: 0.96, blue: 0.98)
                
                // Vòng radar LiDAR
                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.12), lineWidth: 1.5)
                        .frame(width: radius * 2, height: radius * 2)
                    
                    Circle()
                        .stroke(Color.blue.opacity(0.18), lineWidth: 1.5)
                        .frame(width: radius * 1.4, height: radius * 1.4)
                    
                    Circle()
                        .stroke(Color.blue.opacity(0.24), lineWidth: 1.5)
                        .frame(width: radius * 0.75, height: radius * 0.75)
                    
                    // Trục ngang và trục dọc radar
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: radius))
                        path.addLine(to: CGPoint(x: radius * 2, y: radius))
                        path.move(to: CGPoint(x: radius, y: 0))
                        path.addLine(to: CGPoint(x: radius, y: radius * 2))
                    }
                    .stroke(Color.blue.opacity(0.08), lineWidth: 1)
                    .frame(width: radius * 2, height: radius * 2)
                    
                    // Tia quét radar xoay liên tục
                    Circle()
                        .fill(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    Color.blue.opacity(0.0),
                                    Color.blue.opacity(0.0),
                                    Color.blue.opacity(0.25)
                                ]),
                                center: .center
                            )
                        )
                        .frame(width: radius * 2, height: radius * 2)
                        .rotationEffect(.degrees(isRotating ? 360 : 0))
                        .animation(Animation.linear(duration: 3.5).repeatForever(autoreverses: false), value: isRotating)
                        .onAppear {
                            isRotating = true
                        }
                    
                    // Biểu tượng Robot ở giữa radar
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(Color(white: 0.15))
                                .frame(width: 46, height: 46)
                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                                .frame(width: 46, height: 46)
                            Image(systemName: "fanblades.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                        }
                        
                        Text(device.friendlyModelName)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(white: 0.25))
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(state.isCharging ? Color.green : Color.blue)
                                .frame(width: 6, height: 6)
                            Text(state.isCharging ? "Tại trạm sạc" : (state.cleanState == "clean" ? "Đang làm việc" : "Sẵn sàng"))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    }
                }
                .position(x: w / 2, y: h * 0.40)
                
                // Trạng thái & nút thao tác
                VStack(spacing: 12) {
                    Text("Đang đồng bộ bản đồ LiDAR từ cảm biến...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(white: 0.45))
                    
                    Button(action: onRefresh) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text("Tải lại bản đồ LiDAR")
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(red: 0.09, green: 0.47, blue: 1.0).opacity(0.12))
                        .cornerRadius(20)
                    }
                }
                .position(x: w / 2, y: h * 0.75)
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
