import SwiftUI

public struct RobotCardView: View {
    public let device: DeviceModel
    public let onSelect: () -> Void
    public var onRename: ((String) -> Void)? = nil
    
    @State private var showRenameAlert: Bool = false
    @State private var newNameText: String = ""
    
    public init(device: DeviceModel, onSelect: @escaping () -> Void, onRename: ((String) -> Void)? = nil) {
        self.device = device
        self.onSelect = onSelect
        self.onRename = onRename
    }
    
    private var isCleaning: Bool {
        device.cleanState == "clean"
    }
    
    private var batteryLevel: Int {
        device.battery ?? 100
    }
    
    private var batteryColor: Color {
        if batteryLevel > 50 { return .green }
        if batteryLevel > 20 { return .orange }
        return .red
    }
    
    public var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 16) {
                // Hàng 1: Icon Robot thật, Tên, Model & Nút đổi tên
                HStack(spacing: 14) {
                    // Biểu tượng Robot Hút Bụi Laser LiDAR chuyên nghiệp
                    RobotAvatarView(isCleaning: isCleaning, size: 52)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(device.displayName)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            // Nút đổi tên Robot
                            Button(action: {
                                newNameText = device.displayName
                                showRenameAlert = true
                            }) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.cyan.opacity(0.85))
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                        
                        Text(device.friendlyModelName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.gray)
                        
                        if let fw = device.fwVer {
                            Text("Firmware: \(fw)")
                                .font(.system(size: 11))
                                .foregroundColor(.gray.opacity(0.8))
                        }
                    }
                    
                    Spacer()
                    
                    // Nút mũi tên vào điều khiển
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(isCleaning ? .cyan : .gray.opacity(0.6))
                }
                
                Divider()
                    .background(Color.white.opacity(0.08))
                
                // Hàng 2: Trạng thái Pin & Hoạt động thực tế
                HStack {
                    // Mức pin
                    HStack(spacing: 6) {
                        Image(systemName: (device.isCharging ?? false) ? "battery.100.bolt" : "battery.75")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(batteryColor)
                        
                        Text("\(batteryLevel)%")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        
                        if device.isCharging ?? false {
                            Text("• Đang sạc")
                                .font(.system(size: 12))
                                .foregroundColor(.yellow)
                        }
                    }
                    
                    Spacer()
                    
                    // Badge trạng thái
                    if isCleaning {
                        StatusBadgeView(text: "ĐANG DỌN DẸP", color: .cyan, isPulse: true)
                    } else if device.cleanState == "pause" {
                        StatusBadgeView(text: "Tạm dừng", color: .orange)
                    } else if device.isCharging ?? false {
                        StatusBadgeView(text: "Tại dock sạc", color: .green)
                    } else {
                        StatusBadgeView(text: device.cleanStateText ?? "Chờ lệnh", color: .blue)
                    }
                }
            }
            .padding(18)
            .background(Color(red: 0.08, green: 0.11, blue: 0.18))
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isCleaning ? Color.cyan : Color.white.opacity(0.08), lineWidth: isCleaning ? 2 : 1)
                    .shadow(color: isCleaning ? Color.cyan.opacity(0.5) : Color.clear, radius: 8)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .alert("Đổi tên Robot", isPresented: $showRenameAlert) {
            TextField("Nhập tên mới", text: $newNameText)
            Button("Lưu") {
                onRename?(newNameText)
            }
            Button("Hủy", role: .cancel) {}
        } message: {
            Text("Đặt tên gợi nhớ cho robot (VD: Robot Tầng 1, Deebot Phòng Khách).")
        }
    }
}
