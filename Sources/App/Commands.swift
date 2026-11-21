import SwiftUI

/// What the menu bar and hardware-keyboard shortcuts can do in the focused window.
struct BrowserActions {
    let model: BrowserModel
    let web: WebController
    let focusAddress: () -> Void
    let newTab: () -> Void
    let newPrivateTab: () -> Void
    let toggleSidebar: () -> Void
    let splitWithNext: () -> Void
}

private struct BrowserActionsKey: FocusedValueKey { typealias Value = BrowserActions }
extension FocusedValues {
    var browserActions: BrowserActions? {
        get { self[BrowserActionsKey.self] }
        set { self[BrowserActionsKey.self] = newValue }
    }
}

/// Opens a page in a new window: the caller queues the address, the new window picks it up.
@MainActor enum WindowSeed {
    static let id = "browser"
    static var pending: [URL] = []
    private static var primaryClaimed = false
    /// Only the first window owns the saved session; extra windows start fresh so they can't overwrite it.
    static func claimPrimary() -> Bool { defer { primaryClaimed = true }; return !primaryClaimed }
}

/// The iPad menu bar (hold ⌘ to see the shortcuts) with the Mac's shortcuts.
struct LilyCommands: Commands {
    @FocusedValue(\.browserActions) private var actions
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Tab") { actions?.newTab() }.keyboardShortcut("t").disabled(actions == nil)
            Button("New Private Tab") { actions?.newPrivateTab() }.keyboardShortcut("n", modifiers: [.command, .shift]).disabled(actions == nil)
            Button("New Window") { openWindow(id: WindowSeed.id) }.keyboardShortcut("n")
            Divider()
            Button("Close Tab") { if let a = actions { a.model.close(a.model.activeID) } }.keyboardShortcut("w").disabled(actions == nil)
            Button("Reopen Closed Tab") { actions?.model.reopenClosedTab() }
                .keyboardShortcut("t", modifiers: [.command, .shift]).disabled(!(actions?.model.canReopen ?? false))
        }
        CommandGroup(replacing: .printItem) {
            Button("Print…") { actions?.web.printPage() }.keyboardShortcut("p").disabled(actions == nil)
        }
        CommandGroup(after: .textEditing) {
            Button("Find in Page…") { actions?.web.find() }.keyboardShortcut("f").disabled(actions == nil)
            Button("Find Next") { actions?.web.findNext() }.keyboardShortcut("g").disabled(actions == nil)
            Button("Find Previous") { actions?.web.findPrevious() }.keyboardShortcut("g", modifiers: [.command, .shift]).disabled(actions == nil)
        }
        CommandGroup(replacing: .sidebar) {
            Button("Toggle Sidebar") { actions?.toggleSidebar() }.keyboardShortcut("s").disabled(actions == nil)
            Button("Open Location…") { actions?.focusAddress() }.keyboardShortcut("l").disabled(actions == nil)
            Button("Command Bar") { actions?.focusAddress() }.keyboardShortcut("k").disabled(actions == nil)
            Divider()
            Button("Reload Page") { actions?.web.reload() }.keyboardShortcut("r").disabled(actions == nil)
            Button("Reload Ignoring Cache") { actions?.web.reloadFromOrigin() }.keyboardShortcut("r", modifiers: [.command, .shift]).disabled(actions == nil)
            Button("Zoom In") { if let a = actions { a.model.zoomStep(for: a.model.active.url, in: true) } }.keyboardShortcut("+").disabled(actions == nil)
            Button("Zoom Out") { if let a = actions { a.model.zoomStep(for: a.model.active.url, in: false) } }.keyboardShortcut("-").disabled(actions == nil)
            Button("Actual Size") { if let a = actions { a.model.resetZoom(for: a.model.active.url) } }.keyboardShortcut("0").disabled(actions == nil)
        }
        CommandMenu("History") {
            Button("Back") { actions?.web.goBack() }.keyboardShortcut("[").disabled(!(actions?.web.canGoBack ?? false))
            Button("Forward") { actions?.web.goForward() }.keyboardShortcut("]").disabled(!(actions?.web.canGoForward ?? false))
        }
        CommandMenu("Tabs") {
            Button("Next Tab") { actions?.model.selectNextTab(1) }.keyboardShortcut(.tab, modifiers: .control)
            Button("Previous Tab") { actions?.model.selectNextTab(-1) }.keyboardShortcut(.tab, modifiers: [.control, .shift])
            Button("Pin or Unpin Tab") { if let a = actions { a.model.togglePin(a.model.activeID) } }.keyboardShortcut("d")
            Divider()
            ForEach(1...9, id: \.self) { number in
                Button(number == 9 ? "Last Tab" : "Tab \(number)") { actions?.model.selectTab(number: number) }
                    .keyboardShortcut(KeyEquivalent(Character("\(number)")))
            }
            Divider()
            Button("Next Space") { actions?.model.selectNextSpace(1) }.keyboardShortcut("]", modifiers: [.command, .option])
            Button("Previous Space") { actions?.model.selectNextSpace(-1) }.keyboardShortcut("[", modifiers: [.command, .option])
            Divider()
            Button("Split View") { actions?.splitWithNext() }.keyboardShortcut("1", modifiers: [.command, .control])
            Button("Exit Split View") { actions?.model.exitSplit() }.keyboardShortcut("0", modifiers: [.command, .control])
        }
    }
}
