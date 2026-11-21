import Foundation
import LilyKit
import Observation

/// What the views show and the iOS-only state around it. Tab order, selection, spaces, closing and the saved
/// session are LilyKit's `TabCollection`, shared with the Mac; this adds Split View, private tabs, zoom and saving.
@MainActor @Observable
final class BrowserModel {
    private var collection: TabCollection
    var spaces: [Space] { collection.spaces }
    var currentSpaceID: UUID { collection.currentSpaceID }
    var tabs: [TabItem] { collection.tabs }
    /// The collection always holds a tab (closing a space's last one leaves a fresh blank).
    var activeID: UUID { collection.activeID ?? collection.tabs[0].id }
    /// The second pane in Split View (iPad and other wide windows). Not saved: a relaunch starts unsplit.
    private(set) var splitID: UUID?
    /// Per-website choices (zoom, dark mode, JavaScript, ads), sealed on disk; shared by every window.
    let sites: SiteSettings
    @ObservationIgnored private let storage: SessionStorage?
    /// Visited pages and bookmarks (nil in tests that don't need them). Private tabs never reach `history`.
    let history: History?
    let bookmarks: Bookmarks?
    /// Private tabs: their own non-persistent web data store, never saved, never offered for reopening.
    private(set) var privateIDs: Set<UUID> = []
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    /// With `storage`, every change is saved shortly after it happens. Call `restore()` to bring back the last session.
    init(spaces: [Space] = Space.defaults, storage: SessionStorage? = nil, sites: SiteSettings = SiteSettings(directory: nil),
         history: History? = nil, bookmarks: Bookmarks? = nil) {
        self.storage = storage
        self.sites = sites
        self.history = history
        self.bookmarks = bookmarks
        var collection = TabCollection(spaces: spaces)
        collection.create(url: nil)
        self.collection = collection
    }

    /// Replaces the fresh state with the saved session (when "Restore tabs on launch" is on), unless the user
    /// has already started browsing.
    func restore() async {
        guard Preferences.restoresSession, let saved = await storage?.load(), !touched else { return }
        apply(saved)
    }

    func apply(_ saved: TabSession) {
        guard collection.restore(saved, asleep: false) else { return }
        splitID = nil
    }

    /// True once the fresh single tab has been used, so a late restore can't clobber it.
    private var touched: Bool { tabs.count != 1 || tabs[0].url != nil }

    var currentSpace: Space { collection.currentSpace }
    var active: TabItem { collection.active ?? collection.tabs[0] }
    var pinnedTabs: [TabItem] { tabs.filter { $0.spaceID == currentSpaceID && $0.isPinned } }
    var regularTabs: [TabItem] { tabs.filter { $0.spaceID == currentSpaceID && !$0.isPinned } }
    func count(in space: Space) -> Int { tabs.filter { $0.spaceID == space.id }.count }

    /// Loads what the user typed in the active tab: a URL (upgraded to https when possible, with
    /// tracking parameters removed) or a search with the chosen engine. Both follow Settings.
    func go(to input: String) {
        guard var url = Preferences.urlResolver.resolve(input) else { return }
        guard NavigationPolicy.isLoadable(url) else { return } // no file:, data: or other schemes from the address bar
        if Preferences.httpsFirstEnabled, let secure = HTTPSFirst.upgrade(url) {
            if let host = url.host { UpgradeLog.record(host) } // a failed attempt gives up in 10 s and offers HTTP
            url = secure
        }
        if Preferences.flag(Preferences.Key.removeLinkTracking, default: true) { url = LinkTracking.cleaned(url) }
        update(activeID) { $0.url = url }
    }

    var splitTab: TabItem? { splitID.flatMap { id in tabs.first { $0.id == id } } }
    var currentSpaceTabs: [TabItem] { pinnedTabs + regularTabs }

    func newTab() {
        collection.create(url: nil)
        scheduleSave()
    }

    func isPrivate(_ id: UUID) -> Bool { privateIDs.contains(id) }

    func newPrivateTab() {
        privateIDs.insert(collection.create(url: nil).id)
        scheduleSave()
    }

