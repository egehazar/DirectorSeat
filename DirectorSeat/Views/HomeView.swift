import SwiftUI

struct HomeView: View {
    @State private var showIdeaIntake = false
    @State private var showDebugChecklist = false
    @State private var showDebugPreview = false

    var body: some View {
        VStack {
            HStack {
                Spacer()
                VStack(spacing: 4) {
                    Button("C") { showDebugChecklist = true }
                    Button("P") { showDebugPreview = true }
                }
                .font(.system(size: 10))
                .foregroundStyle(Theme.Colors.textSecondary.opacity(0.15))
            }
            .padding(.horizontal, Theme.Spacing.lg)

            Spacer()
                .frame(minHeight: 60)

            Spacer()

            VStack(spacing: 0) {
                Image(systemName: "film.fill")
                    .font(.system(size: 120))
                    .foregroundStyle(Theme.Colors.accent)

                Spacer()
                    .frame(height: Theme.Spacing.xxl)

                Text("Your first film,\nstarts here.")
                    .font(Theme.Typography.heroTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Spacer()
                    .frame(height: Theme.Spacing.xs)

                Text("You bring the idea. We'll handle the rest.")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            DSPrimaryButton(title: "Make a Film") {
                showIdeaIntake = true
            }
            .padding(.horizontal, Theme.Spacing.xl - Theme.Spacing.lg)

            Spacer()
                .frame(height: Theme.Spacing.sm)

            Text("Takes about 30 minutes.")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary.opacity(0.8))

            Spacer()
                .frame(height: Theme.Spacing.xl)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.background.ignoresSafeArea())
        .navigationDestination(isPresented: $showIdeaIntake) {
            IdeaIntakeView()
        }
        .navigationDestination(isPresented: $showDebugChecklist) {
            SetupChecklistView(plan: .debugMock)
        }
        .navigationDestination(isPresented: $showDebugPreview) {
            PlanPreviewView(plan: .debugMock)
        }
    }
}

#Preview {
    HomeView()
}
