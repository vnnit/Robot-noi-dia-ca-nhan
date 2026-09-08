import Foundation

public final class EcovacsDeviceService {
    public static let shared = EcovacsDeviceService()
    
    private let session: URLSession
    private let authService = EcovacsAuthService.shared
    private let keychain = KeychainManager.shared
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15.0
        config.timeoutIntervalForResource = 25.0
        self.session = URLSession(configuration: config)
    }
    
    private let cacheKey = "cached_devices_list_v1"
    
    // MARK: - Quản lý Cache Cục bộ (Tải tức thì 0ms)
    public func getCachedDevices() -> [DeviceModel] {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let list = try? JSONDecoder().decode([DeviceModel].self, from: data) else {
            return []
        }
        return list
    }
    
    public func saveCachedDevices(_ devices: [DeviceModel]) {
        guard !devices.isEmpty else { return }
        if let data = try? JSONEncoder().encode(devices) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }
    
    private let rawJsonCacheKey = "cached_raw_devices_json"
    
    public func getCachedRawDevicesJson() -> String {
        return UserDefaults.standard.string(forKey: rawJsonCacheKey) ?? "[]"
    }
    
    public func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: rawJsonCacheKey)
    }
    
    // MARK: - 1. Lấy danh sách Robot từ Ecovacs Cloud
    public func fetchDevices(forceRefreshAuth: Bool = false) async throws -> [DeviceModel] {
        var creds = forceRefreshAuth ? (try await authService.forceRefreshToken()) : (try await authService.ensureValidToken())
        let portalUrl = Constants.portalUrl(for: keychain.country)
        guard let url = URL(string: portalUrl + "/api/users/user.do") else {
            throw NSError(domain: "EcovacsDevice", code: -1, userInfo: [NSLocalizedDescriptionKey: "Sai URL kết nối Ecovacs"])
        }
        
        var devicesRaw: [[String: Any]]? = nil
        var lastErrorMessage: String? = nil
        
        // Thử tối đa 2 lần (lần 2 tự động làm mới Token nếu gặp lỗi 1004 / auth error)
        for attempt in 0..<2 {
            let body: [String: Any] = [
                "userid": creds.userId,
                "todo": "GetDeviceList",
                "auth": [
                    "with": "users",
                    "userid": creds.userId,
                    "realm": Constants.realm,
                    "token": creds.token,
                    "resource": creds.deviceId
                ]
            ]
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            do {
                let (data, _) = try await session.data(for: request)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let result = json["result"] as? String ?? ""
                    let errno = json["errno"] as? Int ?? 0
                    let errorStr = json["error"] as? String ?? ""
                    
                    // Nếu gặp lỗi xác thực hoặc hết hạn token (errno 1004 / auth error / result fail)
                    if errno == 1004 || result == "fail" || errorStr.lowercased().contains("auth") {
                        print("[EcovacsDeviceService] Phiên đăng nhập hết hạn (errno: \(errno), error: \(errorStr)). Đang tự động cấp mới Token...")
                        if attempt == 0 {
                            creds = try await authService.forceRefreshToken()
                            continue
                        } else {
                            lastErrorMessage = "Phiên đăng nhập đã hết hạn hoặc không hợp lệ. Vui lòng thử lại hoặc đăng nhập lại."
                            break
                        }
                    }
                    
                    if let devs = json["devices"] as? [[String: Any]] {
                        devicesRaw = devs
                        break
                    }
                }
            } catch {
                print("[EcovacsDeviceService] Lỗi kết nối mạng: \(error.localizedDescription)")
                if attempt == 0 {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    continue
                }
                lastErrorMessage = "Lỗi kết nối mạng: \(error.localizedDescription)"
            }
        }
        
        guard let validDevicesRaw = devicesRaw else {
            let cached = getCachedDevices()
            if !cached.isEmpty {
                return cached
            }
            if let msg = lastErrorMessage {
                throw NSError(domain: "EcovacsDevice", code: -1, userInfo: [NSLocalizedDescriptionKey: msg])
            }
            throw NSError(domain: "EcovacsDevice", code: -1, userInfo: [NSLocalizedDescriptionKey: "Không nhận được danh sách thiết bị từ máy chủ Ecovacs."])
        }
        
        // Lưu lại chuỗi JSON gốc để xem debug
        if let rawData = try? JSONSerialization.data(withJSONObject: validDevicesRaw, options: .prettyPrinted),
           let rawStr = String(data: rawData, encoding: .utf8) {
            UserDefaults.standard.set(rawStr, forKey: rawJsonCacheKey)
        }
        
        var list: [DeviceModel] = []
        let existingCache = getCachedDevices()
        
        for d in validDevicesRaw {
            guard let did = d["did"] as? String, !did.isEmpty else { continue }
            let name = (d["deviceName"] as? String) ?? (d["name"] as? String) ?? "DEEBOT"
            let nick = (d["nick"] as? String)
            let model = (d["model"] as? String) ?? (d["product_category"] as? String) ?? "DEEBOT"
            let devClass = (d["class"] as? String) ?? "yna5xi"
            let company = (d["company"] as? String) ?? "eco-ng"
            let status = (d["status"] as? Int) ?? 1
            let icon = d["icon"] as? String
            let fwVer = (d["version"] as? String) ?? "v1.9.7"
            let res = (d["resource"] as? String) ?? "pwMl"
            
            // Giữ lại trạng thái pin/hoạt động đã lưu trong cache trước đó
            let cachedDev = existingCache.first(where: { $0.did == did })
            
            let modelObj = DeviceModel(
                did: did,
                name: name,
                nick: nick,
                model: model,
                deviceClass: devClass,
                company: company,
                status: status,
                icon: icon,
                fwVer: fwVer,
                resource: res,
                battery: cachedDev?.battery,
                isCharging: cachedDev?.isCharging,
                cleanState: cachedDev?.cleanState,
                cleanStateText: cachedDev?.cleanStateText
            )
            list.append(modelObj)
        }
        
        if !list.isEmpty {
            saveCachedDevices(list)
        }
        return list
    }
    
    // MARK: - 2. Gửi lệnh chung (Direct CloudCtl REST)
    public func executeCommand(
        device: DeviceModel,
        cmdName: String,
        payloadArgs: [String: Any] = [:],
        payloadType: String = "j"
    ) async throws -> [String: Any] {
        let creds = try await authService.ensureValidToken()
        
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "mid", value: device.deviceClass),
            URLQueryItem(name: "did", value: device.did),
            URLQueryItem(name: "td", value: "q"),
            URLQueryItem(name: "u", value: creds.userId),
            URLQueryItem(name: "cv", value: "1.67.3"),
            URLQueryItem(name: "t", value: "a"),
            URLQueryItem(name: "av", value: "1.3.1")
        ]
        
        let portalUrl = Constants.portalUrl(for: keychain.country)
        guard var comp = URLComponents(string: portalUrl + "/api/iot/devmanager.do") else {
            throw NSError(domain: "EcovacsDevice", code: -1, userInfo: [NSLocalizedDescriptionKey: "Sai URL devmanager"])
        }
        comp.queryItems = queryItems
        guard let url = comp.url else {
            throw NSError(domain: "EcovacsDevice", code: -1, userInfo: [NSLocalizedDescriptionKey: "Không thể tạo URL devmanager"])
        }
        
        var innerPayload: [String: Any] = [
            "header": [
                "pri": "1",
                "ts": Int(Date().timeIntervalSince1970),
                "tzm": 480,
                "ver": "0.0.50"
            ]
        ]
        if !payloadArgs.isEmpty {
            innerPayload["body"] = ["data": payloadArgs]
        }
        
        let body: [String: Any] = [
            "cmdName": cmdName,
            "payload": innerPayload,
            "payloadType": payloadType,
            "td": "q",
            "toId": device.did,
            "toRes": device.resource,
            "toType": device.deviceClass,
            "auth": [
                "with": "users",
                "userid": creds.userId,
                "realm": Constants.realm,
                "token": creds.token,
                "resource": creds.deviceId
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 3.5
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Eco-Iot-Direct", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await session.data(for: request)
        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        return json
    }
    
    // MARK: - Lấy nhanh pin và trạng thái dọn dẹp cho danh sách (siêu nhanh < 1s)
    public func getQuickStatus(device: DeviceModel) async -> (battery: Int?, isCharging: Bool?, cleanState: String?, cleanStateText: String?) {
        async let battRes = try? executeCommand(device: device, cmdName: "getBattery")
        async let cleanRes = try? executeCommand(device: device, cmdName: "getCleanInfo")
        
        let (batt, clean) = await (battRes, cleanRes)
        var battery: Int? = nil
        var isCharging: Bool? = nil
        var cleanState: String? = nil
        var cleanStateText: String? = nil
        
        if let b = batt, let body = extractBodyData(b) {
            if let val = body["value"] as? Int { battery = val }
        }
        if let cl = clean, let body = extractBodyData(cl) {
            if let st = body["state"] as? String {
                cleanState = st
                switch st {
                case "clean": cleanStateText = "Đang dọn dẹp"
                case "pause": cleanStateText = "Đang tạm dừng"
                case "stop": cleanStateText = "Đã dừng dọn"
                case "go_charging": cleanStateText = "Đang về trạm sạc"
                case "charging":
                    cleanStateText = "Đang sạc pin"
                    isCharging = true
                default:
                    cleanStateText = "Nghỉ ngơi / Chờ lệnh"
                }
            }
        }
        return (battery, isCharging, cleanState, cleanStateText)
    }
    
    // MARK: - 3. Lấy Trạng thái Thời gian thực Đầy đủ (Full Live State)
    public func getDeviceState(device: DeviceModel) async -> DeviceState {
        var state = DeviceState.initial
        
        async let battRes = try? executeCommand(device: device, cmdName: "getBattery")
        async let cleanRes = try? executeCommand(device: device, cmdName: "getCleanInfo")
        async let chargeRes = try? executeCommand(device: device, cmdName: "getChargeState")
        async let speedRes = try? executeCommand(device: device, cmdName: "getSpeed")
        async let waterRes = try? executeCommand(device: device, cmdName: "getWaterInfo")
        async let errRes = try? executeCommand(device: device, cmdName: "getError")
        
        let results = await (battRes, cleanRes, chargeRes, speedRes, waterRes, errRes)
        
        // Pin
        if let b = results.0, let body = extractBodyData(b) {
            if let val = body["value"] as? Int { state.batteryPercent = val }
            if let low = body["isLow"] as? Bool { state.isLowBattery = low }
        }
        
        // Sạc
        if let c = results.2, let body = extractBodyData(c) {
            if let ch = body["isCharging"] as? Bool { state.isCharging = ch }
            if let m = body["mode"] as? String { state.chargeMode = m }
            state.chargeText = state.isCharging ? "Đang sạc pin tại trạm" : "Đang sử dụng pin"
        }
        
        // Dọn dẹp
        if let cl = results.1, let body = extractBodyData(cl) {
            if let st = body["state"] as? String {
                state.cleanState = st
                switch st {
                case "clean": state.cleanStateText = "Đang dọn dẹp"
                case "pause": state.cleanStateText = "Đang tạm dừng"
                case "stop": state.cleanStateText = "Đã dừng dọn"
                case "go_charging": state.cleanStateText = "Đang về trạm sạc"
                case "charging": state.cleanStateText = "Đang sạc pin"
                case "error": state.cleanStateText = "Báo lỗi"
                default:
                    state.cleanStateText = state.isCharging ? "Đang sạc pin tại trạm" : "Nghỉ ngơi / Chờ lệnh"
                }
            }
            if let tr = body["trigger"] as? String { state.cleanTrigger = tr }
        }
        
        // Lực hút & Nước
        if let sp = results.3, let body = extractBodyData(sp) {
            if let s = body["speed"] as? String { state.fanSpeed = s }
        }
        if let wt = results.4, let body = extractBodyData(wt) {
            if let a = body["amount"] as? Int { state.waterAmount = a }
        }
        
        // Mã lỗi
        if let er = results.5, let body = extractBodyData(er) {
            if let code = body["code"] as? Int {
                state.errorCode = code
                state.errorText = Constants.errorDescriptions[code] ?? "Mã lỗi #\(code)"
            }
        }
        
        return state
    }
    
    // MARK: - 4. Các lệnh điều khiển dọn dẹp & sạc pin
    public func clean(device: DeviceModel, action: CleanAction) async throws {
        var args: [String: Any] = ["act": action.rawValue]
        if action == .start {
            args["type"] = "auto"
        }
        _ = try await executeCommand(device: device, cmdName: "clean", payloadArgs: args)
    }
    
    public func charge(device: DeviceModel) async throws {
        _ = try await executeCommand(device: device, cmdName: "charge", payloadArgs: ["act": "go"])
    }
    
    public func playSound(device: DeviceModel) async throws {
        _ = try await executeCommand(device: device, cmdName: "playSound", payloadArgs: [:])
    }
    
    public func relocate(device: DeviceModel) async throws {
        _ = try await executeCommand(device: device, cmdName: "setRelocationState", payloadArgs: [:])
    }
    
    // MARK: - 5. Cài đặt lực hút, nước, âm lượng, khóa trẻ em
    public func setFanSpeed(device: DeviceModel, speed: FanSpeedLevel) async throws {
        _ = try await executeCommand(device: device, cmdName: "setSpeed", payloadArgs: ["speed": speed.rawValue])
    }
    
    public func setWaterInfo(device: DeviceModel, amount: Int) async throws {
        _ = try await executeCommand(device: device, cmdName: "setWaterInfo", payloadArgs: ["amount": amount])
    }
    
    public func setVolume(device: DeviceModel, volume: Int) async throws {
        _ = try await executeCommand(device: device, cmdName: "setVolume", payloadArgs: ["volume": volume])
    }
    
    public func setChildLock(device: DeviceModel, enabled: Bool) async throws {
        _ = try await executeCommand(device: device, cmdName: "setChildLock", payloadArgs: ["enable": enabled ? 1 : 0])
    }
    
    public func setCarpetBoost(device: DeviceModel, enabled: Bool) async throws {
        _ = try await executeCommand(device: device, cmdName: "setCarpetAutoFanBoost", payloadArgs: ["enable": enabled ? 1 : 0])
    }
    
    // MARK: - 6. Quản lý phụ kiện & Reset tuổi thọ
    public func getConsumables(device: DeviceModel) async -> ConsumablesData {
        var data = ConsumablesData.default
        let types: [(ConsumableType, String, Double)] = [
            (.brush, "brush", 300.0),
            (.sideBrush, "sideBrush", 150.0),
            (.heap, "heap", 150.0),
            (.unitCare, "unitCare", 30.0)
        ]
        
        for (t, typeStr, defaultMaxHours) in types {
            if let res = try? await executeCommand(device: device, cmdName: "getLifeSpan", payloadArgs: ["type": typeStr]),
               let body = extractBodyData(res),
               let leftMins = body["left"] as? Double {
                let totalMins = (body["total"] as? Double) ?? (defaultMaxHours * 60.0)
                let pct = totalMins > 0 ? max(0, min(100, Int((leftMins / totalMins) * 100))) : 100
                let leftHours = round((leftMins / 60.0) * 10) / 10
                let totalHours = round((totalMins / 60.0) * 10) / 10
                let item = ConsumableItem(type: t, leftHours: leftHours, totalHours: totalHours, percent: pct, status: pct > 15 ? "Tốt" : "Cần thay thế")
                switch t {
                case .brush: data.brush = item
                case .sideBrush: data.sideBrush = item
                case .heap: data.heap = item
                case .unitCare: data.unitCare = item
                }
            }
        }
        return data
    }
    
    public func resetConsumable(device: DeviceModel, component: ConsumableType) async throws {
        _ = try await executeCommand(device: device, cmdName: "resetLifeSpan", payloadArgs: ["type": component.rawValue])
    }
    
    // MARK: - 7. Lấy Bản đồ LiDAR SVG
    public func getSvgMap(device: DeviceModel) async -> String? {
        // Gửi lệnh getMap / pullMap
        let res = try? await executeCommand(device: device, cmdName: "getMap", payloadArgs: [:])
        if let res = res, let body = extractBodyData(res), let svg = body["svg"] as? String, !svg.isEmpty {
            return svg
        }
        return nil
    }
    
    // MARK: - Helper
    private func extractBodyData(_ json: [String: Any]) -> [String: Any]? {
        if let resp = json["resp"] as? [String: Any], let body = resp["body"] as? [String: Any], let data = body["data"] as? [String: Any] {
            return data
        }
        if let body = json["body"] as? [String: Any], let data = body["data"] as? [String: Any] {
            return data
        }
        if let data = json["data"] as? [String: Any] {
            return data
        }
        return nil
    }
}
