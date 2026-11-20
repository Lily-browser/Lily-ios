import SwiftUI
import WebKit

/// One WKWebView for the visible tab. Switching tabs rebuilds it from the tab's URL, so hidden
/// tabs hold no web content process (hibernated by design).
struct WebView: UIViewRepresentable {
    let tab: TabItem
    let onChange: @MainActor (UUID, URL?, String?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }

    func makeUIView(context: Context) -> WKWebView {
        let web = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        web.navigationDelegate = context.coordinator
        web.allowsBackForwardNavigationGestures = true
        context.coordinator.tabID = tab.id
        if let url = tab.url { web.load(URLRequest(url: url)) }
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        context.coordinator.tabID = tab.id
        // Load only when the model asks for a different address than the page already shows.
        if let url = tab.url, web.url != url, !web.isLoading || context.coordinator.lastRequested != url {
            context.coordinator.lastRequested = url
            web.load(URLRequest(url: url))
        }
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        var tabID = UUID()
        var lastRequested: URL?
        private let onChange: @MainActor (UUID, URL?, String?) -> Void

        init(onChange: @escaping @MainActor (UUID, URL?, String?) -> Void) { self.onChange = onChange }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onChange(tabID, webView.url, webView.title)
        }
    }
}
