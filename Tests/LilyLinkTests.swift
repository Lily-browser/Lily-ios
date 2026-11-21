import Foundation
import Testing
@testable import Lily

struct LilyLinkTests {
    @Test func aPageSurvivesTheRoundTrip() throws {
        let page = URL(string: "https://example.com/a path?q=1&r=two#frag")
            ?? URL(string: "https://example.com/a%20path?q=1&r=two#frag")!
        let link = try #require(LilyLink.make(for: page))
        #expect(link.scheme == "lily" && link.host == "open")
        #expect(LilyLink.page(from: link) == page)
    }

    @Test func onlyWebPagesAreAccepted() {
        for bad in ["file:///etc/hosts", "javascript:alert(1)", "data:text/html,x", "tel:123", "lily://open", "https://"] {
            #expect(LilyLink.make(for: URL(string: bad)!) == nil, "\(bad)")
        }
        // A hand-made link can't smuggle another scheme through the app's door.
        for bad in ["lily://open?url=javascript:alert(1)", "lily://open?url=file:///etc/hosts", "lily://open?url=data:text/html,x",
                    "lily://other?url=https://example.com", "https://open?url=https://example.com", "lily://open?url=", "lily://open"] {
            #expect(LilyLink.page(from: URL(string: bad)!) == nil, "\(bad)")
        }
    }

    @Test func oversizedAddressesAreRefused() {
        let long = URL(string: "https://example.com/" + String(repeating: "a", count: 9_000))!
        #expect(LilyLink.make(for: long) == nil)
    }

    @MainActor @Test func aLinkOpensANewTabInTheModel() throws {
        let model = BrowserModel()
        let page = try #require(LilyLink.page(from: LilyLink.make(for: URL(string: "https://example.com/x")!)!))
        model.open(page)
        #expect(model.tabs.count == 2 && model.active.url?.host == "example.com")
    }
}
