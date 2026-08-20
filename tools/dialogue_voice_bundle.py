#!/usr/bin/env python3
"""Stage and review offline generated dialogue voice clips.

The ElevenLabs export remains an operator-controlled artifact. This tool never
calls a speech API: it copies exported MP3 files into the paths declared by the
authored manifest, records their SHA-256, and verifies the resulting bundle.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import shutil
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
ALLOWED_STATUSES = frozenset({"pending", "generated", "approved"})


def _safe_relative_path(value: Any) -> Path | None:
    if not isinstance(value, str) or not value.strip():
        return None
    path = Path(value)
    if path.is_absolute() or ".." in path.parts:
        return None
    return path


def _project_path(root: Path, relative: str) -> Path | None:
    path = _safe_relative_path(relative)
    if path is None:
        return None
    return root / path


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _mp3_frame_offset(data: bytes) -> int | None:
    """Find a plausible MPEG audio frame after an optional ID3v2 header."""
    offset = 0
    if data.startswith(b"ID3") and len(data) >= 10:
        tag_size = data[6:10]
        if any(byte & 0x80 for byte in tag_size):
            return None
        offset = 10 + sum(byte << (7 * (3 - index)) for index, byte in enumerate(tag_size))
        if data[5] & 0x10:
            offset += 10

    for index in range(offset, max(offset, min(len(data) - 3, 64 * 1024))):
        first, second, third, fourth = data[index : index + 4]
        if first != 0xFF or second & 0xE0 != 0xE0:
            continue
        version = (second >> 3) & 0x03
        layer = (second >> 1) & 0x03
        bitrate_index = (third >> 4) & 0x0F
        sample_rate_index = (third >> 2) & 0x03
        if version == 1 or layer == 0 or bitrate_index in {0, 15} or sample_rate_index == 3:
            continue
        if (fourth >> 6) == 3:
            continue
        return index
    return None


def looks_like_mp3(path: Path) -> bool:
    """Reject empty/non-MP3 exports without requiring optional media packages."""
    if path.suffix.casefold() != ".mp3" or not path.is_file() or path.stat().st_size < 4:
        return False
    with path.open("rb") as handle:
        data = handle.read(64 * 1024)
    return _mp3_frame_offset(data) is not None


def load_manifest(path: Path) -> dict[str, Any]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError("manifest root must be an object")
    return payload


def validate_manifest(manifest: dict[str, Any]) -> list[str]:
    entries = manifest.get("entries")
    if not isinstance(entries, list):
        return ["manifest entries must be an array"]

    errors: list[str] = []
    seen_cues: set[str] = set()
    seen_paths: set[str] = set()
    for index, entry in enumerate(entries):
        label = f"entry {index + 1}"
        if not isinstance(entry, dict):
            errors.append(f"{label}: must be an object")
            continue
        cue_id = entry.get("cue_id")
        audio_path = entry.get("audio_path")
        status = entry.get("status")
        if not isinstance(cue_id, str) or not cue_id.strip():
            errors.append(f"{label}: cue_id is required")
        elif cue_id in seen_cues:
            errors.append(f"{label}: duplicate cue_id {cue_id!r}")
        else:
            seen_cues.add(cue_id)
        if not isinstance(audio_path, str) or not audio_path.strip():
            errors.append(f"{label}: audio_path is required")
        elif _safe_relative_path(audio_path) is None:
            errors.append(f"{label}: audio_path must be a safe relative path")
        elif audio_path in seen_paths:
            errors.append(f"{label}: duplicate audio_path {audio_path!r}")
        else:
            seen_paths.add(audio_path)
        if status not in ALLOWED_STATUSES:
            errors.append(f"{label}: unsupported status {status!r}")
    return errors


def _source_candidates(input_dir: Path, entry: dict[str, Any]) -> list[Path]:
    cue_id = str(entry["cue_id"])
    audio_path = str(entry["audio_path"])
    candidates = [
        input_dir / f"{cue_id}.mp3",
        input_dir / Path(audio_path).name,
        input_dir / audio_path,
    ]
    unique: list[Path] = []
    for candidate in candidates:
        resolved = candidate.resolve()
        if resolved not in {item.resolve() for item in unique}:
            unique.append(candidate)
    return [candidate for candidate in unique if candidate.is_file()]


def stage_manifest(
    manifest: dict[str, Any], input_dir: Path, project_root: Path
) -> tuple[dict[str, Any], list[str], list[str]]:
    """Copy available pending clips and return (updated, errors, staged cue IDs)."""
    updated = copy.deepcopy(manifest)
    errors = validate_manifest(updated)
    if errors:
        return updated, errors, []
    if not input_dir.is_dir():
        return updated, [f"input directory does not exist: {input_dir}"], []

    plans: list[tuple[dict[str, Any], Path, Path]] = []
    for entry in updated["entries"]:
        if entry["status"] != "pending":
            continue
        candidates = _source_candidates(input_dir, entry)
        if len(candidates) > 1:
            errors.append(f"{entry['cue_id']}: multiple matching MP3 exports")
            continue
        if not candidates:
            continue
        source = candidates[0]
        if not looks_like_mp3(source):
            errors.append(f"{entry['cue_id']}: export is not a valid MP3: {source}")
            continue
        target = _project_path(project_root, entry["audio_path"])
        if target is None:
            errors.append(f"{entry['cue_id']}: unsafe target path {entry['audio_path']!r}")
            continue
        plans.append((entry, source, target))

    if errors:
        return updated, sorted(set(errors)), []

    staged: list[str] = []
    for entry, source, target in plans:
        target.parent.mkdir(parents=True, exist_ok=True)
        if source.resolve() != target.resolve():
            shutil.copy2(source, target)
        entry["status"] = "generated"
        entry["audio_sha256"] = _sha256_file(target)
        staged.append(str(entry["cue_id"]))
    return updated, [], staged


def review_bundle(manifest: dict[str, Any], project_root: Path, require_all: bool = False) -> list[str]:
    """Return deterministic review findings for generated/approved bundle entries."""
    errors = validate_manifest(manifest)
    if errors:
        return errors

    expected_paths: set[Path] = set()
    for entry in manifest["entries"]:
        target = _project_path(project_root, entry["audio_path"])
        if target is None:
            continue
        expected_paths.add(target.resolve())
        status = entry["status"]
        if status == "pending":
            if target.is_file():
                errors.append(f"{entry['cue_id']}: audio exists while status is pending; stage the manifest")
            elif require_all:
                errors.append(f"{entry['cue_id']}: pending clip is missing: {entry['audio_path']}")
            continue
        if not target.is_file():
            errors.append(f"{entry['cue_id']}: bundled clip is missing: {entry['audio_path']}")
            continue
        if not looks_like_mp3(target):
            errors.append(f"{entry['cue_id']}: bundled clip is not a valid MP3: {entry['audio_path']}")
            continue
        expected_hash = entry.get("audio_sha256")
        if not isinstance(expected_hash, str) or len(expected_hash) != 64:
            errors.append(f"{entry['cue_id']}: generated clip is missing audio_sha256")
        elif expected_hash.casefold() != _sha256_file(target):
            errors.append(f"{entry['cue_id']}: audio_sha256 does not match {entry['audio_path']}")

    audio_root = project_root / "audio" / "voice"
    if audio_root.is_dir():
        for path in sorted(audio_root.rglob("*.mp3"), key=lambda item: item.as_posix().casefold()):
            if path.resolve() not in expected_paths:
                errors.append(f"orphan bundled clip: {path.relative_to(project_root).as_posix()}")
    return sorted(set(errors))


def _write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    stage = subparsers.add_parser("stage", help="copy exported MP3 files and mark them generated")
    stage.add_argument("--manifest", type=Path, required=True)
    stage.add_argument("--input-dir", type=Path, required=True)
    stage.add_argument("--project-root", type=Path, default=ROOT)
    stage.add_argument("--output", type=Path, help="updated manifest path; defaults to --manifest")

    review = subparsers.add_parser("review", help="verify bundled clips and manifest integrity")
    review.add_argument("--manifest", type=Path, required=True)
    review.add_argument("--project-root", type=Path, default=ROOT)
    review.add_argument("--require-all", action="store_true", help="fail when any pending cue is not bundled")

    args = parser.parse_args(argv)
    try:
        manifest = load_manifest(args.manifest)
    except (OSError, json.JSONDecodeError, ValueError) as error:
        print(f"ERROR: cannot load manifest: {error}", file=sys.stderr)
        return 1

    if args.command == "stage":
        updated, errors, staged = stage_manifest(
            manifest, args.input_dir.resolve(), args.project_root.resolve()
        )
        if errors:
            for error in errors:
                print(f"ERROR: {error}", file=sys.stderr)
            return 1
        output = (args.output or args.manifest).resolve()
        _write_json(output, updated)
        pending = sum(entry["status"] == "pending" for entry in updated["entries"])
        print(f"Staged {len(staged)} voice clips; {pending} cues remain pending: {output}")
        return 0

    errors = review_bundle(manifest, args.project_root.resolve(), require_all=args.require_all)
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    bundled = sum(entry["status"] in {"generated", "approved"} for entry in manifest["entries"])
    pending = sum(entry["status"] == "pending" for entry in manifest["entries"])
    print(f"Voice bundle review passed: {bundled} bundled, {pending} pending")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
