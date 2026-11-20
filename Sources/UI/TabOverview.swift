import SwiftUI

/// The tab system for a small screen: pinned tabs in a strip, the rest as page cards in a grid,
/// spaces along the bottom. Tap a card to switch, ✕ to close, long-press for more.
struct TabOverview: View {
    @AppStorage(Settings.accentKey) private var accentHex = Theme.accentHex
    let model: BrowserModel
    let snapshots: SnapshotCache
    let dismiss: () -> Void
    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 14) {
                    if !model.pinnedTabs.isEmpty { pinnedStrip }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(model.regularTabs) { tab in
                            TabCard(tab: tab, image: snapshots.images[tab.id], active: tab.id == model.activeID,
                                    close: { snapshots.remove(tab.id); model.close(tab.id) })
                                .onTapGesture { model.select(tab.id); dismiss() }
                                .contextMenu {
                                    Button("Pin", systemImage: "pin") { model.togglePin(tab.id) }
                                    Button("Close Other Tabs", systemImage: "xmark.square") { model.closeOthers(keeping: tab.id) }
                                    Button("Close", systemImage: "xmark", role: .destructive) { snapshots.remove(tab.id); model.close(tab.id) }
                                }
                        }
                        Button { model.newTab(); dismiss() } label: {
                            Label("New Tab", systemImage: "plus").font(.system(size: 16, weight: .medium)).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 150)
                                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14).padding(.bottom, 12)
            }
            spaceSwitcher
        }
        .background(SpaceBackdrop(colorHex: model.currentSpace.colorHex))
        .sheet(isPresented: $showingSettings) { SettingsView(model: model, snapshots: snapshots) }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: model.currentSpace.symbol).font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(hex: model.currentSpace.colorHex))
            Text(model.currentSpace.name).font(.system(size: 17, weight: .semibold))
            Text("\(model.pinnedTabs.count + model.regularTabs.count)").font(.system(size: 14)).foregroundStyle(.secondary)
            Spacer()
            Button { showingSettings = true } label: { Image(systemName: "gearshape").font(.system(size: 17)) }
                .accessibilityLabel("Settings")
            Button("Done", action: dismiss).font(.system(size: 16, weight: .semibold)).padding(.leading, 6)
        }
        .padding(.horizontal, 18).padding(.top, 22).padding(.bottom, 12)
    }

    private var pinnedStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.pinnedTabs) { tab in
                    let active = tab.id == model.activeID
                    HStack(spacing: 8) {
                        SiteBadge(tab: tab, size: 22)
                        Text(tab.displayTitle).font(.system(size: 14, weight: .medium)).lineLimit(1).frame(maxWidth: 110)
                    }
                    .padding(.horizontal, 10).frame(height: 40)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(active ? AnyShapeStyle(Color(hex: accentHex).opacity(0.14)) : AnyShapeStyle(.quaternary.opacity(0.6))))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(active ? Color(hex: accentHex).opacity(0.5) : .clear, lineWidth: 1))
                    .onTapGesture { model.select(tab.id); dismiss() }
                    .contextMenu { Button("Unpin", systemImage: "pin.slash") { model.togglePin(tab.id) } }
                }
            }
        }
    }

    private var spaceSwitcher: some View {
        HStack(spacing: 14) {
            ForEach(model.spaces) { space in
                let current = space.id == model.currentSpaceID
                Button { model.selectSpace(space.id) } label: {
                    Image(systemName: space.symbol)
                        .font(.system(size: current ? 15 : 12, weight: .semibold))
                        .foregroundStyle(current ? Color(hex: space.colorHex) : .secondary)
                        .frame(width: 38, height: 38)
                        .background(current ? Color(hex: space.colorHex).opacity(0.18) : .clear, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(space.name)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(.bar)
    }
}

private struct TabCard: View {
    @AppStorage(Settings.accentKey) private var accentHex = Theme.accentHex
    let tab: TabItem
    let image: UIImage?
    let active: Bool
    let close: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            // The overlay keeps an oversized screenshot from growing the card and pushing the title bar out.
            Color(.systemBackground).overlay(alignment: image == nil ? .center : .top) {
                if let image { Image(uiImage: image).resizable().scaledToFill() } else { SiteBadge(tab: tab, size: 40) }
            }
            .clipped()
            HStack(spacing: 6) {
                SiteBadge(tab: tab, size: 18)
                Text(tab.displayTitle).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                Spacer(minLength: 0)
                Button(action: close) {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).padding(5)
                        .background(.quaternary, in: Circle())
                }
                .buttonStyle(.plain).accessibilityLabel("Close tab")
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(.regularMaterial)
        }
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(active ? Color(hex: accentHex) : Color.primary.opacity(0.08), lineWidth: active ? 2.5 : 0.5))
        .shadow(color: .black.opacity(0.10), radius: 5, y: 2)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
