import SwiftUI

public struct StatusBadgeView: View {
    public let text: String
    public let color: Color
    public var isPulse: Bool = false
    
    @State private var pulseOpacity = 0.4
    
    public init(text: String, color: Color, isPulse: Bool = false) {
        self.text = text
        self.color = color
        self.isPulse = isPulse
    }
    
    public var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .opacity(isPulse ? pulseOpacity : 1.0)
                .onAppear {
                    if isPulse {
                        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                            pulseOpacity = 1.0
                        }
                    }
                }
            
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

public struct CustomToastView: View {
    public let message: String
    
    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.cyan)
                .font(.system(size: 16, weight: .bold))
            
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(red: 0.1, green: 0.14, blue: 0.2).opacity(0.95))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.cyan.opacity(0.4), lineWidth: 1)
        )
    }
}

/// Biểu tượng Robot Hút Bụi Laser LiDAR Ecovacs chuyên dụng
public struct RobotAvatarView: View {
    public let isCleaning: Bool
    public let isDarkModel: Bool
    public var size: CGFloat = 54
    
    public init(isCleaning: Bool, isDarkModel: Bool = false, size: CGFloat = 54) {
        self.isCleaning = isCleaning
        self.isDarkModel = isDarkModel
        self.size = size
    }
    
    public var body: some View {
        ZStack {
            // Hiệu ứng hào quang khi đang dọn dẹp
            if isCleaning {
                Circle()
                    .fill(Color.cyan.opacity(0.25))
                    .frame(width: size * 1.15, height: size * 1.15)
                    .blur(radius: 4)
            }
            
            // Thân Robot tròn (Trắng sứ cao cấp hoặc Kim loại đen nòng súng Gunmetal)
            Circle()
                .fill(
                    isDarkModel ?
                    LinearGradient(
                        colors: [Color(white: 0.24), Color(white: 0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                    LinearGradient(
                        colors: [Color.white, Color(white: 0.92)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(isCleaning ? Color.cyan : (isDarkModel ? Color.white.opacity(0.25) : Color(white: 0.82)), lineWidth: isCleaning ? 2 : 1.2)
                )
                .shadow(color: isCleaning ? Color.cyan.opacity(0.4) : Color.black.opacity(0.35), radius: isCleaning ? 6 : 3)
            
            // Cản va chạm phía trước (Front Bumper Arc)
            Circle()
                .trim(from: 0.62, to: 0.88)
                .stroke(isCleaning ? Color.cyan.opacity(0.8) : (isDarkModel ? Color.white.opacity(0.35) : Color(white: 0.72)), lineWidth: max(1.5, size * 0.035))
                .frame(width: size * 0.86, height: size * 0.86)
                .rotationEffect(.degrees(45))
            
            // Nắp mở hộp bụi (Dustbin lid groove)
            RoundedRectangle(cornerRadius: 3)
                .stroke(isDarkModel ? Color.white.opacity(0.12) : Color.black.opacity(0.08), lineWidth: 1)
                .frame(width: size * 0.46, height: size * 0.32)
                .offset(y: size * 0.14)
            
            // Tháp cảm biến Laser LiDAR (D-ToF LDS Tower)
            Circle()
                .fill(
                    isCleaning ?
                    LinearGradient(colors: [Color.cyan, Color.blue], startPoint: .top, endPoint: .bottom) :
                    (isDarkModel ?
                     LinearGradient(colors: [Color(white: 0.34), Color(white: 0.2)], startPoint: .top, endPoint: .bottom) :
                     LinearGradient(colors: [Color.white, Color(white: 0.86)], startPoint: .top, endPoint: .bottom))
                )
                .frame(width: size * 0.36, height: size * 0.36)
                .offset(y: -size * 0.12)
                .overlay(
                    Circle()
                        .stroke(isDarkModel ? Color.white.opacity(0.4) : Color(white: 0.78), lineWidth: 1)
                        .offset(y: -size * 0.12)
                )
            
            // Mắt quét Laser LiDAR phát sáng
            Circle()
                .fill(isCleaning ? Color.white : (isDarkModel ? Color.cyan.opacity(0.85) : Color.blue.opacity(0.8)))
                .frame(width: size * 0.12, height: size * 0.12)
                .offset(y: -size * 0.12)
            
            // Nút nguồn / Khởi động (LED Power Button)
            Circle()
                .fill(isCleaning ? Color.green : (isDarkModel ? Color.white.opacity(0.6) : Color(white: 0.5)))
                .frame(width: size * 0.1, height: size * 0.1)
                .offset(y: size * 0.25)
                .shadow(color: isCleaning ? Color.green.opacity(0.8) : Color.clear, radius: 3)
        }
        .frame(width: size, height: size)
    }
}

/// Mô phỏng hình ảnh Robot DEEBOT cùng Trạm Sạc / Dock OMNI chuẩn model (Hình 1)
/// Tự động thích ứng ngoại hình:
/// - DEEBOT T10 TURBO / OMNI: Robot trắng sứ + Trạm giẻ OMNI màu trắng cao cấp
/// - DEEBOT T9 AIVI / T8 AIVI: Robot đen nòng súng (Gunmetal) + Trạm sạc / trạm hút rác tự động đen bóng
public struct RobotStationHeroView: View {
    public let modelName: String
    public let isCleaning: Bool
    public let isDarkModel: Bool
    
    public init(modelName: String = "DEEBOT", isCleaning: Bool = false, isDarkModel: Bool = false) {
        self.modelName = modelName
        self.isCleaning = isCleaning
        self.isDarkModel = isDarkModel
    }
    
    public var body: some View {
        ZStack {
            // Bóng đổ sàn nhà (Floor Shadow)
            Ellipse()
                .fill(Color.black.opacity(isDarkModel ? 0.16 : 0.12))
                .frame(width: 290, height: 42)
                .blur(radius: 12)
                .offset(y: 115)
            
            // 1. Trạm sạc đa năng (Dock Station)
            if isDarkModel {
                // Trạm sạc / Auto-Empty Dock cho dòng T9 AIVI / T8 AIVI (Đen carbon sang trọng)
                ZStack(alignment: .top) {
                    // Thân trạm chính màu đen nòng súng
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.25), Color(white: 0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 160, height: 195)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.2), radius: 10, x: -4, y: 6)
                    
                    // Tháp gom bụi tự động Auto-Empty Tower
                    VStack(spacing: 0) {
                        // Nắp trạm trên cùng
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(white: 0.2))
                            .frame(width: 160, height: 38)
                            .overlay(
                                Rectangle()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(height: 1),
                                alignment: .bottom
                            )
                        
                        Spacer()
                        
                        // Cửa khoang hút bụi / chân tiếp xúc sạc
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(white: 0.1))
                                .frame(width: 140, height: 60)
                            
                            HStack(spacing: 16) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.yellow.opacity(0.85))
                                    .frame(width: 14, height: 8)
                                Circle()
                                    .fill(Color(white: 0.28))
                                    .frame(width: 28, height: 28)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.yellow.opacity(0.85))
                                    .frame(width: 14, height: 8)
                            }
                        }
                        .padding(.bottom, 6)
                    }
                    .frame(width: 160, height: 195)
                    
