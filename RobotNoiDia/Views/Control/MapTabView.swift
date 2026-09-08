import SwiftUI

public struct MapTabView: View {
    @ObservedObject var viewModel: RobotControlViewModel
    
    public init(viewModel: RobotControlViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // Header phụ & Nút Làm mới bản đồ
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bản đồ Laser LiDAR")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text("Chạm 2 ngón tay để thu phóng và di chuyển")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                Spacer()
                Button(action: {
                    Task { await viewModel.refreshMap() }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("Quét lại")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.cyan.opacity(0.12))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 4)
            
            // Khu vực bản đồ SVG
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(red: 0.06, green: 0.08, blue: 0.14))
                    .frame(height: 380)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                
                if viewModel.isMapLoading {
                    VStack(spacing: 14) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                            .scaleEffect(1.3)
                        Text("Đang tải dữ liệu bản đồ từ cảm biến LiDAR...")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                } else if let svg = viewModel.svgMap, !svg.isEmpty {
                    SVGWebView(svgString: svg)
                        .frame(height: 370)
                        .cornerRadius(16)
                        .padding(4)
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
                }
            }
        }
    }
}