    /// Opens a page in a new tab next to the others (links from other apps, "Open in New Tab").
    func open(_ url: URL, activate makeActive: Bool = true) {
        guard NavigationPolicy.isLoadable(url) else { return }
        collection.create(url: url, activate: makeActive)
        scheduleSave()
    }

    func duplicate(_ id: UUID) {
        collection.duplicate(id)
        scheduleSave()
    }

    func move(_ id: UUID, to space: Space) {
        collection.moveTab(id, toSpace: space.id, unpin: true)
        if collection.visibleTabs.isEmpty { collection.create(url: nil) }
        scheduleSave()
    }

    /// Reorders the unpinned tabs of the current space (drag and drop in the sidebar).
    func moveRegularTabs(from source: IndexSet, to destination: Int) {
        var visible = regularTabs
        visible.move(fromOffsets: source, toOffset: destination)
        let slots = collection.tabs.indices.filter { collection.tabs[$0].spaceID == currentSpaceID && !collection.tabs[$0].isPinned }
        // Place each tab at its slot, front to back: a tab always comes from a later slot, so earlier ones stay put.
        for (slot, tab) in zip(slots, visible) where collection.tabs[slot].id != tab.id { collection.move(tab.id, to: slot) }
        scheduleSave()
    }

    func closeBelow(_ id: UUID) {
        let list = regularTabs
        guard let index = list.firstIndex(where: { $0.id == id }) else { return }
        let doomed = list[(index + 1)...].map(\.id)
        let activeDoomed = doomed.contains(activeID)
        closeTabs(doomed)
        if let other = splitID, doomed.contains(other) || activeDoomed { splitID = nil }
        if activeDoomed { activate(id) }
        scheduleSave()
    }

    func reopenClosedTab() {
        guard collection.reopenClosed() != nil else { return }
        scheduleSave()
    }
    var canReopen: Bool { !collection.recentlyClosed.isEmpty }

    /// ⌘1–⌘8 pick the nth tab, ⌘9 the last one.
    func selectTab(number: Int) {
        let list = currentSpaceTabs
        guard !list.isEmpty else { return }
        select((number >= 9 ? list.last! : list[min(number, list.count) - 1]).id)
    }

    func selectNextTab(_ step: Int) {
        let list = currentSpaceTabs
        guard let index = list.firstIndex(where: { $0.id == activeID }), !list.isEmpty else { return }
        select(list[(index + step + list.count) % list.count].id)
    }

    func selectNextSpace(_ step: Int) {
        guard let index = spaces.firstIndex(where: { $0.id == currentSpaceID }) else { return }
        selectSpace(spaces[(index + step + spaces.count) % spaces.count].id)
    }

    // MARK: Zoom

    func zoom(for url: URL?) -> Double { sites.zoom(for: url) }
    func zoomStep(for url: URL?, in zoomingIn: Bool) {
        let next = SiteSettings.zoomLevel(after: zoom(for: url), zoomingIn: zoomingIn)
        sites.update(url) { $0.zoom = next }
    }
    func resetZoom(for url: URL?) { sites.update(url) { $0.zoom = nil } }

    // MARK: Split View

    /// Shows `id` next to the active tab. Splitting with the active tab itself does nothing.
    func split(with id: UUID) {
        guard id != activeID, tabs.contains(where: { $0.id == id }) else { return }
        splitID = id
    }
    func exitSplit() { splitID = nil }
    /// Both panes, in the order the tabs are listed (so choosing a pane never swaps their sides).
    var splitPanes: [TabItem] {
        guard let other = splitTab else { return [] }
        return [active, other].sorted { (tabs.firstIndex(of: $0) ?? 0) < (tabs.firstIndex(of: $1) ?? 0) }
    }
    /// Closes one pane's place in the split: the other tab stays and becomes the only page.
    func unsplit(keeping id: UUID) {
        splitID = nil
        if id != activeID { activate(id) }
    }

    func select(_ id: UUID) {
        guard let tab = collection.tab(id) else { return }
        if tab.spaceID != currentSpaceID { splitID = nil }
        activate(id)
    }

    func selectSpace(_ id: UUID) {
        guard spaces.contains(where: { $0.id == id }) else { return }
        if id != currentSpaceID { splitID = nil }
        collection.switchSpace(to: id)
        if collection.visibleTabs.isEmpty { collection.create(url: nil) }
        scheduleSave()
    }

