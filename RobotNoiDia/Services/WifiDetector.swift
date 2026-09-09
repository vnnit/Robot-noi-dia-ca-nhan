import Foundation
import SystemConfiguration.CaptiveNetwork
import NetworkExtension
import CoreLocation

/// Service phat hien va doc ten mang Wi-Fi (SSID) hien tai ma iPhone dang ket noi
/// Ho tro ca NEHotspotNetwork (iOS 14+) va CNCopyCurrentNetworkInfo voi CoreLocation fallback
@MainActor
public final class WifiDetector: NSObject, ObservableObject, CLLocationManagerDelegate {
    public static let shared = WifiDetector()
    
    @Published public var currentSSID: String = ""
    @Published public var isDetecting: Bool = false
    @Published public var isRobotAP: Bool = false
    @Published public var lastDetectedAt: Date? = nil
    
    private let locationManager = CLLocationManager()
    
    override private init() {
        super.init()
        locationManager.delegate = self
    }
    
    /// Bat dau quet Wi-Fi hien tai. Neu co callback onFound, se duoc goi khi tim thay SSID hop le (khong phai robot).
    public func scanCurrentWifi(onFound: ((String) -> Void)? = nil) {
        self.isDetecting = true
        
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        
        // Thu doc ngay lap tuc
        readNetworkSSID(onFound: onFound)
    }
    
    public func readNetworkSSID(onFound: ((String) -> Void)? = nil) {
        // 1. Thu qua NetworkExtension (Chuan iOS 14+)
        NEHotspotNetwork.fetchCurrent { [weak self] network in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let ssid = network?.ssid, !ssid.isEmpty {
                    self.processDetectedSSID(ssid, onFound: onFound)
                    return
                }
                
                // 2. Du phong bang CNCopyCurrentNetworkInfo (SystemConfiguration)
                if let fallbackSSID = self.getSSIDFromSystemConfiguration(), !fallbackSSID.isEmpty {
                    self.processDetectedSSID(fallbackSSID, onFound: onFound)
                    return
                }
                
                self.isDetecting = false
            }
        }
    }
    
    private func getSSIDFromSystemConfiguration() -> String? {
        guard let interfaces = CNCopySupportedInterfaces() as? [String] else { return nil }
        for interface in interfaces {
            guard let info = CNCopyCurrentNetworkInfo(interface as CFString) as NSDictionary? else { continue }
            if let ssid = info[kCNNetworkInfoKeySSID as String] as? String, !ssid.isEmpty {
                return ssid
            }
        }
        return nil
    }
    
    private func processDetectedSSID(_ ssid: String, onFound: ((String) -> Void)?) {
        self.isDetecting = false
        self.currentSSID = ssid
        self.lastDetectedAt = Date()
        
        let upper = ssid.uppercased()
        if upper.hasPrefix("ECOVACS_") {
            self.isRobotAP = true
        } else {
            self.isRobotAP = false
            onFound?(ssid)
        }
    }
    
    // CLLocationManagerDelegate
    nonisolated public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            Task { @MainActor in
                self.readNetworkSSID()
            }
        }
    }
}
