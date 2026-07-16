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
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable, Iterable, Sequence

TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from validate_content_examples import (  # noqa: E402
    ROOT,
    SCHEMAS_DIR,
    SchemaStore,
    SchemaValidationError,
    schema_for_example,
    validate_value,
)

RECORD_TYPE_BY_PREFIX = {
    "char.": "character",
    "dialogue.": "dialogue",
    "bark.": "bark_pool",
    "quest.": "quest",
    "item.": "item",
    "commission.": "commission",
    "loc.": "location",
}

CONDITION_OPS = {
    "always",
    "flag_is",
    "flag_not",
    "fact_known",
    "phase_is",
    "pressure_at_least",
    "relationship_at_least",
    "item_owned",
    "quest_state_is",
}

EFFECT_OPS = {
    "set_flag",
    "set_fact",
    "set_phase",
    "set_quest_state",
    "adjust_pressure",
    "adjust_relationship",
    "add_item",
    "remove_item",
    "set_location_state",
}

CONDITION_LIST_KEYS = frozenset({"conditions", "entry_conditions", "requires"})
EFFECT_LIST_KEYS = frozenset({"effects"})

# Per-op semantic rules beyond JSON Schema: required fields, key namespace, value type.
CONDITION_RULES: dict[str, dict[str, Any]] = {
    "always": {"required": set(), "forbidden": {"key", "value", "amount"}},
    "flag_is": {"required": {"key", "value"}, "key_prefix": "flag.", "value_type": bool},
    "flag_not": {"required": {"key", "value"}, "key_prefix": "flag.", "value_type": bool},
    "fact_known": {"required": {"key"}, "forbidden": {"amount"}, "key_prefix": "fact."},
    "phase_is": {"required": {"key", "value"}, "key_prefix": "phase.", "value_type": str},
    "pressure_at_least": {"required": {"key", "amount"}, "forbidden": {"value"}, "key_prefix": "pressure."},
    "relationship_at_least": {"required": {"key", "amount"}, "forbidden": {"value"}, "key_prefix": "rel."},
    "item_owned": {"required": {"key"}, "forbidden": {"value", "amount"}, "key_prefix": "item.", "item_ref": True},
    "quest_state_is": {
        "required": {"key", "value"},
        "forbidden": {"amount"},
        "key_prefix": "quest.",
        "value_type": str,
        "quest_state": True,
    },
}

EFFECT_RULES: dict[str, dict[str, Any]] = {
    "set_flag": {"required": {"key", "value"}, "forbidden": {"amount"}, "key_prefix": "flag.", "value_type": bool},
    "set_fact": {"required": {"key", "value"}, "forbidden": {"amount"}, "key_prefix": "fact.", "value_type": bool},
    "set_phase": {"required": {"key", "value"}, "forbidden": {"amount"}, "key_prefix": "phase.", "value_type": str},
    "set_quest_state": {
        "required": {"key", "value"},
        "forbidden": {"amount"},
        "key_prefix": "quest.",
        "value_type": str,
        "quest_state": True,
    },
    "adjust_pressure": {"required": {"key", "amount"}, "forbidden": {"value"}, "key_prefix": "pressure."},
    "adjust_relationship": {"required": {"key", "amount"}, "forbidden": {"value"}, "key_prefix": "rel."},
    "add_item": {"required": {"key"}, "forbidden": {"value", "amount"}, "key_prefix": "item.", "item_ref": True},
    "remove_item": {"required": {"key"}, "forbidden": {"value", "amount"}, "key_prefix": "item.", "item_ref": True},
    "set_location_state": {
        "required": {"key", "value"},
        "forbidden": {"amount"},
        "key_prefix": "loc.",
        "value_type": str,
        "location_state": True,
    },
}


@dataclass(frozen=True, order=True)
class Diagnostic:
    code: str
    path: str
    pointer: str
    message: str

    def format(self) -> str:
        location = self.path if not self.pointer or self.pointer == "$" else f"{self.path}:{self.pointer}"
        return f"{self.code} {location}: {self.message}"


