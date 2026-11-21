import SwiftUI

/// The tab system for a small screen: pinned tabs in a strip, the rest as page cards in a grid,
/// spaces along the bottom. Tap a card to switch, ✕ to close, long-press (or VoiceOver actions) for more.
struct TabOverview: View {
    let model: BrowserModel
    let snapshots: SnapshotCache
    let dismiss: () -> Void
    @State private var showingSettings = false
    @AppStorage(Settings.accentKey) private var accentHex = Theme.accentHex
    @ScaledMetric(relativeTo: .body) private var cardHeight: CGFloat = 150

    var body: some View {
        ZStack(alignment: .bottom) {
            SpaceBackdrop(colorHex: model.currentSpace.colorHex)
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: 14) {
                        if !model.pinnedTabs.isEmpty { pinnedStrip }
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(model.regularTabs) { tab in card(for: tab) }
                            newTabCard
                        }
                    }
                    .padding(.horizontal, 14).padding(.bottom, 84) // room for the floating space switcher
                }
            }
            SpaceSwitcher(model: model).padding(.bottom, 8)
        }
        .sheet(isPresented: $showingSettings) { SettingsView(model: model, snapshots: snapshots) }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Label {
                Text(model.currentSpace.name).font(.headline)
            } icon: {
                Image(systemName: model.currentSpace.symbol).foregroundStyle(Color(hex: model.currentSpace.colorHex))
            }
            Text("\(model.pinnedTabs.count + model.regularTabs.count)").font(.subheadline).foregroundStyle(.secondary)
                .accessibilityLabel("\(model.pinnedTabs.count + model.regularTabs.count) tabs")
            Spacer()
            Button { showingSettings = true } label: {
                Image(systemName: "gearshape").frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .accessibilityLabel("Settings")
            Button("Done", action: dismiss).font(.body.weight(.semibold)).frame(minHeight: 44)
        }
        .padding(.horizontal, 18).padding(.top, 14)
    }

    private func card(for tab: TabItem) -> some View {
        let active = tab.id == model.activeID
        return ZStack(alignment: .topTrailing) {
            Button { model.select(tab.id); dismiss() } label: {
                TabCard(tab: tab, image: snapshots.images[tab.id], active: active, accentHex: accentHex, height: cardHeight)
            }
            .buttonStyle(.plain)
            .overlay(alignment: .topLeading) {
                if model.isPrivate(tab.id) { Image(systemName: "eye.slash").font(.caption.weight(.bold)).padding(8).accessibilityHidden(true) }
            }
            .accessibilityLabel(model.isPrivate(tab.id) ? "\(tab.displayTitle), private" : tab.displayTitle)
            .accessibilityAddTraits(active ? .isSelected : [])
            Button { snapshots.remove(tab.id); model.close(tab.id) } label: {
                Image(systemName: "xmark").font(.caption2.weight(.bold)).padding(6)
                    .background(.quaternary, in: Circle())
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain).padding(.top, -6).padding(.trailing, -6)
            .accessibilityLabel("Close \(tab.displayTitle)")
        }
        .contextMenu {
            Button("Pin", systemImage: "pin") { model.togglePin(tab.id) }
            Button("Close Other Tabs", systemImage: "xmark.square") { model.closeOthers(keeping: tab.id) }
            Button("Close", systemImage: "xmark", role: .destructive) { snapshots.remove(tab.id); model.close(tab.id) }
        }
    }

    private var newTabCard: some View {
        Button { model.newTab(); dismiss() } label: {
            Label("New Tab", systemImage: "plus").font(.callout.weight(.medium)).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: cardHeight)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu { Button("New Private Tab", systemImage: "eye.slash") { model.newPrivateTab(); dismiss() } }
    }

    private var pinnedStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.pinnedTabs) { tab in
                    let active = tab.id == model.activeID
                    Button { model.select(tab.id); dismiss() } label: {
                        HStack(spacing: 8) {
                            SiteBadge(tab: tab, size: 24)
                            Text(tab.displayTitle).font(.subheadline.weight(.medium)).lineLimit(1).frame(maxWidth: 120)
                        }
                        .padding(.horizontal, 12).frame(minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(active ? AnyShapeStyle(Color(hex: accentHex).opacity(0.14)) : AnyShapeStyle(.quaternary.opacity(0.6))))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(active ? Color(hex: accentHex).opacity(0.6) : .clear, lineWidth: 1))
                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(tab.displayTitle), pinned")
                    .accessibilityAddTraits(active ? .isSelected : [])
                    .contextMenu { Button("Unpin", systemImage: "pin.slash") { model.togglePin(tab.id) } }
                }
            }
        }
    }
}

private struct TabCard: View {
    let tab: TabItem
    let image: UIImage?
    let active: Bool
    let accentHex: String
    let height: CGFloat

    var body: some View {
        ZStack(alignment: .top) {
            // The overlay keeps an oversized screenshot from growing the card and pushing the title bar out.
            Color(.systemBackground).overlay(alignment: image == nil ? .center : .top) {
                if let image { Image(uiImage: image).resizable().scaledToFill() } else { SiteBadge(tab: tab, size: 40) }
            }
            .clipped()
            HStack(spacing: 6) {
                SiteBadge(tab: tab, size: 18)
                Text(tab.displayTitle).font(.caption.weight(.semibold)).lineLimit(1)
                Spacer(minLength: 32) // the close button sits over this space
            }
            .padding(.horizontal, 8).padding(.vertical, 8)
            .background(.regularMaterial)
        }
        .frame(height: height)
        // Concentric with the grid's 14 pt margin and the display corners.
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(active ? Color(hex: accentHex) : Color.primary.opacity(0.08), lineWidth: active ? 3 : 0.5))
        .shadow(color: .black.opacity(0.10), radius: 5, y: 2)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
