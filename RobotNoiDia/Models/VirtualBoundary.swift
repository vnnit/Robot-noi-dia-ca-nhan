import Foundation
import SwiftUI

// MARK: - 1. Tường Ảo (Virtual Wall)
public struct VirtualWall: Identifiable, Codable, Hashable {
    public var id: String
    public var x1: Double
    public var y1: Double
    public var x2: Double
    public var y2: Double
    public var name: String
    
    public init(id: String = UUID().uuidString, x1: Double, y1: Double, x2: Double, y2: Double, name: String = "Tường ảo") {
        self.id = id
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
        self.name = name
    }
}

// MARK: - 2. Vùng Cấm (Restricted Zone: No-Go / No-Mop)
public enum RestrictedZoneType: String, Codable, CaseIterable {
    case noGo = "no_go"      // Cấm quét và lau
    case noMop = "no_mop"    // Cấm lau sàn (khu vực trải thảm)
    
    public var title: String {
        switch self {
        case .noGo: return "Vùng cấm vào"
        case .noMop: return "Vùng cấm lau (Thảm)"
        }
    }
    
    public var colorHex: String {
        switch self {
        case .noGo: return "#EF4444" // Đỏ
        case .noMop: return "#A855F7" // Tím
        }
    }
}

public struct RestrictedZone: Identifiable, Codable, Hashable {
    public var id: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var type: RestrictedZoneType
    public var name: String
    
    public init(id: String = UUID().uuidString, x: Double, y: Double, width: Double, height: Double, type: RestrictedZoneType, name: String = "") {
        self.id = id
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.type = type
        self.name = name.isEmpty ? type.title : name
    }
}

// MARK: - 3. Lịch Hẹn Giờ Dọn Dẹp (Cleaning Schedule)
public struct CleaningScheduleItem: Identifiable, Codable, Hashable {
    public var id: String
    public var hour: Int
    public var minute: Int
    public var repeatDays: [Int] // 1: CN, 2: T2, ..., 7: T7
    public var isEnabled: Bool
    public var cleanMode: String // "auto", "area"
    public var fanSpeed: String  // quiet, standard, max, max+
    public var waterAmount: Int  // 1..4
    public var label: String
    
    public init(
        id: String = UUID().uuidString,
        hour: Int,
        minute: Int,
        repeatDays: [Int] = [2, 3, 4, 5, 6, 7, 1],
        isEnabled: Bool = true,
        cleanMode: String = "auto",
        fanSpeed: String = "standard",
        waterAmount: Int = 2,
        label: String = "Hẹn giờ dọn dẹp"
    ) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.repeatDays = repeatDays
        self.isEnabled = isEnabled
        self.cleanMode = cleanMode
        self.fanSpeed = fanSpeed
        self.waterAmount = waterAmount
        self.label = label
    }
    
    public var timeString: String {
        String(format: "%02d:%02d", hour, minute)
    }
    
    public var repeatDaysText: String {
        if repeatDays.count == 7 {
            return "Hàng ngày"
        }
        if repeatDays.sorted() == [2, 3, 4, 5, 6] {
            return "Ngày trong tuần (T2 - T6)"
        }
        if repeatDays.sorted() == [1, 7] {
            return "Cuối tuần (T7, CN)"
        }
        if repeatDays.isEmpty {
            return "Một lần duy nhất"
        }
        let dayNames: [Int: String] = [
            1: "CN", 2: "T2", 3: "T3", 4: "T4", 5: "T5", 6: "T6", 7: "T7"
        ]
        return repeatDays.compactMap { dayNames[$0] }.joined(separator: ", ")
    }
}

// MARK: - 4. Lệnh Trạm Sạc Thông Minh (Station Action)
public enum StationActionType: Int, CaseIterable {
    case emptyDustbin = 1   // Tự động gom rác
    case startMopWash = 2   // Bắt đầu giặt giẻ
    case stopMopWash = -2   // Dừng giặt giẻ
    case startAirDrying = 3 // Bắt đầu sấy khô giẻ khí nóng
    case stopAirDrying = -3 // Dừng sấy khô giẻ
    
    public var title: String {
        switch self {
        case .emptyDustbin: return "Gom rác tự động"
        case .startMopWash: return "Giặt giẻ lau"
        case .stopMopWash: return "Dừng giặt giẻ"
        case .startAirDrying: return "Sấy khô giẻ"
        case .stopAirDrying: return "Dừng sấy khô"
        }
    }
    
    public var icon: String {
        switch self {
        case .emptyDustbin: return "trash.fill"
        case .startMopWash: return "drop.triangle.fill"
        case .stopMopWash: return "drop.triangle"
        case .startAirDrying: return "wind"
        case .stopAirDrying: return "wind"
        }
    }
}

// MARK: - 5. Chế Độ Vẽ Tường Ảo & Vùng Cấm Trực Tiếp Trên Bản Đồ (Interactive Map Drawing)
import SwiftUI

