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
