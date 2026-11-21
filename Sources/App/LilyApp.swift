import SwiftUI

@main
struct LilyApp: App {
    init() { Downloads.purge() }

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
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        if let model {
            BrowserView(model: model)
                .onOpenURL { link in if let page = LilyLink.page(from: link) { model.open(page) } }
                .onChange(of: scenePhase) { _, phase in if phase == .background { Task { await Library.flush() } } }
        } else {
            Color(.systemBackground).ignoresSafeArea()
                .onOpenURL { link in if let page = LilyLink.page(from: link) { WindowSeed.pending.append(page) } } // the window isn't ready yet
                .task { await Blocking.prepare(); await Sites.load(); await Library.load(); makeModel() }
        }
    }

    private func makeModel() {
        let primary = WindowSeed.claimPrimary()
        let made = BrowserModel(storage: primary ? .standard : nil, sites: Sites.shared, history: Library.history, bookmarks: Library.bookmarks)
        if primary { Task { await made.restore() } }
        if let url = WindowSeed.pending.first { WindowSeed.pending.removeFirst(); made.go(to: url.absoluteString) }
        model = made
    }
}
