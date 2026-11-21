import SwiftUI

struct BrowserView: View {
    @Bindable var model: BrowserModel
    @State private var controllers = ControllerStore()
    @State private var snapshots = SnapshotCache()
    @State private var showingCommandBar = false
    @State private var showingSidebar = false
    @State private var showingSiteSettings = false
    @AppStorage(Settings.accentKey) private var accent = Theme.accentHex
    @AppStorage(Settings.modeKey) private var mode = Settings.Mode.system.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var columns = NavigationSplitViewVisibility.all

    /// The controller of the focused page (the one the toolbar and shortcuts drive).
    private var web: WebController { controllers.controller(for: model.activeID) }

    var body: some View {
        Group { if sizeClass == .regular { regularBody } else { compactBody } }
            .focusedSceneValue(\.browserActions, BrowserActions(
                model: model, web: web,
                focusAddress: { showingCommandBar = true },
                newTab: { model.newTab(); showingCommandBar = true },
                toggleSidebar: { columns = columns == .detailOnly ? .all : .detailOnly },
                splitWithNext: splitWithNext))
    }

    /// ⌃⌘1: show the next tab beside this one, or a new tab if there is only one.
    private func splitWithNext() {
        guard sizeClass == .regular else { return }
        let others = model.currentSpaceTabs.filter { $0.id != model.activeID }
        if let target = others.first(where: { $0.id == model.splitID }) ?? others.first { model.split(with: target.id) }
        else { let current = model.activeID; model.newTab(); model.split(with: current) }
    }

    // MARK: iPad, unfolded foldables, wide windows: the Mac's sidebar plus a system toolbar

