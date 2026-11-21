import Foundation

/// The page shown when a load fails. Plain HTML with no script, inline style only; nothing from the error
/// (which can echo a server's text) is shown except a fixed message, and the address is escaped.
enum ErrorPage {
    struct Message: Equatable { var title: String; var detail: String }

    /// The user's own stop, and loads that turned into a download, are not errors.
    static func message(for error: NSError) -> Message? {
        if error.domain == NSURLErrorDomain {
            switch error.code {
            case NSURLErrorCancelled: return nil
            case NSURLErrorNotConnectedToInternet, NSURLErrorDataNotAllowed:
                return Message(title: "You're offline", detail: "Check your connection and try again.")
            case NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed:
                return Message(title: "Can't find the server", detail: "Check the address for typing mistakes.")
            case NSURLErrorTimedOut:
                return Message(title: "The server took too long", detail: "It may be busy or unreachable. Try again in a moment.")
            case NSURLErrorCannotConnectToHost, NSURLErrorNetworkConnectionLost:
                return Message(title: "Can't connect", detail: "The server refused or dropped the connection.")
            default:
                if isCertificateProblem(error) {
                    return Message(title: "This connection isn't private",
                                   detail: "Lily couldn't verify who runs this site, so it was blocked to keep your data safe. Attackers might be trying to steal your information.")
                }
            }
        }
        if error.domain == "WebKitErrorDomain", error.code == 102 { return nil } // frame load interrupted (a download took over)
        return Message(title: "Can't open this page", detail: "Something went wrong while loading it.")
    }

    static func isCertificateProblem(_ error: NSError) -> Bool {
        error.domain == NSURLErrorDomain && [NSURLErrorServerCertificateUntrusted, NSURLErrorServerCertificateHasBadDate, NSURLErrorServerCertificateHasUnknownRoot,
                                             NSURLErrorServerCertificateNotYetValid, NSURLErrorClientCertificateRejected, NSURLErrorClientCertificateRequired].contains(error.code)
    }

    /// Failures where trying plain HTTP is a fair question after an HTTPS upgrade: the host may simply not offer HTTPS.
    /// A bad certificate is never one of them.
    static func suggestsHTTPFallback(_ error: NSError) -> Bool {
        error.domain == NSURLErrorDomain && [NSURLErrorCannotConnectToHost, NSURLErrorNetworkConnectionLost, NSURLErrorTimedOut, NSURLErrorSecureConnectionFailed].contains(error.code)
    }

    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "'", with: "&#39;")
    }

    static func html(_ message: Message, address: URL) -> String {
        let host = escape(address.host ?? address.absoluteString)
        let link = escape(address.absoluteString)
        return """
        <!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'">
        <style>
        :root { color-scheme: light dark; }
        body { font: -apple-system-body; font-family: -apple-system, system-ui, sans-serif; margin: 0; min-height: 100vh; display: flex; align-items: center; justify-content: center; text-align: center; }
        main { max-width: 28em; padding: 2em; }
        h1 { font-size: 1.4em; margin: 0 0 .4em; }
        p { color: gray; line-height: 1.45; margin: .4em 0; }
        a { display: inline-block; margin-top: 1.2em; padding: .6em 1.4em; border-radius: 2em; background: rgba(127,127,127,.18); color: inherit; text-decoration: none; font-weight: 600; }
        </style></head><body><main>
        <h1>\(escape(message.title))</h1><p>\(escape(message.detail))</p><p>\(host)</p>
        <a href="\(link)">Try Again</a>
        </main></body></html>
        """
    }
}
