#!/usr/bin/env python3
"""Build the footstep one-shot pools from CC0 Foley recordings (R-1641).

Why: the first footstep pools were placeholders - two pools cut from AI walk
cycles and four synthesised from shaped noise (R-1382, R-1383). Listeners
classify the surface type of a step reliably, and a noise burst reads as noise,
not as a boot on cobbles. Every pool is now a real recording of one step.

Material:
- Kenney "Impact Sounds" (CC0): wood, concrete and grass steps that already
  ship as single one-shots; they are only mixed to mono and levelled.
- Freesound HQ previews (CC0): continuous walks on gravel, packed dirt, mud,
  a puddle, shallow water and knee-deep wading, plus a swimmer's strokes
  (R-1648; the stroke pool rides along because it is cut the same way). Single steps are cut out at fixed offsets
  (constants below, picked as strong onsets with a clean gap to the next step).

Each clip is mono (the pools play through AudioStreamPlayer3D, where a baked
stereo image fights positional panning), high-passed, faded in over 3 ms and
out over its tail, then levelled so the loudest 50 ms window sits at the pool's
target. Targets differ per surface on purpose: a step on grass is quieter than
a heel on flagstone, and levelling them equal would sound wrong.

Sources are cached under build/audio_sources/ (gitignored) and verified by
sha256, so regeneration is reproducible offline once cached.

Usage:
    python3 tools/audio/build_footstep_pools.py
    python3 tools/audio/build_footstep_pools.py --print-sources
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import subprocess
import sys
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CACHE_DIR = ROOT / "build" / "audio_sources"
OUT_DIR = ROOT / "sounds" / "footsteps"
SAMPLE_RATE = 44100
AUDIO_BITRATE = "128k"
USER_AGENT = "rebel-reval/r1641-footstep-pools"
CC0 = "https://creativecommons.org/publicdomain/zero/1.0/"
TASK = "R-1641"
# Leading context kept before a detected onset, so the attack is never clipped.
PRE_ROLL = 0.012
FADE_IN = 0.003
PEAK_CEILING_DB = -3.0

SOURCES = {
    "kenney_impact": {
        "kind": "zip",
        "title": "Impact Sounds (footstep set)",
        "author": "Kenney",
        "page": "https://kenney.nl/assets/impact-sounds",
        "url": "https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip",
        "sha256": "029d734af1582474edf3a694d1b0cebc97c1c152f2f39fa34d4c2bafc5de77f8",
        "cache": "kenney_impact-sounds.zip",
    },
    "fs_401345": {
        "kind": "preview",
        "title": "SFX_Steps_Gravel_Walk",
        "author": "GiocoSound",
        "fs_id": 401345,
        "page": "https://freesound.org/people/GiocoSound/sounds/401345/",
        "url": "https://cdn.freesound.org/previews/401/401345_5820033-hq.mp3",
    },
    "fs_264469": {
        "kind": "preview",
        "title": "Footsteps Dirt 01",
        "author": "aglinder",
        "fs_id": 264469,
        "page": "https://freesound.org/people/aglinder/sounds/264469/",
        "url": "https://cdn.freesound.org/previews/264/264469_1042839-hq.mp3",
    },
    "fs_488068": {
        "kind": "preview",
        "title": "Footsteps_Mud_01",
        "author": "BenDrain",
        "fs_id": 488068,
        "page": "https://freesound.org/people/BenDrain/sounds/488068/",
        "url": "https://cdn.freesound.org/previews/488/488068_4763661-hq.mp3",
    },
    "fs_488069": {
        "kind": "preview",
        "title": "Footsteps_Mud_02",
        "author": "BenDrain",
        "fs_id": 488069,
        "page": "https://freesound.org/people/BenDrain/sounds/488069/",
        "url": "https://cdn.freesound.org/previews/488/488069_4763661-hq.mp3",
    },
    "fs_106395": {
        "kind": "preview",
        "title": "puddlewalk",
        "author": "j1987",
        "fs_id": 106395,
        "page": "https://freesound.org/people/j1987/sounds/106395/",
        "url": "https://cdn.freesound.org/previews/106/106395_367313-hq.mp3",
    },
    "fs_861369": {
        "kind": "preview",
        "title": "Splashing Footsteps Shallow Water",
        "author": "ChristopherJngs",
        "fs_id": 861369,
        "page": "https://freesound.org/people/ChristopherJngs/sounds/861369/",
        "url": "https://cdn.freesound.org/previews/861/861369_8154783-hq.mp3",
    },
    "fs_265582": {
        "kind": "preview",
        "title": "Footsteps Water 01",
        "author": "aglinder",
        "fs_id": 265582,
        "page": "https://freesound.org/people/aglinder/sounds/265582/",
        "url": "https://cdn.freesound.org/previews/265/265582_1042839-hq.mp3",
    },
    "fs_342932": {
        "kind": "preview",
        "title": "Wading in Shallow Water",
        "author": "ryansitz",
        "fs_id": 342932,
        "page": "https://freesound.org/people/ryansitz/sounds/342932/",
        "url": "https://cdn.freesound.org/previews/342/342932_5800259-hq.mp3",
    },
    "fs_438845": {
        "kind": "preview",
        "title": "G54-26-Person Swimming",
        "author": "craigsmith",
        "fs_id": 438845,
        "page": "https://freesound.org/people/craigsmith/sounds/438845/",
        "url": "https://cdn.freesound.org/previews/438/438845_2524442-hq.mp3",
    },
}

# Freesound preview digests, pinned so a changed CDN file fails loudly instead
# of silently changing the pools.
PREVIEW_SHA256 = {
    "fs_401345": "30f3b33063d2175086627181d8e74f1bd773ec548528da5dc1d82d925bcc145a",
    "fs_264469": "3fff403aa63a5b50f5d0143afaa74e231b5c946adfb861318737ddd518f464ea",
    "fs_488068": "a90bbfbb1678b5de2051a079d293701278f57c6b952accf445b1806c96328185",
    "fs_488069": "7cb74c4434df8743977875c40331edb60943dda77255f4594c73c7463e3a0ec8",
    "fs_106395": "e149bb9ed789cc1f441c32f10ac31af6f13de2221cb70e4d046e4a2233058f97",
    "fs_861369": "f9f67010299d84663bdaca507e1a9696fa2e659311c852db3d5e2b8b155c99e3",
    "fs_265582": "6a6bd7bb2ee0c165c4b7293d707a0bc7591c01c4d78c9f419b7a84002d5ab1e5",
    "fs_342932": "45146fdb33646cb5ca73ada1058a9ed059d64a3339f633e78086b859ee6c7fa1",
    "fs_438845": "5bc55a68068331968f6d840323f91fff2ef6998fb85ac0d9ebeedaae01a113ad",
}

# surface -> (peak-window target dBFS, high-pass Hz, [(source, member or offset, length)])
# Kenney members are whole one-shots (length None = keep the file length).
POOLS = {
    "wood": (-14.0, 70, [("kenney_impact", f"Audio/footstep_wood_00{i}.ogg", None) for i in range(5)]),
    "stone": (
        -14.0,
        90,
        [("kenney_impact", f"Audio/footstep_concrete_00{i}.ogg", None) for i in range(5)],
    ),
    "grass": (-19.0, 90, [("kenney_impact", f"Audio/footstep_grass_00{i}.ogg", None) for i in range(5)]),
    "gravel": (
        -16.0,
        80,
        [
            ("fs_401345", 0.800, 0.38),
            ("fs_401345", 1.590, 0.38),
            ("fs_401345", 2.320, 0.38),
            ("fs_401345", 4.550, 0.38),
            ("fs_401345", 5.360, 0.38),
            ("fs_401345", 6.120, 0.38),
        ],
    ),
    "dirt": (
        -17.0,
        70,
        [
            ("fs_264469", 0.410, 0.36),
            ("fs_264469", 0.815, 0.36),
            ("fs_264469", 1.210, 0.40),
            ("fs_264469", 1.765, 0.40),
            ("fs_264469", 9.100, 0.40),
        ],
    ),
    "mud": (
        -16.0,
        60,
        [
            ("fs_488068", 0.175, 0.45),
            ("fs_488068", 1.945, 0.45),
            ("fs_488068", 4.265, 0.40),
            ("fs_488069", 1.025, 0.45),
            ("fs_488069", 3.420, 0.45),
            ("fs_488069", 4.195, 0.45),
        ],
    ),
    "puddle": (
        -14.0,
        60,
        [
            ("fs_106395", 1.325, 0.30),
            ("fs_106395", 2.950, 0.30),
            ("fs_861369", 0.705, 0.45),
            ("fs_861369", 1.480, 0.35),
            ("fs_861369", 3.945, 0.45),
            ("fs_861369", 7.425, 0.40),
        ],
    ),
    "water_shallow": (
        -14.0,
        50,
        [
            ("fs_265582", 0.435, 0.55),
            ("fs_265582", 1.725, 0.55),
            ("fs_265582", 4.640, 0.55),
            ("fs_265582", 5.330, 0.55),
            ("fs_265582", 7.465, 0.55),
            ("fs_265582", 9.320, 0.50),
        ],
    ),
    # R-1648: knee-deep and deeper. A leg pulled out of the water and pushed back
    # in is a long gurgling slosh, not the short slap of a puddle or ankle-deep
    # splash, so the cuts keep the plunge plus the other leg's lift after it.
    # The cuts are the low, long plunges (the short bright onsets between them
    # are the lift-outs). Quieter than a splash: the water damps the impact.
    "water_wade": (
        -16.0,
        70,
        [
            ("fs_342932", 3.900, 0.65),
            ("fs_342932", 4.890, 0.60),
            ("fs_342932", 12.510, 0.60),
            ("fs_342932", 13.700, 0.60),
            ("fs_342932", 15.580, 0.65),
            ("fs_342932", 16.710, 0.65),
            ("fs_342932", 18.970, 0.65),
            ("fs_342932", 21.600, 0.65),
        ],
    ),
    # R-1648: one arm pull of a crawl or a sculling sweep, played by the swimmer
    # presenter once per stroke (feet leave the bed, so no step plays). The
    # opening second of the source is a jump-in splash and is skipped.
    "swim": (
        -18.0,
        60,
        [
            ("fs_438845", 2.610, 0.80),
            ("fs_438845", 3.850, 0.80),
            ("fs_438845", 6.670, 0.80),
            ("fs_438845", 8.910, 0.80),
            ("fs_438845", 15.320, 0.80),
            ("fs_438845", 19.000, 0.80),
            ("fs_438845", 22.320, 0.80),
            ("fs_438845", 31.860, 0.80),
        ],
    ),
}

# Pools added after R-1641 carry their own task in the provenance rows.
POOL_TASKS = {"water_wade": "R-1648", "swim": "R-1648"}
# Swim strokes are not steps; every other pool is named <surface>_step_NN.
POOL_FILE_STEMS = {"swim": "swim_stroke"}


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _expected_sha(source_id: str) -> str:
    source = SOURCES[source_id]
    return source.get("sha256") or PREVIEW_SHA256.get(source_id, "")


def _ensure_source(source_id: str) -> Path:
    source = SOURCES[source_id]
    name = source.get("cache") or f"{source_id}.mp3"
    dest = CACHE_DIR / name
    if not dest.is_file():
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        request = urllib.request.Request(source["url"], headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(request, timeout=600) as response:
            dest.write_bytes(response.read())
    digest = _sha256(dest)
    expected = _expected_sha(source_id)
    if expected and digest != expected:
        raise RuntimeError(f"sha256 mismatch for {dest.name}: {digest}")
    return dest


def _decode(data_args: list[str], extra_filter: str) -> bytes:
    command = ["ffmpeg", "-hide_banner", "-loglevel", "error", *data_args]
    command += ["-af", extra_filter, "-ac", "1", "-ar", str(SAMPLE_RATE), "-f", "f32le", "-"]
    return subprocess.run(command, capture_output=True, check=True).stdout


def _peak_window_db(raw: bytes) -> tuple[float, float]:
    """Loudest 50 ms RMS window and the sample peak, both in dBFS."""
    import array
    import math

    samples = array.array("f")
    samples.frombytes(raw)
    window = int(SAMPLE_RATE * 0.05)
    hop = max(1, window // 4)
    best = 1e-12
    peak = 1e-12
    for value in samples:
        peak = max(peak, abs(value))
    for start in range(0, max(1, len(samples) - window), hop):
        chunk = samples[start : start + window]
        energy = sum(v * v for v in chunk) / max(1, len(chunk))
        best = max(best, energy)
    return 10.0 * math.log10(best), 20.0 * math.log10(peak)


def _clip_input(
    source_id: str, member: object, length: float | None
) -> tuple[list[str], str, float]:
    """ffmpeg input args, the trim filter prefix and the clip length in seconds."""
    path = _ensure_source(source_id)
    if SOURCES[source_id]["kind"] == "zip":
        tmp = CACHE_DIR / "kenney_members" / str(member)
        if not tmp.is_file():
            tmp.parent.mkdir(parents=True, exist_ok=True)
            with zipfile.ZipFile(path) as archive:
                tmp.write_bytes(archive.read(str(member)))
        probe = subprocess.run(
            ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(tmp)],
            capture_output=True, check=True, text=True,
        )
        return ["-i", str(tmp)], "", float(probe.stdout.strip())
    start = max(0.0, float(member) - PRE_ROLL)
    # Trim in the filter graph: input-side -ss lands up to a few hundred ms off
    # on these VBR previews and misses the step, and output-side -ss would run
    # after the fades.
    trim = f"atrim=start={start:.3f}:duration={length:.3f},asetpts=PTS-STARTPTS,"
    return ["-i", str(path)], trim, float(length)


def _shape_filter(highpass: int, length: float) -> str:
    # The tail fade covers the last 40 % so a cut never ends on a hard edge or
    # carries the next step's attack.
    fade_out = max(0.03, length * 0.4)
    return (
        f"highpass=f={highpass},afade=t=in:d={FADE_IN},"
        f"afade=t=out:st={max(0.0, length - fade_out):.3f}:d={fade_out:.3f}:curve=exp"
    )


def _clips() -> list[dict]:
    clips = []
    for surface, (target, highpass, members) in POOLS.items():
        for index, (source_id, member, length) in enumerate(members, start=1):
            clips.append(
                {
                    "surface": surface,
                    "index": index,
                    "target": target,
                    "highpass": highpass,
                    "source_id": source_id,
                    "member": member,
                    "length": length,
                    "file": f"{POOL_FILE_STEMS.get(surface, surface + '_step')}_{index:02d}.mp3",
                    "task": POOL_TASKS.get(surface, TASK),
                }
            )
    return clips


def _render(clip: dict) -> None:
    args, trim, length = _clip_input(clip["source_id"], clip["member"], clip["length"])
    shape = trim + _shape_filter(clip["highpass"], length)
    loudest, peak = _peak_window_db(_decode(args, shape))
    gain = clip["target"] - loudest
    # A limiter would smear the transient that makes a step a step; cap the gain
    # at the peak ceiling instead and accept a slightly quieter clip.
    gain = min(gain, PEAK_CEILING_DB - peak)
    out = OUT_DIR / clip["file"]
    command = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", *args]
    command += ["-af", f"{shape},volume={gain:.2f}dB", "-ac", "1", "-ar", str(SAMPLE_RATE)]
    command += ["-c:a", "libmp3lame", "-b:a", AUDIO_BITRATE, str(out)]
    subprocess.run(command, check=True)
    clip["gain_db"] = round(gain, 2)


def _notes(clip: dict) -> str:
    source = SOURCES[clip["source_id"]]
    if source["kind"] == "zip":
        cut = f"whole one-shot {clip['member']}"
    else:
        cut = f"single step cut at {float(clip['member']):.3f} s, {clip['length'] * 1000:.0f} ms"
    kind = "swim stroke" if clip["surface"] == "swim" else f"{clip['surface']} footstep"
    if clip["surface"] == "swim":
        cut = cut.replace("single step", "single stroke")
    return (
        f"{clip['task']} {kind} from CC0 {source['title']}; {cut}; mono, "
        f"{clip['highpass']} Hz high-pass, loudest 50 ms at {clip['target']:.0f} dBFS"
    )


def _write_manifest() -> None:
    fields = ["clip_id", "title", "author", "license", "page", "file", "notes"]
    with (OUT_DIR / "manifest.csv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        for clip in _clips():
            source = SOURCES[clip["source_id"]]
            writer.writerow(
                {
                    "clip_id": f"footstep.{clip['file'][:-4]}",
                    "title": source["title"],
                    "author": source["author"],
                    "license": CC0,
                    "page": source["page"],
                    "file": clip["file"],
                    "notes": _notes(clip),
                }
            )


def _source_rows() -> list[list[str]]:
    rows = []
    for clip in _clips():
        source = SOURCES[clip["source_id"]]
        path = OUT_DIR / clip["file"]
        digest = _sha256(path) if path.is_file() else "missing"
        rows.append(
            [
                f"sounds.footsteps.{clip['file'][:-4]}",
                f"sounds/footsteps/{clip['file']}",
                source["author"],
                "tools/audio/build_footstep_pools.py",
                f"{source['page']} sha256:{digest}",
                str(source.get("fs_id", "not applicable")),
                "CC0 1.0",
                f"{_notes(clip)}; mono 44.1 kHz 128 kbps; source sha256 {_expected_sha(clip['source_id'])}.",
                f"approved - {clip['task']} CC0 Foley recording (maintainer request 2026-10-10)",
            ]
        )
    return rows


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--print-sources", action="store_true", help="print assets/SOURCES.csv rows")
    args = parser.parse_args()
    if args.print_sources:
        csv.writer(sys.stdout, lineterminator="\n").writerows(_source_rows())
        return
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for clip in _clips():
        _render(clip)
        print(f"wrote sounds/footsteps/{clip['file']} (gain {clip['gain_db']:+.1f} dB)")
    _write_manifest()


if __name__ == "__main__":
    main()
