import SwiftUI

public struct RobotControlView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: RobotControlViewModel
    
    public init(device: DeviceModel) {
        _viewModel = StateObject(wrappedValue: RobotControlViewModel(device: device))
    }
    
    private var batteryLevel: Int {
        viewModel.state.batteryPercent
    }
    
    private var batteryColor: Color {
        if batteryLevel > 50 { return .green }
        if batteryLevel > 20 { return .orange }
        return .red
    }
    
    public var body: some View {
        ZStack {
            // Nền tối
            Color(red: 0.05, green: 0.07, blue: 0.12)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Navigation Bar
                HStack {
                    Button(action: {
                        appState.navigateToPicker()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .bold))
                            Text("Đổi Robot")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.cyan)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 2) {
                        Text(viewModel.device.displayName)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(viewModel.device.friendlyModelName)
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // Nút làm mới dữ liệu
                    Button(action: {
                        viewModel.refreshAll()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.cyan)
                            .padding(8)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 12)
                
                // Nội dung chính
                ScrollView {
                    VStack(spacing: 16) {
                        // Card Trạng thái Tổng quan (Pin + Hoạt động)
                        HStack(spacing: 14) {
                            // Cụm Pin
                            HStack(spacing: 8) {
                                Image(systemName: viewModel.state.isCharging ? "battery.100.bolt" : "battery.75")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(batteryColor)
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("\(batteryLevel)%")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                    Text(viewModel.state.chargeText)
                                        .font(.system(size: 11))
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Spacer()
                            
                            // Trạng thái dọn dẹp
                            StatusBadgeView(
                                text: viewModel.state.cleanStateText,
                                color: viewModel.state.cleanState == "clean" ? .cyan : (viewModel.state.cleanState == "pause" ? .orange : .green),
                                isPulse: viewModel.state.cleanState == "clean"
                            )
                        }
                        .padding(16)
                        .background(Color(red: 0.08, green: 0.11, blue: 0.18))
                        .cornerRadius(16)
                        
                        // Cụm nút tác vụ nhanh
                        ControlActionBar(viewModel: viewModel)
                        
                        // Segment Tab Selector (Điều khiển / Phụ kiện / Bản đồ)
                        Picker("Tab", selection: $viewModel.selectedTab) {
                            ForEach(ControlTab.allCases) { tab in
                                HStack {
                                    Image(systemName: tab.icon)
                                    Text(tab.title)
                                }
                                .tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.vertical, 4)
                        
                        // Tab Content
                        switch viewModel.selectedTab {
                        case .controls:
                            SettingsTabView(viewModel: viewModel)
                        case .consumables:
                            ConsumablesTabView(viewModel: viewModel)
                        case .map:
                            MapTabView(viewModel: viewModel)
                        }
                        
                        Spacer().frame(height: 30)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }
            }
            
            // Toast thông báo nổi khi gửi lệnh
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
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
    }
}
