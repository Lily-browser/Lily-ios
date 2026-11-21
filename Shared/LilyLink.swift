import Foundation

/// The one link other parts of the system use to hand Lily a page: `lily://open?url=<address>`. The Share
/// extension builds it and the app reads it. Only web pages travel in it, and the app checks again before loading.
enum LilyLink {
    static let scheme = "lily"
    static let maxLength = 8_192

    static func isWebPage(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return false }
        return url.host?.isEmpty == false && url.absoluteString.count <= maxLength
    }

    /// The link that opens `page` in Lily; nil unless it is an http(s) page.
    static func make(for page: URL) -> URL? {
        guard isWebPage(page), var parts = URLComponents(string: "\(scheme)://open") else { return nil }
        parts.queryItems = [URLQueryItem(name: "url", value: page.absoluteString)]
        return parts.url
    }

    /// The page a Lily link asks for; nil for anything else (other hosts, other schemes, `javascript:`, `file:`, oversized or malformed).
    static func page(from link: URL) -> URL? {
        guard link.scheme?.lowercased() == scheme, link.host?.lowercased() == "open",
              let raw = URLComponents(url: link, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "url" })?.value,
              raw.count <= maxLength, let page = URL(string: raw), isWebPage(page) else { return nil }
        return page
    }
}
