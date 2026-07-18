"""Shared types, constants, and reference helpers for content validation."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any

RECORD_TYPE_BY_PREFIX = {
    "char.": "character",
    "dialogue.": "dialogue",
    "bark.": "bark_pool",
    "quest.": "quest",
    "item.": "item",
    "commission.": "commission",
    "loc.": "location",
    "mechanism.": "mechanism",
    "phase_profile.": "phase_profile",
    "slicephase.": "phase_profile",
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
    "forged_modification_is",
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
    "forged_modification_is": {
        "required": {"key", "value"},
        "forbidden": {"amount"},
        "key_prefix": "commission.",
        "value_type": str,
        "commission_ref": True,
        "forging_option": True,
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


def diag(code: str, path: Path, pointer: str, message: str, *, root: Path) -> Diagnostic:
    try:
        rel = path.relative_to(root)
        display = rel.as_posix()
    except ValueError:
        display = path.as_posix()
    return Diagnostic(code=code, path=display, pointer=pointer, message=message)


def record_type_for_id(content_id: str) -> str | None:
    for prefix, record_type in RECORD_TYPE_BY_PREFIX.items():
        if content_id.startswith(prefix):
            return record_type
    return None


def local_ids(items: list[dict[str, Any]] | None, field: str = "id") -> list[str]:
    if not items:
        return []
    return [str(item[field]) for item in items if isinstance(item, dict) and field in item]


def check_local_duplicates(
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
                diag(
                    "DUPLICATE_ID",
                    path,
                    f"{pointer}[{index}].id",
                    f"duplicate local id {local_id!r} (first at index {seen[local_id]})",
                    root=root,
                )
            )
        else:
            seen[local_id] = index


def record_ref_valid(
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
            diag(
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
            diag(
                "REFERENCE",
                path,
                pointer,
                f"expected {expected_type} id, got {actual_type} record {content_id!r}",
                root=root,
            )
        )
        return False
    return True


def require_record_ref(
    diagnostics: list[Diagnostic],
    *,
    path: Path,
    pointer: str,
    content_id: str | None,
    expected_type: str,
    index: dict[str, tuple[str, Path, dict[str, Any]]],
    root: Path,
) -> None:
    record_ref_valid(
        diagnostics,
        path=path,
        pointer=pointer,
        content_id=content_id,
        expected_type=expected_type,
        index=index,
        root=root,
    )


def quest_state_ids(index: dict[str, tuple[str, Path, dict[str, Any]]], quest_id: str) -> set[str]:
    entry = index.get(quest_id)
    if entry is None:
        return set()
    _, _, record = entry
    return set(local_ids(record.get("states")))


def commission_forging_option_ids(index: dict[str, tuple[str, Path, dict[str, Any]]], commission_id: str) -> set[str]:
    entry = index.get(commission_id)
    if entry is None:
        return set()
    _, _, record = entry
    return {
        str(option["id"])
        for option in (record.get("forging_options") or [])
        if isinstance(option, dict) and "id" in option
    }


def location_state_ids(index: dict[str, tuple[str, Path, dict[str, Any]]], location_id: str) -> set[str]:
    entry = index.get(location_id)
    if entry is None:
        return set()
    _, _, record = entry
    return set(local_ids(record.get("phase_states")))
