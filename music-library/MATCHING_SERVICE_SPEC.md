# MusicMatchingService — iOS Spec

Design doc for the runtime service that picks a music track for a generated `FilmmakingPlan`. **This is a spec, not code.** The Swift implementation happens in a future session, after the database has enough tracks (~30+ minimum, ~50+ ideal) to make matching meaningful.

## Surface

```swift
// Services/MusicMatchingService.swift

protocol MusicMatchingService {
    /// Returns up to 3 ranked tracks for the given plan.
    /// nil indicates the matcher could not propose anything (empty database
    /// or all candidates filtered out — rare, but the caller should handle it).
    func match(
        plan: FilmmakingPlan,
        database: MusicDatabase,
        userOverride: MusicTrack? = nil
    ) async throws -> MatchResult?
}

struct MatchResult {
    let primary: MusicTrack          // top pick — what the UI auto-selects
    let alternates: [MusicTrack]     // up to 2 more, ranked, for the swap UI
    let rationale: String            // one-sentence why, shown in the music picker sheet
    let cacheKey: String             // sha256(plan.matchingFingerprint) — see Caching
    let source: MatchSource          // .llm | .cache | .fallback | .userOverride
}

enum MatchSource {
    case llm              // fresh Claude API call
    case cache            // hit per-plan cache
    case fallback         // API unreachable; deterministic local heuristic ran
    case userOverride     // user previously picked a specific track for this plan
}
```

## Algorithm — happy path

