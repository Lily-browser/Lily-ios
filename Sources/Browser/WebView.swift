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
        context.coordinator.isPrivate = isPrivate
        context.coordinator.adsAllowed = site.adsAllowed ?? false
        controller.web = web
        context.coordinator.watchScrolling(of: web)
        controller.setChromeHidden(false)
        if let url = tab.url, NavigationPolicy.isLoadable(url) { context.coordinator.lastRequested = url; web.load(URLRequest(url: url)) }
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
        if let url = tab.url, web.url != url, context.coordinator.lastRequested != url, NavigationPolicy.isLoadable(url) {
            context.coordinator.lastRequested = url
            web.load(URLRequest(url: url))
        }
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var adsAllowed = false
        var isPrivate = false
        var tabID = UUID()
        var lastRequested: URL?
        private var scrollObservation: NSKeyValueObservation?
        private var lastOffset: CGFloat = 0
        /// Pages may open one window without a tap and show a few dialogs per page load; the rest are ignored.
        private var scriptedPopups = 0
        private var dialogs = 0
        /// Hosts this tab just sent over HTTPS, so a server that bounces back to HTTP can't loop us.
        private var upgraded: [String: Date] = [:]
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

        // MARK: Navigation policy

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let url = action.request.url else { return .cancel }
            if action.shouldPerformDownload { return .download }
            let isMain = action.targetFrame?.isMainFrame ?? true
            switch NavigationPolicy.decision(for: url, isMainFrame: isMain, userInitiated: action.navigationType == .linkActivated) {
            case .cancel:
                return .cancel
            case .openExternally:
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                return .cancel
            case .allow:
                guard action.targetFrame?.isMainFrame == true, let host = url.host?.lowercased(), let secure = HTTPSFirst.upgrade(url) else { return .allow }
                if let last = upgraded[host], Date().timeIntervalSince(last) < 10 {
                    HTTPSFirst.allowedHTTPHosts.insert(host) // this host sends HTTPS back to HTTP: stop trying
                    return .allow
                }
                upgraded[host] = Date()
                webView.load(URLRequest(url: secure))
                return .cancel
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse) async -> WKNavigationResponsePolicy {
            if !response.canShowMIMEType { return .download }
            if response.isForMainFrame, let http = response.response as? HTTPURLResponse,
               (http.value(forHTTPHeaderField: "Content-Disposition") ?? "").lowercased().hasPrefix("attachment") { return .download }
            return .allow
        }

        func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) { download.delegate = Downloads.shared }
        func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) { download.delegate = Downloads.shared }

        /// Links that ask for a new window (target=_blank, window.open) become a new tab. A tap may open as many as
        /// it likes; a script gets one per page load, so a page can't bury you in tabs.
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            guard let url = navigationAction.request.url, ["http", "https"].contains(url.scheme?.lowercased()) else { return nil }
            if navigationAction.navigationType != .linkActivated {
                guard scriptedPopups < 1 else { return nil }
                scriptedPopups += 1
            }
            onOpen(url)
            return nil
        }

        // MARK: Errors

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
            controller.sync()
            show(error, in: webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
            controller.sync()
            show(error, in: webView)
        }

        private func show(_ error: any Error, in web: WKWebView) {
            let ns = error as NSError
            guard let message = ErrorPage.message(for: ns) else { return }
            let failing = (ns.userInfo[NSURLErrorFailingURLErrorKey] as? URL) ?? web.url ?? lastRequested
            guard let failing, NavigationPolicy.isLoadable(failing), failing.scheme?.lowercased() != "about" else { return }
            if failing.scheme?.lowercased() == "https", let host = failing.host?.lowercased(), upgraded[host] != nil,
               ErrorPage.suggestsHTTPFallback(ns), var parts = URLComponents(url: failing, resolvingAgainstBaseURL: false) {
                parts.scheme = "http"
                if let insecure = parts.url {
                    Task { await offerHTTP(host: host, insecure: insecure, in: web, fallback: (message, failing)) }
                    return
                }
            }
            web.loadSimulatedRequest(URLRequest(url: failing), responseHTML: ErrorPage.html(message, address: failing))
        }

        /// HTTPS-First's rule: a site with no secure connection opens over HTTP only after you agree, for this run only.
        private func offerHTTP(host: String, insecure: URL, in web: WKWebView, fallback: (ErrorPage.Message, URL)) async {
            let answer = await Presenter.ask(title: "\(host) isn't available securely",
                                             message: "Its secure (HTTPS) connection failed. Opening it over HTTP means anyone on the network can read or change what you send and see.",
                                             actions: ["Open with HTTP"], cancel: "Cancel")
            if answer.index == 0 {
                HTTPSFirst.allowedHTTPHosts.insert(host)
                web.load(URLRequest(url: insecure))
            } else {
                web.loadSimulatedRequest(URLRequest(url: fallback.1), responseHTML: ErrorPage.html(fallback.0, address: fallback.1))
            }
        }

        // MARK: JavaScript dialogs

        private func allowDialog() -> Bool { dialogs += 1; return dialogs <= 3 }
        private func source(_ frame: WKFrameInfo) -> String { frame.securityOrigin.host.isEmpty ? "This page says" : "\(frame.securityOrigin.host) says" }

        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo) async {
            guard allowDialog() else { return }
            _ = await Presenter.ask(title: source(frame), message: message, actions: ["OK"], cancel: nil)
        }

        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo) async -> Bool {
            guard allowDialog() else { return false }
            return await Presenter.ask(title: source(frame), message: message, actions: ["OK"], cancel: "Cancel").index == 0
        }

        func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo) async -> String? {
            guard allowDialog() else { return nil }
            let answer = await Presenter.ask(title: source(frame), message: prompt, actions: ["OK"], cancel: "Cancel", field: ("", String((defaultText ?? "").prefix(500))))
            return answer.index == 0 ? (answer.text ?? "") : nil
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
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            scriptedPopups = 0
            dialogs = 0
            controller.sync()
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onChange(tabID, webView.url, webView.title)
            controller.sync()
            guard !isPrivate else { return } // no picture of a private page is kept, not even in memory
            let id = tabID
            Task { // let the page paint, then keep a thumbnail for the tab overview
                try? await Task.sleep(for: .milliseconds(600))
                if let image = await controller.snapshot() { snapshots.set(image, for: id) }
            }
        }
    }
}
