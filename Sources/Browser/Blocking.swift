import LilyKit
import Observation
import WebKit

/// Content blocking for every web view: LilyKit's built-in list plus the filter lists chosen in Settings,
/// compiled to WebKit content rule lists (nothing leaves the device but the list downloads).
///
/// EasyList and EasyPrivacy are on from the first launch (the built-in list alone is only ~130 ad domains).
/// WebKit applies a rule list to loads that start after it is attached, so web views are registered here and
/// re-attached, and reloaded once, whenever the compiled lists change.
@MainActor
enum Blocking {
    static let blocker = AdBlocker(store: .default(), directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Lily/filters"))
    private static var preparing: Task<Void, Never>?
    private static var pages: [Entry] = []
    private static var generation = 0

    private struct Entry {
        weak var web: WKWebView?
        var adsAllowed: Bool
        var appliedGeneration: Int
    }

    /// Compiles or loads the lists once; every window waits for the same task so no page loads unfiltered.
    /// The very first launch also waits (up to `firstRunWait`) for the default lists to download and compile.
    static func prepare(firstRunWait: Duration = .seconds(25)) async {
        if preparing == nil {
            preparing = Task {
                enableDefaultLists()
                await blocker.prepare()
                try? await Task.sleep(for: .milliseconds(150)) // let a rebuild started by prepare() begin
                let deadline = ContinuousClock.now + firstRunWait
                while blocker.isUpdating, ContinuousClock.now < deadline { try? await Task.sleep(for: .milliseconds(200)) }
                watch()
            }
        }
        await preparing?.value
    }

    /// First launch only: nothing chosen yet means the defaults, which the user can change in Settings.
    private static func enableDefaultLists() {
        guard UserDefaults.standard.stringArray(forKey: Preferences.Key.filterLists) == nil else { return }
        blocker.setList("easylist", enabled: true)
        blocker.setList("easyprivacy", enabled: true)
    }

    /// `adsAllowed` is the per-site "allow ads" choice (SiteSettings), so ad blocking can be off for one site.
    static func configure(_ web: WKWebView, adsAllowed: Bool = false) {
        blocker.configure(web.configuration.userContentController, adsAllowed: adsAllowed)
        pages.removeAll { $0.web == nil }
        if let index = pages.firstIndex(where: { $0.web === web }) {
            pages[index].adsAllowed = adsAllowed
            pages[index].appliedGeneration = generation
        } else {
            pages.append(Entry(web: web, adsAllowed: adsAllowed, appliedGeneration: generation))
        }
    }

    /// Re-attaches the lists after a rebuild finishes, and reloads pages that were loaded without them.
    private static func watch() {
        withObservationTracking { _ = blocker.isUpdating } onChange: {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                if !blocker.isUpdating { reapply() }
                watch()
            }
        }
    }

    private static func reapply() {
        generation += 1
        for index in pages.indices {
            guard let web = pages[index].web else { continue }
            blocker.configure(web.configuration.userContentController, adsAllowed: pages[index].adsAllowed)
            pages[index].appliedGeneration = generation
            if !pages[index].adsAllowed, web.url != nil { web.reload() }
        }
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
