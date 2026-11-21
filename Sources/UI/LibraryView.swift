import LilyKit
import SwiftUI

/// Bookmarks, history and downloads in one sheet.
struct LibraryView: View {
    enum Section: String, CaseIterable, Identifiable {
        case bookmarks = "Bookmarks", history = "History", downloads = "Downloads"
        var id: String { rawValue }
    }

    let model: BrowserModel
    @State var section: Section
    @State private var query = ""
    @State private var confirmingClear = false
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Settings.accentKey) private var accent = Theme.accentHex
    @AppStorage(Settings.modeKey) private var mode = Settings.Mode.system.rawValue

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Library", selection: $section) { ForEach(Section.allCases) { Text($0.rawValue).tag($0) } }
                    .pickerStyle(.segmented).padding(.horizontal, 16).padding(.vertical, 8)
                switch section {
                case .bookmarks: BookmarkList(model: model, query: query, open: open)
                case .history: HistoryList(model: model, query: query, open: open)
                case .downloads: DownloadList()
                }
            }
            .navigationTitle(section.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: section == .history ? "Search history" : "Search bookmarks")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                if section == .history {
                    ToolbarItem(placement: .secondaryAction) {
                        Button("Clear History…", systemImage: "trash", role: .destructive) { confirmingClear = true }
                    }
                }
            }
            .confirmationDialog("Clear history", isPresented: $confirmingClear, titleVisibility: .visible) {
                Button("Last Hour", role: .destructive) { model.history?.clear(since: Date().addingTimeInterval(-3_600)) }
                Button("Today", role: .destructive) { model.history?.clear(since: Calendar.current.startOfDay(for: Date())) }
                Button("All History", role: .destructive) { model.history?.clear() }
            }
        }
        .tint(Color(hex: accent))
        .preferredColorScheme(Settings.Mode(rawValue: mode)?.scheme)
    }

    private func open(_ url: URL, newTab: Bool) {
        if newTab { model.open(url) } else { model.go(to: url.absoluteString) }
        dismiss()
    }
}

private struct Empty: View {
    let title: String, symbol: String, detail: String
    var body: some View { ContentUnavailableView(title, systemImage: symbol, description: Text(detail)) }
}

private struct PageRow: View {
    let title: String
    let url: URL
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.isEmpty ? (url.host ?? url.absoluteString) : title).font(.body).lineLimit(1)
            Text(url.host ?? url.absoluteString).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private extension View {
    func pageMenu(url: URL, open: @escaping (URL, Bool) -> Void) -> some View {
        contextMenu {
            Button("Open", systemImage: "arrow.up.right") { open(url, false) }
            Button("Open in New Tab", systemImage: "plus.square.on.square") { open(url, true) }
            Button("Copy Link", systemImage: "link") { UIPasteboard.general.url = url }
            ShareLink(item: url)
        }
    }
}

private struct BookmarkList: View {
    let model: BrowserModel
    let query: String
    let open: (URL, Bool) -> Void

    var body: some View {
        if let bookmarks = model.bookmarks {
            let found = bookmarks.search(query, limit: 100)
            if query.isEmpty, bookmarks.root.isEmpty {
                Empty(title: "No Bookmarks", symbol: "star", detail: "Tap the star in the address menu to bookmark a page.")
            } else if query.isEmpty {
                List(bookmarks.root, children: \.children) { node in row(node, bookmarks) }
            } else if found.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                List(found) { node in row(node, bookmarks) }
            }
        }
    }

    @ViewBuilder private func row(_ node: Bookmarks.Node, _ bookmarks: Bookmarks) -> some View {
        if let url = node.url {
            Button { open(url, false) } label: { PageRow(title: node.title, url: url) }
                .buttonStyle(.plain)
                .pageMenu(url: url, open: open)
                .swipeActions { Button("Delete", role: .destructive) { bookmarks.remove(node.id) } }
        } else {
            Label(node.title, systemImage: "folder")
                .swipeActions { Button("Delete", role: .destructive) { bookmarks.remove(node.id) } }
        }
    }
}

private struct HistoryList: View {
    let model: BrowserModel
    let query: String
    let open: (URL, Bool) -> Void

    var body: some View {
        if let history = model.history {
            let visits = query.isEmpty ? history.recent(500) : history.search(query, limit: 200)
            let days = Dictionary(grouping: visits) { Calendar.current.startOfDay(for: $0.visitedAt) }.sorted { $0.key > $1.key }
            if visits.isEmpty {
                if query.isEmpty { Empty(title: "No History", symbol: "clock", detail: "Pages you visit show up here. Private tabs are never recorded.") }
                else { ContentUnavailableView.search(text: query) }
            } else {
                List {
                    ForEach(days, id: \.key) { day, visits in
                        SwiftUI.Section(day.formatted(.dateTime.weekday(.wide).day().month(.wide))) {
                            ForEach(visits) { visit in
                                Button { open(visit.url, false) } label: { PageRow(title: visit.title, url: visit.url) }
                                    .buttonStyle(.plain)
                                    .pageMenu(url: visit.url, open: open)
                                    .swipeActions { Button("Delete", role: .destructive) { forget(visit.url, in: history) } }
                            }
                        }
                    }
                }
            }
        }
    }

    /// One row stands for every visit of that page, so deleting it removes them all.
    private func forget(_ url: URL, in history: History) {
        history.remove(Set(history.visits.filter { $0.url == url }.map(\.id)))
    }
}

private struct DownloadList: View {
    private let downloads = Downloads.shared

    var body: some View {
        if downloads.items.isEmpty {
            Empty(title: "No Downloads", symbol: "arrow.down.circle", detail: "Files from websites show up here until you quit Lily. Save them to Files to keep them.")
        } else {
            List {
                ForEach(downloads.items) { item in
                    Button { if item.state == .done { downloads.finished = item } } label: {
                        HStack {
                            Image(systemName: item.state == .failed ? "exclamationmark.triangle" : item.state == .done ? "doc" : "arrow.down.circle")
                                .foregroundStyle(item.state == .failed ? .red : .secondary)
                            VStack(alignment: .leading) {
                                Text(item.name).lineLimit(1)
                                Text(item.state == .done ? "Tap to save to Files" : item.state == .failed ? "Failed" : "Downloading…")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .frame(minHeight: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .swipeActions { Button("Delete", role: .destructive) { downloads.remove(item.id) } }
                }
            }
        }
    }
}
