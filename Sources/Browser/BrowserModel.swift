import Foundation
import LilyKit
import Observation

/// Spaces, their tabs and what's selected. The tab model and session storage are LilyKit's; this holds the
/// iOS state the views need.
@MainActor @Observable
final class BrowserModel {
    private(set) var spaces: [Space]
    private(set) var currentSpaceID: UUID
    private(set) var tabs: [TabItem]
    private(set) var activeID: UUID
    /// The second pane in Split View (iPad and other wide windows). Not saved: a relaunch starts unsplit.
    private(set) var splitID: UUID?
    /// Recently closed tabs, newest last, for Reopen Closed Tab.
    private(set) var closedTabs: [TabItem] = []
    /// Per-website choices (zoom, dark mode, JavaScript, ads), sealed on disk; shared by every window.
    let sites: SiteSettings
    @ObservationIgnored private var lastActive: [UUID: UUID] = [:]
    @ObservationIgnored private let storage: SessionStorage?
    /// Private tabs: their own non-persistent web data store, never saved, never offered for reopening.
    private(set) var privateIDs: Set<UUID> = []
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    /// With `storage`, every change is saved shortly after it happens. Call `restore()` to bring back the last session.
    init(spaces: [Space] = Space.defaults, storage: SessionStorage? = nil, sites: SiteSettings = SiteSettings(directory: nil)) {
        self.storage = storage
        self.sites = sites
        self.spaces = spaces
        currentSpaceID = spaces[0].id
        let first = TabItem(spaceID: spaces[0].id)
        tabs = [first]
        activeID = first.id
    }

    /// Replaces the fresh state with the saved session (when "Restore tabs on launch" is on), unless the user
    /// has already started browsing.
    func restore() async {
        guard Preferences.restoresSession, let saved = await storage?.load(), !touched else { return }
        apply(saved)
    }

    func apply(_ saved: TabSession) {
        spaces = saved.spaces
        currentSpaceID = saved.currentSpaceID
        tabs = saved.tabs
        activeID = saved.activeID
        splitID = nil
    }

    /// True once the fresh single tab has been used, so a late restore can't clobber it.
    private var touched: Bool { tabs.count != 1 || tabs[0].url != nil }

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

    var splitTab: TabItem? { splitID.flatMap { id in tabs.first { $0.id == id } } }
    var currentSpaceTabs: [TabItem] { pinnedTabs + regularTabs }

    func newTab() {
        let tab = TabItem(spaceID: currentSpaceID)
        tabs.append(tab)
        activate(tab.id)
    }

    func isPrivate(_ id: UUID) -> Bool { privateIDs.contains(id) }

    func newPrivateTab() {
        let tab = TabItem(spaceID: currentSpaceID)
        privateIDs.insert(tab.id)
        tabs.append(tab)
        activate(tab.id)
    }

    /// Opens a page in a new tab next to the others (links from other apps, "Open in New Tab").
    func open(_ url: URL, activate makeActive: Bool = true) {
        let tab = TabItem(spaceID: currentSpaceID, url: url)
        tabs.append(tab)
        if makeActive { activate(tab.id) } else { scheduleSave() }
    }

    func duplicate(_ id: UUID) {
        guard let tab = tabs.first(where: { $0.id == id }), let index = tabs.firstIndex(of: tab) else { return }
        let copy = TabItem(spaceID: tab.spaceID, url: tab.url, title: tab.title)
        tabs.insert(copy, at: index + 1)
        activate(copy.id)
    }

    func move(_ id: UUID, to space: Space) {
        guard spaces.contains(where: { $0.id == space.id }) else { return }
        update(id) { $0.spaceID = space.id; $0.isPinned = false }
        if !tabs.contains(where: { $0.spaceID == currentSpaceID }) { tabs.append(TabItem(spaceID: currentSpaceID)) }
        if !tabs.contains(where: { $0.id == activeID && $0.spaceID == currentSpaceID }) {
            activate(tabs.first { $0.spaceID == currentSpaceID }!.id)
        }
    }

