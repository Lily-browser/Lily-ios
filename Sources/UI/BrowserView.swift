import SwiftUI

struct BrowserView: View {
    @Bindable var model: BrowserModel
    @State private var web = WebController()
    @State private var snapshots = SnapshotCache()
    @State private var showingCommandBar = false
    @State private var showingSidebar = false
    @AppStorage(Settings.accentKey) private var accent = Theme.accentHex
    @AppStorage(Settings.modeKey) private var mode = Settings.Mode.system.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            SpaceBackdrop(colorHex: model.currentSpace.colorHex)
            VStack(spacing: 10) {
                pageCard
                bottomBar
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)
            .padding(.bottom, 6)
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
        .sheet(isPresented: $showingSidebar) {
            TabOverview(model: model, snapshots: snapshots) { showingSidebar = false }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .tint(Color(hex: accent))
                .preferredColorScheme(Settings.Mode(rawValue: mode)?.scheme)
        }
    }

    private var pageCard: some View {
        ZStack {
            Color(.systemBackground)
            if model.active.url == nil {
                StartPage(space: model.currentSpace)
            } else {
                WebView(tab: model.active, controller: web, snapshots: snapshots) { id, url, title in model.pageChanged(id, url: url, title: title) }
                    .id(model.activeID)
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