def _diag(code: str, path: Path, pointer: str, message: str, *, root: Path) -> Diagnostic:
    try:
        rel = path.relative_to(root)
        display = rel.as_posix()
    except ValueError:
        display = path.as_posix()
    return Diagnostic(code=code, path=display, pointer=pointer, message=message)


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
            diagnostics.append(_diag("INPUT", path, "$", "path does not exist", root=root))
            continue
        if path.is_file():
            if path.suffix.lower() == ".json":
                discovered.append(path)
            else:
                diagnostics.append(_diag("INPUT", path, "$", "path is not a JSON file", root=root))
            continue
        if path.is_dir():
            json_files = sorted(
                (item.resolve() for item in path.rglob("*.json")),
                key=lambda item: item.as_posix().casefold(),
            )
            if not json_files:
                diagnostics.append(_diag("INPUT", path, "$", "no JSON files found", root=root))
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
            diagnostics.append(_diag("JSON_PARSE", path, "$", str(exc), root=root))
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


def _record_type_for_id(content_id: str) -> str | None:
    for prefix, record_type in RECORD_TYPE_BY_PREFIX.items():
        if content_id.startswith(prefix):
            return record_type
    return None


def _local_ids(items: list[dict[str, Any]] | None, field: str = "id") -> list[str]:
    if not items:
        return []
    return [str(item[field]) for item in items if isinstance(item, dict) and field in item]


def _check_local_duplicates(
    diagnostics: list[Diagnostic],
    *,
    path: Path,
    pointer: str,
    ids: list[str],
    root: Path,
) -> None:
    seen: dict[str, int] = {}
    for index, local_id in enumerate(ids):
        if local_id in seen:
            diagnostics.append(
                _diag(
                    "DUPLICATE_ID",
                    path,
                    f"{pointer}[{index}].id",
                    f"duplicate local id {local_id!r} (first at index {seen[local_id]})",
                    root=root,
                )
            )
        else:
            seen[local_id] = index


def _record_ref_valid(
    diagnostics: list[Diagnostic],
    *,
    path: Path,
    pointer: str,
    content_id: str | None,
    expected_type: str,
    index: dict[str, tuple[str, Path, dict[str, Any]]],
    root: Path,
) -> bool:
    if not content_id:
        return False
    entry = index.get(content_id)
    if entry is None:
        diagnostics.append(
            _diag(
                "REFERENCE",
                path,
                pointer,
                f"unknown {expected_type} id {content_id!r}",
                root=root,
            )
        )
        return False
    actual_type, _, _ = entry
    if actual_type != expected_type:
        diagnostics.append(
            _diag(
                "REFERENCE",
                path,
                pointer,
                f"expected {expected_type} id, got {actual_type} record {content_id!r}",
                root=root,
            )
        )
        return False
    return True


def _require_record_ref(
    diagnostics: list[Diagnostic],
    *,
    path: Path,
    pointer: str,
    content_id: str | None,
    expected_type: str,
    index: dict[str, tuple[str, Path, dict[str, Any]]],
    root: Path,
) -> None:
    _record_ref_valid(
        diagnostics,
        path=path,
        pointer=pointer,
        content_id=content_id,
        expected_type=expected_type,
        index=index,
        root=root,
    )


def _quest_state_ids(index: dict[str, tuple[str, Path, dict[str, Any]]], quest_id: str) -> set[str]:
    entry = index.get(quest_id)
    if entry is None:
        return set()
    _, _, record = entry
    return set(_local_ids(record.get("states")))


def _location_state_ids(index: dict[str, tuple[str, Path, dict[str, Any]]], location_id: str) -> set[str]:
    entry = index.get(location_id)
    if entry is None:
        return set()
    _, _, record = entry
    return set(_local_ids(record.get("phase_states")))


def _schema_error_is_unknown_op_enum(message: str) -> bool:
    return ".op" in message and "is not one of" in message


