import Foundation

// MARK: - 1. Tường Ảo (Virtual Wall)
public struct VirtualWall: Identifiable, Codable, Hashable {
    public var id: String
    public var x1: Double
    public var y1: Double
    public var x2: Double
    public var y2: Double
    public var name: String
    
    public init(id: String = UUID().uuidString, x1: Double, y1: Double, x2: Double, y2: Double, name: String = "Tường ảo") {
        self.id = id
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
        self.name = name
    }
}

// MARK: - 2. Vùng Cấm (Restricted Zone: No-Go / No-Mop)
public enum RestrictedZoneType: String, Codable, CaseIterable {
    case noGo = "no_go"      // Cấm quét và lau
    case noMop = "no_mop"    // Cấm lau sàn (khu vực trải thảm)
    
    public var title: String {
        switch self {
        case .noGo: return "Vùng cấm vào"
        case .noMop: return "Vùng cấm lau (Thảm)"
        }
    }
    
    public var colorHex: String {
        switch self {
        case .noGo: return "#EF4444" // Đỏ
        case .noMop: return "#A855F7" // Tím
        }
    }
}

public struct RestrictedZone: Identifiable, Codable, Hashable {
    public var id: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var type: RestrictedZoneType
    public var name: String
    
    public init(id: String = UUID().uuidString, x: Double, y: Double, width: Double, height: Double, type: RestrictedZoneType, name: String = "") {
        self.id = id
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.type = type
        self.name = name.isEmpty ? type.title : name
    }
}

// MARK: - 3. Lịch Hẹn Giờ Dọn Dẹp (Cleaning Schedule)
public struct CleaningScheduleItem: Identifiable, Codable, Hashable {
    public var id: String
    public var hour: Int
    public var minute: Int
    public var repeatDays: [Int] // 1: CN, 2: T2, ..., 7: T7
    public var isEnabled: Bool
    public var cleanMode: String // "auto", "area"
    public var fanSpeed: String  // quiet, standard, max, max+
    public var waterAmount: Int  // 1..4
    public var label: String
    
    public init(
        id: String = UUID().uuidString,
        hour: Int,
        minute: Int,
        repeatDays: [Int] = [2, 3, 4, 5, 6, 7, 1],
        isEnabled: Bool = true,
        cleanMode: String = "auto",
        fanSpeed: String = "standard",
        waterAmount: Int = 2,
        label: String = "Hẹn giờ dọn dẹp"
    ) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.repeatDays = repeatDays
        self.isEnabled = isEnabled
        self.cleanMode = cleanMode
        self.fanSpeed = fanSpeed
        self.waterAmount = waterAmount
        self.label = label
    }
    
    public var timeString: String {
        String(format: "%02d:%02d", hour, minute)
    }
    
    public var repeatDaysText: String {
        if repeatDays.count == 7 {
            return "Hàng ngày"
        }
        if repeatDays.sorted() == [2, 3, 4, 5, 6] {
            return "Ngày trong tuần (T2 - T6)"
        }
        if repeatDays.sorted() == [1, 7] {
            return "Cuối tuần (T7, CN)"
        }
        if repeatDays.isEmpty {
            return "Một lần duy nhất"
        }
        let dayNames: [Int: String] = [
            1: "CN", 2: "T2", 3: "T3", 4: "T4", 5: "T5", 6: "T6", 7: "T7"
        ]
        return repeatDays.compactMap { dayNames[$0] }.joined(separator: ", ")
    }
}

// MARK: - 4. Lệnh Trạm Sạc Thông Minh (Station Action)
public enum StationActionType: Int, CaseIterable {
    case emptyDustbin = 1   // Tự động gom rác
    case startMopWash = 2   // Bắt đầu giặt giẻ
    case stopMopWash = -2   // Dừng giặt giẻ
    case startAirDrying = 3 // Bắt đầu sấy khô giẻ khí nóng
    case stopAirDrying = -3 // Dừng sấy khô giẻ
    
    public var title: String {
        switch self {
        case .emptyDustbin: return "Gom rác tự động"
        case .startMopWash: return "Giặt giẻ lau"
        case .stopMopWash: return "Dừng giặt giẻ"
        case .startAirDrying: return "Sấy khô giẻ"
        case .stopAirDrying: return "Dừng sấy khô"
        }
    }
    
    public var icon: String {
        switch self {
        case .emptyDustbin: return "trash.fill"
        case .startMopWash: return "drop.triangle.fill"
        case .stopMopWash: return "drop.triangle"
        case .startAirDrying: return "wind"
        case .stopAirDrying: return "wind"
        }
    }
}
