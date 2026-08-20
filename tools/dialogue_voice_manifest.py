#!/usr/bin/env python3
"""Build an authored, offline voice manifest for dialogue and bark content.

The manifest is a production-time handoff to ElevenLabs. This tool never calls a
remote service and never changes runtime dialogue behavior. Generated audio can
be reviewed and copied into the paths recorded by the manifest before a release.

Examples:
    python3 tools/dialogue_voice_manifest.py \
        --content content/examples/valid \
        --content content/demo \
        --locale en \
        --output docs/data/dialogue_voice_manifest.json
    python3 tools/dialogue_voice_manifest.py --check \
        --content content/examples/valid \
        --content content/demo \
        --locale en \
        --output docs/data/dialogue_voice_manifest.json
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path
from typing import Any, Iterable

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CONTENT_DIRS = [ROOT / "content" / "examples" / "valid", ROOT / "content" / "demo"]
DEFAULT_CATALOG_DIR = ROOT / "localization"
DEFAULT_OUTPUT = ROOT / "docs" / "data" / "dialogue_voice_manifest.json"
DEFAULT_MODEL_ID = "eleven_multilingual_v2"


def normalize_locale(value: str) -> str:
    return value.strip().lower().replace("_", "-")


def base_locale(value: str) -> str:
    return value.split("-", 1)[0]


def _locale_candidates(locale: str) -> list[str]:
    candidates: list[str] = []
    for candidate in (normalize_locale(locale), base_locale(normalize_locale(locale)), "en"):
        if candidate and candidate not in candidates:
            candidates.append(candidate)
    return candidates


def _discover_json_files(paths: Iterable[Path]) -> list[Path]:
    discovered: set[Path] = set()
    for raw_path in paths:
        path = raw_path.resolve()
        if path.is_file() and path.suffix.lower() == ".json":
            discovered.add(path)
        elif path.is_dir():
            discovered.update(item.resolve() for item in path.rglob("*.json"))
    return sorted(discovered, key=lambda item: item.as_posix().casefold())


def _load_catalogs(catalog_dir: Path) -> tuple[dict[str, dict[str, str]], list[str]]:
    catalogs: dict[str, dict[str, str]] = {}
    errors: list[str] = []
    for path in _discover_json_files([catalog_dir]):
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            errors.append(f"{path}: cannot read localization catalog: {exc}")
            continue
        if not isinstance(payload, dict):
            errors.append(f"{path}: catalog root must be an object")
            continue
        locale = normalize_locale(str(payload.get("locale", "")))
        translations = payload.get("translations")
        if not locale or not isinstance(translations, dict):
            errors.append(f"{path}: expected non-empty locale and translations object")
            continue
        catalogs[locale] = {
            str(key): str(value)
            for key, value in translations.items()
            if isinstance(key, str) and isinstance(value, str) and value.strip()
        }
    return catalogs, errors


def resolve_text(
    entry: dict[str, Any], locale: str, catalogs: dict[str, dict[str, str]]
) -> str:
    text_key = entry.get("text_key")
    inline_text = entry.get("text")
    fallback = inline_text.strip() if isinstance(inline_text, str) else ""
    if isinstance(text_key, str) and text_key.strip():
        key = text_key.strip()
        for candidate in _locale_candidates(locale):
            translation = catalogs.get(candidate, {}).get(key, "")
            if translation.strip():
                return translation.strip()
    return fallback


def _sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def _cue(
    *,
    record: dict[str, Any],
    source_path: Path,
    project_root: Path,
    entry: dict[str, Any],
    entry_pointer: str,
    locale: str,
    catalogs: dict[str, dict[str, str]],
    voice_map: dict[str, str],
    errors: list[str],
) -> dict[str, Any] | None:
    record_id = record.get("id")
    entry_id = entry.get("id")
    speaker_id = entry.get("speaker_id")
    if not isinstance(record_id, str) or not record_id.strip():
        errors.append(f"{source_path}: missing record id at $.id")
        return None
    if not isinstance(entry_id, str) or not entry_id.strip():
        errors.append(f"{source_path}: missing entry id at {entry_pointer}.id")
        return None
    if not isinstance(speaker_id, str) or not speaker_id.strip():
        errors.append(f"{source_path}: missing speaker_id at {entry_pointer}")
        return None

    text = resolve_text(entry, locale, catalogs)
    if not text:
        errors.append(
            f"{source_path}: no authored text or catalog translation at {entry_pointer}"
        )
        return None

    cue_id = f"{record_id}.{entry_id}"
    relative_source = source_path.relative_to(project_root).as_posix()
    filename = cue_id.replace(".", "_") + ".mp3"
    return {
        "cue_id": cue_id,
        "content_id": record_id,
        "entry_id": entry_id,
        "source": relative_source,
        "source_pointer": entry_pointer,
        "speaker_id": speaker_id,
        "locale": normalize_locale(locale),
        "text_key": entry.get("text_key", ""),
        "text": text,
        "text_sha256": _sha256_text(text),
        "provider": "elevenlabs",
        "model_id": DEFAULT_MODEL_ID,
        "voice_id": voice_map.get(speaker_id),
        "status": "pending",
        "audio_path": f"audio/voice/{normalize_locale(locale)}/{speaker_id}/{filename}",
    }


def _extract_record_cues(
    record: dict[str, Any],
    source_path: Path,
    project_root: Path,
    locale: str,
    catalogs: dict[str, dict[str, str]],
    voice_map: dict[str, str],
    errors: list[str],
) -> list[dict[str, Any]]:
    record_type = record.get("type")
    if record_type == "dialogue":
        cues: list[dict[str, Any]] = []
        for node_index, node in enumerate(record.get("nodes", [])):
            if not isinstance(node, dict):
                errors.append(f"{source_path}: node {node_index} must be an object")
                continue
            cue = _cue(
                record=record,
                source_path=source_path,
                project_root=project_root,
                entry=node,
                entry_pointer=f"$.nodes[{node_index}]",
                locale=locale,
                catalogs=catalogs,
                voice_map=voice_map,
                errors=errors,
            )
            if cue is not None:
                cues.append(cue)
        return cues

    if record_type == "bark_pool":
        cues = []
        for entry_index, entry in enumerate(record.get("entries", [])):
            if not isinstance(entry, dict):
                errors.append(f"{source_path}: bark entry {entry_index} must be an object")
                continue
            cue = _cue(
                record=record,
                source_path=source_path,
                project_root=project_root,
                entry=entry,
                entry_pointer=f"$.entries[{entry_index}]",
                locale=locale,
                catalogs=catalogs,
                voice_map=voice_map,
                errors=errors,
            )
            if cue is not None:
                cues.append(cue)
        return cues

    return []


def _load_voice_map(path: Path | None) -> tuple[dict[str, str], list[str]]:
    if path is None:
        return {}, []
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return {}, [f"{path}: cannot read voice map: {exc}"]
    if not isinstance(payload, dict):
        return {}, [f"{path}: voice map root must be an object"]
    return {
        str(key): str(value)
        for key, value in payload.items()
        if isinstance(key, str) and isinstance(value, str) and value.strip()
    }, []


def build_manifest(
    project_root: Path = ROOT,
    content_dirs: Iterable[Path] = DEFAULT_CONTENT_DIRS,
    locale: str = "en",
    catalog_dir: Path = DEFAULT_CATALOG_DIR,
    voice_map_path: Path | None = None,
) -> tuple[dict[str, Any], list[str]]:
    root = project_root.resolve()
    catalogs, errors = _load_catalogs(catalog_dir.resolve())
    voice_map, voice_map_errors = _load_voice_map(voice_map_path.resolve() if voice_map_path else None)
    errors.extend(voice_map_errors)
    cues: list[dict[str, Any]] = []

    for source_path in _discover_json_files(content_dirs):
        try:
            payload = json.loads(source_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            errors.append(f"{source_path}: cannot read content JSON: {exc}")
            continue
        if not isinstance(payload, dict):
            continue
        cues.extend(
            _extract_record_cues(
                payload,
                source_path,
                root,
                locale,
                catalogs,
                voice_map,
                errors,
            )
        )

    cues.sort(key=lambda item: str(item["cue_id"]))
    cue_ids = [str(item["cue_id"]) for item in cues]
    duplicates = sorted({cue_id for cue_id in cue_ids if cue_ids.count(cue_id) > 1})
    for cue_id in duplicates:
        errors.append(f"duplicate cue_id {cue_id!r}")

    manifest = {
        "schema_version": 1,
        "provider": "elevenlabs",
        "model_id": DEFAULT_MODEL_ID,
        "locale": normalize_locale(locale),
        "source_policy": {
            "authored_offline": True,
            "runtime_api_allowed": False,
            "status_values": ["pending", "generated", "approved"],
        },
        "entries": cues,
    }
    return manifest, sorted(set(errors))


def _render(payload: dict[str, Any]) -> str:
    return json.dumps(payload, indent=2, ensure_ascii=False) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--content",
        action="append",
        type=Path,
        dest="content_dirs",
        help="Content file or directory; repeat for multiple roots",
    )
    parser.add_argument("--catalog-dir", type=Path, default=DEFAULT_CATALOG_DIR)
    parser.add_argument("--locale", default="en")
    parser.add_argument("--voice-map", type=Path, help="Optional JSON map of speaker_id to ElevenLabs voice_id")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--check", action="store_true", help="Fail when output is missing or stale")
    args = parser.parse_args(argv)

    content_dirs = args.content_dirs or DEFAULT_CONTENT_DIRS
    payload, errors = build_manifest(
        project_root=ROOT,
        content_dirs=content_dirs,
        locale=args.locale,
        catalog_dir=args.catalog_dir,
        voice_map_path=args.voice_map,
    )
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    rendered = _render(payload)
    if args.check:
        if not args.output.exists():
            print(f"ERROR: manifest is missing: {args.output}", file=sys.stderr)
            return 1
        if args.output.read_text(encoding="utf-8") != rendered:
            print(f"ERROR: manifest is stale: {args.output}", file=sys.stderr)
            return 1
        print(f"Voice manifest is current: {args.output} ({len(payload['entries'])} entries)")
        return 0

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(rendered, encoding="utf-8")
    print(f"Wrote voice manifest: {args.output} ({len(payload['entries'])} entries)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