def _scan_unknown_ops(
    diagnostics: list[Diagnostic],
    *,
    path: Path,
    record: Any,
    root: Path,
) -> bool:
    """Classify unknown condition/effect ops before schema validation."""
    found = False

    def walk(obj: Any, pointer: str) -> None:
        nonlocal found
        if isinstance(obj, dict):
            for key, value in obj.items():
                child_pointer = f"{pointer}.{key}"
                if key in CONDITION_LIST_KEYS and isinstance(value, list):
                    for index, item in enumerate(value):
                        if not isinstance(item, dict):
                            continue
                        op = item.get("op")
                        if isinstance(op, str) and op not in CONDITION_OPS:
                            found = True
                            diagnostics.append(
                                _diag(
                                    "UNSUPPORTED_CONDITION",
                                    path,
                                    f"{child_pointer}[{index}]",
                                    f"unknown op {op!r}",
                                    root=root,
                                )
                            )
                elif key in EFFECT_LIST_KEYS and isinstance(value, list):
                    for index, item in enumerate(value):
                        if not isinstance(item, dict):
                            continue
                        op = item.get("op")
                        if isinstance(op, str) and op not in EFFECT_OPS:
                            found = True
                            diagnostics.append(
                                _diag(
                                    "UNSUPPORTED_EFFECT",
                                    path,
                                    f"{child_pointer}[{index}]",
                                    f"unknown op {op!r}",
                                    root=root,
                                )
                            )
                else:
                    walk(value, child_pointer)
        elif isinstance(obj, list):
            for index, item in enumerate(obj):
                walk(item, f"{pointer}[{index}]")

    walk(record, "$")
    return found


def _validate_condition_semantics(
    diagnostics: list[Diagnostic],
    *,
    path: Path,
    pointer: str,
    condition: dict[str, Any],
    index: dict[str, tuple[str, Path, dict[str, Any]]],
    root: Path,
) -> None:
    op = condition.get("op")
    if op not in CONDITION_OPS:
        diagnostics.append(_diag("UNSUPPORTED_CONDITION", path, pointer, f"unknown op {op!r}", root=root))
        return

    rules = CONDITION_RULES[op]
    for required in rules.get("required", set()):
        if required not in condition:
            diagnostics.append(
                _diag("UNSUPPORTED_CONDITION", path, pointer, f"{op} requires {required!r}", root=root)
            )
    for forbidden in rules.get("forbidden", set()):
        if forbidden in condition:
            diagnostics.append(
                _diag("UNSUPPORTED_CONDITION", path, pointer, f"{op} must not include {forbidden!r}", root=root)
            )

    key = condition.get("key")
    prefix = rules.get("key_prefix")
    if prefix and isinstance(key, str) and not key.startswith(prefix):
        diagnostics.append(
            _diag(
                "UNSUPPORTED_CONDITION",
                path,
                f"{pointer}.key",
                f"{op} key must start with {prefix!r}, got {key!r}",
                root=root,
            )
        )

    value_type = rules.get("value_type")
    if value_type is not None and "value" in condition and not isinstance(condition["value"], value_type):
        diagnostics.append(
            _diag(
                "UNSUPPORTED_CONDITION",
                path,
                f"{pointer}.value",
                f"{op} value must be {value_type.__name__}",
                root=root,
            )
        )

    if rules.get("item_ref") and isinstance(key, str):
        _require_record_ref(
            diagnostics,
            path=path,
            pointer=f"{pointer}.key",
            content_id=key,
            expected_type="item",
            index=index,
            root=root,
        )

    if rules.get("quest_state") and isinstance(key, str):
        if _record_ref_valid(
            diagnostics,
            path=path,
            pointer=f"{pointer}.key",
            content_id=key,
            expected_type="quest",
            index=index,
            root=root,
        ) and isinstance(condition.get("value"), str):
            if condition["value"] not in _quest_state_ids(index, key):
                diagnostics.append(
                    _diag(
                        "UNSUPPORTED_CONDITION",
                        path,
                        f"{pointer}.value",
                        f"quest {key!r} has no state {condition['value']!r}",
                        root=root,
                    )
                )


