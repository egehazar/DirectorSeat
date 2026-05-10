import AVFoundation
import SwiftData
import SwiftUI
import UIKit

struct ShotReviewView: View {
    let plan: FilmmakingPlan
    @State var capturedTakes: [Int: [URL]]
    @State var selectedTakes: [Int: URL]
    /// Recorded durations from the parent (`viewModel.takeDurations` on the
    /// forward path, empty on the resume path). Kept as a regular `var` rather
    /// than `@State` so the parent's @Published updates flow through —
    /// otherwise a duration that loads after presentation gets stranded in
    /// the parent and the per-card label keeps showing the plan estimate.
    var takeDurations: [URL: Double] = [:]
    var project: FilmProject?
    /// Callback invoked when the user taps "Re-shoot This Shot" inside a
    /// ShotDetailSheet. The 0-indexed shot index is passed up so the parent
    /// can clear the take, reset state, and route back to Shooting Mode.
    var onReshoot: ((Int) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var postState = PostProductionState()
    @State private var selectedShotIndex: Int?
    @State private var thumbnails: [Int: UIImage] = [:]
    @State private var showPostFlow = false
    /// Lazily-loaded durations for cases where the parent didn't supply one
    /// (HomeView resume path) or hadn't loaded one yet at presentation time.
    /// Merged with `takeDurations` at display time, parent value wins.
    @State private var locallyLoadedDurations: [URL: Double] = [:]

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
        (0..<allShots.count).compactMap { idx in
            guard selectedTakes[idx] != nil else { return nil }
            return displaySeconds(forShotIndex: idx) ?? allShots[idx].estimatedDurationSeconds
        }.reduce(0, +)
    }

    /// Returns the actual recorded duration of the take we'd display for this
    /// shot (selected take, falling back to first captured take), or nil if no
    /// take exists or its duration hasn't been loaded yet. Prefers the
    /// parent-supplied map; falls through to the locally-loaded backup.
    private func displaySeconds(forShotIndex index: Int) -> Int? {
        guard let url = selectedTakes[index] ?? capturedTakes[index]?.first else { return nil }
        if let seconds = takeDurations[url] { return Int(seconds.rounded()) }
        if let seconds = locallyLoadedDurations[url] { return Int(seconds.rounded()) }
        return nil
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
                    // Forward to the parent's handler. The parent decides how to
                    // route — either via ShootingModeViewModel (forward path) or
                    // by mutating FilmProject directly (HomeView resume path).
                    self.onReshoot?(index)
                }
            )
        }
        .navigationDestination(isPresented: $showPostFlow) {
            PostProductionView(plan: plan, postState: postState, project: project)
        }
        .task {
            await loadThumbnails()
            await loadMissingDurations()
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

                Text(formattedDuration(displaySeconds(forShotIndex: index) ?? shot.estimatedDurationSeconds))
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
            await postState.assemble(plan: plan, takes: orderedTakes)
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

    /// Fallback path: when ShotReviewView is constructed without a populated
    /// takeDurations map (e.g. restored from FilmProject in HomeView), or
    /// before the parent's async duration-load for the latest take has
    /// completed, load any missing durations from disk so the cards show real
    /// take length. Writes to `locallyLoadedDurations` so a later parent
    /// update (which would land in `takeDurations`) takes precedence.
    private func loadMissingDurations() async {
        for index in 0..<allShots.count {
            guard let url = selectedTakes[index] ?? capturedTakes[index]?.first,
                  takeDurations[url] == nil,
                  locallyLoadedDurations[url] == nil else { continue }
            let asset = AVURLAsset(url: url)
            if let d = try? await asset.load(.duration), d.seconds.isFinite, d.seconds > 0 {
                locallyLoadedDurations[url] = d.seconds
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
