import Foundation

public enum ConsumableType: String, Codable, CaseIterable, Identifiable {
    case brush = "brush"
    case sideBrush = "sideBrush"
    case heap = "heap"
    case unitCare = "unitCare"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .brush: return "Chổi chính (Main Brush)"
        case .sideBrush: return "Chổi ven (Side Brush)"
        case .heap: return "Màng lọc bụi HEPA"
        case .unitCare: return "Cảm biến chống rơi (Unit Care)"
        }
    }
    
    public var systemIcon: String {
        switch self {
        case .brush: return "cylinder.split.1x2"
        case .sideBrush: return "fanblades"
        case .heap: return "square.grid.3x3.topleft.filled"
        case .unitCare: return "sensor.tag.radiowaves.forward"
        }
    }
    
    public var defaultTotalHours: Double {
        switch self {
        case .brush: return 300.0
        case .sideBrush: return 150.0
        case .heap: return 150.0
        case .unitCare: return 30.0
        }
    }
}

public struct ConsumableItem: Codable, Identifiable {
    public var id: String { type.rawValue }
    public let type: ConsumableType
    public var leftHours: Double
    public var totalHours: Double
    public var percent: Int
    public var status: String
    
    public var isWarning: Bool {
        percent <= 15
    }
}

public struct ConsumablesData: Codable {
    public var brush: ConsumableItem
    public var sideBrush: ConsumableItem
    public var heap: ConsumableItem
    public var unitCare: ConsumableItem
    
    public var allItems: [ConsumableItem] {
        [brush, sideBrush, heap, unitCare]
    }
    
    public static var `default`: ConsumablesData {
        ConsumablesData(
            brush: ConsumableItem(type: .brush, leftHours: 255.0, totalHours: 300.0, percent: 85, status: "Tốt"),
            sideBrush: ConsumableItem(type: .sideBrush, leftHours: 127.5, totalHours: 150.0, percent: 85, status: "Tốt"),
            heap: ConsumableItem(type: .heap, leftHours: 127.5, totalHours: 150.0, percent: 85, status: "Tốt"),
            unitCare: ConsumableItem(type: .unitCare, leftHours: 25.5, totalHours: 30.0, percent: 85, status: "Tốt")
        )
    }
}
