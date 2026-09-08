import Foundation
import UserNotifications

/// Quản lý Hệ thống Thông báo Nội bộ iOS (Local Notifications)
/// Tự động hiển thị Banner & Âm thanh trên màn hình khóa hoặc khi đang mở app
public final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    public static let shared = NotificationManager()
    
    private let userDefaults = UserDefaults.standard
    private let keyEnabled = "ios_robot_notifications_enabled"
    
    public var isEnabled: Bool {
        get {
            if userDefaults.object(forKey: keyEnabled) == nil {
                return true // Mặc định bật
            }
            return userDefaults.bool(forKey: keyEnabled)
        }
        set {
            userDefaults.set(newValue, forKey: keyEnabled)
            if newValue {
                requestPermission()
            }
        }
    }
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    // MARK: - Xin quyền thông báo iOS
    public func requestPermission(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("[NotificationManager] Lỗi xin quyền: \(error)")
                }
                completion?(granted)
            }
        }
    }
    
    // MARK: - Gửi thông báo ngay
    public func sendNotification(
        title: String,
        body: String,
        sound: UNNotificationSound = .default,
        delaySeconds: TimeInterval = 0.5
    ) {
        guard isEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(0.1, delaySeconds), repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[NotificationManager] Không thể thêm thông báo: \(error)")
            }
        }
    }
    
    // MARK: - Gửi thông báo kiểm tra (Test Notification)
    public func sendTestNotification() {
        requestPermission { [weak self] granted in
            guard let self = self else { return }
            if granted {
                self.sendNotification(
                    title: "🔔 Thông báo Robot Nội Địa",
                    body: "Hệ thống thông báo trạng thái robot trên iOS đang hoạt động hoàn hảo!",
                    delaySeconds: 1.0
                )
            }
        }
    }
    
    // MARK: - Bộ theo dõi trạng thái Robot thông minh (Chống spam)
    private var lastCleanStatePerDevice: [String: String] = [:]
    private var lastErrorCodePerDevice: [String: Int] = [:]
    private var lastBatteryWarningPerDevice: [String: Bool] = [:]
    
    public func notifyQuickStatusChange(device: DeviceModel, battery: Int?, isCharging: Bool?, cleanState: String?) {
        guard isEnabled else { return }
        
        let devName = device.displayName
        let did = device.did
        
        // 1. Theo dõi tiến độ dọn dẹp (Clean State)
        if let currentCleanState = cleanState {
            let previousCleanState = lastCleanStatePerDevice[did]
            if let prev = previousCleanState, prev != currentCleanState {
                switch currentCleanState {
                case "clean":
                    sendNotification(
                        title: "🧹 \(devName) bắt đầu dọn dẹp",
                        body: "\(devName) đã rời trạm sạc và bắt đầu dọn dẹp tự động."
                    )
                case "pause":
                    sendNotification(
                        title: "⏸ \(devName) tạm dừng",
                        body: "Robot đang tạm dừng dọn dẹp."
                    )
                case "go_charging":
                    sendNotification(
                        title: "🔋 \(devName) hoàn thành & về trạm",
                        body: "Robot đã làm sạch xong và đang trên đường quay về trạm sạc."
                    )
                case "charging":
                    if prev == "go_charging" || prev == "clean" {
                        sendNotification(
                            title: "⚡️ \(devName) đã về trạm sạc",
                            body: "Robot đã cập bến trạm sạc an toàn và đang nạp pin."
                        )
                    }
                case "stop":
                    if prev == "clean" {
                        sendNotification(
                            title: "⏹ \(devName) đã dừng dọn",
                            body: "Phiên dọn dẹp của robot đã kết thúc."
                        )
                    }
                default:
                    break
                }
            }
            lastCleanStatePerDevice[did] = currentCleanState
        }
        
        // 2. Theo dõi Pin yếu
        if let bat = battery {
            let charging = isCharging ?? false
            let prevWarned = lastBatteryWarningPerDevice[did] ?? false
            if bat <= 15 && !prevWarned && !charging {
                sendNotification(
                    title: "🪫 Pin yếu: \(devName)",
                    body: "Mức pin của robot còn dưới \(bat)%. Vui lòng cho robot về trạm sạc."
                )
                lastBatteryWarningPerDevice[did] = true
            } else if bat > 20 {
                lastBatteryWarningPerDevice[did] = false
            }
        }
    }
    
    public func notifyStateChange(device: DeviceModel, state: DeviceState) {
        guard isEnabled else { return }
        
        // Kiểm tra dọn dẹp và pin
        notifyQuickStatusChange(
            device: device,
            battery: state.batteryPercent,
            isCharging: state.isCharging,
            cleanState: state.cleanState
        )
        
        let devName = device.displayName
        let did = device.did
        
        // Theo dõi Báo sự cố / Báo lỗi phần cứng (Hardware error)
        let prevError = lastErrorCodePerDevice[did] ?? 0
        let currentError = state.errorCode
        
        if currentError != prevError && currentError > 0 {
            let desc = Constants.errorDescriptions[currentError] ?? "Robot gặp sự cố hoặc mắc kẹt."
            sendNotification(
                title: "⚠️ Cảnh báo sự cố: \(devName)",
                body: "Mã lỗi \(currentError): \(desc)"
            )
        }
        lastErrorCodePerDevice[did] = currentError
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    // Đảm bảo Banner và Âm thanh hiển thị kể cả khi ứng dụng đang mở (Foreground)
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}