def _validate_effect_semantics(
    diagnostics: list[Diagnostic],
    *,
    path: Path,
    pointer: str,
    effect: dict[str, Any],
    index: dict[str, tuple[str, Path, dict[str, Any]]],
    root: Path,
) -> None:
    op = effect.get("op")
    if op not in EFFECT_OPS:
        diagnostics.append(_diag("UNSUPPORTED_EFFECT", path, pointer, f"unknown op {op!r}", root=root))
        return

    rules = EFFECT_RULES[op]
    for required in rules.get("required", set()):
        if required not in effect:
            diagnostics.append(
                _diag("UNSUPPORTED_EFFECT", path, pointer, f"{op} requires {required!r}", root=root)
            )
    for forbidden in rules.get("forbidden", set()):
        if forbidden in effect:
            diagnostics.append(
                _diag("UNSUPPORTED_EFFECT", path, pointer, f"{op} must not include {forbidden!r}", root=root)
            )

    key = effect.get("key")
    prefix = rules.get("key_prefix")
    if prefix and isinstance(key, str) and not key.startswith(prefix):
        diagnostics.append(
            _diag(
                "UNSUPPORTED_EFFECT",
                path,
                f"{pointer}.key",
                f"{op} key must start with {prefix!r}, got {key!r}",
                root=root,
            )
        )

    value_type = rules.get("value_type")
    if value_type is not None and "value" in effect and not isinstance(effect["value"], value_type):
        diagnostics.append(
            _diag(
                "UNSUPPORTED_EFFECT",
                path,
                f"{pointer}.value",
                f"{op} value must be {value_type.__name__}",
                root=root,
            )
        )

    if rules.get("item_ref") and isinstance(key, str):
        _require_record_ref(
            diagnostics,
            path=path,
            pointer=f"{pointer}.key",
            content_id=key,
            expected_type="item",
            index=index,
            root=root,
        )

    if rules.get("quest_state") and isinstance(key, str):
        if _record_ref_valid(
            diagnostics,
            path=path,
            pointer=f"{pointer}.key",
            content_id=key,
            expected_type="quest",
            index=index,
            root=root,
        ) and isinstance(effect.get("value"), str):
            if effect["value"] not in _quest_state_ids(index, key):
                diagnostics.append(
                    _diag(
                        "UNSUPPORTED_EFFECT",
                        path,
                        f"{pointer}.value",
                        f"quest {key!r} has no state {effect['value']!r}",
                        root=root,
                    )
                )

    if rules.get("location_state") and isinstance(key, str):
        if _record_ref_valid(
            diagnostics,
            path=path,
            pointer=f"{pointer}.key",
            content_id=key,
            expected_type="location",
            index=index,
            root=root,
        ) and isinstance(effect.get("value"), str):
            if effect["value"] not in _location_state_ids(index, key):
                diagnostics.append(
                    _diag(
                        "UNSUPPORTED_EFFECT",
                        path,
                        f"{pointer}.value",
                        f"location {key!r} has no phase state {effect['value']!r}",
                        root=root,
                    )
                )


def _walk_operation_lists(
    obj: Any,
    pointer: str,
    list_keys: frozenset[str],
    sink: Callable[[str, dict[str, Any]], None],
) -> None:
    """Visit operation objects only inside schema-defined operation arrays.

    Conditions and effects share the same {op, key, ...} shape, so classifying
    every object with an ``op`` field would send effects to the condition
    validator and vice versa.
    """
    if isinstance(obj, dict):
        for key, value in obj.items():
            child_pointer = f"{pointer}.{key}"
            if key in list_keys and isinstance(value, list):
                for index, item in enumerate(value):
                    if isinstance(item, dict):
                        sink(f"{child_pointer}[{index}]", item)
            else:
                _walk_operation_lists(value, child_pointer, list_keys, sink)
    elif isinstance(obj, list):
        for index, item in enumerate(obj):
            _walk_operation_lists(item, f"{pointer}[{index}]", list_keys, sink)


def _walk_conditions(
    obj: Any,
    pointer: str,
    sink: Callable[[str, dict[str, Any]], None],
) -> None:
    _walk_operation_lists(obj, pointer, CONDITION_LIST_KEYS, sink)


def _walk_effects(
    obj: Any,
    pointer: str,
    sink: Callable[[str, dict[str, Any]], None],
) -> None:
    _walk_operation_lists(obj, pointer, EFFECT_LIST_KEYS, sink)


