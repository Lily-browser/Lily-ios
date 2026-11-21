import Foundation
import Testing
import LilyKit
@testable import Lily

@MainActor
struct LibraryTests {
    private let page = URL(string: "https://example.com/a")!

    @Test func regularPagesAreRecordedAndPrivateOnesNever() {
        let history = History(directory: nil)
        let model = BrowserModel(history: history, bookmarks: Bookmarks(directory: nil))
        model.pageChanged(model.activeID, url: page, title: "Example")
        #expect(history.visits.count == 1)
        model.newPrivateTab()
        model.pageChanged(model.activeID, url: URL(string: "https://secret.example/x")!, title: "Secret")
        #expect(history.visits.count == 1 && !history.visits.contains { $0.url.host == "secret.example" })
    }

    @Test func historyCanBeTurnedOff() {
        UserDefaults.standard.set(false, forKey: Library.keepHistoryKey)
        defer { UserDefaults.standard.removeObject(forKey: Library.keepHistoryKey) }
        let history = History(directory: nil)
        let model = BrowserModel(history: history, bookmarks: nil)
        model.pageChanged(model.activeID, url: page, title: "Example")
        #expect(history.visits.isEmpty)
    }

    @Test func starTogglesTheActivePage() {
        let bookmarks = Bookmarks(directory: nil)
        let model = BrowserModel(history: nil, bookmarks: bookmarks)
        model.toggleBookmark() // blank tab: nothing to bookmark
        #expect(bookmarks.linkCount == 0)
        model.pageChanged(model.activeID, url: page, title: "Example")
        model.toggleBookmark()
        #expect(model.isBookmarked && bookmarks.contains(page))
        model.toggleBookmark()
        #expect(!model.isBookmarked)
    }
}
