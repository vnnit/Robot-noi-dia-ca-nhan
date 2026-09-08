import SwiftUI

/// Màn hình Cài đặt Nâng cao (Hình 5 - Chuẩn Ecovacs Home App)
public struct SettingsTabView: View {
    @ObservedObject var viewModel: RobotControlViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showYikoSheet: Bool = false
    @State private var showCleaningLogSheet: Bool = false
    @State private var showConsumablesSheet: Bool = false
    @State private var showAiviSheet: Bool = false
    @State private var showVideoManagerSheet: Bool = false
    @State private var showAboutRobotSheet: Bool = false
    @State private var showAboutStationSheet: Bool = false
    
    public init(viewModel: RobotControlViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                Color(red: 0.96, green: 0.97, blue: 0.99)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Nhóm 1: Trợ lý giọng nói YIKO (Chỉ hiện khi robot hỗ trợ)
                        if viewModel.device.hasYiko {
                            VStack(spacing: 0) {
                                Button(action: { showYikoSheet = true }) {
                                    settingItemRow(
                                        icon: "mic.fill",
                                        iconColor: Color(red: 0.09, green: 0.47, blue: 1.0),
                                        title: "Trợ lý giọng nói YIKO",
                                        detail: "Điều khiển bằng giọng nói OK YIKO"
                                    )
                                }
                            }
                            .background(Color.white)
                            .cornerRadius(14)
                            .padding(.horizontal, 16)
                        }
                        
                        // Nhóm 2: Nhật ký & Phụ kiện
                        VStack(spacing: 0) {
                            Button(action: {
                                Task { await viewModel.fetchCleaningLogs() }
                                showCleaningLogSheet = true
                            }) {
                                settingItemRow(
                                    icon: "clock.arrow.circlepath",
                                    iconColor: Color(red: 0.0, green: 0.75, blue: 0.45),
                                    title: "Nhật ký dọn dẹp",
                                    detail: "Lịch sử và diện tích đã làm sạch"
                                )
                            }
                            
                            Divider().padding(.leading, 50)
                            
                            Button(action: { showConsumablesSheet = true }) {
                                settingItemRow(
                                    icon: "wrench.and.screwdriver.fill",
                                    iconColor: Color.orange,
                                    title: "Phụ kiện & Bảo dưỡng",
                                    detail: "Tuổi thọ chổi, màng lọc, giẻ lau"
                                )
                            }
                        }
                        .background(Color.white)
                        .cornerRadius(14)
                        .padding(.horizontal, 16)
                        
                        // Nhóm 3: Trí tuệ AI, Camera & Chế độ không làm phiền
                        VStack(spacing: 0) {
                            if viewModel.device.hasCamera {
                                Button(action: { showAiviSheet = true }) {
                                    settingItemRow(
                                        icon: "eye.fill",
                                        iconColor: Color.purple,
                                        title: "Cài đặt thông minh AIVI",
                                        detail: "Nhận diện vật cản & trí tuệ nhân tạo 3D"
                                    )
                                }
                                
                                Divider().padding(.leading, 50)
                                
                                Button(action: { showVideoManagerSheet = true }) {
                                    settingItemRow(
                                        icon: "video.fill",
                                        iconColor: Color.blue,
                                        title: "Trình quản lý Video",
                                        detail: "Tuần tra an ninh và truyền hình trực tiếp"
                                    )
                                }
                                
                                Divider().padding(.leading, 50)
                            }
                            
                            // Toggle Chế độ Không làm phiền (DND)
                            HStack(spacing: 14) {
                                Image(systemName: "moon.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color.indigo)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Chế độ Không làm phiền")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(Color(white: 0.15))
                                    Text("Tắt thông báo giọng nói & đèn trạng thái ban đêm")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: Binding(
                                    get: { viewModel.doNotDisturb },
                                    set: { _ in viewModel.toggleDoNotDisturb() }
                                ))
                                .labelsHidden()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            
                            Divider().padding(.leading, 50)
                            
                            // Toggle Tự tăng áp thảm
                            HStack(spacing: 14) {
                                Image(systemName: "wind")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color.teal)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Tự tăng áp khi gặp thảm")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(Color(white: 0.15))
                                    Text("Tăng tối đa lực hút bụi khi robot leo lên thảm")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: Binding(
                                    get: { viewModel.state.carpetAutoBoost },
                                    set: { _ in viewModel.toggleCarpetBoost() }
                                ))
                                .labelsHidden()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            
                            Divider().padding(.leading, 50)
                            
                            // Toggle Khóa trẻ em
                            HStack(spacing: 14) {
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color.pink)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Khóa trẻ em")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(Color(white: 0.15))
                                    Text("Khóa nút bấm vật lý trên thân robot")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: Binding(
                                    get: { viewModel.state.childLock },
                                    set: { _ in viewModel.toggleChildLock() }
                                ))
                                .labelsHidden()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        .background(Color.white)
                        .cornerRadius(14)
                        .padding(.horizontal, 16)
                        
