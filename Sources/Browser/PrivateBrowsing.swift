import WebKit

/// One in-memory web data store shared by all private tabs: nothing reaches disk, and it is replaced
/// (so cookies, caches and storage vanish) when the last private tab closes.
@MainActor
enum PrivateBrowsing {
    private(set) static var store = WKWebsiteDataStore.nonPersistent()
    static func reset() { store = WKWebsiteDataStore.nonPersistent() }
}
