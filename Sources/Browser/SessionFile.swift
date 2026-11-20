import Foundation

/// What survives a relaunch: spaces, tabs and what was selected. Tab addresses are sensitive, so the file
/// is readable only while the device is unlocked and excluded from backups. (Moving it to LilyKit's
/// sealed storage needs a signed build for Keychain access; see docs/PLAN.md.)
struct SessionSnapshot: Codable, Equatable, Sendable {
    var spaces: [Space]
    var tabs: [TabItem]
    var activeID: UUID
    var currentSpaceID: UUID

    /// A snapshot is usable only if every tab belongs to a space and something is selectable.
    var isValid: Bool {
        guard !spaces.isEmpty, !tabs.isEmpty else { return false }
        let ids = Set(spaces.map(\.id))
        return tabs.allSatisfy { ids.contains($0.spaceID) } && ids.contains(currentSpaceID)
    }
}

struct SessionFile: Sendable {
    let url: URL

    static var standard: SessionFile {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return SessionFile(url: base.appendingPathComponent("Lily/session.json"))
    }

    func load() -> SessionSnapshot? {
        guard let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(SessionSnapshot.self, from: data), snapshot.isValid else { return nil }
        return snapshot
    }

    func write(_ snapshot: SessionSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var excluded = url
        try? excluded.setResourceValues(values)
    }

    func delete() { try? FileManager.default.removeItem(at: url) }
}
