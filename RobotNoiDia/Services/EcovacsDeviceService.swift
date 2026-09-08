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
    
    // MARK: - 7. Lấy Bản đồ LiDAR SVG thực tế từ Robot
    public struct MapResult {
        public let svg: String
        public let mid: String
        public let coverageM2: Int
        
        public init(svg: String, mid: String, coverageM2: Int) {
            self.svg = svg
            self.mid = mid
            self.coverageM2 = coverageM2
        }
    }
    
    public func getSvgMapWithDetails(device: DeviceModel) async -> MapResult? {
        // 1. Ưu tiên tải bản đồ LiDAR thực tế từ Máy chủ DIY Backend (HƯỚNG 2)
        if let diyResult = await fetchMapFromDIYServer(device: device) {
            return diyResult
        }
        
        // 2. Dự phòng: Gửi lệnh getMajorMap qua Ecovacs Cloud
        guard let res = try? await executeCommand(device: device, cmdName: "getMajorMap", payloadArgs: [:]),
              let body = extractBodyData(res) else {
            return nil
        }
        
        let mid = (body["mid"] as? String) ?? (body["mid"] as? Int).map { String($0) } ?? ""
        let pieceWidth = (body["pieceWidth"] as? Int) ?? 100
        let pieceHeight = (body["pieceHeight"] as? Int) ?? 100
        let cellWidth = (body["cellWidth"] as? Int) ?? 8
        let cellHeight = (body["cellHeight"] as? Int) ?? 8
        let valueStr = (body["value"] as? String) ?? ""
        
        let vals = valueStr.split(separator: ",").map(String.init)
        var activeTiles: [(row: Int, col: Int)] = []
        
        for (idx, val) in vals.enumerated() {
            let cleanVal = val.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanVal.isEmpty && cleanVal != "1295764014" && cleanVal != "0" {
                let r = idx / cellWidth
                let c = idx % cellWidth
                activeTiles.append((r, c))
            }
        }
        
        guard !activeTiles.isEmpty else {
            return nil
        }
        
        // Kiểm tra trạng thái sạc thực tế để định vị đế sạc & robot
        let chargeRes = try? await executeCommand(device: device, cmdName: "getChargeState", payloadArgs: [:])
        let isCharging = (extractBodyData(chargeRes ?? [:])?["isCharging"] as? Int) == 1
        
        let svg = generateSvgMap(
            mid: mid,
            cellWidth: cellWidth,
            cellHeight: cellHeight,
            pieceWidth: pieceWidth,
            pieceHeight: pieceHeight,
            activeTiles: activeTiles,
            isCharging: isCharging
        )
        
        let coverageM2 = activeTiles.count * 10
        return MapResult(svg: svg, mid: mid, coverageM2: coverageM2)
    }

    public func getSvgMap(device: DeviceModel) async -> String? {
        return await getSvgMapWithDetails(device: device)?.svg
    }
    
    // MARK: - Tải bản đồ LiDAR độ phân giải cao từ Máy chủ DIY (HƯỚNG 2)
    public func fetchMapFromDIYServer(device: DeviceModel) async -> MapResult? {
        let baseUrl = Constants.diyServerBaseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(baseUrl)/api/devices/\(device.did)/map") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 4.0
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let hasMap = json["has_map"] as? Bool, hasMap,
                  let svg = json["svg"] as? String,
                  svg.contains("<svg") else {
                return nil
            }
            return MapResult(svg: svg, mid: "LiDAR", coverageM2: 0)
        } catch {
            return nil
        }
    }
    
    public func triggerDiyMapRefresh(device: DeviceModel) async -> MapResult? {
        let baseUrl = Constants.diyServerBaseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(baseUrl)/api/devices/\(device.did)/map/refresh") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 6.0
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
            return MapResult(svg: svg, mid: "LiDAR", coverageM2: 0)
        } catch {
            return nil
        }
    }
    
    private func generateSvgMap(
        mid: String,
        cellWidth: Int,
        cellHeight: Int,
        pieceWidth: Int,
        pieceHeight: Int,
        activeTiles: [(row: Int, col: Int)],
        isCharging: Bool
    ) -> String {
        let minCol = activeTiles.map { $0.col }.min() ?? 0
        let maxCol = activeTiles.map { $0.col }.max() ?? 0
        let minRow = activeTiles.map { $0.row }.min() ?? 0
        let maxRow = activeTiles.map { $0.row }.max() ?? 0
        
        let pad = 36
        let vx = minCol * pieceWidth - pad
        let vy = minRow * pieceHeight - pad
        let vw = (maxCol - minCol + 1) * pieceWidth + pad * 2
        let vh = (maxRow - minRow + 1) * pieceHeight + pad * 2
        
        var svg: [String] = []
        svg.append("<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"\(vx) \(vy) \(vw) \(vh)\" width=\"100%\" height=\"100%\">")
        svg.append("  <defs>")
        svg.append("    <linearGradient id=\"roomGrad1\" x1=\"0%\" y1=\"0%\" x2=\"100%\" y2=\"100%\">")
        svg.append("      <stop offset=\"0%\" stop-color=\"#E0F2FE\" stop-opacity=\"0.95\"/>")
        svg.append("      <stop offset=\"100%\" stop-color=\"#BAE6FD\" stop-opacity=\"0.95\"/>")
        svg.append("    </linearGradient>")
        svg.append("    <linearGradient id=\"roomGrad2\" x1=\"0%\" y1=\"0%\" x2=\"100%\" y2=\"100%\">")
        svg.append("      <stop offset=\"0%\" stop-color=\"#DCFCE7\" stop-opacity=\"0.95\"/>")
        svg.append("      <stop offset=\"100%\" stop-color=\"#BBF7D0\" stop-opacity=\"0.95\"/>")
        svg.append("    </linearGradient>")
        svg.append("    <linearGradient id=\"roomGrad3\" x1=\"0%\" y1=\"0%\" x2=\"100%\" y2=\"100%\">")
        svg.append("      <stop offset=\"0%\" stop-color=\"#FEF3C7\" stop-opacity=\"0.95\"/>")
        svg.append("      <stop offset=\"100%\" stop-color=\"#FDE68A\" stop-opacity=\"0.95\"/>")
        svg.append("    </linearGradient>")
        svg.append("    <filter id=\"shadow\" x=\"-10%\" y=\"-10%\" width=\"120%\" height=\"120%\">")
        svg.append("      <feDropShadow dx=\"0\" dy=\"4\" stdDeviation=\"6\" flood-color=\"#0284C7\" flood-opacity=\"0.15\"/>")
        svg.append("    </filter>")
        svg.append("  </defs>")
        
        // Grid floor lines
        svg.append("  <g stroke=\"#CBD5E1\" stroke-width=\"0.5\" stroke-dasharray=\"2,4\" opacity=\"0.6\">")
        for c in (minCol - 1)...(maxCol + 2) {
            let x = c * pieceWidth
            svg.append("    <line x1=\"\(x)\" y1=\"\(vy)\" x2=\"\(x)\" y2=\"\(vy + vh)\" />")
        }
        for r in (minRow - 1)...(maxRow + 2) {
            let y = r * pieceHeight
            svg.append("    <line x1=\"\(vx)\" y1=\"\(y)\" x2=\"\(vx + vw)\" y2=\"\(y)\" />")
        }
        svg.append("  </g>")
        
        // Active room tiles
        svg.append("  <g filter=\"url(#shadow)\">")
        let grads = ["url(#roomGrad1)", "url(#roomGrad2)", "url(#roomGrad3)"]
        for (r, c) in activeTiles {
            let x = c * pieceWidth
            let y = r * pieceHeight
            let grad = grads[(r + c) % grads.count]
            svg.append("    <rect x=\"\(x + 1)\" y=\"\(y + 1)\" width=\"\(pieceWidth - 2)\" height=\"\(pieceHeight - 2)\" rx=\"8\" fill=\"\(grad)\" stroke=\"#0284C7\" stroke-width=\"1.5\" />")
        }
        svg.append("  </g>")
        
        // Outer bounding wall
        let minX = minCol * pieceWidth
        let minY = minRow * pieceHeight
        let bw = (maxCol - minCol + 1) * pieceWidth
        let bh = (maxRow - minRow + 1) * pieceHeight
        svg.append("  <rect x=\"\(minX)\" y=\"\(minY)\" width=\"\(bw)\" height=\"\(bh)\" rx=\"12\" fill=\"none\" stroke=\"#0369A1\" stroke-width=\"3\" stroke-dasharray=\"8,4\" />")
        
        // Dock station
        let dockX = Double(minCol + maxCol + 1) * Double(pieceWidth) / 2.0
        let dockY = Double(maxRow + 1) * Double(pieceHeight) - 18.0
        
        svg.append("  <g transform=\"translate(\(dockX - 14.0), \(dockY - 14.0))\">")
        svg.append("    <rect width=\"28\" height=\"28\" rx=\"6\" fill=\"#10B981\" stroke=\"#FFFFFF\" stroke-width=\"2\"/>")
        svg.append("    <path d=\"M15 4L7 16h6l-2 8 8-12h-6l2-8z\" fill=\"#FFFFFF\"/>")
        svg.append("    <text x=\"14\" y=\"38\" font-family=\"-apple-system, sans-serif\" font-size=\"9\" font-weight=\"bold\" fill=\"#047857\" text-anchor=\"middle\">ĐẾ SẠC</text>")
        svg.append("  </g>")
        
        // Robot Position
        let rx = dockX
        let ry = isCharging ? (dockY - 25.0) : (Double(minRow + maxRow) * Double(pieceHeight) / 2.0)
        
        svg.append("  <g transform=\"translate(\(rx), \(ry))\">")
        svg.append("    <circle r=\"18\" fill=\"#0F172A\" stroke=\"#FFFFFF\" stroke-width=\"2.5\" />")
        svg.append("    <circle r=\"8\" fill=\"#0284C7\" />")
        svg.append("    <circle r=\"3\" fill=\"#38BDF8\" />")
        svg.append("    <polygon points=\"0,-18 -4,-12 4,-12\" fill=\"#38BDF8\" />")
        svg.append("    <text x=\"0\" y=\"30\" font-family=\"-apple-system, sans-serif\" font-size=\"9\" font-weight=\"bold\" fill=\"#0F172A\" text-anchor=\"middle\">DEEBOT</text>")
        svg.append("  </g>")
        
        // Floorplan watermark / info
        let textX = vx + 10
        let textY = vy + vh - 10
        svg.append("  <text x=\"\(textX)\" y=\"\(textY)\" font-family=\"-apple-system, sans-serif\" font-size=\"10\" font-weight=\"600\" fill=\"#64748B\">LiDAR ID: #\(mid) • Diện tích: \(activeTiles.count * 10) m²</text>")
        svg.append("</svg>")
        
        return svg.joined(separator: "\n")
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
