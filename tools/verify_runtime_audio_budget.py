#!/usr/bin/env python3
"""Enforce the P0-182 runtime audio bitrate and per-file size budget.

Scans ``music/`` and ``sounds/``. Lossy cues use the sounds_lossy / music
tables; retained PCM source takes use sounds_pcm. Git LFS pointer files are
checked against the pointer size field so CI can fail an oversized object
before it is materialized.

Usage:
    python3 tools/verify_runtime_audio_budget.py
"""

from __future__ import annotations

import argparse
import json
import struct
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "docs" / "data" / "runtime_audio_budget.json"
LFS_POINTER_HEADER = b"version https://git-lfs.github.com/spec/v1\n"

MPEG1_L3_BITRATE = (0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320)
MPEG2_L3_BITRATE = (0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160)
MPEG_SR = {
    3: (44100, 48000, 32000),
    2: (22050, 24000, 16000),
    0: (11025, 12000, 8000),
}


def load_manifest(path: Path) -> tuple[dict[str, Any], list[str]]:
    if not path.is_file():
        return {}, [f"missing runtime audio budget: {path}"]
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return {}, [f"could not read runtime audio budget: {exc}"]
    if not isinstance(payload, dict):
        return {}, ["runtime audio budget root must be an object"]
    return payload, []


def parse_lfs_pointer(blob: bytes) -> tuple[str, int] | None:
    if not blob.startswith(LFS_POINTER_HEADER):
        return None
    fields: dict[str, str] = {}
    for line in blob[len(LFS_POINTER_HEADER) :].splitlines():
        if b" " not in line:
            continue
        key, value = line.decode("utf-8", errors="replace").split(" ", 1)
        fields[key] = value
    oid = fields.get("oid", "")
    try:
        size = int(fields["size"])
    except (KeyError, ValueError):
        return None
    return oid, size


def _id3v2_size(data: bytes) -> int:
    if len(data) < 10 or not data.startswith(b"ID3"):
        return 0
    tag = data[6:10]
    if any(byte & 0x80 for byte in tag):
        return 0
    size = 10 + sum(byte << (7 * (3 - index)) for index, byte in enumerate(tag))
    if data[5] & 0x10:
        size += 10
    return size


def _mp3_frame_offset(data: bytes, start: int) -> int | None:
    limit = min(len(data) - 4, start + 64 * 1024)
    for index in range(start, max(start, limit)):
        if data[index] != 0xFF or data[index + 1] & 0xE0 != 0xE0:
            continue
        version = (data[index + 1] >> 3) & 0x03
        layer = (data[index + 1] >> 1) & 0x03
        bitrate_index = (data[index + 2] >> 4) & 0x0F
        sample_rate_index = (data[index + 2] >> 2) & 0x03
        if version == 1 or layer != 1 or bitrate_index in {0, 15} or sample_rate_index == 3:
            continue
        if version not in MPEG_SR:
            continue
        return index
    return None


def _frame_bitrate_kbps(header: bytes) -> int:
    version = (header[1] >> 3) & 0x03
    bitrate_index = (header[2] >> 4) & 0x0F
    table = MPEG1_L3_BITRATE if version == 3 else MPEG2_L3_BITRATE
    return table[bitrate_index] * 1000


def _frame_sample_rate(header: bytes) -> int:
    version = (header[1] >> 3) & 0x03
    sample_rate_index = (header[2] >> 2) & 0x03
    return MPEG_SR[version][sample_rate_index]


def _frame_length(header: bytes) -> int:
    bitrate = _frame_bitrate_kbps(header)
    sample_rate = _frame_sample_rate(header)
    if bitrate <= 0 or sample_rate <= 0:
        return 0
    padding = (header[2] >> 1) & 0x01
    version = (header[1] >> 3) & 0x03
    slot = 144 if version == 3 else 72
    return int(slot * bitrate / sample_rate) + padding


def probe_mp3(path: Path) -> tuple[int, float] | None:
    """Return (average_bitrate_bps, duration_s) for CBR and VBR MP3s."""
    data = path.read_bytes()
    if len(data) >= 12 and data.startswith(b"RIFF") and data[8:12] == b"WAVE":
        return probe_wav(path)
    if len(data) < 16:
        return None
    start = _id3v2_size(data)
    offset = _mp3_frame_offset(data, start)
    if offset is None:
        return None
    header = data[offset : offset + 4]
    sample_rate = _frame_sample_rate(header)
    samples_per_frame = 1152 if ((header[1] >> 3) & 0x03) == 3 else 576
    # Xing/Info may sit after side info, or a few bytes later on LAME files.
    search = data[offset : offset + 220]
    for tag in (b"Xing", b"Info"):
        at = search.find(tag)
        if at < 0 or offset + at + 16 > len(data):
            continue
        flags = struct.unpack(">I", data[offset + at + 4 : offset + at + 8])[0]
        cursor = offset + at + 8
        frames = 0
        xing_bytes = 0
        if flags & 0x1 and cursor + 4 <= len(data):
            frames = struct.unpack(">I", data[cursor : cursor + 4])[0]
            cursor += 4
        if flags & 0x2 and cursor + 4 <= len(data):
            xing_bytes = struct.unpack(">I", data[cursor : cursor + 4])[0]
        if frames > 0 and sample_rate > 0:
            duration = frames * samples_per_frame / sample_rate
            payload = xing_bytes or (len(data) - start)
            if duration > 0:
                return int(payload * 8 / duration), duration
    frames = 0
    cursor = offset
    end = len(data) - 128 if data[-128:-125] == b"TAG" else len(data)
    while cursor + 4 <= end:
        if data[cursor] != 0xFF or data[cursor + 1] & 0xE0 != 0xE0:
            cursor += 1
            continue
        hdr = data[cursor : cursor + 4]
        version = (hdr[1] >> 3) & 0x03
        layer = (hdr[1] >> 1) & 0x03
        bitrate_index = (hdr[2] >> 4) & 0x0F
        sample_rate_index = (hdr[2] >> 2) & 0x03
        if version == 1 or layer != 1 or bitrate_index in {0, 15} or sample_rate_index == 3:
            cursor += 1
            continue
        length = _frame_length(hdr)
        if length < 24:
            cursor += 1
            continue
        frames += 1
        cursor += length
    if frames <= 0 or sample_rate <= 0:
        return None
    duration = frames * samples_per_frame / sample_rate
    payload = max(1, len(data) - start)
    return int(payload * 8 / duration), duration


