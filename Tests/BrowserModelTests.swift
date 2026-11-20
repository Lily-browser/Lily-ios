import Foundation
import Testing
@testable import Lily

@MainActor
struct BrowserModelTests {
    @Test func startsWithOneEmptyTab() {
        let model = BrowserModel()
        #expect(model.tabs.count == 1)
        #expect(model.active.url == nil)
        #expect(model.active.displayTitle == "New Tab")
    }

    @Test func typedHostBecomesHTTPSAndSearchBecomesSearchURL() {
        let model = BrowserModel()
        model.go(to: "example.com")
        #expect(model.active.url?.scheme == "https")
        model.go(to: "http://example.com")
        #expect(model.active.url?.scheme == "https")
        model.go(to: "swift concurrency")
        #expect(model.active.url?.query?.contains("swift") == true)
    }

    @Test func newTabIsSelectedAndClosingFallsBack() {
        let model = BrowserModel()
        let first = model.activeID
        model.newTab()
        #expect(model.tabs.count == 2 && model.activeID != first)
        model.close(model.activeID)
        #expect(model.activeID == first)
    }

    @Test func closingTheLastTabLeavesAFreshOne() {
        let model = BrowserModel()
        let only = model.activeID
        model.close(only)
        #expect(model.tabs.count == 1 && model.activeID != only)
    }

    @Test func pageChangesUpdateTheTitleShown() {
        let model = BrowserModel()
        model.pageChanged(model.activeID, url: URL(string: "https://example.com/a"), title: "Example")
        #expect(model.active.displayTitle == "Example")
    }
}