                    // Đèn LED chỉ báo trạng thái trạm (Xanh dương / Trắng)
                    Circle()
                        .fill(Color.cyan.opacity(0.9))
                        .frame(width: 6, height: 6)
                        .shadow(color: Color.cyan, radius: 4)
                        .padding(.top, 16)
                    
                    // Logo Ecovacs khắc chìm trên trạm
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1.2)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Text("E")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Color.white.opacity(0.5))
                        )
                        .padding(.top, 56)
                }
                .offset(x: -38, y: 0)
            } else {
                // Trạm OMNI giặt sấy giẻ cho dòng T10 TURBO (Trắng sứ tinh khôi)
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.98), Color(white: 0.92)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 175, height: 215)
                        .shadow(color: Color.black.opacity(0.08), radius: 10, x: -4, y: 6)
                    
                    VStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(white: 0.94))
                            .frame(width: 175, height: 44)
                            .overlay(
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 1),
                                alignment: .bottom
                            )
                        
                        Spacer()
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(white: 0.2))
                                .frame(width: 155, height: 70)
                            
                            HStack(spacing: 12) {
                                Rectangle()
                                    .fill(Color(white: 0.35))
                                    .frame(width: 32, height: 18)
                                    .cornerRadius(4)
                                Rectangle()
                                    .fill(Color(white: 0.15))
                                    .frame(width: 44, height: 14)
                                    .cornerRadius(2)
                            }
                        }
                        .padding(.bottom, 6)
                    }
                    .frame(width: 175, height: 215)
                    
                    Circle()
                        .stroke(Color.gray.opacity(0.35), lineWidth: 1.5)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Text("E")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.gray)
                        )
                        .padding(.top, 65)
                }
                .offset(x: -38, y: -10)
            }
            
            // 2. Robot Hút Bụi DEEBOT đỗ phía trước trạm
            if isDarkModel {
                // Thân Robot DEEBOT T9 AIVI (Màu đen bóng Carbon / Nòng súng cao cấp)
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.25))
                        .frame(width: 155, height: 155)
                        .blur(radius: 6)
                        .offset(x: 4, y: 8)
                    
                    // Thân tròn chassis kim loại tối màu
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(white: 0.28), Color(white: 0.13)],
                                center: .center,
                                startRadius: 10,
                                endRadius: 80
                            )
                        )
                        .frame(width: 155, height: 155)
                        .overlay(
                            Circle()
                                .stroke(isCleaning ? Color.cyan : Color.white.opacity(0.2), lineWidth: isCleaning ? 2.5 : 1.5)
                        )
                        .shadow(color: Color.black.opacity(0.35), radius: 8, x: 2, y: 4)
                    
                    // Cản trước và camera kép AIVI 3D nhận diện vật thể
                    Circle()
                        .trim(from: 0.65, to: 0.85)
                        .stroke(Color.white.opacity(0.3), lineWidth: 3)
                        .frame(width: 142, height: 142)
                        .rotationEffect(.degrees(40))
                    
                    // Tháp cảm biến Laser LiDAR (D-ToF LDS Tower) màu đen
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.32), Color(white: 0.18)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 54, height: 54)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.25), lineWidth: 1.2)
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 4, x: 1, y: 2)
                        .overlay(
                            Circle()
                                .stroke(isCleaning ? Color.cyan : Color.cyan.opacity(0.7), lineWidth: 1.5)
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Text("E")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(Color.cyan)
                                )
                        )
                    
                    // Huy hiệu DEEBOT • AIVI
                    HStack(spacing: 3) {
                        Text("DEEBOT")
                            .font(.system(size: 7, weight: .bold, design: .rounded))
                            .foregroundColor(Color(white: 0.75))
                        Text("AIVI")
                            .font(.system(size: 7, weight: .black, design: .rounded))
                            .foregroundColor(Color.cyan)
                    }
                    .offset(y: 48)
                }
                .offset(x: 52, y: 35)
            } else {
                // Thân Robot DEEBOT T10 TURBO (Màu trắng sứ tinh khôi)
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.2))
                        .frame(width: 155, height: 155)
                        .blur(radius: 6)
                        .offset(x: 4, y: 8)
                    
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white, Color(white: 0.93)],
                                center: .center,
                                startRadius: 10,
                                endRadius: 80
                            )
                        )
                        .frame(width: 155, height: 155)
                        .overlay(
                            Circle()
                                .stroke(isCleaning ? Color.cyan : Color(white: 0.85), lineWidth: isCleaning ? 2.5 : 1.5)
                        )
                        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 2, y: 4)
                    
                    Circle()
                        .trim(from: 0.65, to: 0.85)
                        .stroke(Color(white: 0.75), lineWidth: 3)
                        .frame(width: 142, height: 142)
                        .rotationEffect(.degrees(40))
                    
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white, Color(white: 0.88)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 54, height: 54)
                        .overlay(
                            Circle()
                                .stroke(Color(white: 0.8), lineWidth: 1.2)
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 1, y: 2)
                        .overlay(
                            Circle()
                                .stroke(isCleaning ? Color.cyan : Color.gray.opacity(0.4), lineWidth: 1.5)
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Text("E")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(isCleaning ? .cyan : .gray)
                                )
                        )
                    
                    Text("DEEBOT")
                        .font(.system(size: 7, weight: .bold, design: .rounded))
                        .foregroundColor(Color(white: 0.6))
                        .offset(y: 48)
                }
                .offset(x: 52, y: 35)
            }
        }
        .frame(height: 270)
    }
}

