import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FilmProject.updatedAt, order: .reverse) private var projects: [FilmProject]
    @State private var showIdeaIntake = false
    @State private var selectedProject: FilmProject?
    @State private var showResumeProject = false

    // Debug
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
        VStack(spacing: 0) {
            debugButtons

            if projects.isEmpty {
                emptyState
            } else {
                projectList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.background.ignoresSafeArea())
        .navigationDestination(isPresented: $showIdeaIntake) {
            IdeaIntakeView()
        }
        .navigationDestination(isPresented: $showResumeProject) {
            if let project = selectedProject {
                ProjectResumeView(project: project)
            }
        }
        // Debug destinations
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
            PostProductionView(plan: .debugMock, postState: debugPostState)
        }
        .navigationDestination(isPresented: $showDebugExport) {
            ExportSuccessView(url: URL(fileURLWithPath: "/mock/final.mp4"), filmTitle: "A mysterious note in a library book")
        }
        .sheet(isPresented: $showDebugPaywall) {
            PaywallView(exportState: debugExportState)
        }
        .navigationDestination(isPresented: $showDebugFastTest) {
            ShootingModeView(plan: .fastTest)
        }
        .navigationDestination(isPresented: $showDebugReview) {
            ShotReviewView(plan: .debugMock, capturedTakes: ShotReviewView.mockTakes, selectedTakes: ShotReviewView.mockSelected)
        }
    }

    // MARK: - Debug Buttons

    private var debugButtons: some View {
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
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 0) {
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
    }

    // MARK: - Project List

    private var projectList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Your films")
                    .font(Theme.Typography.heroTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.lg)

            ScrollView {
                LazyVStack(spacing: Theme.Spacing.md) {
                    ForEach(projects) { project in
                        ProjectCard(project: project)
                            .onTapGesture {
                                selectedProject = project
                                showResumeProject = true
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    let store = ProjectStore(modelContext: modelContext)
                                    store.delete(project)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.xl)
            }

            Spacer()

            Button {
                showIdeaIntake = true
            } label: {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                    Text("Make a new film")
                        .font(Theme.Typography.body)
                }
                .foregroundStyle(Theme.Colors.accent)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Theme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
        }
    }
}

// MARK: - Project Card

private struct ProjectCard: View {
    let project: FilmProject

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Group {
                if let thumbnail = project.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        Theme.Colors.surface
                        Image(systemName: "film")
                            .font(.system(size: 24))
                            .foregroundStyle(Theme.Colors.textSecondary.opacity(0.4))
                    }
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(project.title)
                    .font(Theme.Typography.body.bold())
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(2)

                Text(project.statusDisplay)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                Text(project.relativeTimeDisplay)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.Colors.textSecondary.opacity(0.4))
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 110)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var statusColor: Color {
        switch project.status {
        case "planning": .orange
        case "shooting": .blue
        case "reviewing": .purple
        case "post": .cyan
        case "exported": .green
        default: Theme.Colors.textSecondary
        }
    }
}

// MARK: - Resume Router

private struct ProjectResumeView: View {
    let project: FilmProject

    var body: some View {
        if let plan = project.plan {
            switch project.status {
            case "shooting":
                ShootingModeView(plan: plan, project: project)
            case "reviewing":
                ShotReviewView(
                    plan: plan,
                    capturedTakes: project.capturedTakes,
                    selectedTakes: project.selectedTakes,
                    project: project,
                    onReshoot: { shotIndex in
                        // Path B: no ShootingModeViewModel in scope on the
                        // resume route. Mutate FilmProject directly; the
                        // surrounding switch on project.status (a SwiftData
                        // @Model property) re-renders to ShootingModeView
                        // automatically once status flips to "shooting".
                        let urls = project.capturedTakes[shotIndex] ?? []
                        for url in urls {
                            do {
                                try FileManager.default.removeItem(at: url)
                            } catch {
                                print("[DirectorSeat] Could not delete take file at \(url.path): \(error.localizedDescription)")
                            }
                        }
                        var captured = project.capturedTakes
                        var selected = project.selectedTakes
                        captured.removeValue(forKey: shotIndex)
                        selected.removeValue(forKey: shotIndex)
                        project.capturedTakes = captured
                        project.selectedTakes = selected
                        project.currentShotIndex = shotIndex
                        project.status = "shooting"
                        try? project.modelContext?.save()
                    }
                )
            case "post":
                PostProductionResumeWrapper(plan: plan, project: project)
            case "exported":
                if let url = project.exportedVideoURL {
                    ExportSuccessView(url: url, filmTitle: project.filmTitle, project: project)
                } else {
                    PostProductionResumeWrapper(plan: plan, project: project)
                }
            default:
                PlanPreviewView(plan: plan, project: project)
            }
        } else {
            VStack(spacing: Theme.Spacing.md) {
                Text("Project data unavailable")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Colors.background.ignoresSafeArea())
        }
    }
}

private struct PostProductionResumeWrapper: View {
    let plan: FilmmakingPlan
    let project: FilmProject
    @StateObject private var postState = PostProductionState()

    var body: some View {
        PostProductionView(plan: plan, postState: postState, project: project)
            .onAppear {
                postState.project = project
                if let url = project.assembledVideoURL {
                    postState.assembledVideoURL = url
                }
                postState.filmTitle = project.filmTitle
                postState.directorName = project.directorName
                postState.titleCardsEnabled = project.titleCardsEnabled
            }
    }
}

#Preview {
    HomeView()
}