def _validate_dialogue(
    diagnostics: list[Diagnostic],
    *,
    path: Path,
    record: dict[str, Any],
    index: dict[str, tuple[str, Path, dict[str, Any]]],
    root: Path,
) -> None:
    nodes = record.get("nodes") or []
    node_ids = _local_ids(nodes)
    _check_local_duplicates(diagnostics, path=path, pointer="$.nodes", ids=node_ids, root=root)

    id_to_index = {node_id: idx for idx, node_id in enumerate(node_ids)}
    start = record.get("start_node_id")
    if isinstance(start, str) and start not in id_to_index:
        diagnostics.append(
            _diag("REFERENCE", path, "$.start_node_id", f"unknown dialogue node id {start!r}", root=root)
        )

    for node_index, node in enumerate(nodes):
        if not isinstance(node, dict):
            continue
        base = f"$.nodes[{node_index}]"
        speaker = node.get("speaker_id")
        if speaker:
            _require_record_ref(
                diagnostics,
                path=path,
                pointer=f"{base}.speaker_id",
                content_id=speaker,
                expected_type="character",
                index=index,
                root=root,
            )
        next_node = node.get("next_node_id")
        if isinstance(next_node, str) and next_node not in id_to_index:
            diagnostics.append(
                _diag("REFERENCE", path, f"{base}.next_node_id", f"unknown dialogue node id {next_node!r}", root=root)
            )
        choices = node.get("choices") or []
        choice_ids = _local_ids(choices)
        _check_local_duplicates(diagnostics, path=path, pointer=f"{base}.choices", ids=choice_ids, root=root)
        for choice_index, choice in enumerate(choices):
            if not isinstance(choice, dict):
                continue
            target = choice.get("target_node_id")
            if isinstance(target, str) and target not in id_to_index:
                diagnostics.append(
                    _diag(
                        "REFERENCE",
                        path,
                        f"{base}.choices[{choice_index}].target_node_id",
                        f"unknown dialogue node id {target!r}",
                        root=root,
                    )
                )

    if isinstance(start, str) and start in id_to_index:
        reachable = {start}
        queue = [start]
        while queue:
            current = queue.pop(0)
            node_index = id_to_index.get(current)
            if node_index is None:
                continue
            node = nodes[node_index]
            if not isinstance(node, dict):
                continue
            next_node = node.get("next_node_id")
            if isinstance(next_node, str) and next_node in id_to_index and next_node not in reachable:
                reachable.add(next_node)
                queue.append(next_node)
            for choice in node.get("choices") or []:
                if not isinstance(choice, dict):
                    continue
                target = choice.get("target_node_id")
                if isinstance(target, str) and target in id_to_index and target not in reachable:
                    reachable.add(target)
                    queue.append(target)
        for node_index, node_id in enumerate(node_ids):
            if node_id not in reachable:
                diagnostics.append(
                    _diag(
                        "REACHABILITY",
                        path,
                        f"$.nodes[{node_index}].id",
                        f"dialogue node {node_id!r} is unreachable from start_node_id",
                        root=root,
                    )
                )


