import Foundation
import SwiftUI

@MainActor
public final class RobotPickerViewModel: ObservableObject {
    @Published public var devices: [DeviceModel] = []
    @Published public var isLoading: Bool = false
    @Published public var isRefreshing: Bool = false
    @Published public var errorMessage: String? = nil
    
    private let deviceService = EcovacsDeviceService.shared
    private var refreshTimer: Timer?
    
    public init() {
        // Tải tức thời danh sách robot từ cache cục bộ (0ms, không chờ mạng)
        let cached = deviceService.getCachedDevices()
        self.devices = cached
        self.isLoading = cached.isEmpty
    }
    
    public func loadDevices(showLoading: Bool = false) {
        if showLoading && devices.isEmpty {
            isLoading = true
        }
        errorMessage = nil
        
        Task {
            do {
                let fetched = try await deviceService.fetchDevices()
                
                // Hiển thị danh sách robot
                self.devices = fetched
                self.isLoading = false
                self.isRefreshing = false
                
                // Nạp nhanh pin & dọn dẹp chạy ngầm không chặn giao diện
                await withTaskGroup(of: (Int, Int?, Bool?, String?, String?).self) { group in
                    for (index, dev) in fetched.enumerated() {
                        group.addTask {
                            let qs = await self.deviceService.getQuickStatus(device: dev)
                            return (index, qs.battery, qs.isCharging, qs.cleanState, qs.cleanStateText)
                        }
                    }
                    
                    for await (index, batt, ch, st, text) in group {
                        if index < self.devices.count {
                            if let b = batt { self.devices[index].battery = b }
                            if let c = ch { self.devices[index].isCharging = c }
                            if let s = st { self.devices[index].cleanState = s }
                            if let t = text { self.devices[index].cleanStateText = t }
                        }
                    }
                }
                
                // Lưu lại cache gồm cả trạng thái pin
                self.deviceService.saveCachedDevices(self.devices)
                
                // Bắt đầu chu kỳ làm mới thẻ định kỳ 6 giây
                startAutoPolling()
            } catch {
                self.isLoading = false
                self.isRefreshing = false
                if self.devices.isEmpty {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    public func renameRobot(did: String, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let idx = devices.firstIndex(where: { $0.did == did }) {
            devices[idx].nick = trimmed.isEmpty ? nil : trimmed
            devices[idx].saveCustomName(trimmed)
            let updated = devices[idx]
            devices[idx] = updated
            deviceService.saveCachedDevices(devices)
        }
    }
    
    public func startAutoPolling() {
        stopAutoPolling()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                for (index, dev) in self.devices.enumerated() {
                    let qs = await self.deviceService.getQuickStatus(device: dev)
                    if index < self.devices.count {
                        if let b = qs.battery { self.devices[index].battery = b }
                        if let c = qs.isCharging { self.devices[index].isCharging = c }
                        if let s = qs.cleanState { self.devices[index].cleanState = s }
                        if let t = qs.cleanStateText { self.devices[index].cleanStateText = t }
                    }
                }
                self.deviceService.saveCachedDevices(self.devices)
            }
        }
    }
    
    public func stopAutoPolling() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
}
