import SwiftUI

struct HomeView: View {
    @State private var showIdeaIntake = false
    @State private var showDebugChecklist = false
    @State private var showDebugPreview = false
    @State private var showDebugShooting = false
    @State private var showDebugReview = false
    @State private var showDebugAssembly = false
    @State private var showDebugExport = false
    @State private var showDebugPaywall = false
    @State private var showDebugFastTest = false
    @StateObject private var debugPostState = PostProductionState()
    @StateObject private var debugExportState = ExportState()

    var body: some View {
        VStack {
            HStack {
                Spacer()
                VStack(spacing: 4) {
                    Button("C") { showDebugChecklist = true }
                    Button("P") { showDebugPreview = true }
                    Button("S") { showDebugShooting = true }
                    Button("R") { showDebugReview = true }
                    Button("A") {
                        debugPostState.assembledVideoURL = URL(fileURLWithPath: "/mock/assembled.mov")
                        showDebugAssembly = true
                    }
                    Button("E") { showDebugExport = true }
                    Button("PW") { showDebugPaywall = true }
                    Button("X") { showDebugFastTest = true }
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
        .navigationDestination(isPresented: $showDebugShooting) {
            ShootingModeView(plan: .debugMock)
        }
        .navigationDestination(isPresented: $showDebugAssembly) {
            PostProductionView(
                plan: .debugMock,
                postState: debugPostState
            )
        }
        .navigationDestination(isPresented: $showDebugExport) {
            ExportSuccessView(
                url: URL(fileURLWithPath: "/mock/final.mp4"),
                filmTitle: "A mysterious note in a library book"
            )
        }
        .sheet(isPresented: $showDebugPaywall) {
            PaywallView(exportState: debugExportState)
        }
        .navigationDestination(isPresented: $showDebugFastTest) {
            ShootingModeView(plan: .fastTest)
        }
        .navigationDestination(isPresented: $showDebugReview) {
            ShotReviewView(
                plan: .debugMock,
                capturedTakes: ShotReviewView.mockTakes,
                selectedTakes: ShotReviewView.mockSelected
            )
        }
    }
}

#Preview {
    HomeView()
}
