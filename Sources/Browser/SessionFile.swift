import Foundation
import LilyKit

/// Where the session lives. Tab addresses can carry tokens, so the session is sealed with a Keychain key
/// (LilyKit `TabSessionStore`). The plaintext `session.json` of earlier builds is read once, sealed and removed.
/// If the Keychain refuses (it can in an unsigned build), nothing is saved rather than falling back to plaintext,
/// and an old `session.json` is kept until sealing works.
struct SessionStorage: Sendable {
    private let sealed: TabSessionStore
    private let legacy: LegacySessionFile

    static var standard: SessionStorage {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Lily")
        return SessionStorage(directory: base, keys: KeychainKeyStore())
    }

    init(directory: URL, keys: KeyStore) {
        sealed = TabSessionStore(directory: directory, keys: keys)
        legacy = LegacySessionFile(url: directory.appendingPathComponent("session.json"))
    }

    func load() async -> TabSession? {
        if let session = await sealed.load() { return session }
        guard let old = legacy.load() else { return nil }
        await sealed.save(old)
        if await sealed.load() != nil { legacy.delete() }
        return old
    }

    func save(_ session: TabSession) async {
        await sealed.save(session)
    }
}

struct LegacySessionFile: Sendable {
    let url: URL
    func load() -> TabSession? {
        guard let data = try? Data(contentsOf: url),
              let session = try? JSONDecoder().decode(TabSession.self, from: data), session.isValid else { return nil }
        return session
    }
    func delete() { try? FileManager.default.removeItem(at: url) }
}