public enum DrawingTool: String, CaseIterable, Identifiable {
    case wall = "wall"
    case noGo = "noGo"
    case noMop = "noMop"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .wall: return "Tường ảo"
        case .noGo: return "Cấm vào"
        case .noMop: return "Cấm lau"
        }
    }
    
    public var icon: String {
        switch self {
        case .wall: return "line.diagonal"
        case .noGo: return "nosign"
        case .noMop: return "drop.triangle"
        }
    }
    
    public var color: Color {
        switch self {
        case .wall: return Color(red: 0.95, green: 0.25, blue: 0.25)
        case .noGo: return Color(red: 0.95, green: 0.25, blue: 0.25)
        case .noMop: return Color(red: 0.65, green: 0.35, blue: 0.95)
        }
    }
}

public struct BoundaryDrawingOverlayView: View {
    @ObservedObject var viewModel: RobotControlViewModel
    let containerSize: CGSize
    let mapBounds: CGRect
    
    @State private var selectedTool: DrawingTool = .wall
    @State private var startPoint: CGPoint? = nil
    @State private var currentPoint: CGPoint? = nil
    @State private var tempWalls: [VirtualWall] = []
    @State private var tempZones: [RestrictedZone] = []
    
    public init(viewModel: RobotControlViewModel, containerSize: CGSize, mapBounds: CGRect) {
        self.viewModel = viewModel
        self.containerSize = containerSize
        self.mapBounds = mapBounds
        _tempWalls = State(initialValue: viewModel.state.virtualWalls)
        _tempZones = State(initialValue: viewModel.state.restrictedZones)
    }
    
    private func screenToSvg(_ pt: CGPoint) -> CGPoint {
        guard mapBounds.width > 0 && mapBounds.height > 0 && containerSize.width > 0 && containerSize.height > 0 else {
            return pt
        }
        let scale = min(containerSize.width / mapBounds.width, containerSize.height / mapBounds.height)
        let displayedW = mapBounds.width * scale
        let displayedH = mapBounds.height * scale
        let offsetX = (containerSize.width - displayedW) / 2.0
        let offsetY = (containerSize.height - displayedH) / 2.0
        
        let svgX = mapBounds.minX + (pt.x - offsetX) / scale
        let svgY = mapBounds.minY + (pt.y - offsetY) / scale
        return CGPoint(x: svgX, y: svgY)
    }
    
    private func svgToScreen(_ pt: CGPoint) -> CGPoint {
        guard mapBounds.width > 0 && mapBounds.height > 0 && containerSize.width > 0 && containerSize.height > 0 else {
            return pt
        }
        let scale = min(containerSize.width / mapBounds.width, containerSize.height / mapBounds.height)
        let displayedW = mapBounds.width * scale
        let displayedH = mapBounds.height * scale
        let offsetX = (containerSize.width - displayedW) / 2.0
        let offsetY = (containerSize.height - displayedH) / 2.0
        
        let scrX = offsetX + (pt.x - mapBounds.minX) * scale
        let scrY = offsetY + (pt.y - mapBounds.minY) * scale
        return CGPoint(x: scrX, y: scrY)
    }
    
    public var body: some View {
        ZStack {
            // Lớp nền đen mờ nhẹ tạo cảm giác canvas chuyên nghiệp
            Color.black.opacity(0.35)
                .cornerRadius(18)
            
            // Canvas vẽ tương tác trực tiếp
            drawingCanvasView
            
            // Các nút xóa từng phần tử đã vẽ
            deleteAnchorsView
            
            // Header & Footer Toolbars
            VStack(spacing: 0) {
                headerToolBar
                    .padding(.top, 8)
                
                Spacer()
                
                footerActionBar
                    .padding(.bottom, 10)
            }
            .padding(.horizontal, 10)
        }
        .cornerRadius(18)
    }
    
