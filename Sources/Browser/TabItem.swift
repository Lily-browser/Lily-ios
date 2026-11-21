import Foundation

/// A workspace with its own tabs, a symbol and a color (like Spaces on the Mac).
struct Space: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    var name: String
    var symbol: String
    var colorHex: String

    init(id: UUID = UUID(), name: String, symbol: String, colorHex: String) {
        self.id = id; self.name = name; self.symbol = symbol; self.colorHex = colorHex
    }

    static let defaults = [
        Space(name: "Personal", symbol: "person.fill", colorHex: "#5E5CE6"),
        Space(name: "Work", symbol: "briefcase.fill", colorHex: "#0A84FF"),
        Space(name: "Play", symbol: "gamecontroller.fill", colorHex: "#34C759"),
    ]
}

/// Metadata-first tab: just enough to list, search and restore it. A web view exists only for the
/// visible tab (see `BrowserModel`), so thousands of tabs cost a few hundred bytes each.
struct TabItem: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    var spaceID: UUID
    var url: URL?
    var title: String
    var isPinned: Bool

    init(id: UUID = UUID(), spaceID: UUID, url: URL? = nil, title: String = "", isPinned: Bool = false) {
        self.id = id; self.spaceID = spaceID; self.url = url; self.title = title; self.isPinned = isPinned
    }

    /// What lists show: the title, else the host, else "New Tab".
    var displayTitle: String {
        if !title.isEmpty { return title }
        return url?.host ?? "New Tab"
    }

    /// "example.com/path" without scheme or www, as the Mac's address pill shows it.
    var shortAddress: String {
        guard let url, let host = url.host else { return "" }
        let path = url.path == "/" ? "" : url.path
        return host.replacingOccurrences(of: "www.", with: "", options: .anchored) + path
    }
}
