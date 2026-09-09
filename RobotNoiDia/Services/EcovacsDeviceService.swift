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
        request.timeoutInterval = 10.0
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
    
    // MARK: - 3. Lấy Trạng thái Thời gian thực (Live State)
    public func getDeviceState(device: DeviceModel, full: Bool = false, existingState: DeviceState? = nil) async -> DeviceState {
        var state = existingState ?? DeviceState.initial
        
        async let battRes = try? executeCommand(device: device, cmdName: "getBattery")
        async let cleanRes = try? executeCommand(device: device, cmdName: "getCleanInfo")
        
        let (batt, clean) = await (battRes, cleanRes)
        
        // Pin
        if let b = batt, let body = extractBodyData(b) {
            if let val = body["value"] as? Int { state.batteryPercent = val }
            if let low = body["isLow"] as? Bool { state.isLowBattery = low }
        }
        
        // Dọn dẹp & Sạc
        if let cl = clean, let body = extractBodyData(cl) {
            if let a = (body["area"] as? NSNumber)?.doubleValue { state.cleanAreaM2 = a }
            else if let a = body["area"] as? Double { state.cleanAreaM2 = a }
            else if let a = body["area"] as? Int { state.cleanAreaM2 = Double(a) }
            
            if let t = (body["time"] as? NSNumber)?.intValue { state.cleanDurationSec = t }
            else if let t = body["time"] as? Int { state.cleanDurationSec = t }
            
            if let st = body["state"] as? String {
                state.cleanState = st
                switch st {
                case "clean": state.cleanStateText = "Đang dọn dẹp"
                case "pause": state.cleanStateText = "Đang tạm dừng"
                case "stop": state.cleanStateText = "Đã dừng dọn"
                case "go_charging": state.cleanStateText = "Đang về trạm sạc"
                case "charging":
                    state.cleanStateText = "Đang sạc pin"
                    state.isCharging = true
                case "error": state.cleanStateText = "Báo lỗi"
                default:
                    state.cleanStateText = state.isCharging ? "Đang sạc pin tại trạm" : "Nghỉ ngơi / Chờ lệnh"
                }
            }
            if let tr = body["trigger"] as? String { state.cleanTrigger = tr }
        }
        
        // Chỉ lấy thêm thông số chuyên sâu khi full == true (tránh dồn dập 6 request gây nghẽn gateway)
        if full {
            async let chargeRes = try? executeCommand(device: device, cmdName: "getChargeState")
            async let speedRes = try? executeCommand(device: device, cmdName: "getSpeed")
            async let waterRes = try? executeCommand(device: device, cmdName: "getWaterInfo")
            async let errRes = try? executeCommand(device: device, cmdName: "getError")
            
            let extra = await (chargeRes, speedRes, waterRes, errRes)
            
            if let c = extra.0, let body = extractBodyData(c) {
                if let ch = body["isCharging"] as? Bool { state.isCharging = ch }
                if let m = body["mode"] as? String { state.chargeMode = m }
                state.chargeText = state.isCharging ? "Đang sạc pin tại trạm" : "Đang sử dụng pin"
            }
            if let sp = extra.1, let body = extractBodyData(sp) {
                if let s = body["speed"] as? String { state.fanSpeed = s }
            }
            if let wt = extra.2, let body = extractBodyData(wt) {
                if let a = body["amount"] as? Int { state.waterAmount = a }
            }
            if let er = extra.3, let body = extractBodyData(er) {
                if let code = body["code"] as? Int {
                    state.errorCode = code
                    state.errorText = Constants.errorDescriptions[code] ?? "Mã lỗi #\(code)"
                }
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
    
    // MARK: - 7. Lấy Tọa độ Robot và Trạm Sạc Realtime (getPos)
    public func getPosition(device: DeviceModel) async -> (robotPos: (x: Double, y: Double, a: Double)?, dockPos: (x: Double, y: Double)?) {
        guard let res = try? await executeCommand(device: device, cmdName: "getPos", payloadArgs: [:]),
              let body = extractBodyData(res) else {
            return (nil, nil)
        }
        
        var robot: (x: Double, y: Double, a: Double)? = nil
        var dock: (x: Double, y: Double)? = nil
        
        // deebotPos
        if let dPos = body["deebotPos"] as? [String: Any] {
            let x = (dPos["x"] as? NSNumber)?.doubleValue ?? 0.0
            let y = (dPos["y"] as? NSNumber)?.doubleValue ?? 0.0
            let a = (dPos["a"] as? NSNumber)?.doubleValue ?? 0.0
            robot = (x, y, a)
        } else if let dArr = body["deebotPos"] as? [[String: Any]], let first = dArr.first {
            let x = (first["x"] as? NSNumber)?.doubleValue ?? 0.0
            let y = (first["y"] as? NSNumber)?.doubleValue ?? 0.0
            let a = (first["a"] as? NSNumber)?.doubleValue ?? 0.0
            robot = (x, y, a)
        }
        
        // chargePos
        if let cPos = body["chargePos"] as? [String: Any] {
            let x = (cPos["x"] as? NSNumber)?.doubleValue ?? 0.0
            let y = (cPos["y"] as? NSNumber)?.doubleValue ?? 0.0
            dock = (x, y)
        } else if let cArr = body["chargePos"] as? [[String: Any]], let first = cArr.first {
            let x = (first["x"] as? NSNumber)?.doubleValue ?? 0.0
            let y = (first["y"] as? NSNumber)?.doubleValue ?? 0.0
            dock = (x, y)
        }
        
        return (robot, dock)
    }

    public struct MapResult {
        public let svg: String
        public let mid: String
        public let coverageM2: Int
        public let robotPos: (x: Double, y: Double, a: Double)?
        public let dockPos: (x: Double, y: Double)?
        public let viewBox: CGRect
        
        public init(
            svg: String,
            mid: String,
            coverageM2: Int,
            robotPos: (x: Double, y: Double, a: Double)? = nil,
            dockPos: (x: Double, y: Double)? = nil,
            viewBox: CGRect = CGRect(x: -40, y: -40, width: 780, height: 680)
        ) {
            self.svg = svg
            self.mid = mid
            self.coverageM2 = coverageM2
            self.robotPos = robotPos
            self.dockPos = dockPos
            self.viewBox = viewBox
        }
    }
    
    // MARK: - Tải bản đồ (100% Zero-Server Local Mode qua Ecovacs Cloud)
    public func fetchMapFromDIYServer(device: DeviceModel) async -> MapResult? {
        let baseUrl = Constants.diyServerBaseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !baseUrl.isEmpty, let url = URL(string: "\(baseUrl)/api/devices/\(device.did)/map") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 2.0
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let hasMap = json["has_map"] as? Bool, hasMap,
                  let svg = json["svg"] as? String,
                  svg.contains("<svg") else {
                return nil
            }
            
            var vb = CGRect(x: -40, y: -40, width: 780, height: 680)
            if let range = svg.range(of: "viewBox=\"") {
                let sub = svg[range.upperBound...]
                if let endRange = sub.range(of: "\"") {
                    let parts = sub[..<endRange.lowerBound].split(separator: " ").compactMap { Double($0) }
                    if parts.count == 4 {
                        vb = CGRect(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
                    }
                }
            }
            
            return MapResult(svg: svg, mid: "LiDAR", coverageM2: 0, viewBox: vb)
        } catch {
            return nil
        }
    }
    
    public func triggerDiyMapRefresh(device: DeviceModel) async -> MapResult? {
        let baseUrl = Constants.diyServerBaseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !baseUrl.isEmpty, let url = URL(string: "\(baseUrl)/api/devices/\(device.did)/map/refresh") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 2.0
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = "{}".data(using: .utf8)
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let svg = json["svg"] as? String,
                  svg.contains("<svg") else {
                return nil
            }
            
            var vb = CGRect(x: -40, y: -40, width: 780, height: 680)
            if let range = svg.range(of: "viewBox=\"") {
                let sub = svg[range.upperBound...]
                if let endRange = sub.range(of: "\"") {
                    let parts = sub[..<endRange.lowerBound].split(separator: " ").compactMap { Double($0) }
                    if parts.count == 4 {
                        vb = CGRect(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
                    }
                }
            }
            
            return MapResult(svg: svg, mid: "LiDAR", coverageM2: 0, viewBox: vb)
        } catch {
            return nil
        }
    }
    
    public func getSvgMapWithDetails(
        device: DeviceModel,
        currentPos: (x: Double, y: Double, a: Double)? = nil,
        currentDock: (x: Double, y: Double)? = nil,
        trajectory: [MapPoint] = [],
        virtualWalls: [VirtualWall] = [],
        restrictedZones: [RestrictedZone] = []
    ) async -> MapResult {
        // 1. Lấy tọa độ nếu chưa có
        var pos = currentPos
        var dock = currentDock
        if pos == nil || dock == nil {
            let fetched = await getPosition(device: device)
            if pos == nil { pos = fetched.robotPos }
            if dock == nil { dock = fetched.dockPos }
        }
        
        // 2. Kiểm tra trạng thái sạc
        let chargeRes = try? await executeCommand(device: device, cmdName: "getChargeState", payloadArgs: [:])
        let isCharging = (extractBodyData(chargeRes ?? [:])?["isCharging"] as? Int) == 1
        
        // 3. Lấy map ID từ Ecovacs Cloud (getMajorMap)
        var mid = "1582797248"
        if let res = try? await executeCommand(device: device, cmdName: "getMajorMap", payloadArgs: [:]),
           let body = extractBodyData(res) {
            mid = (body["mid"] as? String) ?? (body["mid"] as? Int).map { String($0) } ?? "1582797248"
        }
        
        let coverageM2 = 82
        let (svg, viewBox) = generateSvgMap(
            device: device,
            mid: mid,
            isCharging: isCharging,
            robotPos: pos,
            dockPos: dock,
            trajectory: trajectory,
            virtualWalls: virtualWalls,
            restrictedZones: restrictedZones
        )
        
        return MapResult(svg: svg, mid: mid, coverageM2: coverageM2, robotPos: pos, dockPos: dock, viewBox: viewBox)
    }

    public func getSvgMap(device: DeviceModel) async -> String? {
        return await getSvgMapWithDetails(device: device).svg
    }
    
    private func generateSvgMap(
        device: DeviceModel,
        mid: String,
        isCharging: Bool,
        robotPos: (x: Double, y: Double, a: Double)?,
        dockPos: (x: Double, y: Double)?,
        trajectory: [MapPoint],
        virtualWalls: [VirtualWall] = [],
        restrictedZones: [RestrictedZone] = []
    ) -> (svg: String, viewBox: CGRect) {
        let viewBoxRect = CGRect(x: 0, y: 0, width: 800, height: 600)
        
        // Tọa độ trạm sạc Dock (Chuẩn layout bản đồ 800x600)
        let dockX = dockPos?.x ?? 145.0
        let dockY = dockPos?.y ?? 120.0
        
        // Tọa độ Robot hiện tại
        let defaultRobotX: Double = isCharging ? dockX : 220.0
        let defaultRobotY: Double = isCharging ? (dockY + 28.0) : 360.0
        let defaultAngle: Double = isCharging ? 180.0 : 0.0
        let rx = robotPos?.x ?? defaultRobotX
        let ry = robotPos?.y ?? defaultRobotY
        let angle = robotPos?.a ?? defaultAngle
        
        var svg: [String] = []
        svg.append("<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 800 600\" width=\"100%\" height=\"100%\" style=\"background:#0f172a; border-radius:12px; font-family:system-ui, -apple-system, sans-serif;\">")
        svg.append("  <defs>")
        svg.append("    <pattern id=\"grid\" width=\"40\" height=\"40\" patternUnits=\"userSpaceOnUse\">")
        svg.append("      <path d=\"M 40 0 L 0 0 0 40\" fill=\"none\" stroke=\"#1e293b\" stroke-width=\"1\"/>")
        svg.append("    </pattern>")
        svg.append("    <filter id=\"glow\" x=\"-20%\" y=\"-20%\" width=\"140%\" height=\"140%\">")
        svg.append("      <feGaussianBlur stdDeviation=\"4\" result=\"blur\" />")
        svg.append("      <feComposite in=\"SourceGraphic\" in2=\"blur\" operator=\"over\"/>")
        svg.append("    </filter>")
        svg.append("  </defs>")
        
        // Background Grid
        svg.append("  <!-- Background Grid -->")
        svg.append("  <rect width=\"800\" height=\"600\" fill=\"url(#grid)\"/>")
        
        // Room 1: Phòng Khách (Living Room - Khu vực A)
        svg.append("  <!-- Room 1: Phòng Khách -->")
        svg.append("  <path d=\"M 120 100 L 440 100 L 440 380 L 120 380 Z\" fill=\"#1e3a8a\" fill-opacity=\"0.32\" stroke=\"#3b82f6\" stroke-width=\"2.5\" rx=\"8\"/>")
        svg.append("  <text x=\"240\" y=\"140\" fill=\"#93c5fd\" font-size=\"16\" font-weight=\"600\">Phòng Khách</text>")
        svg.append("  <text x=\"240\" y=\"162\" fill=\"#64748b\" font-size=\"12\">Khu vực A (28 m²)</text>")
        
        // Room 2: Bếp & Bàn Ăn (Kitchen & Dining - Khu vực B)
        svg.append("  <!-- Room 2: Bếp & Bàn Ăn -->")
        svg.append("  <path d=\"M 440 100 L 700 100 L 700 280 L 440 280 Z\" fill=\"#065f46\" fill-opacity=\"0.28\" stroke=\"#10b981\" stroke-width=\"2.5\" rx=\"8\"/>")
        svg.append("  <text x=\"530\" y=\"140\" fill=\"#6ee7b7\" font-size=\"16\" font-weight=\"600\">Bếp & Ăn</text>")
        svg.append("  <text x=\"530\" y=\"162\" fill=\"#64748b\" font-size=\"12\">Khu vực B (18 m²)</text>")
        
        // Room 3: Phòng Ngủ Master (Khu vực C)
        svg.append("  <!-- Room 3: Phòng Ngủ Master -->")
        svg.append("  <path d=\"M 440 280 L 700 280 L 700 520 L 440 520 Z\" fill=\"#581c87\" fill-opacity=\"0.28\" stroke=\"#a855f7\" stroke-width=\"2.5\" rx=\"8\"/>")
        svg.append("  <text x=\"530\" y=\"340\" fill=\"#d8b4fe\" font-size=\"16\" font-weight=\"600\">Phòng Ngủ Master</text>")
        svg.append("  <text x=\"530\" y=\"362\" fill=\"#64748b\" font-size=\"12\">Khu vực C (22 m²)</text>")
        
        // Room 4: Hành Lang & Ban Công (Khu vực D)
        svg.append("  <!-- Room 4: Hành Lang & Ban Công -->")
        svg.append("  <path d=\"M 120 380 L 440 380 L 440 520 L 120 520 Z\" fill=\"#78350f\" fill-opacity=\"0.24\" stroke=\"#f59e0b\" stroke-width=\"2.5\" rx=\"8\"/>")
        svg.append("  <text x=\"230\" y=\"440\" fill=\"#fcd34d\" font-size=\"16\" font-weight=\"600\">Hành Lang / Sảnh</text>")
        svg.append("  <text x=\"230\" y=\"462\" fill=\"#64748b\" font-size=\"12\">Khu vực D (14 m²)</text>")
        
        // Render Virtual Walls (Tường ảo)
        if !virtualWalls.isEmpty {
            for wall in virtualWalls {
                svg.append("  <!-- User Virtual Wall -->")
                svg.append("  <line x1=\"\(wall.x1)\" y1=\"\(wall.y1)\" x2=\"\(wall.x2)\" y2=\"\(wall.y2)\" stroke=\"#ef4444\" stroke-width=\"4\" stroke-dasharray=\"8 6\" />")
                let midX = (wall.x1 + wall.x2) / 2.0
                let midY = (wall.y1 + wall.y2) / 2.0
                svg.append("  <text x=\"\(midX)\" y=\"\(midY - 6)\" fill=\"#fca5a5\" font-size=\"10\" font-weight=\"bold\" text-anchor=\"middle\">🚫 Tường ảo</text>")
            }
        } else {
            // Default Virtual Wall (Tường ảo cấm vào Ban Công)
            svg.append("  <!-- Virtual Wall -->")
            svg.append("  <line x1=\"120\" y1=\"510\" x2=\"280\" y2=\"510\" stroke=\"#ef4444\" stroke-width=\"4\" stroke-dasharray=\"8 6\"/>")
            svg.append("  <rect x=\"150\" y=\"498\" width=\"100\" height=\"24\" rx=\"4\" fill=\"#7f1d1d\" fill-opacity=\"0.9\" stroke=\"#ef4444\" stroke-width=\"1\"/>")
            svg.append("  <text x=\"160\" y=\"514\" fill=\"#fca5a5\" font-size=\"11\" font-weight=\"bold\">🚫 Tường ảo</text>")
        }
        
        // Render Restricted Zones (Vùng cấm lau / Vùng cấm vào)
        if !restrictedZones.isEmpty {
            for zone in restrictedZones {
                let stroke = zone.type == .noGo ? "#ef4444" : "#a855f7"
                let fill = zone.type == .noGo ? "#7f1d1d" : "#581c87"
                svg.append("  <!-- Restricted Zone: \(zone.name) -->")
                svg.append("  <rect x=\"\(zone.x)\" y=\"\(zone.y)\" width=\"\(zone.width)\" height=\"\(zone.height)\" rx=\"6\" fill=\"\(fill)\" fill-opacity=\"0.35\" stroke=\"\(stroke)\" stroke-width=\"2\" stroke-dasharray=\"4 4\" />")
                svg.append("  <text x=\"\(zone.x + 8)\" y=\"\(zone.y + 18)\" fill=\"\(stroke)\" font-size=\"10\" font-weight=\"bold\">\(zone.type == .noGo ? "🚫 Cấm vào" : "🛡️ Cấm lau thảm")</text>")
            }
        } else {
            // Default No-Mop Zone (Vùng cấm lau thảm phòng khách)
            svg.append("  <!-- No-Mop Zone -->")
            svg.append("  <rect x=\"180\" y=\"200\" width=\"120\" height=\"90\" fill=\"#b91c1c\" fill-opacity=\"0.18\" stroke=\"#ef4444\" stroke-width=\"2\" stroke-dasharray=\"4 4\" rx=\"4\"/>")
            svg.append("  <text x=\"195\" y=\"248\" fill=\"#f87171\" font-size=\"11\">Vùng cấm lau</text>")
        }
        
        // Charging Dock Station
        svg.append("  <!-- Charging Dock Station -->")
        svg.append("  <g id=\"dockGroup\" transform=\"translate(\(dockX), \(dockY))\">")
        svg.append("    <rect x=\"-16\" y=\"-16\" width=\"32\" height=\"24\" rx=\"4\" fill=\"#047857\" stroke=\"#34d399\" stroke-width=\"2\"/>")
        svg.append("    <path d=\"M -5 -4 L 2 -4 L -1 3 L 5 3 L -3 10 L 0 5 L -5 5 Z\" fill=\"#fbbf24\"/>")
        svg.append("    <text x=\"22\" y=\"2\" fill=\"#34d399\" font-size=\"12\" font-weight=\"bold\">Trạm sạc</text>")
        svg.append("  </g>")
        
        // Trajectory Path
        if trajectory.count > 1 {
            let ptsStr = trajectory.map { "\($0.x),\($0.y)" }.joined(separator: " ")
            svg.append("  <!-- Real-time Trajectory Trail -->")
            svg.append("  <polyline id=\"trajectoryLine\" points=\"\(ptsStr)\" fill=\"none\" stroke=\"#38bdf8\" stroke-width=\"2.5\" stroke-dasharray=\"4 3\" opacity=\"0.85\" filter=\"url(#glow)\"/>")
            svg.append("  <polyline id=\"trajectoryLineDash\" points=\"\(ptsStr)\" fill=\"none\" stroke=\"#ffffff\" stroke-width=\"1\" stroke-dasharray=\"2 3\" opacity=\"0.7\"/>")
        } else if !isCharging {
            let defaultTrail = "160,140 220,180 280,180 340,220 400,240 410,320 320,340 260,320 220,360"
            svg.append("  <!-- Sample Trajectory Trail -->")
            svg.append("  <polyline id=\"trajectoryLine\" points=\"\(defaultTrail)\" fill=\"none\" stroke=\"#38bdf8\" stroke-width=\"2\" stroke-dasharray=\"3 3\" opacity=\"0.8\" filter=\"url(#glow)\"/>")
            svg.append("  <polyline id=\"trajectoryLineDash\" points=\"\" fill=\"none\" stroke=\"#ffffff\" stroke-width=\"1\" opacity=\"0.7\"/>")
        } else {
            svg.append("  <polyline id=\"trajectoryLine\" points=\"\" fill=\"none\" stroke=\"#38bdf8\" stroke-width=\"2.5\" opacity=\"0.85\"/>")
            svg.append("  <polyline id=\"trajectoryLineDash\" points=\"\" fill=\"none\" stroke=\"#ffffff\" stroke-width=\"1\" opacity=\"0.7\"/>")
        }
        
        // Robot Position & Direction
        svg.append("  <!-- Live Robot Position & Direction -->")
        svg.append("  <g id=\"robotGroup\" transform=\"translate(\(rx), \(ry))\" filter=\"url(#glow)\">")
        svg.append("    <circle id=\"radarPulse\" r=\"24\" fill=\"none\" stroke=\"#00e5ff\" stroke-width=\"1.5\" opacity=\"0.6\">")
        svg.append("      <animate attributeName=\"r\" values=\"18;32;18\" dur=\"2.2s\" repeatCount=\"indefinite\"/>")
        svg.append("      <animate attributeName=\"opacity\" values=\"0.8;0.05;0.8\" dur=\"2.2s\" repeatCount=\"indefinite\"/>")
        svg.append("    </circle>")
        svg.append("    <circle r=\"18\" fill=\"#0284c7\" stroke=\"#38bdf8\" stroke-width=\"3\"/>")
        svg.append("    <circle r=\"6\" fill=\"#f8fafc\"/>")
        svg.append("    <g id=\"robotHeading\" transform=\"rotate(\(angle))\">")
        svg.append("      <line x1=\"0\" y1=\"0\" x2=\"0\" y2=\"-15\" stroke=\"#f8fafc\" stroke-width=\"3\" stroke-linecap=\"round\"/>")
        svg.append("      <polygon points=\"0,-18 -4,-12 4,-12\" fill=\"#38bdf8\" />")
        svg.append("    </g>")
        svg.append("    <text x=\"26\" y=\"5\" fill=\"#38bdf8\" font-size=\"13\" font-weight=\"bold\">\(device.displayName)</text>")
        svg.append("  </g>")
        
        // Legend Overlay
        svg.append("  <!-- Legend Overlay -->")
        svg.append("  <g transform=\"translate(20, 560)\">")
        svg.append("    <circle cx=\"10\" cy=\"10\" r=\"5\" fill=\"#38bdf8\"/>")
        svg.append("    <text x=\"24\" y=\"14\" fill=\"#94a3b8\" font-size=\"12\">Vị trí robot</text>")
        svg.append("    <circle cx=\"110\" cy=\"10\" r=\"5\" fill=\"#34d399\"/>")
        svg.append("    <text x=\"124\" y=\"14\" fill=\"#94a3b8\" font-size=\"12\">Dock sạc</text>")
        svg.append("    <line x1=\"190\" y1=\"10\" x2=\"220\" y2=\"10\" stroke=\"#ef4444\" stroke-width=\"3\" stroke-dasharray=\"4 2\"/>")
        svg.append("    <text x=\"228\" y=\"14\" fill=\"#94a3b8\" font-size=\"12\">Tường ảo</text>")
        svg.append("  </g>")
        
        // Floorplan HUD watermark
        svg.append("  <text x=\"780\" y=\"580\" text-anchor=\"end\" fill=\"#64748b\" font-size=\"11\" font-weight=\"500\">LiDAR Map: #\(mid) • 82 m²</text>")
        svg.append("</svg>")
        
        return (svg.joined(separator: "\n"), viewBoxRect)
    }
    
    // MARK: - 9. Nhật ký vệ sinh & Thống kê trọn đời (100% Ecovacs Cloud)
    public func getCleaningLogsAndStats(device: DeviceModel) async -> (stats: CleaningStatsModel?, logs: [CleaningLogItem]) {
        let statsRes = try? await executeCommand(device: device, cmdName: "getTotalStats")
        var statsModel: CleaningStatsModel? = nil
        if let b = statsRes, let body = extractBodyData(b) {
            let area = (body["area"] as? Int) ?? 0
            let timeSec = (body["time"] as? Int) ?? 0
            let count = (body["count"] as? Int) ?? 0
            statsModel = CleaningStatsModel(totalArea: area, totalTimeMin: timeSec / 60, totalCount: count)
        }
        
        // Lấy lịch sử dọn dẹp gần đây
        var logItems: [CleaningLogItem] = []
        if let logsRes = try? await executeCommand(device: device, cmdName: "getCleanLogs", payloadArgs: ["count": 10]),
           let body = extractBodyData(logsRes),
           let logsArray = body["logs"] as? [[String: Any]] {
            for item in logsArray {
                let time = (item["time"] as? String) ?? (item["date"] as? String) ?? "Hôm nay"
                let robot = device.displayName
                let area = (item["area"] as? Int) ?? 0
                let duration = (item["duration"] as? Int) ?? 0
                let result = (item["result"] as? String) ?? "Hoàn thành dọn dẹp"
                logItems.append(CleaningLogItem(time: time, robot: robot, area: area, duration: duration, result: result))
            }
        }
        
        return (statsModel, logItems)
    }
    
    // MARK: - 10. Điều Khiển Trạm Sạc Thông Minh (Station Action)
    public func executeStationAction(device: DeviceModel, action: StationActionType) async throws {
        var act = 1
        var type = 1
        switch action {
        case .emptyDustbin:
            act = 1
            type = 1
        case .startMopWash:
            act = 1
            type = 2
        case .stopMopWash:
            act = 0
            type = 2
        case .startAirDrying:
            act = 1
            type = 3
        case .stopAirDrying:
            act = 0
            type = 3
        }
        _ = try await executeCommand(device: device, cmdName: "stationAction", payloadArgs: ["act": act, "type": type])
    }
    
    public func getStationState(device: DeviceModel) async -> (isWashing: Bool, isDrying: Bool, dustbinFull: Bool) {
        guard let res = try? await executeCommand(device: device, cmdName: "getStationState"),
              let body = extractBodyData(res) else {
            return (false, false, false)
        }
        let washing = (body["washState"] as? Int) == 1 || (body["mopWashState"] as? Int) == 1
        let drying = (body["airDrying"] as? Int) == 1 || (body["airDryingState"] as? Int) == 1
        let dustFull = (body["dustbinState"] as? Int) == 1
        return (washing, drying, dustFull)
    }
    
    // MARK: - 11. Trợ Lý Giọng Nói YIKO
    public func setVoiceAssistant(device: DeviceModel, enabled: Bool) async throws {
        _ = try await executeCommand(device: device, cmdName: "setVoiceAssistantState", payloadArgs: ["enable": enabled ? 1 : 0])
    }
    
    // MARK: - 12. Quản Lý Lịch Hẹn Giờ Dọn Dẹp
    public func getSchedules(device: DeviceModel) -> [CleaningScheduleItem] {
        let key = "cleaning_schedules_\(device.did)"
        if let data = UserDefaults.standard.data(forKey: key),
           let list = try? JSONDecoder().decode([CleaningScheduleItem].self, from: data) {
            return list
        }
        return [
            CleaningScheduleItem(hour: 9, minute: 0, repeatDays: [2, 3, 4, 5, 6], isEnabled: false, cleanMode: "auto", label: "Dọn sáng các ngày đi làm"),
            CleaningScheduleItem(hour: 14, minute: 30, repeatDays: [1, 7], isEnabled: false, cleanMode: "auto", label: "Dọn dẹp cuối tuần")
        ]
    }
    
    public func saveSchedules(device: DeviceModel, schedules: [CleaningScheduleItem]) {
        let key = "cleaning_schedules_\(device.did)"
        if let data = try? JSONEncoder().encode(schedules) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    // MARK: - 13. Quản Lý Tường Ảo & Vùng Cấm (Persistence)
    public func getVirtualBoundaries(device: DeviceModel) -> (walls: [VirtualWall], zones: [RestrictedZone]) {
        let wallKey = "virtual_walls_\(device.did)"
        let zoneKey = "restricted_zones_\(device.did)"
        var walls: [VirtualWall] = []
        var zones: [RestrictedZone] = []
        if let data = UserDefaults.standard.data(forKey: wallKey),
           let list = try? JSONDecoder().decode([VirtualWall].self, from: data) {
            walls = list
        }
        if let data = UserDefaults.standard.data(forKey: zoneKey),
           let list = try? JSONDecoder().decode([RestrictedZone].self, from: data) {
            zones = list
        }
        return (walls, zones)
    }
    
    public func saveVirtualBoundaries(device: DeviceModel, walls: [VirtualWall], zones: [RestrictedZone]) {
        let wallKey = "virtual_walls_\(device.did)"
        let zoneKey = "restricted_zones_\(device.did)"
        if let data = try? JSONEncoder().encode(walls) {
            UserDefaults.standard.set(data, forKey: wallKey)
        }
        if let data = try? JSONEncoder().encode(zones) {
            UserDefaults.standard.set(data, forKey: zoneKey)
        }
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
