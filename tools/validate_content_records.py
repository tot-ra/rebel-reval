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


def validate_magic(context: RecordValidationContext) -> None:
    """Keep the dual-school records closed even where JSON Schema is permissive."""
    record = context.record
    record_type = record.get("type")

    if record_type == "spell":
        if record.get("school") != "school.pagan":
            context.diagnose(
                "MAGIC_CONTRACT",
                "$.school",
                "pagan spells must use school.pagan",
            )
        sequence = record.get("sequence")
        if not isinstance(sequence, list) or not sequence:
            context.diagnose(
                "MAGIC_CONTRACT",
                "$.sequence",
                "pagan spells require an authored element sequence",
            )
    elif record_type == "rite":
        if record.get("school") != "school.divine":
            context.diagnose(
                "MAGIC_CONTRACT",
                "$.school",
                "rites must use school.divine",
            )
        tags = record.get("tags")
        if not isinstance(tags, list) or not tags:
            context.diagnose(
                "MAGIC_CONTRACT",
                "$.tags",
                "rites require authored element tags",
            )
        if record.get("fixed_liturgy") is not True:
            context.diagnose(
                "MAGIC_CONTRACT",
                "$.fixed_liturgy",
                "rites must declare fixed_liturgy true",
            )
        if "sequence" in record:
            context.diagnose(
                "MAGIC_CONTRACT",
                "$.sequence",
                "rites use fixed tags instead of a forge sequence",
            )
    elif record_type == "magic_grant":
        operation = record.get("operation")
        if operation not in {"grant", "revoke"}:
            context.diagnose(
                "MAGIC_CONTRACT",
                "$.operation",
                "magic grant records require operation grant or revoke",
            )
        target_id = record.get("target_id")
        if not isinstance(target_id, str) or not target_id.startswith(("spell.", "rite.")):
            context.diagnose(
                "MAGIC_CONTRACT",
                "$.target_id",
                "magic operations must target a spell or rite record",
            )
        grant_flag = record.get("grant_flag")
        if not isinstance(grant_flag, str) or not grant_flag.startswith("flag.magic."):
            context.diagnose(
                "MAGIC_CONTRACT",
                "$.grant_flag",
                "magic operations require a flag.magic.* grant flag",
            )

        record_id = record.get("id")
        if isinstance(record_id, str):
            expected_operation = None
            if record_id.startswith("magic.grant."):
                expected_operation = "grant"
            elif record_id.startswith("magic.revoke."):
                expected_operation = "revoke"
            if expected_operation is not None and operation != expected_operation:
                context.diagnose(
                    "MAGIC_CONTRACT",
                    "$.operation",
                    f"{record_id} must use operation {expected_operation}",
                )


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
    "spell": validate_magic,
    "rite": validate_magic,
    "magic_grant": validate_magic,
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