    func togglePin(_ id: UUID) {
        guard let tab = collection.tab(id) else { return }
        collection.setPinned(id, !tab.isPinned)
        scheduleSave()
    }

    func rename(_ space: Space, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var changed = spaces.first(where: { $0.id == space.id }) else { return }
        changed.name = String(trimmed.prefix(24))
        collection.updateSpace(changed)
        scheduleSave()
    }

    func recolor(_ space: Space, to colorHex: String) {
        guard var changed = spaces.first(where: { $0.id == space.id }) else { return }
        changed.colorHex = colorHex
        collection.updateSpace(changed)
        scheduleSave()
    }

    /// Closing a space's last tab leaves a fresh empty one, so there is always something to show.
    func close(_ id: UUID) {
        guard collection.tab(id) != nil else { return }
        let wasActive = id == activeID
        let other = splitID
        if splitID == id { splitID = nil }
        collection.close(id, then: .above, keepSpaceNonEmpty: true, remember: !privateIDs.contains(id))
        forgetPrivate([id])
        if wasActive, let other, other != id { splitID = nil; activate(other) }
        scheduleSave()
    }

    /// Closes every unpinned tab in the current space except `keep`.
    func closeOthers(keeping keep: UUID) {
        closeTabs(regularTabs.map(\.id).filter { $0 != keep })
        splitID = nil
        if collection.tab(keep) != nil { activate(keep) } else { select(collection.visibleTabs.first?.id ?? activeID) }
    }

    /// Called by the web view as the page navigates.
    func pageChanged(_ id: UUID, url: URL?, title: String?) {
        update(id) {
            if let url { $0.url = url }
            if let title { $0.title = title }
        }
        if let url, !privateIDs.contains(id), Library.keepsHistory { history?.record(url: url, title: title) }
    }

    // MARK: Bookmarks

    var isBookmarked: Bool { active.url.map { bookmarks?.contains($0) ?? false } ?? false }

    /// Bookmarks the page in front of you, or removes its bookmark. A bookmark is the user's own choice, so it
    /// works in private tabs too (and is the one thing a private tab leaves behind).
    func toggleBookmark() {
        guard let url = active.url, let bookmarks else { return }
        bookmarks.toggle(title: active.displayTitle, url: url)
    }

    /// Tabs whose title or address contains the text, for the command bar.
    func matches(_ text: String) -> [TabItem] {
        let needle = text.lowercased()
        guard !needle.isEmpty else { return [] }
        return tabs.filter { $0.title.lowercased().contains(needle) || ($0.url?.absoluteString.lowercased().contains(needle) ?? false) }
            .prefix(5).map { $0 }
    }

    /// What is saved: private tabs are left out, and the selection falls back to a saved tab.
    var snapshot: TabSession {
        if let saved = collection.session(excluding: privateIDs, keepingBlankTabs: true) { return saved }
        let blank = TabItem(spaceID: currentSpaceID)
        return TabSession(spaces: spaces, tabs: [blank], activeID: blank.id, currentSpaceID: currentSpaceID)
    }

    /// Drops private state: when the last private tab goes, its cookies and storage go with it.
    private func forgetPrivate(_ ids: [UUID]) {
        guard !privateIDs.isEmpty else { return }
        privateIDs.subtract(ids)
        if privateIDs.isEmpty { PrivateBrowsing.reset() }
    }

    /// Closes tabs one by one (private ones are never remembered for reopening).
    private func closeTabs(_ ids: [UUID]) {
        for id in ids { collection.close(id, remember: !privateIDs.contains(id)) }
        forgetPrivate(ids)
    }

    private func activate(_ id: UUID) {
        if splitID == id { splitID = activeID } // choosing the other pane just moves focus
        collection.activate(id)
        scheduleSave()
    }

    private func update(_ id: UUID, _ change: (inout TabItem) -> Void) {
        collection.update(id, change)
        scheduleSave()
    }

    /// Coalesces bursts of changes into one write shortly after the last.
    private func scheduleSave() {
        guard let storage else { return }
        saveTask?.cancel()
        let snapshot = snapshot
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await storage.save(snapshot)
        }
    }
}
