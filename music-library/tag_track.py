#!/usr/bin/env python3
"""
tag_track.py — Tag a single audio file for the DirectorSeat music library.

Reads an audio file, computes local statistics (duration, tempo, dynamic range,
RMS curve), then asks Claude Sonnet 4.6 to propose tag values matching SCHEMA.md.
Output is written to music-library/tags/{track_id}.json with _review_needed=true
so a human reviews before commit.

Usage:
    python tag_track.py <audio-file>
    python tag_track.py <audio-file> --source-url "https://pixabay.com/..."

If ANTHROPIC_API_KEY is not set, the script still produces valid JSON with the
local analysis populated and the LLM-derived fields left null + _local_only=true,
so a human can fill in the proposed tags by hand.
"""

import argparse
import json
import os
import re
import sys
import unicodedata
from pathlib import Path

import numpy as np
import soundfile as sf
import librosa
import mutagen


SCHEMA_SYSTEM_PROMPT = """You are a music supervisor tagging a royalty-free track for DirectorSeat, an iOS app that guides beginners through making short films with their phone. Your job is to propose tag values from limited information: filename, duration, tempo estimate, dynamic range, and a 5-bucket RMS curve describing energy across the track.

You CANNOT actually hear the audio. Make plausible inferences from the data. A human reviewer will verify and correct your proposals before they ship — when uncertain, lean toward the more common interpretation rather than guessing wildly.

OUTPUT SCHEMA (return JSON only, no prose, no code fences):
{
  "title": "string — derived from filename, prettified (e.g. 'sad-piano-solo.mp3' → 'Sad Piano Solo')",
  "artist": "Unknown" | "string from filename if a credit pattern is visible (e.g. 'song-by-johndoe.mp3' → 'johndoe')",
  "license": "CC0" | "CC-BY" | "CC-BY-SA" | "CC-BY-ND" | "CC-BY-NC" | "Pixabay" | "Public Domain" | "Unknown",
  "mood_primary": "one of: contemplative, melancholic, tense, hopeful, joyful, urgent, ambient, triumphant, ominous, playful, intimate, anthemic",
  "mood_secondary": "same vocabulary OR null",
  "tempo_bucket": "slow (<70 BPM) | medium (70-110) | fast (>110) | variable",
  "intensity": "integer 1-5 (1=barely-there ambient, 5=full driving with all elements)",
  "instrumentation": "3-5 word description (e.g. 'solo piano', 'acoustic guitar and strings', 'orchestral with brass')",
  "recommended_for": ["3-5 short phrases describing scene contexts this fits"],
  "avoid_for": ["2-3 short phrases describing scenes this would feel wrong for"],
  "loop_friendly": "boolean — true if energy curve is flat/cyclic and could loop without seam",
  "has_clear_arc": "boolean — true if RMS curve builds and resolves, false if flat"
}

REASONING GUIDE:
- Filename keywords often hint at mood: 'sad', 'epic', 'calm', 'happy', 'tension', 'uplifting', 'cinematic', 'corporate', 'inspiring' all carry strong priors.
- Tempo + RMS curve together imply intensity: high RMS + fast tempo → 4-5; low RMS + slow tempo → 1-2; mid-range RMS at any tempo → 3.
- Flat RMS curve (all 'low' or all 'medium') → loop_friendly=true, has_clear_arc=false.
- RMS curve that goes low → high → low, or steadily rises and resolves → has_clear_arc=true, loop_friendly likely false.
- Wide dynamic range (>15 dB) suggests dramatic arc; narrow (<8 dB) suggests ambient/loopable bed.
- recommended_for is the primary field a downstream LLM uses to match scenes — be specific about emotional context and pacing, not genre. Examples that work: 'scene with quiet emotional reveal', 'interview sit-down with reflective tone', 'comedic cold open', 'tension before a quiet decision', 'travel montage', 'hopeful closing voiceover'. Avoid genre labels like 'cinematic underscore' — those don't help the matcher.
- avoid_for is equally important. Be concrete about what kind of scene it would clash with.
- License: filenames from Pixabay typically end in a numeric ID; assume Pixabay if unclear and the user can override. Default to 'Unknown' rather than guessing CC0."""


