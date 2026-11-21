import SwiftUI
import UIKit

/// The system "Save to Files" sheet for a finished download (a copy is saved; the temporary file stays until launch).
struct ExportPicker: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController { UIDocumentPickerViewController(forExporting: [url], asCopy: true) }
    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}
}

/// Covers the page whenever the app isn't active and a private tab is showing, so the app switcher's picture
/// of Lily never contains a private page.
struct PrivacyCover: View {
    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThickMaterial)
            Image(systemName: "eye.slash.fill").font(.system(size: 44)).foregroundStyle(.secondary)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
