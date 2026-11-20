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
    /// A small picture of the page as it is now, for the tab overview.
    func snapshot() async -> UIImage? {
        guard let web else { return nil }
        let config = WKSnapshotConfiguration()
        config.snapshotWidth = 320
        return try? await web.takeSnapshot(configuration: config)
    }

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
    let snapshots: SnapshotCache
    let onChange: @MainActor (UUID, URL?, String?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(controller: controller, snapshots: snapshots, onChange: onChange) }

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
        private let snapshots: SnapshotCache
        private let onChange: @MainActor (UUID, URL?, String?) -> Void

        init(controller: WebController, snapshots: SnapshotCache, onChange: @escaping @MainActor (UUID, URL?, String?) -> Void) {
            self.controller = controller
            self.snapshots = snapshots
            self.onChange = onChange
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { controller.sync() }
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) { controller.sync() }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onChange(tabID, webView.url, webView.title)
            controller.sync()
            let id = tabID
            Task { // let the page paint, then keep a thumbnail for the tab overview
                try? await Task.sleep(for: .milliseconds(600))
                if let image = await controller.snapshot() { snapshots.set(image, for: id) }
            }
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) { controller.sync() }
    }
}
