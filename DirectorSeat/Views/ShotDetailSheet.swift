import AVKit
import SwiftUI

struct ShotDetailSheet: View {
    let shotIndex: Int
    let shot: Shot
    let takes: [URL]
    @Binding var selectedTakeURL: URL?
    let onReshoot: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var previewingURL: URL?
    @State private var player: AVPlayer?

    var body: some View {
        VStack(spacing: 0) {
            if let url = previewingURL ?? selectedTakeURL ?? takes.first {
                Group {
                    if let player {
                        VideoPlayer(player: player)
                    } else {
                        Color.black
                    }
                }
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.lg)
                .onAppear {
                    let newPlayer = AVPlayer(url: url)
                    player = newPlayer
                    newPlayer.play()
                }
                .onChange(of: previewingURL) { _, newURL in
                    guard let newURL else { return }
                    let newPlayer = AVPlayer(url: newURL)
                    player = newPlayer
                    newPlayer.play()
                }
            } else {
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "video.slash")
                        .font(.system(size: 36))
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Text("No take captured")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .background(Theme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.lg)
            }

            if takes.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(Array(takes.enumerated()), id: \.offset) { index, url in
                            Button {
                                previewingURL = url
                            } label: {
                                VStack(spacing: Theme.Spacing.xs) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Theme.Colors.surface)
                                        .frame(width: 80, height: 50)
                                        .overlay {
                                            Image(systemName: "play.fill")
                                                .font(.system(size: 14))
                                                .foregroundStyle(Theme.Colors.textSecondary)
                                        }
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(
                                                    (previewingURL ?? selectedTakeURL) == url ? Theme.Colors.accent : .clear,
                                                    lineWidth: 2
                                                )
                                        )

                                    Text("Take \(index + 1)")
                                        .font(Theme.Typography.caption)
                                        .foregroundStyle(Theme.Colors.textSecondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                }
                .padding(.top, Theme.Spacing.md)
            }

            Spacer()

            VStack(spacing: Theme.Spacing.md) {
                if let previewURL = previewingURL, previewURL != selectedTakeURL {
                    DSPrimaryButton(title: "Use This Take") {
                        selectedTakeURL = previewURL
                        dismiss()
                    }
                }

                Button {
                    dismiss()
                    onReshoot()
                } label: {
                    Text("Re-shoot This Shot")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Theme.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Button { dismiss() } label: {
                    Text("Close")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Theme.Colors.background)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}