    /// Reorders the unpinned tabs of the current space (drag and drop in the sidebar).
    func moveRegularTabs(from source: IndexSet, to destination: Int) {
        var visible = regularTabs
        visible.move(fromOffsets: source, toOffset: destination)
        let slots = tabs.indices.filter { tabs[$0].spaceID == currentSpaceID && !tabs[$0].isPinned }
        for (slot, tab) in zip(slots, visible) { tabs[slot] = tab }
        scheduleSave()
    }

    func closeBelow(_ id: UUID) {
        let list = regularTabs
        guard let index = list.firstIndex(where: { $0.id == id }) else { return }
        let doomed = Set(list[(index + 1)...].map(\.id))
        remember(tabs.filter { doomed.contains($0.id) })
        tabs.removeAll { doomed.contains($0.id) }
        if let other = splitID, doomed.contains(other) || doomed.contains(activeID) { splitID = nil }
        if doomed.contains(activeID) { activate(id) }
        scheduleSave()
    }

    func reopenClosedTab() {
        guard var tab = closedTabs.popLast() else { return }
        if !spaces.contains(where: { $0.id == tab.spaceID }) { tab.spaceID = currentSpaceID }
        tabs.append(tab)
        select(tab.id)
    }
    var canReopen: Bool { !closedTabs.isEmpty }

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
        guard let tab = tabs.first(where: { $0.id == id }) else { return }
        if tab.spaceID != currentSpaceID { splitID = nil }
        currentSpaceID = tab.spaceID
        activate(id)
    }

    func selectSpace(_ id: UUID) {
        guard spaces.contains(where: { $0.id == id }) else { return }
        if id != currentSpaceID { splitID = nil }
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
        if !privateIDs.contains(id) { remember([tabs[index]]) }
        forgetPrivate([id])
        if splitID == id { splitID = nil }
        tabs.remove(at: index)
        if !tabs.contains(where: { $0.spaceID == space }) { tabs.append(TabItem(spaceID: space)) }
        if id == activeID, let other = splitID, other != id { splitID = nil; activate(other) }
        else if id == activeID {
            let sameSpace = tabs.filter { $0.spaceID == space }
            let next = sameSpace.last { tabs.firstIndex(of: $0)! < index } ?? sameSpace[0]
            activate(next.id)
        }
        scheduleSave()
    }

    /// Closes every unpinned tab in the current space except `keep`.
    func closeOthers(keeping keep: UUID) {
        let closing = tabs.filter { $0.spaceID == currentSpaceID && !$0.isPinned && $0.id != keep }
        remember(closing.filter { !privateIDs.contains($0.id) })
        forgetPrivate(closing.map(\.id))
        splitID = nil
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

    /// What is saved: private tabs are left out, and the selection falls back to a saved tab.
    var snapshot: TabSession {
        var saved = tabs.filter { !privateIDs.contains($0.id) }
        if saved.isEmpty { saved = [TabItem(spaceID: currentSpaceID)] }
        let selected = saved.contains { $0.id == activeID } ? activeID : (saved.first { $0.spaceID == currentSpaceID } ?? saved[0]).id
        return TabSession(spaces: spaces, tabs: saved, activeID: selected, currentSpaceID: currentSpaceID)
    }

    /// Drops private state: when the last private tab goes, its cookies and storage go with it.
    private func forgetPrivate(_ ids: [UUID]) {
        guard !privateIDs.isEmpty else { return }
        privateIDs.subtract(ids)
        if privateIDs.isEmpty { PrivateBrowsing.reset() }
    }

    private func remember(_ closed: [TabItem]) {
        closedTabs.append(contentsOf: closed.filter { $0.url != nil })
        if closedTabs.count > 20 { closedTabs.removeFirst(closedTabs.count - 20) }
    }

    private func activate(_ id: UUID) {
        if splitID == id { splitID = activeID } // choosing the other pane just moves focus
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
