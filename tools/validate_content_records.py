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


def _validate_magic_summon_effect(context: RecordValidationContext) -> None:
    """Fail closed on authored summon lifecycle and adapter identity."""
    effect = context.record.get("effect")
    if not isinstance(effect, dict):
        return
    delivery = effect.get("delivery")
    if not isinstance(delivery, dict) or delivery.get("kind") != "summon":
        return
    if delivery.get("summon_kind") != "illusionary_double":
        context.diagnose(
            "MAGIC_EFFECT",
            "$.effect.delivery.summon_kind",
            "summon requires the supported authored summon_kind illusionary_double",
        )
    for field in ("lifetime_sec", "health", "collision_radius", "aggro_radius"):
        value = delivery.get(field)
        if not _is_positive_number(value):
            context.diagnose(
                "MAGIC_EFFECT",
                f"$.effect.delivery.{field}",
                f"summon requires a positive {field}",
            )
    spawn_offset = delivery.get("spawn_offset")
    if not _is_non_negative_number(spawn_offset):
        context.diagnose(
            "MAGIC_EFFECT",
            "$.effect.delivery.spawn_offset",
            "summon requires a non-negative spawn_offset",
        )
    if effect.get("impact") is not None:
        context.diagnose(
            "MAGIC_EFFECT",
            "$.effect.impact",
            "summon effects must not define a direct impact",
        )


def _validate_magic_self_modifier(context: RecordValidationContext) -> None:
    """Self delivery carries exactly one timed modifier and nothing that hits others."""
    effect = context.record.get("effect")
    if not isinstance(effect, dict):
        return
    delivery = effect.get("delivery")
    is_self = isinstance(delivery, dict) and delivery.get("kind") == "self"
    modifier = effect.get("modifier")
    if not is_self:
        if modifier is not None:
            context.diagnose(
                "MAGIC_EFFECT",
                "$.effect.modifier",
                "timed modifiers are only delivered by self effects",
            )
        return
    if not isinstance(modifier, dict):
        context.diagnose(
            "MAGIC_EFFECT",
            "$.effect.modifier",
            "self delivery requires an authored timed modifier",
        )
    else:
        stacking = modifier.get("stacking")
        max_stacks = modifier.get("max_stacks")
        if stacking == "stack" and not (isinstance(max_stacks, int) and max_stacks >= 2):
            context.diagnose(
                "MAGIC_EFFECT",
                "$.effect.modifier.max_stacks",
                "stack modifiers require max_stacks of at least 2",
            )
        if stacking == "replace" and max_stacks not in (None, 1):
            context.diagnose(
                "MAGIC_EFFECT",
                "$.effect.modifier.max_stacks",
                "replace modifiers cannot declare more than one stack",
            )
    for field in ("impact", "area"):
        if effect.get(field) is not None:
            context.diagnose(
                "MAGIC_EFFECT",
                f"$.effect.{field}",
                f"self effects must not define {field}",
            )
    extra = sorted(key for key in delivery if key != "kind")
    if extra:
        context.diagnose(
            "MAGIC_EFFECT",
            "$.effect.delivery",
            "self delivery takes no placement fields: " + ", ".join(extra),
        )


def _is_positive_number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and value > 0


def _is_non_negative_number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and value >= 0


def validate_magic(context: RecordValidationContext) -> None:
    """Keep the dual-school records closed even where JSON Schema is permissive."""
    record = context.record
    record_type = record.get("type")

    if record_type in {"spell", "rite"}:
        _validate_magic_summon_effect(context)
        _validate_magic_self_modifier(context)

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
