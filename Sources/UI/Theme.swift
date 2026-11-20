import SwiftUI

/// The Mac app's look: indigo accent, a per-space color tinting the backdrop, rounded continuous shapes.
enum Theme {
    static let accentHex = "#5E5CE6" // the app icon's indigo (Apple's system indigo)
    static let accent = Color(hex: accentHex)
    static let pageRadius: CGFloat = 14
    static let rowRadius: CGFloat = 9
}

extension Color {
    init(hex: String) {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")).prefix(6)
        let value = UInt32(digits, radix: 16) ?? 0x5E5CE6
        self.init(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
    }
}

/// The window behind the page card: the system background washed with the current space's color.
struct SpaceBackdrop: View {
    let colorHex: String
    var body: some View {
        ZStack {
            Color(.systemBackground)
            LinearGradient(colors: [Color(hex: colorHex).opacity(0.34), Color(hex: colorHex).opacity(0.10)],
                           startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
    }
}

/// Stand-in for a favicon: the site's first letter on a color derived from its host.
struct SiteBadge: View {
    let tab: TabItem
    var size: CGFloat = 22

    var body: some View {
        let host = tab.url?.host ?? ""
        let hue = Double(host.utf8.reduce(0) { ($0 &* 31 &+ Int($1)) % 360 }) / 360
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(host.isEmpty ? AnyShapeStyle(.quaternary) : AnyShapeStyle(Color(hue: hue, saturation: 0.5, brightness: 0.82)))
            .frame(width: size, height: size)
            .overlay {
                if let letter = host.replacingOccurrences(of: "www.", with: "").first {
                    Text(String(letter).uppercased()).font(.system(size: size * 0.5, weight: .bold)).foregroundStyle(.white)
                } else {
                    Image(systemName: "plus").font(.system(size: size * 0.45, weight: .bold)).foregroundStyle(.secondary)
                }
            }
    }
}
