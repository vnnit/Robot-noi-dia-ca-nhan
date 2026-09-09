import Foundation
import Network

/// Dịch vụ kết nối trực tiếp MQTT Broker `iot-cn.ecovacs.com:8883` trên iPhone bằng Apple Network.framework
/// Nhận các gói tin sự kiện thời gian thực (MapChangedEvent, StateEvent, BatteryEvent) trực tiếp từ robot.
public final class EcovacsMQTTService: ObservableObject {
    public static let shared = EcovacsMQTTService()
    
    @Published public var isConnected: Bool = false
    @Published public var lastMessageTopic: String = ""
    
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.robot.noidia.mqtt", qos: .userInitiated)
    private var isConnecting = false
    private var pingTimer: Timer?
    
    public var onMessageReceived: ((String, Data) -> Void)?
    
    private init() {}
    
    // MARK: - Tự động kết nối bằng thông tin đã lưu
    public func connectWithSavedCredentials() {
        let km = KeychainManager.shared
        guard let uid = km.userId, let tok = km.token, !uid.isEmpty, !tok.isEmpty else { return }
        connect(userId: uid, token: tok, deviceId: km.deviceId)
    }
    
    // MARK: - Kết nối MQTT qua TLS
    public func connect(userId: String, token: String, deviceId: String) {
        guard !isConnected && !isConnecting else { return }
        isConnecting = true
        
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(Constants.mqttBrokerHost),
            port: NWEndpoint.Port(rawValue: Constants.mqttBrokerPort)!
        )
        
        let tlsOptions = NWProtocolTLS.Options()
        sec_protocol_options_set_verify_block(tlsOptions.securityProtocolOptions, { (_, _, sec_protocol_verify_complete) in
            sec_protocol_verify_complete(true) // Cho phép chứng chỉ nội địa Ecovacs
        }, queue)
        
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.enableKeepalive = true
        tcpOptions.keepaliveIdle = 30
        
        let params = NWParameters(tls: tlsOptions, tcp: tcpOptions)
        let conn = NWConnection(to: endpoint, using: params)
        self.connection = conn
        