    private var regularBody: some View {
        ZStack {
            NavigationSplitView(columnVisibility: $columns) {
                SidebarView(model: model, snapshots: snapshots)
                    .navigationSplitViewColumnWidth(min: 240, ideal: 300, max: 360)
            } detail: {
                NavigationStack {
                    ZStack {
                        SpaceBackdrop(colorHex: model.currentSpace.colorHex)
                        panes.padding(.horizontal, 10).padding(.bottom, 10)
                    }
                    .toolbar { regularToolbar }
                    .toolbarTitleDisplayMode(.inline)
                }
            }
            .accessibilityHidden(showingCommandBar)
            if showingCommandBar {
                CommandBar(model: model) { showingCommandBar = false }
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.96, anchor: .top).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .tint(Color(hex: accent))
        .preferredColorScheme(Settings.Mode(rawValue: mode)?.scheme)
        .animation(reduceMotion ? nil : .smooth(duration: 0.22), value: showingCommandBar)
    }

    @ToolbarContentBuilder private var regularToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button { web.goBack() } label: { Image(systemName: "chevron.left") }
                .disabled(!web.canGoBack).accessibilityLabel("Back")
            Button { web.goForward() } label: { Image(systemName: "chevron.right") }
                .disabled(!web.canGoForward).accessibilityLabel("Forward")
            Button { web.reload() } label: { Image(systemName: "arrow.clockwise") }
                .disabled(model.active.url == nil).accessibilityLabel("Reload")
        }
        ToolbarItem(placement: .principal) {
            addressPill.frame(minWidth: 280, maxWidth: 560)
        }
        ToolbarItemGroup(placement: .primaryAction) {
            if model.splitID != nil {
                Button { model.exitSplit() } label: { Image(systemName: "rectangle.split.2x1.slash") }
                    .accessibilityLabel("Exit Split View")
            } else {
                Button { splitWithNext() } label: { Image(systemName: "rectangle.split.2x1") }
                    .accessibilityLabel("Split View")
            }
            if let url = model.active.url { ShareLink(item: url) }
            Button { model.newTab(); showingCommandBar = true } label: { Image(systemName: "plus") }
                .accessibilityLabel("New Tab")
        }
    }

    // MARK: iPhone and other compact windows: bottom bar, tab overview sheet

    private var compactBody: some View {
        ZStack {
            SpaceBackdrop(colorHex: model.currentSpace.colorHex)
            VStack(spacing: 10) {
                pageCard
                if !web.chromeHidden { bottomBar.transition(.move(edge: .bottom).combined(with: .opacity)) }
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)
            .padding(.bottom, web.chromeHidden ? 0 : 6)
            .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: web.chromeHidden)
            .accessibilityHidden(showingCommandBar)
            if showingCommandBar {
                CommandBar(model: model) { showingCommandBar = false }
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.96, anchor: .top).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .tint(Color(hex: accent))
        .preferredColorScheme(Settings.Mode(rawValue: mode)?.scheme)
        .animation(reduceMotion ? nil : .smooth(duration: 0.22), value: showingCommandBar)
        .sheet(isPresented: $showingSiteSettings) {
            SiteSettingsSheet(model: model, url: model.active.url)
                .presentationDetents([.medium])
                .tint(Color(hex: accent))
        }
        .sheet(isPresented: $showingSidebar) {
            TabOverview(model: model, snapshots: snapshots) { showingSidebar = false }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .tint(Color(hex: accent))
                .preferredColorScheme(Settings.Mode(rawValue: mode)?.scheme)
        }
    }

    private var pageCard: some View { card(for: model.active) }

    /// One page, or two side by side in Split View. Each pane has a small header: tap it to focus that
    /// page (the toolbar and shortcuts follow focus), × to leave the split keeping that page.
    @ViewBuilder private var panes: some View {
        let split = model.splitPanes
        if split.count == 2 {
            HStack(spacing: 10) {
                ForEach(split) { tab in
                    VStack(spacing: 6) {
                        paneHeader(tab)
                        card(for: tab)
                            .overlay(RoundedRectangle(cornerRadius: Theme.pageRadius, style: .continuous)
                                .strokeBorder(tab.id == model.activeID ? Color(hex: accent).opacity(0.7) : .clear, lineWidth: 2))
                    }
                }
            }
        } else {
            pageCard
        }
    }

    private func paneHeader(_ tab: TabItem) -> some View {
        let focused = tab.id == model.activeID
        return HStack(spacing: 8) {
            Button { model.select(tab.id) } label: {
                HStack(spacing: 8) {
                    SiteBadge(tab: tab, size: 18)
                    Text(tab.displayTitle).font(.footnote.weight(focused ? .semibold : .regular)).lineLimit(1)
                    Spacer(minLength: 0)
                }
                .frame(minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(tab.displayTitle), \(focused ? "focused pane" : "pane")")
            .accessibilityHint("Focuses this page")
            Button { model.unsplit(keeping: tab.id) } label: {
                Image(systemName: "xmark").font(.footnote.weight(.semibold)).frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
            .accessibilityLabel("Show only \(tab.displayTitle)")
        }
        .padding(.horizontal, 8)
        .frame(height: 30)
    }

    private func card(for tab: TabItem) -> some View {
        ZStack {
            Color(.systemBackground)
            if tab.url == nil {
                StartPage(space: model.currentSpace)
            } else {
                WebView(tab: tab, controller: controllers.controller(for: tab.id), snapshots: snapshots,
                        zoom: model.zoom(for: tab.url), site: model.sites.site(for: tab.url),
                        onChange: { id, url, title in model.pageChanged(id, url: url, title: title) },
                        onOpen: { model.open($0) })
                    .id(tab.id)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.pageRadius, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 3)
    }

    /// One glass group (iOS 26+): the buttons and the address pill share a container so they blend and
    /// morph together instead of stacking separate blurs.
    @ViewBuilder private var bottomBar: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 10) { barContent }
        } else {
            barContent
        }
    }

    private var barContent: some View {
        HStack(spacing: 8) {
            barButton("chevron.left", "Back", enabled: web.canGoBack) { web.goBack() }
            addressPill
            barButton("square.on.square", "Tabs and spaces", enabled: true) {
                Task {
                    if let image = await web.snapshot() { snapshots.set(image, for: model.activeID) }
                    showingSidebar = true
                }
            }
            barButton("plus", "New Tab", enabled: true) { model.newTab(); showingCommandBar = true }
        }
    }

    private var addressPill: some View {
        Button { showingCommandBar = true } label: {
            HStack(spacing: 6) {
                Image(systemName: model.active.url == nil ? "magnifyingglass" : "lock.fill").font(.caption.weight(.semibold))
                Text(model.active.shortAddress.isEmpty ? "Search or enter address" : model.active.shortAddress)
                    .font(.subheadline.weight(.medium)).lineLimit(1).truncationMode(.middle)
            }
            .foregroundStyle(model.active.url == nil ? .secondary : .primary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .chrome(Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(model.active.shortAddress.isEmpty ? "Search or enter address" : "Address, \(model.active.shortAddress)")
        .accessibilityHint("Opens the search field")
        .contextMenu {
            if let url = model.active.url {
                ShareLink(item: url)
                Button("Copy Link", systemImage: "link") { UIPasteboard.general.url = url }
                Button("Reload", systemImage: "arrow.clockwise") { web.reload() }
                Button("Website Settings…", systemImage: "slider.horizontal.3") { showingSiteSettings = true }
            }
        }
    }

    private func barButton(_ symbol: String, _ label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.callout.weight(.semibold))
                .frame(width: 44, height: 44)
                .chrome(Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? Color.primary : Color.secondary.opacity(0.6))
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}

/// One `WebController` per tab, created on demand. A plain reference (not observed): views observe the
/// controllers themselves.
@MainActor final class ControllerStore {
    private var all: [UUID: WebController] = [:]
    func controller(for id: UUID) -> WebController {
        if let found = all[id] { return found }
        let made = WebController(); all[id] = made; return made
    }
}

private struct StartPage: View {
    let space: Space
    @AppStorage(Settings.accentKey) private var accentHex = Theme.accentHex
    @ScaledMetric(relativeTo: .largeTitle) private var leaf: CGFloat = 54

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "leaf.fill").font(.system(size: leaf)).foregroundStyle(Color(hex: accentHex)).accessibilityHidden(true)
            Text("Lily").font(.largeTitle.weight(.semibold))
            Label(space.name, systemImage: space.symbol)
                .font(.subheadline.weight(.semibold)).foregroundStyle(Color(hex: space.colorHex))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}