def _validate_record_semantics(
    diagnostics: list[Diagnostic],
    *,
    path: Path,
    record: dict[str, Any],
    index: dict[str, tuple[str, Path, dict[str, Any]]],
    project_root: Path,
    root: Path,
) -> None:
    record_type = record.get("type")

    if record_type == "character":
        for rel_index, rel in enumerate(record.get("relationships") or []):
            if isinstance(rel, dict):
                _require_record_ref(
                    diagnostics,
                    path=path,
                    pointer=f"$.relationships[{rel_index}].target_id",
                    content_id=rel.get("target_id"),
                    expected_type="character",
                    index=index,
                    root=root,
                )
        _check_local_duplicates(
            diagnostics, path=path, pointer="$.outcomes", ids=_local_ids(record.get("outcomes")), root=root
        )

    elif record_type == "dialogue":
        for part_index, participant in enumerate(record.get("participants") or []):
            _require_record_ref(
                diagnostics,
                path=path,
                pointer=f"$.participants[{part_index}]",
                content_id=participant if isinstance(participant, str) else None,
                expected_type="character",
                index=index,
                root=root,
            )
        _validate_dialogue(diagnostics, path=path, record=record, index=index, root=root)

    elif record_type == "bark_pool":
        _require_record_ref(
            diagnostics,
            path=path,
            pointer="$.owner_id",
            content_id=record.get("owner_id"),
            expected_type="character",
            index=index,
            root=root,
        )
        for loc_index, loc_id in enumerate(record.get("location_ids") or []):
            _require_record_ref(
                diagnostics,
                path=path,
                pointer=f"$.location_ids[{loc_index}]",
                content_id=loc_id if isinstance(loc_id, str) else None,
                expected_type="location",
                index=index,
                root=root,
            )
        _check_local_duplicates(
            diagnostics, path=path, pointer="$.entries", ids=_local_ids(record.get("entries")), root=root
        )
        for entry_index, entry in enumerate(record.get("entries") or []):
            if isinstance(entry, dict):
                _require_record_ref(
                    diagnostics,
                    path=path,
                    pointer=f"$.entries[{entry_index}].speaker_id",
                    content_id=entry.get("speaker_id"),
                    expected_type="character",
                    index=index,
                    root=root,
                )

    elif record_type == "quest":
        _check_local_duplicates(
            diagnostics, path=path, pointer="$.states", ids=_local_ids(record.get("states")), root=root
        )
        _check_local_duplicates(
            diagnostics, path=path, pointer="$.objectives", ids=_local_ids(record.get("objectives")), root=root
        )
        _check_local_duplicates(
            diagnostics, path=path, pointer="$.outcomes", ids=_local_ids(record.get("outcomes")), root=root
        )
        state_ids = set(_local_ids(record.get("states")))
        initial_state = record.get("initial_state")
        if isinstance(initial_state, str) and state_ids and initial_state not in state_ids:
            diagnostics.append(
                _diag(
                    "REFERENCE",
                    path,
                    "$.initial_state",
                    f"unknown quest state id {initial_state!r}",
                    root=root,
                )
            )
        _check_local_duplicates(
            diagnostics,
            path=path,
            pointer="$.transitions",
            ids=_local_ids(record.get("transitions")),
            root=root,
        )
        for transition_index, transition in enumerate(record.get("transitions") or []):
            if not isinstance(transition, dict):
                continue
            for field in ("from_state", "to_state"):
                state_id = transition.get(field)
                if isinstance(state_id, str) and state_ids and state_id not in state_ids:
                    diagnostics.append(
                        _diag(
                            "REFERENCE",
                            path,
                            f"$.transitions[{transition_index}].{field}",
                            f"unknown quest state id {state_id!r}",
                            root=root,
                        )
                    )
            for effect_index, effect in enumerate(transition.get("effects") or []):
                if (
                    isinstance(effect, dict)
                    and effect.get("op") == "set_quest_state"
                    and effect.get("key") == record.get("id")
                ):
                    diagnostics.append(
                        _diag(
                            "UNSUPPORTED_EFFECT",
                            path,
                            f"$.transitions[{transition_index}].effects[{effect_index}]",
                            "quest transitions must use to_state instead of setting their own quest state",
                            root=root,
                        )
                    )
        for obj_index, objective in enumerate(record.get("objectives") or []):
            if not isinstance(objective, dict):
                continue
            state_id = objective.get("state_id")
            if isinstance(state_id, str) and state_ids and state_id not in state_ids:
                diagnostics.append(
                    _diag(
                        "REFERENCE",
                        path,
                        f"$.objectives[{obj_index}].state_id",
                        f"unknown quest state id {state_id!r}",
                        root=root,
                    )
                )
        links = record.get("content_links") or {}
        link_fields = {
            "character_ids": "character",
            "dialogue_ids": "dialogue",
            "bark_ids": "bark_pool",
            "commission_ids": "commission",
            "item_ids": "item",
            "location_ids": "location",
        }
        for field, expected in link_fields.items():
            for link_index, content_id in enumerate(links.get(field) or []):
                _require_record_ref(
                    diagnostics,
                    path=path,
                    pointer=f"$.content_links.{field}[{link_index}]",
                    content_id=content_id if isinstance(content_id, str) else None,
                    expected_type=expected,
                    index=index,
                    root=root,
                )

    elif record_type == "item":
        _require_record_ref(
            diagnostics,
            path=path,
            pointer="$.owner_id",
            content_id=record.get("owner_id"),
            expected_type="character",
            index=index,
            root=root,
        )
        _require_record_ref(
            diagnostics,
            path=path,
            pointer="$.location_id",
            content_id=record.get("location_id"),
            expected_type="location",
            index=index,
            root=root,
        )

    elif record_type == "commission":
        _require_record_ref(
            diagnostics,
            path=path,
            pointer="$.client_id",
            content_id=record.get("client_id"),
            expected_type="character",
            index=index,
            root=root,
        )
        _require_record_ref(
            diagnostics,
            path=path,
            pointer="$.quest_id",
            content_id=record.get("quest_id"),
            expected_type="quest",
            index=index,
            root=root,
        )
        _require_record_ref(
            diagnostics,
            path=path,
            pointer="$.object_item_id",
            content_id=record.get("object_item_id"),
            expected_type="item",
            index=index,
            root=root,
        )
        _require_record_ref(
            diagnostics,
            path=path,
            pointer="$.location_id",
            content_id=record.get("location_id"),
            expected_type="location",
            index=index,
            root=root,
        )
        _check_local_duplicates(
            diagnostics,
            path=path,
            pointer="$.investigation_clues",
            ids=_local_ids(record.get("investigation_clues")),
            root=root,
        )
        _check_local_duplicates(
            diagnostics,
            path=path,
            pointer="$.forging_options",
            ids=_local_ids(record.get("forging_options")),
            root=root,
        )

    elif record_type == "location":
        for conn_index, loc_id in enumerate(record.get("connected_location_ids") or []):
            _require_record_ref(
                diagnostics,
                path=path,
                pointer=f"$.connected_location_ids[{conn_index}]",
                content_id=loc_id if isinstance(loc_id, str) else None,
                expected_type="location",
                index=index,
                root=root,
            )
        for occ_index, char_id in enumerate(record.get("occupant_ids") or []):
            _require_record_ref(
                diagnostics,
                path=path,
                pointer=f"$.occupant_ids[{occ_index}]",
                content_id=char_id if isinstance(char_id, str) else None,
                expected_type="character",
                index=index,
                root=root,
            )
        _check_local_duplicates(
            diagnostics,
            path=path,
            pointer="$.phase_states",
            ids=_local_ids(record.get("phase_states")),
            root=root,
        )
        _check_local_duplicates(
            diagnostics,
            path=path,
            pointer="$.spawn_ids",
            ids=[str(item) for item in (record.get("spawn_ids") or [])],
            root=root,
        )
        scene_path = record.get("scene_path")
        if isinstance(scene_path, str) and scene_path.startswith("res://"):
            rel = scene_path.removeprefix("res://")
            asset = (project_root / rel).resolve()
            try:
                asset.relative_to(project_root.resolve())
            except ValueError:
                diagnostics.append(
                    _diag(
                        "INPUT",
                        path,
                        "$.scene_path",
                        f"res:// path escapes project root: {scene_path!r}",
                        root=root,
                    )
                )
            else:
                if not asset.is_file():
                    diagnostics.append(
                        _diag(
                            "MISSING_ASSET",
                            path,
                            "$.scene_path",
                            f"scene file not found at {rel!r}",
                            root=root,
                        )
                    )

    def on_condition(pointer: str, condition: dict[str, Any]) -> None:
        _validate_condition_semantics(
            diagnostics, path=path, pointer=pointer, condition=condition, index=index, root=root
        )

    def on_effect(pointer: str, effect: dict[str, Any]) -> None:
        _validate_effect_semantics(
            diagnostics, path=path, pointer=pointer, effect=effect, index=index, root=root
        )

    _walk_conditions(record, "$", on_condition)
    _walk_effects(record, "$", on_effect)


