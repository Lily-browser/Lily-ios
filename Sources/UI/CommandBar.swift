import SwiftUI

/// The Mac's floating command bar: a card over a dimmed window with the field on top and matching
/// tabs and the search action below. Dismisses with a tap outside, the VoiceOver escape gesture or Go.
struct CommandBar: View {
    let model: BrowserModel
    let dismiss: () -> Void
    @State private var text = ""
    @FocusState private var focused: Bool
    @AppStorage(Settings.accentKey) private var accentHex = Theme.accentHex

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.28).ignoresSafeArea().onTapGesture(perform: dismiss).accessibilityHidden(true)
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").font(.title3.weight(.medium)).foregroundStyle(.secondary).accessibilityHidden(true)
                    TextField("Search or enter address", text: $text)
                        .font(.title3.weight(.medium))
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .keyboardType(.webSearch).submitLabel(.go)
                        .focused($focused)
                        .onSubmit(open)
                    if !text.isEmpty {
                        Button { text = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary).frame(width: 44, height: 44).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).accessibilityLabel("Clear text")
                    }
                }
                .padding(.leading, 16).padding(.trailing, text.isEmpty ? 16 : 4).padding(.vertical, text.isEmpty ? 14 : 2)
                let rows = results
                if !rows.isEmpty {
                    Divider().padding(.horizontal, 12)
                    VStack(spacing: 2) { ForEach(rows) { row in resultRow(row) } }.padding(8)
                }
            }
            .chrome(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.22), radius: 30, y: 14)
            .frame(maxWidth: 620)
            .padding(.horizontal, 14).padding(.top, 70)
            .frame(maxWidth: .infinity)
            .accessibilityAddTraits(.isModal)
        }
        .accessibilityAction(.escape, dismiss)
        .onAppear { focused = true }
    }

    private struct Row: Identifiable {
        let id: String
        let title: String
        let subtitle: String?
        let symbol: String?
        let tab: TabItem?
        var url: URL? = nil
    }

    private var results: [Row] {
        var rows: [Row] = []
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            rows.append(Row(id: "go", title: trimmed, subtitle: "Search or open", symbol: "arrow.up.right", tab: nil))
        }
        let tabs = trimmed.isEmpty ? Array(model.regularTabs.filter { $0.url != nil }.prefix(5)) : model.matches(trimmed)
        rows += tabs.map { Row(id: $0.id.uuidString, title: $0.displayTitle, subtitle: $0.shortAddress, symbol: nil, tab: $0) }
        if !trimmed.isEmpty {
            var seen = Set(tabs.compactMap(\.url))
            let marks = (model.bookmarks?.search(trimmed, limit: 3) ?? []).compactMap { node in node.url.map { (node.title, $0, "star") } }
            let past = (model.history?.search(trimmed, limit: 6) ?? []).map { ($0.title, $0.url, "clock") }
            for (title, url, symbol) in (marks + past) where seen.insert(url).inserted && rows.count < 8 {
                rows.append(Row(id: url.absoluteString, title: title.isEmpty ? (url.host ?? url.absoluteString) : title, subtitle: url.host, symbol: symbol, tab: nil, url: url))
            }
        }
        return rows
    }

    private func resultRow(_ row: Row) -> some View {
        Button {
            if let tab = row.tab { model.select(tab.id); dismiss() } else if let url = row.url { model.go(to: url.absoluteString); dismiss() } else { open() }
        } label: {
            HStack(spacing: 10) {
                if let tab = row.tab { SiteBadge(tab: tab, size: 24) }
                else { Image(systemName: row.symbol ?? "globe").frame(width: 24, height: 24).foregroundStyle(Color(hex: accentHex)) }
                VStack(alignment: .leading, spacing: 1) {
                    Text(row.title).font(.subheadline.weight(.medium)).lineLimit(1)
                    if let subtitle = row.subtitle, !subtitle.isEmpty {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer()
                if row.tab == nil, row.url == nil { Image(systemName: "return").font(.caption.weight(.semibold)).foregroundStyle(.secondary).accessibilityHidden(true) }
            }
            .padding(.horizontal, 10).frame(minHeight: 44)
            .background(row.id == "go" ? AnyShapeStyle(Color(hex: accentHex).opacity(0.14)) : AnyShapeStyle(.clear),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(row.tab != nil ? "Switches to this tab" : row.url != nil ? "Opens this page" : "Searches or opens the address")
    }

    private func open() {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        model.go(to: text)
        dismiss()
    }
}
