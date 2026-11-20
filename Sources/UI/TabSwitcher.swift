import SwiftUI

struct TabSwitcher: View {
    let model: BrowserModel
    let dismiss: () -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(model.tabs) { tab in
                    Button {
                        model.select(tab.id)
                        dismiss()
                    } label: {
                        HStack {
                            Text(tab.displayTitle).lineLimit(1)
                            Spacer()
                            if tab.id == model.activeID { Image(systemName: "checkmark").foregroundStyle(.tint) }
                        }
                    }
                    .swipeActions { Button("Close", role: .destructive) { model.close(tab.id) } }
                }
            }
            .navigationTitle("Tabs")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done", action: dismiss) } }
        }
    }
}
