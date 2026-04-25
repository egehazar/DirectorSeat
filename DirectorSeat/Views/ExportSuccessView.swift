import AVKit
import SwiftUI
import UIKit

struct ExportSuccessView: View {
    let url: URL
    let filmTitle: String
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var showShareSheet = false
    @State private var showCheckmark = false
    @State private var saveMessage: String?
    @State private var showSaveAlert = false

    private var isFirstExport: Bool {
        !UserDefaults.standard.bool(forKey: "hasExportedFirstFilm")
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: Theme.Spacing.xl)

            if showCheckmark {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.Colors.accent)
                    .transition(.scale.combined(with: .opacity))
                    .padding(.bottom, Theme.Spacing.md)
            }

            Text("Your film is ready.")
                .font(Theme.Typography.heroTitle)
                .foregroundStyle(Theme.Colors.textPrimary)

            Text(filmTitle)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textPrimary.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.sm)

            Spacer()
                .frame(height: Theme.Spacing.xl)

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

            Spacer()

            VStack(spacing: Theme.Spacing.sm) {
                DSPrimaryButton(title: "Save to Camera Roll") {
                    Task {
                        let state = ExportState()
                        do {
                            try await state.saveToCameraRoll(url: url)
                            saveMessage = "Saved to your camera roll!"
                        } catch {
                            saveMessage = error.localizedDescription
                        }
                        showSaveAlert = true
                    }
                }

                Button {
                    showShareSheet = true
                } label: {
                    Text("Share")
                        .font(Theme.Typography.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Theme.Colors.buttonPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Button { dismiss() } label: {
                    Text("Make Another Film")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.top, Theme.Spacing.sm)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .onAppear {
            let newPlayer = AVPlayer(url: url)
            player = newPlayer
            newPlayer.play()

            if isFirstExport {
                UserDefaults.standard.set(true, forKey: "hasExportedFirstFilm")
            }
            withAnimation(.spring(duration: 0.5).delay(0.3)) {
                showCheckmark = true
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [url])
        }
        .alert(saveMessage ?? "", isPresented: $showSaveAlert) {
            Button("OK") {}
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ExportSuccessView(
        url: URL(fileURLWithPath: "/mock/final.mp4"),
        filmTitle: "A mysterious note in a library book"
    )
}
