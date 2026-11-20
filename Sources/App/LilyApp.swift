import SwiftUI

@main
struct LilyApp: App {
    var body: some Scene {
        WindowGroup(id: WindowSeed.id) {
            WindowRoot()
        }
        .commands { LilyCommands() }
    }
}

/// One window. The first owns the saved session; more windows (Stage Manager, ⌘N, "Open in New Window")
/// get their own tabs and are not restored.
private struct WindowRoot: View {
    @State private var model: BrowserModel?

    var body: some View {
        if let model {
            BrowserView(model: model)
        } else {
            Color(.systemBackground).ignoresSafeArea().onAppear(perform: makeModel)
        }
    }

    private func makeModel() {
        let primary = WindowSeed.claimPrimary()
        let made = BrowserModel(file: primary ? .standard : nil)
        if let url = WindowSeed.pending.first { WindowSeed.pending.removeFirst(); made.go(to: url.absoluteString) }
        model = made
    }
}
