import UIKit
import UniformTypeIdentifiers

/// "Lily" in the share sheet: takes the page being shared (Safari, Mail, Messages, any app that shares a web
/// address) and opens it in Lily in a new tab. It reads only the address, shows no screen of its own, and hands
/// it over as a `lily://open?url=` link, which the app validates again.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        Task { await handOver() }
    }

    private func handOver() async {
        if let page = await sharedPage(), let link = LilyLink.make(for: page) { open(link) }
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func sharedPage() async -> URL? {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? []).flatMap { $0.attachments ?? [] }
        for provider in providers where provider.canLoadObject(ofClass: URL.self) {
            let url: URL? = await withCheckedContinuation { continuation in
                _ = provider.loadObject(ofClass: URL.self) { url, _ in continuation.resume(returning: url) }
            }
            if let url, LilyLink.isWebPage(url) { return url }
        }
        return nil
    }

    /// Extensions can't call `UIApplication.shared`; the application is still reachable up the responder chain.
    private func open(_ link: URL) {
        var responder: UIResponder? = self
        while let current = responder {
            if let application = current as? UIApplication {
                application.open(link, options: [:], completionHandler: nil)
                return
            }
            responder = current.next
        }
    }
}
