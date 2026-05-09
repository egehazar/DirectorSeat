# V1.1 Hardware Validation Checklist

Everything built tonight (Layers 1-3 dialogue redesign + 14 template rewrite + AssemblyEngine + test target) compiles clean and passes simulator tests. None of it has been validated on real iPhone hardware. This checklist exists so when iPhone access opens up, the validation runs efficiently rather than ad-hoc.

## How to use this

Items are grouped by time cost. Run them in order: quick first while the device is still connecting / app is installing, medium next, full (anything requiring actual filming) last. Mark each PASS / FAIL / SKIP as you go.

Set a 90-minute soft budget. If you blow past it, stop, capture what you've found, and resume next session — don't grind.

## Pre-flight

Before opening Xcode:

- [ ] Phone unlocked, Developer Mode still enabled (Settings → Privacy & Security → Developer Mode)
- [ ] Lightning-to-USB-C or USB-C cable on hand
- [ ] Xcode shows the device under Window → Devices and Simulators within 30 seconds of connect
- [ ] Build target = the borrowed iPhone, not the simulator
- [ ] Scheme = DirectorSeat (not DirectorSeatTests)
- [ ] Deployment target still iOS 18.0 (last set during V1 hardware tests)
- [ ] Recent commit lands on device cleanly with first build

## Quick checks (under 1 minute each)

These verify rendering and surface-level correctness. Do them while the app is still warm from install.

- [ ] **Home screen renders** — project list (or empty state if no saved projects) shows without crashes, "Make a new film" button visible
- [ ] **Idea intake → plan generation works end-to-end with a test idea** — type a 1-sentence idea, tap through to plan generation, plan loads in under 30 seconds without error. If this fails, nothing downstream matters; stop and debug.
- [ ] **Plan Preview shows dialogue sections on dialogue-bearing shots** — divider line above, "DIALOGUE · SPEAKER" eyebrow, italic quoted line, info button on right
- [ ] **Plan Preview hides dialogue section on silent shots** — silent shots show only direction text, no divider, no dialogue display
- [ ] **Tap a dialogue line — edit sheet opens at .medium detent** — text field pre-filled with current line, "Reset to original draft" button only shown if user-written line differs from draft, "Make it silent" button visible, Save button at bottom
- [ ] **Edit a line, hit Save — line updates immediately in Plan Preview** — the new line appears italic+quoted in the shot card
- [ ] **Reopen the same plan from project list — edit persists** — close the plan, return to home, reopen the project, the edited line is still there (validates SwiftData persistence path through the dialogue edit flow)
- [ ] **Tap info button (ⓘ) — info sheet appears** — "WHY THIS LINE" section with beatPurpose, "HOW TO PERFORM" section with voiceCue, "Talk to AI about this line" button at bottom
- [ ] **Tap "Talk to AI about this line" — info sheet dismisses, shot chat opens** — note: there's a 0.3s asyncAfter delay between dismiss and chat open, this is intentional. If the chat doesn't open within 1 second of the dismiss, that's a bug.
- [ ] **Quick-prompt chips appear in shot chat for dialogue-bearing shots** — "Make this funnier", "Three alternatives", "More subtle", "Different tone" visible above the message area, scrollable horizontally if needed
- [ ] **Chips disappear after first user message sent** — type or tap a chip, send the message, chips should vanish on next render

## Medium checks (1-5 minutes each)

These need a few interactions or a short generation cycle.

