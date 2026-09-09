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
    
    // MARK: - Bộ theo dõi trạng thái Robot thông minh (Chống spam tuyệt đối)
    // 1. Khóa phiên dọn dẹp (Session Lock): Chỉ báo "Bắt đầu dọn dẹp" 1 lần duy nhất trong toàn bộ phiên
    private var isCleaningSessionActive: [String: Bool] = [:]
    
    // 2. Thời điểm gửi thông báo gần nhất (did -> [type: Date]) để chống gửi trùng lặp
    private var lastNotificationTimestamps: [String: [String: Date]] = [:]
    
    // 3. Trạng thái dọn dẹp gần nhất
    private var lastCleanStatePerDevice: [String: String] = [:]
    private var lastErrorCodePerDevice: [String: Int] = [:]
    private var lastBatteryWarningPerDevice: [String: Bool] = [:]
    
    // 4. Timer lọc bỏ tạm dừng ảo (khi robot dừng vài giây quét LiDAR dò bản đồ lúc mới xuất phát)
    private var pendingPauseWorkItems: [String: DispatchWorkItem] = [:]
    
    // 5. Serial Queue xử lý đồng bộ tránh xung đột đa luồng
    private let stateQueue = DispatchQueue(label: "com.robotnoidia.notification.stateQueue")
    
    public func notifyQuickStatusChange(device: DeviceModel, battery: Int?, isCharging: Bool?, cleanState: String?) {
        guard isEnabled else { return }
        
        let devName = device.displayName
        let did = device.did
        
        stateQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 1. Theo dõi tiến độ dọn dẹp (Clean State)
            if let rawState = cleanState?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), !rawState.isEmpty {
                let currentCleanState = rawState
                let sessionActive = self.isCleaningSessionActive[did] ?? false
                let now = Date()
                
                let canNotify = { (type: String, minInterval: TimeInterval) -> Bool in
                    if let lastDate = self.lastNotificationTimestamps[did]?[type] {
                        return now.timeIntervalSince(lastDate) >= minInterval
                    }
                    return true
                }
                
                let markNotified = { (type: String) in
                    if self.lastNotificationTimestamps[did] == nil {
                        self.lastNotificationTimestamps[did] = [:]
                    }
                    self.lastNotificationTimestamps[did]?[type] = now
                }
                
                switch currentCleanState {
                case "clean":
                    // Robot đang chạy: HỦY ngay timer báo tạm dừng nếu có (robot đã tiếp tục dọn)
                    self.pendingPauseWorkItems[did]?.cancel()
                    self.pendingPauseWorkItems[did] = nil
                    
                    // CHỈ BÁO "Bắt đầu dọn dẹp" 1 LẦN DUY NHẤT KHI MỚI BẮT ĐẦU PHIÊN!
                    // Nếu đã trong phiên dọn dẹp (sessionActive == true), TUYỆT ĐỐI KHÔNG BÁO LẠI khi robot dừng dò bản đồ rồi chạy tiếp!
                    if !sessionActive && canNotify("clean", 120) {
                        self.isCleaningSessionActive[did] = true
                        markNotified("clean")
                        self.sendNotification(
                            title: "🧹 \(devName) bắt đầu dọn dẹp",
                            body: "\(devName) đã rời trạm sạc và bắt đầu dọn dẹp tự động."
                        )
                    }
                    
                case "pause":
                    // Khi robot rời trạm và dừng vài giây để quét laser LiDAR / định vị bản đồ,
                    // firmware Ecovacs thường phát trạng thái pause ngắn.
                    // Chúng ta đợi 12 giây: chỉ khi robot thực sự dừng hẳn quá 12s mới gửi thông báo!
                    if sessionActive && canNotify("pause", 60) && self.pendingPauseWorkItems[did] == nil {
                        let workItem = DispatchWorkItem { [weak self] in
                            guard let self = self else { return }
                            self.stateQueue.async {
                                if self.lastCleanStatePerDevice[did] == "pause" {
                                    markNotified("pause")
                                    self.sendNotification(
                                        title: "⏸ \(devName) tạm dừng",
                                        body: "Robot đang tạm dừng dọn dẹp."
                                    )
                                }
                                self.pendingPauseWorkItems[did] = nil
                            }
                        }
                        self.pendingPauseWorkItems[did] = workItem
                        DispatchQueue.global().asyncAfter(deadline: .now() + 12.0, execute: workItem)
                    }
                    
                case "go_charging":
                    self.pendingPauseWorkItems[did]?.cancel()
                    self.pendingPauseWorkItems[did] = nil
                    
                    if sessionActive && canNotify("go_charging", 60) {
                        markNotified("go_charging")
                        self.sendNotification(
                            title: "🔋 \(devName) hoàn thành & về trạm",
                            body: "Robot đã làm sạch xong và đang trên đường quay về trạm sạc."
                        )
                    }
                    
                case "charging":
                    self.pendingPauseWorkItems[did]?.cancel()
                    self.pendingPauseWorkItems[did] = nil
                    
                    // Robot đã về trạm sạc -> KẾT THÚC PHIÊN DỌN DẸP
                    if sessionActive {
                        self.isCleaningSessionActive[did] = false
                        if canNotify("charging", 60) {
                            markNotified("charging")
                            self.sendNotification(
                                title: "⚡️ \(devName) đã về trạm sạc",
                                body: "Robot đã cập bến trạm sạc an toàn và đang nạp pin."
                            )
                        }
                    }
                    
                case "stop":
                    self.pendingPauseWorkItems[did]?.cancel()
                    self.pendingPauseWorkItems[did] = nil
                    
                    // Dừng dọn hẳn
                    if sessionActive {
                        self.isCleaningSessionActive[did] = false
                        if canNotify("stop", 60) {
                            markNotified("stop")
                            self.sendNotification(
                                title: "⏹ \(devName) đã dừng dọn",
                                body: "Phiên dọn dẹp của robot đã kết thúc."
                            )
                        }
                    }
                    
                default:
                    break
                }
                
                self.lastCleanStatePerDevice[did] = currentCleanState
            }
            
            // 2. Theo dõi Pin yếu
            if let bat = battery {
                let charging = isCharging ?? false
                let prevWarned = self.lastBatteryWarningPerDevice[did] ?? false
                if bat <= 15 && !prevWarned && !charging {
                    self.sendNotification(
                        title: "🪫 Pin yếu: \(devName)",
                        body: "Mức pin của robot còn dưới \(bat)%. Vui lòng cho robot về trạm sạc."
                    )
                    self.lastBatteryWarningPerDevice[did] = true
                } else if bat > 20 {
                    self.lastBatteryWarningPerDevice[did] = false
                }
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
        let currentError = state.errorCode
        stateQueue.async { [weak self] in
            guard let self = self else { return }
            let prevError = self.lastErrorCodePerDevice[did] ?? 0
            if currentError != prevError && currentError > 0 {
                let desc = Constants.errorDescriptions[currentError] ?? "Robot gặp sự cố hoặc mắc kẹt."
                self.sendNotification(
                    title: "⚠️ Cảnh báo sự cố: \(devName)",
                    body: "Mã lỗi \(currentError): \(desc)"
                )
            }
            self.lastErrorCodePerDevice[did] = currentError
        }
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
