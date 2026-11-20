import SwiftUI

struct BrowserView: View {
    @Bindable var model: BrowserModel
    @State private var web = WebController()
    @State private var snapshots = SnapshotCache()
    @AppStorage(Settings.accentKey) private var accent = Theme.accentHex
    @AppStorage(Settings.modeKey) private var mode = Settings.Mode.system.rawValue
    @State private var showingCommandBar = false
    @State private var showingSidebar = false

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
            if showingCommandBar {
                CommandBar(model: model) { showingCommandBar = false }
                    .transition(.scale(scale: 0.96, anchor: .top).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .tint(Color(hex: accent))
        .preferredColorScheme(Settings.Mode(rawValue: mode)?.scheme)
        .animation(.smooth(duration: 0.22), value: showingCommandBar)
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

    private var bottomBar: some View {
        HStack(spacing: 8) {
            barButton("chevron.left", "Back", enabled: web.canGoBack) { web.goBack() }
            Button { showingCommandBar = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: model.active.url == nil ? "magnifyingglass" : "lock.fill").font(.system(size: 12, weight: .semibold))
                    Text(model.active.shortAddress.isEmpty ? "Search or enter address" : model.active.shortAddress)
                        .font(.system(size: 15, weight: .medium)).lineLimit(1).truncationMode(.middle)
                }
                .foregroundStyle(model.active.url == nil ? .secondary : .primary)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(.regularMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.separator.opacity(0.5), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            barButton("square.on.square", "Tabs and spaces", enabled: true) {
                Task {
                    if let image = await web.snapshot() { snapshots.set(image, for: model.activeID) }
                    showingSidebar = true
                }
            }
            barButton("plus", "New Tab", enabled: true) { model.newTab(); showingCommandBar = true }
        }
    }

    private func barButton(_ symbol: String, _ label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 15, weight: .semibold))
                .frame(width: 40, height: 40)
                .background(.regularMaterial, in: Circle())
                .overlay(Circle().strokeBorder(.separator.opacity(0.5), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? Color.primary : Color.secondary.opacity(0.45))
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}

private struct StartPage: View {
    @AppStorage(Settings.accentKey) private var accentHex = Theme.accentHex
    let space: Space
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "leaf.fill").font(.system(size: 54)).foregroundStyle(Color(hex: accentHex))
            Text("Lily").font(.largeTitle.weight(.semibold))
            Label(space.name, systemImage: space.symbol)
                .font(.subheadline.weight(.semibold)).foregroundStyle(Color(hex: space.colorHex))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
