# Performer View — Design Spec (V1.1)

**Status:** Design exploration. No implementation until reviewed.
**Author:** design pass, 2026-05-29.
**Scope:** Single-device. The director hands *their own phone* to the actor.

> Note: the requested brainstorming skill at `/mnt/skills/user/brainstorming/`
> is not present in this environment, so this spec follows the task's own
> design-exploration structure (explore options → recommend with reasoning →
> written spec, no feature code).

## 1. What it is

A stripped-down, glanceable screen the director hands to an actor so the actor
can read **their line, the voice cue, and their direction** at arm's length —
instead of craning across the room at the director's screen. The director then
takes the phone back and records as they do today.

**Fixed decision (not relitigated):** Performer View shows all three — dialogue
line, voice cue, and direction text.

## 2. Grounding in the existing architecture

Read before writing this spec; the design fits these real types:

- **`ShootingModeView.swift`** — the camera screen. `recordingState`-driven
  `ZStack`: `CameraPreviewView` + `topBarOverlay` (xmark exit, "Shot n of N",
  `info.circle` → `shotInfoSheet`) + `directionCard` + `actionArea`. The
  `directionCard` already renders, in a `ScrollView { … }.frame(maxHeight: 260)`:
  shot type, `directionText`, `cameraPlacement`, `actorDirection`, the dialogue
  line in `Theme.Typography.title.italic()` (22pt semibold italic, wrapped in
  `\u{201C}…\u{201D}`), and the voice cue prefixed `\u{25B8}`.
- **`ShootingModeViewModel.swift`** — owns `RecordingState { idle, countingDown,
  recording, reviewing(URL) }`, `currentShot`, `currentShotNumber`,
  `totalShots`, and **`startRecording()`**, which **already contains the
  3‑2‑1 countdown** (`idle → countingDown` via a `Timer` → `beginActualRecording()
  → recording`). The red record button in `actionArea` (`.idle`) is the only
  record trigger.
- **`Shot` / `DialogueDirection`** (`Models/FilmmakingPlan.swift`) —
  `Shot.directionText: String` and `Shot.actorDirection: String` are
  non-optional. `Shot.displayLine` = `userWrittenLine ?? draftLine ?? ""`.
  A shot is "silent" when `dialogueDirection == nil`, `hasSpokenLine == false`,
  or `displayLine.isEmpty` — the same test the `directionCard` uses to decide
  whether to draw the line.
