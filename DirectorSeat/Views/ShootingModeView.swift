import AVKit
import SwiftUI
import UIKit

struct ShootingModeView: View {
    @StateObject private var viewModel: ShootingModeViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showExitConfirmation = false
    @State private var showSkipConfirmation = false
    @State private var showInfoSheet = false
    @State private var showShotReview = false
    @State private var showEndEarlyConfirmation = false
    @State private var isPulsing = false
    @State private var isBlinking = false
    @State private var reviewPlayer: AVPlayer?
    @Environment(\.scenePhase) private var scenePhase

    let project: FilmProject?

    init(plan: FilmmakingPlan, project: FilmProject? = nil) {
        self.project = project
        _viewModel = StateObject(wrappedValue: ShootingModeViewModel(plan: plan, project: project))
    }

    var body: some View {
        Group {
            if viewModel.permissionGranted == false {
                permissionDeniedView
            } else {
                shootingView
            }
        }
        .background(Color.black.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.requestPermissions()
        }
        .onDisappear {
            viewModel.cleanup()
        }
        .navigationDestination(isPresented: $showShotReview) {
            ShotReviewView(
                plan: viewModel.plan,
                capturedTakes: viewModel.capturedTakes,
                selectedTakes: viewModel.selectedTakes,
                project: project
            )
        }
        .onChange(of: viewModel.allShotsComplete) { _, complete in
            if complete { showShotReview = true }
        }
        .onChange(of: viewModel.recordingState) { _, newState in
            if case .reviewing(let url) = newState {
                reviewPlayer = AVPlayer(url: url)
                reviewPlayer?.play()
            } else {
                reviewPlayer = nil
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active, viewModel.permissionGranted == false {
                Task { await viewModel.requestPermissions() }
            }
        }
        .alert("Recording Failed", isPresented: $viewModel.showRecordingError) {
            Button("OK") {}
        } message: {
            Text("Recording failed. Please try again.")
        }
        .alert("Camera Unavailable", isPresented: $viewModel.cameraStartError) {
            Button("OK") { dismiss() }
        } message: {
            Text("Could not access the camera. It may be in use by another app. Please close other camera apps and try again.")
        }
    }

    // MARK: - Main Shooting View

    private var shootingView: some View {
        ZStack {
            CameraPreviewView(previewLayer: viewModel.cameraService.previewLayer)
                .ignoresSafeArea()

            if case .reviewing = viewModel.recordingState {
                reviewOverlay
            } else {
                if viewModel.recordingState == .idle {
                    ruleOfThirdsOverlay
                }

                topBarOverlay

                VStack(spacing: 0) {
                    Spacer()
                    directionCard
                    actionArea
                }

                if viewModel.recordingState == .countingDown {
                    Text("\(viewModel.countdownValue)")
                        .font(.system(size: 80, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(radius: 10)
                }
            }
        }
    }

    // MARK: - Top Bar

    private var topBarOverlay: some View {
        VStack(spacing: 0) {
            VStack(spacing: Theme.Spacing.xs) {
                HStack {
                    Button { showExitConfirmation = true } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white)
                            .shadow(radius: 4)
                            .padding(Theme.Spacing.sm)
                    }

                    Spacer()

                    Text("Shot \(viewModel.currentShotNumber) of \(viewModel.totalShots)")
                        .font(Theme.Typography.body)
                        .foregroundStyle(.white)
                        .shadow(radius: 4)

                    Spacer()

                    Button { showInfoSheet = true } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white)
                            .shadow(radius: 4)
                            .padding(Theme.Spacing.sm)
                    }
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(.white.opacity(0.3))
                            .frame(height: 3)

                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Theme.Colors.accent)
                            .frame(
                                width: geometry.size.width * CGFloat(viewModel.currentShotNumber) / CGFloat(max(viewModel.totalShots, 1)),
                                height: 3
                            )
                    }
                }
                .frame(height: 3)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.md)
            .background(
                LinearGradient(colors: [.black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )

            Spacer()
        }
        .confirmationDialog("Pause shoot", isPresented: $showExitConfirmation) {
            Button("Pause") { dismiss() }
            Button("End Shoot Early") { showEndEarlyConfirmation = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your progress will be saved.")
        }
        .alert("End shoot early?", isPresented: $showEndEarlyConfirmation) {
            Button("End & Review", role: .destructive) { showShotReview = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your captured shots will be saved. You can review what you have so far.")
        }
        .sheet(isPresented: $showInfoSheet) {
            shotInfoSheet
        }
    }

    @ViewBuilder
    private var shotInfoSheet: some View {
        if let shot = viewModel.currentShot {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("\(shot.shotType.uppercased()) SHOT")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.accent)
                    .tracking(2)

                Text(shot.directionText)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text("Camera: \(shot.cameraPlacement)")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)

                Text("Action: \(shot.actorDirection)")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)

                if shot.dialogueDirection?.hasSpokenLine == true, !shot.displayLine.isEmpty {
                    Text("\u{201C}\(shot.displayLine)\u{201D}")
                        .font(Theme.Typography.body.italic())
                        .foregroundStyle(Theme.Colors.textSecondary)

                    if let voiceCue = shot.dialogueDirection?.voiceCue, !voiceCue.isEmpty {
                        Text("\u{25B8} \(voiceCue)")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textSecondary.opacity(0.7))
                            .lineLimit(2)
                    }
                }
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Direction Card

    private var directionCard: some View {
        Group {
            if let shot = viewModel.currentShot {
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(shot.shotType.uppercased()) SHOT")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.accent)
                        .tracking(2)

                    Text(shot.directionText)
                        .font(Theme.Typography.body)
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .padding(.top, Theme.Spacing.sm)

                    Text(shot.cameraPlacement)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.top, Theme.Spacing.sm)

                    Text(shot.actorDirection)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.top, Theme.Spacing.sm)

                    if shot.dialogueDirection?.hasSpokenLine == true, !shot.displayLine.isEmpty {
                        Text("\u{201C}\(shot.displayLine)\u{201D}")
                            .font(Theme.Typography.title.italic())
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                            .padding(.top, Theme.Spacing.sm)

                        if let voiceCue = shot.dialogueDirection?.voiceCue, !voiceCue.isEmpty {
                            Text("\u{25B8} \(voiceCue)")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(.white.opacity(0.7))
                                .lineLimit(2)
                                .padding(.top, Theme.Spacing.xs)
                        }
                    }
                }
                .padding(Theme.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.black.opacity(0.7))
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 16))
                .overlay(alignment: .topTrailing) {
                    Text("~\(shot.estimatedDurationSeconds)s")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(Theme.Spacing.md)
                }
                .opacity(directionCardOpacity)
            }
        }
    }

    private var directionCardOpacity: Double {
        switch viewModel.recordingState {
        case .idle: 1.0
        case .countingDown: 0.5
        case .recording: 0.3
        case .reviewing: 0.0
        }
    }

    // MARK: - Action Area

    private var actionArea: some View {
        VStack(spacing: Theme.Spacing.sm) {
            switch viewModel.recordingState {
            case .idle:
                recordButton
            case .countingDown:
                Color.clear.frame(height: 72)
            case .recording:
                recIndicator
                stopButton
            case .reviewing:
                EmptyView()
            }
        }
        .padding(.vertical, Theme.Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(.black.opacity(0.5))
    }

    private var recordButton: some View {
        Button { viewModel.startRecording() } label: {
            Circle()
                .fill(.red)
                .frame(width: 72, height: 72)
                .scaleEffect(isPulsing ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
        }
        .onAppear { isPulsing = true }
    }

    private var stopButton: some View {
        Button { viewModel.stopRecording() } label: {
            ZStack {
                Circle()
                    .fill(.red.opacity(0.3))
                    .frame(width: 72, height: 72)
                RoundedRectangle(cornerRadius: 6)
                    .fill(.red)
                    .frame(width: 28, height: 28)
            }
        }
    }

    private var recIndicator: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
                .opacity(isBlinking ? 1.0 : 0.3)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isBlinking)
                .onAppear { isBlinking = true }

            Text("REC \u{00B7} \(formattedDuration(viewModel.recordingDuration))")
                .font(Theme.Typography.caption)
                .foregroundStyle(.white)
        }
    }

    // MARK: - Review Overlay

    private var reviewOverlay: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text("Shot \(viewModel.currentShotNumber) of \(viewModel.totalShots)")
                    .font(Theme.Typography.body)
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.top, Theme.Spacing.lg)

            Spacer()

            if let player = reviewPlayer {
                VideoPlayer(player: player)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, Theme.Spacing.lg)
            }

            Spacer()

            VStack(spacing: Theme.Spacing.md) {
                HStack(spacing: Theme.Spacing.sm) {
                    Button {
                        viewModel.retryTake()
                    } label: {
                        Text("Retry")
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Theme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    DSPrimaryButton(title: "Use This") {
                        viewModel.useTake()
                    }
                }

                Button { showSkipConfirmation = true } label: {
                    Text("Skip this shot")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Color.black.ignoresSafeArea())
        .confirmationDialog("Skip this shot?", isPresented: $showSkipConfirmation) {
            Button("Skip", role: .destructive) { viewModel.skipShot() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You can always come back and shoot it later.")
        }
    }

    // MARK: - Rule of Thirds

    private var ruleOfThirdsOverlay: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height

            Path { path in
                path.move(to: CGPoint(x: w / 3, y: 0))
                path.addLine(to: CGPoint(x: w / 3, y: h))
                path.move(to: CGPoint(x: 2 * w / 3, y: 0))
                path.addLine(to: CGPoint(x: 2 * w / 3, y: h))
                path.move(to: CGPoint(x: 0, y: h / 3))
                path.addLine(to: CGPoint(x: w, y: h / 3))
                path.move(to: CGPoint(x: 0, y: 2 * h / 3))
                path.addLine(to: CGPoint(x: w, y: 2 * h / 3))
            }
            .stroke(.white.opacity(0.2), lineWidth: 1)
        }
        .ignoresSafeArea()
    }

    // MARK: - Permission Denied

    private var permissionDeniedView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(Theme.Colors.textSecondary)

            Text("Camera access required")
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textPrimary)

            Text("DirectorSeat needs camera and microphone access to record your shots.")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(Theme.Typography.body)
            .foregroundStyle(Theme.Colors.accent)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.background.ignoresSafeArea())
    }

    // MARK: - Helpers

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

#Preview {
    NavigationStack {
        ShootingModeView(plan: .debugMock)
    }
}
