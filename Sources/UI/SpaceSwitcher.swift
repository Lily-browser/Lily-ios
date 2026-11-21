import SwiftUI

/// Floating glass capsule (iOS 26+) with one button per space; shared by the phone and iPad layouts.
struct SpaceSwitcher: View {
    let model: BrowserModel

    var body: some View {
        HStack(spacing: 4) {
            ForEach(model.spaces) { space in
                let current = space.id == model.currentSpaceID
                Button { model.selectSpace(space.id) } label: {
                    Image(systemName: space.symbol)
                        .font(current ? .callout.weight(.semibold) : .footnote.weight(.semibold))
                        .foregroundStyle(current ? Color(hex: space.colorHex) : .secondary)
                        .frame(width: 52, height: 44)
                        .background(current ? Color(hex: space.colorHex).opacity(0.18) : .clear, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(space.name)
                .accessibilityAddTraits(current ? .isSelected : [])
            }
        }
        .padding(4)
        .chrome(Capsule())
    }
}
