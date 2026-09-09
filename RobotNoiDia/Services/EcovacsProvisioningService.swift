import Foundation
import Network
import Darwin
import NetworkExtension

/// Helper điều phối luồng hoàn thành của Continuation an toàn đa luồng (Thread-safe Continuation Gate)
private final class ContinuationGate<T>: @unchecked Sendable {
    private var didResume = false
    private let lock = NSLock()
    private let continuation: CheckedContinuation<T, Error>
    
    init(_ continuation: CheckedContinuation<T, Error>) {
        self.continuation = continuation
    }
    
    func resume(returning value: T) {
        lock.lock()
        defer { lock.unlock() }
        guard !didResume else { return }
        didResume = true
        continuation.resume(returning: value)
    }
    
    func resume(throwing error: Error) {
        lock.lock()
        defer { lock.unlock() }
        guard !didResume else { return }
        didResume = true
        continuation.resume(throwing: error)
    }
}

/// Thuật toán EcoCRC8 độc quyền của Ecovacs để mã hóa buffer cấu hình Wi-Fi
public enum EcoCRC8 {
    /// Bảng tra cứu CRC8 với đa thức chuẩn ITU 0x07 (x^8 + x^2 + x + 1)
    private static let table: [UInt8] = {
        var tab = [UInt8](repeating: 0, count: 256)
        for i in 0..<256 {
            var b = UInt8(i)
            for _ in 0..<8 {
                if (b & 0x80) != 0 {
                    b = (b << 1) ^ 0x07
                } else {
                    b = b << 1
                }
            }
            tab[i] = b
        }
        return tab
    }()
    
    /// Tính toán mã CRC8 cho mảng byte dữ liệu
    public static func calc(_ data: Data) -> UInt8 {
        var crc: UInt8 = 0
        for byte in data {
            crc = table[Int(crc ^ byte)]
        }
        return crc
    }
    
    /// Đóng gói buffer cấu hình theo định dạng mã máy Ecovacs:
    /// Byte 0: 0x42 ('B')
    /// Byte 1: 0xA4 (164)
    /// Byte 2: 0x59 ('Y')
    /// Byte 3: CRC8(JSON)
    /// Byte 4...N: JSON bytes
    public static func getConfigBuffer(jsonString: String) -> Data {
        guard let jsonBytes = jsonString.data(using: .utf8) else { return Data() }
        let crc = calc(jsonBytes)
        var buffer = Data([0x42, 0xA4, 0x59, crc])
        buffer.append(jsonBytes)
        return buffer
    }
}

/// Kết quả polling từ Cloud
public struct ProvisioningCloudResult: Sendable {
    public enum Mode: Sendable {
        case pollSCResult // devmanager.do (chuẩn WlAp cho T10, X1, v.v.)
        case aliGetSCSync // ali.do (chuẩn V5 cho T8, T9)
        case newDeviceFound // Quét thấy device mới tinh qua fetchDevices
    }
    public let mode: Mode
    public let sn: String?
    public let mid: String?
    public let token: String?
}

/// Trạng thái của quá trình nạp Wi-Fi và ghép đôi Robot mới
public enum ProvisioningStep: Equatable {
    case idle
    case sendingToRobot(progress: String)
    case waitingForInternet(message: String)
    case waitingRobotOnline(progress: String)
    case obtainingToken(progress: String)
    case bindingDevice(progress: String)
    case success(robotName: String)
    case failed(error: String)
}

/// Service quản lý toàn bộ quy trình Kích hoạt & Cài đặt Wi-Fi cho Robot Ecovacs mới
/// Hỗ trợ cả 2 thế hệ giao thức:
/// 1. Dòng hiện đại (T10, T10 Turbo, X1, v.v.): SoftAP HTTP port 8888 (SetApConfig) & Cloud PollSCResult
/// 2. Dòng tiền nhiệm (T8, T9, v.v.): SoftAP TCP port 9876 (scpa) & Cloud AliGetSCSync
@MainActor
public final class EcovacsProvisioningService: ObservableObject {
    public static let shared = EcovacsProvisioningService()
    
