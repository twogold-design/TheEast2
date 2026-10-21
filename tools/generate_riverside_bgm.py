"""Rebuild the original Riverside Day score with NumPy and the Python standard library.

No recordings, network requests, external sound banks or copyrighted melodies are used.
The simulated plucked strings/flute are an interpretation, not acoustic recordings.
Every note/reverb tail wraps around a fixed 32-bar buffer for seamless playback.
"""
from __future__ import annotations

import argparse
import json
import math
import wave
from pathlib import Path

import numpy as np

RATE = 44100
BPM = 76
BEAT = 60.0 / BPM
BARS = 32
LENGTH = round(BARS * 4 * BEAT * RATE)
RNG = np.random.default_rng(271828)


def hz(midi: int) -> float:
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


def pluck(midi: int, length: float, mellow: bool = False) -> np.ndarray:
    """Decaying inharmonic string modes, rounded attack and a quiet wooden transient."""
    t = np.arange(round(length * RATE), dtype=np.float64) / RATE
    f = hz(midi)
    y = np.zeros_like(t)
    for k in range(1, 12):
        stiffness = math.sqrt(1.0 + 0.000065 * k * k)
        decay = (2.05 if mellow else 1.8) / (1.0 + k * 0.23)
        amplitude = 1.0 / k ** (1.72 if mellow else 1.42)
        amplitude *= math.exp(-k / (4.5 if mellow else 7.0))
        y += amplitude * np.sin(2 * np.pi * f * k * stiffness * t) * np.exp(-t / decay)
    noise = RNG.normal(0, 1, len(t))
    noise = np.convolve(noise, np.ones(13) / 13, mode="same")
    y += noise * 0.022 * np.exp(-t / 0.024)
    y *= (1 - np.exp(-t / 0.009)) * np.minimum(1.0, (length - t) / 0.07)
    return y.astype(np.float32)


def flute(midi: int, beats: float) -> np.ndarray:
    """Soft breath tone with restrained delayed vibrato and a shaped human phrase."""
    duration = beats * BEAT
    length = duration + 0.45
    t = np.arange(round(length * RATE), dtype=np.float64) / RATE
    vibrato = 0.0018 * np.sin(2 * np.pi * 4.3 * t) * np.clip((t - 0.24) / 0.7, 0, 1)
    # Integrating instantaneous frequency avoids an increasing vibrato excursion.
    phase = np.cumsum(hz(midi) * (1 + vibrato)) * (2 * np.pi / RATE)
    y = np.sin(phase) + 0.16 * np.sin(2 * phase + 0.1) + 0.045 * np.sin(3 * phase)
    breath = np.convolve(RNG.normal(0, 1, len(t)), np.ones(11) / 11, mode="same")
    y += breath * 0.042
    attack = np.clip(t / 0.12, 0, 1)
    release = np.clip((length - t) / 0.48, 0, 1)
    shape = (0.88 + 0.12 * np.sin(np.pi * np.clip(t / duration, 0, 1)))
    return (y * attack * release * shape).astype(np.float32)


def cushion(midi: int, beats: float) -> np.ndarray:
    duration = beats * BEAT
    length = duration + 1.25
    t = np.arange(round(length * RATE), dtype=np.float64) / RATE
    f = hz(midi)
    y = 0.48 * np.sin(2 * np.pi * f * t)
    y += 0.27 * np.sin(2 * np.pi * f * 1.0012 * t + 0.5)
    y += 0.12 * np.sin(2 * np.pi * f * 2 * t + 0.3)
    envelope = np.minimum(np.clip(t / 0.8, 0, 1), np.clip((length - t) / 1.3, 0, 1))
    return (y * envelope).astype(np.float32)


def place(bus: np.ndarray, tone: np.ndarray, beat: float, gain: float, pan: float) -> None:
    start = round(beat * BEAT * RATE) % LENGTH
    stereo = tone[:, None] * np.array([
        math.cos((pan + 1) * math.pi / 4),
        math.sin((pan + 1) * math.pi / 4),
    ], dtype=np.float32)[None, :] * gain
    first = min(len(tone), LENGTH - start)
    bus[start:start + first] += stereo[:first]
    if first < len(tone):
        bus[:len(tone) - first] += stereo[first:]


