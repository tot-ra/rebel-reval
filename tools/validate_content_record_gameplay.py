"""Validators for gameplay content records."""

from __future__ import annotations

from validate_content_common import quest_state_ids
from validate_content_record_context import RecordValidationContext


def validate_item(context: RecordValidationContext) -> None:
    context.require_field_ref("owner_id", "character")
    context.require_field_ref("location_id", "location")


def validate_commission(context: RecordValidationContext) -> None:
    for field, expected_type in (
        ("client_id", "character"),
        ("quest_id", "quest"),
        ("object_item_id", "item"),
        ("location_id", "location"),
    ):
        context.require_field_ref(field, expected_type)
    context.check_record_duplicates("investigation_clues")
    context.check_record_duplicates("forging_options")


def validate_mechanism(context: RecordValidationContext) -> None:
    for field, expected_type in (
        ("commission_id", "commission"),
        ("object_item_id", "item"),
        ("location_id", "location"),
    ):
        context.require_field_ref(field, expected_type)
    context.check_record_duplicates("responses")

    default_response = context.record.get("default_response")
    if isinstance(default_response, dict):
        context.check_duplicates("$.default_response", [str(default_response.get("id", ""))])


def validate_encounter(context: RecordValidationContext) -> None:
    record = context.record
    context.require_field_ref("quest_id", "quest")

    resolved_flag = record.get("resolved_flag")
    if isinstance(resolved_flag, str) and not resolved_flag.startswith("flag."):
        context.diagnose(
            "REFERENCE",
            "$.resolved_flag",
            f"resolved_flag must use flag. prefix, got {resolved_flag!r}",
        )

    quest_id = record.get("quest_id")
    known_states = quest_state_ids(context.index, quest_id) if isinstance(quest_id, str) else set()
    outcome_kinds: list[str] = []
    for outcome_index, outcome in enumerate(record.get("outcomes") or []):
        if not isinstance(outcome, dict):
            continue
        kind = outcome.get("kind")
        if isinstance(kind, str):
            outcome_kinds.append(kind)
        quest_state = outcome.get("quest_state")
        if isinstance(quest_state, str) and known_states and quest_state not in known_states:
            context.diagnose(
                "REFERENCE",
                f"$.outcomes[{outcome_index}].quest_state",
                f"unknown quest state id {quest_state!r} for {quest_id!r}",
            )
    context.check_duplicates("$.outcomes", outcome_kinds)


# Spirit-duel word spells (ADR 0048, SPIRIT_DIALOGUE.md "Psychological spells and willpower").
# Light -> the duel element it guards (SPIRIT_SIGHT.md "The seven soul lights"); awareness is
# sight and guards none, so a spell on awareness takes its element from its other light.
SPIRIT_LIGHT_ELEMENT = {
    "aspect.nature": "fear",
    "aspect.affection": "coin",
    "aspect.tenacity": "duty",
    "aspect.unity": "love",
    "aspect.resonance": "shame",
    "aspect.awareness": None,
    "aspect.light": "faith",
}
# The five starters are today's word spells (SpiritWordSpells.DEFAULT_ELEMENTS): one per element,
# each the lowering half of its element at -2 for 1 willpower.
SPIRIT_STARTER_ELEMENTS = ("fear", "shame", "duty", "love", "faith")
SPIRIT_STARTER_DELTA = -2
SPIRIT_ANSWER_KINDS = ("attack", "defense", "feint", "appeal", "pressure", "evade")


def _spirit_line_key_ok(key: str) -> bool:
    if key in ("default", "weak"):
        return True
    if key.startswith("answer."):
        return key[len("answer."):] in SPIRIT_ANSWER_KINDS
    if key.startswith("topic."):
        topic = key[len("topic."):]
        return bool(topic) and all(ch.islower() or ch.isdigit() or ch == "_" for ch in topic)
    return False


def validate_spirit_spell(context: RecordValidationContext) -> None:
    record = context.record
    vector = record.get("light_vector") or []
    aspects: list[str] = []
    signs: set[int] = set()
    for index, entry in enumerate(vector):
        if not isinstance(entry, dict):
            continue
        aspects.append(str(entry.get("aspect", "")))
        delta = entry.get("delta")
        if delta == 0:
            context.diagnose("SPIRIT_SPELL", f"$.light_vector[{index}].delta", "delta must not be 0")
        elif isinstance(delta, int):
            signs.add(1 if delta > 0 else -1)
    context.check_duplicates("$.light_vector", aspects)

    expected_kind = None
    if signs == {-1}:
        expected_kind = "lowering"
    elif signs == {1}:
        expected_kind = "raising"
    elif signs == {-1, 1}:
        expected_kind = "mixed"
    kind = record.get("kind")
    if expected_kind is not None and kind != expected_kind:
        context.diagnose(
            "SPIRIT_SPELL",
            "$.kind",
            f"kind {kind!r} disagrees with the light_vector signs (expected {expected_kind!r})",
        )

    element = record.get("element")
    guarded = {SPIRIT_LIGHT_ELEMENT.get(aspect) for aspect in aspects}
    if element not in guarded:
        context.diagnose(
            "SPIRIT_SPELL",
            "$.element",
            f"element {element!r} is not guarded by any light of the spell ({', '.join(aspects)})",
        )

    lines = record.get("lines")
    if isinstance(lines, dict):
        for key in sorted(lines):
            if not _spirit_line_key_ok(key):
                context.diagnose(
                    "SPIRIT_SPELL",
                    f"$.lines.{key}",
                    "line context must be default, weak, answer.<move kind> or topic.<topic id>",
                )

    guilt = record.get("guilt")
    if isinstance(guilt, dict) and not any(int(value) > 0 for value in guilt.values()):
        context.diagnose("SPIRIT_SPELL", "$.guilt", "guilt must weigh at least one school above 0")

    if record.get("starter") is True:
        _validate_spirit_starter(context, record, vector)


def _validate_spirit_starter(context: RecordValidationContext, record: dict, vector: list) -> None:
    element = record.get("element")
    shape_ok = (
        element in SPIRIT_STARTER_ELEMENTS
        and record.get("kind") == "lowering"
        and record.get("cost") == 1
        and "guilt" not in record
        and len(vector) == 1
        and isinstance(vector[0], dict)
        and vector[0].get("delta") == SPIRIT_STARTER_DELTA
        and SPIRIT_LIGHT_ELEMENT.get(str(vector[0].get("aspect"))) == element
    )
    if not shape_ok:
        context.diagnose(
            "SPIRIT_SPELL",
            "$.starter",
            "a starter must be today's word: one of "
            f"{', '.join(SPIRIT_STARTER_ELEMENTS)}, its own light at {SPIRIT_STARTER_DELTA}, "
            "lowering, cost 1, no guilt",
        )
    # One starter per element across the corpus, so the five slots map one to one.
    own_id = record.get("id")
    for other_id, (other_type, _path, other) in sorted(context.index.items()):
        if other_id == own_id or other_type != "spirit_spell":
            continue
        if other.get("starter") is True and other.get("element") == element and str(other_id) < str(own_id):
            context.diagnose(
                "SPIRIT_SPELL",
                "$.starter",
                f"element {element!r} already has the starter {other_id!r}",
            )
            break
