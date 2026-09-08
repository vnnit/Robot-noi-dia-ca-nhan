import SwiftUI

@main
struct RobotNoiDiaApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            Group {
                switch appState.currentScreen {
                case .login:
                    LoginView()
                case .robotPicker:
                    RobotPickerView()
                case .robotControl(let device):
                    RobotControlView(device: device)
                        .id(device.did)
                }
            }
            .environmentObject(appState)
            .preferredColorScheme(.dark)
        }
    }
}
