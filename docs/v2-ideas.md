# V2 Ideas — Multi-user Collaboration & Pricing

Captured from design discussions. Not for V1.1 — these are post-launch.

## Multi-user audio collaboration

Three related features, all V2:

1. **Performer View** — strip-down screen so an actor sees their line/cue/direction when the director hands them the phone. NOTE: a single-device version of this is being built IN V1.1 (see performer-view-spec.md). The V2 version is the multi-device extension below.
2. **Multi-device audio recording** — User B's phone records audio locally during the shoot, uploads after, synced to User A's video.
3. **Multi-user project sharing** — User A (paid) invites User B by a 6-character code; User B joins, records audio for scenes on their own phone.

### Sync approach (decided)
Slate-clap sync (Solution A): actor claps once at shot start; the clap is a sharp peak in both audio waveforms, used to align User B's external audio against User A's video. Chosen over start-time-ping sync (unreliable, network jitter) and waveform cross-correlation (correct but heavy — deferred to a future "auto-sync magic mode").

### Brutal-compromise minimum-viable scope (1–2 weeks)
- One-way collaboration: User B can only upload audio, never edits the plan
- No real-time sync: User B pulls project metadata once on join, never syncs after
- Simple invite: 6-character code typed manually, no deep links
- No conflict resolution (User B can't edit anything that conflicts)
- No push notifications: User A polls the API when they open the project
- Slate-clap sync, no waveform correlation

### Stack
- Neon serverless Postgres for project/collaboration metadata
- S3-equivalent blob store for audio files (Postgres is wrong for 50MB audio blobs)
- Identity: Apple Sign In, synced to the metadata DB

### Known hard parts (for when this becomes real)
- Auth + identity is its own subsystem
- Permission model: decide up front whether collaborators are read-only / audio-only / full co-editors. Hard to change later.
- Deep-link → install → open-with-project-ID flow has Apple-specific gotchas (Universal Links)
- Realistic timeline done well: 4–6 weeks. Minimum-viable: 1–2 weeks with the compromises above.

## Pricing thinking (V1.1 decision + future tiers)

### V1.1 launch decision (settled)
One consumable product, $4.99, "Film Export." No tiers at launch. Watermarked free export (zero credits) vs clean paid export (1 credit). Promo codes for first-export giveaways (Apple-native, marketing not code). Credit-based architecture already built so future tiers are catalog additions, not refactors.

### Future tiers (after launch data, NOT before)
Considered: Sketch Export ($1.99/$2.99 for <60s) + Short Film ($4.99) + Larger Project ($9.99). Decision was to NOT launch with tiers — ship one product, measure real user behavior, add a cheaper tier only if users making tiny tests bounce off the $4.99 paywall. If tiering later, base it on runtime (easy for users to understand), NOT actor count / shot count / "small vs large" (feels arbitrary).

### Rejected for V1.1
- Free first film baked into the app (freemium cannibalization risk; train users that the app is free → poor paid conversion). Use promo codes for recruited testers instead.
- Weekly subscription (retains badly).
