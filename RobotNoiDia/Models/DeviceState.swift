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
    public var dustbinFull: Bool
    public var stationWashFrequency: String // "6m2", "10m2", "15m2", "room"
    public var autoEmptyFrequency: Int // 1, 2, 3, 0 (thủ công)
    public var stationErrorCode: Int
    
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
    public var carpetAvoidance: Bool
    public var cleanCount: Int // 1 (tiêu chuẩn), 2 (đan lưới bàn cờ x2)
    
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
            dustbinFull: false,
            stationWashFrequency: "10m2",
            autoEmptyFrequency: 1,
            stationErrorCode: 0,
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
            carpetAvoidance: false,
            cleanCount: 1,
            errorCode: 0,
            errorText: "Bình thường",
            fwVer: "v1.9.7"
        )
    }
}

// MARK: - Model Dọn Dẹp Theo Phòng (Room Clean)
public struct CleaningRoom: Identifiable, Codable, Hashable {
    public var id: String { "\(index)" }
    public let index: Int
    public var name: String
    public var icon: String
    public var colorHex: String
    
    public init(index: Int, name: String, icon: String, colorHex: String = "#3B82F6") {
        self.index = index
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
    }
}

// MARK: - Model Khoanh Vùng Tùy Chỉnh (Area Clean Box)
public struct CustomAreaBox: Codable, Hashable {
    public var x1: Double
    public var y1: Double
    public var x2: Double
    public var y2: Double
    
    public init(x1: Double, y1: Double, x2: Double, y2: Double) {
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
    }
    
    public var minX: Double { min(x1, x2) }
    public var maxX: Double { max(x1, x2) }
    public var minY: Double { min(y1, y2) }
    public var maxY: Double { max(y1, y2) }
    public var width: Double { abs(x2 - x1) }
    public var height: Double { abs(y2 - y1) }
    
    public var formattedAreaM2: String {
        // Quy đổi tọa độ viewBox sang m² ước tính (mỗi đơn vị ~ 0.1m)
        let area = (width * 0.1) * (height * 0.1)
        return String(format: "%.1f m²", max(1.0, area))
    }
}

// MARK: - Model Bản Đồ Sao Lưu Đa Tầng (Golden Map Backup)
public struct MapBackupItem: Identifiable, Codable, Hashable {
    public let id: String
    public var name: String
    public var floorName: String
    public var date: Date
    public var svgString: String
    public var viewBox: String
    public var rooms: [CleaningRoom]
    public var virtualWalls: [VirtualWall]
    public var restrictedZones: [RestrictedZone]
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        floorName: String = "Tầng 1",
        date: Date = Date(),
        svgString: String,
        viewBox: String,
        rooms: [CleaningRoom] = [],
        virtualWalls: [VirtualWall] = [],
        restrictedZones: [RestrictedZone] = []
    ) {
        self.id = id
        self.name = name
        self.floorName = floorName
        self.date = date
        self.svgString = svgString
        self.viewBox = viewBox
        self.rooms = rooms
        self.virtualWalls = virtualWalls
        self.restrictedZones = restrictedZones
    }
    
    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm • dd/MM/yyyy"
        return formatter.string(from: date)
    }
}