def validate_corpus(
    paths: Sequence[str | Path],
    *,
    project_root: Path | None = None,
    schemas_dir: Path | None = None,
) -> list[Diagnostic]:
    """Validate JSON content under the given paths; return sorted diagnostics."""
    resolved_paths = [Path(path) for path in paths]
    records, diagnostics, corpus_root = load_corpus(resolved_paths)
    project_root = (project_root or ROOT).resolve()
    schemas_dir = (schemas_dir or SCHEMAS_DIR).resolve()
    store = SchemaStore(schemas_dir)

    index: dict[str, tuple[str, Path, dict[str, Any]]] = {}
    id_sources: dict[str, list[Path]] = {}

    for path, payload in sorted(records.items(), key=lambda item: item[0].as_posix().casefold()):
        if not isinstance(payload, dict):
            diagnostics.append(_diag("SCHEMA", path, "$", "top-level JSON value must be an object", root=corpus_root))
            continue

        has_unknown_ops = _scan_unknown_ops(diagnostics, path=path, record=payload, root=corpus_root)
        try:
            schema_name = schema_for_example(payload)
            schema = store.resolve(schema_name)
            validate_value(payload, schema, store)
        except SchemaValidationError as exc:
            if not (has_unknown_ops and _schema_error_is_unknown_op_enum(str(exc))):
                diagnostics.append(_diag("SCHEMA", path, "$", str(exc), root=corpus_root))
            continue

        content_id = payload.get("id")
        if isinstance(content_id, str):
            id_sources.setdefault(content_id, []).append(path)
            expected_type = _record_type_for_id(content_id)
            actual_type = payload.get("type")
            if expected_type and actual_type != expected_type:
                diagnostics.append(
                    _diag(
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
                    _diag(
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
        _validate_record_semantics(
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
