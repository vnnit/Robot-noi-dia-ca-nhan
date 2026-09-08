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
    
    public var displayName: String {
        if let custom = customNick, !custom.trimmingCharacters(in: .whitespaces).isEmpty {
            return custom.trimmingCharacters(in: .whitespaces)
        }
        if let nick = nick, !nick.trimmingCharacters(in: .whitespaces).isEmpty {
            return nick.trimmingCharacters(in: .whitespaces)
        }
        if !name.trimmingCharacters(in: .whitespaces).isEmpty {
            return name.trimmingCharacters(in: .whitespaces)
        }
        return Constants.modelFriendlyNames[deviceClass] ?? Constants.modelFriendlyNames[model] ?? "DEEBOT"
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
        Constants.modelFriendlyNames[deviceClass] ?? Constants.modelFriendlyNames[model] ?? model
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
