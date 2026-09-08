import SwiftUI

public struct ControlActionBar: View {
    @ObservedObject var viewModel: RobotControlViewModel
    
    public init(viewModel: RobotControlViewModel) {
        self.viewModel = viewModel
    }
    
    private var isCleaning: Bool {
        viewModel.state.cleanState == "clean"
    }
    
    private var isPaused: Bool {
        viewModel.state.cleanState == "pause"
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // Hàng 1: Nút Dọn dẹp chính (To nổi bật)
            HStack(spacing: 12) {
                // Nút Bắt đầu / Tạm dừng / Tiếp tục
                Button(action: {
                    if isCleaning {
                        viewModel.triggerClean(action: .pause)
                    } else if isPaused {
                        viewModel.triggerClean(action: .resume)
                    } else {
                        viewModel.triggerClean(action: .start)
                    }
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: isCleaning ? "pause.fill" : "play.fill")
                            .font(.system(size: 20, weight: .bold))
                        
                        Text(isCleaning ? "Tạm Dừng" : (isPaused ? "Tiếp Tục Dọn" : "Bắt Đầu Dọn"))
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        LinearGradient(
                            colors: isCleaning ? [Color.orange, Color.red] : [Color.cyan, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
                    .shadow(color: (isCleaning ? Color.orange : Color.cyan).opacity(0.4), radius: 8, x: 0, y: 4)
                }
                
                // Nếu đang dọn dẹp hoặc tạm dừng: Hiển thị nút Dừng hẳn
                if isCleaning || isPaused {
                    Button(action: {
                        viewModel.triggerClean(action: .stop)
                    }) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 52, height: 52)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(14)
                    }
                }
            }
            
            // Hàng 2: Về Sạc, Tìm Robot, Tái Định Vị
            HStack(spacing: 10) {
                // Về sạc
                Button(action: { viewModel.triggerCharge() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.batteryblock.fill")
                            .foregroundColor(.yellow)
                        Text("Về Trạm Sạc")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                
                // Định vị (phát âm thanh)
                Button(action: { viewModel.triggerPlaySound() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundColor(.cyan)
                        Text("Tìm Robot")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                
                // Tái định vị bản đồ
                Button(action: { viewModel.triggerRelocate() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "location.north.line.fill")
                            .foregroundColor(.green)
                        Text("Tái Định Vị")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
            }
        }
        .padding(16)
        .background(Color(red: 0.08, green: 0.11, blue: 0.18))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
