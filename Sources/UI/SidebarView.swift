import SwiftUI

/// The Mac's sidebar for regular-width windows (iPad, an unfolded foldable, Stage Manager): the current
/// space, pinned tiles, the tab list and a space switcher. A system sidebar, so it collapses with the
/// standard toggle and gets Liquid Glass on iPadOS 26.
struct SidebarView: View {
    let model: BrowserModel
    let snapshots: SnapshotCache
    @State private var showingSettings = false
    @AppStorage(Settings.accentKey) private var accentHex = Theme.accentHex

    var body: some View {
        List {
            if !model.pinnedTabs.isEmpty {
                PinnedTiles(model: model, snapshots: snapshots, accentHex: accentHex)
                    .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 8, trailing: 8))
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
            }
            Section {
                ForEach(model.regularTabs) { tab in
                    row(for: tab)
                        .listRowInsets(EdgeInsets(top: 1, leading: 8, bottom: 1, trailing: 8))
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                }
                .onMove { model.moveRegularTabs(from: $0, to: $1) }
                Button { model.newTab() } label: {
                    Label("New Tab", systemImage: "plus").font(.body).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).padding(.horizontal, 10)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 1, leading: 8, bottom: 1, trailing: 8))
                .listRowBackground(Color.clear).listRowSeparator(.hidden)
            } header: {
                Label {
                    Text(model.currentSpace.name).font(.subheadline.weight(.semibold))
                } icon: {
                    Image(systemName: model.currentSpace.symbol).foregroundStyle(Color(hex: model.currentSpace.colorHex))
                }
                .textCase(nil)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(SpaceBackdrop(colorHex: model.currentSpace.colorHex))
        .safeAreaInset(edge: .bottom) { SpaceSwitcher(model: model).padding(.bottom, 8) }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingSettings = true } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel("Settings")
            }
        }
        .navigationTitle("Lily")
        .sheet(isPresented: $showingSettings) { SettingsView(model: model, snapshots: snapshots) }
    }

    private func row(for tab: TabItem) -> some View {
        let active = tab.id == model.activeID
        return Button { model.select(tab.id) } label: {
            HStack(spacing: 10) {
                SiteBadge(tab: tab, size: 24)
                Text(tab.displayTitle).font(.body).lineLimit(1).truncationMode(.tail)
                Spacer(minLength: 0)
                if model.isPrivate(tab.id) { Image(systemName: "eye.slash").font(.caption).foregroundStyle(.secondary).accessibilityLabel("Private") }
            }
            .padding(.horizontal, 10).frame(minHeight: 44)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(active ? Color(hex: model.currentSpace.colorHex).opacity(0.22) : .clear))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(model.isPrivate(tab.id) ? "\(tab.displayTitle), private" : tab.displayTitle)
        .accessibilityAddTraits(active ? .isSelected : [])
        .swipeActions(edge: .trailing) { Button("Close", role: .destructive) { snapshots.remove(tab.id); model.close(tab.id) } }
        .swipeActions(edge: .leading) { Button("Pin") { model.togglePin(tab.id) }.tint(Color(hex: accentHex)) }
        .contextMenu { TabMenu(model: model, snapshots: snapshots, tab: tab) }
    }
}

private struct PinnedTiles: View {
    let model: BrowserModel
    let snapshots: SnapshotCache
    let accentHex: String

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(model.pinnedTabs) { tab in
                let active = tab.id == model.activeID
                Button { model.select(tab.id) } label: {
                    SiteBadge(tab: tab, size: 30)
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(active ? AnyShapeStyle(Color(hex: accentHex).opacity(0.14)) : AnyShapeStyle(.quaternary.opacity(0.5))))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(active ? Color(hex: accentHex).opacity(0.5) : .clear, lineWidth: 1))
                        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(tab.displayTitle), pinned")
                .accessibilityAddTraits(active ? .isSelected : [])
                .contextMenu { TabMenu(model: model, snapshots: snapshots, tab: tab) }
            }
        }
    }
}

/// The Mac's tab context menu, minus what only makes sense with a pointer-first window manager.
struct TabMenu: View {
    let model: BrowserModel
    let snapshots: SnapshotCache
    let tab: TabItem
    @Environment(\.openWindow) private var openWindow
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        Button(tab.isPinned ? "Unpin" : "Pin", systemImage: tab.isPinned ? "pin.slash" : "pin") { model.togglePin(tab.id) }
        Button("Duplicate", systemImage: "plus.square.on.square") { model.duplicate(tab.id) }
        if sizeClass == .regular, tab.id != model.activeID {
            Button("Open in Split View", systemImage: "rectangle.split.2x1") { model.split(with: tab.id) }
        }
        if let url = tab.url {
            Button("Copy Link", systemImage: "link") { UIPasteboard.general.url = url }
            ShareLink(item: url)
            Button("Open in New Window", systemImage: "macwindow.badge.plus") { WindowSeed.pending.append(url); openWindow(id: WindowSeed.id) }
        }
        let others = model.spaces.filter { $0.id != tab.spaceID }
        if !others.isEmpty {
            Menu("Move to Space", systemImage: "arrow.right.square") {
                ForEach(others) { space in
                    Button(space.name, systemImage: space.symbol) { model.move(tab.id, to: space) }
                }
            }
        }
        Divider()
        if !tab.isPinned {
            Button("Close Tabs Below", systemImage: "arrow.down.to.line") { model.closeBelow(tab.id) }
            Button("Close Other Tabs", systemImage: "xmark.square") { model.closeOthers(keeping: tab.id) }
        }
        Button("Close Tab", systemImage: "xmark", role: .destructive) { snapshots.remove(tab.id); model.close(tab.id) }
    }
}
