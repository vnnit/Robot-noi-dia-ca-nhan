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
        if showLoading {
            isLoading = true
        }
        errorMessage = nil
        
        Task {
            do {
                var fetched = try await deviceService.fetchDevices()
                
                // Nạp trạng thái thời gian thực cho từng robot song song
                await withTaskGroup(of: (Int, DeviceState).self) { group in
                    for (index, dev) in fetched.enumerated() {
                        group.addTask {
                            let state = await self.deviceService.getDeviceState(device: dev)
                            return (index, state)
                        }
                    }
                    
                    for await (index, state) in group {
                        if index < fetched.count {
                            fetched[index].battery = state.batteryPercent
                            fetched[index].isCharging = state.isCharging
                            fetched[index].cleanState = state.cleanState
                            fetched[index].cleanStateText = state.cleanStateText
                        }
                    }
                }
                
                self.devices = fetched
                self.isLoading = false
                self.isRefreshing = false
                
                // Bắt đầu chu kỳ làm mới thẻ định kỳ 6 giây
                startAutoPolling()
            } catch {
                self.isLoading = false
                self.isRefreshing = false
                self.errorMessage = error.localizedDescription
            }
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
