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
    @State private var showBoundaryDialog: Bool = false
    
    public init(device: DeviceModel) {
        _viewModel = StateObject(wrappedValue: RobotControlViewModel(device: device))
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let screenHeight = geometry.size.height
            let screenWidth = geometry.size.width
            
            let collapsedHeight: CGFloat = 240
            let expandedHeight: CGFloat = screenHeight - 90
            let collapsedOffsetY = screenHeight - collapsedHeight
            let expandedOffsetY: CGFloat = 90
            
            let baseOffsetY = isSheetExpanded ? expandedOffsetY : collapsedOffsetY
            let currentSheetOffsetY = max(expandedOffsetY, min(collapsedOffsetY, baseOffsetY + dragOffset))
            
            ZStack(alignment: .top) {
                Color(red: 0.94, green: 0.96, blue: 0.98)
                    .ignoresSafeArea()
                
                mapContentView(screenHeight: screenHeight)
                
                mapHeaderInfo
                
                mapOverlayButtons
                
                topNavigationBar
                
                floatingStatusCapsule
                
                bottomSheetContainer(
                    screenWidth: screenWidth,
                    expandedHeight: expandedHeight,
                    offsetY: currentSheetOffsetY
                )
                
                toastOverlayView
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
        .sheet(isPresented: $viewModel.showCleaningLogSheet) {
            CleaningLogSheetView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showScheduleSheet) {
            ScheduleView(viewModel: viewModel)
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
        .confirmationDialog("Tường Ảo & Vùng Cấm", isPresented: $showBoundaryDialog, titleVisibility: .visible) {
            boundaryDialogContent
        }
    }
    
    // MARK: - Gestures
    private var sheetDragGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                dragOffset = value.translation.height
            }
            .onEnded { value in
                let velocity = value.predictedEndTranslation.height
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    if isSheetExpanded {
                        if value.translation.height > 35 || velocity > 120 {
                            isSheetExpanded = false
                        }
                    } else {
                        if value.translation.height < -35 || velocity < -120 {
                            isSheetExpanded = true
                        }
                    }
                    dragOffset = 0
                }
            }
    }
    
    // MARK: - Subviews
    @ViewBuilder
    private func mapContentView(screenHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 90)
            
            ZStack {
                if viewModel.isMapLoading && (viewModel.svgMap == nil || viewModel.svgMap?.isEmpty == true) {
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.09, green: 0.47, blue: 1.0)))
                            .scaleEffect(1.2)
                        Text("Đang tải bản đồ LiDAR...")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                } else if let svg = viewModel.svgMap, !svg.isEmpty {
                    ZStack {
                        SVGWebView(
                            svgString: svg,
                            robotX: viewModel.state.robotX,
                            robotY: viewModel.state.robotY,
                            robotAngle: viewModel.state.robotAngle,
                            trajectory: viewModel.state.trajectory
                        )
                        .disabled(viewModel.isEditingBoundaries)
                        
                        if viewModel.isEditingBoundaries {
                            GeometryReader { geo in
                                BoundaryDrawingOverlayView(
                                    viewModel: viewModel,
                                    containerSize: geo.size,
                                    mapBounds: viewModel.mapBounds
                                )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .cornerRadius(18)
                    .padding(.horizontal, 8)
                    .shadow(color: Color.black.opacity(0.18), radius: 8, y: 3)
                } else {
                    LiDARRadarScanningView(device: viewModel.device, state: viewModel.state) {
                        Task { await viewModel.refreshMap() }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(height: screenHeight - 230)
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private var mapHeaderInfo: some View {
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
    }
    
    @ViewBuilder
    private var mapOverlayButtons: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 105)
            
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
            
            Button(action: {
                withAnimation {
                    viewModel.isEditingBoundaries.toggle()
                }
                if viewModel.isEditingBoundaries {
                    viewModel.showToastNotification("Chạm và kéo tay để vẽ tường ảo & vùng cấm")
                }
            }) {
                Image(systemName: viewModel.isEditingBoundaries ? "pencil.slash" : "hand.raised.slash.fill")
                    .font(.system(size: 16))
                    .foregroundColor(viewModel.isEditingBoundaries ? .white : Color(red: 0.95, green: 0.25, blue: 0.25))
                    .frame(width: 42, height: 42)
                    .background(viewModel.isEditingBoundaries ? Color.red : Color.white.opacity(0.95))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.08), radius: 5, y: 2)
            }
            
            Button(action: {
                viewModel.showScheduleSheet = true
            }) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 16))
                    .foregroundColor(Color.orange)
                    .frame(width: 42, height: 42)
                    .background(Color.white.opacity(0.95))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.08), radius: 5, y: 2)
            }
            
            Spacer()
        }
        .padding(.trailing, 16)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    
    @ViewBuilder
    private var topNavigationBar: some View {
        HStack(alignment: .center) {
            Button(action: {
                appState.navigateToPicker()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(Color(white: 0.15))
                    .padding(8)
            }
            
            Spacer()
            
            VStack(spacing: 3) {
                HStack(spacing: 6) {
                    RobotIconThumbnailView(device: viewModel.device, size: 24)
                    
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
    }
    
    @ViewBuilder
    private var floatingStatusCapsule: some View {
        VStack {
            Spacer().frame(height: 52)
            
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(viewModel.state.isWorking ? Color.blue : Color(red: 0.0, green: 0.75, blue: 0.45))
                        .frame(width: 7, height: 7)
                    
                    Text(viewModel.state.isWorking ? "Robot đang dọn dẹp" : (viewModel.state.isCharging ? "Đang sạc tại trạm" : "Robot đang chờ lệnh"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(white: 0.2))
                        .lineLimit(1)
                }
                
                Spacer()
                
                Button(action: {
                    Task { await viewModel.fetchCleaningLogs() }
                    viewModel.showCleaningLogSheet = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 11, weight: .bold))
                        Text("Nhật ký")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color(red: 0.09, green: 0.47, blue: 1.0).opacity(0.1))
                    .cornerRadius(8)
                }
                
                Button(action: {
                    Task { await viewModel.refreshMap() }
                    viewModel.toastMessage = "Đang quét lại bản đồ..."
                    viewModel.showToast = true
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10, weight: .bold))
                        Text("Quét")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(Color(white: 0.3))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color(white: 0.94))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.95))
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(0.08), radius: 6, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
            .padding(.horizontal, 14)
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private func bottomSheetContainer(screenWidth: CGFloat, expandedHeight: CGFloat, offsetY: CGFloat) -> some View {
        VStack(spacing: 0) {
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
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    bottomSheetMainActions
                    
                    Divider()
                        .background(Color.gray.opacity(0.15))
                        .padding(.horizontal, 16)
                    
                    VStack(alignment: .leading, spacing: 18) {
                        smartStationCard
                        scheduleQuickCard
                        cleaningControlsCard
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
        .offset(y: offsetY)
        .simultaneousGesture(sheetDragGesture)
    }
    
    @ViewBuilder
    private var bottomSheetMainActions: some View {
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
        
        HStack(spacing: 0) {
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
    }
    
    @ViewBuilder
    private var smartStationCard: some View {
        if viewModel.device.hasOmniStation {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    HStack(spacing: 6) {
                        Image(systemName: "powerplug.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                        Text("Trạm sạc thông minh (Turbo / OMNI)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color(white: 0.15))
                    }
                    
                    Spacer()
                    
                    if viewModel.state.isWashingMop {
                        HStack(spacing: 4) {
                            Circle().fill(Color.blue).frame(width: 6, height: 6)
                            Text("Đang giặt giẻ...")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                    } else if viewModel.state.isAirDrying {
                        HStack(spacing: 4) {
                            Circle().fill(Color.orange).frame(width: 6, height: 6)
                            Text("Đang sấy nóng...")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.orange)
                        }
                    } else if viewModel.state.dustbinEmptying {
                        HStack(spacing: 4) {
                            Circle().fill(Color.purple).frame(width: 6, height: 6)
                            Text("Đang hút rác...")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.purple)
                        }
                    } else {
                        Text("Trạm sẵn sàng")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(white: 0.5))
                    }
                }
                
                HStack(spacing: 8) {
                    // Nút 1: Giặt giẻ thủ công
                    Button(action: {
                        viewModel.triggerStationAction(viewModel.state.isWashingMop ? .stopMopWash : .startMopWash)
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: viewModel.state.isWashingMop ? "stop.fill" : "drop.triangle.fill")
                                .font(.system(size: 14))
                            Text(viewModel.state.isWashingMop ? "Dừng giặt" : "Giặt giẻ")
                                .font(.system(size: 11, weight: .bold))
                            Text(viewModel.state.isWashingMop ? "Đang chạy" : "Thủ công")
                                .font(.system(size: 9))
                                .opacity(0.8)
                        }
                        .foregroundColor(viewModel.state.isWashingMop ? .white : Color(red: 0.09, green: 0.47, blue: 1.0))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(viewModel.state.isWashingMop ? Color.blue : Color(red: 0.91, green: 0.95, blue: 1.0))
                        .cornerRadius(10)
                    }
                    
                    // Nút 2: Bắt đầu sấy khô giẻ khí nóng (Hot Air Drying)
                    Button(action: {
                        viewModel.triggerStationAction(viewModel.state.isAirDrying ? .stopAirDrying : .startAirDrying)
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: viewModel.state.isAirDrying ? "stop.fill" : "wind")
                                .font(.system(size: 14))
                            Text(viewModel.state.isAirDrying ? "Dừng sấy" : "Sấy khí nóng")
                                .font(.system(size: 11, weight: .bold))
                            Text(viewModel.state.isAirDrying ? "Đang sấy" : "Khí nóng 45°C")
                                .font(.system(size: 9))
                                .opacity(0.8)
                        }
                        .foregroundColor(viewModel.state.isAirDrying ? .white : Color.orange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(viewModel.state.isAirDrying ? Color.orange : Color.orange.opacity(0.12))
                        .cornerRadius(10)
                    }
                    
                    // Nút 3: Tự động hút rác vào túi bụi (Auto-empty dustbin)
                    Button(action: {
                        viewModel.triggerStationAction(.emptyDustbin)
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 14))
                            Text(viewModel.state.dustbinEmptying ? "Đang hút..." : "Hút bụi rác")
                                .font(.system(size: 11, weight: .bold))
                            Text("Vào túi bụi")
                                .font(.system(size: 9))
                                .opacity(0.8)
                        }
                        .foregroundColor(viewModel.state.dustbinEmptying ? .white : Color.purple)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(viewModel.state.dustbinEmptying ? Color.purple : Color.purple.opacity(0.12))
                        .cornerRadius(10)
                    }
                }
            }
            .padding(12)
            .background(Color(red: 0.97, green: 0.98, blue: 1.0))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.blue.opacity(0.15), lineWidth: 1)
            )
            
            Divider().padding(.vertical, 2)
        }
    }
    
    @ViewBuilder
    private var scheduleQuickCard: some View {
        Button(action: {
            viewModel.showScheduleSheet = true
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.orange)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lịch Hẹn Giờ Dọn Dẹp (Schedule)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(white: 0.15))
                    
                    let activeCount = viewModel.state.schedules.filter { $0.isEnabled }.count
                    Text(activeCount > 0 ? "\(activeCount) khung giờ đang bật tự động" : "Hẹn robot tự chạy vào khung giờ cố định trong tuần")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray.opacity(0.6))
            }
            .padding(12)
            .background(Color.white)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.orange.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    @ViewBuilder
    private var cleaningControlsCard: some View {
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
    
    @ViewBuilder
    private var toastOverlayView: some View {
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
    
    @ViewBuilder
    private var boundaryDialogContent: some View {
        Button("Thêm Tường Ảo (Virtual Wall)") {
            let rx = viewModel.state.robotX
            let ry = viewModel.state.robotY
            viewModel.addVirtualWall(x1: rx - 10, y1: ry - 10, x2: rx + 10, y2: ry - 10)
        }
        Button("Thêm Vùng Cấm Hút & Lau (No-Go)") {
            let rx = viewModel.state.robotX
            let ry = viewModel.state.robotY
            viewModel.addRestrictedZone(x: rx - 10, y: ry + 5, width: 15, height: 15, type: .noGo)
        }
        Button("Thêm Vùng Cấm Lau Nhà (No-Mop)") {
            let rx = viewModel.state.robotX
            let ry = viewModel.state.robotY
            viewModel.addRestrictedZone(x: rx + 5, y: ry + 5, width: 12, height: 12, type: .noMop)
        }
        if !viewModel.state.virtualWalls.isEmpty || !viewModel.state.restrictedZones.isEmpty {
            Button("Xóa Tất Cả Tường Ảo & Vùng Cấm", role: .destructive) {
                viewModel.state.virtualWalls.removeAll()
                viewModel.state.restrictedZones.removeAll()
                Task { await viewModel.updateMapSvg() }
                viewModel.showToastNotification("Đã xóa tất cả tường ảo và vùng cấm")
            }
        }
        Button("Đóng", role: .cancel) {}
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

// MARK: - Màn hình Nhật ký vệ sinh & Thống kê trọn đời (Cleaning Log Sheet)
public struct CleaningLogSheetView: View {
    @ObservedObject var viewModel: RobotControlViewModel
    @Environment(\.presentationMode) var presentationMode
    
    public init(viewModel: RobotControlViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.96, green: 0.97, blue: 0.99)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // 3 Thẻ thống kê trọn đời (Stats Cards)
                        if let stats = viewModel.cleaningStats {
                            HStack(spacing: 10) {
                                statCard(
                                    title: "Tổng diện tích",
                                    value: stats.formattedArea,
                                    unit: "m²",
                                    color: Color(red: 0.09, green: 0.47, blue: 1.0)
                                )
                                statCard(
                                    title: "Tổng thời gian",
                                    value: stats.totalHoursText,
                                    unit: "giờ",
                                    color: Color(red: 0.0, green: 0.75, blue: 0.45)
                                )
                                statCard(
                                    title: "Số lần dọn",
                                    value: "\(stats.totalCount)",
                                    unit: "lần",
                                    color: Color(red: 0.45, green: 0.3, blue: 0.9)
                                )
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                        } else if viewModel.isLogsLoading {
                            ProgressView()
                                .padding(.top, 20)
                        }
                        
                        // Danh sách lịch sử dọn dẹp gần đây
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Lịch sử dọn dẹp gần đây")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color(white: 0.2))
                                
                                Spacer()
                                
                                Button(action: {
                                    Task { await viewModel.fetchCleaningLogs() }
                                }) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.top, 8)
                            
                            if viewModel.isLogsLoading && viewModel.cleaningLogs.isEmpty {
                                VStack(spacing: 10) {
                                    ProgressView()
                                    Text("Đang tải dữ liệu nhật ký...")
                                        .font(.system(size: 13))
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 30)
                            } else if viewModel.cleaningLogs.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "doc.text.magnifyingglass")
                                        .font(.system(size: 38))
                                        .foregroundColor(.gray.opacity(0.4))
                                    Text("Chưa có phiên dọn dẹp nào gần đây")
                                        .font(.system(size: 13))
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 35)
                            } else {
                                LazyVStack(spacing: 10) {
                                    ForEach(viewModel.cleaningLogs) { log in
                                        logItemRow(log: log)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        
                        Spacer().frame(height: 24)
                    }
                }
            }
            .navigationTitle("Nhật Ký Dọn Dẹp")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.showCleaningLogSheet = false
                    }) {
                        Text("Xong")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                    }
                }
            }
        }
    }
    
    private func statCard(title: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(white: 0.45))
            
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 17, weight: .black))
                    .foregroundColor(color)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(unit)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(white: 0.5))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.04), radius: 5, y: 2)
    }
    
    private func logItemRow(log: CleaningLogItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(Color(red: 0.0, green: 0.75, blue: 0.45))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(log.time)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(white: 0.15))
                Text(log.result)
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.45))
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(log.area) m²")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(white: 0.15))
                Text("\(log.duration) phút")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 1)
    }
}
