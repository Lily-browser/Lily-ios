import SwiftUI

/// The Mac app's look: indigo accent, a per-space color tinting the backdrop, rounded continuous shapes.
enum Theme {
    static let accentHex = "#5E5CE6" // the app icon's indigo (Apple's system indigo)
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

extension View {
    /// Floating chrome. On iOS 26 and later it is Liquid Glass (interactive, so it responds to touch);
    /// before that a system material with a hairline edge. Chrome only: never use it on content.
    @ViewBuilder func chrome<S: InsettableShape>(_ shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: shape)
        } else {
            self.background(.regularMaterial, in: shape)
                .overlay(shape.strokeBorder(.separator.opacity(0.5), lineWidth: 0.5))
        }
    }
}

/// Names for the accent presets, so color is never the only way to tell them apart (VoiceOver, Settings).
enum AccentName {
    static func of(_ hex: String) -> String {
        switch hex.uppercased() {
        case "#5E5CE6": return "Indigo"
        case "#0A84FF": return "Blue"
        case "#30B0C7": return "Teal"
        case "#34C759": return "Green"
        case "#FF9F0A": return "Orange"
        case "#FF375F": return "Pink"
        case "#BF5AF2": return "Purple"
        case "#8E8E93": return "Gray"
        default: return "Color"
        }
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
            .fill(host.isEmpty ? AnyShapeStyle(.quaternary) : AnyShapeStyle(Color(hue: hue, saturation: 0.62, brightness: 0.55)))
            .frame(width: size, height: size)
            .overlay {
                if let letter = host.replacingOccurrences(of: "www.", with: "").first {
                    Text(String(letter).uppercased()).font(.system(size: size * 0.5, weight: .bold)).foregroundStyle(.white)
                } else {
                    Image(systemName: "plus").font(.system(size: size * 0.45, weight: .bold)).foregroundStyle(.secondary)
                }
            }
            .accessibilityHidden(true) // decorative: the tab's title is read instead
    }
}
