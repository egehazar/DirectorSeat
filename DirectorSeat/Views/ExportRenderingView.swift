import SwiftUI

struct ExportRenderingView: View {
    @ObservedObject var exportState: ExportState
    @Environment(\.dismiss) private var dismiss
    @State private var isSpinning = false
    @State private var showHint = false

    private var progress: Double {
        if case .rendering(let p) = exportState.phase { return p }
        return 0
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            if case .failure(let message) = exportState.phase {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundStyle(.red)

                Text("Export Failed")
                    .font(Theme.Typography.heroTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text(message)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.lg)

                VStack(spacing: Theme.Spacing.sm) {
                    DSPrimaryButton(title: "Try Again") {
                        exportState.retry()
                    }

                    Button("Go Back") { dismiss() }
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .padding(.horizontal, Theme.Spacing.lg)
            } else {
                Image(systemName: "film.stack")
                    .font(.system(size: 48))
                    .foregroundStyle(Theme.Colors.accent)
                    .rotationEffect(.degrees(isSpinning ? 360 : 0))
                    .animation(.linear(duration: 3).repeatForever(autoreverses: false), value: isSpinning)

                Text("Rendering your film...")
                    .font(Theme.Typography.heroTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text("\(Int(progress * 100))%")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.2), value: progress)

                Text("This may take a moment.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary.opacity(0.6))

                if showHint {
                    Text("Feel free to put your phone down \u{2014} we'll notify you.")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary.opacity(0.5))
                        .transition(.opacity)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.background.ignoresSafeArea())
        .onAppear {
            isSpinning = true
            Task {
                try? await Task.sleep(for: .seconds(5))
                withAnimation { showHint = true }
            }
        }
    }
}

#Preview {
    ExportRenderingView(exportState: ExportState())
}
