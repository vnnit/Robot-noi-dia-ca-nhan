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
        delaySeconds: TimeInterval = 0
    ) {
        guard isEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound
        
        let trigger: UNNotificationTrigger? = delaySeconds > 0 ? UNTimeIntervalNotificationTrigger(timeInterval: delaySeconds, repeats: false) : nil
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
                    body: "Hệ thống thông báo trạng thái robot trên iOS đang hoạt động hoàn hảo!"
                )
            }
        }
    }
    
    // MARK: - Bộ theo dõi trạng thái Robot thông minh (Chống spam tuyệt đối - Báo đúng 1 lần khi chuyển trạng thái)
    private var lastCleanStatePerDevice: [String: String] = [:]
    private var lastErrorCodePerDevice: [String: Int] = [:]
    private var lastStationErrorPerDevice: [String: Int] = [:]
    private var lastBatteryWarningPerDevice: [String: Bool] = [:]
    private var lastDustbinFullPerDevice: [String: Bool] = [:]
    private var lastNotificationTimestamps: [String: [String: Date]] = [:]
    
    // Cờ kiểm soát từng phiên làm việc: Đảm bảo "Bắt đầu dọn", "Về sạc", "Đã dừng" chỉ nổ đúng 1 lần duy nhất trong toàn bộ phiên
    private var hasNotifiedCleanStartPerDevice: [String: Bool] = [:]
    private var hasNotifiedPausePerDevice: [String: Bool] = [:]
    private var hasNotifiedGoChargingPerDevice: [String: Bool] = [:]
    private var hasNotifiedDockedPerDevice: [String: Bool] = [:]
    private var lastNotificationTimePerDevice: [String: Date] = [:]
    private var sessionStartTimePerDevice: [String: Date] = [:]
    
    // Serial Queue xử lý đồng bộ tránh xung đột đa luồng
    private let stateQueue = DispatchQueue(label: "com.robotnoidia.notification.stateQueue")
    
    private func canSendNotification(for did: String, eventType: String, minInterval: TimeInterval = 12.0) -> Bool {
        let now = Date()
        if let lastGlobal = lastNotificationTimePerDevice[did], now.timeIntervalSince(lastGlobal) < minInterval {
            return false
        }
        if let lastSpecific = lastNotificationTimestamps[did]?[eventType], now.timeIntervalSince(lastSpecific) < 45.0 {
            return false
        }
        return true
    }
    
    private func recordNotificationSent(for did: String, eventType: String) {
        let now = Date()
        lastNotificationTimePerDevice[did] = now
        if lastNotificationTimestamps[did] == nil {
            lastNotificationTimestamps[did] = [:]
        }
        lastNotificationTimestamps[did]?[eventType] = now
    }
    
    public func notifyQuickStatusChange(device: DeviceModel, battery: Int?, isCharging: Bool?, cleanState: String?) {
        guard isEnabled else { return }
        
        let devName = device.displayName
        let did = device.did
        
        stateQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 1. Theo dõi tiến độ dọn dẹp (Clean State) theo Session State Machine
            if let rawState = cleanState?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), !rawState.isEmpty {
                let currentCleanState = rawState
                let prevState = self.lastCleanStatePerDevice[did]
                
                // Khởi tạo trạng thái ban đầu khi mở app: ghi nhận mốc nền mà không spam thông báo giả
                guard let previous = prevState else {
                    self.lastCleanStatePerDevice[did] = currentCleanState
                    if currentCleanState == "clean" {
                        // Nếu khi mở app robot đã đang chạy, đánh dấu đã thông báo để không bao giờ spam lại
                        self.hasNotifiedCleanStartPerDevice[did] = true
                        self.sessionStartTimePerDevice[did] = Date()
                    } else if currentCleanState == "charging" {
                        self.hasNotifiedDockedPerDevice[did] = true
                    }
                    return
                }
                
                switch currentCleanState {
                case "clean":
                    let alreadyStarted = self.hasNotifiedCleanStartPerDevice[did] ?? false
                    let isResumingFromPause = (previous == "pause") || (self.hasNotifiedPausePerDevice[did] ?? false)
                    
                    if !alreadyStarted {
                        // BẮT ĐẦU PHIÊN DỌN MỚI: BÁO ĐÚNG 1 LẦN DUY NHẤT
                        if self.canSendNotification(for: did, eventType: "clean_start", minInterval: 15.0) {
                            self.sendNotification(
                                title: "🧹 \(devName) bắt đầu dọn dẹp",
                                body: "\(devName) đã rời trạm sạc và bắt đầu dọn dẹp tự động."
                            )
                            self.recordNotificationSent(for: did, eventType: "clean_start")
                            self.sessionStartTimePerDevice[did] = Date()
                            self.hasNotifiedCleanStartPerDevice[did] = true
                            self.hasNotifiedPausePerDevice[did] = false
                            self.hasNotifiedGoChargingPerDevice[did] = false
                            self.hasNotifiedDockedPerDevice[did] = false
                        }
                    } else if isResumingFromPause {
                        // TIẾP TỤC SAU KHI TẠM DỪNG: BÁO ĐÚNG 1 LẦN
                        if self.canSendNotification(for: did, eventType: "clean_resume", minInterval: 15.0) {
                            self.sendNotification(
                                title: "▶️ \(devName) tiếp tục dọn dẹp",
                                body: "Robot đã tiếp tục công việc hút bụi / lau nhà."
                            )
                            self.recordNotificationSent(for: did, eventType: "clean_resume")
                            self.hasNotifiedPausePerDevice[did] = false
                        }
                    }
                    // Nếu đã dọn dẹp liên tục: TUYỆT ĐỐI KHÔNG GỬI THÔNG BÁO GÌ CẢ
                    
                case "pause":
                    let alreadyPaused = self.hasNotifiedPausePerDevice[did] ?? false
                    if !alreadyPaused && (self.hasNotifiedCleanStartPerDevice[did] ?? false) {
                        if self.canSendNotification(for: did, eventType: "pause", minInterval: 15.0) {
                            self.sendNotification(
                                title: "⏸ \(devName) tạm dừng dọn",
                                body: "Robot đang tạm dừng dọn dẹp."
                            )
                            self.recordNotificationSent(for: did, eventType: "pause")
                            self.hasNotifiedPausePerDevice[did] = true
                        }
                    }
                    
                case "go_charging":
                    let alreadyGoCharging = self.hasNotifiedGoChargingPerDevice[did] ?? false
                    if !alreadyGoCharging {
                        if self.canSendNotification(for: did, eventType: "go_charging", minInterval: 15.0) {
                            self.sendNotification(
                                title: "🔋 \(devName) đang về trạm sạc",
                                body: "Robot đã hoàn thành dọn dẹp và đang quay về trạm sạc."
                            )
                            self.recordNotificationSent(for: did, eventType: "go_charging")
                            self.hasNotifiedGoChargingPerDevice[did] = true
                        }
                    }
                    
                case "charging":
                    let alreadyDocked = self.hasNotifiedDockedPerDevice[did] ?? false
                    let wasInSession = (self.hasNotifiedCleanStartPerDevice[did] ?? false) || (self.hasNotifiedGoChargingPerDevice[did] ?? false) || (previous == "go_charging")
                    let isTrulyCharging = isCharging ?? false
                    
                    let sessionDuration = Date().timeIntervalSince(self.sessionStartTimePerDevice[did] ?? Date())
                    // Chỉ báo về sạc khi thực sự có sạc pin VÀ đã qua ít nhất 20s kể từ lúc bắt đầu dọn hoặc previous là go_charging
                    let isLegitimateDocking = isTrulyCharging && (previous == "go_charging" || sessionDuration >= 20.0)
                    
                    if !alreadyDocked && wasInSession && isLegitimateDocking {
                        if self.canSendNotification(for: did, eventType: "charging", minInterval: 15.0) {
                            self.sendNotification(
                                title: "⚡️ \(devName) đã về trạm sạc",
                                body: "Robot đã cập bến trạm sạc an toàn và đang nạp pin."
                            )
                            self.recordNotificationSent(for: did, eventType: "charging")
                            self.hasNotifiedDockedPerDevice[did] = true
                            
                            // Reset cờ phiên dọn dẹp sau khi đã docking thành công
                            self.hasNotifiedCleanStartPerDevice[did] = false
                            self.hasNotifiedPausePerDevice[did] = false
                            self.hasNotifiedGoChargingPerDevice[did] = false
                        }
                    }
                    
                case "stop":
                    let wasCleaning = (self.hasNotifiedCleanStartPerDevice[did] ?? false)
                    if wasCleaning && previous != "stop" {
                        if self.canSendNotification(for: did, eventType: "stop", minInterval: 15.0) {
                            self.sendNotification(
                                title: "⏹ \(devName) đã dừng dọn",
                                body: "Phiên dọn dẹp của robot đã kết thúc."
                            )
                            self.recordNotificationSent(for: did, eventType: "stop")
                        }
                    }
                    // Reset cờ phiên
                    self.hasNotifiedCleanStartPerDevice[did] = false
                    self.hasNotifiedPausePerDevice[did] = false
                    self.hasNotifiedGoChargingPerDevice[did] = false
                    
                default:
                    break
                }
                
                self.lastCleanStatePerDevice[did] = currentCleanState
            }
            
            // 2. Theo dõi Pin yếu (< 15%) - Chỉ báo 1 lần duy nhất khi pin tụt dưới 15%
            if let bat = battery {
                let charging = isCharging ?? false
                let prevWarned = self.lastBatteryWarningPerDevice[did] ?? false
                if bat <= 15 && !prevWarned && !charging {
                    self.sendNotification(
                        title: "🪫 Pin yếu: \(devName)",
                        body: "Mức pin của robot còn \(bat)%. Vui lòng cho robot về trạm sạc."
                    )
                    self.lastBatteryWarningPerDevice[did] = true
                } else if bat > 20 || charging {
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
        let currentError = state.errorCode
        let currentStationError = state.stationErrorCode
        let isDustbinFull = state.dustbinFull
        
        stateQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 1. Cảnh báo lỗi robot phần cứng: CHỈ BÁO 1 LẦN KHI PHÁT SINH MÃ LỖI MỚI (> 0)
            let prevError = self.lastErrorCodePerDevice[did] ?? 0
            if currentError > 0 && currentError != prevError {
                let desc = Constants.errorDescriptions[currentError] ?? "Robot gặp sự cố hoặc mắc kẹt."
                self.sendNotification(
                    title: "⚠️ Cảnh báo sự cố: \(devName)",
                    body: "Mã lỗi #\(currentError): \(desc)"
                )
                self.lastErrorCodePerDevice[did] = currentError
            } else if currentError == 0 {
                self.lastErrorCodePerDevice[did] = 0
            }
            
            // 2. Cảnh báo Trạm sạc: Hết nước sạch hoặc bình chứa nước bẩn đã đầy (mã 314 / 101)
            let prevStationError = self.lastStationErrorPerDevice[did] ?? 0
            let effectiveStationError = (currentStationError > 0) ? currentStationError : (currentError == 314 || currentError == 101 ? currentError : 0)
            if effectiveStationError > 0 && effectiveStationError != prevStationError {
                self.sendNotification(
                    title: "⚠️ Trạm sạc \(devName): Cần thay nước",
                    body: "Hết nước sạch hoặc bình chứa nước bẩn đã đầy. Vui lòng kiểm tra hộp nước."
                )
                self.lastStationErrorPerDevice[did] = effectiveStationError
            } else if effectiveStationError == 0 {
                self.lastStationErrorPerDevice[did] = 0
            }
            
            // 3. Cảnh báo Túi gom rác đã đầy (Auto-Empty dustbag full)
            let prevDustbin = self.lastDustbinFullPerDevice[did] ?? false
            if isDustbinFull && !prevDustbin {
                self.sendNotification(
                    title: "🗑 Trạm sạc \(devName): Túi rác đã đầy",
                    body: "Túi đựng rác trong trạm hút tự động đã đầy. Vui lòng thay túi rác mới."
                )
                self.lastDustbinFullPerDevice[did] = true
            } else if !isDustbinFull {
                self.lastDustbinFullPerDevice[did] = false
            }
        }
    }
    
    // MARK: - Nhắc nhở bảo dưỡng phụ kiện định kỳ (< 5% tuổi thọ)
    public func notifyConsumablesChange(device: DeviceModel, consumables: ConsumablesData) {
        guard isEnabled else { return }
        let devName = device.displayName
        let did = device.did
        let now = Date()
        
        stateQueue.async { [weak self] in
            guard let self = self else { return }
            for item in consumables.allItems {
                if item.percent < 5 {
                    let key = "consumable_\(item.id)"
                    var shouldSend = true
                    if let lastDate = self.lastNotificationTimestamps[did]?[key] {
                        shouldSend = now.timeIntervalSince(lastDate) >= 86400 // Cooldown 24 tiếng chống spam
                    }
                    if shouldSend {
                        if self.lastNotificationTimestamps[did] == nil {
                            self.lastNotificationTimestamps[did] = [:]
                        }
                        self.lastNotificationTimestamps[did]?[key] = now
                        self.sendNotification(
                            title: "🛠 Nhắc nhở bảo dưỡng: \(devName)",
                            body: "\(item.type.title) chỉ còn \(item.percent)% tuổi thọ (\(item.leftHours)h). Vui lòng vệ sinh hoặc thay thế linh kiện."
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    // Đảm bảo Banner và Âm thanh hiển thị kể cả khi ứng dụng đang mở (Foreground)
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge, .list])
    }
}
