import Foundation
import Security

/// Quản lý lưu trữ phiên đăng nhập vĩnh viễn trên thiết bị iPhone
/// Sử dụng Apple Keychain kết hợp UserDefaults để đảm bảo dữ liệu không bao giờ mất
/// Chỉ bị xoá khi người dùng chủ động bấm Đăng xuất (Logout)
public final class KeychainManager {
    public static let shared = KeychainManager()
    
    private let service = "com.robot.noidia.auth"
    private let userDefaults = UserDefaults.standard
    
    // Keys
    private let keyAccount = "ecovacs_account"
    private let keyPasswordHash = "ecovacs_password_hash"
    private let keyUserId = "ecovacs_user_id"
    private let keyToken = "ecovacs_token"
    private let keyExpiresAt = "ecovacs_expires_at"
    private let keyCountry = "ecovacs_country"
    private let keyDeviceId = "ecovacs_device_id"
    private let keyLastSelectedDid = "ecovacs_last_selected_did"
    
    private init() {}
    
    // MARK: - Kiểm tra trạng thái đăng nhập
    public var hasSavedSession: Bool {
        guard let acc = account, !acc.isEmpty,
              let pwd = passwordHash, !pwd.isEmpty else {
            return false
        }
        return true
    }
    
    // MARK: - Lưu thông tin đăng nhập vĩnh viễn
    public func saveSession(
        account: String,
        passwordHash: String,
        userId: String,
        token: String,
        expiresAt: Int,
        country: String = "CN",
        deviceId: String
    ) {
        setKeychain(account, forKey: keyAccount)
        setKeychain(passwordHash, forKey: keyPasswordHash)
        setKeychain(token, forKey: keyToken)
        
        userDefaults.set(account, forKey: keyAccount)
        userDefaults.set(passwordHash, forKey: keyPasswordHash)
        userDefaults.set(token, forKey: keyToken)
        userDefaults.set(userId, forKey: keyUserId)
        userDefaults.set(expiresAt, forKey: keyExpiresAt)
        userDefaults.set(country, forKey: keyCountry)
        userDefaults.set(deviceId, forKey: keyDeviceId)
    }
    
    public func updateToken(token: String, expiresAt: Int) {
        setKeychain(token, forKey: keyToken)
        userDefaults.set(token, forKey: keyToken)
        userDefaults.set(expiresAt, forKey: keyExpiresAt)
    }
    
    // MARK: - Getters
    public var account: String? {
        getKeychain(forKey: keyAccount) ?? userDefaults.string(forKey: keyAccount)
    }
    
    public var passwordHash: String? {
        getKeychain(forKey: keyPasswordHash) ?? userDefaults.string(forKey: keyPasswordHash)
    }
    
    public var userId: String? {
        userDefaults.string(forKey: keyUserId)
    }
    
    public var token: String? {
        getKeychain(forKey: keyToken) ?? userDefaults.string(forKey: keyToken)
    }
    
    public var expiresAt: Int {
        userDefaults.integer(forKey: keyExpiresAt)
    }
    
    public var country: String {
        userDefaults.string(forKey: keyCountry) ?? "CN"
    }
    
    public var deviceId: String {
        if let did = userDefaults.string(forKey: keyDeviceId), !did.isEmpty {
            return did
        }
        let generated = CryptoHelper.generateDeviceId(account: account ?? "default_user")
        userDefaults.set(generated, forKey: keyDeviceId)
        return generated
    }
    
    public var lastSelectedDid: String? {
        get { userDefaults.string(forKey: keyLastSelectedDid) }
        set { userDefaults.set(newValue, forKey: keyLastSelectedDid) }
    }
    
    // MARK: - Xoá phiên (Chỉ gọi khi người dùng bấm Logout)
    public func clearSession() {
        deleteKeychain(forKey: keyAccount)
        deleteKeychain(forKey: keyPasswordHash)
        deleteKeychain(forKey: keyToken)
        
        userDefaults.removeObject(forKey: keyAccount)
        userDefaults.removeObject(forKey: keyPasswordHash)
        userDefaults.removeObject(forKey: keyToken)
        userDefaults.removeObject(forKey: keyUserId)
        userDefaults.removeObject(forKey: keyExpiresAt)
        userDefaults.removeObject(forKey: keyCountry)
        userDefaults.removeObject(forKey: keyDeviceId)
        userDefaults.removeObject(forKey: keyLastSelectedDid)
    }
    
    // MARK: - Keychain Core
    private func setKeychain(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }
        deleteKeychain(forKey: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func getKeychain(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    
    private func deleteKeychain(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
