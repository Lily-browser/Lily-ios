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
    @ObservationIgnored private var lastActive: [UUID: UUID] = [:]
    @ObservationIgnored private let file: SessionFile?
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    /// With a `file`, the previous session is restored (when "Restore tabs on launch" is on) and every
    /// change is saved shortly after it happens.
    init(spaces: [Space] = Space.defaults, file: SessionFile? = nil) {
        self.file = file
        if Preferences.restoresSession, let saved = file?.load() {
            self.spaces = saved.spaces
            currentSpaceID = saved.currentSpaceID
            tabs = saved.tabs
            activeID = saved.tabs.contains { $0.id == saved.activeID } ? saved.activeID : saved.tabs[0].id
            return
        }
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

    /// Loads what the user typed in the active tab: a URL (upgraded to https when possible, with
    /// tracking parameters removed) or a search with the chosen engine. Both follow Settings.
    func go(to input: String) {
        guard var url = Preferences.urlResolver.resolve(input) else { return }
        if Preferences.httpsFirstEnabled { url = HTTPSFirst.upgrade(url) ?? url }
        if Preferences.flag(Preferences.Key.removeLinkTracking, default: true) { url = LinkTracking.cleaned(url) }
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
            scheduleSave()
        } else if let first = tabs.first(where: { $0.spaceID == id }) {
            activeID = first.id
            scheduleSave()
        } else {
            newTab()
        }
    }

    func togglePin(_ id: UUID) { update(id) { $0.isPinned.toggle() } }

    func rename(_ space: Space, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = spaces.firstIndex(where: { $0.id == space.id }) else { return }
        spaces[index].name = String(trimmed.prefix(24))
        scheduleSave()
    }

    func recolor(_ space: Space, to colorHex: String) {
        guard let index = spaces.firstIndex(where: { $0.id == space.id }) else { return }
        spaces[index].colorHex = colorHex
        scheduleSave()
    }

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
        scheduleSave()
    }

    /// Closes every unpinned tab in the current space except `keep`.
    func closeOthers(keeping keep: UUID) {
        tabs.removeAll { $0.spaceID == currentSpaceID && !$0.isPinned && $0.id != keep }
        if tabs.contains(where: { $0.id == keep }) { activate(keep) } else { select(tabs.first { $0.spaceID == currentSpaceID }?.id ?? active.id) }
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

    var snapshot: SessionSnapshot {
        SessionSnapshot(spaces: spaces, tabs: tabs, activeID: activeID, currentSpaceID: currentSpaceID)
    }

    private func activate(_ id: UUID) {
        activeID = id
        lastActive[currentSpaceID] = id
        scheduleSave()
    }

    private func update(_ id: UUID, _ change: (inout TabItem) -> Void) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        change(&tabs[index])
        scheduleSave()
    }

    /// Coalesces bursts of changes into one write shortly after the last.
    private func scheduleSave() {
        guard let file else { return }
        saveTask?.cancel()
        let snapshot = snapshot
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await Task.detached { file.write(snapshot) }.value
        }
    }
}
