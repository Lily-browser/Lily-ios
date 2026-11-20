import SwiftUI

/// The Mac's floating command bar: a blurred card over a dimmed window with the field on top and
/// matching tabs and the search action below.
struct CommandBar: View {
    let model: BrowserModel
    let dismiss: () -> Void
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.28).ignoresSafeArea().onTapGesture(perform: dismiss)
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").font(.system(size: 18, weight: .medium)).foregroundStyle(.secondary)
                    TextField("Search or enter address", text: $text)
                        .font(.system(size: 19, weight: .medium))
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .keyboardType(.webSearch).submitLabel(.go)
                        .focused($focused)
                        .onSubmit(open)
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                let rows = results
                if !rows.isEmpty {
                    Divider().padding(.horizontal, 12)
                    VStack(spacing: 2) { ForEach(rows) { row in resultRow(row) } }.padding(8)
                }
            }
            .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.separator.opacity(0.6), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.28), radius: 30, y: 14)
            .padding(.horizontal, 14).padding(.top, 70)
        }
        .onAppear { focused = true }
    }

    private struct Row: Identifiable {
        let id: String
        let title: String
        let subtitle: String?
        let symbol: String?
        let tab: TabItem?
    }

    private var results: [Row] {
        var rows: [Row] = []
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            rows.append(Row(id: "go", title: trimmed, subtitle: "Search or open", symbol: "arrow.up.right", tab: nil))
        }
        let tabs = trimmed.isEmpty ? Array(model.regularTabs.filter { $0.url != nil }.prefix(5)) : model.matches(trimmed)
        rows += tabs.map { Row(id: $0.id.uuidString, title: $0.displayTitle, subtitle: $0.shortAddress, symbol: nil, tab: $0) }
        return rows
    }

    private func resultRow(_ row: Row) -> some View {
        Button {
            if let tab = row.tab { model.select(tab.id); dismiss() } else { open() }
        } label: {
            HStack(spacing: 10) {
                if let tab = row.tab { SiteBadge(tab: tab, size: 24) }
                else { Image(systemName: row.symbol ?? "globe").frame(width: 24, height: 24).foregroundStyle(Theme.accent) }
                VStack(alignment: .leading, spacing: 1) {
                    Text(row.title).font(.system(size: 15, weight: .medium)).lineLimit(1)
                    if let subtitle = row.subtitle, !subtitle.isEmpty {
                        Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer()
                if row.tab == nil { Image(systemName: "return").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary) }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(row.id == "go" ? AnyShapeStyle(Theme.accent.opacity(0.14)) : AnyShapeStyle(.clear),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func open() {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        model.go(to: text)
        dismiss()
    }
}
