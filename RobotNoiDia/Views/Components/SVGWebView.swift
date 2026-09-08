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
                image {
                    image-rendering: pixelated;
                    image-rendering: -webkit-optimize-contrast;
                }
                path.trace {
                    stroke: #ffffff;
                    stroke-width: 1.5;
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
