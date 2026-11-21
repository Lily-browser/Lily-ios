import UIKit

/// Shows the small system dialogs a page asks for (JavaScript alert, confirm, prompt) and Lily's own questions.
@MainActor
enum Presenter {
    static var top: UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        var controller = (scene?.keyWindow ?? scene?.windows.first)?.rootViewController
        while let next = controller?.presentedViewController, !next.isBeingDismissed { controller = next }
        return controller
    }

    /// The text a page supplies is cut short so it can't fill the screen, and says whose it is.
    static func clipped(_ text: String, limit: Int = 600) -> String { text.count > limit ? String(text.prefix(limit)) + "…" : text }

    /// Buttons: the first is the default (right) action. Returns the index tapped, or nil when nothing could be shown.
    static func ask(title: String, message: String?, actions: [String], cancel: String?, field: (placeholder: String, text: String)? = nil)
        async -> (index: Int?, text: String?) {
        guard let host = top else { return (nil, nil) }
        return await withCheckedContinuation { continuation in
            let alert = UIAlertController(title: title, message: message.map { clipped($0) }, preferredStyle: .alert)
            var input: UITextField?
            if let field { alert.addTextField { $0.placeholder = field.placeholder; $0.text = field.text; input = $0 } }
            for (index, name) in actions.enumerated() {
                alert.addAction(UIAlertAction(title: name, style: .default) { _ in continuation.resume(returning: (index, input?.text)) })
            }
            if let cancel { alert.addAction(UIAlertAction(title: cancel, style: .cancel) { _ in continuation.resume(returning: (nil, nil)) }) }
            host.present(alert, animated: true)
        }
    }
}