    @Published public var step: ProvisioningStep = .idle
    @Published public var isBusy: Bool = false
    @Published public var currentSck2: String? = nil
    
    private init() {}
    
    // MARK: - Bước 1 & 2: Gửi SSID, Mật khẩu và sck2 sang Robot qua SoftAP
    public func sendWifiCredentialsToRobot(
        ssid: String,
        password: String
    ) async throws -> String {
        let cleanSSID = ssid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanSSID.isEmpty else {
            throw NSError(domain: "Provisioning", code: -1, userInfo: [NSLocalizedDescriptionKey: "Tên Wi-Fi (SSID) không được để trống!"])
        }
        
        // 1. Sinh chuỗi ngẫu nhiên 2 ký tự (giống RandomUtil.getRandomStr(2) trong APK gốc)
        let letters = "abcdefghijklmnopqrstuvwxyz0123456789"
        let rand2 = String((0..<2).map { _ in letters.randomElement()! })
        
        // 2. Tính sck2 = MD5(SSID + Password + rand2)
        let sck2 = CryptoHelper.md5("\(cleanSSID)\(password)\(rand2)")
        self.currentSck2 = sck2
        
        self.step = .sendingToRobot(progress: "Đang kết nối & truyền thông tin Wi-Fi sang Robot...")
        self.isBusy = true
        
        // =========================================================================
        // PHƯƠNG THỨC 1: HTTP API cổng 8888 (/req.do) - Chuẩn SoftAP hiện đại của T10, X1
        // =========================================================================
        let httpPayload = "{\"td\":\"SetApConfig\",\"s\":\"\(cleanSSID)\",\"p\":\"\(password)\",\"sc\":\"\",\"sck2\":\"\(sck2)\"}"
        let httpRequestString = "POST /req.do HTTP/1.1\r\nHost: 192.168.0.1:8888\r\nContent-Type: application/json; charset=utf-8\r\nContent-Length: \(httpPayload.utf8.count)\r\nConnection: close\r\n\r\n\(httpPayload)"
        guard let httpRequestData = httpRequestString.data(using: .utf8) else {
            throw NSError(domain: "Provisioning", code: -2, userInfo: [NSLocalizedDescriptionKey: "Lỗi tạo gói tin HTTP SetApConfig!"])
        }
        
        // Thử gửi HTTP tới 192.168.0.1:8888 rồi tới 192.168.5.1:8888
        let candidateHosts = ["192.168.0.1", "192.168.5.1"]
        for host in candidateHosts {
            do {
                print("[SoftAP-HTTP] Thử gửi SetApConfig tới \(host):8888...")
                let reply = try sendViaBsdSocket(host: host, port: 8888, data: httpRequestData)
                print("[SoftAP-HTTP] Phản hồi từ \(host):8888: '\(reply)'")
                if reply.localizedCaseInsensitiveContains("\"ret\":\"ok\"") ||
                   reply.localizedCaseInsensitiveContains("\"ret\": \"ok\"") ||
                   reply.localizedCaseInsensitiveContains("200 OK") {
                    print("[SoftAP-HTTP] Robot dòng T10/X1 tại \(host) đã chấp nhận cấu hình Wi-Fi thành công!")
                    return sck2
                }
            } catch {
                print("[SoftAP-HTTP] Không thể kết nối tới \(host):8888: \(error.localizedDescription)")
            }
        }
        
        // =========================================================================
        // PHƯƠNG THỨC 2: TCP Socket cổng 9876 (scpa) - Chuẩn của T8, T9
        // =========================================================================
        let slkJson = "{\"sck2\":\"\(sck2)\"}"
        let slkBuffer = EcoCRC8.getConfigBuffer(jsonString: slkJson)
        let slkMsg = slkBuffer.base64EncodedString()
        let rawScpaJson = "{\"td\":\"scpa\",\"ssid\":\"\(cleanSSID)\",\"passphrase\":\"\(password)\",\"encrypt\":\"\(password.isEmpty ? "no" : "yes")\",\"append_info\":\"0\",\"slk_msg\":\"\(slkMsg)\"}"
        let scpaPacketString = "@" + rawScpaJson
        guard let scpaPacketData = scpaPacketString.data(using: .utf8) else {
            throw NSError(domain: "Provisioning", code: -2, userInfo: [NSLocalizedDescriptionKey: "Lỗi đóng gói gói tin scpa!"])
        }
        
        for host in candidateHosts {
            do {
                print("[SoftAP-Socket] Thử gửi scpa tới \(host):9876...")
                let reply = try sendViaBsdSocket(host: host, port: 9876, data: scpaPacketData)
                print("[SoftAP-Socket] Phản hồi từ \(host):9876: '\(reply)'")
                if reply.localizedCaseInsensitiveContains("ok") || reply.localizedCaseInsensitiveContains("ret") {
                    print("[SoftAP-Socket] Robot dòng T8/T9 tại \(host) đã chấp nhận cấu hình Wi-Fi!")
                    return sck2
                }
            } catch {
                print("[SoftAP-Socket] Không thể kết nối tới \(host):9876: \(error.localizedDescription)")
            }
        }
        
        // Cách dự phòng cuối: Sử dụng NWConnection ép interface Wi-Fi tới 192.168.0.1:9876
        do {
            print("[SoftAP-NWConnection] Thử gửi qua Network.framework...")
            try await sendViaNWConnection(host: "192.168.0.1", port: 9876, data: scpaPacketData)
            return sck2
        } catch {
            print("[SoftAP-NWConnection] Thất bại: \(error.localizedDescription)")
        }
        
        throw NSError(domain: "Provisioning", code: -4, userInfo: [
            NSLocalizedDescriptionKey: "Không thể kết nối hoặc Robot không phản hồi cấu hình Wi-Fi (Cả cổng HTTP 8888 của T10 và TCP 9876 đều không phản hồi). Hãy kiểm tra:\n1. iPhone đã kết nối đúng vào Wi-Fi của Robot (ECOVACS_xxxx).\n2. Tạm TẮT Dữ liệu di động (4G/LTE) để máy không bỏ qua mạng Wi-Fi nội bộ của Robot."
        ])
    }
    
