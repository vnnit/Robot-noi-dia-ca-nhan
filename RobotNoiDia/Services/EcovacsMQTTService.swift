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
            sec_protocol_verify_complete(true) // Cho phép TLS self-signed hoặc chứng chỉ nội địa
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
        let topics = [
            "iot/atr/+/\(device.did)/\(device.deviceClass)/\(device.resource)/j",
            "iot/p2p/+/\(device.did)/\(device.deviceClass)/\(device.resource)/+/+/+/p/+/j"
        ]
        for topic in topics {
            sendSubscribePacket(topic: topic)
        }
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
                DispatchQueue.main.async { self.isConnected = true }
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
            // Phân tích topic và payload
            if data.count > 4 {
                let topicLen = Int(data[2]) << 8 | Int(data[3])
                if data.count >= 4 + topicLen {
                    let topicData = data.subdata(in: 4..<(4 + topicLen))
                    let topic = String(data: topicData, encoding: .utf8) ?? ""
                    let payloadData = data.subdata(in: (4 + topicLen)..<data.count)
                    DispatchQueue.main.async {
                        self.lastMessageTopic = topic
                        self.onMessageReceived?(topic, payloadData)
                    }
                }
            }
        default:
            break
        }
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
