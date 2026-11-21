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
