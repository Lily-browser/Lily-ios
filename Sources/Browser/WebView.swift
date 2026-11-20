import SwiftUI
import WebKit
import Observation

/// Lets the toolbar drive the visible web view (back, forward, reload) without owning it.
@MainActor @Observable
final class WebController {
    @ObservationIgnored weak var web: WKWebView?
    private(set) var canGoBack = false
    private(set) var canGoForward = false
    private(set) var isLoading = false

    func goBack() { web?.goBack() }
    func goForward() { web?.goForward() }
    func reload() { web?.reload() }
    func stop() { web?.stopLoading() }
    func sync() {
        canGoBack = web?.canGoBack ?? false
        canGoForward = web?.canGoForward ?? false
        isLoading = web?.isLoading ?? false
    }
}

/// One WKWebView for the visible tab. Switching tabs rebuilds it from the tab's URL, so hidden
/// tabs hold no web content process (hibernated by design).
struct WebView: UIViewRepresentable {
    let tab: TabItem
    let controller: WebController
    let onChange: @MainActor (UUID, URL?, String?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(controller: controller, onChange: onChange) }

    func makeUIView(context: Context) -> WKWebView {
        let web = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        web.navigationDelegate = context.coordinator
        web.allowsBackForwardNavigationGestures = true
        web.isOpaque = false
        web.backgroundColor = .clear
        context.coordinator.tabID = tab.id
        controller.web = web
        if let url = tab.url { context.coordinator.lastRequested = url; web.load(URLRequest(url: url)) }
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        context.coordinator.tabID = tab.id
        controller.web = web
        if let url = tab.url, web.url != url, context.coordinator.lastRequested != url {
            context.coordinator.lastRequested = url
            web.load(URLRequest(url: url))
        }
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        var tabID = UUID()
        var lastRequested: URL?
        private let controller: WebController
        private let onChange: @MainActor (UUID, URL?, String?) -> Void

        init(controller: WebController, onChange: @escaping @MainActor (UUID, URL?, String?) -> Void) {
            self.controller = controller
            self.onChange = onChange
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { controller.sync() }
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) { controller.sync() }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onChange(tabID, webView.url, webView.title)
            controller.sync()
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) { controller.sync() }
    }
}
