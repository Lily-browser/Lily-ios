import Foundation

/// Metadata-first tab: just enough to list, search and restore it. A web view exists only for the
/// visible tab (see `BrowserModel`), so thousands of tabs cost a few hundred bytes each.
struct TabItem: Identifiable, Equatable, Sendable {
    let id: UUID
    var url: URL?
    var title: String
    var isPinned: Bool

    init(id: UUID = UUID(), url: URL? = nil, title: String = "", isPinned: Bool = false) {
        self.id = id
        self.url = url
        self.title = title
        self.isPinned = isPinned
    }

    /// What the tab switcher shows: the title, else the host, else "New Tab".
    var displayTitle: String {
        if !title.isEmpty { return title }
        return url?.host ?? "New Tab"
    }
}
