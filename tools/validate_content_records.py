"""Per-record semantic validation for validate_content."""

from __future__ import annotations

from pathlib import Path
from typing import Any

from validate_content_common import (
    Diagnostic,
    check_local_duplicates,
    diag,
    local_ids,
    quest_state_ids,
    require_record_ref,
)
from validate_content_semantics import (
    validate_condition_semantics,
    validate_dialogue,
    validate_effect_semantics,
    walk_conditions,
    walk_effects,
)

def validate_record_semantics(
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
                require_record_ref(
                    diagnostics,
                    path=path,
                    pointer=f"$.relationships[{rel_index}].target_id",
                    content_id=rel.get("target_id"),
                    expected_type="character",
                    index=index,
                    root=root,
                )
        check_local_duplicates(
            diagnostics, path=path, pointer="$.outcomes", ids=local_ids(record.get("outcomes")), root=root
        )

    elif record_type == "dialogue":
        for part_index, participant in enumerate(record.get("participants") or []):
            require_record_ref(
                diagnostics,
                path=path,
                pointer=f"$.participants[{part_index}]",
                content_id=participant if isinstance(participant, str) else None,
                expected_type="character",
                index=index,
                root=root,
            )
        validate_dialogue(diagnostics, path=path, record=record, index=index, root=root)

    elif record_type == "bark_pool":
        require_record_ref(
            diagnostics,
            path=path,
            pointer="$.owner_id",
            content_id=record.get("owner_id"),
            expected_type="character",
            index=index,
            root=root,
        )
        for loc_index, loc_id in enumerate(record.get("location_ids") or []):
            require_record_ref(
                diagnostics,
                path=path,
                pointer=f"$.location_ids[{loc_index}]",
                content_id=loc_id if isinstance(loc_id, str) else None,
                expected_type="location",
                index=index,
                root=root,
            )
        check_local_duplicates(
            diagnostics, path=path, pointer="$.entries", ids=local_ids(record.get("entries")), root=root
        )
        for entry_index, entry in enumerate(record.get("entries") or []):
            if isinstance(entry, dict):
                require_record_ref(
                    diagnostics,
                    path=path,
                    pointer=f"$.entries[{entry_index}].speaker_id",
                    content_id=entry.get("speaker_id"),
                    expected_type="character",
                    index=index,
                    root=root,
                )

    elif record_type == "quest":
        check_local_duplicates(
            diagnostics, path=path, pointer="$.states", ids=local_ids(record.get("states")), root=root
        )
        check_local_duplicates(
            diagnostics, path=path, pointer="$.objectives", ids=local_ids(record.get("objectives")), root=root
        )
        check_local_duplicates(
            diagnostics, path=path, pointer="$.outcomes", ids=local_ids(record.get("outcomes")), root=root
        )
        state_ids = set(local_ids(record.get("states")))
        initial_state = record.get("initial_state")
        if isinstance(initial_state, str) and state_ids and initial_state not in state_ids:
            diagnostics.append(
                diag(
                    "REFERENCE",
                    path,
                    "$.initial_state",
                    f"unknown quest state id {initial_state!r}",
                    root=root,
                )
            )
        check_local_duplicates(
            diagnostics,
            path=path,
            pointer="$.transitions",
            ids=local_ids(record.get("transitions")),
            root=root,
        )
        for transition_index, transition in enumerate(record.get("transitions") or []):
            if not isinstance(transition, dict):
                continue
            for field in ("from_state", "to_state"):
                state_id = transition.get(field)
                if isinstance(state_id, str) and state_ids and state_id not in state_ids:
                    diagnostics.append(
                        diag(
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
                        diag(
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
                    diag(
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
                require_record_ref(
                    diagnostics,
                    path=path,
                    pointer=f"$.content_links.{field}[{link_index}]",
                    content_id=content_id if isinstance(content_id, str) else None,
                    expected_type=expected,
                    index=index,
                    root=root,
                )

    elif record_type == "item":
        require_record_ref(
            diagnostics,
            path=path,
            pointer="$.owner_id",
            content_id=record.get("owner_id"),
            expected_type="character",
            index=index,
            root=root,
        )
        require_record_ref(
            diagnostics,
            path=path,
            pointer="$.location_id",
            content_id=record.get("location_id"),
            expected_type="location",
            index=index,
            root=root,
        )

    elif record_type == "commission":
        require_record_ref(
            diagnostics,
            path=path,
            pointer="$.client_id",
            content_id=record.get("client_id"),
            expected_type="character",
            index=index,
            root=root,
        )
        require_record_ref(
            diagnostics,
            path=path,
            pointer="$.quest_id",
            content_id=record.get("quest_id"),
            expected_type="quest",
            index=index,
            root=root,
        )
        require_record_ref(
            diagnostics,
            path=path,
            pointer="$.object_item_id",
            content_id=record.get("object_item_id"),
            expected_type="item",
            index=index,
            root=root,
        )
        require_record_ref(
            diagnostics,
            path=path,
            pointer="$.location_id",
            content_id=record.get("location_id"),
            expected_type="location",
            index=index,
            root=root,
        )
        check_local_duplicates(
            diagnostics,
            path=path,
            pointer="$.investigation_clues",
            ids=local_ids(record.get("investigation_clues")),
            root=root,
        )
        check_local_duplicates(
            diagnostics,
            path=path,
            pointer="$.forging_options",
            ids=local_ids(record.get("forging_options")),
            root=root,
        )

    elif record_type == "mechanism":
        require_record_ref(
            diagnostics,
            path=path,
            pointer="$.commission_id",
            content_id=record.get("commission_id"),
            expected_type="commission",
            index=index,
            root=root,
        )
        require_record_ref(
            diagnostics,
            path=path,
            pointer="$.object_item_id",
            content_id=record.get("object_item_id"),
            expected_type="item",
            index=index,
            root=root,
        )
        require_record_ref(
            diagnostics,
            path=path,
            pointer="$.location_id",
            content_id=record.get("location_id"),
            expected_type="location",
            index=index,
            root=root,
        )
        check_local_duplicates(
            diagnostics,
            path=path,
            pointer="$.responses",
            ids=local_ids(record.get("responses")),
            root=root,
        )
        default_response = record.get("default_response")
        if isinstance(default_response, dict):
            check_local_duplicates(
                diagnostics,
                path=path,
                pointer="$.default_response",
                ids=[str(default_response.get("id", ""))],
                root=root,
            )

    elif record_type == "encounter":
        require_record_ref(
            diagnostics,
            path=path,
            pointer="$.quest_id",
            content_id=record.get("quest_id"),
            expected_type="quest",
            index=index,
            root=root,
        )
        resolved_flag = record.get("resolved_flag")
        if isinstance(resolved_flag, str) and not resolved_flag.startswith("flag."):
            diagnostics.append(
                diag(
                    "REFERENCE",
                    path,
                    "$.resolved_flag",
                    f"resolved_flag must use flag. prefix, got {resolved_flag!r}",
                    root=root,
                )
            )
        kind_ids: list[str] = []
        quest_id = record.get("quest_id")
        known_states = (
            quest_state_ids(index, quest_id) if isinstance(quest_id, str) else set()
        )
        for outcome_index, outcome in enumerate(record.get("outcomes") or []):
            if not isinstance(outcome, dict):
                continue
            kind = outcome.get("kind")
            if isinstance(kind, str):
                kind_ids.append(kind)
            quest_state = outcome.get("quest_state")
            if (
                isinstance(quest_state, str)
                and known_states
                and quest_state not in known_states
            ):
                diagnostics.append(
                    diag(
                        "REFERENCE",
                        path,
                        f"$.outcomes[{outcome_index}].quest_state",
                        f"unknown quest state id {quest_state!r} for {quest_id!r}",
                        root=root,
                    )
                )
        check_local_duplicates(
            diagnostics,
            path=path,
            pointer="$.outcomes",
            ids=kind_ids,
            root=root,
        )

    elif record_type == "location":
        for conn_index, loc_id in enumerate(record.get("connected_location_ids") or []):
            require_record_ref(
                diagnostics,
                path=path,
                pointer=f"$.connected_location_ids[{conn_index}]",
                content_id=loc_id if isinstance(loc_id, str) else None,
                expected_type="location",
                index=index,
                root=root,
            )
        for occ_index, char_id in enumerate(record.get("occupant_ids") or []):
            require_record_ref(
                diagnostics,
                path=path,
                pointer=f"$.occupant_ids[{occ_index}]",
                content_id=char_id if isinstance(char_id, str) else None,
                expected_type="character",
                index=index,
                root=root,
            )
        check_local_duplicates(
            diagnostics,
            path=path,
            pointer="$.phase_states",
            ids=local_ids(record.get("phase_states")),
            root=root,
        )
        check_local_duplicates(
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
                    diag(
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
                        diag(
                            "MISSING_ASSET",
                            path,
                            "$.scene_path",
                            f"scene file not found at {rel!r}",
                            root=root,
                        )
                    )

    def on_condition(pointer: str, condition: dict[str, Any]) -> None:
        validate_condition_semantics(
            diagnostics, path=path, pointer=pointer, condition=condition, index=index, root=root
        )

    def on_effect(pointer: str, effect: dict[str, Any]) -> None:
        validate_effect_semantics(
            diagnostics, path=path, pointer=pointer, effect=effect, index=index, root=root
        )

    walk_conditions(record, "$", on_condition)
    walk_effects(record, "$", on_effect)