def slugify(name: str) -> str:
    """Filename → URL/path-safe id."""
    name = unicodedata.normalize("NFKD", name)
    name = name.encode("ascii", "ignore").decode("ascii")
    name = re.sub(r"[^\w\s-]", "", name).strip().lower()
    name = re.sub(r"[-\s_]+", "-", name)
    return name or "untitled"


def label_rms(normalized: float) -> str:
    """Bucket a normalized RMS value [0,1] into low/medium/high for the LLM."""
    if normalized < 0.4:
        return "low"
    if normalized < 0.7:
        return "medium"
    return "high"


def analyze_audio(path: Path) -> dict:
    """Compute the local stats Claude needs to reason about the track."""
    # File-level metadata via mutagen
    meta_info: dict = {}
    try:
        meta = mutagen.File(str(path))
        if meta is not None:
            if hasattr(meta, "info"):
                meta_info["sample_rate"] = getattr(meta.info, "sample_rate", None)
                meta_info["channels"] = getattr(meta.info, "channels", None)
                meta_info["bitrate"] = getattr(meta.info, "bitrate", None)
            tags = dict(meta.tags or {}) if hasattr(meta, "tags") and meta.tags else {}
            if tags:
                meta_info["tags"] = {k: str(v) for k, v in tags.items()}
    except Exception as e:
        meta_info["error"] = str(e)

    # Load audio (mono, native sample rate) for waveform analysis
    y, sr = librosa.load(str(path), sr=None, mono=True)
    duration = float(librosa.get_duration(y=y, sr=sr))

    # 5-bucket RMS curve: intro / early / mid / late / outro
    rms = librosa.feature.rms(y=y, frame_length=2048, hop_length=512).flatten()
    n = len(rms)
    if n < 5:
        # Track too short for meaningful bucketing — fall back to flat
        rms_buckets = [float(rms.mean()) if n else 0.0] * 5
    else:
        bucket_size = n // 5
        rms_buckets = []
        for i in range(5):
            start = i * bucket_size
            end = start + bucket_size if i < 4 else n
            rms_buckets.append(float(rms[start:end].mean()))

    rms_max = max(rms_buckets) or 1.0
    rms_norm = [v / rms_max for v in rms_buckets]
    rms_curve = {
        "intro": label_rms(rms_norm[0]),
        "early": label_rms(rms_norm[1]),
        "mid":   label_rms(rms_norm[2]),
        "late":  label_rms(rms_norm[3]),
        "outro": label_rms(rms_norm[4]),
    }

    # Tempo via librosa beat tracking
    try:
        tempo, _ = librosa.beat.beat_track(y=y, sr=sr)
        tempo = float(np.atleast_1d(tempo)[0])
    except Exception:
        tempo = 0.0

    # Dynamic range = peak / RMS, in dB
    if len(y) == 0:
        dr_db = 0.0
    else:
        peak = float(np.max(np.abs(y)))
        rms_global = float(np.sqrt(np.mean(y ** 2)))
        if peak > 0 and rms_global > 0:
            dr_db = 20.0 * float(np.log10(peak / rms_global))
        else:
            dr_db = 0.0

    return {
        "metadata": meta_info,
        "duration_seconds": round(duration, 2),
        "tempo_bpm_estimate": round(tempo, 1),
        "dynamic_range_db": round(dr_db, 2),
        "rms_curve": rms_curve,
        "rms_normalized": [round(v, 3) for v in rms_norm],
    }


