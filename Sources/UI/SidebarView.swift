import SwiftUI

/// The Mac sidebar as a sheet: space header, pinned tiles, the tab list, a new-tab row and the
/// space switcher along the bottom.
struct SidebarView: View {
    let model: BrowserModel
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            List {
                if !model.pinnedTabs.isEmpty {
                    PinnedGrid(model: model, dismiss: dismiss)
                        .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 8, trailing: 8))
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                }
                ForEach(model.regularTabs) { tab in
                    TabRow(tab: tab, active: tab.id == model.activeID, spaceColor: model.currentSpace.colorHex)
                        .contentShape(Rectangle())
                        .onTapGesture { model.select(tab.id); dismiss() }
                        .listRowInsets(EdgeInsets(top: 1, leading: 8, bottom: 1, trailing: 8))
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing) { Button("Close", role: .destructive) { model.close(tab.id) } }
                        .swipeActions(edge: .leading) { Button("Pin") { model.togglePin(tab.id) }.tint(Theme.accent) }
                        .contextMenu { Button(tab.isPinned ? "Unpin" : "Pin", systemImage: "pin") { model.togglePin(tab.id) } }
                }
                Button { model.newTab(); dismiss() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus").font(.system(size: 12, weight: .bold)).frame(width: 22, height: 22)
                        Text("New Tab").font(.system(size: 16))
                    }
                    .foregroundStyle(.secondary).padding(.horizontal, 10).frame(height: 38)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 1, leading: 8, bottom: 1, trailing: 8))
                .listRowBackground(Color.clear).listRowSeparator(.hidden)
            }
            .listStyle(.plain).scrollContentBackground(.hidden)
            spaceSwitcher
        }
        .background(SpaceBackdrop(colorHex: model.currentSpace.colorHex))
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: model.currentSpace.symbol).font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(hex: model.currentSpace.colorHex))
            Text(model.currentSpace.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(.secondary)
            Spacer()
            Button("Done", action: dismiss).font(.system(size: 15, weight: .semibold))
        }
        .padding(.horizontal, 18).padding(.top, 22).padding(.bottom, 8)
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

private struct TabRow: View {
    let tab: TabItem
    let active: Bool
    let spaceColor: String

    var body: some View {
        HStack(spacing: 10) {
            SiteBadge(tab: tab, size: 22)
            Text(tab.displayTitle).font(.system(size: 16)).lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10).frame(height: 40)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(active ? Color(hex: spaceColor).opacity(0.22) : .clear))
    }
}

private struct PinnedGrid: View {
    let model: BrowserModel
    let dismiss: () -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(model.pinnedTabs) { tab in
                let active = tab.id == model.activeID
                Button { model.select(tab.id); dismiss() } label: {
                    SiteBadge(tab: tab, size: 28)
                        .frame(maxWidth: .infinity, minHeight: 62)
                        .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(active ? AnyShapeStyle(Theme.accent.opacity(0.12)) : AnyShapeStyle(.quaternary.opacity(0.5))))
                        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(active ? Theme.accent.opacity(0.45) : .clear, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .contextMenu { Button("Unpin", systemImage: "pin.slash") { model.togglePin(tab.id) } }
            }
        }
    }
}
