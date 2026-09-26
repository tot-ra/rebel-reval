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


_PERSISTENT_AREA_DELIVERY_FIELDS = {"kind", "radius", "duration_sec", "target_policy"}


def _validate_magic_persistent_area(context: RecordValidationContext) -> None:
    """Persistent areas pair placement, lifetime, and targeting with one timed impact."""
    effect = context.record.get("effect")
    if not isinstance(effect, dict):
        return
    delivery = effect.get("delivery")
    if not isinstance(delivery, dict):
        return
    impact = effect.get("impact")
    is_area = delivery.get("kind") == "persistent_area"
    heal_over_time = isinstance(impact, dict) and impact.get("kind") == "heal_over_time"
    if not is_area:
        for field in ("duration_sec", "target_policy"):
            if field in delivery:
                context.diagnose(
                    "MAGIC_EFFECT",
                    f"$.effect.delivery.{field}",
                    f"{field} is only valid on persistent_area delivery",
                )
        if heal_over_time:
            context.diagnose(
                "MAGIC_EFFECT",
                "$.effect.impact.kind",
                "heal_over_time is only delivered by persistent_area effects",
            )
        return
    for field in ("radius", "duration_sec"):
        if not _is_positive_number(delivery.get(field)):
            context.diagnose(
                "MAGIC_EFFECT",
                f"$.effect.delivery.{field}",
                f"persistent_area requires a positive {field}",
            )
    policy = delivery.get("target_policy")
    if policy not in {"ally", "hostile"}:
        context.diagnose(
            "MAGIC_EFFECT",
            "$.effect.delivery.target_policy",
            "persistent_area requires target_policy ally or hostile",
        )
    extra = sorted(key for key in delivery if key not in _PERSISTENT_AREA_DELIVERY_FIELDS)
    if extra:
        context.diagnose(
            "MAGIC_EFFECT",
            "$.effect.delivery",
            "persistent_area takes no projectile or summon fields: " + ", ".join(extra),
        )
    if effect.get("area") is not None:
        context.diagnose(
            "MAGIC_EFFECT",
            "$.effect.area",
            "persistent_area effects must not define a second area",
        )
    if not heal_over_time:
        # The runtime area only knows timed healing today; other timed modules
        # need their own adapter before content may author them.
        context.diagnose(
            "MAGIC_EFFECT",
            "$.effect.impact",
            "persistent_area requires a heal_over_time impact",
        )
        return
    for field in ("amount", "duration_sec", "tick_interval_sec"):
        if not _is_positive_number(impact.get(field)):
            context.diagnose(
                "MAGIC_EFFECT",
                f"$.effect.impact.{field}",
                f"heal_over_time requires a positive {field}",
            )
    interval = impact.get("tick_interval_sec")
    duration = impact.get("duration_sec")
    if _is_positive_number(interval) and _is_positive_number(duration) and interval > duration:
        context.diagnose(
            "MAGIC_EFFECT",
            "$.effect.impact.tick_interval_sec",
            "heal_over_time must tick at least once within its duration",
        )
    if "damage_type" in impact:
        context.diagnose(
            "MAGIC_EFFECT",
            "$.effect.impact.damage_type",
            "heal_over_time does not carry a damage_type",
        )
    if policy == "hostile":
        context.diagnose(
            "MAGIC_EFFECT",
            "$.effect.delivery.target_policy",
            "healing areas must target allies, not hostiles",
        )


_AREA_PULSE_DELIVERY_FIELDS = {"kind", "radius", "arc_deg"}
_AREA_PULSE_IMPACT_KINDS = {"stagger", "damage", "knockback"}
# Control modules only MagicAreaPulse2D applies; other adapters would drop them.
_AREA_PULSE_ONLY_IMPACT_KINDS = {"stagger", "knockback"}
# Keep area control a short interrupt, never a lock: an enemy's REACT beat is
# held for the full stagger window (MAGIC.md 5.3).
_MAX_STAGGER_SEC = 3.0
# Knockback is a shove, not a launch: the push stays inside a typical combat
# lane and its REACT hold stays shorter than a stagger (MAGIC.md 5.4).
_MAX_KNOCKBACK_DISTANCE = 160.0
_MAX_KNOCKBACK_SEC = 1.0


