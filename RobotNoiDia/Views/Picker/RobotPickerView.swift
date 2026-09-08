import SwiftUI

public struct RobotPickerView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = RobotPickerViewModel()
    @State private var showLogoutAlert: Bool = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Nền tối
            Color(red: 0.05, green: 0.07, blue: 0.12)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Header Bar
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Robot Nội Địa")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Chọn robot để vào điều khiển chi tiết")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // Nút Làm mới
                    Button(action: {
                        viewModel.loadDevices(showLoading: false)
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.cyan)
                            .padding(10)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Circle())
                    }
                    
                    // Nút Đăng xuất
                    Button(action: {
                        showLogoutAlert = true
                    }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.red.opacity(0.8))
                            .padding(10)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 16)
                
                // Nội dung danh sách
                if viewModel.isLoading && viewModel.devices.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                            .scaleEffect(1.4)
                        Text("Đang nạp danh sách robot...")
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
                        
                        Text("Không tìm thấy robot nào trong tài khoản.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                        
                        Button(action: { viewModel.loadDevices() }) {
                            Text("Thử lại")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.cyan)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(Color.cyan.opacity(0.15))
                                .cornerRadius(8)
                        }
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(viewModel.devices) { dev in
                                RobotCardView(device: dev) {
                                    appState.navigateToControl(device: dev)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                    }
                    .refreshable {
                        viewModel.loadDevices(showLoading: false)
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadDevices()
        }
        .onDisappear {
            viewModel.stopAutoPolling()
        }
        .alert(isPresented: $showLogoutAlert) {
            Alert(
                title: Text("Đăng xuất tài khoản?"),
                message: Text("Thông tin đăng nhập đã lưu trên máy sẽ bị xoá. Bạn sẽ phải nhập lại tài khoản khi mở lại app."),
                primaryButton: .destructive(Text("Đăng xuất")) {
                    appState.logout()
                },
                secondaryButton: .cancel(Text("Hủy"))
            )
        }
    }
}
