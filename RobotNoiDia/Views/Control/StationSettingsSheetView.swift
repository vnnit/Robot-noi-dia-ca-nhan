import SwiftUI

/// Màn hình Cài đặt Trạm sạc Nâng cao (Station Turbo / Auto-Empty Settings)
public struct StationSettingsSheetView: View {
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
                    VStack(spacing: 18) {
                        // Header trạng thái trạm
                        stationStatusBanner
                        
                        // CÀI ĐẶT CHO TRẠM GIẶT GIẺ & SẤY NÓNG (T10 TURBO / OMNI)
                        if viewModel.device.hasMopWashStation {
                            turboSettingsSection
                        }
                        
                        // CÀI ĐẶT CHO TRẠM HÚT RÁC TỰ ĐỘNG (T9 AIVI DOCK RÁC)
                        if viewModel.device.hasAutoEmptyStation {
                            autoEmptySettingsSection
                        }
                        
                        // THAO TÁC THỦ CÔNG NHANH
                        manualActionsSection
                        
                        Spacer().frame(height: 30)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Cài Đặt Trạm Sạc")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Xong") {
                        HapticManager.shared.light()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                }
            }
        }
    }
    
    // MARK: - 1. Banner trạng thái trạm
    private var stationStatusBanner: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(viewModel.device.hasMopWashStation ? Color.blue.opacity(0.12) : Color.purple.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: viewModel.device.hasMopWashStation ? "powerplug.fill" : "trash.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(viewModel.device.hasMopWashStation ? Color(red: 0.09, green: 0.47, blue: 1.0) : Color.purple)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(viewModel.device.hasMopWashStation ? "Trạm Sạc Giặt Sấy Turbo" : "Trạm Hút Rác Tự Động")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.12))
                
                Text(stationCurrentStatusDescription)
                    .font(.system(size: 12))
                    .foregroundColor(Color.gray)
            }
            
            Spacer()
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.04), radius: 5, y: 2)
    }
    
    private var stationCurrentStatusDescription: String {
        if viewModel.state.dustbinEmptying {
            return "Đang gom rác vào túi lọc..."
        } else if viewModel.state.isWashingMop {
            return "Đang giặt giẻ lau kép xoay..."
        } else if viewModel.state.isAirDrying {
            return "Đang sấy khô khí nóng 45°C..."
        } else if viewModel.state.dustbinFull {
            return "⚠️ Túi rác đã đầy, cần thay mới"
        }
        return "Sẵn sàng hoạt động"
    }
    
    // MARK: - 2. Nhóm cài đặt T10 Turbo (Giặt giẻ & Sấy khô)
    private var turboSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "drop.triangle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                Text("GIẶT GIẺ LAU TỰ ĐỘNG")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.gray)
            }
            .padding(.leading, 4)
            
            VStack(spacing: 0) {
                // Tần suất giặt giẻ
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tần suất robot quay về giặt giẻ")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.12))
                    
                    Text("Robot sẽ tự động trở về trạm giặt sạch giẻ lau theo diện tích đã làm sạch:")
                        .font(.system(size: 11))
                        .foregroundColor(Color.gray)
                    
                    HStack(spacing: 6) {
                        frequencyPill(title: "Sau 6 m²", key: "6m2")
                        frequencyPill(title: "Sau 10 m²", key: "10m2")
                        frequencyPill(title: "Sau 15 m²", key: "15m2")
                        frequencyPill(title: "Mỗi phòng", key: "room")
                    }
                    .padding(.top, 4)
                }
                .padding(14)
                
                Divider().padding(.horizontal, 14)
                
                // Thời gian sấy khô khí nóng
                VStack(alignment: .leading, spacing: 8) {
                    Text("Thời gian sấy nóng khí nóng 45°C")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.12))
                    
                    Text("Thổi khí nóng làm khô giẻ hoàn toàn, diệt khuẩn và chống nấm mốc gây mùi:")
                        .font(.system(size: 11))
                        .foregroundColor(Color.gray)
                    
                    HStack(spacing: 8) {
                        ForEach([2, 3, 4], id: \.self) { hours in
                            dryingHourPill(hours: hours)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(14)
            }
            .background(Color.white)
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(0.04), radius: 5, y: 2)
        }
    }
    
    private func frequencyPill(title: String, key: String) -> some View {
        let isSelected = viewModel.state.stationWashFrequency == key
        return Button(action: {
            HapticManager.shared.selection()
            viewModel.updateWashFrequency(key)
        }) {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : Color(red: 0.1, green: 0.1, blue: 0.12))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(isSelected ? Color(red: 0.09, green: 0.47, blue: 1.0) : Color(red: 0.94, green: 0.95, blue: 0.97))
                .cornerRadius(9)
        }
    }
    
    private func dryingHourPill(hours: Int) -> some View {
        let isSelected = viewModel.state.airDryingHours == hours
        return Button(action: {
            HapticManager.shared.selection()
            viewModel.updateAirDryingHours(hours)
        }) {
            HStack(spacing: 4) {
                Image(systemName: "wind")
                    .font(.system(size: 11))
                Text("\(hours) Giờ")
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
            }
            .foregroundColor(isSelected ? .white : Color(red: 0.1, green: 0.1, blue: 0.12))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(isSelected ? Color.orange : Color(red: 0.94, green: 0.95, blue: 0.97))
            .cornerRadius(9)
        }
    }
    
    // MARK: - 3. Nhóm cài đặt T9 AIVI (Dock rác Auto-Empty)
    private var autoEmptySettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.purple)
                Text("TỰ ĐỘNG GOM RÁC (AUTO-EMPTY)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.gray)
            }
            .padding(.leading, 4)
            
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tần suất tự động gom rác vào dock")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.12))
                    
                    Text("Tự động hút rác từ hộp bụi robot lên túi rác dung tích lớn 2.5L của trạm:")
                        .font(.system(size: 11))
                        .foregroundColor(Color.gray)
                    
                    VStack(spacing: 8) {
                        autoEmptyOptionRow(title: "Sau mỗi lần dọn (Khuyên dùng)", detail: "Gom rác ngay khi robot vừa về trạm sạc", freq: 1)
                        autoEmptyOptionRow(title: "Sau mỗi 2 lần dọn", detail: "Phù hợp khi nhà ít bụi bẩn để tiết kiệm túi lọc", freq: 2)
                        autoEmptyOptionRow(title: "Sau mỗi 3 lần dọn", detail: "Gom sau 3 chu trình làm sạch", freq: 3)
                        autoEmptyOptionRow(title: "Chỉ gom thủ công khi bấm nút", detail: "Tắt tự động hút để tránh tiếng ồn ban đêm", freq: 0)
                    }
                    .padding(.top, 6)
                }
                .padding(14)
            }
            .background(Color.white)
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(0.04), radius: 5, y: 2)
        }
    }
    
    private func autoEmptyOptionRow(title: String, detail: String, freq: Int) -> some View {
        let isSelected = viewModel.state.autoEmptyFrequency == freq
        return Button(action: {
            HapticManager.shared.selection()
            viewModel.updateAutoEmptyFrequency(freq)
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.purple : Color.gray.opacity(0.4), lineWidth: 2)
                        .frame(width: 20, height: 20)
                    if isSelected {
                        Circle()
                            .fill(Color.purple)
                            .frame(width: 10, height: 10)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.12))
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundColor(Color.gray)
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(isSelected ? Color.purple.opacity(0.08) : Color.clear)
            .cornerRadius(8)
        }
    }
    
    // MARK: - 4. Thao tác thủ công nhanh
    private var manualActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("THAO TÁC THỦ CÔNG")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.gray)
                .padding(.leading, 4)
            
            VStack(spacing: 10) {
                if viewModel.device.hasAutoEmptyStation {
                    Button(action: {
                        HapticManager.shared.medium()
                        viewModel.triggerStationAction(.emptyDustbin)
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("Bắt đầu gom rác ngay")
                                .font(.system(size: 14, weight: .bold))
                            Spacer()
                            if viewModel.state.dustbinEmptying {
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .purple))
                            }
                        }
                        .foregroundColor(.purple)
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                
                if viewModel.device.hasMopWashStation {
                    Button(action: {
                        HapticManager.shared.medium()
                        viewModel.triggerStationAction(viewModel.state.isWashingMop ? .stopMopWash : .startMopWash)
                    }) {
                        HStack {
                            Image(systemName: viewModel.state.isWashingMop ? "stop.fill" : "drop.triangle.fill")
                            Text(viewModel.state.isWashingMop ? "Dừng giặt giẻ" : "Bắt đầu giặt giẻ ngay")
                                .font(.system(size: 14, weight: .bold))
                            Spacer()
                        }
                        .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                        .padding()
                        .background(Color(red: 0.09, green: 0.47, blue: 1.0).opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        HapticManager.shared.medium()
                        viewModel.triggerStationAction(viewModel.state.isAirDrying ? .stopAirDrying : .startAirDrying)
                    }) {
                        HStack {
                            Image(systemName: viewModel.state.isAirDrying ? "stop.fill" : "wind")
                            Text(viewModel.state.isAirDrying ? "Dừng sấy nóng" : "Bắt đầu sấy nóng 45°C ngay")
                                .font(.system(size: 14, weight: .bold))
                            Spacer()
                        }
                        .foregroundColor(.orange)
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
}
