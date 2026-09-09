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

public struct MapPoint: Codable, Hashable {
    public let x: Double
    public let y: Double
    
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
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
    
    // Thống kê phiên dọn dẹp hiện tại (Live stats)
    public var cleanAreaM2: Double
    public var cleanDurationSec: Int
    
    // Tọa độ định vị LiDAR thời gian thực
    public var robotX: Double
    public var robotY: Double
    public var robotAngle: Double
    public var dockX: Double
    public var dockY: Double
    public var trajectory: [MapPoint]
    
    // Trạng thái Trạm Sạc Thông Minh (Station State - Dòng Omni / Turbo)
    public var isWashingMop: Bool
    public var isAirDrying: Bool
    public var airDryingHours: Int
    public var dustbinEmptying: Bool
    
    // Bản đồ nâng cao: Tường ảo & Vùng cấm
    public var virtualWalls: [VirtualWall]
    public var restrictedZones: [RestrictedZone]
    
    // Lịch hẹn giờ dọn dẹp
    public var schedules: [CleaningScheduleItem]
    
    // Trợ lý giọng nói YIKO
    public var yikoEnabled: Bool
    
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
            cleanAreaM2: 0.0,
            cleanDurationSec: 0,
            robotX: 0.0,
            robotY: 0.0,
            robotAngle: 0.0,
            dockX: 0.0,
            dockY: 0.0,
            trajectory: [],
            isWashingMop: false,
            isAirDrying: false,
            airDryingHours: 2,
            dustbinEmptying: false,
            virtualWalls: [],
            restrictedZones: [],
            schedules: [
                CleaningScheduleItem(hour: 9, minute: 0, repeatDays: [2, 3, 4, 5, 6], isEnabled: false, cleanMode: "auto", label: "Dọn sáng các ngày đi làm"),
                CleaningScheduleItem(hour: 14, minute: 30, repeatDays: [1, 7], isEnabled: false, cleanMode: "auto", label: "Dọn dẹp cuối tuần")
            ],
            yikoEnabled: true,
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


