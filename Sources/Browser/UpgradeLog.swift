import Foundation

/// Hosts Lily has just sent over HTTPS instead of HTTP (HTTPS-first), so a failed attempt can offer HTTP, a server
/// that sends HTTPS back to HTTP can't loop, and the attempt gives up quickly instead of after a minute.
@MainActor
enum UpgradeLog {
    private static var hosts: [String: Date] = [:]
    /// A host that doesn't answer on HTTPS is dropped after this long (the system default is 60 s).
    static let attemptTimeout: TimeInterval = 10

    static func record(_ host: String) { hosts[host.lowercased()] = Date() }

    /// True when `host` was upgraded less than `within` seconds ago (default: long enough to cover a slow attempt).
    static func wasUpgraded(_ host: String, within: TimeInterval = 120) -> Bool {
        guard let when = hosts[host.lowercased()] else { return false }
        return Date().timeIntervalSince(when) < within
    }

    static func request(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        if url.scheme?.lowercased() == "https", let host = url.host, wasUpgraded(host) { request.timeoutInterval = attemptTimeout }
        return request
    }
}
