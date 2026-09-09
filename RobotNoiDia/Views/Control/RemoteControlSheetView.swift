import SwiftUI

/// Màn hình Cần Điều Khiển Thủ Công (Manual Remote Control / D-Pad)
public struct RemoteControlSheetView: View {
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
                
                VStack(spacing: 24) {
                    // Header trạng thái robot
                    robotStatusHeader
                    
                    Spacer()
                    
                    // Cụm phím điều hướng D-Pad Joystick
                    dpadControllerView
                    
                    Spacer()
                    
                    // Các thao tác phụ (Về sạc, Hút tại chỗ, Định vị)
                    quickAuxiliaryActions
                    
                    Text("Nhấn các nút điều hướng để di chuyển robot ra khỏi gầm giường/tủ hoặc tới vị trí rác.")
                        .font(.system(size: 11))
                        .foregroundColor(Color.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)
                }
                .padding(.top, 16)
            }
            .navigationTitle("Điều Khiển Thủ Công")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") {
                        HapticManager.shared.light()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                }
            }
        }
    }
    
    // MARK: - Header
    private var robotStatusHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.09, green: 0.47, blue: 1.0).opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.device.displayName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.12))
                Text("Pin \(viewModel.state.batteryPercent)% • \(viewModel.state.cleanStateText)")
                    .font(.system(size: 12))
                    .foregroundColor(Color.gray)
            }
            
            Spacer()
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.04), radius: 5, y: 2)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Cụm phím D-Pad
    private var dpadControllerView: some View {
        ZStack {
            // Nền vòng tròn trung tâm
            Circle()
                .fill(Color.white)
                .frame(width: 250, height: 250)
                .shadow(color: Color.black.opacity(0.08), radius: 16, y: 6)
            
            // 1. Phím TIẾN (Forward)
            VStack {
                dpadDirectionButton(icon: "arrow.up", direction: "forward", label: "Tiến")
                Spacer()
            }
            .frame(height: 230)
            
            // 2. Phím LÙI (Backward)
            VStack {
                Spacer()
                dpadDirectionButton(icon: "arrow.down", direction: "backward", label: "Lùi")
            }
            .frame(height: 230)
            
            // 3. Phím TRÁI (Left)
            HStack {
                dpadDirectionButton(icon: "arrow.left", direction: "left", label: "Trái")
                Spacer()
            }
            .frame(width: 230)
            
            // 4. Phím PHẢI (Right)
            HStack {
                Spacer()
                dpadDirectionButton(icon: "arrow.right", direction: "right", label: "Phải")
            }
            .frame(width: 230)
            
            // 5. Nút DỪNG ở giữa (STOP)
            Button(action: {
                HapticManager.shared.medium()
                viewModel.sendManualMove(direction: "stop")
            }) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.12))
                        .frame(width: 68, height: 68)
                    
                    Circle()
                        .fill(Color.red)
                        .frame(width: 52, height: 52)
                        .shadow(color: Color.red.opacity(0.4), radius: 6, y: 2)
                    
                    Text("DỪNG")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    private func dpadDirectionButton(icon: String, direction: String, label: String) -> some View {
        Button(action: {
            HapticManager.shared.light()
            viewModel.sendManualMove(direction: direction)
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.94, green: 0.95, blue: 0.98))
                    .frame(width: 60, height: 60)
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
            }
        }
    }
    
    // MARK: - Thao tác phụ
    private var quickAuxiliaryActions: some View {
        HStack(spacing: 16) {
            // Nút Về sạc
            Button(action: {
                HapticManager.shared.medium()
                viewModel.triggerCharge()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                    Text("Về sạc")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
            }
            
            // Nút Phát âm thanh định vị
            Button(action: {
                HapticManager.shared.light()
                viewModel.triggerPlaySound()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "speaker.wave.3.fill")
                    Text("Định vị")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Color.orange)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
            }
        }
    }
}
