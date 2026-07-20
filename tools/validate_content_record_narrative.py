"""Validators for narrative content records."""

from __future__ import annotations

from typing import Any

from validate_content_record_context import RecordValidationContext
from validate_content_semantics import validate_dialogue


QUEST_LINK_TYPES = {
    "character_ids": "character",
    "dialogue_ids": "dialogue",
    "bark_ids": "bark_pool",
    "commission_ids": "commission",
    "item_ids": "item",
    "location_ids": "location",
}


def validate_character(context: RecordValidationContext) -> None:
    record = context.record
    for rel_index, relationship in enumerate(record.get("relationships") or []):
        if isinstance(relationship, dict):
            context.require_ref(
                f"$.relationships[{rel_index}].target_id",
                relationship.get("target_id"),
                "character",
            )
    context.check_record_duplicates("outcomes")


def validate_dialogue_record(context: RecordValidationContext) -> None:
    record = context.record
    for participant_index, participant in enumerate(record.get("participants") or []):
        context.require_ref(
            f"$.participants[{participant_index}]",
            participant if isinstance(participant, str) else None,
            "character",
        )
    validate_dialogue(
        context.diagnostics,
        path=context.path,
        record=record,
        index=context.index,
        root=context.root,
    )


def validate_bark_pool(context: RecordValidationContext) -> None:
    record = context.record
    context.require_field_ref("owner_id", "character")
    for location_index, location_id in enumerate(record.get("location_ids") or []):
        context.require_ref(
            f"$.location_ids[{location_index}]",
            location_id if isinstance(location_id, str) else None,
            "location",
        )
    context.check_record_duplicates("entries")
    for entry_index, entry in enumerate(record.get("entries") or []):
        if isinstance(entry, dict):
            context.require_ref(
                f"$.entries[{entry_index}].speaker_id",
                entry.get("speaker_id"),
                "character",
            )


def validate_quest(context: RecordValidationContext) -> None:
    record = context.record
    context.check_record_duplicates("states")
    context.check_record_duplicates("objectives")
    context.check_record_duplicates("outcomes")

    state_ids = {
        str(state["id"])
        for state in record.get("states") or []
        if isinstance(state, dict) and "id" in state
    }
    initial_state = record.get("initial_state")
    if isinstance(initial_state, str) and state_ids and initial_state not in state_ids:
        _diagnose_unknown_state(context, "$.initial_state", initial_state)

    context.check_record_duplicates("transitions")
    for transition_index, transition in enumerate(record.get("transitions") or []):
        if not isinstance(transition, dict):
            continue
        for field in ("from_state", "to_state"):
            state_id = transition.get(field)
            if isinstance(state_id, str) and state_ids and state_id not in state_ids:
                _diagnose_unknown_state(context, f"$.transitions[{transition_index}].{field}", state_id)
        _reject_direct_self_state_effect(context, transition, transition_index)

    for objective_index, objective in enumerate(record.get("objectives") or []):
        if not isinstance(objective, dict):
            continue
        state_id = objective.get("state_id")
        if isinstance(state_id, str) and state_ids and state_id not in state_ids:
            _diagnose_unknown_state(context, f"$.objectives[{objective_index}].state_id", state_id)

    links = record.get("content_links") or {}
    for field, expected_type in QUEST_LINK_TYPES.items():
        for link_index, content_id in enumerate(links.get(field) or []):
            context.require_ref(
                f"$.content_links.{field}[{link_index}]",
                content_id if isinstance(content_id, str) else None,
                expected_type,
            )


def _diagnose_unknown_state(context: RecordValidationContext, pointer: str, state_id: str) -> None:
    context.diagnose("REFERENCE", pointer, f"unknown quest state id {state_id!r}")


def _reject_direct_self_state_effect(
    context: RecordValidationContext,
    transition: dict[str, Any],
    transition_index: int,
) -> None:
    for effect_index, effect in enumerate(transition.get("effects") or []):
        if (
            isinstance(effect, dict)
            and effect.get("op") == "set_quest_state"
            and effect.get("key") == context.record.get("id")
        ):
            context.diagnose(
                "UNSUPPORTED_EFFECT",
                f"$.transitions[{transition_index}].effects[{effect_index}]",
                "quest transitions must use to_state instead of setting their own quest state",
            )
