import SwiftUI

struct DSPrimaryButton: View {
    let title: String
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Typography.headline)
                .foregroundStyle(isEnabled ? .black : Theme.Colors.textSecondary.opacity(0.4))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(isEnabled ? Theme.Colors.buttonPrimary : Theme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(PressStyle())
    }
}

private struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    DSPrimaryButton(title: "Make a Film") {
        print("Tapped")
    }
    .padding(.horizontal, Theme.Spacing.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.Colors.background)
}
