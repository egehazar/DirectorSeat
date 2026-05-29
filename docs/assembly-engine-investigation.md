# AssemblyEngine Export Orientation Investigation

## Symptom

On real iPhone hardware, exported films rendered with a split frame: portrait
footage filled only the left ~56% of the frame width, the remainder solid
black, with the title card text laid out against a landscape frame (wrong
position). The bug did not reproduce with the synthesized test clips used by
`AssemblyEngineIntegrationTests`, which is why it survived earlier sessions.

## Root cause

The bug was **not** in the AssemblyEngine. `CompositionAssembler` correctly
produced an upright **1080×1920 portrait** intermediate (identity transform).

The fault was entirely in **`VideoExportService`**, which:

1. Rendered its title/end cards at a hardcoded **1920×1080 landscape** size and
   inserted the title card as the *first* segment, so the export composition
   track inherited a landscape `naturalSize`.
2. Never derived `renderSize` from the assembled video — the export fell back to
   that landscape track size.

Result: the 1080-px-wide portrait content was placed into a 1920-px-wide
landscape canvas — `1080 / 1920 = 56.25%`, exactly the observed split.

## How it was localized

Real iPhone footage was committed as test fixtures (`c78193c`,
`DirectorSeatTests/Fixtures/RealFootage/`) because the iPhone's
`preferredTransform` bakes rotation **and** translation together in a way the
rotation-only synthesized clips did not reproduce. An instrumented
real-vs-synthesized pipeline dump then showed the disagreement unambiguously:

- AssemblyEngine output (real): `1080×1920` portrait, identity — correct.
- VideoExportService output (real): `1920×1080` landscape — wrong.
- content-width / canvas-width: `1080 / 1920 = 56.2%`.

## Resolution

- **`100a54a`** — Derive the export `renderSize` from the assembled video's
  `naturalSize.applying(preferredTransform)` (single source of truth) and set it
  explicitly on the video composition in both the CIFilter and no-filter paths.
  Title/end cards now render at that size. Orientation-agnostic: portrait in →
  portrait out, landscape in → landscape out.
- **`d0887d5`** — Follow-on found via the same diagnostic: `VideoExportService`
  allocated an audio track unconditionally, and an empty audio track triggers
  the iOS 26 MediaValidator export rejection (`err=-12783`,
  `exportFailed("Operation Stopped")`) for silent sources. Now allocated lazily,
  matching `CompositionAssembler`.

Both are covered by regression tests against the real-footage fixtures
(`RealFootageExportPipelineTests`); full suite green (19 passed, 0 failed).

## Status — closed

Confirmed on **real iPhone hardware, 2026-05-29**: device export now produces
correct portrait video — no split frame, no misplaced title card. The
renderSize fix is validated end-to-end on device.

`FeatureFlags.useAssemblyEngine` is now shipping **`true`**.
