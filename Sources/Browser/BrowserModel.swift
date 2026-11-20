import Foundation
import LilyKit
import Observation

/// The tab list and what's selected. Platform-neutral logic belongs in LilyKit; this holds only the
/// iOS state the views need (see LilyKit issue #3 for the plan to share the tab model).
@MainActor @Observable
final class BrowserModel {
    private(set) var tabs: [TabItem]
    private(set) var activeID: UUID
    private let resolver = URLResolver()

    init() {
        let first = TabItem()
        tabs = [first]
        activeID = first.id
    }

    var active: TabItem { tabs.first { $0.id == activeID } ?? tabs[0] }

    /// Loads what the user typed in the active tab: a URL (upgraded to https when possible) or a search.
    func go(to input: String) {
        guard var url = resolver.resolve(input) else { return }
        url = HTTPSFirst.upgrade(url) ?? url
        update(activeID) { $0.url = url }
    }

    func newTab() {
        let tab = TabItem()
        tabs.append(tab)
        activeID = tab.id
    }

    func select(_ id: UUID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        activeID = id
    }

    /// Closing the last tab leaves a fresh empty one, so there is always something to show.
    func close(_ id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs.remove(at: index)
        if tabs.isEmpty { tabs = [TabItem()] }
        if id == activeID { activeID = tabs[min(index, tabs.count - 1)].id }
    }

    /// Called by the web view as the page navigates.
    func pageChanged(_ id: UUID, url: URL?, title: String?) {
        update(id) {
            if let url { $0.url = url }
            if let title { $0.title = title }
        }
    }

    private func update(_ id: UUID, _ change: (inout TabItem) -> Void) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        change(&tabs[index])
    }
}
