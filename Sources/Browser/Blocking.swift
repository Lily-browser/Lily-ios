import LilyKit
import WebKit

/// Content blocking for every web view: LilyKit's built-in list plus the filter lists chosen in Settings,
/// compiled to WebKit content rule lists (nothing leaves the device but the list downloads).
@MainActor
enum Blocking {
    static let blocker = AdBlocker(store: .default(), directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Lily/filters"))
    private static var preparing: Task<Void, Never>?

    /// Compiles or loads the lists once; every window waits for the same task so no page loads unfiltered.
    static func prepare() async {
        if preparing == nil { preparing = Task { await blocker.prepare() } }
        await preparing?.value
    }

    /// `adsAllowed` is the per-site "allow ads" choice (SiteSettings), so ad blocking can be off for one site.
    static func configure(_ web: WKWebView, adsAllowed: Bool = false) {
        blocker.configure(web.configuration.userContentController, adsAllowed: adsAllowed)
    }
}

/// The one sealed site-settings store, shared by every window.
@MainActor
enum Sites {
    static let shared = SiteSettings(directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Lily"))
    private static var loading: Task<Void, Never>?
    static func load() async {
        if loading == nil { loading = Task { await shared.load() } }
        await loading?.value
    }
}
