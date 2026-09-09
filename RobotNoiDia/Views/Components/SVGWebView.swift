import SwiftUI
import WebKit

/// Hiển thị bản đồ SVG LiDAR từ robot bằng WebKit với khả năng tương tác Pinch Zoom, Pan và cập nhật vị trí thời gian thực mượt mà không giật màn hình
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
        Coordinator(self)
    }
    
    public class Coordinator: NSObject, WKNavigationDelegate {
        var parent: SVGWebView
        var lastLoadedBaseSvg: String = ""
        var isPageLoaded: Bool = false
        
        init(_ parent: SVGWebView) {
            self.parent = parent
        }
        
        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isPageLoaded = true
        }
    }
    
    public func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
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
        let coordinator = context.coordinator
        coordinator.parent = self
        
        // Tạo chuỗi tọa độ vết đường đi
        let polyString: String
        if trajectory.count > 1 {
            polyString = trajectory.map { "\($0.x),\($0.y)" }.joined(separator: " ")
        } else {
            polyString = ""
        }
        
        // Trích xuất phần khung phòng cơ bản (loại bỏ dynamic position) để kiểm tra xem phòng có đổi không
        let baseWithoutPos = svgString.components(separatedBy: "<g id=\"robotGroup\"").first ?? svgString
        
        if coordinator.isPageLoaded && coordinator.lastLoadedBaseSvg == baseWithoutPos,
           let rx = robotX, let ry = robotY {
            // Đã tải xong trang và bản đồ nền giữ nguyên -> Cập nhật vị trí và quỹ đạo qua JavaScript siêu mượt (60fps)
            let angle = robotAngle ?? 0.0
            let js = """
            if (window.updateRobot) {
                window.updateRobot(\(rx), \(ry), \(angle));
            }
            if (window.updateTrajectory) {
                window.updateTrajectory('\(polyString)');
            }
            """
            uiView.evaluateJavaScript(js, completionHandler: nil)
        } else {
            // Bản đồ nền thay đổi hoặc trang tải lần đầu -> Load lại HTML đầy đủ
            coordinator.lastLoadedBaseSvg = baseWithoutPos
            coordinator.isPageLoaded = false
            
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
                        width: 98vw;
                        height: 88vh;
                        max-width: 100%;
                        max-height: 100%;
                        display: block;
                        margin: auto;
                        background-color: #090d16;
                    }
                    #robotGroup {
                        transition: transform 0.35s cubic-bezier(0.25, 0.1, 0.25, 1.0);
                    }
                    #robotHeading {
                        transition: transform 0.35s cubic-bezier(0.25, 0.1, 0.25, 1.0);
                    }
                    image {
                        image-rendering: pixelated;
                        image-rendering: -webkit-optimize-contrast;
                    }
                </style>
                <script>
                    window.updateRobot = function(x, y, a) {
                        var rg = document.getElementById('robotGroup');
                        if (rg) rg.setAttribute('transform', 'translate(' + x + ', ' + y + ')');
                        var rh = document.getElementById('robotHeading');
                        if (rh) rh.setAttribute('transform', 'rotate(' + a + ')');
                    };
                    window.updateTrajectory = function(pointsStr) {
                        var tl = document.getElementById('trajectoryLine');
                        if (tl) tl.setAttribute('points', pointsStr);
                        var tld = document.getElementById('trajectoryLineDash');
                        if (tld) tld.setAttribute('points', pointsStr);
                    };
                </script>
            </head>
            <body>
                \(svgString)
            </body>
            </html>
            """
            uiView.loadHTMLString(htmlContent, baseURL: nil)
        }
    }
}
