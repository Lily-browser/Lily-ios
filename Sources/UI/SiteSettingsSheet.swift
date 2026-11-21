import SwiftUI
import LilyKit

/// What this website is allowed to do and how it looks, remembered per site (sealed on disk).
struct SiteSettingsSheet: View {
    let model: BrowserModel
    let url: URL?
    @Environment(\.dismiss) private var dismiss

    private var site: SiteSettings.Site { model.sites.site(for: url) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: zoomIndex, in: 0...(SiteSettings.zoomLevels.count - 1)) {
                        LabeledContent("Zoom", value: "\(Int((model.zoom(for: url) * 100).rounded()))%")
                    }
                    Picker("Appearance", selection: binding(\.darkMode, default: .standard)) {
                        ForEach([SiteSettings.DarkMode.standard, .dark, .light], id: \.self) { Text($0.title).tag($0) }
                    }
                } header: { Text(SiteSettings.key(for: url) ?? "This page") }
                Section {
                    Toggle("JavaScript", isOn: binding(\.javaScript, default: true))
                    Toggle("Block ads and trackers", isOn: Binding(
                        get: { !(site.adsAllowed ?? false) },
                        set: { blocking in model.sites.update(url) { $0.adsAllowed = blocking ? nil : true } }))
                } footer: { Text("Turning these off reloads the page.") }
                Section {
                    Button("Reset This Website", role: .destructive) {
                        if let key = SiteSettings.storageKey(for: url) { model.sites.reset(key) }
                    }.disabled(site.isEmpty)
                }
            }
            .navigationTitle("Website Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private var zoomIndex: Binding<Int> {
        Binding {
            SiteSettings.zoomLevels.enumerated().min { abs($0.element - model.zoom(for: url)) < abs($1.element - model.zoom(for: url)) }?.offset ?? 5
        } set: { i in model.sites.update(url) { $0.zoom = SiteSettings.zoomLevels[i] } }
    }

    private func binding<T: Equatable>(_ path: WritableKeyPath<SiteSettings.Site, T?>, default fallback: T) -> Binding<T> {
        Binding(get: { site[keyPath: path] ?? fallback },
                set: { value in model.sites.update(url) { $0[keyPath: path] = value == fallback ? nil : value } })
    }
}
