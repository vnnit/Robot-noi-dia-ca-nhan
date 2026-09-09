import Foundation
import SwiftUI

public enum ControlTab: String, CaseIterable, Identifiable {
    case controls = "controls"
    case consumables = "consumables"
    case map = "map"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .controls: return "Điều khiển"
        case .consumables: return "Phụ kiện"
        case .map: return "Bản đồ"
        }
    }
    
    public var icon: String {
        switch self {
        case .controls: return "slider.horizontal.3"
        case .consumables: return "wrench.and.screwdriver"
        case .map: return "map"
        }
    }
}

@MainActor
public final class RobotControlViewModel: ObservableObject {
    @Published public var device: DeviceModel
    
    @Published public var state: DeviceState = .initial
    @Published public var consumables: ConsumablesData = .default
    @Published public var svgMap: String? = nil
    @Published public var mapId: String? = nil
    @Published public var mapCoverageM2: Int? = nil
    @Published public var selectedTab: ControlTab = .controls
    
    // Thuộc tính điều khiển chi tiết theo Hình 2, 3, 4
    @Published public var cleanModeTab: String = "auto" // "area", "auto", "custom"
    @Published public var cleaningPreference: String = "standard" // "standard", "customize"
    @Published public var cleanTimes: Int = 1 // 1 hoặc 2 lần
    @Published public var moppingMode: String = "standard" // "standard" hoặc "deep"
    @Published public var edgeDeepCleaning: Bool = true
    @Published public var doNotDisturb: Bool = false
    @Published public var showMoreSettings: Bool = false
    
    @Published public var isExecutingCommand: Bool = false
    @Published public var isMapLoading: Bool = false
    @Published public var toastMessage: String? = nil
    @Published public var showToast: Bool = false
    
    // MARK: - Nhật ký vệ sinh & Thống kê trọn đời
    @Published public var cleaningLogs: [CleaningLogItem] = []
    @Published public var cleaningStats: CleaningStatsModel? = nil
    @Published public var isLogsLoading: Bool = false
    @Published public var showCleaningLogSheet: Bool = false
    
    private let deviceService = EcovacsDeviceService.shared
    private var pollingTask: Task<Void, Never>?
    
    public init(device: DeviceModel) {
        self.device = device
        setupMqttListener()
    }
    
