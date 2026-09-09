import SwiftUI
import WebKit

/// Hiển thị bản đồ SVG LiDAR từ robot bằng WebKit với khả năng tương tác Pinch Zoom & Pan mượt mà
public struct SVGWebView: UIViewRepresentable {
    public let svgString: String
    public let robotX: Double?
    public let robotY: Double?
    public let robotAngle: Double?
    public let trajectory: [MapPoint]
    
    public init(
        svgString: String,
        robotX: Double? = nil,
        robotY: Double? = nil,
        robotAngle: Double? = nil,
        trajectory: [MapPoint] = []
    ) {
        self.svgString = svgString
        self.robotX = robotX
        self.robotY = robotY
        self.robotAngle = robotAngle
        self.trajectory = trajectory
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    public class Coordinator: NSObject, WKNavigationDelegate {
        var lastLoadedSvg: String = ""
        var lastRobotX: Double? = nil
        var lastRobotY: Double? = nil
        var lastRobotAngle: Double? = nil
        var lastTrajectoryCount: Int = 0
        var isPageLoaded: Bool = false
        weak var webView: WKWebView?
        
        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            self.isPageLoaded = true
            self.webView = webView
            
            // Đồng bộ ngay vị trí robot và quỹ đạo khi vừa tải xong trang HTML
            if let x = lastRobotX, let y = lastRobotY {
                let a = lastRobotAngle ?? 0.0
                let js = "if(window.updateRobot){window.updateRobot(\(x), \(y), \(a));}"
                webView.evaluateJavaScript(js, completionHandler: nil)
            }
        }
    }
    
    public func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        webView.isOpaque = true
        webView.backgroundColor = UIColor(red: 0.035, green: 0.05, blue: 0.086, alpha: 1.0)
        webView.scrollView.backgroundColor = UIColor(red: 0.035, green: 0.05, blue: 0.086, alpha: 1.0)
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.maximumZoomScale = 5.0
        webView.scrollView.minimumZoomScale = 0.5
        return webView
    }
    
    public func updateUIView(_ uiView: WKWebView, context: Context) {
        let coord = context.coordinator
        
        // 1. Nếu bản đồ phòng SVG thay đổi: Nạp lại toàn bộ HTML
        if coord.lastLoadedSvg != svgString {
            coord.lastLoadedSvg = svgString
            coord.isPageLoaded = false
            coord.lastRobotX = robotX
            coord.lastRobotY = robotY
            coord.lastRobotAngle = robotAngle
            coord.lastTrajectoryCount = trajectory.count
            
            let htmlContent = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes">
                <style>
                    * { margin: 0; padding: 0; box-sizing: border-box; }
                    html, body {
                        background-color: #090d16;
                        width: 100%;
                        height: 100%;
                        display: flex;
                        justify-content: center;
                        align-items: center;
                        overflow: hidden;
                    }
                    svg {
                        width: 100%;
                        height: 100%;
                        max-width: 100%;
                        max-height: 100%;
                        display: block;
                        margin: auto;
                        background-color: #090d16;
                    }
                    image {
                        image-rendering: pixelated;
                        image-rendering: -webkit-optimize-contrast;
                    }
                </style>
                <script>
                    window.updateRobot = function(x, y, angle) {
                        var g = document.getElementById('robotGroup');
                        if (g) {
                            g.setAttribute('transform', 'translate(' + x + ', ' + y + ')');
                        }
                        var h = document.getElementById('robotHeading');
                        if (h && angle !== undefined && angle !== null) {
                            h.setAttribute('transform', 'rotate(' + angle + ')');
                        }
                    };
                    window.updateTrajectory = function(pointsStr) {
                        var line = document.getElementById('trajectoryLine');
                        if (line) {
                            line.setAttribute('points', pointsStr);
                        }
                        var lineDash = document.getElementById('trajectoryLineDash');
                        if (lineDash) {
                            lineDash.setAttribute('points', pointsStr);
                        }
                    };
                </script>
            </head>
            <body>
                \(svgString)
            </body>
            </html>
            """
            uiView.loadHTMLString(htmlContent, baseURL: nil)
            return
        }
        
        // 2. Nếu chỉ có tọa độ robot hoặc quỹ đạo thay đổi: Cập nhật trực tiếp DOM qua JS (Zero Reload, Zero Flicker, Giữ nguyên Pinch Zoom)
        if coord.isPageLoaded {
            if let x = robotX, let y = robotY, (coord.lastRobotX != x || coord.lastRobotY != y || coord.lastRobotAngle != robotAngle) {
                coord.lastRobotX = x
                coord.lastRobotY = y
                coord.lastRobotAngle = robotAngle
                let a = robotAngle ?? 0.0
                let js = "window.updateRobot(\(x), \(y), \(a));"
                uiView.evaluateJavaScript(js, completionHandler: nil)
            }
            
            if coord.lastTrajectoryCount != trajectory.count {
                coord.lastTrajectoryCount = trajectory.count
                let ptsStr = trajectory.map { "\($0.x),\($0.y)" }.joined(separator: " ")
                let js = "window.updateTrajectory('\(ptsStr)');"
                uiView.evaluateJavaScript(js, completionHandler: nil)
            }
        } else {
            coord.lastRobotX = robotX
            coord.lastRobotY = robotY
            coord.lastRobotAngle = robotAngle
            coord.lastTrajectoryCount = trajectory.count
        }
    }
}

