# Sourcing Checklist — Music Library V1.1

Practical guide for acquiring 30–50 royalty-free tracks and feeding them through the tagging pipeline. Goal: a tagged, bundled library covering all 12 mood buckets with enough range that the LLM matcher rarely runs out of candidates.

## Distribution Target

12 mood buckets × ~4 tracks each = **48 tracks**. A few buckets that come up more often (`contemplative`, `hopeful`, `tense`) can have 5–6; rare ones (`anthemic`, `ominous`) can have 3. Don't fall below 3 per bucket — the matcher needs choice.

| Mood | Target | What it sounds like |
|---|---|---|
| `contemplative` | 5 | solo piano, soft strings, slow ambient — interview / reflection beds |
| `melancholic` | 4 | minor key, sparse, acoustic — sad story moments |
| `tense` | 5 | pulse, low drone, escalating — investigation, suspense |
| `hopeful` | 5 | rising arpeggios, warm pads, mid-tempo strings |
| `joyful` | 4 | bright acoustic, happy piano, light percussion |
| `urgent` | 4 | driving drums, busy strings, fast tempo — chase, race-against-clock |
| `ambient` | 4 | flat texture, no clear melody — backdrop for VO-heavy scenes |
| `triumphant` | 3 | big orchestral, brass, resolution — victory moments |
| `ominous` | 3 | low pulse, dissonant — threat, dread |
| `playful` | 4 | pizzicato, ukulele, whimsical — comedy, kids, casual content |
| `intimate` | 4 | very sparse, single instrument, quiet — close emotional moments |
| `anthemic` | 3 | big build, full kit + orchestra — epic finale, brand piece |

**Within each bucket, mix tempo:** at least one slow, one medium, and one fast (or variable). The matcher can compensate for mood mismatches better than tempo mismatches — getting the pacing right matters more than nailing the mood label.

**Within each bucket, mix instrumentation:** at least one acoustic / one orchestral / one electronic if possible. Beginners shoot all kinds of films; the library shouldn't lean too hard on any single sonic palette.

## Recommended Sources (ranked by ease + license clarity)