def probe_wav(path: Path) -> tuple[int, float] | None:
    data = path.read_bytes()
    if len(data) < 44 or data[:4] != b"RIFF" or data[8:12] != b"WAVE":
        return None
    offset = 12
    byte_rate = 0
    data_size = 0
    while offset + 8 <= len(data):
        chunk_id = data[offset : offset + 4]
        chunk_size = struct.unpack_from("<I", data, offset + 4)[0]
        body = offset + 8
        if chunk_id == b"fmt " and chunk_size >= 16 and body + 16 <= len(data):
            byte_rate = struct.unpack_from("<I", data, body + 8)[0]
        elif chunk_id == b"data":
            data_size = chunk_size
            break
        offset = body + chunk_size + (chunk_size & 1)
    if byte_rate <= 0:
        return None
    payload = data_size if data_size else max(0, path.stat().st_size - 44)
    duration = payload / byte_rate if byte_rate else 0.0
    return byte_rate * 8, duration


def probe_audio(path: Path) -> tuple[int, float] | None:
    suffix = path.suffix.lower()
    header = path.read_bytes()[:12]
    if header.startswith(b"RIFF") and header[8:12] == b"WAVE":
        return probe_wav(path)
    if suffix == ".mp3":
        return probe_mp3(path)
    if suffix == ".wav":
        return probe_wav(path)
    return None


def iter_audio_files(root: Path, roots: list[str], suffixes: set[str]) -> list[Path]:
    files: list[Path] = []
    for name in roots:
        folder = root / name
        if not folder.is_dir():
            continue
        for path in folder.rglob("*"):
            if path.is_file() and path.suffix.lower() in suffixes:
                files.append(path)
    return sorted(files)


def _budget_for(rel: str, suffix: str, manifest: dict[str, Any]) -> dict[str, int] | None:
    budget = manifest.get("budget", {})
    policy = manifest.get("policy", {})
    pcm = {item.lower() for item in policy.get("pcm_suffixes", [])}
    if rel.startswith("music/"):
        row = budget.get("music")
    elif suffix in pcm:
        row = budget.get("sounds_pcm")
    else:
        row = budget.get("sounds_lossy")
    if not isinstance(row, dict):
        return None
    try:
        return {
            "max_bitrate_bps": int(row["max_bitrate_bps"]),
            "max_file_bytes": int(row["max_file_bytes"]),
        }
    except (KeyError, TypeError, ValueError):
        return None


def validate(
    *,
    root: Path = ROOT,
    manifest_path: Path | None = None,
) -> list[str]:
    resolved = manifest_path or MANIFEST_PATH
    if not resolved.is_absolute():
        resolved = root / resolved
    manifest, errors = load_manifest(resolved)
    if errors:
        return errors

    policy = manifest.get("policy", {})
    roots = policy.get("roots", ["music", "sounds"])
    suffixes = {str(item).lower() for item in policy.get("suffixes", [".mp3"])}
    if not isinstance(roots, list) or not roots:
        return ["runtime audio budget policy.roots must be a non-empty array"]

    exceptions = {
        str(row.get("path", ""))
        for row in manifest.get("exceptions", [])
        if isinstance(row, dict)
    }
    files = iter_audio_files(root, [str(item) for item in roots], suffixes)
    if not files:
        errors.append("runtime audio budget found no audio files under music/ or sounds/")

    for path in files:
        rel = path.relative_to(root).as_posix()
        if rel in exceptions:
            continue
        caps = _budget_for(rel, path.suffix.lower(), manifest)
        if caps is None:
            errors.append(f"{rel}: no budget row for this path/suffix")
            continue
        blob = path.read_bytes()[:256]
        pointer = parse_lfs_pointer(blob)
        if pointer is not None:
            _oid, size_bytes = pointer
        else:
            size_bytes = path.stat().st_size
        if size_bytes > caps["max_file_bytes"]:
            errors.append(
                f"{rel}: {size_bytes} bytes exceeds per-file cap {caps['max_file_bytes']}"
            )
        if pointer is not None:
            continue
        probed = probe_audio(path)
        if probed is None:
            if path.suffix.lower() in {".mp3", ".wav"}:
                errors.append(f"{rel}: could not parse audio bitrate")
            continue
        bitrate_bps, _duration = probed
        if bitrate_bps > caps["max_bitrate_bps"]:
            errors.append(
                f"{rel}: {bitrate_bps} bps exceeds encode ceiling {caps['max_bitrate_bps']}"
            )
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--manifest", type=Path)
    args = parser.parse_args(argv)
    errors = validate(root=args.root, manifest_path=args.manifest)
    if errors:
        print("runtime audio budget verification failed:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1
    print("runtime audio budget verification passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