1. **Fingerprint the plan.** Hash the matching-relevant fields into a stable string. Plan revisions that don't change the matching inputs (e.g. user edits a shot description but mood/pacing stay the same) reuse the cache.
2. **Check the per-project override store.** If the user has previously picked a specific track for this plan (or a plan with a near-identical fingerprint), return it as `.userOverride` without calling the API.
3. **Check the per-fingerprint cache.** Return cached result if present and not expired (suggested TTL: 30 days — tracks don't go stale, only the database changes).
4. **Build a compact track summary.** For each track in the database, emit one line: `id | mood_primary[/mood_secondary] | tempo_bucket | intensity | instrumentation | recommended_for[0..2]`. Strip `avoid_for` and the longer `recommended_for` entries to keep the prompt small — the LLM doesn't need them at the candidate-list stage. Estimated ~80 tokens/track × 50 tracks ≈ 4K tokens — well under any limit.
5. **Call Claude Sonnet 4.6** with system prompt + plan summary + track list. System prompt is cached (it doesn't change request-to-request); only the plan and track list change.
6. **Parse top-3 ranked ids + per-track rationale + overall rationale.** Validate each id exists in the database (LLM hallucinations are rare but possible). Drop any unknown ids.
7. **Return the result, write to cache.**

## Plan inputs the matcher uses

These are the fields the matcher reads off `FilmmakingPlan`. The fingerprint is a hash of these — nothing else.

- **Plan-level mood** — primary intended emotional register, derived from the user's intake answers. The schema's 12-bucket vocabulary should be the same one the planner emits.
- **Pacing profile per scene** — from the existing scene-level metadata (slow burn / steady / accelerating / fragmented). The matcher aggregates to a dominant pacing.
- **Shot count** — proxy for runtime. Short films (< 8 shots) want loop_friendly tracks more often; longer ones tolerate `has_clear_arc=true`.
- **Dominant audio treatments** — if the plan calls for VO over most shots, the matcher should bias toward `intensity ≤ 3` and `instrumentation` that doesn't fight a voice (no busy orchestration). Editorial direction in the plan probably already encodes this.
- **Editorial direction tags** — anything the existing `EDITORIAL DIRECTION` system prompt section produced. These often carry strong sonic priors ("documentary intimate" → solo acoustic, "hero arc" → orchestral with arc).

## System prompt sketch

```
You are a music supervisor for DirectorSeat, a beginner-filmmaker iOS app. You pick royalty-free music for short films users have just generated a plan for.

You receive:
1. A plan summary — the user's filming intent, mood, pacing, shot count, and editorial direction.
2. A track list — every track in the user's bundled library, summarized with mood, tempo, intensity, instrumentation, and one or two example contexts each track fits.

Pick the top 3 tracks that best match the plan. Rank by match quality.

For each pick:
- Write a one-sentence rationale tied to the plan (NOT generic — reference specific plan elements).
- Confidence: high | medium | low.

Then write one overall rationale paragraph explaining the dominant choice.

OUTPUT JSON ONLY:
{
  "picks": [
    {"id": "track-id", "rationale": "...", "confidence": "high|medium|low"},
    {"id": "track-id-2", "rationale": "...", "confidence": "high|medium|low"},
    {"id": "track-id-3", "rationale": "...", "confidence": "high|medium|low"}
  ],
  "overall_rationale": "..."
}

If no track is a good match, return fewer picks. Never invent track ids.
```

## Caching

- **Per-plan cache** — keyed by `sha256(plan.matchingFingerprint)`. Stored in `Library/Caches/MusicMatchCache/` (or Core Data, if there's already a cache table). 30-day TTL is sensible; tracks rarely change.
- **System prompt cache** — use Anthropic's prompt caching with `cache_control: {type: "ephemeral"}` on the system prompt + frozen track list. Track list changes only when the database is updated (rare); when it does change, the cache invalidates and the next call writes fresh. Expected hit rate: 80%+.
- **Re-generation does not burn API calls** — if the user re-runs the planner without changing matching-relevant inputs, the fingerprint is the same and the cache returns instantly.

## Fallback when the API is unreachable

The matcher must never block plan completion on network. If the Anthropic API errors, times out, or returns malformed output, fall back to a deterministic local heuristic:

```swift
func localFallback(plan: FilmmakingPlan, database: MusicDatabase) -> MatchResult {
    let candidates = database.tracks
        .filter { $0.mood_primary == plan.mood ||
                  $0.mood_secondary == plan.mood }
        .filter { compatibleTempoBucket($0.tempo_bucket, plan.dominantPacing) }
        .filter { $0.intensity >= plan.minIntensity &&
                  $0.intensity <= plan.maxIntensity }

    // Score: mood-primary match worth 2x mood-secondary match.
    // Tie-break: tracks with `recommended_for` entries that share keywords
    // with the plan's editorial direction get a small bonus.
    let ranked = candidates.sorted { a, b in
        score(a, plan: plan) > score(b, plan: plan)
    }

    return MatchResult(
        primary: ranked[0],
        alternates: Array(ranked.dropFirst().prefix(2)),
        rationale: "Selected offline based on mood + pacing match.",
        cacheKey: plan.matchingFingerprint,
        source: .fallback
    )
}
```

The fallback is intentionally deterministic — same inputs always produce the same picks. This means a user who triggered the matcher offline gets the same selection if they retry online and the cache has expired in the meantime, which avoids confusing UI churn.

If the database is empty or no track passes the filters, return `nil` and let the caller show "No music selected — pick one yourself" UI.

## User override flow

- Music picker sheet shows the primary pick + 2 alternates + a "Browse all" option.
- When the user picks a non-primary track, persist `(planFingerprint → trackId)` in a per-project store (e.g., Core Data, with a `MusicOverride` entity tied to the plan's project).
- On subsequent calls to `match()` for the same plan, the override is returned with `source: .userOverride` — the matcher does not re-call the API or re-rank, since the user explicitly chose.
- "Reset to suggested" button in the picker clears the override and triggers a fresh match on next call.
- Browsing all tracks should still show the matcher's ranking as a default sort, with mood/tempo filters available.

## Failure modes to handle

| Failure | Behavior |
|---|---|
| Empty database | Return nil; caller shows "No music available" UI. |
| API unreachable | Run `localFallback`. Set `source: .fallback`. |
| API returns malformed JSON | Log, run `localFallback`. |
| API returns ids not in database | Drop them; if fewer than 3 valid picks remain, fill from fallback. |
| User has saved override but track id no longer exists in database | Treat as if no override; fresh match. Inform via toast. |
| All tracks filtered out by fallback heuristic | Return the closest-mood track regardless of tempo/intensity, plus one wildcard from the same mood family. |

## Performance targets

- LLM call budget: 1500 input tokens (cached prefix amortizes track list cost); 800 output tokens. p50 latency ~2s, p99 < 8s.
- Cache hit case: instant (< 50ms file read).
- Fallback case: < 100ms regardless of database size (50 tracks is trivial).

## Open questions for the implementation session

1. Should `MusicTrack` be an `enum`-like struct or fully decoded from JSON? Probably the latter — the database is shipped, not generated at compile time.
2. Where does `database.json` live? Bundled in the app (locks the catalog at release) vs. fetched from a CDN (lets new tracks ship without app updates). Recommend CDN with a stale-while-revalidate policy + fallback to bundled.
3. Should the matcher prefer `loop_friendly` tracks for fragmented-pacing scenes? Probably yes, but encode the bias in the system prompt rather than the local fallback — the LLM can weigh it against other factors.
4. Plan re-generation is currently triggered by the user; if it becomes automatic on every edit, the cache TTL might need to be shorter to keep matching fresh. For now, 30 days is fine.