def _validate_magic_area_pulse(context: RecordValidationContext) -> None:
    """Immediate area pulses carry a radius and one stagger, damage, or knockback impact."""
    effect = context.record.get("effect")
    if not isinstance(effect, dict):
        return
    delivery = effect.get("delivery")
    if not isinstance(delivery, dict):
        return
    impact = effect.get("impact")
    impact_kind = impact.get("kind") if isinstance(impact, dict) else None
    if delivery.get("kind") != "area_pulse":
        if impact_kind in _AREA_PULSE_ONLY_IMPACT_KINDS:
            # Only MagicAreaPulse2D applies CombatStaggerEffect and
            # CombatKnockbackEffect; any other adapter would silently drop them.
            context.diagnose(
                "MAGIC_EFFECT",
                "$.effect.impact.kind",
                f"{impact_kind} is only delivered by area_pulse effects",
            )
        return
    if not _is_positive_number(delivery.get("radius")):
        context.diagnose(
            "MAGIC_EFFECT",
            "$.effect.delivery.radius",
            "area_pulse requires a positive radius",
        )
    extra = sorted(key for key in delivery if key not in _AREA_PULSE_DELIVERY_FIELDS)
    if extra:
        context.diagnose(
            "MAGIC_EFFECT",
            "$.effect.delivery",
            "area_pulse takes no projectile, summon, or lifetime fields: " + ", ".join(extra),
        )
    if "arc_deg" in delivery:
        arc = delivery.get("arc_deg")
        if not _is_positive_number(arc) or arc > 360:
            context.diagnose(
                "MAGIC_EFFECT",
                "$.effect.delivery.arc_deg",
                "area_pulse arc_deg must be in (0, 360]",
            )
    if effect.get("area") is not None:
        context.diagnose(
            "MAGIC_EFFECT",
            "$.effect.area",
            "area_pulse effects must not define a second area",
        )
    if impact_kind not in _AREA_PULSE_IMPACT_KINDS:
        context.diagnose(
            "MAGIC_EFFECT",
            "$.effect.impact",
            "area_pulse requires a stagger, damage, or knockback impact",
        )
        return
    if impact_kind == "damage":
        if not _is_positive_number(impact.get("amount")):
            context.diagnose(
                "MAGIC_EFFECT",
                "$.effect.impact.amount",
                "area_pulse damage requires a positive amount",
            )
        return
    max_duration = _MAX_STAGGER_SEC
    if impact_kind == "knockback":
        max_duration = _MAX_KNOCKBACK_SEC
        distance = impact.get("distance")
        if not _is_positive_number(distance):
            context.diagnose(
                "MAGIC_EFFECT",
                "$.effect.impact.distance",
                "knockback requires a positive distance",
            )
        elif distance > _MAX_KNOCKBACK_DISTANCE:
            context.diagnose(
                "MAGIC_EFFECT",
                "$.effect.impact.distance",
                f"knockback distance must not exceed {_MAX_KNOCKBACK_DISTANCE:g}",
            )
    elif "distance" in impact:
        context.diagnose(
            "MAGIC_EFFECT",
            "$.effect.impact.distance",
            "stagger does not carry distance",
        )
    duration = impact.get("duration_sec")
    if not _is_positive_number(duration):
        context.diagnose(
            "MAGIC_EFFECT",
            "$.effect.impact.duration_sec",
            f"{impact_kind} requires a positive duration_sec",
        )
    elif duration > max_duration:
        context.diagnose(
            "MAGIC_EFFECT",
            "$.effect.impact.duration_sec",
            f"{impact_kind} duration_sec must not exceed {max_duration:g}",
        )
    for field in ("amount", "damage_type", "tick_interval_sec"):
        if field in impact:
            context.diagnose(
                "MAGIC_EFFECT",
                f"$.effect.impact.{field}",
                f"{impact_kind} does not carry {field}",
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
        _validate_magic_persistent_area(context)
        _validate_magic_area_pulse(context)

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
        else:
            # WHY: schema accepts any spell.*/rite.* id. A grant or revoke that
            # names a missing cookbook entry would otherwise leave unlocks dangling.
            expected_type = "spell" if target_id.startswith("spell.") else "rite"
            context.require_ref("$.target_id", target_id, expected_type)
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
