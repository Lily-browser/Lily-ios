import CryptoKit
import Foundation
import LilyKit
import Testing
import WebKit
@testable import Lily

/// Loads a URL and returns the failure it ended in, or nil if the page committed.
@MainActor
private final class Probe: NSObject, WKNavigationDelegate {
    var failure: NSError?
    var finished = false
    func webView(_ w: WKWebView, didFinish n: WKNavigation!) { finished = true }
    func webView(_ w: WKWebView, didFail n: WKNavigation!, withError e: any Error) { failure = e as NSError; finished = true }
    func webView(_ w: WKWebView, didFailProvisionalNavigation n: WKNavigation!, withError e: any Error) { failure = e as NSError; finished = true }
    func load(_ web: WKWebView, _ url: URL) async {
        web.navigationDelegate = self
        web.load(URLRequest(url: url))
        for _ in 0..<150 where !finished { try? await Task.sleep(for: .milliseconds(100)) }
    }
}

@MainActor
struct RealWorldTests {
    @Test func adDomainsAreBlockedAndOtherPagesAreNot() async {
        await Blocking.prepare()
        let ad = URL(string: "https://doubleclick.net/")!
        let page = URL(string: "https://example.com/")!

        let control = WKWebView(frame: .zero), controlProbe = Probe()
        await controlProbe.load(control, ad)
        let blocked = WKWebView(frame: .zero), blockedProbe = Probe()
        Blocking.configure(blocked)
        await blockedProbe.load(blocked, ad)
        let plain = WKWebView(frame: .zero), plainProbe = Probe()
        Blocking.configure(plain)
        await plainProbe.load(plain, page)

        #expect(blockedProbe.failure != nil)
        #expect(blockedProbe.failure?.code != controlProbe.failure?.code || controlProbe.failure == nil)
        #expect(plainProbe.failure == nil)
    }

    /// A domain that is only in EasyList (not in the ~130-domain built-in list): proves the real lists are on by default.
    @Test func easyListDomainsAreBlockedOutOfTheBox() async {
        await Blocking.prepare()
        for _ in 0..<1200 where Blocking.blocker.isUpdating { try? await Task.sleep(for: .milliseconds(100)) }
        let web = WKWebView(frame: .zero), probe = Probe()
        Blocking.configure(web)
        await probe.load(web, URL(string: "https://0019x.com/")!)
        #expect(Blocking.blocker.isListEnabled("easylist"))
        #expect(probe.failure?.code == 104, "EasyList rule not applied: \(String(describing: probe.failure)); status: \(Blocking.blocker.status)")
    }

    @Test func theRealKeychainSealsAndRestoresASession() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("lily-kc-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = TabSessionStore(directory: dir, keys: KeychainKeyStore())
        let model = BrowserModel()
        await store.save(model.snapshot)
        let loaded = await store.load()
        #expect(loaded == model.snapshot)
    }
}
