import Foundation
import SwiftUI

public enum AppScreen: Hashable {
    case login
    case robotPicker
    case robotControl(DeviceModel)
}

@MainActor
public final class AppState: ObservableObject {
    @Published public var currentScreen: AppScreen = .login
    @Published public var selectedDevice: DeviceModel? = nil
    
    private let keychain = KeychainManager.shared
    private let authService = EcovacsAuthService.shared
    
    public init() {
        checkSavedSession()
    }
    
    /// Kiểm tra phiên đăng nhập đã lưu vĩnh viễn trên máy
    public func checkSavedSession() {
        if keychain.hasSavedSession {
            // Đã có tài khoản lưu vĩnh viễn -> Vào thẳng màn hình chọn Robot
            self.currentScreen = .robotPicker
            
            // Chạy gia hạn token ngầm trong nền (nếu cần)
            Task {
                do {
                    _ = try await authService.ensureValidToken()
                } catch {
                    print("[AppState] Silent refresh failed, but keeping session: \(error)")
                }
            }
        } else {
            self.currentScreen = .login
        }
    }
    
    public func navigateToPicker() {
        self.selectedDevice = nil
        self.currentScreen = .robotPicker
    }
    
    public func navigateToControl(device: DeviceModel) {
        self.selectedDevice = device
        self.keychain.lastSelectedDid = device.did
        self.currentScreen = .robotControl(device)
    }
    
    public func logout() {
        authService.logout()
        self.selectedDevice = nil
        self.currentScreen = .login
    }
}
