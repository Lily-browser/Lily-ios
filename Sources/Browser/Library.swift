import Foundation
import LilyKit

/// Bookmarks and history: one sealed store each (encrypted at rest, key in the Keychain), shared by every window.
@MainActor
enum Library {
    private static let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Lily")
    static let history = History(directory: directory)
    static let bookmarks = Bookmarks(directory: directory)
    private static var loading: Task<Void, Never>?

    static func load() async {
        if loading == nil { loading = Task { await history.load(); await bookmarks.load() } }
        await loading?.value
    }

    /// History saves in batches; write what is pending when the app leaves the screen.
    static func flush() async {
        await history.flush()
        await bookmarks.flush()
    }

    /// "Keep browsing history" in Settings. Private tabs are never recorded whatever this says.
    static let keepHistoryKey = "KeepHistory"
    static var keepsHistory: Bool { UserDefaults.standard.object(forKey: keepHistoryKey) as? Bool ?? true }
}