def call_claude(filename: str, analysis: dict) -> dict:
    """Ask Claude Sonnet 4.6 to propose schema field values from the local analysis."""
    import anthropic

    client = anthropic.Anthropic()

    # Cache the schema/system prompt — it's frozen across all calls.
    system = [
        {
            "type": "text",
            "text": SCHEMA_SYSTEM_PROMPT,
            "cache_control": {"type": "ephemeral"},
        }
    ]

    user_text = (
        f"Filename: {filename}\n"
        f"Duration: {analysis['duration_seconds']}s\n"
        f"Tempo estimate: {analysis['tempo_bpm_estimate']} BPM\n"
        f"Dynamic range: {analysis['dynamic_range_db']} dB\n"
        f"RMS curve (energy across the track):\n"
        f"  intro: {analysis['rms_curve']['intro']}\n"
        f"  early: {analysis['rms_curve']['early']}\n"
        f"  mid:   {analysis['rms_curve']['mid']}\n"
        f"  late:  {analysis['rms_curve']['late']}\n"
        f"  outro: {analysis['rms_curve']['outro']}\n\n"
        f"Propose tag values per the schema. Return ONLY a JSON object."
    )

    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=1500,
        system=system,
        messages=[{"role": "user", "content": user_text}],
    )

    text = next(b.text for b in response.content if b.type == "text").strip()
    # Strip code fences if the model added them despite instructions.
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)
    return json.loads(text)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Tag an audio track for the DirectorSeat music library."
    )
    parser.add_argument("audio_file", type=Path, help="Path to the audio file (.mp3, .wav, .flac, etc.)")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path(__file__).parent / "tags",
        help="Where to write the tag JSON. Defaults to ./tags/.",
    )
    parser.add_argument(
        "--source-url",
        type=str,
        default="",
        help="URL the track was downloaded from (for license traceability).",
    )
    args = parser.parse_args()

    if not args.audio_file.exists():
        sys.exit(f"Error: file not found: {args.audio_file}")

    args.output_dir.mkdir(parents=True, exist_ok=True)

    print(f"Analyzing {args.audio_file.name}...", file=sys.stderr)
    analysis = analyze_audio(args.audio_file)
    print(
        f"  duration={analysis['duration_seconds']}s  "
        f"tempo={analysis['tempo_bpm_estimate']} BPM  "
        f"DR={analysis['dynamic_range_db']} dB",
        file=sys.stderr,
    )
    print(f"  RMS curve: {analysis['rms_curve']}", file=sys.stderr)

    track_id = slugify(args.audio_file.stem)

    output: dict = {
        "_review_needed": True,
        "id": track_id,
        "source_url": args.source_url,
        "duration_seconds": analysis["duration_seconds"],
        "_analysis": analysis,
    }

    if os.environ.get("ANTHROPIC_API_KEY"):
        print("Calling Claude Sonnet 4.6 for tag proposals...", file=sys.stderr)
        try:
            llm_tags = call_claude(args.audio_file.name, analysis)
            output.update(llm_tags)
            print("  LLM proposals received.", file=sys.stderr)
        except Exception as e:
            print(f"  LLM call failed: {type(e).__name__}: {e}", file=sys.stderr)
            output["_local_only"] = True
            output["_llm_error"] = f"{type(e).__name__}: {e}"
            _populate_local_only_placeholders(output, args.audio_file)
    else:
        print(
            "ANTHROPIC_API_KEY not set — outputting local analysis only. "
            "Set the env var and re-run, or fill the LLM fields by hand.",
            file=sys.stderr,
        )
        output["_local_only"] = True
        _populate_local_only_placeholders(output, args.audio_file)

    output_path = args.output_dir / f"{track_id}.json"
    output_path.write_text(json.dumps(output, indent=2) + "\n")
    print(f"\nWrote {output_path}", file=sys.stderr)
    print(
        "  _review_needed=true. After reviewing/editing the JSON, flip it to "
        "false (or delete the field) so build_database.py picks it up.",
        file=sys.stderr,
    )


def _populate_local_only_placeholders(output: dict, audio_file: Path) -> None:
    """Fill the LLM-derived fields with null placeholders so the JSON is well-formed."""
    output.setdefault(
        "title",
        audio_file.stem.replace("-", " ").replace("_", " ").title(),
    )
    output.setdefault("artist", "Unknown")
    output.setdefault("license", "Unknown")
    output.setdefault("mood_primary", None)
    output.setdefault("mood_secondary", None)
    output.setdefault("tempo_bucket", None)
    output.setdefault("intensity", None)
    output.setdefault("instrumentation", None)
    output.setdefault("recommended_for", [])
    output.setdefault("avoid_for", [])
    output.setdefault("loop_friendly", None)
    output.setdefault("has_clear_arc", None)


if __name__ == "__main__":
    main()
