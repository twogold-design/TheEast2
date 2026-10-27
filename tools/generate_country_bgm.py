"""Compose Country Meadow: an original, quiet acoustic-country-style loop.

All sound is synthesized with NumPy; these are not recordings of instruments.
No network, samples, external sound banks, or borrowed melody. Guitar gestures,
alternating root/fifth bass, brushes and sparse double-course answers give a
country feel while leaving room for game effects. Fixed seed, circular tails.
"""
from __future__ import annotations

import argparse
import json
import math
import wave
from pathlib import Path

import numpy as np

RATE = 44100
BPM = 92
BEAT = 60.0 / BPM
BARS = 40
LENGTH = round(BARS * 4 * BEAT * RATE)
RNG = np.random.default_rng(20261022)


def hz(midi: int) -> float:
    return 440.0 * 2 ** ((midi - 69) / 12)


def string(midi: int, duration=2.6, kind="guitar") -> np.ndarray:
    """Damped string partials with pick-position comb and wooden resonance.

    Double-course mandolin uses independently detuned string phases; there is
    no sustained sine/flute lead. Upper partials decay faster than fundamentals.
    """
    t = np.arange(round(duration * RATE), dtype=np.float64) / RATE
    f = hz(midi)
    y = np.zeros_like(t)
    bass = kind == "bass"
    mandolin = kind == "mandolin"
    courses = [-0.0018, 0.0018] if mandolin else [0.0]
    pick = 0.23 if mandolin else (0.32 if bass else 0.19)
    for detune in courses:
        for k in range(1, 20 if not bass else 10):
            frequency = f * k * (1 + detune) * math.sqrt(1 + 0.000015 * k * k)
            if frequency > 8200:
                break
            amp = math.sin(k * math.pi * pick) / k ** (1.15 if mandolin else 1.34)
            # Broad acoustic body resonances rather than an electronic whistle.
            amp *= 0.8 + 0.3 * math.exp(-((frequency - 190) / 95) ** 2)
            amp *= math.exp(-frequency / (4900 if mandolin else 3300))
            decay = (0.63 if mandolin else (0.85 if bass else 1.25)) / (1 + k * 0.18)
            phase = float(RNG.uniform(-0.10, 0.10))
            y += amp * np.cos(2 * math.pi * frequency * t + phase) * np.exp(-t / decay) / len(courses)
    noise = RNG.normal(0, 1, len(t))
    noise = np.convolve(noise, np.ones(9) / 9, mode="same")
    y += 0.035 * noise * np.exp(-t / 0.035)
    # A very short, quiet wooden body transient joins the pluck attack.
    y += 0.045 * np.sin(2 * np.pi * (110 if bass else 185) * t) * np.exp(-t / 0.035)
    attack = 0.007 if mandolin else 0.009
    y *= (1 - np.exp(-t / attack)) * np.clip((duration - t) / 0.10, 0, 1)
    return y.astype(np.float32)


def brush(accent=False) -> np.ndarray:
    t = np.arange(round(RATE * 0.23), dtype=np.float64) / RATE
    raw = RNG.normal(0, 1, len(t))
    softened = np.convolve(raw, np.ones(7) / 7, mode="same")
    low = np.convolve(softened, np.ones(65) / 65, mode="same")
    sound = (softened - low) * 0.35
    if accent:
        sound += 0.07 * np.sin(2 * np.pi * 165 * t) * np.exp(-t / 0.035)
    return (sound * (1 - np.exp(-t / 0.012)) * np.exp(-t / (0.075 if accent else 0.045))).astype(np.float32)


def place(bus: np.ndarray, tone: np.ndarray, beat: float, gain: float, pan: float) -> None:
    start = round(beat * BEAT * RATE) % LENGTH
    stereo = tone[:, None] * np.array([math.cos((pan + 1) * math.pi / 4),
                                      math.sin((pan + 1) * math.pi / 4)], np.float32) * gain
    first = min(len(tone), LENGTH - start)
    bus[start:start + first] += stereo[:first]
    if first < len(tone):
        bus[:len(tone) - first] += stereo[first:]


