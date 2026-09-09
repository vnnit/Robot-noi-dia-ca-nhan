import Foundation
import SwiftUI

@MainActor
public final class RobotPickerViewModel: ObservableObject {
    @Published public var devices: [DeviceModel] = []
    @Published public var isLoading: Bool = false
    @Published public var isRefreshing: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var showAddRobotSheet: Bool = false
    @Published public var isSyncingCloud: Bool = false
    @Published public var isScanningLAN: Bool = false
    @Published public var scanProgress: Float = 0.0
    @Published public var discoveredDevices: [DiscoveredLocalDevice] = []


    
    private let deviceService = EcovacsDeviceService.shared
    private var refreshTimer: Timer?
    
    public init() {
        // Tải tức thời danh sách robot từ cache cục bộ (0ms, không chờ mạng)
        let cached = deviceService.getCachedDevices()
        self.devices = cached
        self.isLoading = cached.isEmpty
        if !cached.isEmpty {
            RobotImageCacheManager.shared.preloadImages(for: cached)
        }
    }
    
    public func loadDevices(showLoading: Bool = false, forceRefreshAuth: Bool = false) {
        if showLoading || devices.isEmpty {
            isLoading = true
        }
        errorMessage = nil
        
        Task {
            do {
                let fetched = try await deviceService.fetchDevices(forceRefreshAuth: forceRefreshAuth)
                
                // Hiển thị danh sách robot & Tải trước toàn bộ ảnh vào Disk Cache
                self.devices = fetched
                self.isLoading = false
                self.isRefreshing = false
                RobotImageCacheManager.shared.preloadImages(for: fetched)
                if fetched.isEmpty {
                    self.errorMessage = "Chưa tìm thấy robot nào trong tài khoản."
                }
                
                // Nạp nhanh pin & dọn dẹp chạy ngầm không chặn giao diện
                await withTaskGroup(of: (Int, Bool, Int?, Bool?, String?, String?).self) { group in
                    for (index, dev) in fetched.enumerated() {
                        group.addTask {
                            let qs = await self.deviceService.getQuickStatus(device: dev)
                            return (index, qs.isOnline, qs.battery, qs.isCharging, qs.cleanState, qs.cleanStateText)
                        }
                    }
                    
                    for await (index, isOnline, batt, ch, st, text) in group {
                        if index < self.devices.count {
                            self.devices[index].status = isOnline ? 1 : 0
                            self.devices[index].battery = isOnline ? batt : nil
                            self.devices[index].isCharging = isOnline ? ch : false
                            self.devices[index].cleanState = isOnline ? st : "offline"
                            self.devices[index].cleanStateText = isOnline ? text : "Ngoại tuyến"
                        }
                    }
                }
                
                // Lưu lại cache gồm cả trạng thái pin
                self.deviceService.saveCachedDevices(self.devices)
                
                // Bắt đầu chu kỳ làm mới thẻ định kỳ 5 giây
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
    
    public func deleteRobot(device: DeviceModel) async throws {
        try await deviceService.deleteDevice(device: device)
        devices.removeAll(where: { $0.did == device.did })
        deviceService.saveCachedDevices(devices)
    }
    
    public func startAutoPolling() {
        stopAutoPolling()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                for (index, dev) in self.devices.enumerated() {
                    let qs = await self.deviceService.getQuickStatus(device: dev)
                    if index < self.devices.count {
                        self.devices[index].status = qs.isOnline ? 1 : 0
                        self.devices[index].battery = qs.isOnline ? qs.battery : nil
                        self.devices[index].isCharging = qs.isOnline ? (qs.isCharging ?? false) : false
                        self.devices[index].cleanState = qs.isOnline ? qs.cleanState : "offline"
                        self.devices[index].cleanStateText = qs.isOnline ? qs.cleanStateText : "Ngoại tuyến"
                        NotificationManager.shared.notifyQuickStatusChange(
                            device: self.devices[index],
                            battery: self.devices[index].battery,
                            isCharging: self.devices[index].isCharging,
                            cleanState: self.devices[index].cleanState
                        )
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
    
    // MARK: - Quản Lý & Thêm Robot Mới
    public func addManualRobot(did: String, name: String, preset: PresetRobotModel) {
        let cleanDid = did.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanDid.isEmpty else { return }
        
        let customName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = customName.isEmpty ? preset.name : customName
        
        let newDevice = DeviceModel(
            did: cleanDid,
            name: finalName,
            nick: finalName,
            model: preset.modelCode,
            deviceClass: preset.deviceClass,
            company: preset.company,
            status: 1,
            icon: preset.defaultIcon,
            fwVer: "v1.0.0",
            resource: preset.resource,
            battery: 100,
            isCharging: true,
            cleanState: "charging",
            cleanStateText: "Đang sạc"
        )
        
        deviceService.addCustomDevice(newDevice)
        self.devices = deviceService.getCachedDevices()
        RobotImageCacheManager.shared.preloadImages(for: self.devices)
        HapticManager.shared.success()
    }
    
    public func deleteRobot(did: String) {
        HapticManager.shared.medium()
        deviceService.deleteDevice(did: did)
        self.devices = deviceService.getCachedDevices()
    }
    
    public func syncCloudRobots() async -> (success: Bool, message: String) {
        isSyncingCloud = true
        defer { isSyncingCloud = false }
        
        do {
            let result = try await deviceService.syncNewCloudDevices(forceRefreshAuth: true)
            self.devices = deviceService.getCachedDevices()
            RobotImageCacheManager.shared.preloadImages(for: self.devices)
            HapticManager.shared.success()
            if result.added > 0 {
                return (true, "Đã tìm thấy \(result.added) robot mới! Tổng cộng: \(result.total) robot.")
            } else {
                return (true, "Tất cả robot trong tài khoản (\(result.total) robot) đã được đồng bộ đầy đủ.")
            }
        } catch {
            return (false, "Lỗi kết nối Ecovacs Cloud: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Quét Mạng Nội Bộ (Local LAN Discovery)
    public func startLANScan() {
        guard !isScanningLAN else { return }
        isScanningLAN = true
        scanProgress = 0.0
        discoveredDevices.removeAll()
        HapticManager.shared.light()
        
        Task {
            let results = await LocalNetworkScannerService.shared.scanSubnet { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.scanProgress = progress
                }
            }
            self.discoveredDevices = results
            self.isScanningLAN = false
            self.scanProgress = 1.0
            HapticManager.shared.success()
        }
    }
    
    public func addDiscoveredRobot(discovered: DiscoveredLocalDevice, name: String, preset: PresetRobotModel) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = cleanName.isEmpty ? (discovered.hostname ?? preset.name) : cleanName
        let syntheticDid = "lan_\(discovered.ip.replacingOccurrences(of: ".", with: "_"))"
        
        let newDevice = DeviceModel(
            did: syntheticDid,
            name: finalName,
            nick: finalName,
            model: preset.modelCode,
            deviceClass: preset.deviceClass,
            company: preset.company,
            status: 1,
            icon: preset.defaultIcon,
            fwVer: "LAN Direct",
            resource: preset.resource,
            battery: 100,
            isCharging: true,
            cleanState: "charging",
            cleanStateText: "Trực tuyến (LAN)",
            localIp: discovered.ip,
            localLatencyMs: discovered.latencyMs
        )
        
        deviceService.addCustomDevice(newDevice)
        self.devices = deviceService.getCachedDevices()
        RobotImageCacheManager.shared.preloadImages(for: self.devices)
        HapticManager.shared.success()
    }
    
    deinit {


        refreshTimer?.invalidate()
    }
}
