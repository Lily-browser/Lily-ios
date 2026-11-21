import SwiftUI
import Observation

/// Small page thumbnails for the tab overview. Memory only, never written to disk, so what you
/// browsed isn't left behind as pictures; cleared with "Clear Browsing Data".
@MainActor @Observable
final class SnapshotCache {
    private(set) var images: [UUID: UIImage] = [:]
    func set(_ image: UIImage, for id: UUID) { images[id] = image }
    func remove(_ id: UUID) { images[id] = nil }
    func clear() { images = [:] }
}
