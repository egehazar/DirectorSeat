import SwiftData
import SwiftUI

struct PlanPreviewView: View {
    @State private var plan: FilmmakingPlan
    var project: FilmProject?
    @Environment(\.dismiss) private var dismiss
    @State private var showChecklist = false
    @State private var activeShotChat: ShotChatContext?
    @State private var editingDialogue: DialogueEditContext?
    @State private var editingDialogueText = ""
    @State private var showingDialogueInfo: DialogueInfoContext?
    @State private var pendingChatFromInfo: ShotChatContext?

    init(plan: FilmmakingPlan, project: FilmProject? = nil) {
        _plan = State(initialValue: plan)
        self.project = project
    }

    private var totalShots: Int {
        plan.scenes.reduce(0) { $0 + $1.shots.count }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .padding(Theme.Spacing.xs)
                }
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.lg)

            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(plan.logline)
                            .font(Theme.Typography.title)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .lineSpacing(2)
                            .padding(.top, Theme.Spacing.lg)

                        Text("\(plan.scenes.count) scenes \u{00B7} \(totalShots) shots \u{00B7} ~\(plan.estimatedTotalShootMinutes) min to shoot")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .padding(.vertical, Theme.Spacing.sm)
                            .padding(.horizontal, Theme.Spacing.md)
                            .background(Theme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.top, Theme.Spacing.md)

                        ForEach(plan.scenes) { scene in
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(spacing: Theme.Spacing.sm) {
                                    Rectangle()
                                        .fill(Theme.Colors.surface)
                                        .frame(width: 40, height: 1)

                                    Text("SCENE \(scene.sceneNumber)")
                                        .font(Theme.Typography.caption)
                                        .foregroundStyle(Theme.Colors.accent)
                                        .tracking(2)
                                }
                                .padding(.top, Theme.Spacing.xl)

                                Text(scene.description)
                                    .font(Theme.Typography.body)
                                    .foregroundStyle(Theme.Colors.textSecondary)
                                    .padding(.top, Theme.Spacing.sm)

                                VStack(spacing: Theme.Spacing.sm) {
                                    ForEach(scene.shots) { shot in
                                        shotCard(shot: shot, scene: scene)
                                    }
                                }
                                .padding(.top, Theme.Spacing.md)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, 100)
                }

                LinearGradient(
                    colors: [Theme.Colors.background.opacity(0), Theme.Colors.background],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 40)
                .allowsHitTesting(false)
            }

            VStack(spacing: Theme.Spacing.sm) {
                DSPrimaryButton(title: "Let's Shoot") {
                    showChecklist = true
                }

                Text("Tap any shot to refine it \u{00B7} Next: setup checklist")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary.opacity(0.6))
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showChecklist) {
            SetupChecklistView(plan: plan, project: project)
        }
        .sheet(item: $activeShotChat, onDismiss: {
            savePlanToProject()
        }) { context in
            ShotChatView(
                plan: $plan,
                shot: context.shot,
                globalShotNumber: context.globalShotNumber,
                project: project,
                existingMessages: project?.conversations[context.globalShotNumber] ?? []
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingDialogue) { context in
            dialogueEditSheet(context: context)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $showingDialogueInfo, onDismiss: {
            if let pending = pendingChatFromInfo {
                pendingChatFromInfo = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    activeShotChat = pending
                }
            }
        }) { context in
            dialogueInfoSheet(context: context)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Shot Card

    private func shotCard(shot: Shot, scene: FilmScene) -> some View {
        let globalNum = globalShotNumber(for: shot, in: scene)
        return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("SHOT \(shot.shotNumber) \u{00B7} \(shot.shotType.uppercased())")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .tracking(1.5)

            Text(shot.directionText)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textPrimary)

            if let dd = shot.dialogueDirection, dd.hasSpokenLine {
                Rectangle()
                    .fill(Theme.Colors.textSecondary.opacity(0.15))
                    .frame(height: 1)
                    .padding(.vertical, Theme.Spacing.md)

                HStack {
                    Text("DIALOGUE \u{00B7} \(dd.speaker?.uppercased() ?? "SPEAKER")")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .tracking(1.5)
                    Spacer()
                    Button {
                        showingDialogueInfo = DialogueInfoContext(shot: shot, globalShotNumber: globalNum)
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.Colors.textSecondary.opacity(0.6))
                    }
                }

                Button {
                    editingDialogueText = shot.displayLine
                    editingDialogue = DialogueEditContext(shot: shot, globalShotNumber: globalNum)
                } label: {
                    let line = shot.displayLine
                    Group {
                        if line.isEmpty {
                            Text("[no line written yet]")
                                .font(Theme.Typography.body.italic())
                                .foregroundStyle(Theme.Colors.textSecondary.opacity(0.5))
                        } else {
                            Text("\u{201C}\(line)\u{201D}")
                                .font(Theme.Typography.body.italic())
                                .foregroundStyle(Theme.Colors.textPrimary.opacity(0.95))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            activeShotChat = ShotChatContext(shot: shot, globalShotNumber: globalNum)
        }
    }

    // MARK: - Dialogue Edit Sheet

    private func dialogueEditSheet(context: DialogueEditContext) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Edit line")
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Colors.textPrimary)

            Text("Shot \(context.globalShotNumber) \u{00B7} \(context.shot.dialogueDirection?.speaker?.uppercased() ?? "SPEAKER")")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)

            TextField("Write your line...", text: $editingDialogueText, axis: .vertical)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(4...8)
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack(spacing: Theme.Spacing.md) {
                if let dd = context.shot.dialogueDirection,
                   let draft = dd.draftLine,
                   dd.userWrittenLine != nil,
                   dd.userWrittenLine != draft {
                    Button("Reset to original draft") {
                        editingDialogueText = draft
                    }
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                }

                Button("Make it silent") {
                    makeDialogueSilent(globalShotNumber: context.globalShotNumber)
                    editingDialogue = nil
                }
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
            }

            Spacer()

            DSPrimaryButton(title: "Save") {
                saveDialogueEdit(globalShotNumber: context.globalShotNumber, newLine: editingDialogueText)
                editingDialogue = nil
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.background)
    }

    // MARK: - Dialogue Info Sheet

    private func dialogueInfoSheet(context: DialogueInfoContext) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("WHY THIS LINE")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .tracking(1.5)

            Text(context.shot.dialogueDirection?.beatPurpose ?? "")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textPrimary)

            Text("HOW TO PERFORM")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .tracking(1.5)
                .padding(.top, Theme.Spacing.md)

            Text(context.shot.dialogueDirection?.voiceCue ?? "")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textPrimary)

            Spacer()

            Button {
                pendingChatFromInfo = ShotChatContext(shot: context.shot, globalShotNumber: context.globalShotNumber)
                showingDialogueInfo = nil
            } label: {
                Text("Talk to AI about this line")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.accent)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.background)
    }

    // MARK: - Dialogue Editing Helpers

    private func saveDialogueEdit(globalShotNumber: Int, newLine: String) {
        guard let (si, shi) = plan.sceneAndShotIndex(forGlobal: globalShotNumber) else { return }
        let oldShot = plan.scenes[si].shots[shi]
        guard let oldDD = oldShot.dialogueDirection else { return }
        let newDD = DialogueDirection(
            hasSpokenLine: oldDD.hasSpokenLine,
            speaker: oldDD.speaker,
            beatPurpose: oldDD.beatPurpose,
            voiceCue: oldDD.voiceCue,
            draftLine: oldDD.draftLine,
            userWrittenLine: newLine.isEmpty ? nil : newLine
        )
        let newShot = oldShot.withDialogueDirection(newDD)
        if let updated = plan.replacingShot(atGlobal: globalShotNumber, with: newShot) {
            plan = updated
            savePlanToProject()
        }
    }

    private func makeDialogueSilent(globalShotNumber: Int) {
        guard let (si, shi) = plan.sceneAndShotIndex(forGlobal: globalShotNumber) else { return }
        let oldShot = plan.scenes[si].shots[shi]
        guard let oldDD = oldShot.dialogueDirection else { return }
        let silentDD = DialogueDirection(
            hasSpokenLine: false,
            speaker: oldDD.speaker,
            beatPurpose: oldDD.beatPurpose,
            voiceCue: oldDD.voiceCue,
            draftLine: oldDD.draftLine,
            userWrittenLine: oldDD.userWrittenLine
        )
        let newShot = oldShot.withDialogueDirection(silentDD)
        if let updated = plan.replacingShot(atGlobal: globalShotNumber, with: newShot) {
            plan = updated
            savePlanToProject()
        }
    }

    // MARK: - Helpers

    private func globalShotNumber(for shot: Shot, in scene: FilmScene) -> Int {
        var num = 0
        for s in plan.scenes {
            for sh in s.shots {
                num += 1
                if s.sceneNumber == scene.sceneNumber && sh.shotNumber == shot.shotNumber {
                    return num
                }
            }
        }
        return 0
    }

    private func savePlanToProject() {
        guard let project else { return }
        project.plan = plan
        try? project.modelContext?.save()
    }
}

// MARK: - Context Types

private struct ShotChatContext: Identifiable {
    let id = UUID()
    let shot: Shot
    let globalShotNumber: Int
}

private struct DialogueEditContext: Identifiable {
    let id = UUID()
    let shot: Shot
    let globalShotNumber: Int
}

private struct DialogueInfoContext: Identifiable {
    let id = UUID()
    let shot: Shot
    let globalShotNumber: Int
}

#Preview {
    NavigationStack {
        PlanPreviewView(plan: .sample)
    }
}
