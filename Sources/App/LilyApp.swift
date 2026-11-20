import SwiftUI

@main
struct LilyApp: App {
    @State private var model = BrowserModel()

    var body: some Scene {
        WindowGroup {
            BrowserView(model: model)
        }
    }
}