- [ ] **Conversational shot refinement still works** — tap a shot card, send a refinement request, AI proposes a structured revision, accept it, plan updates. (Layer 2 should not have regressed Layer 1's chat flow.)
- [ ] **Dialogue-craft tutoring loop works** — tap a chip like "Three alternatives", AI returns 2-4 numbered alternatives in conversational format (NOT a structured revision), then express preference for one ("I like #2"), AI follows up with a structured revision. Acceptance updates the line.
- [ ] **Conversation persists per shot** — close shot chat, reopen same shot, previous messages still there. Open a different shot, conversation is empty (per-shot isolation).
- [ ] **Templates browser shows all 14 templates** — scroll through, count them, verify Sketch Bit / Piece to Camera / The Voicemail / The Apology / A Day In all appear, verify Letter / Reunion / Decision do NOT appear (those were cut), verify "The Awkward Run-In" and "The Thing You Find In Their Pocket" appear (renamed from Chase / Mysterious Object)
- [ ] **Template detail view shows engine and emotional escalation** — pick any template, verify the engine field renders as italic accent text below description, verify each scene has its emotional escalation as italic caption below the scene description
- [ ] **Template generation produces editorial metadata** — generate a film from a template, drill into a shot, verify the shot has reasonable values for `recommendedHoldSeconds`, `transitionInType`/`transitionOutType`, `pacingRole`, `audioTreatment`. The data should be present even if we can't yet see its effect on the assembled film.
- [ ] **Shooting Mode renders dialogue at 22pt** — start shooting any film with dialogue-bearing shots, verify the dialogue line appears in title-size italic typography (visibly larger than V1's 17pt body), with the voice cue hint below in caption size with "▸ " prefix
- [ ] **Voice cue hint readable but not distracting during recording** — judgment call: does the cue help you remember how to deliver, or is it cluttering the frame? If cluttering, note it for follow-up.
- [ ] **Multi-language plan generation** — set shooting language to Turkish in the language selector on Quick Context view 2, generate from a Turkish idea text ("Restoranda iki arkadaş, biri diğerine kötü bir haber vermek üzere"), verify dialogue and scaffolding (beat_purpose, voice_cue) come back in Turkish
- [ ] **Migration flag works** — temporarily set `FeatureFlags.useAssemblyEngine = false`, rebuild, run the X-button fast-test pipeline, verify it falls back to VideoAssemblyService cleanly. Then flip back to `true` and rebuild for the rest of testing.

## Full checks (5-15 minutes each, requires actual filming)

These need real takes from the camera. Save them for last because they take the longest.

- [ ] **AssemblyEngine end-to-end with new editorial metadata — produces a watchable film**
  - Pick the **Sketch Bit** template (most dialogue-heavy, structurally tight, fastest to validate)
  - Use idea: "Every time I open the fridge there's one less thing in it. Someone is stealing my food."
  - Shoot all 5 shots in fast-test mode
  - Assemble through to export
  - Save to camera roll, watch the resulting film
  - **Critical questions:**
    - Does the film actually feel like a sketch with setup → escalation → button, or does it feel like a brick of cuts?
    - Does each shot's hold duration feel intentional, or are some too long/short?
    - Does dialogue land cleanly (audible, not stepped on by transitions)?
    - Watermark visible and legible at 32pt with shadow?

- [ ] **Specific editorial metadata reaches the screen — verification shot**
  - Use the same plan from above
  - Look at the assembled film for one shot that has `transitionOutType: "dissolve"` or `pacingRole: "establishing"` with a long `recommendedHoldSeconds`
  - Visually verify: did the dissolve happen? Did the establishing shot hold for the specified duration?
  - If both yes: editorial layer is reaching the screen. Major win.
  - If no: editorial metadata is being generated but ignored downstream. Note which fields fail and we debug separately.

- [ ] **Audio mix verification — is dialogue priority working?**
  - Watch the same film with attention to audio
  - Are dialogue lines clearly audible above any source ambient noise?
  - If a music cue exists in the plan (probably not yet — music library not built), is music ducking under dialogue?
  - Are there any audible pops or jumps at shot boundaries? (50ms boundary crossfades should prevent these)

- [ ] **Compare AssemblyEngine vs VideoAssemblyService side by side**
  - Set `useAssemblyEngine = true`, generate and shoot a film, save the assembled output
  - Set `useAssemblyEngine = false`, regenerate the same plan with same takes (or just rerun assembly), save that output
  - Watch both back-to-back
  - Subjective question: which feels more like a film vs a montage? If they feel identical, the editorial layer isn't doing real work yet and we have a debug job. If the new engine version feels more deliberate, ship it.

- [ ] **Backward compat — assemble a film generated before tonight**
  - Find a saved project from earlier in V1 testing if one exists (the persistence work landed earlier this session)
  - Resume the project, take it through assembly with the new engine
  - Verify it produces a watchable film equivalent to what VideoAssemblyService would have produced (legacy plans have all editorial fields nil → defaults to full take, cuts, dialogue_priority audio)

- [ ] **Take longer than recommended hold — trim from end works correctly**
  - Pick a shot with `recommendedHoldSeconds: 3.0` or so
  - Record a 6-7 second take (over-shoot intentionally)
  - Assemble, verify the assembled shot is roughly 3 seconds and uses the START of the take, not the middle or end
  - Watch for jump cuts or missing action at the cut point

- [ ] **Take shorter than recommended hold — uses full take with warning**
  - Pick a shot with `recommendedHoldSeconds: 5.0`
  - Record a 2-second take (under-shoot)
  - Assemble, verify it doesn't crash, uses the full 2-second take, and that the diagnostic log mentions the warning

## Stretch goals (if time allows)

These are nice-to-have but not blocking V1.1 launch.

- [ ] Run a complete film through The Voicemail template — verify the new template's engine produces a watchable film, not just good text
- [ ] Try the Spanish-explicit-override path with a non-Spanish idea — verify dialogue comes back in Spanish
- [ ] Generate from one template, refine 2-3 shots conversationally, shoot the modified plan, verify the refinements show up in the final film
- [ ] Test the "Make it silent" button in the dialogue edit sheet — flip a dialogue-bearing shot to silent, regenerate (or just re-shoot), verify the assembled film has no dialogue on that shot

## What to do if something fails

For any FAIL:

1. Screenshot or screen-record the problem if possible
2. Note: was it a render bug (wrong text/layout), an interaction bug (tap doesn't work), or a logic bug (wrong output)?
3. Check Xcode console for errors or warnings
4. If the failure is in the AssemblyEngine path, flip `useAssemblyEngine = false` and verify the legacy path still works (rules out general regression vs new-engine-specific bug)
5. Don't try to fix it during the iPhone session — capture, move on, fix in next focused session

If 3+ failures stack up: stop validation, the substrate has issues, focus the rest of the iPhone time on diagnosing one of them carefully rather than continuing to discover more.

## After validation

When iPhone goes back:

1. Commit any debug-flag toggles you made during testing (set them back first if needed)
2. Write a short summary of validation results: what passed, what failed, what's now confirmed shippable
3. The failed items become the work queue for next session
4. The passed items are the baseline V1.1 — anything that breaks them in future is a regression

## Things explicitly NOT being validated tonight

These are deferred to later sessions because they require infrastructure we haven't built yet:

- Actual music in films (music library not curated yet, no tracks loaded)
- Real Apple StoreKit IAP (still using fake `isPaid` toggle)
- Voice preview / dialogue audition (Grok or ElevenLabs not integrated)
- Apple Sign In flow
- Onboarding 3-card first-launch experience
- App Store screenshots, TestFlight beta, privacy policy
- Vision-based room/scene analysis with phone placement overlay

If any of these come up during validation, note them as expected gaps, not failures.