def compose() -> tuple[np.ndarray, dict]:
    global RNG
    RNG = np.random.default_rng(20261022)
    mix = np.zeros((LENGTH, 2), np.float32)
    # G major; five 8-bar sentences, with an Em middle and a D->G loop cadence.
    voicings = {
        "G": (31, 38, [43, 47, 50, 55, 59, 62]),
        "C": (36, 43, [48, 52, 55, 60, 64]),
        "D": (38, 33, [45, 50, 54, 57, 62, 66]),
        "E": (28, 35, [40, 47, 52, 55, 59, 64]),
        "A": (33, 40, [45, 48, 52, 57, 60, 64]),
    }
    harmony = list("GGCCGGDD" "GGCECDGG" "EECCGADD" "GCGEC DGG".replace(" ", "") + "CCGGECDD")
    assert len(harmony) == BARS
    guitar_notes = bass_notes = strums = brush_hits = 0
    for bar, chord in enumerate(harmony):
        root, fifth, notes = voicings[chord]
        phrase = bar // 8
        # Slight shuffle, and tiny deterministic player timing/velocity changes.
        for beat, pitch in [(0, root), (2, fifth)]:
            place(mix, string(pitch, 1.9, "bass"), bar * 4 + beat + 0.015,
                  0.24 * float(RNG.uniform(0.94, 1.04)), 0.02)
            bass_notes += 1
        arpeggio = [(0.03, 0), (0.56, 2), (1.02, 3), (1.57, 4),
                    (2.02, 1), (2.56, 3), (3.03, 2), (3.57, 4)]
        if phrase == 2:
            arpeggio = [(0.03, 0), (0.58, 3), (1.57, 4), (2.02, 1), (2.57, 2), (3.57, 4)]
        for beat, degree in arpeggio:
            gain = (0.15 if degree <= 1 else 0.125) * float(RNG.uniform(0.9, 1.06))
            place(mix, string(notes[degree], 2.7), bar * 4 + beat + float(RNG.uniform(-0.013, 0.013)), gain, -0.25)
            guitar_notes += 1
        # Quiet backbeat strums: successive strings, not a piano-like chord hit.
        for beat in [1.04, 3.04]:
            chosen = notes[1:] if beat < 2 else list(reversed(notes[2:]))
            for index, pitch in enumerate(chosen):
                place(mix, string(pitch, 1.45), bar * 4 + beat + index * 0.019,
                      (0.042 if phrase == 2 else 0.055) * float(RNG.uniform(0.9, 1.05)), 0.32)
            strums += 1
        for beat in [0.56, 1.02, 1.56, 2.56, 3.02, 3.56]:
            accent = abs(beat - round(beat)) < 0.1
            place(mix, brush(accent), bar * 4 + beat, 0.11 if accent else 0.045, 0.1)
            brush_hits += 1

    # New low-register, rest-rich answering figures. They emerge at sentence
    # ends instead of carrying a persistent lead. Entirely original note data.
    answers = [
        (2, 2.54, 64), (2, 3.05, 67), (2, 3.57, 64), (3, 0.10, 60),
        (6, 2.55, 62), (6, 3.08, 66), (7, 0.08, 69), (7, 1.58, 66),
        (10, 2.55, 67), (10, 3.08, 64), (11, 0.08, 59), (11, 1.56, 62),
        (14, 2.58, 62), (14, 3.08, 59), (15, 0.08, 55),
        (18, 2.55, 64), (18, 3.08, 67), (19, 0.08, 69), (19, 1.56, 67),
        (22, 2.55, 64), (22, 3.08, 60), (23, 0.08, 62),
        (26, 2.55, 62), (26, 3.08, 67), (27, 0.08, 64),
        (30, 2.56, 59), (30, 3.08, 62), (31, 0.08, 67),
        (34, 2.55, 62), (34, 3.08, 59), (35, 0.08, 55),
        (38, 2.55, 64), (38, 3.08, 62), (39, 0.08, 66), (39, 1.55, 62),
    ]
    for bar, beat, pitch in answers:
        place(mix, string(pitch, 1.8, "mandolin"), bar * 4 + beat, 0.12, 0.46)

    # Modest circular room reflections preserve natural-decay energy at wrap.
    wet = np.zeros_like(mix)
    for seconds, gain in [(0.047, .095), (.083, .065), (.137, .047), (.211, .029), (.323, .019)]:
        wet += np.roll(mix[:, ::-1], round(seconds * RATE), axis=0) * gain
    audio = mix + wet
    audio -= audio.mean(axis=0, keepdims=True)
    audio = np.tanh(audio * 1.15)
    rms = float(np.sqrt(np.mean(audio.astype(np.float64) ** 2)))
    peak = float(np.max(np.abs(audio)))
    audio *= min(10 ** (-3 / 20) / peak, 10 ** (-22 / 20) / rms)
    step = np.abs(audio[0] - audio[-1])
    stats = {
        "title": "田野小路 / Country Meadow", "original_composition": True,
        "sound_source": "Original NumPy-synthesized acoustic-style instruments; no real instrument recordings or external samples",
        "sample_rate": RATE, "channels": 2, "bars": BARS, "bpm": BPM,
        "duration_seconds": LENGTH / RATE, "samples": LENGTH,
        "peak_dbfs": round(20 * math.log10(float(np.max(np.abs(audio)))), 3),
        "rms_dbfs": round(20 * math.log10(float(np.sqrt(np.mean(audio.astype(np.float64) ** 2)))), 3),
        "loop_boundary_step": step.tolist(),
        "adjacent_step_99_9_percentile": float(np.percentile(np.abs(np.diff(audio, axis=0)), 99.9)),
        "first_half_second_rms": float(np.sqrt(np.mean(audio[:RATE // 2] ** 2))),
        "last_half_second_rms": float(np.sqrt(np.mean(audio[-RATE // 2:] ** 2))),
        "guitar_arpeggio_notes": guitar_notes, "guitar_strums": strums,
        "alternating_bass_notes": bass_notes, "brush_hits": brush_hits,
        "mandolin_answer_notes": len(answers),
    }
    assert stats["peak_dbfs"] <= -3
    assert float(np.max(step)) < stats["adjacent_step_99_9_percentile"]
    return audio, stats


def write_wav(path: Path, audio: np.ndarray, dither=True) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if dither:
        audio = audio + (RNG.random(audio.shape, dtype=np.float32) - RNG.random(audio.shape, dtype=np.float32)) / 65536
    pcm = np.clip(np.rint(audio * 32767), -32768, 32767).astype("<i2")
    with wave.open(str(path), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=root / "godot/assets/audio/country_meadow.wav")
    parser.add_argument("--preview", type=Path, default=root / "qa/bgm/country-preview.wav")
    parser.add_argument("--stats", type=Path, default=root / "qa/bgm/country_meadow_stats.json")
    args = parser.parse_args()
    audio, stats = compose()
    write_wav(args.output, audio)
    preview = audio[:20 * RATE].copy()
    fade = round(RATE * 0.15)
    preview[:fade] *= np.linspace(0, 1, fade, dtype=np.float32)[:, None]
    preview[-fade:] *= np.linspace(1, 0, fade, dtype=np.float32)[:, None]
    write_wav(args.preview, preview)
    args.stats.parent.mkdir(parents=True, exist_ok=True)
    args.stats.write_text(json.dumps(stats, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(stats, ensure_ascii=False, indent=2))
    print(f"Wrote {args.output} ({args.output.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
