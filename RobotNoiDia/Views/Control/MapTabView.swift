import SwiftUI

public struct MapTabView: View {
    @ObservedObject var viewModel: RobotControlViewModel
    
    public init(viewModel: RobotControlViewModel) {
        self.viewModel = viewModel
    }
    
    private var formattedTime: String {
        let totalSec = viewModel.state.cleanDurationSec
        let mins = totalSec / 60
        let secs = totalSec % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    private var areaText: String {
        if viewModel.state.cleanAreaM2 > 0 {
            return String(format: "%.1f m²", viewModel.state.cleanAreaM2)
        } else if let cov = viewModel.mapCoverageM2, cov > 0 {
            return "\(cov) m²"
        }
        return "-- m²"
    }
    
    public var body: some View {
        VStack(spacing: 14) {
            // MARK: - 1. Live HUD Statistics Bar
            HStack(spacing: 0) {
                // Diện tích
                VStack(spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.dashed")
                            .font(.system(size: 12))
                            .foregroundColor(.cyan)
                        Text("DIỆN TÍCH")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.gray)
                    }
                    Text(areaText)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .background(Color.white.opacity(0.15))
                    .frame(height: 28)
                
                // Thời gian dọn
                VStack(spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: "stopwatch")
                            .font(.system(size: 12))
                            .foregroundColor(.cyan)
                        Text("THỜI GIAN")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.gray)
                    }
                    Text(formattedTime)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .background(Color.white.opacity(0.15))
                    .frame(height: 28)
                
                // Mức pin
                VStack(spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.state.isCharging ? "battery.100.bolt" : "battery.75")
                            .font(.system(size: 12))
                            .foregroundColor(viewModel.state.isCharging ? .green : .cyan)
                        Text("PIN")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.gray)
                    }
                    Text("\(viewModel.state.batteryPercent)%")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(viewModel.state.isLowBattery ? .red : .white)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .background(Color.white.opacity(0.15))
                    .frame(height: 28)
                
                // Trạng thái
                VStack(spacing: 3) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(viewModel.state.isWorking ? Color.cyan : (viewModel.state.isCharging ? Color.green : Color.orange))
                            .frame(width: 6, height: 6)
                        Text("TRẠNG THÁI")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.gray)
                    }
                    Text(viewModel.state.cleanStateText)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(viewModel.state.isWorking ? .cyan : (viewModel.state.isCharging ? .green : .white))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .background(Color(red: 0.08, green: 0.11, blue: 0.18))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            
            // MARK: - 2. Khu vực Bản đồ SVG Realtime
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(red: 0.04, green: 0.06, blue: 0.10))
                    .frame(height: 410)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
                    )
                
                if viewModel.isMapLoading && (viewModel.svgMap == nil || viewModel.svgMap?.isEmpty == true) {
                    VStack(spacing: 14) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                            .scaleEffect(1.3)
                        Text("Đang đồng bộ tọa độ & LiDAR từ Ecovacs...")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(height: 410)
                } else if let svg = viewModel.svgMap, !svg.isEmpty {
                    SVGWebView(
                        svgString: svg,
                        robotX: viewModel.state.robotX,
                        robotY: viewModel.state.robotY,
                        robotAngle: viewModel.state.robotAngle,
                        trajectory: viewModel.state.trajectory
                    )
                        .frame(height: 400)
                        .cornerRadius(16)
                        .padding(5)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "map.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.6))
                        
                        Text("Chưa có dữ liệu bản đồ hiển thị.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                        
                        Button(action: {
                            Task { await viewModel.refreshMap() }
                        }) {
                            Text("Tải bản đồ ngay")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.cyan)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.cyan.opacity(0.15))
                                .cornerRadius(8)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(height: 410)
                }
                
                // Floating Action Buttons (Góc trên bên phải bản đồ)
                VStack(spacing: 8) {
                    // Nút quét lại map
                    Button(action: {
                        Task { await viewModel.refreshMap() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 34, height: 34)
                            .background(Color.black.opacity(0.65))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                    }
                    
                    // Nút định vị phát chuông
                    Button(action: {
                        viewModel.triggerPlaySound()
                    }) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.cyan)
                            .frame(width: 34, height: 34)
                            .background(Color.black.opacity(0.65))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.cyan.opacity(0.3), lineWidth: 1))
                    }
                    
                    // Nút làm mới vệt đường đi
                    if !viewModel.state.trajectory.isEmpty {
                        Button(action: {
                            viewModel.clearTrajectory()
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.orange)
                                .frame(width: 34, height: 34)
                                .background(Color.black.opacity(0.65))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.orange.opacity(0.3), lineWidth: 1))
                        }
                    }
                }
                .padding(12)
            }
            
            // MARK: - 3. Quick Action Bar (Ngay dưới bản đồ)
            HStack(spacing: 12) {
                // Nút Dọn dẹp / Tạm dừng
                Button(action: {
                    if viewModel.state.cleanState == "clean" {
                        viewModel.triggerClean(action: .pause)
                    } else if viewModel.state.cleanState == "pause" {
                        viewModel.triggerClean(action: .resume)
                    } else {
                        viewModel.triggerClean(action: .start)
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: viewModel.state.cleanState == "clean" ? "pause.fill" : "play.fill")
                            .font(.system(size: 15))
                        Text(viewModel.state.cleanState == "clean" ? "Tạm dừng" : (viewModel.state.cleanState == "pause" ? "Tiếp tục" : "Bắt đầu dọn"))
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(
                        LinearGradient(
                            colors: viewModel.state.cleanState == "clean" ? [Color.orange, Color.red] : [Color.blue, Color.cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: (viewModel.state.cleanState == "clean" ? Color.orange : Color.cyan).opacity(0.3), radius: 6, y: 2)
                }
                
                // Nút Về trạm sạc
                Button(action: {
                    viewModel.triggerCharge()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 15))
                        Text("Về trạm sạc")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.6))
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Color(red: 0.05, green: 0.18, blue: 0.12))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.green.opacity(0.35), lineWidth: 1)
                    )
                }
            }
        }
    }
}
