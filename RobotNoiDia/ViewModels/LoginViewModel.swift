import Foundation
import SwiftUI

@MainActor
public final class LoginViewModel: ObservableObject {
    @Published public var account: String = ""
    @Published public var password: String = ""
    @Published public var country: String = "CN"
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    
    private let authService = EcovacsAuthService.shared
    private let keychain = KeychainManager.shared
    
    public init() {
        // Nạp sẵn tài khoản đã lưu (nếu có)
        if let savedAccount = keychain.account {
            self.account = savedAccount
        }
        self.country = keychain.country
    }
    
    public func login(onSuccess: @escaping () -> Void) {
        let trimmedAccount = account.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedAccount.isEmpty else {
            errorMessage = "Vui lòng nhập số điện thoại hoặc email."
            return
        }
        guard !trimmedPassword.isEmpty else {
            errorMessage = "Vui lòng nhập mật khẩu tài khoản."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                _ = try await authService.login(
                    account: trimmedAccount,
                    passwordOrHash: trimmedPassword,
                    country: country,
                    isHash: false
                )
                // Nạp và lưu cache trước danh sách robot để mở PickerView tức thì không có độ trễ
                _ = try? await EcovacsDeviceService.shared.fetchDevices()
                self.isLoading = false
                onSuccess()
            } catch {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
