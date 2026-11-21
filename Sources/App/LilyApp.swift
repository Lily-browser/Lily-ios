import SwiftUI

@main
struct LilyApp: App {
    @State private var model = BrowserModel(file: .standard)

    var body: some Scene {
        WindowGroup {
            BrowserView(model: model)
        }
    }
}