    private func setupMqttListener() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("EcovacsRobotEventReceived"),
            object: nil,
            queue: .main
        ) { [weak self] notif in
            guard let self = self,
                  let userInfo = notif.userInfo,
                  let topic = userInfo["topic"] as? String,
                  let data = userInfo["data"] as? [String: Any] else { return }
            
            if topic.contains(self.device.did) {
                self.processLiveMqttEvent(topic: topic, data: data)
            }
        }
    }
    
    private func processLiveMqttEvent(topic: String, data: [String: Any]) {
        if topic.contains("onBattery") || topic.contains("getBattery") {
            if let val = data["value"] as? Int { self.state.batteryPercent = val }
            if let low = data["isLow"] as? Bool { self.state.isLowBattery = low }
        } else if topic.contains("onCleanInfo") || topic.contains("getCleanInfo") {
            if let a = (data["area"] as? NSNumber)?.doubleValue { self.state.cleanAreaM2 = a }
            if let t = (data["time"] as? NSNumber)?.intValue { self.state.cleanDurationSec = t }
            if let st = data["state"] as? String {
                self.state.cleanState = st
                switch st {
                case "clean": self.state.cleanStateText = "Đang dọn dẹp"
                case "pause": self.state.cleanStateText = "Đang tạm dừng"
                case "stop": self.state.cleanStateText = "Đã dừng dọn"
                case "go_charging": self.state.cleanStateText = "Đang về trạm sạc"
                case "charging":
                    self.state.cleanStateText = "Đang sạc pin"
                    self.state.isCharging = true
                case "error": self.state.cleanStateText = "Báo lỗi"
                default:
                    self.state.cleanStateText = self.state.isCharging ? "Đang sạc pin tại trạm" : "Nghỉ ngơi / Chờ lệnh"
                }
            }
        } else if topic.contains("onChargeState") || topic.contains("getChargeState") {
            if let ch = data["isCharging"] as? Bool { self.state.isCharging = ch }
            if let m = data["mode"] as? String { self.state.chargeMode = m }
            self.state.chargeText = self.state.isCharging ? "Đang sạc pin tại trạm" : "Đang sử dụng pin"
        } else if topic.contains("onPos") || topic.contains("getPos") {
            if let dPos = data["deebotPos"] as? [String: Any] {
                let x = (dPos["x"] as? NSNumber)?.doubleValue ?? 0.0
                let y = (dPos["y"] as? NSNumber)?.doubleValue ?? 0.0
                let a = (dPos["a"] as? NSNumber)?.doubleValue ?? 0.0
                self.recordNewRobotPosition(x: x, y: y, angle: a)
            }
        } else if topic.contains("onError") || topic.contains("getError") {
            if let code = data["code"] as? Int {
                self.state.errorCode = code
                self.state.errorText = Constants.errorDescriptions[code] ?? "Mã lỗi #\(code)"
            }
        }
        NotificationManager.shared.notifyStateChange(device: self.device, state: self.state)
    }
    
    public func renameRobot(newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        device.nick = trimmed.isEmpty ? nil : trimmed
        device.saveCustomName(trimmed)
        let updated = device
        self.device = updated
        showToastNotification("Đã đổi tên robot thành: \(device.displayName)")
    }
    
    public func onAppear() {
        // 1. Kích hoạt Socket MQTT lắng nghe trực tiếp sự kiện thời gian thực
        EcovacsMQTTService.shared.connectWithSavedCredentials()
        EcovacsMQTTService.shared.subscribeToDevice(device: device)
        
        // 2. Tải toàn bộ trạng thái ban đầu
        refreshAll()
        startStatePolling()
    }
    
    public func onDisappear() {
        stopStatePolling()
    }
    
    public func refreshAll() {
        Task {
            await refreshState(full: true)
            await refreshLivePositionAndTrajectory()
            await refreshConsumables()
            await refreshMap()
            await fetchCleaningLogs()
        }
    }
    
    // MARK: - State Polling (Chu kỳ thông minh: 2.5s khi dọn, 8s khi nghỉ)
    public func refreshState(full: Bool = false) async {
        let newState = await deviceService.getDeviceState(device: device, full: full, existingState: self.state)
        self.state = newState
        NotificationManager.shared.notifyStateChange(device: device, state: newState)
    }
    
    private func startStatePolling() {
        stopStatePolling()
        pollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }
                let isCleaning = self.state.cleanState == "clean"
                let sleepSeconds: UInt64 = isCleaning ? 3 : 8
                try? await Task.sleep(nanoseconds: sleepSeconds * 1_000_000_000)
                guard !Task.isCancelled else { break }
                
                await self.refreshState(full: false)
                if isCleaning || self.selectedTab == .map {
                    await self.refreshLivePositionAndTrajectory()
                }
            }
        }
    }
    
    private func stopStatePolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
    
    // MARK: - Tọa độ & Quỹ đạo thời gian thực (Real-time Live Trajectory)
    public func refreshLivePositionAndTrajectory() async {
        let (robotPos, dockPos) = await deviceService.getPosition(device: device)
        if let dock = dockPos {
            self.state.dockX = dock.x
            self.state.dockY = dock.y
        }
        if let bot = robotPos {
            recordNewRobotPosition(x: bot.x, y: bot.y, angle: bot.a)
        }
    }
    
    private func recordNewRobotPosition(x: Double, y: Double, angle: Double) {
        self.state.robotX = x
        self.state.robotY = y
        self.state.robotAngle = angle
        
        let newPoint = MapPoint(x: x, y: y)
        if let last = self.state.trajectory.last {
            let dx = newPoint.x - last.x
            let dy = newPoint.y - last.y
            let dist = (dx * dx + dy * dy).squareRoot()
            if dist >= 4.0 {
                self.state.trajectory.append(newPoint)
                Task { await updateMapSvg() }
            }
        } else {
            self.state.trajectory.append(newPoint)
            Task { await updateMapSvg() }
        }
    }
    
    public func clearTrajectory() {
        self.state.trajectory.removeAll()
        Task { await updateMapSvg() }
        showToastNotification("Đã làm mới vệt đường đi")
    }

    
    // MARK: - Remote Actions
    public func triggerClean(action: CleanAction) {
        isExecutingCommand = true
        Task {
            do {
                try await deviceService.clean(device: device, action: action)
                self.showToastNotification("Đã gửi lệnh: \(action.title)")
                await self.refreshState()
            } catch {
                self.showToastNotification("Lỗi: \(error.localizedDescription)")
            }
            self.isExecutingCommand = false
        }
    }
    
    public func triggerCharge() {
        isExecutingCommand = true
        Task {
            do {
                try await deviceService.charge(device: device)
                self.showToastNotification("Robot đang quay về trạm sạc...")
                await self.refreshState()
            } catch {
                self.showToastNotification("Lỗi: \(error.localizedDescription)")
            }
            self.isExecutingCommand = false
        }
    }
    
    public func triggerPlaySound() {
        Task {
            do {
                try await deviceService.playSound(device: device)
                self.showToastNotification("Robot đang phát âm thanh định vị...")
            } catch {
                self.showToastNotification("Lỗi: \(error.localizedDescription)")
            }
        }
    }
    
    public func triggerRelocate() {
        Task {
            do {
                try await deviceService.relocate(device: device)
                self.showToastNotification("Đang tái định vị robot trên bản đồ...")
            } catch {
                self.showToastNotification("Lỗi: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Settings
    public func setFanSpeed(_ speed: FanSpeedLevel) {
        Task {
            do {
                try await deviceService.setFanSpeed(device: device, speed: speed)
                self.state.fanSpeed = speed.rawValue
                self.showToastNotification("Đã đổi lực hút: \(speed.title)")
            } catch {
                self.showToastNotification("Lỗi: \(error.localizedDescription)")
            }
        }
    }
    
    public func setWaterAmount(_ amount: Int) {
        Task {
            do {
                try await deviceService.setWaterInfo(device: device, amount: amount)
                self.state.waterAmount = amount
                self.showToastNotification("Đã đổi lượng nước mức \(amount)")
            } catch {
                self.showToastNotification("Lỗi: \(error.localizedDescription)")
            }
        }
    }
    
    public func setVolume(_ volume: Int) {
        Task {
            do {
                try await deviceService.setVolume(device: device, volume: volume)
                self.state.volume = volume
            } catch {
                self.showToastNotification("Lỗi: \(error.localizedDescription)")
            }
        }
    }
    
    public func toggleChildLock() {
        let newTarget = !state.childLock
        Task {
            do {
                try await deviceService.setChildLock(device: device, enabled: newTarget)
                self.state.childLock = newTarget
                self.showToastNotification("Khóa trẻ em: \(newTarget ? "Đã bật" : "Đã tắt")")
            } catch {
                self.showToastNotification("Lỗi: \(error.localizedDescription)")
            }
        }
    }
    
    public func toggleCarpetBoost() {
        let newTarget = !state.carpetAutoBoost
        Task {
            do {
                try await deviceService.setCarpetBoost(device: device, enabled: newTarget)
                self.state.carpetAutoBoost = newTarget
                self.showToastNotification("Tự tăng áp lên thảm: \(newTarget ? "Đã bật" : "Đã tắt")")
            } catch {
                self.showToastNotification("Lỗi: \(error.localizedDescription)")
            }
        }
    }
    
    public func setCleanTimes(_ times: Int) {
        self.cleanTimes = times
        Task {
            _ = try? await deviceService.executeCommand(device: device, cmdName: "setCleanTimes", payloadArgs: ["times": times])
            self.showToastNotification("Đã chọn dọn dẹp: x\(times) lần")
        }
    }
    
    public func setMoppingMode(_ mode: String) {
        self.moppingMode = mode
        let title = mode == "deep" ? "Lau sâu" : "Tiêu chuẩn"
        Task {
            _ = try? await deviceService.executeCommand(device: device, cmdName: "setMoppingMode", payloadArgs: ["mode": mode])
            self.showToastNotification("Chế độ lau: \(title)")
        }
    }
    
    public func toggleEdgeDeepCleaning() {
        self.edgeDeepCleaning.toggle()
        let val = self.edgeDeepCleaning
        Task {
            _ = try? await deviceService.executeCommand(device: device, cmdName: "setEdgeDeepCleaning", payloadArgs: ["enable": val ? 1 : 0])
            self.showToastNotification("Làm sạch sâu góc cạnh: \(val ? "Đã bật" : "Đã tắt")")
        }
    }
    
    public func toggleDoNotDisturb() {
        self.doNotDisturb.toggle()
        let val = self.doNotDisturb
        Task {
            _ = try? await deviceService.executeCommand(device: device, cmdName: "setDoNotDisturb", payloadArgs: ["enable": val ? 1 : 0])
            self.showToastNotification("Chế độ không làm phiền: \(val ? "Đã bật" : "Đã tắt")")
        }
    }
    
    // MARK: - Consumables
    public func refreshConsumables() async {
        let data = await deviceService.getConsumables(device: device)
        self.consumables = data
    }
    
    public func resetConsumable(type: ConsumableType) {
        Task {
            do {
                try await deviceService.resetConsumable(device: device, component: type)
                self.showToastNotification("Đã reset \(type.title) về 100%")
                await self.refreshConsumables()
            } catch {
                self.showToastNotification("Lỗi reset linh kiện: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Map Realtime (Zero-Server)
    public func updateMapSvg() async {
        let res = await deviceService.getSvgMapWithDetails(
            device: device,
            currentPos: (state.robotX, state.robotY, state.robotAngle),
            currentDock: (state.dockX, state.dockY),
            trajectory: state.trajectory
        )
        self.svgMap = res.svg
        self.mapId = res.mid
        self.mapCoverageM2 = res.coverageM2
    }
    
    public func refreshMap() async {
        isMapLoading = true
        await refreshLivePositionAndTrajectory()
        await updateMapSvg()
        self.isMapLoading = false
    }
    
    // MARK: - Cleaning Logs
    public func fetchCleaningLogs() async {
        isLogsLoading = true
        let (stats, logs) = await deviceService.getCleaningLogsAndStats(device: device)
        self.cleaningStats = stats
        self.cleaningLogs = logs
        self.isLogsLoading = false
    }
    
    // MARK: - Toast
    private func showToastNotification(_ msg: String) {
        self.toastMessage = msg
        self.showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if self.toastMessage == msg {
                self.showToast = false
            }
        }
    }
}
