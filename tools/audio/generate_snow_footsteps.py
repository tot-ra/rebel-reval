#!/usr/bin/env python3
"""Synthesise the snow footstep pool (ADR 0045, snow footprints task).

Why synthesis: the footstep pools are CC0 recordings (R-1641), but no cleared
CC0 snow-crunch recording is in the repository and this clip family is the one
place where a procedural model is convincing: dry snow under a boot is a
cloud of tiny ice-crystal fractures. Each step is

  - a soft low "press" (low-passed noise, 4 ms attack, ~110 ms decay): the
    snowpack settling under the weight of the foot;
  - 90-260 crystal grains scattered over the first ~280 ms, denser at the
    start: each grain is a 1-3 ms damped sinusoid at 1.8-6.5 kHz with a
    log-normal level, which together read as a crunch.

Six deterministic variations (seeded), mono 44.1 kHz, 80 Hz high-passed,
levelled so the loudest 50 ms window sits at -17 dBFS (a step in snow is
quieter than a heel on flagstone), encoded as 128 kbps MP3 like every pool.
The output is original project work (AGPL-3.0-or-later, project author).

Usage:
    python3 tools/audio/generate_snow_footsteps.py
    python3 tools/audio/generate_snow_footsteps.py --print-sources
"""

from __future__ import annotations

import argparse
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

RATE = 44100
OUT_DIR = Path("sounds/footsteps")
VARIATIONS = 6
TARGET_DBFS = -17.0
PEAK_CAP_DBFS = -3.0


def _grain(rng: np.random.Generator, length: int) -> np.ndarray:
    n = np.arange(length)
    freq = rng.uniform(1800.0, 6500.0)
    tau = rng.uniform(0.001, 0.003) * RATE
    return np.exp(-n / tau) * np.sin(2.0 * np.pi * freq * n / RATE + rng.uniform(0, 6.28))


def synth_step(seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    duration = rng.uniform(0.30, 0.42)
    total = int(duration * RATE)
    out = np.zeros(total)
    # The press: low-passed noise with a fast attack and a ~110 ms decay.
    noise = rng.standard_normal(total)
    kernel = np.ones(24) / 24.0
    low = np.convolve(noise, kernel, mode="same")
    t = np.arange(total) / RATE
    press_env = (1.0 - np.exp(-t / 0.004)) * np.exp(-t / rng.uniform(0.08, 0.13))
    out += low * press_env * 2.2
    # The crunch: crystal grains, denser at the start of the step.
    grains = int(rng.integers(90, 260))
    span = rng.uniform(0.2, 0.3)
    for _ in range(grains):
        onset = 0.006 + span * rng.random() ** 1.9
        start = int(onset * RATE)
        glen = int(0.014 * RATE)
        if start + glen >= total:
            continue
        level = float(rng.lognormal(mean=-1.6, sigma=0.75))
        out[start : start + glen] += level * _grain(rng, glen)
    # A rare squeak of dry cold snow: a short rising whistle.
    if rng.random() < 0.35:
        s0 = int(rng.uniform(0.03, 0.12) * RATE)
        sl = int(rng.uniform(0.04, 0.09) * RATE)
        if s0 + sl < total:
            u = np.arange(sl)
            freq = np.linspace(2100.0, 2900.0, sl)
            phase = 2.0 * np.pi * np.cumsum(freq) / RATE
            out[s0 : s0 + sl] += 0.12 * np.sin(phase) * np.sin(np.pi * u / sl)
    # Fade out over the last 35 %.
    fade = np.ones(total)
    cut = int(total * 0.65)
    fade[cut:] = np.linspace(1.0, 0.0, total - cut) ** 1.5
    return out * fade


def level(step: np.ndarray) -> np.ndarray:
    window = int(0.05 * RATE)
    energy = np.convolve(step * step, np.ones(window) / window, mode="valid")
    loudest = float(np.sqrt(energy.max()) + 1e-9)
    gain = 10 ** (TARGET_DBFS / 20.0) / loudest
    peak_cap = 10 ** (PEAK_CAP_DBFS / 20.0) / (float(np.abs(step).max()) + 1e-9)
    return step * min(gain, peak_cap)


def write_mp3(samples: np.ndarray, path: Path) -> None:
    pcm = (np.clip(samples, -1.0, 1.0) * 32767.0).astype(np.int16)
    with tempfile.TemporaryDirectory() as tmp:
        wav_path = Path(tmp) / "step.wav"
        with wave.open(str(wav_path), "wb") as wav:
            wav.setnchannels(1)
            wav.setsampwidth(2)
            wav.setframerate(RATE)
            wav.writeframes(pcm.tobytes())
        subprocess.run(
            [
                "ffmpeg", "-y", "-loglevel", "error", "-i", str(wav_path),
                "-af", "highpass=f=80", "-ac", "1", "-ar", str(RATE),
                "-codec:a", "libmp3lame", "-b:a", "128k", str(path),
            ],
            check=True,
        )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--print-sources", action="store_true")
    args = parser.parse_args()
    for index in range(1, VARIATIONS + 1):
        path = OUT_DIR / f"snow_step_{index:02d}.mp3"
        if args.print_sources:
            print(
                f"sounds.footsteps.snow_step_{index:02d},{path.as_posix()},"
                "project maintainer (procedural synthesis),"
                "tools/audio/generate_snow_footsteps.py,"
                "numpy damped-grain model; no external audio,"
                f"{9100 + index},AGPL-3.0-or-later (project author),"
                f"\"Snow footstep {index}: press plus crystal grains; mono 44.1 kHz; 80 Hz "
                "high-pass; loudest 50 ms at -17 dBFS; 128 kbps MP3.\","
                "approved - procedural SFX (ADR 0045)"
            )
            continue
        write_mp3(level(synth_step(9100 + index)), path)
        print("wrote", path)


if __name__ == "__main__":
    main()
