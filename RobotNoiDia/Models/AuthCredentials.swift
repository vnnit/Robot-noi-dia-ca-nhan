import Foundation

public struct AuthCredentials: Codable {
    public let userId: String
    public let token: String
    public let deviceId: String
    public let expiresAt: Int
    
    public var isExpired: Bool {
        let now = Int(Date().timeIntervalSince1970)
        return now >= expiresAt
    }
}
