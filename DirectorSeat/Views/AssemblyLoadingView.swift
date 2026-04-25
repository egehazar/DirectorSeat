import SwiftUI

struct AssemblyLoadingView: View {
    @ObservedObject var postState: PostProductionState
    var onDismiss: () -> Void
    @State private var messageIndex = 0
    @State private var isPulsing = false

    private let messages = [
        "Combining your shots...",
        "Finding the best moments...",
        "Adding polish...",
    ]

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Theme.Colors.accent)
                        .frame(width: 8, height: 8)
                        .scaleEffect(isPulsing ? 1.0 : 0.4)
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.2),
                            value: isPulsing
                        )
                }
            }

            Text(messages[messageIndex])
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textPrimary)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: messageIndex)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { isPulsing = true }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.5))
                messageIndex = (messageIndex + 1) % messages.count
            }
        }
        .alert("Assembly Failed", isPresented: Binding(
            get: { postState.assemblyError != nil },
            set: { if !$0 { postState.assemblyError = nil } }
        )) {
            Button("Try Again") {
                postState.assemblyError = nil
                postState.retryAssembly()
            }
            Button("Go Back", role: .cancel) { onDismiss() }
        } message: {
            Text(postState.assemblyError ?? "")
        }
    }
}

#Preview {
    AssemblyLoadingView(postState: PostProductionState(), onDismiss: {})
}
