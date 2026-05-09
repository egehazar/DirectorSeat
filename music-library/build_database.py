#!/usr/bin/env python3
"""
build_database.py — Validate every tag JSON in tags/ and concatenate the approved
tracks into database.json. The iOS app loads this single file (or fetches it
from a CDN) at runtime.

A track is approved iff `_review_needed` is false or absent. Anything still
flagged is excluded with a warning. Same for malformed JSON, missing required
fields, or invalid enum values.

Usage:
    python build_database.py
    python build_database.py --strict     # exit non-zero if anything was skipped
    python build_database.py --tags-dir other/dir --output other/database.json
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Any


REQUIRED_FIELDS = [
    "id",
    "title",
    "artist",
    "source_url",
    "license",
    "duration_seconds",
    "mood_primary",
    "tempo_bucket",
    "intensity",
    "instrumentation",
    "recommended_for",
    "avoid_for",
    "loop_friendly",
    "has_clear_arc",
]

# `source_url` is required to be present, but allowed to be empty for
# in-house compositions. Same for `mood_secondary` (may be null).
ALLOW_EMPTY = {"source_url"}
ARRAY_FIELDS = {"recommended_for", "avoid_for"}

VALID_MOODS = {
    "contemplative", "melancholic", "tense", "hopeful", "joyful", "urgent",
    "ambient", "triumphant", "ominous", "playful", "intimate", "anthemic",
}

VALID_TEMPO_BUCKETS = {"slow", "medium", "fast", "variable"}

KNOWN_LICENSES = {
    "CC0", "CC-BY", "CC-BY-SA", "CC-BY-ND", "CC-BY-NC",
    "Pixabay", "Public Domain",
}


def validate(track: dict) -> tuple[list[str], list[str]]:
    """Return (errors, warnings) for a single track dict."""
    errors: list[str] = []
    warnings: list[str] = []

    if track.get("_review_needed"):
        errors.append("_review_needed=true — review the proposed tags and flip to false")
        return errors, warnings

    # Required field presence
    for f in REQUIRED_FIELDS:
        if f not in track:
            errors.append(f"missing required field: {f}")
            continue
        v = track[f]
        if v is None and f not in ALLOW_EMPTY:
            errors.append(f"required field is null: {f}")
            continue
        if f in ARRAY_FIELDS and isinstance(v, list) and len(v) == 0:
            errors.append(f"required array is empty: {f}")

    # Enum checks (only if the field is present and non-null)
    mp = track.get("mood_primary")
    if mp and mp not in VALID_MOODS:
        errors.append(
            f"mood_primary={mp!r} is not in the 12-bucket vocabulary "
            f"({sorted(VALID_MOODS)})"
        )

    ms = track.get("mood_secondary")
    if ms and ms not in VALID_MOODS:
        errors.append(f"mood_secondary={ms!r} is not in the 12-bucket vocabulary")

    tb = track.get("tempo_bucket")
    if tb and tb not in VALID_TEMPO_BUCKETS:
        errors.append(
            f"tempo_bucket={tb!r} must be one of {sorted(VALID_TEMPO_BUCKETS)}"
        )

    intensity = track.get("intensity")
    if intensity is not None:
        if not isinstance(intensity, int) or isinstance(intensity, bool):
            errors.append(f"intensity must be an integer, got {type(intensity).__name__}: {intensity!r}")
        elif not (1 <= intensity <= 5):
            errors.append(f"intensity must be 1-5, got {intensity}")

    lic = track.get("license")
    if lic and lic not in KNOWN_LICENSES:
        warnings.append(f"unrecognized license {lic!r} (not in {sorted(KNOWN_LICENSES)})")

    # Type checks for booleans
    for bool_field in ("loop_friendly", "has_clear_arc"):
        v = track.get(bool_field)
        if v is not None and not isinstance(v, bool):
            errors.append(f"{bool_field} must be boolean, got {type(v).__name__}: {v!r}")

    # ID sanity
    track_id = track.get("id")
    if track_id and not isinstance(track_id, str):
        errors.append(f"id must be a string, got {type(track_id).__name__}")
    elif track_id and not track_id.replace("-", "").replace("_", "").isalnum():
        warnings.append(f"id={track_id!r} contains characters outside [a-z0-9_-]; matcher caching is keyed on it")

    return errors, warnings


def strip_private(track: dict) -> dict:
    """Remove underscore-prefixed fields before adding to the database."""
    return {k: v for k, v in track.items() if not k.startswith("_")}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tags-dir", type=Path, default=Path(__file__).parent / "tags")
    parser.add_argument(
        "--output", type=Path, default=Path(__file__).parent / "database.json"
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="exit non-zero if any track was skipped (for CI)",
    )
    args = parser.parse_args()

    if not args.tags_dir.exists():
        sys.exit(f"Error: tags directory not found: {args.tags_dir}")

    json_files = sorted(args.tags_dir.glob("*.json"))
    if not json_files:
        sys.exit(f"Error: no .json files in {args.tags_dir}")

    approved: list[dict[str, Any]] = []
    skipped: list[tuple[Path, list[str]]] = []
    seen_ids: dict[str, Path] = {}

    for path in json_files:
        try:
            track = json.loads(path.read_text())
        except json.JSONDecodeError as e:
            print(f"  ✗ {path.name}: malformed JSON — {e}", file=sys.stderr)
            skipped.append((path, [f"malformed JSON: {e}"]))
            continue

        if not isinstance(track, dict):
            print(f"  ✗ {path.name}: top-level value is not an object", file=sys.stderr)
            skipped.append((path, ["top-level value is not an object"]))
            continue

        errors, warnings = validate(track)

        # Duplicate id check
        track_id = track.get("id")
        if track_id and track_id in seen_ids and not errors:
            errors.append(
                f"duplicate id {track_id!r} (also defined in {seen_ids[track_id].name})"
            )

        if errors:
            print(f"  ✗ {path.name}:", file=sys.stderr)
            for e in errors:
                print(f"      - {e}", file=sys.stderr)
            for w in warnings:
                print(f"      - (warning) {w}", file=sys.stderr)
            skipped.append((path, errors))
            continue

        if warnings:
            print(f"  ! {path.name} (approved with warnings):", file=sys.stderr)
            for w in warnings:
                print(f"      - {w}", file=sys.stderr)
        else:
            print(f"  ✓ {path.name}", file=sys.stderr)

        if track_id:
            seen_ids[track_id] = path
        approved.append(strip_private(track))

    print(
        f"\nResult: {len(approved)} approved, {len(skipped)} skipped",
        file=sys.stderr,
    )

    if approved:
        # Sort by id for deterministic database output (helps git diffs).
        approved.sort(key=lambda t: t.get("id", ""))
        database = {
            "schema_version": 1,
            "track_count": len(approved),
            "tracks": approved,
        }
        args.output.write_text(json.dumps(database, indent=2) + "\n")
        print(f"Wrote {args.output} ({len(approved)} tracks)", file=sys.stderr)
    else:
        print("No approved tracks — database.json was NOT written.", file=sys.stderr)

    if args.strict and skipped:
        sys.exit(1)


if __name__ == "__main__":
    main()
