import Foundation
import Network

/// Đại diện cho một thiết bị hoặc Robot tìm thấy trong mạng Wi-Fi nội bộ
public struct DiscoveredLocalDevice: Identifiable, Hashable, Codable {
    public var id: String { "\(ip):\(port)" }
    public let ip: String
    public let port: Int
    public let hostname: String?
    public let latencyMs: Int
    public let modelHint: String
    public let isEcovacsLikely: Bool
    
    public init(ip: String, port: Int, hostname: String? = nil, latencyMs: Int, modelHint: String = "Thiết Bị Mạng", isEcovacsLikely: Bool = false) {
        self.ip = ip
        self.port = port
        self.hostname = hostname
        self.latencyMs = latencyMs
        self.modelHint = modelHint
        self.isEcovacsLikely = isEcovacsLikely
    }
}

/// Dịch vụ quét và phát hiện Robot trong mạng Wi-Fi gia đình (Local LAN Discovery)
/// Sử dụng hoàn toàn Apple Network.framework (NWConnection) - an toàn tuyệt đối, không crash
public final class LocalNetworkScannerService {
    public static let shared = LocalNetworkScannerService()
    
    private init() {}
    
    /// Lấy địa chỉ IP và Subnet prefix của iPhone trên giao diện Wi-Fi (en0)
    /// Đảm bảo kiểm tra con trỏ NULL an toàn (tránh EXC_BAD_ACCESS)
    public func getLocalWifiIPAddress() -> (ip: String, subnetPrefix: String)? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return nil
        }
        defer { freeifaddrs(ifaddr) }
        
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            // Kiểm tra an toàn: bỏ qua nếu ifa_addr là NULL
            guard let ifaAddr = interface.ifa_addr else { continue }
            
            let addrFamily = ifaAddr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                // "en0" là Wi-Fi chính trên iPhone
                if name == "en0" || name.hasPrefix("en") {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    let result = getnameinfo(
                        ifaAddr,
                        socklen_t(ifaAddr.pointee.sa_len),
                        &hostname,
                        socklen_t(hostname.count),
                        nil,
                        0,
                        NI_NUMERICHOST
                    )
                    if result == 0 {
                        let ipCandidate = String(cString: hostname)
                        if ipCandidate != "127.0.0.1" && ipCandidate.contains(".") {
                            address = ipCandidate
                            break
                        }
                    }
                }
            }
        }
        
        guard let ip = address else { return nil }
        let components = ip.split(separator: ".")
        guard components.count == 4 else { return nil }
        let subnetPrefix = "\(components[0]).\(components[1]).\(components[2])"
        return (ip: ip, subnetPrefix: subnetPrefix)
    }
    
    /// Thăm dò một địa chỉ IP và cổng TCP cụ thể bằng Apple Network.framework (NWConnection)
    /// Hoàn toàn an toàn bộ nhớ, tự động kích hoạt hộp thoại cấp quyền Mạng cục bộ (Local Network) của iOS
    public func probePort(ip: String, port: Int, timeoutSec: Double = 0.35) async -> (isOpen: Bool, latencyMs: Int) {
        guard let portEndpoint = NWEndpoint.Port(rawValue: UInt16(port)) else {
            return (false, 0)
        }
        let startTime = CFAbsoluteTimeGetCurrent()
        let hostEndpoint = NWEndpoint.Host(ip)
        
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.connectionTimeout = Int(timeoutSec * 1000)
        let params = NWParameters(tls: nil, tcp: tcpOptions)
        let connection = NWConnection(host: hostEndpoint, port: portEndpoint, using: params)
        
        return await withCheckedContinuation { continuation in
            let lock = NSLock()
            var resumed = false
            
            let finish = { (isOpen: Bool) in
                lock.lock()
                defer { lock.unlock() }
                if !resumed {
                    resumed = true
                    connection.stateUpdateHandler = nil
                    connection.cancel()
                    let latency = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
                    continuation.resume(returning: (isOpen, max(1, latency)))
                }
            }
            
            // Bộ đếm Timeout an toàn
            DispatchQueue.global().asyncAfter(deadline: .now() + timeoutSec) {
                finish(false)
            }
            
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    finish(true)
                case .failed:
                    finish(false)
                case .waiting(let error):
                    // Cổng bị từ chối (ECONNREFUSED) vẫn chứng minh thiết bị đang tồn tại và online
                    if case .posix(let code) = error, code == .ECONNREFUSED {
                        finish(true)
                    } else {
                        finish(false)
                    }
                case .cancelled:
                    finish(false)
                default:
                    break
                }
            }
            
            connection.start(queue: DispatchQueue.global(qos: .userInitiated))
        }
    }
    
    /// Phân giải tên máy (Hostname) an toàn
    public func resolveHostname(ip: String) async -> String? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                var addr = sockaddr_in()
                addr.sin_family = sa_family_t(AF_INET)
                if inet_pton(AF_INET, ip, &addr.sin_addr) == 1 {
                    var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    let result = withUnsafePointer(to: &addr) {
                        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                            getnameinfo($0, socklen_t(MemoryLayout<sockaddr_in>.size), &hostBuffer, socklen_t(hostBuffer.count), nil, 0, 0)
                        }
                    }
                    if result == 0 {
                        let name = String(cString: hostBuffer)
                        if !name.isEmpty && name != ip {
                            continuation.resume(returning: name)
                            return
                        }
                    }
                }
                continuation.resume(returning: nil)
            }
        }
    }
    
    /// Nhận diện thương hiệu Robot Ecovacs / Deebot
    public func inspectDeviceIdentity(ip: String, port: Int) async -> (modelHint: String, isEcovacs: Bool) {
        guard let url = URL(string: "http://\(ip):\(port)/") else {
            return ("Thiết Bị Mạng", false)
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 0.6
        request.httpMethod = "GET"
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let body = String(data: data, encoding: .utf8)?.lowercased() ?? ""
            let headers = (response as? HTTPURLResponse)?.allHeaderFields as? [String: Any] ?? [:]
            let serverHeader = (headers["Server"] as? String)?.lowercased() ?? ""
            
            if body.contains("ecovacs") || body.contains("deebot") || serverHeader.contains("ecovacs") {
                if body.contains("t10") { return ("DEEBOT T10 TURBO", true) }
                if body.contains("t9") { return ("DEEBOT T9 AIVI", true) }
                if body.contains("x1") { return ("DEEBOT X1 OMNI", true) }
                return ("DEEBOT Robot Hút Bụi", true)
            }
        } catch {}
        
        if port == 8883 {
            return ("Robot Ecovacs (MQTT Port)", true)
        } else if port == 5222 || port == 5223 {
            return ("Robot Ecovacs (XMPP Port)", true)
        } else if port == 4000 || port == 4001 {
            return ("Robot Ecovacs (Local Port)", true)
        }
        
        return ("Thiết Bị Mạng (Cổng \(port))", false)
    }
    
    /// Quét toàn bộ dải IP mạng cục bộ gia đình (254 IPs) theo từng đợt (Batches)
    /// Tránh quá tải router và tránh cạn kiệt socket file descriptors trên iOS
    public func scanSubnet(
        onProgress: @escaping (Float) -> Void
    ) async -> [DiscoveredLocalDevice] {
        let subnetPrefix: String
        if let wifi = getLocalWifiIPAddress() {
            subnetPrefix = wifi.subnetPrefix
        } else {
            subnetPrefix = "192.168.1"
        }
        
        var results: [DiscoveredLocalDevice] = []
        let targetPorts = [80, 8080, 8883, 5222, 4000]
        
        let batchSize = 16
        var completedHosts = 0
        let totalHosts = 254
        
        for batchStart in stride(from: 1, through: totalHosts, by: batchSize) {
            let batchEnd = min(batchStart + batchSize - 1, totalHosts)
            
            await withTaskGroup(of: DiscoveredLocalDevice?.self) { group in
                for i in batchStart...batchEnd {
                    let candidateIp = "\(subnetPrefix).\(i)"
                    group.addTask {
                        for port in targetPorts {
                            let (isOpen, latency) = await self.probePort(ip: candidateIp, port: port, timeoutSec: 0.25)
                            if isOpen {
                                let hostname = await self.resolveHostname(ip: candidateIp)
                                let (hint, isEco) = await self.inspectDeviceIdentity(ip: candidateIp, port: port)
                                
                                let isEcovacsLikely = isEco || (hostname?.lowercased().contains("ecovacs") == true) || (hostname?.lowercased().contains("deebot") == true)
                                let finalHint = isEcovacsLikely ? (isEco ? hint : "DEEBOT Robot (\(hostname ?? candidateIp))") : hint
                                
                                return DiscoveredLocalDevice(
                                    ip: candidateIp,
                                    port: port,
                                    hostname: hostname,
                                    latencyMs: latency,
                                    modelHint: finalHint,
                                    isEcovacsLikely: isEcovacsLikely
                                )
                            }
                        }
                        return nil
                    }
                }
                
                for await dev in group {
                    completedHosts += 1
                    let progress = Float(completedHosts) / Float(totalHosts)
                    onProgress(progress)
                    if let d = dev {
                        results.append(d)
                    }
                }
            }
        }
        
        // Sắp xếp đưa các thiết bị có khả năng là Robot lên hàng đầu
        results.sort {
            if $0.isEcovacsLikely != $1.isEcovacsLikely {
                return $0.isEcovacsLikely && !$1.isEcovacsLikely
            }
            return $0.latencyMs < $1.latencyMs
        }
        
        return results
    }
    
    /// Kiểm tra nhanh một địa chỉ IP tùy ý do người dùng nhập
    public func testSpecificIP(ip: String, port: Int = 80) async -> (isOnline: Bool, latencyMs: Int, hint: String) {
        let trimmedIp = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIp.isEmpty else { return (false, 0, "IP không hợp lệ") }
        
        let portsToTry = [port, 80, 8080, 8883, 5222]
        for p in portsToTry {
            let (isOpen, latency) = await probePort(ip: trimmedIp, port: p, timeoutSec: 0.6)
            if isOpen {
                let (hint, isEco) = await inspectDeviceIdentity(ip: trimmedIp, port: p)
                let hostname = await resolveHostname(ip: trimmedIp)
                let model = isEco ? hint : (hostname != nil ? "Thiết bị: \(hostname!)" : "Thiết bị mạng (Cổng \(p))")
                return (true, latency, model)
            }
        }
        return (false, 0, "Không có phản hồi")
    }
}
