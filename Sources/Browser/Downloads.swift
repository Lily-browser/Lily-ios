import Foundation
import Observation
import WebKit
import os

/// Files a page sends instead of showing (attachments, PDFs a page forces, archives). They land in a private
/// temporary folder, one folder per download so names never collide or overwrite, and then the system's
/// "Save to Files" sheet asks where to keep them. Nothing is kept in Lily's own storage between launches.
@MainActor @Observable
final class Downloads: NSObject, WKDownloadDelegate {
    static let shared = Downloads()
    /// A download that grows past this is cancelled, so a hostile stream can't fill the device.
    static let maxBytes: Int64 = 2_000_000_000

    struct Item: Identifiable, Equatable {
        enum State: Equatable { case running, done, failed }
        let id: UUID
        var name: String
        var state: State
        var fileURL: URL?
    }

    private(set) var items: [Item] = []
    /// The file that just arrived; the browser view offers to save it.
    var finished: Item?
    @ObservationIgnored private var byDownload: [ObjectIdentifier: (id: UUID, watch: NSKeyValueObservation?)] = [:]
    @ObservationIgnored private let log = Logger(subsystem: "dev.lily.browser.ios", category: "downloads")

    nonisolated static var folder: URL { FileManager.default.temporaryDirectory.appendingPathComponent("Downloads", isDirectory: true) }

    /// Called once at launch: downloads from earlier runs are not kept.
    nonisolated static func purge() { try? FileManager.default.removeItem(at: folder) }

    /// A safe file name: no folders, no hidden or empty names, bounded length.
    nonisolated static func safeName(_ suggested: String) -> String {
        let last = suggested.split(whereSeparator: { "/\\:".contains($0) }).last.map(String.init) ?? ""
        let cleaned = String(last.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }.prefix(120))
            .trimmingCharacters(in: CharacterSet(charactersIn: ". ").union(.whitespacesAndNewlines))
        return cleaned.isEmpty ? "download" : cleaned
    }

    func remove(_ id: UUID) {
        if let item = items.first(where: { $0.id == id }), let url = item.fileURL { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        items.removeAll { $0.id == id }
    }

    func clear() {
        Self.purge()
        items.removeAll { $0.state != .running }
    }

    // MARK: WKDownloadDelegate

    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String) async -> URL? {
        let name = Self.safeName(suggestedFilename)
        if response.expectedContentLength > Self.maxBytes {
            items.append(Item(id: UUID(), name: name, state: .failed))
            return nil
        }
        let folder = Self.folder.appendingPathComponent(UUID().uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true,
                                                    attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        } catch {
            return nil
        }
        let id = UUID()
        items.append(Item(id: id, name: name, state: .running, fileURL: folder.appendingPathComponent(name)))
        let watch = download.progress.observe(\.completedUnitCount) { progress, _ in
            if progress.completedUnitCount > Downloads.maxBytes { download.cancel { _ in } }
        }
        byDownload[ObjectIdentifier(download)] = (id, watch)
        return folder.appendingPathComponent(name)
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let entry = byDownload.removeValue(forKey: ObjectIdentifier(download)), let index = items.firstIndex(where: { $0.id == entry.id }) else { return }
        items[index].state = .done
        finished = items[index]
    }

    func download(_ download: WKDownload, didFailWithError error: any Error, resumeData: Data?) {
        guard let entry = byDownload.removeValue(forKey: ObjectIdentifier(download)), let index = items.firstIndex(where: { $0.id == entry.id }) else { return }
        log.error("Download failed (\(String(describing: (error as NSError).code), privacy: .public))")
        items[index].state = .failed
        if let url = items[index].fileURL { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        items[index].fileURL = nil
    }
}