- **`Theme.swift`** — `Typography.title` = 22pt semibold, `heroTitle` = 28pt,
  `body` = 17pt, `caption` = 13pt. `Colors.background` (#0A0A0A),
  `surface` (#161616), `textPrimary` (white), `textSecondary` (gray 0.7),
  `accent` (#F5F1EA). `Spacing.xs…xxl` (4…48).

Convention (`CLAUDE.md`): typography/colors live in `Theme/`; every screen has a
single clear primary action; beginner-first ("when in doubt, simplify").

---

## 3. Open question 1 — Handback mechanism (RECOMMENDED: option **a**)

How does control return to the director to actually record?

| Option | Actor action | Record trigger | New state | Fit with existing flow |
|---|---|---|---|---|
| **(a) "Ready" → hand back → director records** | taps **Ready** (dismisses) | existing red button → `startRecording()` → existing 3‑2‑1 | **1 View-local Bool** | reuses record flow verbatim |
| (b) Director takes phone, dismisses, records | none | existing red button | 1 View-local Bool (dismiss is director's) | same, minus the actor's affordance |
| (c) Actor taps → auto-countdown → auto-record | taps Start | **new** countdown drives recording from Performer View | couples Performer View to `recordingState`; duplicates the countdown | fights the existing flow |

### Recommendation: (a) — actor taps "Ready," hands phone back, director taps record.

**Why.** The record path is already perfect for this: `startRecording()`
*already* runs the 3‑2‑1 countdown the director needs to settle the frame after
taking the phone back. Option (a) changes **nothing** in recording control — the
"Ready" button is purely the dismiss that returns to the existing `.idle`
Shooting Mode, where the red button works exactly as today. New state is a single
View-local `@State private var showPerformerView` (see §7); the ViewModel is
untouched. "Ready" also gives the actor a dignified, unambiguous handback signal
("I've got it — here you go"), which is the social cue the feature is really
about.

**Runner-up: (b).** Functionally identical and equally cheap — both reuse the red
button and add one boolean. It loses only the actor's explicit "Ready" affordance
(someone still has to dismiss Performer View, so the control exists regardless).
If review prefers no actor-facing button, (b) is a one-word relabel of (a)'s
dismiss control ("Done"/"Director") with no architectural difference.

**Rejected: (c).** It is the worst fit on a single device. Recording must **not**
start while the actor is holding the phone — the camera is pointed at the actor,
who needs to hand the phone to the director and step into frame first. (c) also
duplicates the countdown that `startRecording()` already owns and forces
Performer View to drive `recordingState`, adding coupling and state for no gain.
It inverts who directs: the director should hold the record trigger, not the actor.

---

## 4. Open question 2 — Which shots offer Performer View (RECOMMENDED: **all shots**)

| Option | Behavior on silent shots |
|---|---|
| **All shots** | line + cue omitted; **direction becomes the hero** |
| Dialogue-bearing only | entry point hidden on silent shots |

### Recommendation: all shots; silent shots show direction only.

**Why.** The feature's premise is "the actor reads *their stuff* at arm's length
without craning." On a silent shot that stuff is the **direction** — e.g.
`actorDirection` = *"Walk slowly, hand on the wall, looking ahead"* — which is
exactly an instruction the actor benefits from glancing at mid-performance. A
"Hand to Actor" affordance that blinks in and out per shot is more confusing for a
beginner than one that's always there (the beginner-first / "simplify"
convention). The layout already degrades gracefully: no line → the Direction zone
scales up to fill the screen, mirroring how `directionCard` simply omits the line
block when `displayLine` is empty.

**Guard (the genuinely empty case):** offer "Hand to Actor" only when the shot has
*something* to show — `!shot.displayLine.isEmpty || !shot.actorDirection.isEmpty
|| !shot.directionText.isEmpty`. In practice the LLM always populates
`directionText`, so this only hides the button for a degenerate empty shot. See
§8.

---

## 5. Entry point — "Hand to Actor"

**Where.** In the `actionArea`, **`.idle` state only** (you only hand off before
rolling). It sits directly **above the red record button**, styled as a clearly
secondary control so the record button remains the single primary action:

- A full-width pill, `Theme.Colors.surface` background, `Theme.Spacing.md` corner
  radius — matching the existing "Retry" secondary button in `reviewOverlay`.
- Icon `theatermasks.fill` (or `person.fill`) + label **"Hand to Actor"**,
  `Theme.Typography.body`, `textPrimary`.
- Shown only when the §4 guard passes; hidden during `countingDown` / `recording`
  / `reviewing` (the `actionArea` already switches on `recordingState`).

It deliberately does **not** go in the top bar — that bar is shot navigation
(`info.circle` is reference/lookup; "Hand to Actor" is an action and belongs with
the actions).

```
┌──────────────────────────── camera preview ───┐
│  ✕            Shot 2 of 6              ⓘ        │
│                                                 │
│            (rule-of-thirds grid)                │
│                                                 │
│  ┌─ direction card (unchanged) ───────────┐    │
│  │ CLOSE-UP SHOT                    ~10s   │    │
│  │ Close-up of the reader's face…          │    │
│  │ “What the…”                             │    │
│  │ ▸ Muttered, trailing off                │    │
│  └─────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────┐   │  ← NEW, idle only
│  │      🎭  Hand to Actor                   │   │
│  └─────────────────────────────────────────┘   │
│                  (  ●  record )                 │
└─────────────────────────────────────────────────┘
```

## 6. Performer View layout (glanceable at arm's length)

A **full-screen takeover** (not the camera preview) on `Theme.Colors.background`.
Type is sized for reading from several feet away — deliberately larger than the
22pt `directionCard` line, but consistent in *style* (semibold italic line, `▸`
cue, quotes). Add new tokens to `Theme.Typography` to keep theming centralized:

- `performerLine` = `.system(size: 36, weight: .semibold)` → used `.italic()`
- `performerDirection` = `.system(size: 24, weight: .regular)`
- `performerCue` = `.system(size: 20, weight: .medium)`

**Hierarchy (top → bottom), content in a vertical `ScrollView`, "Ready" pinned
below it:**

1. **Context strip** (small): `SHOT n of N · CLOSE-UP` — `Theme.Typography.caption`,
   tracked, `accent`. Tiny chevron-down "Director" close in the top corner (§8).
2. **The Line (hero):** `\u{201C}\(shot.displayLine)\u{201D}` in `performerLine.italic()`,
   `textPrimary`, leading-aligned, generous line spacing. Omitted on silent shots.
3. **Voice cue:** `\u{25B8} \(voiceCue)` in `performerCue`, `accent` / `textSecondary`.
   Omitted when empty.
4. **Direction:** `shot.actorDirection` in `performerDirection`, `textPrimary`.
   On a silent shot this is promoted to the hero (rendered at `performerLine` size).
5. **Pinned primary action:** a large **Ready** button (`DSPrimaryButton` style),
   full-width, always visible **outside** the scroll so it's reachable even when
   the direction text is long.

```
┌──────────── Performer View (full screen) ──────┐
│ SHOT 2 OF 6 · CLOSE-UP                    ⌄     │
│                                                 │
│   “What the…”                                   │  ← 36pt semibold italic
│                                                 │
│   ▸ Muttered, trailing off — genuine surprise   │  ← 20pt, accent
│                                                 │
│   ───────────────────────────────────────────  │
│   Read the note; let your expression change     │  ← 24pt (actorDirection)
│   slowly from curiosity to concern.             │
│      ⋮  (scrolls if longer)                     │
│                                                 │
│   ┌─────────────────────────────────────────┐  │
│   │                Ready                      │  │  ← pinned, dismisses
│   └─────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

> Field mapping to confirm in review: this spec treats "**direction text**" as
> `shot.actorDirection` (the actor's performance instruction) and intentionally
> omits `shot.directionText` (scene/framing description) and `cameraPlacement`
> (a director concern) to keep the screen glanceable. If you meant the literal
> `directionText` field, it's a one-line swap/addition — flag it.

## 7. Interaction flow (start → finish)

```
1. Director in Shooting Mode, recordingState == .idle, framing the shot.
2. Director taps "Hand to Actor"  ──►  showPerformerView = true
3. Performer View covers the screen (camera session stays alive underneath —
   no cleanup()/stopSession()).
4. Director physically hands the phone to the actor.
5. Actor reads line + cue + direction at arm's length; preps.
6. Actor taps "Ready"            ──►  showPerformerView = false  (back to .idle)
7. Actor hands the phone back to the director.
8. Director frames, taps the red record button  ──►  viewModel.startRecording()
   ──►  existing 3‑2‑1 countdown  ──►  .recording   (UNCHANGED)
9. Director taps stop  ──►  review  ──►  Use This / Retry  (UNCHANGED)
```

The dotted box (steps 2–6) is the only new surface; steps 8–9 are today's flow,
untouched.

## 8. State — new vs reused

**New (minimal):**
- `@State private var showPerformerView = false` in `ShootingModeView`, presented
  via `.fullScreenCover(isPresented:)` (or a top `ZStack` layer). **No ViewModel
  changes. No new `RecordingState` case.** Performer View is presentational + one
  dismiss.
- Three `Theme.Typography` tokens (§6).

**Reused (read-only by Performer View):**
- `viewModel.currentShot` (drives all content), `currentShotNumber`, `totalShots`.
- The entire `RecordingState` machine and `startRecording()` — Performer View
  never touches them; entry is gated to `.idle`.

This minimalism is what makes handback option (a) the right call: the feature is a
read-only overlay plus a boolean.

## 9. Edge cases

- **Director backs out mid-Performer-View** (wrong shot / changed mind): a
  secondary chevron-down "Director" control in the top corner also sets
  `showPerformerView = false`. Two dismiss paths (actor "Ready", director close),
  identical effect; `recordingState` stays `.idle`, nothing lost.
- **No direction text:** if a shot has a line but empty `actorDirection`, omit the
  Direction zone (as `directionCard` omits empty blocks). If a shot has *neither*
  line nor any direction (`displayLine`, `actorDirection`, `directionText` all
  empty) the §4 guard hides "Hand to Actor" entirely — nothing to hand over.
- **Very long direction text:** the §6 content lives in a `ScrollView`, mirroring
  the `directionCard`'s `ScrollView { … }.frame(maxHeight: 260)` scroll fix. The
  **Ready button is pinned outside the scroll** so it's always reachable no matter
  how long the direction runs.
- **Backgrounding during handover** (screen locks, etc.): Performer View persists;
  the existing `scenePhase` handler re-checks camera permission on `.active` and
  does not interfere with the overlay.

## 10. Explicitly out of scope (V1.1)

This is **single-device only** — the director hands their own phone over. NOT in
V1.1:

- Multi-device / companion app / the actor's own phone.
- Any audio: no text-to-speech reading the line aloud, no audio cues.
- Teleprompter-style auto-scroll or timed reveal.
- Remote/synced control between two screens.

These are V2 multi-user features. **`docs/v2-ideas.md` does not exist yet** — it
should be created to capture them; this spec only references it as their home.

## 11. Open items for review

1. Confirm handback **option (a)** vs runner-up **(b)** (actor-facing "Ready"
   button or not).
2. Confirm **"direction text" = `actorDirection`** (§6 mapping), or whether to
   also/instead show `directionText`.
3. Confirm the three new `Theme.Typography` sizes (36 / 24 / 20) read well at
   arm's length on-device.
