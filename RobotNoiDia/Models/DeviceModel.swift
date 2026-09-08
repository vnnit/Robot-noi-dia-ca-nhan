import Foundation

/// Đại diện cho một robot Ecovacs trong tài khoản
public struct DeviceModel: Identifiable, Codable, Hashable {
    public var id: String { did }
    
    public let did: String
    public var name: String
    public var nick: String?
    public let model: String
    public let deviceClass: String
    public let company: String
    public var status: Int
    public var icon: String?
    public var fwVer: String?
    public var resource: String
    
    // Cached dynamic indicators
    public var battery: Int?
    public var isCharging: Bool?
    public var cleanState: String?
    public var cleanStateText: String?
    
    public var customNick: String? {
        UserDefaults.standard.string(forKey: "custom_robot_name_\(did)")
    }
    
    private var isLikelySerialCode: Bool {
        let cleaned = name.trimmingCharacters(in: .whitespaces)
        if cleaned.count >= 8 && cleaned.range(of: "^[A-Z0-9_-]+$", options: .regularExpression) != nil {
            return true
        }
        return false
    }
    
    public var displayName: String {
        if let custom = customNick, !custom.trimmingCharacters(in: .whitespaces).isEmpty {
            return custom.trimmingCharacters(in: .whitespaces)
        }
        if let nick = nick, !nick.trimmingCharacters(in: .whitespaces).isEmpty, nick != name {
            return nick.trimmingCharacters(in: .whitespaces)
        }
        // Nếu tên không phải là mã serial thô (như E0BA14837C09HM0H0516), thì mới hiển thị tên
        if !name.trimmingCharacters(in: .whitespaces).isEmpty && !isLikelySerialCode {
            return name.trimmingCharacters(in: .whitespaces)
        }
        return friendlyModelName
    }
    
    public func saveCustomName(_ newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: "custom_robot_name_\(did)")
        } else {
            UserDefaults.standard.set(trimmed, forKey: "custom_robot_name_\(did)")
        }
    }
    
    public var friendlyModelName: String {
        if let friendly = Constants.modelFriendlyNames[deviceClass] { return friendly }
        if let friendly = Constants.modelFriendlyNames[model] { return friendly }
        let combined = (model + " " + deviceClass).lowercased()
        if combined.contains("t10") { return "DEEBOT T10 TURBO" }
        if combined.contains("t9") { return "DEEBOT T9 AIVI" }
        if combined.contains("t8") { return "DEEBOT T8 AIVI" }
        if combined.contains("x1") { return "DEEBOT X1 OMNI" }
        if combined.contains("t20") { return "DEEBOT T20 PRO" }
        if combined.contains("t30") { return "DEEBOT T30 PRO" }
        if !model.isEmpty && model != "DEEBOT" { return "DEEBOT \(model)" }
        return "DEEBOT"
    }
    
    public var debugJsonFormatted: String {
        let dict: [String: Any] = [
            "did": did,
            "name": name,
            "nick": nick ?? "",
            "model": model,
            "deviceClass": deviceClass,
            "company": company,
            "status": status,
            "fwVer": fwVer ?? "",
            "resource": resource,
            "battery": battery ?? 0,
            "isCharging": isCharging ?? false,
            "cleanState": cleanState ?? "",
            "cleanStateText": cleanStateText ?? "",
            "displayName": displayName,
            "friendlyModelName": friendlyModelName,
            "hasCamera": hasCamera,
            "has3DMap": has3DMap,
            "hasYiko": hasYiko,
            "hasOmniStation": hasOmniStation,
            "hasEdgeDeepCleaning": hasEdgeDeepCleaning
        ]
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }
    
    public var isOnline: Bool {
        status == 1
    }
    
    public var isCleaning: Bool {
        cleanState == "clean"
    }
    
    // Dynamic Model Capabilities (Tự động nhận diện tính năng theo từng dòng robot)
    public var hasCamera: Bool {
        let text = (friendlyModelName + " " + model + " " + deviceClass).uppercased()
        return text.contains("AIVI") || text.contains("T10") || text.contains("X1") || text.contains("X2") || text.contains("T20") || text.contains("T30")
    }
    
    public var has3DMap: Bool {
        let text = (friendlyModelName + " " + model + " " + deviceClass).uppercased()
        return text.contains("T9") || text.contains("T10") || text.contains("X1") || text.contains("X2") || text.contains("T20") || text.contains("T30")
    }
    
    public var hasYiko: Bool {
        let text = (friendlyModelName + " " + model + " " + deviceClass).uppercased()
        return text.contains("T10") || text.contains("X1") || text.contains("X2") || text.contains("T20") || text.contains("T30")
    }
    
    public var hasOmniStation: Bool {
        let text = (friendlyModelName + " " + model + " " + deviceClass).uppercased()
        return text.contains("TURBO") || text.contains("OMNI") || text.contains("PRO") || text.contains("PLUS")
    }
    
    public var hasEdgeDeepCleaning: Bool {
        let text = (friendlyModelName + " " + model + " " + deviceClass).uppercased()
        return text.contains("T10") || text.contains("T20") || text.contains("T30") || text.contains("X1") || text.contains("X2")
    }
    
    public var isDarkModel: Bool {
        let text = (friendlyModelName + " " + model + " " + deviceClass).uppercased()
        if text.contains("T9") || text.contains("T8") || text.contains("8KWDB4") || text.contains("YNA5XI") || text.contains("BLACK") || (text.contains("AIVI") && !text.contains("T10")) {
            return true
        }
        return false
    }
    
    public init(
        did: String,
        name: String,
        nick: String? = nil,
        model: String,
        deviceClass: String,
        company: String = "eco-ng",
        status: Int = 1,
        icon: String? = nil,
        fwVer: String? = nil,
        resource: String = "pwMl",
        battery: Int? = nil,
        isCharging: Bool? = nil,
        cleanState: String? = nil,
        cleanStateText: String? = nil
    ) {
        self.did = did
        self.name = name
        self.nick = nick
        self.model = model
        self.deviceClass = deviceClass
        self.company = company
        self.status = status
        self.icon = icon
        self.fwVer = fwVer
        self.resource = resource
        self.battery = battery
        self.isCharging = isCharging
        self.cleanState = cleanState
        self.cleanStateText = cleanStateText
    }
}

// MARK: - Cleaning Stats & Logs Models
public struct CleaningStatsModel: Codable, Hashable {
    public let totalArea: Int
    public let totalTimeMin: Int
    public let totalCount: Int
    
    public init(totalArea: Int, totalTimeMin: Int, totalCount: Int) {
        self.totalArea = totalArea
        self.totalTimeMin = totalTimeMin
        self.totalCount = totalCount
    }
    
    public var totalHoursText: String {
        let hours = Double(totalTimeMin) / 60.0
        return String(format: "%.1f", hours)
    }
    
    public var formattedArea: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: totalArea)) ?? "\(totalArea)"
    }
}

public struct CleaningLogItem: Identifiable, Codable, Hashable {
    public var id: String { "\(time)_\(area)_\(duration)" }
    public let time: String
    public let robot: String
    public let area: Int
    public let duration: Int
    public let result: String
    
    public init(time: String, robot: String, area: Int, duration: Int, result: String) {
        self.time = time
        self.robot = robot
        self.area = area
        self.duration = duration
        self.result = result
    }
}
