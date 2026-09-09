import Foundation
import UIKit

/// Trình quản lý phản hồi xúc giác (Taptic Engine Haptic Feedback)
public final class HapticManager {
    public static let shared = HapticManager()
    
    private init() {}
    
    /// Rung nhẹ khi chạm nút, chuyển tab, chọn chip
    public func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
    
    /// Rung vừa khi bấm nút chính (Bắt đầu dọn, Về sạc)
    public func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
    
    /// Rung mạnh khi thực hiện thao tác quan trọng (Reset linh kiện, Xóa tường ảo)
    public func heavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
    }
    
    /// Rung khi chọn phần tử trong danh sách hoặc picker
    public func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
    
    /// Rung thông báo hoàn tất thành công
    public func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
    
    /// Rung cảnh báo sự cố
    public func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }
    
    /// Rung báo lỗi
    public func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }
}
