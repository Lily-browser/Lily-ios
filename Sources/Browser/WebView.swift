import SwiftUI
import LilyKit
import WebKit
import Observation

/// Lets the toolbar drive the visible web view (back, forward, reload) without owning it.
@MainActor @Observable
final class WebController {
    @ObservationIgnored weak var web: WKWebView?
    private(set) var canGoBack = false
    private(set) var canGoForward = false
    private(set) var isLoading = false
    /// Phone layouts slide the bottom bar away while you read (scroll down) and bring it back on scroll up.
    private(set) var chromeHidden = false
    func setChromeHidden(_ hidden: Bool) { if chromeHidden != hidden { chromeHidden = hidden } }

    func goBack() { web?.goBack() }
    func goForward() { web?.goForward() }
    func reload() { web?.reload() }
    func reloadFromOrigin() { web?.reloadFromOrigin() }
    /// ⌘F: the system find bar (match count, next/previous, highlights in the page).
    func find() { web?.findInteraction?.presentFindNavigator(showingReplace: false) }
    func findNext() { web?.findInteraction?.findNext() }
    func findPrevious() { web?.findInteraction?.findPrevious() }
    func printPage() {
        guard let web else { return }
        let info = UIPrintInfo(dictionary: nil)
        info.jobName = web.title ?? "Page"
        info.outputType = .general
        let controller = UIPrintInteractionController.shared
        controller.printInfo = info
        controller.printFormatter = web.viewPrintFormatter()
        controller.present(animated: true)
    }
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
    var zoom: Double = 1
    var site: SiteSettings.Site = SiteSettings.Site()
    var isPrivate = false
    let onChange: @MainActor (UUID, URL?, String?) -> Void
    var onOpen: @MainActor (URL) -> Void = { _ in }

    /// "Dark" and "Force Dark" both ask the page for its dark theme; iOS has no inverting mode.
    static func style(_ mode: SiteSettings.DarkMode?) -> UIUserInterfaceStyle {
        switch mode ?? .standard { case .standard: .unspecified; case .dark, .forced: .dark; case .light: .light }
    }

    func makeCoordinator() -> Coordinator { Coordinator(controller: controller, snapshots: snapshots, onChange: onChange, onOpen: onOpen) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = site.javaScript ?? true
        if isPrivate { configuration.websiteDataStore = PrivateBrowsing.store }
        let web = WKWebView(frame: .zero, configuration: configuration)
        Blocking.configure(web, adsAllowed: site.adsAllowed ?? false)
        web.overrideUserInterfaceStyle = Self.style(site.darkMode)
        web.navigationDelegate = context.coordinator
        web.uiDelegate = context.coordinator
        web.allowsBackForwardNavigationGestures = true
        web.isFindInteractionEnabled = true
        web.pageZoom = zoom
        web.isOpaque = false
        web.backgroundColor = .clear
        context.coordinator.tabID = tab.id
        context.coordinator.adsAllowed = site.adsAllowed ?? false
        controller.web = web
        context.coordinator.watchScrolling(of: web)
        controller.setChromeHidden(false)
        if let url = tab.url { context.coordinator.lastRequested = url; web.load(URLRequest(url: url)) }
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        context.coordinator.tabID = tab.id
        controller.web = web
        if web.pageZoom != zoom { web.pageZoom = zoom }
        web.overrideUserInterfaceStyle = Self.style(site.darkMode)
        // JavaScript and ad lists apply from the next load, so changing them reloads the page once.
        let js = site.javaScript ?? true, ads = site.adsAllowed ?? false
        if web.configuration.defaultWebpagePreferences.allowsContentJavaScript != js || context.coordinator.adsAllowed != ads {
            web.configuration.defaultWebpagePreferences.allowsContentJavaScript = js
            context.coordinator.adsAllowed = ads
            Blocking.configure(web, adsAllowed: ads)
            web.reload()
        }
        if let url = tab.url, web.url != url, context.coordinator.lastRequested != url {
            context.coordinator.lastRequested = url
            web.load(URLRequest(url: url))
        }
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var adsAllowed = false
        var tabID = UUID()
        var lastRequested: URL?
        private var scrollObservation: NSKeyValueObservation?
        private var lastOffset: CGFloat = 0
        private let controller: WebController
        private let snapshots: SnapshotCache
        private let onChange: @MainActor (UUID, URL?, String?) -> Void
        private let onOpen: @MainActor (URL) -> Void

        init(controller: WebController, snapshots: SnapshotCache, onChange: @escaping @MainActor (UUID, URL?, String?) -> Void,
             onOpen: @escaping @MainActor (URL) -> Void) {
            self.controller = controller
            self.snapshots = snapshots
            self.onChange = onChange
            self.onOpen = onOpen
        }

        /// Links that ask for a new window (target=_blank, window.open) become a new tab.
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url, ["http", "https"].contains(url.scheme?.lowercased()) { onOpen(url) }
            return nil
        }

        /// Reading direction decides the bar: down hides it, up (or the top of the page) shows it. Only the
        /// user's own scrolling counts, so page-driven jumps and rubber-banding don't flicker it.
        func watchScrolling(of web: WKWebView) {
            scrollObservation = web.scrollView.observe(\.contentOffset, options: [.new]) { [weak self] scrollView, _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    let offset = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
                    defer { self.lastOffset = offset }
                    guard scrollView.isDragging || scrollView.isDecelerating else { return }
                    let delta = offset - self.lastOffset
                    if offset <= 8 || delta < -10 { self.controller.setChromeHidden(false) }
                    else if delta > 10, offset > 80 { self.controller.setChromeHidden(true) }
                }
            }
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
