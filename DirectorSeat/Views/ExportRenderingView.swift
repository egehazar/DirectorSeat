import SwiftUI

struct ExportRenderingView: View {
    @ObservedObject var exportState: ExportState
    @State private var isSpinning = false
    @State private var showHint = false

    private var progress: Double {
        if case .rendering(let p) = exportState.phase { return p }
        return 0
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

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
        .alert("Export Failed", isPresented: Binding(
            get: { if case .failure = exportState.phase { return true } else { return false } },
            set: { if !$0 { exportState.phase = .idle } }
        )) {
            Button("OK") { exportState.phase = .idle }
        } message: {
            if case .failure(let msg) = exportState.phase {
                Text(msg)
            }
        }
    }
}

#Preview {
    ExportRenderingView(exportState: ExportState())
}
