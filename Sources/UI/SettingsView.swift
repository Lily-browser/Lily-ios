import SwiftUI
import LilyKit
import WebKit

/// Few settings on purpose: the look, the search engine, what's private, and your spaces.
struct SettingsView: View {
    let model: BrowserModel
    let snapshots: SnapshotCache
    @Environment(\.dismiss) private var dismiss

    @AppStorage(Settings.accentKey) private var accent = Theme.accentHex
    @AppStorage(Settings.modeKey) private var mode = Settings.Mode.system.rawValue
    @AppStorage(Preferences.Key.searchEngine) private var engine = Preferences.defaultSearchEngine.rawValue
    @AppStorage(Preferences.Key.httpsFirst) private var httpsFirst = true
    @AppStorage(Preferences.Key.removeLinkTracking) private var removeTracking = true
    @AppStorage(Preferences.Key.adBlock) private var adBlock = true
    @AppStorage(Preferences.Key.restoreSession) private var restore = true
    private var blocker: AdBlocker { Blocking.blocker }
    @State private var confirmingClear = false
    @State private var cleared = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $mode) {
                        ForEach(Settings.Mode.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                    swatches(selection: $accent)
                }
                Section("Search") {
                    Picker("Search engine", selection: $engine) {
                        ForEach(Preferences.SearchEngine.allCases) { Text($0.displayName).tag($0.rawValue) }
                    }
                }
                Section {
                    Toggle("Block ads and trackers", isOn: $adBlock)
                    Toggle("Always try HTTPS first", isOn: $httpsFirst)
                    Toggle("Remove tracking from links", isOn: $removeTracking)
                    Toggle("Restore tabs on launch", isOn: $restore)
                    Button("Clear Browsing Data…", role: .destructive) { confirmingClear = true }
                } header: { Text("Privacy") } footer: {
                    Text(cleared ? "Cleared: cookies, caches, site storage and tab thumbnails." : "Removes cookies, caches and site storage. Your tabs stay.")
                }
                if adBlock {
                    Section {
                        ForEach(FilterLists.all) { list in
                            Toggle(isOn: Binding(get: { blocker.isListEnabled(list.id) }, set: { blocker.setList(list.id, enabled: $0) })) {
                                VStack(alignment: .leading) { Text(list.name); Text(list.summary).font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                        Button("Update Filter Lists") { Task { await blocker.updateFilterLists() } }.disabled(blocker.isUpdating)
                    } header: { Text("Filter lists") } footer: { Text("\(blocker.status). Changes apply to pages you open next.") }
                }
                Section("Spaces") {
                    ForEach(model.spaces) { space in SpaceEditor(model: model, space: space) }
                }
                Section("About") {
                    LabeledContent("Version", value: AppInfo.version)
                    Text("Lily is private by design: no accounts, no analytics.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .onChange(of: adBlock) { _, _ in blocker.settingsChanged() }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .confirmationDialog("Clear all cookies, caches and site data?", isPresented: $confirmingClear, titleVisibility: .visible) {
                Button("Clear Browsing Data", role: .destructive) { clearData() }
            }
        }
        .tint(Color(hex: accent))
        .preferredColorScheme(Settings.Mode(rawValue: mode)?.scheme)
    }

    private func swatches(selection: Binding<String>) -> some View {
        SwatchGrid(selection: selection, diameter: 28)
    }

    private func clearData() {
        snapshots.clear()
        Task {
            await WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
            cleared = true
        }
    }
}

private struct SpaceEditor: View {
    let model: BrowserModel
    let space: Space
    @State private var name: String

    init(model: BrowserModel, space: Space) {
        self.model = model
        self.space = space
        _name = State(initialValue: space.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: space.symbol).foregroundStyle(Color(hex: space.colorHex)).frame(width: 22)
                TextField("Space name", text: $name).onSubmit { model.rename(space, to: name) }
                    .onChange(of: name) { _, new in model.rename(space, to: new) }
            }
            SwatchGrid(selection: Binding(get: { space.colorHex }, set: { model.recolor(space, to: $0) }), diameter: 24)
        }
        .padding(.vertical, 2)
    }
}

enum Settings {
    static let accentKey = "AppearanceAccent" // same keys as the Mac app
    static let modeKey = "AppearanceMode"
    static let accents = ["#5E5CE6", "#0A84FF", "#30B0C7", "#34C759", "#FF9F0A", "#FF375F", "#BF5AF2", "#8E8E93"]

    enum Mode: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
        var scheme: ColorScheme? { self == .light ? .light : self == .dark ? .dark : nil }
    }
}

/// Accent/space color choices: 44 pt targets, named for VoiceOver, with a ring (not just color) on the selection.
private struct SwatchGrid: View {
    @Binding var selection: String
    let diameter: CGFloat

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 0)], spacing: 0) {
            ForEach(Settings.accents, id: \.self) { hex in
                Button { selection = hex } label: {
                    Circle().fill(Color(hex: hex)).frame(width: diameter, height: diameter)
                        .overlay(Circle().strokeBorder(.primary.opacity(0.7), lineWidth: selection == hex ? 2.5 : 0).padding(-4))
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(AccentName.of(hex))
                .accessibilityAddTraits(selection == hex ? .isSelected : [])
            }
        }
    }
}
