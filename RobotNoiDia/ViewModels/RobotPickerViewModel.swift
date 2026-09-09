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
                
                for dev in fetched {
                    NotificationManager.shared.notifyQuickStatusChange(
                        device: dev,
                        battery: dev.battery,
                        isCharging: dev.isCharging,
                        cleanState: dev.cleanState
                    )
                }
                
                // Lưu lại cache
                self.deviceService.saveCachedDevices(self.devices)
                
                // Bắt đầu chu kỳ làm mới nhẹ nhàng định kỳ 30 giây (chỉ kiểm tra danh sách thiết bị từ máy chủ)
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
        // Làm mới danh sách thiết bị nhẹ nhàng mỗi 30s (không gọi devmanager gây nhảy trạng thái)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let updated = try? await self.deviceService.fetchDevices(forceRefreshAuth: false) {
                    self.devices = updated
                    for dev in updated {
                        NotificationManager.shared.notifyQuickStatusChange(
                            device: dev,
                            battery: dev.battery,
                            isCharging: dev.isCharging,
                            cleanState: dev.cleanState
                        )
                    }
                    self.deviceService.saveCachedDevices(updated)
                }
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