/// Hiển thị hình ảnh Robot lớn ở màn hình chọn Robot (RobotPickerView)
/// Tự động nạp ảnh PNG chính hãng từ Ecovacs PIM server qua AsyncImage, kèm bóng đổ sàn nhà.
/// Nếu đang tải hoặc mất mạng, tự động fallback sang mô phỏng RobotStationHeroView.
public struct RobotHeroImageView: View {
    public let device: DeviceModel
    
    public init(device: DeviceModel) {
        self.device = device
    }
    
    public var body: some View {
        ZStack {
            // Bóng đổ sàn nhà (Floor shadow)
            Ellipse()
                .fill(Color.black.opacity(device.isDarkModel ? 0.16 : 0.12))
                .frame(width: 260, height: 38)
                .blur(radius: 12)
                .offset(y: 112)
            
            if let iconUrl = device.resolvedIconUrl {
                AsyncImage(url: iconUrl) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(height: 245)
                            .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 8)
                    case .failure, .empty:
                        RobotStationHeroView(
                            modelName: device.friendlyModelName,
                            isCleaning: device.isCleaning,
                            isDarkModel: device.isDarkModel
                        )
                    @unknown default:
                        RobotStationHeroView(
                            modelName: device.friendlyModelName,
                            isCleaning: device.isCleaning,
                            isDarkModel: device.isDarkModel
                        )
                    }
                }
            } else {
                RobotStationHeroView(
                    modelName: device.friendlyModelName,
                    isCleaning: device.isCleaning,
                    isDarkModel: device.isDarkModel
                )
            }
        }
        .frame(height: 270)
    }
}

