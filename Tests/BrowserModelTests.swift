import Foundation
import Testing
@testable import Lily

@MainActor
struct BrowserModelTests {
    @Test func startsWithOneEmptyTabInTheFirstSpace() {
        let model = BrowserModel()
        #expect(model.tabs.count == 1)
        #expect(model.active.url == nil && model.active.displayTitle == "New Tab")
        #expect(model.active.spaceID == model.currentSpaceID)
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

    @Test func closingTheLastTabInASpaceLeavesAFreshOne() {
        let model = BrowserModel()
        let only = model.activeID
        model.close(only)
        #expect(model.tabs.count == 1 && model.activeID != only)
    }

    @Test func spacesKeepTheirOwnTabsAndRememberTheActiveOne() {
        let model = BrowserModel()
        let personal = model.currentSpaceID
        model.newTab()
        let personalActive = model.activeID
        model.selectSpace(model.spaces[1].id)
        #expect(model.currentSpaceID != personal)
        #expect(model.regularTabs.count == 1 && model.active.spaceID == model.currentSpaceID)
        model.selectSpace(personal)
        #expect(model.activeID == personalActive)
        #expect(model.regularTabs.count == 2)
    }

    @Test func pinningMovesATabToThePinnedGrid() {
        let model = BrowserModel()
        model.togglePin(model.activeID)
        #expect(model.pinnedTabs.count == 1 && model.regularTabs.isEmpty)
        model.togglePin(model.activeID)
        #expect(model.pinnedTabs.isEmpty && model.regularTabs.count == 1)
    }

    @Test func pageChangesUpdateTheTitleAndAddressShown() {
        let model = BrowserModel()
        model.pageChanged(model.activeID, url: URL(string: "https://www.example.com/a"), title: "Example")
        #expect(model.active.displayTitle == "Example")
        #expect(model.active.shortAddress == "example.com/a")
        #expect(model.matches("exam").count == 1)
    }
}
