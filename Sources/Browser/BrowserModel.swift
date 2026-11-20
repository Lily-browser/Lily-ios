import Foundation
import LilyKit
import Observation

/// Spaces, their tabs and what's selected. Platform-neutral logic belongs in LilyKit (issue #3 plans to
/// share the tab model); this holds the iOS state the views need.
@MainActor @Observable
final class BrowserModel {
    private(set) var spaces: [Space]
    private(set) var currentSpaceID: UUID
    private(set) var tabs: [TabItem]
    private(set) var activeID: UUID
    private var lastActive: [UUID: UUID] = [:]
    private let resolver = URLResolver()

    init(spaces: [Space] = Space.defaults) {
        self.spaces = spaces
        currentSpaceID = spaces[0].id
        let first = TabItem(spaceID: spaces[0].id)
        tabs = [first]
        activeID = first.id
    }

    var currentSpace: Space { spaces.first { $0.id == currentSpaceID } ?? spaces[0] }
    var active: TabItem { tabs.first { $0.id == activeID } ?? tabs[0] }
    var pinnedTabs: [TabItem] { tabs.filter { $0.spaceID == currentSpaceID && $0.isPinned } }
    var regularTabs: [TabItem] { tabs.filter { $0.spaceID == currentSpaceID && !$0.isPinned } }
    func count(in space: Space) -> Int { tabs.filter { $0.spaceID == space.id }.count }

    /// Loads what the user typed in the active tab: a URL (upgraded to https when possible) or a search.
    func go(to input: String) {
        guard var url = resolver.resolve(input) else { return }
        url = HTTPSFirst.upgrade(url) ?? url
        update(activeID) { $0.url = url }
    }

    func newTab() {
        let tab = TabItem(spaceID: currentSpaceID)
        tabs.append(tab)
        activate(tab.id)
    }

    func select(_ id: UUID) {
        guard let tab = tabs.first(where: { $0.id == id }) else { return }
        currentSpaceID = tab.spaceID
        activate(id)
    }

    func selectSpace(_ id: UUID) {
        guard spaces.contains(where: { $0.id == id }) else { return }
        currentSpaceID = id
        if let remembered = lastActive[id], tabs.contains(where: { $0.id == remembered }) {
            activeID = remembered
        } else if let first = tabs.first(where: { $0.spaceID == id }) {
            activeID = first.id
        } else {
            newTab()
        }
    }

    func togglePin(_ id: UUID) { update(id) { $0.isPinned.toggle() } }

    /// Closing a space's last tab leaves a fresh empty one, so there is always something to show.
    func close(_ id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let space = tabs[index].spaceID
        tabs.remove(at: index)
        if !tabs.contains(where: { $0.spaceID == space }) { tabs.append(TabItem(spaceID: space)) }
        if id == activeID {
            let sameSpace = tabs.filter { $0.spaceID == space }
            let next = sameSpace.last { tabs.firstIndex(of: $0)! < index } ?? sameSpace[0]
            activate(next.id)
        }
    }

    /// Called by the web view as the page navigates.
    func pageChanged(_ id: UUID, url: URL?, title: String?) {
        update(id) {
            if let url { $0.url = url }
            if let title { $0.title = title }
        }
    }

    /// Tabs whose title or address contains the text, for the command bar.
    func matches(_ text: String) -> [TabItem] {
        let needle = text.lowercased()
        guard !needle.isEmpty else { return [] }
        return tabs.filter { $0.title.lowercased().contains(needle) || ($0.url?.absoluteString.lowercased().contains(needle) ?? false) }
            .prefix(5).map { $0 }
    }

    private func activate(_ id: UUID) {
        activeID = id
        lastActive[currentSpaceID] = id
    }

    private func update(_ id: UUID, _ change: (inout TabItem) -> Void) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        change(&tabs[index])
    }
}
