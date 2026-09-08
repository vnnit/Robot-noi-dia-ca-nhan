import Foundation

public enum CleanAction: String, CaseIterable {
    case start = "start"
    case pause = "pause"
    case resume = "resume"
    case stop = "stop"
    
    public var title: String {
        switch self {
        case .start: return "Bắt đầu dọn"
        case .pause: return "Tạm dừng"
        case .resume: return "Tiếp tục"
        case .stop: return "Dừng hẳn"
        }
    }
}

public enum FanSpeedLevel: String, CaseIterable {
    case quiet = "quiet"
    case standard = "standard"
    case max = "max"
    case maxPlus = "max+"
    
    public var title: String {
        switch self {
        case .quiet: return "Yên tĩnh"
        case .standard: return "Tiêu chuẩn"
        case .max: return "Mạnh"
        case .maxPlus: return "Siêu mạnh (Max+)"
        }
    }
}

public struct DeviceState: Codable {
    public var batteryPercent: Int
    public var isLowBattery: Bool
    
    public var isCharging: Bool
    public var chargeMode: String
    public var chargeText: String
    
    public var cleanState: String // idle, clean, pause, stop, go_charging, charging, error
    public var cleanStateText: String
    public var cleanTrigger: String
    
    public var isWorking: Bool {
        return cleanState == "clean"
    }
    
    public var fanSpeed: String
    public var waterAmount: Int // 1..4
    
    public var volume: Int // 0..10
    public var childLock: Bool
    public var carpetAutoBoost: Bool
    
    public var errorCode: Int
    public var errorText: String
    public var fwVer: String?
    
    public static var initial: DeviceState {
        DeviceState(
            batteryPercent: 100,
            isLowBattery: false,
            isCharging: true,
            chargeMode: "slot",
            chargeText: "Đang sạc tại trạm",
            cleanState: "idle",
            cleanStateText: "Nghỉ ngơi / Chờ lệnh",
            cleanTrigger: "none",
            fanSpeed: "standard",
            waterAmount: 2,
            volume: 7,
            childLock: false,
            carpetAutoBoost: true,
            errorCode: 0,
            errorText: "Bình thường",
            fwVer: "v1.9.7"
        )
    }
}
