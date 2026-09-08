import SwiftUI

public struct StatusBadgeView: View {
    public let text: String
    public let color: Color
    public var isPulse: Bool = false
    
    @State private var pulseOpacity = 0.4
    
    public init(text: String, color: Color, isPulse: Bool = false) {
        self.text = text
        self.color = color
        self.isPulse = isPulse
    }
    
    public var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .opacity(isPulse ? pulseOpacity : 1.0)
                .onAppear {
                    if isPulse {
                        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                            pulseOpacity = 1.0
                        }
                    }
                }
            
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

public struct CustomToastView: View {
    public let message: String
    
    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.cyan)
                .font(.system(size: 16, weight: .bold))
            
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(red: 0.1, green: 0.14, blue: 0.2).opacity(0.95))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.cyan.opacity(0.4), lineWidth: 1)
        )
    }
}
