import SwiftUI
import WebKit

/// Hiển thị bản đồ SVG LiDAR từ robot bằng WebKit với khả năng tương tác Pinch Zoom & Pan mượt mà
public struct SVGWebView: UIViewRepresentable {
    public let svgString: String
    
    public init(svgString: String) {
        self.svgString = svgString
    }
    
    public func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.maximumZoomScale = 5.0
        webView.scrollView.minimumZoomScale = 0.5
        return webView
    }
    
    public func updateUIView(_ uiView: WKWebView, context: Context) {
        let htmlContent = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes">
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body {
                    background-color: transparent;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    min-height: 100vh;
                    overflow: hidden;
                }
                svg {
                    width: 96vw;
                    height: 82vh;
                    max-width: 100%;
                    max-height: 100%;
                }
            </style>
        </head>
        <body>
            \(svgString)
        </body>
        </html>
        """
        uiView.loadHTMLString(htmlContent, baseURL: nil)
    }
}
