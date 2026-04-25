import AVKit
import SwiftUI

struct PostProductionView: View {
    let plan: FilmmakingPlan
    @ObservedObject var postState: PostProductionState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var exportState = ExportState()
    @State private var player: AVPlayer?
    @State private var showPaywall = false
    @State private var showExportFlow = false

    var body: some View {
        if let videoURL = postState.assembledVideoURL {
            postProductionContent(videoURL: videoURL)
        } else {
            AssemblyLoadingView(postState: postState, onDismiss: { dismiss() })
        }
    }

    @ViewBuilder
    private func postProductionContent(videoURL: URL) -> some View {
        VStack(spacing: 0) {
            ZStack {
                Text("Post-Production")
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

            Group {
                if let player {
                    VideoPlayer(player: player)
                } else {
                    Color.black
                }
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.md)
            .onTapGesture {
                if player?.timeControlStatus == .playing {
                    player?.pause()
                } else {
                    player?.play()
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    colorMoodSection
                    musicSection
                    titlesSection
                }
                .padding(.top, Theme.Spacing.lg)
                .padding(.bottom, 160)
            }
            .scrollDismissesKeyboard(.interactively)

            VStack(spacing: Theme.Spacing.sm) {
                DSPrimaryButton(title: "Export My Film") {
                    showPaywall = true
                }

                Text("Next: save and share.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary.opacity(0.6))
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showPaywall, onDismiss: {
            if exportState.userChoseExport {
                exportState.userChoseExport = false
                exportState.startRender(plan: plan, assembledURL: videoURL, state: postState)
                showExportFlow = true
            }
        }) {
            PaywallView(exportState: exportState)
        }
        .fullScreenCover(isPresented: $showExportFlow) {
            ExportFlowView(exportState: exportState, filmTitle: postState.filmTitle)
        }
        .onAppear {
            if postState.filmTitle.isEmpty {
                postState.filmTitle = String(plan.logline.prefix(60))
            }
            let newPlayer = AVPlayer(url: videoURL)
            player = newPlayer
            newPlayer.play()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    // MARK: - Color Mood

    private var colorMoodSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("COLOR MOOD")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .tracking(1.5)
                .padding(.horizontal, Theme.Spacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.md) {
                    ForEach(ColorPreset.allCases) { preset in
                        Button { postState.colorPreset = preset } label: {
                            VStack(spacing: Theme.Spacing.sm) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(presetTint(preset))
                                    .frame(width: 100, height: 56)

                                Text(preset.displayName)
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                            }
                            .frame(width: 100, height: 100)
                            .background(Theme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        postState.colorPreset == preset ? Theme.Colors.accent : .clear,
                                        lineWidth: 2
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }
        }
    }

    private func presetTint(_ preset: ColorPreset) -> Color {
        switch preset {
        case .original: Color.gray.opacity(0.4)
        case .warm: Color.orange.opacity(0.3)
        case .cool: Color.blue.opacity(0.3)
        }
    }

    // MARK: - Music

    private var musicSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("MUSIC")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .tracking(1.5)
                .padding(.horizontal, Theme.Spacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    Button { postState.musicTrackId = nil } label: {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text("No Music")
                                .font(Theme.Typography.body.bold())
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Text("Original audio")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                        .padding(Theme.Spacing.md)
                        .frame(width: 140, height: 80, alignment: .leading)
                        .background(Theme.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(postState.musicTrackId == nil ? Theme.Colors.accent : .clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)

                    ForEach(MusicTrack.library) { track in
                        Button { postState.musicTrackId = track.id } label: {
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                Text(track.name)
                                    .font(Theme.Typography.body.bold())
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                Text(track.mood)
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }
                            .padding(Theme.Spacing.md)
                            .frame(width: 140, height: 80, alignment: .leading)
                            .background(Theme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(postState.musicTrackId == track.id ? Theme.Colors.accent : .clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }

            if postState.musicTrackId != nil {
                VStack(spacing: Theme.Spacing.xs) {
                    Slider(value: $postState.musicVolume, in: 0...1)
                        .tint(Theme.Colors.accent)

                    HStack {
                        Text("Original")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                        Spacer()
                        Text("Music")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }
        }
    }

    // MARK: - Titles

    private var titlesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("TITLES")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .tracking(1.5)
                .padding(.horizontal, Theme.Spacing.lg)

            Toggle("Show title cards", isOn: $postState.titleCardsEnabled)
                .tint(Theme.Colors.accent)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(.horizontal, Theme.Spacing.lg)

            if postState.titleCardsEnabled {
                VStack(spacing: Theme.Spacing.sm) {
                    TextField("Film title", text: $postState.filmTitle)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .padding(Theme.Spacing.md)
                        .background(Theme.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    TextField("Directed by", text: $postState.directorName)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .padding(Theme.Spacing.md)
                        .background(Theme.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .onChange(of: postState.directorName) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "directorName")
                        }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }
        }
    }
}

private struct ExportFlowView: View {
    @ObservedObject var exportState: ExportState
    let filmTitle: String

    var body: some View {
        switch exportState.phase {
        case .success(let url):
            ExportSuccessView(url: url, filmTitle: filmTitle)
        default:
            ExportRenderingView(exportState: exportState)
        }
    }
}

#Preview {
    NavigationStack {
        PostProductionView(
            plan: .debugMock,
            postState: {
                let state = PostProductionState()
                state.assembledVideoURL = URL(fileURLWithPath: "/mock/assembled.mov")
                return state
            }()
        )
    }
}
