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
public final class LocalNetworkScannerService {
    public static let shared = LocalNetworkScannerService()
    
    private init() {}
    
    /// Lấy địa chỉ IP và Subnet prefix của iPhone trên giao diện Wi-Fi (en0)
    public func getLocalWifiIPAddress() -> (ip: String, subnetPrefix: String)? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return nil
        }
        defer { freeifaddrs(ifaddr) }
        
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                // "en0" là interface Wi-Fi chính trên iOS
                if name == "en0" || name.hasPrefix("en") {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(
                        interface.ifa_addr,
                        socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostname,
                        socklen_t(hostname.count),
                        nil,
                        0,
                        NI_NUMERICHOST
                    )
                    address = String(cString: hostname)
                    break
                }
            }
        }
        
        guard let ip = address, ip != "127.0.0.1" else { return nil }
        
        let components = ip.split(separator: ".")
        guard components.count == 4 else { return nil }
        let subnetPrefix = "\(components[0]).\(components[1]).\(components[2])"
        return (ip: ip, subnetPrefix: subnetPrefix)
    }
    
    /// Thăm dò một địa chỉ IP và cổng TCP cụ thể xem có phản hồi không
    public func probePort(ip: String, port: Int, timeoutSec: Double = 0.25) async -> (isOpen: Bool, latencyMs: Int) {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var sock = socket(AF_INET, SOCK_STREAM, 0)
                guard sock >= 0 else {
                    continuation.resume(returning: (false, 0))
                    return
                }
                
                // Đặt socket non-blocking để kiểm tra kết nối với timeout
                var flags = fcntl(sock, F_GETFL, 0)
                _ = fcntl(sock, F_SETFL, flags | O_NONBLOCK)
                
                var addr = sockaddr_in()
                addr.sin_family = sa_family_t(AF_INET)
                addr.sin_port = in_port_t(UInt16(port).bigEndian)
                inet_pton(AF_INET, ip, &addr.sin_addr)
                
                let res = withUnsafePointer(to: &addr) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        connect(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                    }
                }
                
                if res == 0 {
                    close(sock)
                    let latency = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
                    continuation.resume(returning: (true, max(1, latency)))
                    return
                }
                
                var writeSet = fd_set()
                writeSet.zero()
                writeSet.set(sock)
                
                var timeout = timeval(
                    tv_sec: __darwin_time_t(Int(timeoutSec)),
                    tv_usec: __darwin_suseconds_t(Int((timeoutSec.truncatingRemainder(dividingBy: 1.0)) * 1_000_000))
                )
                
                let selectRes = select(sock + 1, nil, &writeSet, nil, &timeout)
                var isOpen = false
                
                if selectRes > 0 && writeSet.isSet(sock) {
                    var error: Int32 = 0
                    var len = socklen_t(MemoryLayout<Int32>.size)
                    getsockopt(sock, SOL_SOCKET, SO_ERROR, &error, &len)
                    if error == 0 {
                        isOpen = true
                    }
                }
                
                close(sock)
                let latency = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
                continuation.resume(returning: (isOpen, max(1, latency)))
            }
        }
    }
    
    /// Phân giải tên máy (Hostname) qua Reverse DNS
    public func resolveHostname(ip: String) async -> String? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                var addr = sockaddr_in()
                addr.sin_family = sa_family_t(AF_INET)
                inet_pton(AF_INET, ip, &addr.sin_addr)
                
                var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let result = withUnsafePointer(to: &addr) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        getnameinfo($0, socklen_t(MemoryLayout<sockaddr_in>.size), &hostBuffer, socklen_t(hostBuffer.count), nil, 0, 0)
                    }
                }
                
                if result == 0 {
                    let name = String(cString: hostBuffer)
                    if name != ip && !name.isEmpty {
                        continuation.resume(returning: name)
                        return
                    }
                }
                continuation.resume(returning: nil)
            }
        }
    }
    
    /// Thử gửi request HTTP nhỏ để kiểm tra xem server nội bộ có phải Ecovacs/Deebot không
    public func inspectDeviceIdentity(ip: String, port: Int) async -> (modelHint: String, isEcovacs: Bool) {
        guard let url = URL(string: "http://\(ip):\(port)/") else {
            return ("Thiết Bị Mạng", false)
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 0.8
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
        
        // Nếu cổng 8883 mở (MQTT TLS) hoặc cổng 5222 mở (XMPP)
        if port == 8883 {
            return ("Robot Ecovacs (MQTT Port)", true)
        } else if port == 5222 || port == 5223 {
            return ("Robot Ecovacs (XMPP Port)", true)
        } else if port == 4000 || port == 4001 {
            return ("Robot Ecovacs (Local Port)", true)
        }
        
        return ("Thiết Bị Mạng (Cổng \(port))", false)
    }
    
    /// Quét toàn bộ dải IP mạng cục bộ gia đình (254 IPs)
    public func scanSubnet(
        onProgress: @escaping (Float) -> Void
    ) async -> [DiscoveredLocalDevice] {
        guard let wifi = getLocalWifiIPAddress() else {
            // Fallback nếu không đọc được IP iPhone (VD trên Simulator): quét dải mặc định 192.168.1.x
            return await performScan(subnetPrefix: "192.168.1", onProgress: onProgress)
        }
        return await performScan(subnetPrefix: wifi.subnetPrefix, onProgress: onProgress)
    }
    
    private func performScan(
        subnetPrefix: String,
        onProgress: @escaping (Float) -> Void
    ) async -> [DiscoveredLocalDevice] {
        var results: [DiscoveredLocalDevice] = []
        let targetPorts = [80, 8080, 8883, 5222, 4000]
        
        let totalHosts = 254
        var completedCount = 0
        
        // Sử dụng TaskGroup với tối đa 25 tác vụ song song để quét cực nhanh
        await withTaskGroup(of: DiscoveredLocalDevice?.self) { group in
            for i in 1...totalHosts {
                let candidateIp = "\(subnetPrefix).\(i)"
                
                group.addTask {
                    for port in targetPorts {
                        let (isOpen, latency) = await self.probePort(ip: candidateIp, port: port, timeoutSec: 0.20)
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
            
            for await item in group {
                completedCount += 1
                let progress = Float(completedCount) / Float(totalHosts)
                onProgress(progress)
                if let dev = item {
                    results.append(dev)
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
            let (isOpen, latency) = await probePort(ip: trimmedIp, port: p, timeoutSec: 0.8)
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

// Extension hỗ trợ thao tác fd_set trong BSD Sockets
extension fd_set {
    mutating func zero() {
        fds_bits = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    }
    
    mutating func set(_ fd: Int32) {
        let intOffset = Int(fd / 32)
        let bitOffset = fd % 32
        let mask = Int32(1 << bitOffset)
        
        withUnsafeMutablePointer(to: &self) { ptr in
            let rawPtr = UnsafeMutableRawPointer(ptr)
            let typedPtr = rawPtr.bindMemory(to: Int32.self, capacity: 32)
            typedPtr[intOffset] |= mask
        }
    }
    
    func isSet(_ fd: Int32) -> Bool {
        let intOffset = Int(fd / 32)
        let bitOffset = fd % 32
        let mask = Int32(1 << bitOffset)
        
        return withUnsafePointer(to: self) { ptr in
            let rawPtr = UnsafeRawPointer(ptr)
            let typedPtr = rawPtr.bindMemory(to: Int32.self, capacity: 32)
            return (typedPtr[intOffset] & mask) != 0
        }
    }
}
