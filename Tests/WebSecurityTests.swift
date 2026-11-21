import Foundation
import Testing
@testable import Lily

struct WebSecurityTests {
    private func url(_ s: String) -> URL { URL(string: s)! }

    @Test func onlyWebPagesAndBlankAreLoadableAddresses() {
        for ok in ["https://example.com", "http://example.com/a?b=c", "about:blank"] { #expect(NavigationPolicy.isLoadable(url(ok)), "\(ok)") }
        for bad in ["file:///etc/hosts", "data:text/html,<b>x</b>", "javascript:alert(1)", "blob:https://example.com/x", "tel:123", "about:config", "https://", "itms-services://?action=download-manifest"] {
            #expect(!NavigationPolicy.isLoadable(url(bad)), "\(bad)")
        }
    }

    @Test func pagesCannotNavigateToLocalOrDangerousSchemes() {
        #expect(NavigationPolicy.decision(for: url("file:///etc/hosts"), isMainFrame: true, userInitiated: true) == .cancel)
        #expect(NavigationPolicy.decision(for: url("itms-services://?action=download-manifest&url=https://x"), isMainFrame: true, userInitiated: true) == .cancel)
        #expect(NavigationPolicy.decision(for: url("foo://bar"), isMainFrame: true, userInitiated: true) == .cancel)
        #expect(NavigationPolicy.decision(for: url("about:config"), isMainFrame: true, userInitiated: true) == .cancel)
        #expect(NavigationPolicy.decision(for: url("data:text/html,<b>x</b>"), isMainFrame: true, userInitiated: true) == .cancel)
        #expect(NavigationPolicy.decision(for: url("data:text/html,<b>x</b>"), isMainFrame: false, userInitiated: false) == .allow)
        #expect(NavigationPolicy.decision(for: url("https://example.com"), isMainFrame: true, userInitiated: false) == .allow)
    }

    @Test func callsAndMailNeedATap() {
        for link in ["tel:+3612345", "mailto:a@b.hu", "sms:123", "facetime:a@b.hu"] {
            #expect(NavigationPolicy.decision(for: url(link), isMainFrame: true, userInitiated: true) == .openExternally, "\(link)")
            #expect(NavigationPolicy.decision(for: url(link), isMainFrame: true, userInitiated: false) == .cancel, "\(link) from a script")
        }
    }

    @Test func errorPageEscapesAndHasNoScript() {
        let evil = url("https://example.com/\"><script>alert(1)</script>")
        let html = ErrorPage.html(ErrorPage.Message(title: "T<", detail: "D&"), address: evil)
        #expect(!html.contains("<script>"))
        #expect(html.contains("T&lt;") && html.contains("D&amp;"))
        #expect(html.contains("default-src 'none'"))
    }

    @Test func errorsAreClassified() {
        let cancelled = NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)
        #expect(ErrorPage.message(for: cancelled) == nil)
        #expect(ErrorPage.message(for: NSError(domain: "WebKitErrorDomain", code: 102)) == nil)
        let cert = NSError(domain: NSURLErrorDomain, code: NSURLErrorServerCertificateUntrusted)
        #expect(ErrorPage.isCertificateProblem(cert) && !ErrorPage.suggestsHTTPFallback(cert))
        #expect(ErrorPage.message(for: cert)?.title == "This connection isn't private")
        #expect(ErrorPage.suggestsHTTPFallback(NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotConnectToHost)))
        // An odd error never leaks its own text.
        let odd = NSError(domain: "X", code: 1, userInfo: [NSLocalizedDescriptionKey: "secret-token-123"])
        #expect(ErrorPage.message(for: odd)?.detail.contains("secret") == false)
    }

    @Test func downloadNamesCannotEscapeTheirFolder() {
        #expect(Downloads.safeName("../../etc/passwd") == "passwd")
        #expect(Downloads.safeName("..") == "download")
        #expect(Downloads.safeName("") == "download")
        #expect(Downloads.safeName(".hidden") == "hidden")
        #expect(Downloads.safeName("a\\b:c.pdf") == "c.pdf")
        #expect(Downloads.safeName(String(repeating: "x", count: 500)).count == 120)
    }

    @MainActor @Test func addressBarRefusesLocalSchemes() {
        let model = BrowserModel()
        model.go(to: "file:///etc/hosts")
        #expect(model.active.url == nil)
        model.go(to: "data:text/html,<script>alert(1)</script>")
        #expect(model.active.url == nil)
        model.go(to: "https://example.com")
        #expect(model.active.url?.host == "example.com")
    }
}
