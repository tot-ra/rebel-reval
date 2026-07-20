"""Dispatch per-record semantic validation by content domain."""

from __future__ import annotations

from pathlib import Path
from typing import Any, Callable

from validate_content_common import Diagnostic
from validate_content_record_context import RecordValidationContext
from validate_content_record_gameplay import (
    validate_commission,
    validate_encounter,
    validate_item,
    validate_mechanism,
)
from validate_content_record_narrative import (
    validate_bark_pool,
    validate_character,
    validate_dialogue_record,
    validate_quest,
)
from validate_content_record_world import validate_location
from validate_content_semantics import (
    validate_condition_semantics,
    validate_effect_semantics,
    walk_conditions,
    walk_effects,
)

RecordValidator = Callable[[RecordValidationContext], None]

RECORD_VALIDATORS: dict[str, RecordValidator] = {
    "character": validate_character,
    "dialogue": validate_dialogue_record,
    "bark_pool": validate_bark_pool,
    "quest": validate_quest,
    "item": validate_item,
    "commission": validate_commission,
    "mechanism": validate_mechanism,
    "encounter": validate_encounter,
    "location": validate_location,
}


def validate_record_semantics(
    diagnostics: list[Diagnostic],
    *,
    path: Path,
    record: dict[str, Any],
    index: dict[str, tuple[str, Path, dict[str, Any]]],
    project_root: Path,
    root: Path,
) -> None:
    """Validate one schema-valid record without changing the public validator API."""
    context = RecordValidationContext(
        diagnostics=diagnostics,
        path=path,
        record=record,
        index=index,
        project_root=project_root,
        root=root,
    )
    record_type = record.get("type")
    validator = RECORD_VALIDATORS.get(record_type) if isinstance(record_type, str) else None
    if validator is not None:
        validator(context)

    walk_conditions(
        record,
        "$",
        lambda pointer, condition: validate_condition_semantics(
            diagnostics,
            path=path,
            pointer=pointer,
            condition=condition,
            index=index,
            root=root,
        ),
    )
    walk_effects(
        record,
        "$",
        lambda pointer, effect: validate_effect_semantics(
            diagnostics,
            path=path,
            pointer=pointer,
            effect=effect,
            index=index,
            root=root,
        ),
    )
