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
    public var size: CGFloat = 54
    
    public init(isCleaning: Bool, size: CGFloat = 54) {
        self.isCleaning = isCleaning
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
            
            // Thân Robot tròn (Chassis kim loại tối màu)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.24), Color(white: 0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(isCleaning ? Color.cyan : Color.white.opacity(0.2), lineWidth: isCleaning ? 2 : 1.2)
                )
                .shadow(color: isCleaning ? Color.cyan.opacity(0.4) : Color.black.opacity(0.5), radius: isCleaning ? 6 : 3)
            
            // Cản va chạm phía trước (Front Bumper Arc)
            Circle()
                .trim(from: 0.62, to: 0.88)
                .stroke(isCleaning ? Color.cyan.opacity(0.8) : Color.white.opacity(0.3), lineWidth: max(1.5, size * 0.035))
                .frame(width: size * 0.86, height: size * 0.86)
                .rotationEffect(.degrees(45))
            
            // Nắp mở hộp bụi (Dustbin lid groove)
            RoundedRectangle(cornerRadius: 3)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                .frame(width: size * 0.46, height: size * 0.32)
                .offset(y: size * 0.14)
            
            // Tháp cảm biến Laser LiDAR (D-ToF LDS Tower)
            Circle()
                .fill(
                    LinearGradient(
                        colors: isCleaning ? [Color.cyan, Color.blue] : [Color(white: 0.34), Color(white: 0.2)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.36, height: size * 0.36)
                .offset(y: -size * 0.12)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                        .offset(y: -size * 0.12)
                )
            
            // Mắt quét Laser LiDAR phát sáng
            Circle()
                .fill(isCleaning ? Color.white : Color.cyan.opacity(0.8))
                .frame(width: size * 0.12, height: size * 0.12)
                .offset(y: -size * 0.12)
            
            // Nút nguồn / Khởi động (LED Power Button)
            Circle()
                .fill(isCleaning ? Color.green : Color.white.opacity(0.6))
                .frame(width: size * 0.1, height: size * 0.1)
                .offset(y: size * 0.25)
                .shadow(color: isCleaning ? Color.green.opacity(0.8) : Color.clear, radius: 3)
        }
        .frame(width: size, height: size)
    }
}

/// Mô phỏng hình ảnh Robot DEEBOT cùng Trạm Sạc / Dock OMNI như ảnh thực tế (Hình 1)
public struct RobotStationHeroView: View {
    public let modelName: String
    public let isCleaning: Bool
    
    public init(modelName: String = "DEEBOT T10 TURBO", isCleaning: Bool = false) {
        self.modelName = modelName
        self.isCleaning = isCleaning
    }
    
    public var body: some View {
        ZStack {
            // Bóng đổ sàn nhà (Floor Shadow)
            Ellipse()
                .fill(Color.black.opacity(0.12))
                .frame(width: 290, height: 42)
                .blur(radius: 12)
                .offset(y: 115)
            
            // 1. Trạm sạc đa năng (OMNI / TURBO Dock Station)
            ZStack(alignment: .top) {
                // Thân trạm chính
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
                
                // Nắp bình nước sạch/bẩn phía trên
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
                    
                    // Khoang đỗ robot và giẻ lau ở đáy trạm
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(white: 0.2))
                            .frame(width: 155, height: 70)
                        
                        // Chi tiết bên trong khoang sạc
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
                
                // Logo Ecovacs trên trạm sạc
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
            
            // 2. Robot Hút Bụi DEEBOT màu trắng (Đỗ phía trước trạm)
            ZStack {
                // Bóng đổ của robot
                Circle()
                    .fill(Color.black.opacity(0.2))
                    .frame(width: 155, height: 155)
                    .blur(radius: 6)
                    .offset(x: 4, y: 8)
                
                // Thân tròn robot (Chassis trắng cao cấp)
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
                
                // Cản trước và khe cảm biến AIVI
                Circle()
                    .trim(from: 0.65, to: 0.85)
                    .stroke(Color(white: 0.75), lineWidth: 3)
                    .frame(width: 142, height: 142)
                    .rotationEffect(.degrees(40))
                
                // Tháp cảm biến Laser LiDAR (D-ToF LDS Tower)
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
                
                // Logo DEEBOT in chìm
                Text("DEEBOT")
                    .font(.system(size: 7, weight: .bold, design: .rounded))
                    .foregroundColor(Color(white: 0.6))
                    .offset(y: 48)
            }
            .offset(x: 52, y: 35)
        }
        .frame(height: 270)
    }
}


