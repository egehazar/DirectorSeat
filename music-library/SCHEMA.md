# Music Track Schema

JSON shape for every entry in `database.json`. Each track has 13 required fields plus 1 optional. The schema is intentionally narrow — the primary consumer is an LLM matching service that picks tracks from short context-rich descriptions, not a faceted search UI.

## Field Reference

| Field | Type | Notes |
|---|---|---|
| `id` | string | Slug from filename. Must be unique across the database. Lowercase, hyphenated, ASCII only. e.g. `quiet-piano-reflection`. |
| `title` | string | Display name. Title-cased version of the id, optionally with the artist's preferred capitalization. |
| `artist` | string | Composer / uploader. `"Unknown"` if not credited. |
| `source_url` | string | URL the track was acquired from. Required for license traceability. Empty string allowed only for tracks composed in-house. |
| `license` | string (enum) | One of: `CC0`, `CC-BY`, `CC-BY-SA`, `CC-BY-ND`, `CC-BY-NC`, `Pixabay`, `Public Domain`. App-bundled tracks must be `CC0`, `Pixabay`, or `Public Domain`; `CC-BY` requires attribution UI; `CC-BY-NC` is forbidden (DirectorSeat is commercial). |
| `duration_seconds` | number | Float, two-decimal precision. From the audio file directly, not the source's claim. |
| `mood_primary` | string (enum) | One of 12 buckets — see Mood Vocabulary below. |
| `mood_secondary` | string (enum) \| null | Same vocabulary. Optional. Used by the matcher when a scene's mood is between two buckets. |
| `tempo_bucket` | string (enum) | `slow` (under ~70 BPM) \| `medium` (70–110) \| `fast` (over 110) \| `variable` (track changes pace mid-piece). |
| `intensity` | integer | 1–5. 1 = barely-there ambient pad. 5 = full driving with all elements firing. The LLM uses this to match against the dominant pacing profile of the user's plan. |
| `instrumentation` | string | 3–5 word free-text. e.g. `"solo piano"`, `"acoustic guitar and strings"`, `"orchestral with brass and timpani"`, `"synth pad and pulse"`. The matcher uses this when the user's plan implies a sonic palette ("intimate documentary feel" → look for solo acoustic). |
| `recommended_for` | string[] | 3–5 short phrases describing scene contexts this track fits. e.g. `["scene with quiet emotional reveal", "interview-style sit-down", "tension before a quiet decision"]`. **This is the primary field the LLM matches against** — be specific about emotional context and pacing, not genre. |
| `avoid_for` | string[] | 2–3 short phrases describing scenes this would feel wrong for. e.g. `["high-action chase", "comedic cold open"]`. Equally important to the matcher — explicit anti-context prevents bad selections. |
| `loop_friendly` | boolean | True if the track can loop without an obvious seam. False if it has a clear in-out arc that would jar on repeat. |
| `has_clear_arc` | boolean | True if the track builds and resolves (intro → climb → release). False if it's flat / cyclic. The matcher uses this to align with the user's pacing profile — long arc-style scenes want arc-style tracks, fragmented scenes want loopable beds. |

## Mood Vocabulary (12 buckets)

`contemplative`, `melancholic`, `tense`, `hopeful`, `joyful`, `urgent`, `ambient`, `triumphant`, `ominous`, `playful`, `intimate`, `anthemic`

These are deliberately broad — too many fine-grained moods makes LLM matching noisy. Distribution target: ~4–5 tracks per bucket, ~50 tracks total.

## Approval Flag

Every JSON file written by `tag_track.py` includes a top-level `_review_needed: true` flag. `build_database.py` skips any track where this is true and prints a warning. After Ege reviews and edits the proposed tags, flip `_review_needed: false` (or remove the field) to mark the track approved.

Fields prefixed with underscore (`_review_needed`, `_local_only`, `_analysis`, `_llm_error`) are stripped from `database.json` during the build step.

## Example Track (fully populated, approved)

```json
{
  "id": "quiet-piano-reflection",
  "title": "Quiet Piano Reflection",
  "artist": "Lesfm",
  "source_url": "https://pixabay.com/music/solo-piano-quiet-piano-reflection-12345/",
  "license": "Pixabay",
  "duration_seconds": 142.30,
  "mood_primary": "contemplative",
  "mood_secondary": "melancholic",
  "tempo_bucket": "slow",
  "intensity": 2,
  "instrumentation": "solo piano",
  "recommended_for": [
    "scene with quiet emotional reveal",
    "character looking out a window in thought",
    "voiceover over still or slow-moving footage",
    "interview-style sit-down with reflective tone"
  ],
  "avoid_for": [
    "high-action sequence",
    "comedic cold open",
    "celebration or victory moment"
  ],
  "loop_friendly": false,
  "has_clear_arc": true
}
```

## Validation Rules

`build_database.py` enforces:

- All non-optional fields present and non-null
- `recommended_for` and `avoid_for` are non-empty arrays
- `mood_primary` (and `mood_secondary` if present) ∈ Mood Vocabulary
- `tempo_bucket` ∈ {slow, medium, fast, variable}
- `intensity` is an integer 1–5
- `license` ∈ recognized set (warns rather than fails on unrecognized — this lets Ege add new license types ad-hoc)
- `_review_needed: true` blocks the track from the build

Tracks that fail validation are listed with their problems and excluded from `database.json`. Run `python build_database.py --strict` to make the build exit non-zero on any issue (useful for CI).