    private var drawingCanvasView: some View {
        Canvas { context, size in
            // 1. Vẽ các Tường ảo đã có trong danh sách
            for wall in tempWalls {
                let p1 = svgToScreen(CGPoint(x: wall.x1, y: wall.y1))
                let p2 = svgToScreen(CGPoint(x: wall.x2, y: wall.y2))
                var path = Path()
                path.move(to: p1)
                path.addLine(to: p2)
                context.stroke(path, with: .color(Color.red), style: StrokeStyle(lineWidth: 3.5, lineCap: .round, dash: [8, 5]))
            }
            
            // 2. Vẽ các Vùng cấm đã có trong danh sách
            for zone in tempZones {
                let p = svgToScreen(CGPoint(x: zone.x, y: zone.y))
                let pBotRight = svgToScreen(CGPoint(x: zone.x + zone.width, y: zone.y + zone.height))
                let rect = CGRect(x: min(p.x, pBotRight.x), y: min(p.y, pBotRight.y), width: abs(pBotRight.x - p.x), height: abs(pBotRight.y - p.y))
                let fillColor = zone.type == .noGo ? Color.red.opacity(0.35) : Color.purple.opacity(0.35)
                let strokeColor = zone.type == .noGo ? Color.red : Color.purple
                context.fill(Path(rect), with: .color(fillColor))
                context.stroke(Path(rect), with: .color(strokeColor), style: StrokeStyle(lineWidth: 2.2, dash: [6, 4]))
            }
            
            // 3. Vẽ nét vẽ trực tiếp khi ngón tay đang chạm kéo (Live Dragging)
            if let start = startPoint, let current = currentPoint {
                if selectedTool == .wall {
                    var path = Path()
                    path.move(to: start)
                    path.addLine(to: current)
                    context.stroke(path, with: .color(Color.red), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                } else {
                    let rect = CGRect(
                        x: min(start.x, current.x),
                        y: min(start.y, current.y),
                        width: abs(current.x - start.x),
                        height: abs(current.y - start.y)
                    )
                    let fillColor = selectedTool == .noGo ? Color.red.opacity(0.4) : Color.purple.opacity(0.4)
                    let strokeColor = selectedTool == .noGo ? Color.red : Color.purple
                    context.fill(Path(rect), with: .color(fillColor))
                    context.stroke(Path(rect), with: .color(strokeColor), style: StrokeStyle(lineWidth: 2.5, dash: [6, 4]))
                }
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { value in
                    if startPoint == nil {
                        startPoint = value.startLocation
                    }
                    currentPoint = value.location
                }
                .onEnded { value in
                    guard let start = startPoint else { return }
                    let end = value.location
                    let svgStart = screenToSvg(start)
                    let svgEnd = screenToSvg(end)
                    
                    if selectedTool == .wall {
                        let dx = svgEnd.x - svgStart.x
                        let dy = svgEnd.y - svgStart.y
                        let dist = (dx * dx + dy * dy).squareRoot()
                        if dist >= 15 {
                            let newWall = VirtualWall(
                                x1: Double(svgStart.x),
                                y1: Double(svgStart.y),
                                x2: Double(svgEnd.x),
                                y2: Double(svgEnd.y)
                            )
                            tempWalls.append(newWall)
                        }
                    } else {
                        let minX = min(svgStart.x, svgEnd.x)
                        let minY = min(svgStart.y, svgEnd.y)
                        let w = abs(svgEnd.x - svgStart.x)
                        let h = abs(svgEnd.y - svgStart.y)
                        if w >= 20 && h >= 20 {
                            let newZone = RestrictedZone(
                                x: Double(minX),
                                y: Double(minY),
                                width: Double(w),
                                height: Double(h),
                                type: selectedTool == .noGo ? .noGo : .noMop
                            )
                            tempZones.append(newZone)
                        }
                    }
                    startPoint = nil
                    currentPoint = nil
                }
        )
    }
    
    private var deleteAnchorsView: some View {
        ZStack {
            // Nút xóa tường ảo
            ForEach(tempWalls) { wall in
                let midSvg = CGPoint(x: (wall.x1 + wall.x2) / 2.0, y: (wall.y1 + wall.y2) / 2.0)
                let pos = svgToScreen(midSvg)
                Button(action: {
                    tempWalls.removeAll { $0.id == wall.id }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.red)
                        .background(Color.white.clipShape(Circle()))
                }
                .position(pos)
            }
            
            // Nút xóa vùng cấm
            ForEach(tempZones) { zone in
                let topRightSvg = CGPoint(x: zone.x + zone.width, y: zone.y)
                let pos = svgToScreen(topRightSvg)
                Button(action: {
                    tempZones.removeAll { $0.id == zone.id }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(zone.type == .noGo ? .red : .purple)
                        .background(Color.white.clipShape(Circle()))
                }
                .position(pos)
            }
        }
    }
    
    private var headerToolBar: some View {
        VStack(spacing: 8) {
            Text("Chạm và kéo ngón tay để vẽ vạch hoặc kéo ô cấm")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.75))
                .cornerRadius(12)
            
            HStack(spacing: 6) {
                ForEach(DrawingTool.allCases) { tool in
                    Button(action: {
                        selectedTool = tool
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: tool.icon)
                                .font(.system(size: 12, weight: .bold))
                            Text(tool.title)
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(selectedTool == tool ? .white : Color(white: 0.8))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(selectedTool == tool ? tool.color : Color.black.opacity(0.65))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selectedTool == tool ? Color.white : Color.clear, lineWidth: 1)
                        )
                    }
                }
            }
        }
    }
    
    private var footerActionBar: some View {
        HStack(spacing: 8) {
            Button(action: {
                tempWalls.removeAll()
                tempZones.removeAll()
            }) {
                Text("Xóa hết")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.6))
                    .cornerRadius(8)
            }
            
            Spacer()
            
            Button(action: {
                viewModel.isEditingBoundaries = false
            }) {
                Text("Hủy")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.65))
                    .cornerRadius(8)
            }
            
            Button(action: {
                viewModel.saveBoundaries(walls: tempWalls, zones: tempZones)
                viewModel.isEditingBoundaries = false
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                    Text("Lưu vùng cấm")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(red: 0.09, green: 0.47, blue: 1.0))
                .cornerRadius(8)
                .shadow(color: Color.blue.opacity(0.4), radius: 4, y: 2)
            }
        }
    }
}
