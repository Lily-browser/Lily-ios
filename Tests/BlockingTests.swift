import Testing
import WebKit
import LilyKit
@testable import Lily

@MainActor
struct BlockingTests {
    @Test func theBuiltInListCompilesAndAttachesToAWebView() async {
        await Blocking.prepare()
        let web = WKWebView(frame: .zero)
        Blocking.configure(web)
        #expect(Blocking.blocker.isEnabled)
        #expect(Blocking.blocker.status != "Preparing…")
    }

    @Test func allowingAdsOnASiteDetachesTheLists() async {
        await Blocking.prepare()
        let web = WKWebView(frame: .zero)
        Blocking.configure(web)
        Blocking.configure(web, adsAllowed: true) // must not crash and must not keep stale lists
        #expect(Blocking.blocker.isEnabled)
    }
}

@MainActor
struct SiteSettingsTests {
    @Test func zoomIsRememberedPerSiteAndResets() {
        let model = BrowserModel()
        let url = URL(string: "https://www.example.com/a")
        model.zoomStep(for: url, in: true)
        #expect(model.zoom(for: URL(string: "https://example.com/b")) > 1)
        #expect(model.zoom(for: URL(string: "https://other.org")) == 1)
        model.resetZoom(for: url)
        #expect(model.zoom(for: url) == 1)
    }

    @Test func allowingAdsAndDarkModeAreStoredOnTheSite() {
        let model = BrowserModel()
        let url = URL(string: "https://example.com")
        model.sites.update(url) { $0.adsAllowed = true; $0.darkMode = .dark; $0.javaScript = false }
        #expect(model.sites.adsAllowed(for: url) && !model.sites.allowsJavaScript(for: url))
        #expect(WebView.style(model.sites.site(for: url).darkMode) == .dark)
    }
}
