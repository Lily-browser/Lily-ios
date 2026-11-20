import SwiftUI

struct BrowserView: View {
    @Bindable var model: BrowserModel
    @State private var address = ""
    @State private var showingTabs = false
    @FocusState private var addressFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if model.active.url == nil {
                StartPage()
            } else {
                WebView(tab: model.active) { id, url, title in model.pageChanged(id, url: url, title: title) }
                    .id(model.activeID)
            }
            Divider()
            bar
        }
        .onChange(of: model.activeID) { syncAddress() }
        .onChange(of: model.active.url) { syncAddress() }
        .sheet(isPresented: $showingTabs) { TabSwitcher(model: model) { showingTabs = false } }
    }

    private var bar: some View {
        HStack(spacing: 12) {
            TextField("Search or enter address", text: $address)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.webSearch)
                .submitLabel(.go)
                .focused($addressFocused)
                .onSubmit { model.go(to: address); addressFocused = false }
            Button { showingTabs = true } label: {
                Image(systemName: "square.on.square").accessibilityLabel("Tabs")
            }
            Button { model.newTab() } label: {
                Image(systemName: "plus").accessibilityLabel("New Tab")
            }
        }
        .padding(.horizontal).padding(.vertical, 8)
        .background(.bar)
    }

    private func syncAddress() {
        guard !addressFocused else { return }
        address = model.active.url?.absoluteString ?? ""
    }
}

private struct StartPage: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "leaf").font(.system(size: 56)).foregroundStyle(.tint)
            Text("Lily").font(.largeTitle.weight(.semibold))
            Text("Private by design.").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