    /// Gửi qua BSD Socket tiêu chuẩn và ép buộc gắn vào interface Wi-Fi (en0)
    private nonisolated func sendViaBsdSocket(host: String, port: UInt16, data: Data) throws -> String {
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else {
            throw NSError(domain: "Provisioning", code: -10, userInfo: [NSLocalizedDescriptionKey: "Không thể tạo socket (errno: \(errno))"])
        }
        defer {
            Darwin.close(sock)
        }
        
        // Ép buộc kết nối qua interface Wi-Fi (en0) để tránh bị 4G Cellular can thiệp
        var wifiIndex = if_nametoindex("en0")
        if wifiIndex > 0 {
            _ = setsockopt(sock, IPPROTO_IP, IP_BOUND_IF, &wifiIndex, socklen_t(MemoryLayout<UInt32>.size))
        }
        
        // Timeout 4 giây
        var timeout = timeval(tv_sec: 4, tv_usec: 0)
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        
        var serverAddr = sockaddr_in()
        serverAddr.sin_family = sa_family_t(AF_INET)
        serverAddr.sin_port = port.bigEndian
        guard inet_pton(AF_INET, host, &serverAddr.sin_addr) == 1 else {
            throw NSError(domain: "Provisioning", code: -11, userInfo: [NSLocalizedDescriptionKey: "IP không hợp lệ: \(host)"])
        }
        
        let connectRes = withUnsafePointer(to: &serverAddr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        guard connectRes == 0 else {
            let err = errno
            throw NSError(domain: "Provisioning", code: -12, userInfo: [NSLocalizedDescriptionKey: "Lỗi kết nối Socket tới \(host):\(port) (errno \(err): \(String(cString: strerror(err))))"])
        }
        
        let sent = data.withUnsafeBytes { ptr in
            Darwin.send(sock, ptr.baseAddress, data.count, 0)
        }
        guard sent > 0 else {
            throw NSError(domain: "Provisioning", code: -13, userInfo: [NSLocalizedDescriptionKey: "Lỗi gửi dữ liệu sang Robot (errno: \(errno))"])
        }
        
        var buf = [UInt8](repeating: 0, count: 4096)
        let recvd = Darwin.recv(sock, &buf, buf.count, 0)
        if recvd > 0 {
            return String(bytes: buf[0..<recvd], encoding: .utf8) ?? ""
        }
        return ""
    }
    
    /// Gửi qua NWConnection với ép buộc interface Wi-Fi
    private func sendViaNWConnection(host: String, port: UInt16, data: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let gate = ContinuationGate(continuation)
            let endpoint = NWEndpoint.hostPort(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(rawValue: port)!
            )
            
            let tcpOptions = NWProtocolTCP.Options()
            tcpOptions.connectionTimeout = 5
            tcpOptions.enableKeepalive = false
            
            let params = NWParameters(tls: nil, tcp: tcpOptions)
            params.requiredInterfaceType = .wifi
            params.prohibitedInterfaceTypes = [.cellular]
            
            let connection = NWConnection(to: endpoint, using: params)
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: data, completion: .contentProcessed { sendError in
                        if let sendError = sendError {
                            connection.cancel()
                            gate.resume(throwing: sendError)
                            return
                        }
                        connection.receive(minimumIncompleteLength: 1, maximumLength: 1024) { _, _, _, _ in
                            connection.cancel()
                            gate.resume(returning: ())
                        }
                    })
                case .failed(let err):
                    connection.cancel()
                    gate.resume(throwing: err)
                case .cancelled:
                    gate.resume(throwing: NSError(domain: "Provisioning", code: -3, userInfo: [NSLocalizedDescriptionKey: "Kết nối bị hủy."]))
                default:
                    break
                }
            }
            
            DispatchQueue.global().asyncAfter(deadline: .now() + 6.0) {
                connection.cancel()
                gate.resume(throwing: NSError(domain: "Provisioning", code: -4, userInfo: [NSLocalizedDescriptionKey: "Hết thời gian chờ kết nối NWConnection."]))
            }
            
            connection.start(queue: .global())
        }
    }
    
    /// Tự động gỡ cấu hình Wi-Fi Robot để iOS tự động ngắt kết nối và quay về Wi-Fi nhà
    public func kickRobotWifi(prefix: String = "ECOVACS_") {
        if #available(iOS 11.0, *) {
            NEHotspotConfigurationManager.shared.getConfiguredSSIDs { ssids in
                for ssid in ssids {
                    let upper = ssid.uppercased()
                    if upper.hasPrefix("ECOVACS_") || upper.hasPrefix("DEEBOT_") {
                        print("[Provisioning] Tự động gỡ cấu hình Wi-Fi Robot: \(ssid)")
                        NEHotspotConfigurationManager.shared.removeConfiguration(forSSID: ssid)
                    }
                }
            }
        }
    }
    
    /// Kiểm tra xem iPhone đã có kết nối Internet thật sự chưa (để liên lạc với Cloud)
    public func isInternetAvailable() async -> Bool {
        guard let url = URL(string: "https://portal.ecouser.net/api/users/user.do") else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "HEAD"
        req.timeoutInterval = 3.0
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            if let httpResp = resp as? HTTPURLResponse, httpResp.statusCode < 500 {
                return true
            }
            return false
        } catch {
            return false
        }
    }
    
    // MARK: - Bước 3: Polling Cloud (PollSCResult & AliGetSCSync với Bộ lọc Anti-False-Positive)
    public func pollBindTokenFromCloud(
        sck2: String,
        existingDids: Set<String>,
        maxAttempts: Int = 20
    ) async throws -> ProvisioningCloudResult {
        guard let creds = EcovacsAuthService.shared.getSavedCredentials() else {
            throw NSError(domain: "Provisioning", code: -5, userInfo: [NSLocalizedDescriptionKey: "Chưa đăng nhập tài khoản Ecovacs!"])
        }
        
        // Tạm dừng đếm ngược và thông báo cho người dùng bật lại 4G / nối Wi-Fi nhà nếu mất kết nối
        var isOnline = await isInternetAvailable()
        var waitNetCount = 0
        while !isOnline && waitNetCount < 30 {
            self.step = .waitingForInternet(message: "Robot đã nhận Wi-Fi! Hãy BẬT LẠI 4G (hoặc vào Cài đặt đổi về Wi-Fi nhà) để máy hoàn tất gán Robot...")
            try await Task.sleep(nanoseconds: 2_000_000_000)
            isOnline = await isInternetAvailable()
            waitNetCount += 1
        }
        
        // Chuẩn bị Request 1: PollSCResult (devmanager.do - Dành cho T10, X1)
        let devManagerUrl = URL(string: "https://portal.ecouser.net/api/iot/devmanager.do")!
        let pollScPayload: [String: Any] = [
            "td": "PollSCResult",
            "sck": sck2,
            "auth": [
                "with": "users",
                "userid": creds.userId,
                "realm": "ecouser.net",
                "token": creds.token
            ]
        ]
        let pollScData = try? JSONSerialization.data(withJSONObject: pollScPayload, options: [])
        
        // Chuẩn bị Request 2: AliGetSCSync (ali.do - Dành cho T8, T9)
        let aliUrl = URL(string: "https://portal.ecouser.net/api/alibridge/ali.do?ituid=\(creds.userId)")!
        let aliPayload: [String: Any] = [
            "td": "AliGetSCSync",
            "data": ["sck2": sck2]
        ]
        let aliData = try? JSONSerialization.data(withJSONObject: aliPayload, options: [])
        
        for attempt in 1...maxAttempts {
            self.step = .waitingRobotOnline(progress: "Đang đợi Robot kết nối Router & báo danh Cloud... (\(attempt)/\(maxAttempts))")
            
            // 1. Thử PollSCResult (devmanager.do)
            if let pollScData = pollScData {
                var req = URLRequest(url: devManagerUrl)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.setValue("Dalvik/2.1.0 (Linux; U; Android 12)", forHTTPHeaderField: "User-Agent")
                req.httpBody = pollScData
                req.timeoutInterval = 6
                
                if let (data, resp) = try? await URLSession.shared.data(for: req),
                   let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let ret = json["ret"] as? String ?? ""
                    if ret.lowercased() == "ok" {
                        let sn = json["name"] as? String
                        let mid = json["type"] as? String
                        print("[Provisioning] PollSCResult THÀNH CÔNG! Robot đã kết nối Cloud: sn=\(sn ?? "nil"), mid=\(mid ?? "nil")")
                        return ProvisioningCloudResult(mode: .pollSCResult, sn: sn, mid: mid, token: nil)
                    }
                }
            }
            
            // 2. Thử AliGetSCSync (ali.do)
            if let aliData = aliData {
                var req = URLRequest(url: aliUrl)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.setValue("Dalvik/2.1.0 (Linux; U; Android 12)", forHTTPHeaderField: "User-Agent")
                req.httpBody = aliData
                req.timeoutInterval = 6
                
                if let (data, resp) = try? await URLSession.shared.data(for: req),
                   let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let code = json["code"] as? Int ?? -1
                    if code == 0,
                       let dataDict = json["data"] as? [String: Any],
                       let scData = dataDict["SCData"] as? [String: Any],
                       let bindToken = scData["bindtoken"] as? String,
                       !bindToken.isEmpty {
                        print("[Provisioning] AliGetSCSync lấy thành công bindtoken: \(bindToken)")
                        return ProvisioningCloudResult(mode: .aliGetSCSync, sn: nil, mid: nil, token: bindToken)
                    }
                }
            }
            
            // 3. Kiểm tra danh sách thiết bị trên Cloud (Chỉ chấp nhận DID MỚI TINH, không bị false positive với robot cũ)
            if attempt % 3 == 0 {
                if let currentDevices = try? await EcovacsDeviceService.shared.fetchDevices() {
                    if let newDevice = currentDevices.first(where: { !existingDids.contains($0.did) }) {
                        let name = newDevice.displayName.isEmpty ? newDevice.name : newDevice.displayName
                        print("[Provisioning] Đã phát hiện Robot mới tinh xuất hiện trên Cloud: \(name) (\(newDevice.did))!")
                        return ProvisioningCloudResult(mode: .newDeviceFound, sn: newDevice.did, mid: newDevice.resource, token: nil)
                    }
                }
            }
            
            // Đợi 2.5 giây cho lần thử tiếp theo
            try await Task.sleep(nanoseconds: 2_500_000_000)
        }
        
        // Kiểm tra lần cuối cùng xem có robot mới nào xuất hiện chưa
        if let currentDevices = try? await EcovacsDeviceService.shared.fetchDevices(),
           let newDevice = currentDevices.first(where: { !existingDids.contains($0.did) }) {
            let name = newDevice.displayName.isEmpty ? newDevice.name : newDevice.displayName
            return ProvisioningCloudResult(mode: .newDeviceFound, sn: newDevice.did, mid: newDevice.resource, token: nil)
        }
        
        throw NSError(domain: "Provisioning", code: -8, userInfo: [
            NSLocalizedDescriptionKey: "Hết thời gian chờ (Timeout). Robot chưa kết nối được với Wi-Fi nhà bạn hoặc mật khẩu Wi-Fi không đúng (Đèn Wi-Fi trên robot vẫn nhấp nháy). Hãy thử kiểm tra lại mật khẩu và đặt robot gần Router hơn."
        ])
    }
    
    // MARK: - Bước 4: Hoàn tất liên kết Robot vào tài khoản
    public func completeBinding(
        result: ProvisioningCloudResult,
        existingDids: Set<String>
    ) async throws -> String {
        self.step = .bindingDevice(progress: "Đang xác thực và gán Robot vào tài khoản...")
        
        // Đồng bộ lại danh sách thiết bị trên Cloud để nhận diện robot mới
        let devices = try await EcovacsDeviceService.shared.fetchDevices()
        if let newestDevice = devices.first(where: { !existingDids.contains($0.did) }) {
            let robotName = newestDevice.displayName.isEmpty ? newestDevice.name : newestDevice.displayName
            self.step = .success(robotName: robotName)
            self.isBusy = false
            return robotName
        } else if let sn = result.sn, !sn.isEmpty {
            let fallbackName = "DEEBOT (\(sn.suffix(6)))"
            self.step = .success(robotName: fallbackName)
            self.isBusy = false
            return fallbackName
        } else {
            self.step = .success(robotName: "Robot Mới")
            self.isBusy = false
            return "Robot Mới"
        }
    }
    
    // MARK: - Hàm Orchestrator kích hoạt trọn gói
    public func executeFullProvisioningFlow(ssid: String, password: String) async {
        do {
            // 0. Lưu danh sách DID các robot hiện có trong tài khoản để chống nhận nhầm
            let cached = EcovacsDeviceService.shared.getCachedDevices()
            let existingDids = Set(cached.map { $0.did })
            print("[Provisioning] Danh sách DID robot đã có trước khi gán: \(existingDids)")
            
            // 1. Gửi cấu hình sang Robot AP (Thử HTTP 8888 của T10/X1 và TCP 9876 của T8/T9)
            let sck2 = try await sendWifiCredentialsToRobot(ssid: ssid, password: password)
            
            // 2. Tự động đá Wi-Fi Robot để iOS quay về Wi-Fi nhà
            kickRobotWifi()
            
            // 3. Polling Cloud lấy bindtoken / kết quả (có cơ chế chờ Internet thông minh & chống false-positive)
            let result = try await pollBindTokenFromCloud(sck2: sck2, existingDids: existingDids)
            
            // 4. Kích hoạt và gán vào tài khoản
            _ = try await completeBinding(result: result, existingDids: existingDids)
            
        } catch {
            self.step = .failed(error: error.localizedDescription)
            self.isBusy = false
        }
    }
    
    public func reset() {
        self.step = .idle
        self.isBusy = false
        self.currentSck2 = nil
    }
}