| Source | License | Notes |
|---|---|---|
| [Pixabay Music](https://pixabay.com/music/) | Pixabay (commercial OK, no attribution required) | Best starting point. Huge catalog, downloadable as MP3 320kbps. Filter by mood + duration. License compatible with App Store distribution. |
| [Free Music Archive](https://freemusicarchive.org/) | Mostly CC-BY, some CC0 | Higher quality on average, more diverse. Filter by license — CC0 / CC-BY only. **CC-BY tracks need an attribution screen in the app**, which is a UX cost. Prefer CC0 unless a track is unmissable. |
| [ccMixter](https://ccmixter.org/) | Mostly CC-BY | Remixer-focused. Good for `playful` and `urgent` buckets. Same attribution caveat as FMA. |
| [YouTube Audio Library](https://studio.youtube.com/) | YouTube's own license — check per track | Only usable if you confirm the per-track license is "no attribution required" AND read the terms (some restrict commercial use outside YouTube). **Default to skipping** unless you're sure. Note: requires sign-in via YouTube Studio. |
| [Bensound](https://www.bensound.com/) | Free with attribution; Pro tier $20-30/track | The free tier requires attribution, the Pro tier doesn't. If the catalog has must-haves, paying once for 3-4 tracks is reasonable. |

**Avoid** Epidemic Sound, Artlist, Soundstripe — subscription models, licenses don't clear for app bundling.

## Quality Bar

- **320 kbps MP3 minimum**, or lossless (FLAC / WAV). Under 192 kbps will sound rough on AirPods.
- **No obvious compression artifacts.** Listen to the full track at full volume on headphones — if you hear swimming/warbly highs, skip it.
- **Loop-able is a bonus**, not a requirement. Tracks that loop cleanly (tag `loop_friendly: true`) are valuable for `ambient` and short-shot films, but the library shouldn't be all loops.
- **Watch for vocals.** Vocal tracks are almost never useful — they fight the user's narration. Filter out anything with prominent lyrics. (Wordless vocal-as-instrument is fine — atmospheric "ahh" pads work.)
- **Length:** 1:30 to 4:00 is ideal. Shorter tracks work but limit scene length; longer is fine since the app will fade out at the right moment.

## Filing Convention

```
music-library/
├── raw/
│   ├── contemplative/
│   │   ├── quiet-piano-reflection.mp3
│   │   ├── morning-light-pad.mp3
│   │   └── ...
│   ├── tense/
│   │   ├── slow-pulse-build.mp3
│   │   └── ...
│   └── ... (one folder per mood bucket)
├── tags/
│   ├── quiet-piano-reflection.json     ← output of tag_track.py
│   └── ...
└── database.json                        ← output of build_database.py
```

`raw/` is gitignored — audio is large and binary, doesn't belong in git unless using LFS. Track the JSON tags and the final `database.json` only.

**Naming:** lowercase-hyphen-case. Strip the source's auto-appended ID number (`piano-reflection-12345.mp3` → `piano-reflection.mp3`) but keep enough description that the filename tells you what it is.

## Review Workflow (for each track)

```
1. Download → save to music-library/raw/<mood-bucket>/<track-id>.mp3
2. Activate the venv:
     source music-library/venv/bin/activate
3. Tag it:
     python music-library/tag_track.py music-library/raw/<bucket>/<file>.mp3 \
         --source-url "https://pixabay.com/music/..."
   This writes music-library/tags/<track-id>.json with _review_needed=true.
4. Review the JSON:
   - Open the file. Check title, artist, mood, intensity, recommended_for.
   - LISTEN to the track. Does the LLM's mood guess match what you hear?
   - Edit anything wrong. Pay especially close attention to:
     • mood_primary — the LLM can't actually hear and may pick wrong
     • recommended_for — these phrases drive the matcher; make them concrete
     • avoid_for — be specific about what would clash
5. Flip "_review_needed": true → false. Save.
6. Repeat steps 1-5 for the next track. Aim for batches of ~10 in one sitting.
7. After a batch, build:
     python music-library/build_database.py
   This validates everything and writes database.json.
8. Commit tags/ and database.json. Don't commit raw/.
```

## Per-Track Review Checklist (15 seconds each)

- [ ] `title` reads like a real title, not a filename leftover
- [ ] `artist` is correct (or "Unknown" if not credited at the source)
- [ ] `license` matches the source's stated license (Pixabay tracks → "Pixabay")
- [ ] `mood_primary` matches what the track actually sounds like — **this is the most common error from the LLM**
- [ ] `intensity` makes sense (1 = barely audible bed, 5 = full driving)
- [ ] `recommended_for` has 3+ entries that are scene-context-specific, not genre labels
- [ ] `avoid_for` has 2+ realistic anti-cases
- [ ] `loop_friendly` matches the actual feel — does it have a definite ending or could you loop forever?
- [ ] `has_clear_arc` matches — does it build and resolve, or stay flat?

## Time Budget

Roughly 5 minutes per track (download, tag, review, edit). 50 tracks ≈ 4 hours total spread across multiple sessions. Don't try to do all 50 in one sitting — listening fatigue makes mood judgments worse.

Best workflow: do 10 tracks in a sitting, all in one mood bucket. Going bucket-by-bucket helps you keep the relative intensity calibration consistent ("is this a 3 or a 4?" is easier when you just heard 8 other contemplative tracks).

## When the Library is "Good Enough"

Ship V1.1 when:
- All 12 buckets have ≥ 3 approved tracks.
- Total ≥ 30 tracks (50 ideal).
- `build_database.py` runs clean (no warnings, no skipped tracks).
- You've manually run the matching service against 5–10 representative plans (mock them up if needed) and the picks feel right at least 80% of the time.

Anything beyond that is V1.2.
