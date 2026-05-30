import SwiftUI

/// A glanceable, single-device screen the director hands to an actor so they can
/// read their line, voice cue, and direction at arm's length — instead of
/// craning at the director's screen. Presented full-screen over Shooting Mode.
///
/// Handback (Option a per docs/performer-view-spec.md): the actor taps "Ready"
/// (or the director taps the corner close) to dismiss back to the `.idle`
/// Shooting Mode, where the existing red record button — which already runs the
/// 3-2-1 countdown — does the actual recording. Tapping "Ready" never starts
/// recording; it only hands control back. This view is presentational only and
/// never touches the recording state machine.
struct PerformerView: View {
    let shot: Shot
    let shotNumber: Int
    let totalShots: Int

    @Environment(\.dismiss) private var dismiss

    private var line: String { shot.displayLine }
    private var voiceCue: String { shot.dialogueDirection?.voiceCue ?? "" }
    private var hasVoiceCue: Bool { shot.hasPerformerLine && !voiceCue.isEmpty }
    private var hasDirection: Bool { !shot.actorDirection.isEmpty }

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                contextStrip

                // Long lines / direction scroll rather than truncate — same
                // pattern as the Shooting Mode direction card. The Ready button
                // is pinned below, outside the scroll, so it's always reachable.
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        if shot.hasPerformerLine {
                            lineView
                            if hasVoiceCue { cueView }
                            if hasDirection {
                                Divider()
                                    .overlay(Color.white.opacity(0.15))
                                    .padding(.vertical, Theme.Spacing.xs)
                                directionView(hero: false)
                            }
                        } else if hasDirection {
                            // Silent shot: actor direction promoted to hero size.
                            directionView(hero: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.xl)
                }

                readyButton
            }
        }
    }

    // MARK: - Context strip

    private var contextStrip: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("SHOT \(shotNumber) OF \(totalShots) \u{00B7} \(shot.shotType.uppercased())")
                .font(Theme.Typography.caption)
                .tracking(2)
                .foregroundStyle(Theme.Colors.accent)

            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(Theme.Spacing.sm)
            }
            .accessibilityLabel("Back to director")
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.lg)
    }

    // MARK: - Content

    private var lineView: some View {
        Text("\u{201C}\(line)\u{201D}")
            .font(Theme.Typography.performerLine.italic())
            .foregroundStyle(Theme.Colors.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(6)
    }

    private var cueView: some View {
        Text("\u{25B8} \(voiceCue)")
            .font(Theme.Typography.performerCue)
            .foregroundStyle(Theme.Colors.accent)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Actor direction. On a silent shot (`hero == true`) it takes the hero slot
    /// at line size but stays upright (it's an instruction, not a spoken quote).
    private func directionView(hero: Bool) -> some View {
        Text(shot.actorDirection)
            .font(hero ? Theme.Typography.performerLine : Theme.Typography.performerDirection)
            .foregroundStyle(Theme.Colors.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(hero ? 6 : 4)
    }

    // MARK: - Ready (handback)

    private var readyButton: some View {
        DSPrimaryButton(title: "Ready") { dismiss() }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.xl)
            .background(Theme.Colors.background)
    }
}

// MARK: - Performer View availability

extension Shot {
    /// True when this shot has a spoken line to surface in Performer View.
    var hasPerformerLine: Bool {
        dialogueDirection?.hasSpokenLine == true && !displayLine.isEmpty
    }

    /// True when Performer View has anything worth showing — a line or an actor
    /// direction. A shot with neither hides the "Hand to Actor" entry point.
    var hasPerformerContent: Bool {
        hasPerformerLine || !actorDirection.isEmpty
    }
}

#Preview("Spoken shot") {
    PerformerView(
        shot: FilmmakingPlan.debugMock.scenes[0].shots[2],
        shotNumber: 3,
        totalShots: 8
    )
}

#Preview("Silent shot") {
    PerformerView(
        shot: FilmmakingPlan.debugMock.scenes[0].shots[0],
        shotNumber: 1,
        totalShots: 8
    )
}