/// Thumbnail icon robot tròn hoặc vuông bo góc cho danh sách RobotCardView / Header
public struct RobotIconThumbnailView: View {
    public let device: DeviceModel
    public var size: CGFloat = 52
    
    public init(device: DeviceModel, size: CGFloat = 52) {
        self.device = device
        self.size = size
    }
    
    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28)
                .fill(Color(red: 0.12, green: 0.15, blue: 0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.28)
                        .stroke(device.isCleaning ? Color.cyan : Color.white.opacity(0.12), lineWidth: device.isCleaning ? 1.5 : 1)
                )
            
            if let iconUrl = device.resolvedIconUrl {
                AsyncImage(url: iconUrl) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .padding(size * 0.1)
                    case .failure, .empty:
                        RobotAvatarView(isCleaning: device.isCleaning, isDarkModel: device.isDarkModel, size: size * 0.78)
                    @unknown default:
                        RobotAvatarView(isCleaning: device.isCleaning, isDarkModel: device.isDarkModel, size: size * 0.78)
                    }
                }
            } else {
                RobotAvatarView(isCleaning: device.isCleaning, isDarkModel: device.isDarkModel, size: size * 0.78)
            }
            
            if device.isCleaning {
                Circle()
                    .fill(Color.cyan)
                    .frame(width: size * 0.2, height: size * 0.2)
                    .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
                    .offset(x: size * 0.36, y: -size * 0.36)
            }
        }
        .frame(width: size, height: size)
    }
}


