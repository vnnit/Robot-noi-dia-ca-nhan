import SwiftUI

public struct SettingsTabView: View {
    @ObservedObject var viewModel: RobotControlViewModel
    
    public init(viewModel: RobotControlViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            // Cảnh báo lỗi nếu có
            if viewModel.state.errorCode != 0 {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.red)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CẢNH BÁO: Mã lỗi #\(viewModel.state.errorCode)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.red)
                        Text(viewModel.state.errorText)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    Spacer()
                }
                .padding(14)
                .background(Color.red.opacity(0.15))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.red.opacity(0.4), lineWidth: 1)
                )
            }
            
            // 1. Chỉnh Lực hút (Fan Speed)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "wind")
                        .foregroundColor(.cyan)
                    Text("Lực hút bụi")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Text(FanSpeedLevel(rawValue: viewModel.state.fanSpeed)?.title ?? viewModel.state.fanSpeed)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.cyan)
                }
                
                HStack(spacing: 8) {
                    ForEach(FanSpeedLevel.allCases, id: \.self) { level in
                        let isSelected = viewModel.state.fanSpeed == level.rawValue
                        Button(action: {
                            viewModel.setFanSpeed(level)
                        }) {
                            Text(level.title.replacingOccurrences(of: " (Max+)", with: ""))
                                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? .white : .gray)
                                .frame(maxWidth: .infinity)
                                .frame(height: 38)
                                .background(isSelected ? Color.cyan.opacity(0.3) : Color.white.opacity(0.04))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(isSelected ? Color.cyan : Color.white.opacity(0.08), lineWidth: 1)
                                )
                        }
                    }
                }
            }
            .padding(16)
            .background(Color(red: 0.08, green: 0.11, blue: 0.18))
            .cornerRadius(16)
            
            // 2. Chỉnh Mức nước lau sàn (Water Amount)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "drop.fill")
                        .foregroundColor(.blue)
                    Text("Lượng nước lau sàn")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Text("Mức \(viewModel.state.waterAmount)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.blue)
                }
                
                HStack(spacing: 8) {
                    ForEach(1...4, id: \.self) { amount in
                        let isSelected = viewModel.state.waterAmount == amount
                        Button(action: {
                            viewModel.setWaterAmount(amount)
                        }) {
                            HStack(spacing: 4) {
                                ForEach(0..<amount, id: \.self) { _ in
                                    Image(systemName: "drop.fill")
                                        .font(.system(size: 10))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .foregroundColor(isSelected ? .white : .gray)
                            .background(isSelected ? Color.blue.opacity(0.3) : Color.white.opacity(0.04))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isSelected ? Color.blue : Color.white.opacity(0.08), lineWidth: 1)
                            )
                        }
                    }
                }
            }
            .padding(16)
            .background(Color(red: 0.08, green: 0.11, blue: 0.18))
            .cornerRadius(16)
            
            // 3. Âm lượng giọng nói
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(.green)
                    Text("Âm lượng thông báo")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(viewModel.state.volume)/10")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.green)
                }
                
                Slider(
                    value: Binding(
                        get: { Double(viewModel.state.volume) },
                        set: { viewModel.setVolume(Int($0)) }
                    ),
                    in: 0...10,
                    step: 1
                )
                .tint(.green)
            }
            .padding(16)
            .background(Color(red: 0.08, green: 0.11, blue: 0.18))
            .cornerRadius(16)
            
            // 4. Tính năng nâng cao: Khóa trẻ em & Tăng áp thảm
            VStack(spacing: 14) {
                // Khóa trẻ em
                Toggle(isOn: Binding(
                    get: { viewModel.state.childLock },
                    set: { _ in viewModel.toggleChildLock() }
                )) {
                    HStack(spacing: 10) {
                        Image(systemName: "lock.circle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 20))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Khóa an toàn trẻ em")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Vô hiệu hóa nút bấm cứng trên thân robot")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                    }
                }
                .tint(.orange)
                
                Divider().background(Color.white.opacity(0.08))
                
                // Tăng áp khi lên thảm
                Toggle(isOn: Binding(
                    get: { viewModel.state.carpetAutoBoost },
                    set: { _ in viewModel.toggleCarpetBoost() }
                )) {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.cyan)
                            .font(.system(size: 20))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tự động tăng áp khi lên thảm")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Tăng tối đa lực hút khi cảm biến phát hiện thảm")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                    }
                }
                .tint(.cyan)
            }
            .padding(16)
            .background(Color(red: 0.08, green: 0.11, blue: 0.18))
            .cornerRadius(16)
        }
    }
}
