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
    
    public init() {}
    
    public func loadDevices(showLoading: Bool = true) {
        if showLoading && devices.isEmpty {
            isLoading = true
        }
        errorMessage = nil
        
        Task {
            do {
                let fetched = try await deviceService.fetchDevices()
                
                // Hiển thị danh sách robot ngay lập tức (siêu tốc < 0.3s)
                self.devices = fetched
                self.isLoading = false
                self.isRefreshing = false
                
                // Nạp trạng thái pin & dọn dẹp chạy ngầm không chặn giao diện
                await withTaskGroup(of: (Int, DeviceState).self) { group in
                    for (index, dev) in fetched.enumerated() {
                        group.addTask {
                            let state = await self.deviceService.getDeviceState(device: dev)
                            return (index, state)
                        }
                    }
                    
                    for await (index, state) in group {
                        if index < self.devices.count {
                            self.devices[index].battery = state.batteryPercent
                            self.devices[index].isCharging = state.isCharging
                            self.devices[index].cleanState = state.cleanState
                            self.devices[index].cleanStateText = state.cleanStateText
                        }
                    }
                }
                
                // Bắt đầu chu kỳ làm mới thẻ định kỳ 8 giây
                startAutoPolling()
            } catch {
                self.isLoading = false
                self.isRefreshing = false
                self.errorMessage = error.localizedDescription
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
        }
    }
    
    public func startAutoPolling() {
        stopAutoPolling()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                for (index, dev) in self.devices.enumerated() {
                    let st = await self.deviceService.getDeviceState(device: dev)
                    if index < self.devices.count {
                        self.devices[index].battery = st.batteryPercent
                        self.devices[index].isCharging = st.isCharging
                        self.devices[index].cleanState = st.cleanState
                        self.devices[index].cleanStateText = st.cleanStateText
                    }
                }
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
