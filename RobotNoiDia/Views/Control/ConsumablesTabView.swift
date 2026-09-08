import SwiftUI

public struct ConsumablesTabView: View {
    @ObservedObject var viewModel: RobotControlViewModel
    @State private var selectedComponentToReset: ConsumableType? = nil
    @State private var showResetAlert: Bool = false
    
    public init(viewModel: RobotControlViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 14) {
            // Header phụ
            HStack {
                Text("Tuổi thọ phụ kiện & Bảo dưỡng")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: {
                    Task { await viewModel.refreshConsumables() }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.cyan)
                }
            }
            .padding(.horizontal, 4)
            
            // Danh sách các linh kiện
            ForEach(viewModel.consumables.allItems) { item in
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: item.type.systemIcon)
                            .font(.system(size: 22))
                            .foregroundColor(item.isWarning ? .red : .cyan)
                            .frame(width: 32)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.type.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text("Còn lại: \(String(format: "%.1f", item.leftHours))h / \(String(format: "%.0f", item.totalHours))h")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        // % và nút Reset
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(item.percent)%")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(item.isWarning ? .red : (item.percent < 40 ? .orange : .green))
                            
                            Button(action: {
                                selectedComponentToReset = item.type
                                showResetAlert = true
                            }) {
                                Text("Reset 100%")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.cyan)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.cyan.opacity(0.12))
                                    .cornerRadius(6)
                            }
                        }
                    }
                    
                    // Thanh tiến độ %
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 6)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(item.isWarning ? Color.red : (item.percent < 40 ? Color.orange : Color.green))
                                .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(item.percent) / 100.0)), height: 6)
                        }
                    }
                    .frame(height: 6)
                }
                .padding(16)
                .background(Color(red: 0.08, green: 0.11, blue: 0.18))
                .cornerRadius(16)
            }
        }
        .alert(isPresented: $showResetAlert) {
            let comp = selectedComponentToReset ?? .brush
            return Alert(
                title: Text("Xác nhận Reset linh kiện?"),
                message: Text("Bạn đã vệ sinh hoặc thay mới \(comp.title)? Tuổi thọ sẽ được đặt lại về 100%."),
                primaryButton: .default(Text("Đặt lại 100%")) {
                    viewModel.resetConsumable(type: comp)
                },
                secondaryButton: .cancel(Text("Hủy"))
            )
        }
    }
}