def compose() -> tuple[np.ndarray, dict]:
    dry = np.zeros((LENGTH, 2), dtype=np.float32)
    # In D: D(add9), Bm7, Gmaj9, A(sus/add6). The accompaniment changes every bar.
    voicings = {
        "D": (38, [57, 62, 66, 69, 74]),
        "B": (35, [57, 62, 66, 71, 74]),
        "G": (31, [55, 59, 62, 66, 69]),
        "A": (33, [57, 61, 64, 69, 71]),
        "E": (40, [55, 59, 64, 66, 71]),
    }
    harmony = list("DD B G D B G A".replace(" ", ""))
    harmony += list("DBGD B E A A".replace(" ", ""))
    harmony += list("G G D B E G A A".replace(" ", ""))
    harmony += list("D B G D E A G D".replace(" ", ""))
    assert len(harmony) == BARS
    patterns = [
        [(0.18, 0), (1.30, 2), (2.05, 1), (3.20, 3)],
        [(0.28, 1), (1.75, 2), (2.70, 4)],
        [(0.10, 0), (1.15, 3), (2.35, 2), (3.45, 4)],
        [(0.30, 1), (1.65, 2), (2.60, 3)],
    ]
    for bar, chord in enumerate(harmony):
        root, notes = voicings[chord]
        place(dry, pluck(root + 12, 4.9, True), bar * 4 + 0.02, 0.16, -0.06)
        # A nearly inaudible sustained bed connects phrases without swelling over the melody.
        for n, pan in zip([notes[0], notes[1], notes[2]], [-0.55, 0.3, 0.6]):
            place(dry, cushion(n - 12, 4.0), bar * 4 + 0.08, 0.016, pan)
        for beat, degree in patterns[(bar + bar // 8) % 4]:
            jitter = float(RNG.uniform(-0.030, 0.030))
            pan = -0.40 if degree % 2 == 0 else 0.35
            gain = float(RNG.uniform(0.105, 0.13))
            place(dry, pluck(notes[degree], 4.2), bar * 4 + beat + jitter, gain, pan)
        if bar in [3, 7, 11, 15, 19, 23, 27, 31]:
            # An unhurried descending response closes each four-bar sentence.
            for beat, pitch in zip([2.30, 2.96, 3.46], [notes[4], notes[3], notes[1]]):
                place(dry, pluck(pitch, 4.0), bar * 4 + beat, 0.075, -0.22)

    # Four eight-bar sentences with rests: statement, variation, lifted middle, return.
    # (bar, beat, pitch, held beats), D major pentatonic. No existing tune was sampled.
    melody = [
        (0, .65, 74, 1.35), (0, 2.40, 78, 1.10),
        (1, .25, 81, 2.05), (1, 2.85, 78, .65),
        (2, .50, 76, 1.10), (2, 2.10, 74, 1.35),
        (4, .50, 78, 1.65), (4, 2.75, 81, .65),
        (5, .30, 83, 1.15), (5, 1.95, 81, 1.30),
        (6, .55, 78, 1.10), (6, 2.10, 76, 1.20),
        (7, .45, 74, 1.15),
        (8, .75, 74, .85), (8, 1.95, 76, .60), (8, 2.95, 78, .65),
        (9, .25, 81, 2.25),
        (10, .45, 83, 1.1), (10, 2.15, 81, 1.1),
        (12, .50, 78, 1.45), (12, 2.50, 76, .85),
        (13, .35, 74, 1.10), (13, 1.90, 76, 1.15),
        (14, .70, 81, 2.10),
        (16, .40, 83, 1.30), (16, 2.25, 86, 1.10),
        (17, .20, 83, 1.30), (17, 2.10, 81, 1.20),
        (18, .50, 81, 2.20),
        (20, .60, 78, .85), (20, 1.95, 81, 1.45),
        (21, .45, 83, 1.1), (21, 2.10, 81, 1.1),
        (22, .55, 78, 1.1), (22, 2.15, 76, 1.1),
        (24, .70, 74, 1.30), (24, 2.40, 78, 1.10),
        (25, .25, 81, 1.50), (25, 2.35, 78, 1.05),
        (26, .50, 76, 1.0), (26, 2.1, 74, 1.25),
        (28, .50, 78, 1.25), (28, 2.40, 76, .85),
        (29, .40, 74, 1.60),
        (30, .65, 71, 1.30), (30, 2.65, 74, 1.0),
    ]
    for bar, beat, pitch, hold in melody:
        # Upper register middle section is attenuated to stay gentle.
        gain = float(RNG.uniform(0.052, 0.060)) * (0.82 if pitch >= 83 else 1)
        place(dry, flute(pitch, hold), bar * 4 + beat, gain, 0.14)
    # Small chamber reflections, circular by construction: no tail cut at a loop seam.
    wet = np.zeros_like(dry)
    for delay, gain in [(0.113, .14), (.227, .09), (.389, .065), (.571, .045)]:
        wet += np.roll(dry[:, ::-1], round(delay * RATE), axis=0) * gain
    for i in range(28):
        delay = .16 + i * .079 + float(RNG.uniform(-.019, .019))
        tap = np.roll(dry, round(delay * RATE), axis=0)
        if i % 2:
            tap = tap[:, ::-1]
        wet += tap * (.023 * math.exp(-delay / .83))
    audio = dry + wet
    audio -= np.mean(audio, axis=0, keepdims=True)
    # Smooth saturation controls isolated pluck peaks without a pumping compressor.
    audio = np.tanh(audio * 1.1)
    peak = float(np.max(np.abs(audio)))
    rms = float(np.sqrt(np.mean(audio.astype(np.float64) ** 2)))
    scale = min(10 ** (-2.0 / 20) / peak, 10 ** (-21.5 / 20) / rms)
    audio *= scale
    stats = {
        "title": "水岸晴日 / Riverside Day", "original_composition": True,
        "sample_rate": RATE, "channels": 2, "bars": BARS, "bpm": BPM,
        "duration_seconds": LENGTH / RATE, "samples": LENGTH,
        "peak_dbfs": round(20 * math.log10(float(np.max(np.abs(audio)))), 3),
        "rms_dbfs": round(20 * math.log10(float(np.sqrt(np.mean(audio.astype(np.float64) ** 2)))), 3),
        "loop_boundary_step": [float(v) for v in np.abs(audio[0] - audio[-1])],
        "adjacent_step_99_9_percentile": float(np.percentile(np.abs(np.diff(audio, axis=0)), 99.9)),
        "first_half_second_rms": float(np.sqrt(np.mean(audio[:RATE // 2] ** 2))),
        "last_half_second_rms": float(np.sqrt(np.mean(audio[-RATE // 2:] ** 2))),
        "flute_notes": len(melody),
    }
    return audio, stats


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    root = Path(__file__).resolve().parents[1]
    parser.add_argument("--output", type=Path, default=root / "godot/assets/audio/riverside_day.wav")
    parser.add_argument("--stats", type=Path, default=root / ".godot-user/qa/riverside_day_stats.json")
    parser.add_argument("--preview", type=Path, help="Optional 20-second excerpt with short fades")
    args = parser.parse_args()
    audio, stats = compose()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    # Deterministic TPDF dither prevents low-level quantization distortion.
    dither = (RNG.random(audio.shape, dtype=np.float32) - RNG.random(audio.shape, dtype=np.float32)) / 65536
    pcm = np.clip(np.rint((audio + dither) * 32767), -32768, 32767).astype("<i2")
    with wave.open(str(args.output), "wb") as out:
        out.setnchannels(2)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(pcm.tobytes())
    args.stats.parent.mkdir(parents=True, exist_ok=True)
    args.stats.write_text(json.dumps(stats, ensure_ascii=False, indent=2), encoding="utf-8")
    if args.preview:
        excerpt = audio[:20 * RATE].copy()
        fade = round(0.15 * RATE)
        excerpt[:fade] *= np.linspace(0, 1, fade, dtype=np.float32)[:, None]
        excerpt[-fade:] *= np.linspace(1, 0, fade, dtype=np.float32)[:, None]
        args.preview.parent.mkdir(parents=True, exist_ok=True)
        with wave.open(str(args.preview), "wb") as out:
            out.setnchannels(2)
            out.setsampwidth(2)
            out.setframerate(RATE)
            out.writeframes(np.rint(excerpt * 32767).astype("<i2").tobytes())
    print(json.dumps(stats, ensure_ascii=False, indent=2))
    print(f"Wrote {args.output} ({args.output.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
