import Foundation

/// What pages and the address bar may load, decided from the address alone (pure, so it is tested without WebKit).
enum NavigationPolicy {
    enum Decision: Equatable { case allow, cancel, openExternally }

    /// Only web pages and a blank page can be a tab's address (typed, restored or opened from another app).
    static func isLoadable(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        if scheme == "http" || scheme == "https" { return url.host?.isEmpty == false }
        return url.absoluteString.lowercased() == "about:blank"
    }

    /// Schemes a tapped link may hand to the system (which asks before calling or composing).
    private static let external: Set<String> = ["tel", "mailto", "sms", "facetime", "facetime-audio"]

    /// A navigation a page asked for. `file:`, `itms-services:` and unknown schemes never load; `data:` only inside
    /// frames, never as the page itself; calls, mail and messages only from a tap, never from a script.
    static func decision(for url: URL, isMainFrame: Bool, userInitiated: Bool) -> Decision {
        guard let scheme = url.scheme?.lowercased() else { return .cancel }
        switch scheme {
        case "http", "https", "blob", "javascript": return .allow // javascript: is the page's own script
        case "about": return ["about:blank", "about:srcdoc"].contains(url.absoluteString.lowercased()) ? .allow : .cancel
        case "data": return isMainFrame ? .cancel : .allow
        default: return external.contains(scheme) && userInitiated ? .openExternally : .cancel
        }
    }
}