                        // Nhóm: Thông báo trạng thái iOS (Local Notifications)
                        VStack(spacing: 0) {
                            HStack(spacing: 14) {
                                Image(systemName: "bell.badge.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Thông báo trạng thái Robot")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(Color(white: 0.15))
                                    Text("Chuông & banner khi dọn xong, về sạc hoặc báo lỗi")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: Binding(
                                    get: { NotificationManager.shared.isEnabled },
                                    set: { NotificationManager.shared.isEnabled = $0 }
                                ))
                                .labelsHidden()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            
                            Divider().padding(.leading, 50)
                            
                            Button(action: {
                                NotificationManager.shared.sendTestNotification()
                                viewModel.toastMessage = "Đã gửi thông báo thử nghiệm!"
                                viewModel.showToast = true
                            }) {
                                settingItemRow(
                                    icon: "paperplane.fill",
                                    iconColor: Color.teal,
                                    title: "Gửi thông báo thử nghiệm",
                                    detail: "Kiểm tra chuông & banner thông báo ngay trên máy"
                                )
                            }
                        }
                        .background(Color.white)
                        .cornerRadius(14)
                        .padding(.horizontal, 16)
                        
                        // Nhóm 4: Thông tin thiết bị & Trạm
                        VStack(spacing: 0) {
                            Button(action: { showAboutRobotSheet = true }) {
                                settingItemRow(
                                    icon: "info.circle.fill",
                                    iconColor: Color.blue,
                                    title: "Thông tin DEEBOT",
                                    detail: "\(viewModel.device.friendlyModelName) • FW: \(viewModel.device.fwVer)"
                                )
                            }
                            
                            if viewModel.device.hasOmniStation {
                                Divider().padding(.leading, 50)
                                
                                Button(action: { showAboutStationSheet = true }) {
                                    settingItemRow(
                                        icon: "powerplug.fill",
                                        iconColor: Color.green,
                                        title: "Thông tin Trạm sạc OMNI",
                                        detail: "Trạm sạc tự động sấy khí nóng"
                                    )
                                }
                            }
                        }
                        .background(Color.white)
                        .cornerRadius(14)
                        .padding(.horizontal, 16)
                        
                        Spacer().frame(height: 100)
                    }
                    .padding(.top, 16)
                }
                
                // HÌNH 5: Nút lớn dưới đáy: "Tìm DEEBOT của tôi"
                VStack {
                    Button(action: {
                        viewModel.triggerPlaySound()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "speaker.wave.3.fill")
                                .font(.system(size: 18))
                            Text("Tìm DEEBOT của tôi")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color(red: 0.09, green: 0.47, blue: 1.0))
                        .cornerRadius(14)
                        .shadow(color: Color(red: 0.09, green: 0.47, blue: 1.0).opacity(0.35), radius: 8, y: 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }
            .navigationBarTitle("Cài đặt", displayMode: .inline)
            .navigationBarItems(
                leading: Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Quay lại")
                            .font(.system(size: 15))
                    }
                    .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                }
            )
            .sheet(isPresented: $showConsumablesSheet) {
                NavigationView {
                    ScrollView {
                        ConsumablesTabView(viewModel: viewModel)
                            .padding(16)
                    }
                    .navigationBarTitle("Phụ kiện & Bảo dưỡng", displayMode: .inline)
                    .navigationBarItems(trailing: Button("Xong") { showConsumablesSheet = false })
                }
            }
            .alert("Trợ lý giọng nói YIKO", isPresented: $showYikoSheet) {
                Button("Đóng", role: .cancel) {}
            } message: {
                Text("Nói \"OK YIKO\" để ra lệnh trực tiếp: \"Dọn dẹp phòng khách\", \"Quay về trạm sạc\", \"Tăng lực hút\".")
            }
            .sheet(isPresented: $showCleaningLogSheet) {
                CleaningLogSheetView(viewModel: viewModel)
            }
            .alert("Cài đặt thông minh AIVI", isPresented: $showAiviSheet) {
                Button("Đóng", role: .cancel) {}
            } message: {
                Text("Hệ thống AIVI 3D nhận diện vật cản giày dép, dây điện, phân thú cưng và lập bản đồ thời gian thực.")
            }
            .alert("Trình quản lý Video", isPresented: $showVideoManagerSheet) {
                Button("Đóng", role: .cancel) {}
            } message: {
                Text("Mã hoá video đầu cuối E2EE chuẩn an toàn dữ liệu TUV Rheinland. Tuần tra bảo vệ tổ ấm khi vắng nhà.")
            }
            .alert("Thông tin DEEBOT", isPresented: $showAboutRobotSheet) {
                Button("Đóng", role: .cancel) {}
            } message: {
                Text("Model: \(viewModel.device.friendlyModelName)\nPhiên bản FW: \(viewModel.device.fwVer)\nMã thiết bị DID: \(viewModel.device.did)")
            }
            .alert("Trạm sạc OMNI", isPresented: $showAboutStationSheet) {
                Button("Đóng", role: .cancel) {}
            } message: {
                Text("Trạm OMNI đa năng:\n- Tự động giặt giẻ lau kép xoay\n- Sấy khô giẻ lau bằng khí nóng 40°C\n- Tự động nạp nước sạch và bơm xả nước bẩn.")
            }
        }
    }
    
    private func settingItemRow(icon: String, iconColor: Color, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(white: 0.15))
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(white: 0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
