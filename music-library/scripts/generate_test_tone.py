#!/usr/bin/env python3
"""Generate a 5-second test audio file so the tagging pipeline can be smoke-tested
without a real track.

Output is a slow ambient pad: a 220 Hz sine with a slight tremolo, fading in
over the first second and fading out over the last second. This produces a
flat-ish RMS curve that should bucket as ambient/loopable in the analysis,
giving the LLM (or local fallback) a sensible reasoning target.
"""

from pathlib import Path
import numpy as np
import soundfile as sf

SAMPLE_RATE = 44100
DURATION_S = 5.0
FREQ_HZ = 220.0
TREMOLO_HZ = 4.0
TREMOLO_DEPTH = 0.15  # ±15% amplitude wobble


def main() -> None:
    n = int(SAMPLE_RATE * DURATION_S)
    t = np.linspace(0.0, DURATION_S, n, endpoint=False, dtype=np.float64)

    # Carrier
    sine = np.sin(2 * np.pi * FREQ_HZ * t)

    # Tremolo (slow amplitude modulation — gives the analysis a non-flat texture)
    tremolo = 1.0 - TREMOLO_DEPTH + TREMOLO_DEPTH * np.sin(2 * np.pi * TREMOLO_HZ * t)
    signal = sine * tremolo * 0.6  # leave headroom

    # 1-second fade-in and fade-out so RMS curve has 'low' intro/outro and
    # 'medium' middle — a real ambient pad shape.
    fade_samples = int(1.0 * SAMPLE_RATE)
    fade_in = np.linspace(0.0, 1.0, fade_samples)
    fade_out = np.linspace(1.0, 0.0, fade_samples)
    signal[:fade_samples] *= fade_in
    signal[-fade_samples:] *= fade_out

    out_path = Path(__file__).parent.parent / "raw" / "ambient" / "test-ambient-pad.wav"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    sf.write(str(out_path), signal.astype(np.float32), SAMPLE_RATE)
    print(f"Wrote {out_path} ({DURATION_S}s, {SAMPLE_RATE} Hz)")


if __name__ == "__main__":
    main()