        conn.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                print("[MQTT] Đã thiết lập kết nối TCP/TLS tới \(Constants.mqttBrokerHost)")
                self.sendConnectPacket(userId: userId, token: token, deviceId: deviceId)
                self.startReceiving()
            case .failed(let err):
                print("[MQTT] Kết nối thất bại: \(err)")
                self.disconnect()
            case .cancelled:
                self.disconnect()
            default:
                break
            }
        }
        
        conn.start(queue: queue)
    }
    
    public func disconnect() {
        isConnecting = false
        DispatchQueue.main.async { self.isConnected = false }
        pingTimer?.invalidate()
        pingTimer = nil
        connection?.cancel()
        connection = nil
    }
    
    // MARK: - Subscribe vào thiết bị
    public func subscribeToDevice(device: DeviceModel) {
        guard isConnected else {
            // Nếu chưa kết nối, kết nối ngay rồi subscribe sau
            connectWithSavedCredentials()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.subscribeToDevice(device: device)
            }
            return
        }
        
        let topics = [
            "iot/atr/+/\(device.did)/\(device.deviceClass)/\(device.resource)/j",
            "iot/atr/+/\(device.did)/+/+/j",
            "iot/p2p/+/\(device.did)/\(device.deviceClass)/\(device.resource)/+/+/+/p/+/j",
            "iot/p2p/+/+/+/+/\(device.did)/\(device.deviceClass)/\(device.resource)/p/+/j",
            "iot/p2p/+/\(device.did)/#"
        ]
        for topic in topics {
            sendSubscribePacket(topic: topic)
        }
        print("[MQTT] Đã đăng ký lắng nghe sự kiện của Robot: \(device.displayName)")
    }
    
    // MARK: - Phát lệnh tức thời trực tiếp qua Socket MQTT (Zero-HTTP Overhead)
    @discardableResult
    public func publishCommand(
        device: DeviceModel,
        cmdName: String,
        payloadArgs: [String: Any] = [:],
        priority: String = "1"
    ) -> Bool {
        guard isConnected, let conn = connection, conn.state == .ready else {
            return false
        }
        
        let km = KeychainManager.shared
        guard let userId = km.userId, !userId.isEmpty else { return false }
        let deviceId = km.deviceId
        
        let reqId = String(UUID().uuidString.prefix(8)).lowercased()
        let topic = "iot/p2p/\(cmdName)/\(userId)/ecouser/\(deviceId)/\(device.did)/\(device.deviceClass)/\(device.resource)/q/\(reqId)/j"
        
        let payloadDict: [String: Any] = [
            "header": [
                "pri": Int(priority) ?? 1,
                "ts": Int(Date().timeIntervalSince1970),
                "tzm": 480,
                "ver": "0.0.50"
            ],
            "body": [
                "data": payloadArgs
            ]
        ]
        
        guard let payloadData = try? JSONSerialization.data(withJSONObject: payloadDict) else {
            return false
        }
        
        let topicData = encodeMqttString(topic)
        let remainingLength = topicData.count + payloadData.count
        
        var packet = Data([0x30]) // PUBLISH QoS 0
        packet.append(encodeRemainingLength(remainingLength))
        packet.append(topicData)
        packet.append(payloadData)
        
        sendRaw(packet)
        print("[MQTT] ⚡ Đã phát lệnh tức thời qua Socket: \(cmdName) -> \(device.displayName)")
        return true
    }
    
    // MARK: - Packet Builders (MQTT 3.1.1)
    private func sendConnectPacket(userId: String, token: String, deviceId: String) {
        let clientId = "\(userId)@ecouser/\(deviceId)"
        
        var variableHeader = Data([
            0x00, 0x04, 0x4D, 0x51, 0x54, 0x54, // Protocol Name "MQTT"
            0x04,                               // Level 4 (MQTT 3.1.1)
            0xC2,                               // Connect Flags: User, Password, Clean Session
            0x00, 0x3C                          // Keep Alive 60s
        ])
        
        var payload = Data()
        payload.append(encodeMqttString(clientId))
        payload.append(encodeMqttString(userId))
        payload.append(encodeMqttString(token))
        
        var packet = Data([0x10]) // CONNECT
        packet.append(encodeRemainingLength(variableHeader.count + payload.count))
        packet.append(variableHeader)
        packet.append(payload)
        
        sendRaw(packet)
    }
    
    private func sendSubscribePacket(topic: String) {
        var variableHeader = Data([0x00, 0x01]) // Packet ID = 1
        var payload = encodeMqttString(topic)
        payload.append(0x00) // QoS 0
        
        var packet = Data([0x82]) // SUBSCRIBE
        packet.append(encodeRemainingLength(variableHeader.count + payload.count))
        packet.append(variableHeader)
        packet.append(payload)
        
        sendRaw(packet)
    }
    
    private func sendPing() {
        let pingPacket = Data([0xC0, 0x00]) // PINGREQ
        sendRaw(pingPacket)
    }
    
    private func sendRaw(_ data: Data) {
        connection?.send(content: data, completion: .contentProcessed({ error in
            if let error = error {
                print("[MQTT] Lỗi gửi dữ liệu: \(error)")
            }
        }))
    }
    
    // MARK: - Nhận dữ liệu
    private func startReceiving() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            if let data = data, !data.isEmpty {
                self.handleIncomingData(data)
            }
            if error == nil && !isComplete {
                self.startReceiving()
            } else {
                self.disconnect()
            }
        }
    }
    
    private func handleIncomingData(_ data: Data) {
        guard let firstByte = data.first else { return }
        let packetType = (firstByte >> 4)
        
        switch packetType {
        case 2: // CONNACK
            if data.count >= 4 && data[3] == 0 {
                DispatchQueue.main.async {
                    self.isConnected = true
                    print("[MQTT] Xác thực thành công với Broker! Sẵn sàng nhận dữ liệu trực tiếp.")
                }
                self.isConnecting = false
                // Bắt đầu gửi keep-alive ping mỗi 30s
                DispatchQueue.main.async {
                    self.pingTimer?.invalidate()
                    self.pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
                        self?.sendPing()
                    }
                }
            }
        case 3: // PUBLISH
            var offset = 1
            var multiplier = 1
            var remainingLength = 0
            while offset < data.count {
                let digit = Int(data[offset])
                remainingLength += (digit & 0x7F) * multiplier
                multiplier *= 128
                offset += 1
                if (digit & 0x80) == 0 { break }
            }
            
            if offset + 2 <= data.count {
                let topicLen = Int(data[offset]) << 8 | Int(data[offset + 1])
                offset += 2
                if offset + topicLen <= data.count {
                    let topicData = data.subdata(in: offset..<(offset + topicLen))
                    let topic = String(data: topicData, encoding: .utf8) ?? ""
                    offset += topicLen
                    
                    let qos = (firstByte >> 1) & 0x03
                    if qos > 0 {
                        offset += 2
                    }
                    
                    if offset <= data.count {
                        let payloadData = data.subdata(in: offset..<data.count)
                        DispatchQueue.main.async {
                            self.lastMessageTopic = topic
                            self.onMessageReceived?(topic, payloadData)
                            self.handleRobotEvent(topic: topic, payload: payloadData)
                        }
                    }
                }
            }
        default:
            break
        }
    }
    
    private func handleRobotEvent(topic: String, payload: Data) {
        guard let json = (try? JSONSerialization.jsonObject(with: payload)) as? [String: Any] else { return }
        var bodyData: [String: Any] = [:]
        if let body = json["body"] as? [String: Any], let d = body["data"] as? [String: Any] {
            bodyData = d
        } else if let d = json["data"] as? [String: Any] {
            bodyData = d
        }
        
        NotificationCenter.default.post(
            name: NSNotification.Name("EcovacsRobotEventReceived"),
            object: nil,
            userInfo: [
                "topic": topic,
                "data": bodyData
            ]
        )
    }
    
    // MARK: - MQTT Encoding Utilities
    private func encodeMqttString(_ str: String) -> Data {
        let utf8 = str.data(using: .utf8) ?? Data()
        var data = Data([UInt8(utf8.count >> 8), UInt8(utf8.count & 0xFF)])
        data.append(utf8)
        return data
    }
    
    private func encodeRemainingLength(_ length: Int) -> Data {
        var data = Data()
        var len = length
        repeat {
            var encodedByte = UInt8(len % 128)
            len /= 128
            if len > 0 {
                encodedByte |= 128
            }
            data.append(encodedByte)
        } while len > 0
        return data
    }
}
