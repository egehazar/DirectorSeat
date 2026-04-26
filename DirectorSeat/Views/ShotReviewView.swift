import AVFoundation
import SwiftData
import SwiftUI
import UIKit

struct ShotReviewView: View {
    let plan: FilmmakingPlan
    @State var capturedTakes: [Int: [URL]]
    @State var selectedTakes: [Int: URL]
    var project: FilmProject?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var postState = PostProductionState()
    @State private var selectedShotIndex: Int?
    @State private var thumbnails: [Int: UIImage] = [:]
    @State private var showPostFlow = false

    private var allShots: [Shot] {
        plan.scenes.flatMap(\.shots)
    }

    private var capturedCount: Int {
        (0..<allShots.count).filter { capturedTakes[$0]?.isEmpty == false }.count
    }

    private var skippedCount: Int {
        allShots.count - capturedCount
    }

    private var totalRuntimeSeconds: Int {
        (0..<allShots.count).compactMap { selectedTakes[$0] != nil ? allShots[$0].estimatedDurationSeconds : nil }.reduce(0, +)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("Your Takes")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textPrimary)

                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .padding(Theme.Spacing.xs)
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.lg)

            Text("\(allShots.count) shots \u{00B7} \(capturedCount) captured \u{00B7} \(skippedCount) skipped \u{00B7} ~\(totalRuntimeSeconds)s runtime")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .padding(.top, Theme.Spacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.md) {
                    ForEach(Array(allShots.enumerated()), id: \.offset) { index, shot in
                        shotCard(index: index, shot: shot)
                            .onTapGesture { selectedShotIndex = index }
                    }
                }
                .padding(.leading, Theme.Spacing.lg)
            }
            .padding(.top, Theme.Spacing.xl)

            Spacer()

            VStack(spacing: Theme.Spacing.sm) {
                DSPrimaryButton(title: "Assemble My Film") {
                    startAssembly()
                }
                .disabled(capturedCount < 3)

                Text(capturedCount < 3 ? "Need at least 3 captured shots." : "Next: post-production")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $selectedShotIndex) { index in
            ShotDetailSheet(
                shotIndex: index,
                shot: allShots[index],
                takes: capturedTakes[index] ?? [],
                selectedTakeURL: Binding(
                    get: { selectedTakes[index] },
                    set: { selectedTakes[index] = $0 }
                ),
                onReshoot: {
                    // Placeholder — re-shooting requires returning to ShootingModeView
                    print("Re-shoot shot \(index + 1)")
                }
            )
        }
        .navigationDestination(isPresented: $showPostFlow) {
            PostProductionView(plan: plan, postState: postState, project: project)
        }
        .task {
            await loadThumbnails()
        }
    }

    private func shotCard(index: Int, shot: Shot) -> some View {
        let takes = capturedTakes[index] ?? []
        let hasTake = !takes.isEmpty
        let hasMultiple = takes.count > 1

        return VStack(spacing: 0) {
            ZStack {
                if let thumb = thumbnails[index] {
                    Image(uiImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 160, height: 120)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Theme.Colors.surface)
                        .frame(width: 160, height: 120)
                        .overlay {
                            Text(hasTake ? "Preview" : "Skipped")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                }
            }
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 16))

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("SHOT \(index + 1) \u{00B7} \(shot.shotType.uppercased())")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .tracking(1)

                Text(formattedDuration(shot.estimatedDurationSeconds))
                    .font(Theme.Typography.body.bold())
                    .foregroundStyle(Theme.Colors.textPrimary)

                HStack(spacing: Theme.Spacing.xs) {
                    Circle()
                        .fill(statusColor(hasTake: hasTake, hasMultiple: hasMultiple))
                        .frame(width: 6, height: 6)
                    Text(statusLabel(hasTake: hasTake, hasMultiple: hasMultiple))
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 160, height: 220)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statusColor(hasTake: Bool, hasMultiple: Bool) -> Color {
        if hasMultiple { return .orange }
        if hasTake { return .green }
        return .gray
    }

    private func statusLabel(hasTake: Bool, hasMultiple: Bool) -> String {
        if hasMultiple { return "Multiple takes" }
        if hasTake { return "Captured" }
        return "Skipped"
    }

    private func formattedDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func startAssembly() {
        let orderedTakes = (0..<allShots.count).compactMap { selectedTakes[$0] }

        // Save selections to project
        if let project {
            project.selectedTakes = selectedTakes
            try? project.modelContext?.save()
        }

        postState.project = project
        postState.filmTitle = project?.filmTitle ?? String(plan.logline.prefix(60))
        postState.directorName = project?.directorName ?? postState.directorName
        showPostFlow = true
        Task {
            await postState.assemble(takes: orderedTakes)
            // Generate thumbnail from first selected take
            if let project {
                let store = ProjectStore(modelContext: project.modelContext!)
                await store.generateThumbnail(for: project)
            }
        }
    }

    private func loadThumbnails() async {
        for index in 0..<allShots.count {
            if let url = selectedTakes[index] ?? capturedTakes[index]?.first {
                if let image = await VideoUtilities.extractFirstFrame(from: url) {
                    thumbnails[index] = image
                }
            }
        }
    }
}

extension ShotReviewView {
    static let mockTakes: [Int: [URL]] = [
        0: [URL(fileURLWithPath: "/mock/shot1_take1.mov")],
        1: [URL(fileURLWithPath: "/mock/shot2_take1.mov"), URL(fileURLWithPath: "/mock/shot2_take2.mov")],
        2: [URL(fileURLWithPath: "/mock/shot3_take1.mov")],
        3: [],
        4: [URL(fileURLWithPath: "/mock/shot5_take1.mov")],
        5: [URL(fileURLWithPath: "/mock/shot6_take1.mov")],
        6: [],
    ]

    static let mockSelected: [Int: URL] = [
        0: URL(fileURLWithPath: "/mock/shot1_take1.mov"),
        1: URL(fileURLWithPath: "/mock/shot2_take1.mov"),
        2: URL(fileURLWithPath: "/mock/shot3_take1.mov"),
        4: URL(fileURLWithPath: "/mock/shot5_take1.mov"),
        5: URL(fileURLWithPath: "/mock/shot6_take1.mov"),
    ]
}

extension Int: @retroactive Identifiable {
    public var id: Int { self }
}

#Preview {
    NavigationStack {
        ShotReviewView(
            plan: .debugMock,
            capturedTakes: [0: [], 1: [], 2: [], 3: [], 4: [], 5: [], 6: []],
            selectedTakes: [:]
        )
    }
}
