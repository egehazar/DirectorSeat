import SwiftUI

struct PlanGenerationLoadingView: View {
    @ObservedObject var viewModel: PlanGenerationViewModel
    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Circle()
                .fill(Theme.Colors.accent.opacity(0.3))
                .frame(width: 60, height: 60)
                .scaleEffect(isPulsing ? 1.2 : 0.8)
                .animation(
                    .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                    value: isPulsing
                )

            Text(viewModel.currentLoadingMessage)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textPrimary)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: viewModel.currentLoadingMessage)

            Text("This usually takes 5 to 10 seconds.")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { isPulsing = true }
        .alert("Something went wrong", isPresented: $viewModel.showError) {
            Button("Try Again") {
                Task { await viewModel.retry() }
            }
        } message: {
            Text(viewModel.lastError)
        }
    }
}

#Preview {
    PlanGenerationLoadingView(viewModel: PlanGenerationViewModel())
}
