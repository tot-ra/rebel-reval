#!/usr/bin/env python3
"""Validate authored JSON content corpus for P1-004.

Schema checks reuse the P1-003 subset validator. This module adds cross-record
references, dialogue reachability, duplicate IDs, semantic condition/effect
rules, and res:// scene asset existence.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Iterable, Sequence

TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from validate_content_common import Diagnostic, diag, record_type_for_id  # noqa: E402
from validate_content_examples import (  # noqa: E402
    ROOT,
    SCHEMAS_DIR,
    SchemaStore,
    SchemaValidationError,
    schema_for_example,
    validate_value,
)
from validate_content_semantics import (  # noqa: E402
    schema_error_is_unknown_op_enum,
    scan_unknown_ops,
)

# Re-export shared helpers for validate_content_records and tests.
from validate_content_common import (  # noqa: E402,F401
    check_local_duplicates as _check_local_duplicates,
    local_ids as _local_ids,
    require_record_ref as _require_record_ref,
)
from validate_content_semantics import (  # noqa: E402,F401
    validate_condition_semantics as _validate_condition_semantics,
    validate_dialogue as _validate_dialogue,
    validate_effect_semantics as _validate_effect_semantics,
    walk_conditions as _walk_conditions,
    walk_effects as _walk_effects,
)


def _dedupe_paths(paths: Iterable[Path]) -> list[Path]:
    seen: set[Path] = set()
    unique: list[Path] = []
    for path in paths:
        if path not in seen:
            seen.add(path)
            unique.append(path)
    return unique


def discover_json_files(paths: Sequence[Path], *, root: Path) -> tuple[list[Path], list[Diagnostic]]:
    """Resolve input paths to JSON files; emit INPUT diagnostics for bad paths."""
    discovered: list[Path] = []
    diagnostics: list[Diagnostic] = []
    for raw in paths:
        path = raw.resolve()
        if not path.exists():
            diagnostics.append(diag("INPUT", path, "$", "path does not exist", root=root))
            continue
        if path.is_file():
            if path.suffix.lower() == ".json":
                discovered.append(path)
            else:
                diagnostics.append(diag("INPUT", path, "$", "path is not a JSON file", root=root))
            continue
        if path.is_dir():
            json_files = sorted(
                (item.resolve() for item in path.rglob("*.json")),
                key=lambda item: item.as_posix().casefold(),
            )
            if not json_files:
                diagnostics.append(diag("INPUT", path, "$", "no JSON files found", root=root))
            else:
                discovered.extend(json_files)
    return _dedupe_paths(discovered), diagnostics


def load_corpus(paths: Sequence[Path]) -> tuple[dict[Path, Any], list[Diagnostic], Path]:
    """Load JSON files; return parsed records, parse diagnostics, and common root."""
    input_root = ROOT.resolve()
    files, input_diagnostics = discover_json_files(paths, root=input_root)
    diagnostics = list(input_diagnostics)
    if not files:
        return {}, diagnostics, input_root

    root = _common_root(files)
    records: dict[Path, Any] = {}
    for path in files:
        try:
            with path.open(encoding="utf-8") as handle:
                records[path] = json.load(handle)
        except json.JSONDecodeError as exc:
            diagnostics.append(diag("JSON_PARSE", path, "$", str(exc), root=root))
    return records, diagnostics, root


def _common_root(paths: Iterable[Path]) -> Path:
    first = next(iter(paths))
    root = first.parent
    for path in paths:
        common: list[str] = []
        for left, right in zip(root.parts, path.parent.parts):
            if left == right:
                common.append(left)
            else:
                break
        root = Path(*common) if common else first.parent
    return root


def validate_corpus(
    paths: Sequence[str | Path],
    *,
    project_root: Path | None = None,
    schemas_dir: Path | None = None,
) -> list[Diagnostic]:
    """Validate JSON content under the given paths; return sorted diagnostics."""
    from validate_content_records import validate_record_semantics

    resolved_paths = [Path(path) for path in paths]
    records, diagnostics, corpus_root = load_corpus(resolved_paths)
    project_root = (project_root or ROOT).resolve()
    schemas_dir = (schemas_dir or SCHEMAS_DIR).resolve()
    store = SchemaStore(schemas_dir)

    index: dict[str, tuple[str, Path, dict[str, Any]]] = {}
    id_sources: dict[str, list[Path]] = {}

    for path, payload in sorted(records.items(), key=lambda item: item[0].as_posix().casefold()):
        if not isinstance(payload, dict):
            diagnostics.append(diag("SCHEMA", path, "$", "top-level JSON value must be an object", root=corpus_root))
            continue

        has_unknown_ops = scan_unknown_ops(diagnostics, path=path, record=payload, root=corpus_root)
        try:
            schema_name = schema_for_example(payload)
            schema = store.resolve(schema_name)
            validate_value(payload, schema, store)
        except SchemaValidationError as exc:
            if not (has_unknown_ops and schema_error_is_unknown_op_enum(str(exc))):
                diagnostics.append(diag("SCHEMA", path, "$", str(exc), root=corpus_root))
            continue

        content_id = payload.get("id")
        if isinstance(content_id, str):
            id_sources.setdefault(content_id, []).append(path)
            expected_type = record_type_for_id(content_id)
            actual_type = payload.get("type")
            if expected_type and actual_type != expected_type:
                diagnostics.append(
                    diag(
                        "SCHEMA",
                        path,
                        "$.id",
                        f"id prefix implies type {expected_type!r}, got {actual_type!r}",
                        root=corpus_root,
                    )
                )
            if content_id not in index:
                index[content_id] = (str(actual_type), path, payload)

    for content_id, sources in sorted(id_sources.items()):
        if len(sources) > 1:
            first = sources[0]
            for duplicate in sources[1:]:
                diagnostics.append(
                    diag(
                        "DUPLICATE_ID",
                        duplicate,
                        "$.id",
                        f"duplicate global content id {content_id!r} (first in {first.name})",
                        root=corpus_root,
                    )
                )

    for path, payload in sorted(records.items(), key=lambda item: item[0].as_posix().casefold()):
        if not isinstance(payload, dict):
            continue
        content_id = payload.get("id")
        if not isinstance(content_id, str):
            continue
        canonical = index.get(content_id)
        if canonical is None or canonical[1] != path:
            continue
        validate_record_semantics(
            diagnostics,
            path=path,
            record=payload,
            index=index,
            project_root=project_root,
            root=corpus_root,
        )

    return sorted(diagnostics)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "paths",
        nargs="+",
        help="JSON files or directories to validate recursively",
    )
    args = parser.parse_args(argv)
    diagnostics = validate_corpus(args.paths)
    for diagnostic in diagnostics:
        print(diagnostic.format())
    return 1 if diagnostics else 0


if __name__ == "__main__":
    raise SystemExit(main())
