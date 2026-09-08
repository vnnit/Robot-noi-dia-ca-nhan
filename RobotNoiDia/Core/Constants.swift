import Foundation

public enum Constants {
    // MARK: - Ecovacs API Auth Credentials
    public static let clientKey = "1520391301804"
    public static let clientSecret = "6c319b2a5cd3e66e39159c2e28f2fce9"
    public static let authClientKey = "1520391491841"
    public static let authClientSecret = "77ef58ce3afbe337da74aa8c5ab963a9"
    
    // MARK: - API Endpoints
    public static let defaultCountry = "CN"
    public static let defaultLang = "EN"
    public static let appCode = "global_e"
    public static let appVersion = "1.6.3"
    public static let channel = "google_play"
    public static let deviceType = "1"
    public static let realm = "ecouser.net"
    
    public static let loginApiBaseUrl = "https://gl-cn-api.ecovacs.cn"
    public static let openApiBaseUrl = "https://gl-cn-openapi.ecovacs.cn"
    public static let portalApiBaseUrl = "https://portal.ecouser.net"
    
    // MARK: - DIY Custom Backend Server (HƯỚNG 2 - Live LiDAR Map)
    public static var diyServerBaseUrl: String {
        get {
            let saved = UserDefaults.standard.string(forKey: "custom_diy_server_url")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return saved.isEmpty ? "http://144.202.92.46:8080" : saved
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "custom_diy_server_url")
        }
    }
    
    public static func portalUrl(for country: String = "CN") -> String {
        let code = country.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if code == "CN" {
            return "https://portal.ecouser.net"
        } else if code == "US" || code == "CA" {
            return "https://portal-na.ecouser.net"
        } else {
            return "https://portal-ww.ecouser.net"
        }
    }
    
    public static let mqttBrokerHost = "jmq-ngiot-cn.dc.cn.ecouser.net"
    public static let mqttBrokerPort: UInt16 = 8883
    
    // MARK: - Friendly Model Names
    public static let modelFriendlyNames: [String: String] = [
        "CURIE_ACS_L": "DEEBOT T10 TURBO",
        "m2sj78": "DEEBOT T10 TURBO",
        "T9_AIVI_AF": "DEEBOT T9 AIVI",
        "8kwdb4": "DEEBOT T9 AIVI",
        "yna5xi": "DEEBOT T8 AIVI",
        "hlx3bt": "DEEBOT T9 Power",
        "om557c": "DEEBOT T20 PRO",
        "u1a3b5": "DEEBOT X1 OMNI"
    ]
    
    // MARK: - Error Code Descriptions (Vietnamese)
    public static let errorDescriptions: [Int: String] = [
        0: "Robot hoạt động bình thường",
        1: "Bánh xe điều hướng bị kẹt vật cản. Vui lòng kiểm tra và vệ sinh bánh xe.",
        2: "Chổi phụ (chổi ven) bị vướng tóc hoặc dị vật.",
        3: "Chổi chính bị kẹt. Vui lòng tháo chổi và vệ sinh trục xoay.",
        4: "Hộp chứa bụi chưa được lắp hoặc lắp chưa đúng khớp.",
        5: "Robot bị nhấc khỏi mặt đất hoặc mắc kẹt trên chướng ngại vật.",
        6: "Cảm biến chống rơi bị bám bụi bẩn. Vui lòng lau sạch đáy robot.",
        7: "Mức pin quá yếu. Robot cần sạc pin để tiếp tục vận hành.",
        8: "Cảm biến LiDAR quét Laser bị che khuất hoặc bị kẹt vật cản.",
        100: "Trạm sạc tự động (Dock) bị mất nguồn điện hoặc robot không tìm thấy đường về.",
        101: "Hộp chứa nước sạch hết nước hoặc hộp nước bẩn đã đầy.",
        102: "Khay giẻ lau xoay bị kẹt hoặc chưa gắn giẻ lau sàn.",
        103: "Hộp bụi tự động gom rác (Auto-Empty Station) bị nghẽn túi rác."
    ]
}
