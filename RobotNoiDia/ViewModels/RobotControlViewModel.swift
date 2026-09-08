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
    public let device: DeviceModel
    
    @Published public var state: DeviceState = .initial
    @Published public var consumables: ConsumablesData = .default
    @Published public var svgMap: String? = nil
    @Published public var selectedTab: ControlTab = .controls
    
    @Published public var isExecutingCommand: Bool = false
    @Published public var isMapLoading: Bool = false
    @Published public var toastMessage: String? = nil
    @Published public var showToast: Bool = false
    
    private let deviceService = EcovacsDeviceService.shared
    private var statePollTimer: Timer?
    
    public init(device: DeviceModel) {
        self.device = device
    }
    
    public func onAppear() {
        refreshAll()
        startStatePolling()
    }
    
    public func onDisappear() {
        stopStatePolling()
    }
    
    public func refreshAll() {
        Task {
            await refreshState()
            await refreshConsumables()
            await refreshMap()
        }
    }
    
    // MARK: - State Polling
    public func refreshState() async {
        let newState = await deviceService.getDeviceState(device: device)
        self.state = newState
    }
    
    private func startStatePolling() {
        stopStatePolling()
        statePollTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshState()
            }
        }
    }
    
    private func stopStatePolling() {
        statePollTimer?.invalidate()
        statePollTimer = nil
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
    
    // MARK: - Map
    public func refreshMap() async {
        isMapLoading = true
        let svg = await deviceService.getSvgMap(device: device)
        if let svg = svg {
            self.svgMap = svg
        }
        self.isMapLoading = false
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
