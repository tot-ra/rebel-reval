"""Condition/effect semantics and dialogue validation for validate_content."""

from __future__ import annotations

from pathlib import Path
from typing import Any, Callable

from validate_content_common import (
    CONDITION_LIST_KEYS,
    CONDITION_OPS,
    CONDITION_RULES,
    EFFECT_LIST_KEYS,
    EFFECT_OPS,
    EFFECT_RULES,
    Diagnostic,
    check_local_duplicates,
    commission_forging_option_ids,
    diag,
    local_ids,
    location_state_ids,
    quest_state_ids,
    record_ref_valid,
    require_record_ref,
)


def schema_error_is_unknown_op_enum(message: str) -> bool:
    return ".op" in message and "is not one of" in message


def scan_unknown_ops(
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
                                diag(
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
                                diag(
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


def validate_condition_semantics(
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
        diagnostics.append(diag("UNSUPPORTED_CONDITION", path, pointer, f"unknown op {op!r}", root=root))
        return

    rules = CONDITION_RULES[op]
    for required in rules.get("required", set()):
        if required not in condition:
            diagnostics.append(
                diag("UNSUPPORTED_CONDITION", path, pointer, f"{op} requires {required!r}", root=root)
            )
    for forbidden in rules.get("forbidden", set()):
        if forbidden in condition:
            diagnostics.append(
                diag("UNSUPPORTED_CONDITION", path, pointer, f"{op} must not include {forbidden!r}", root=root)
            )

    key = condition.get("key")
    prefix = rules.get("key_prefix")
    if prefix and isinstance(key, str) and not key.startswith(prefix):
        diagnostics.append(
            diag(
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
            diag(
                "UNSUPPORTED_CONDITION",
                path,
                f"{pointer}.value",
                f"{op} value must be {value_type.__name__}",
                root=root,
            )
        )

    if rules.get("item_ref") and isinstance(key, str):
        require_record_ref(
            diagnostics,
            path=path,
            pointer=f"{pointer}.key",
            content_id=key,
            expected_type="item",
            index=index,
            root=root,
        )

    if rules.get("quest_state") and isinstance(key, str):
        if record_ref_valid(
            diagnostics,
            path=path,
            pointer=f"{pointer}.key",
            content_id=key,
            expected_type="quest",
            index=index,
            root=root,
        ) and isinstance(condition.get("value"), str):
            if condition["value"] not in quest_state_ids(index, key):
                diagnostics.append(
                    diag(
                        "UNSUPPORTED_CONDITION",
                        path,
                        f"{pointer}.value",
                        f"quest {key!r} has no state {condition['value']!r}",
                        root=root,
                    )
                )

    if rules.get("commission_ref") and isinstance(key, str):
        require_record_ref(
            diagnostics,
            path=path,
            pointer=f"{pointer}.key",
            content_id=key,
            expected_type="commission",
            index=index,
            root=root,
        )

    if rules.get("forging_option") and isinstance(key, str) and isinstance(condition.get("value"), str):
        if record_ref_valid(
            diagnostics,
            path=path,
            pointer=f"{pointer}.key",
            content_id=key,
            expected_type="commission",
            index=index,
            root=root,
        ):
            valid_ids = commission_forging_option_ids(index, key)
            if condition["value"] not in valid_ids:
                diagnostics.append(
                    diag(
                        "UNSUPPORTED_CONDITION",
                        path,
                        f"{pointer}.value",
                        f"commission {key!r} has no forging option {condition['value']!r}",
                        root=root,
                    )
                )


def validate_effect_semantics(
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
        diagnostics.append(diag("UNSUPPORTED_EFFECT", path, pointer, f"unknown op {op!r}", root=root))
        return

    rules = EFFECT_RULES[op]
    for required in rules.get("required", set()):
        if required not in effect:
            diagnostics.append(
                diag("UNSUPPORTED_EFFECT", path, pointer, f"{op} requires {required!r}", root=root)
            )
    for forbidden in rules.get("forbidden", set()):
        if forbidden in effect:
            diagnostics.append(
                diag("UNSUPPORTED_EFFECT", path, pointer, f"{op} must not include {forbidden!r}", root=root)
            )

    key = effect.get("key")
    prefix = rules.get("key_prefix")
    if prefix and isinstance(key, str) and not key.startswith(prefix):
        diagnostics.append(
            diag(
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
            diag(
                "UNSUPPORTED_EFFECT",
                path,
                f"{pointer}.value",
                f"{op} value must be {value_type.__name__}",
                root=root,
            )
        )

    if rules.get("item_ref") and isinstance(key, str):
        require_record_ref(
            diagnostics,
            path=path,
            pointer=f"{pointer}.key",
            content_id=key,
            expected_type="item",
            index=index,
            root=root,
        )

    if rules.get("quest_state") and isinstance(key, str):
        if record_ref_valid(
            diagnostics,
            path=path,
            pointer=f"{pointer}.key",
            content_id=key,
            expected_type="quest",
            index=index,
            root=root,
        ) and isinstance(effect.get("value"), str):
            if effect["value"] not in quest_state_ids(index, key):
                diagnostics.append(
                    diag(
                        "UNSUPPORTED_EFFECT",
                        path,
                        f"{pointer}.value",
                        f"quest {key!r} has no state {effect['value']!r}",
                        root=root,
                    )
                )

    if rules.get("location_state") and isinstance(key, str):
        if record_ref_valid(
            diagnostics,
            path=path,
            pointer=f"{pointer}.key",
            content_id=key,
            expected_type="location",
            index=index,
            root=root,
        ) and isinstance(effect.get("value"), str):
            if effect["value"] not in location_state_ids(index, key):
                diagnostics.append(
                    diag(
                        "UNSUPPORTED_EFFECT",
                        path,
                        f"{pointer}.value",
                        f"location {key!r} has no phase state {effect['value']!r}",
                        root=root,
                    )
                )


def walk_operation_lists(
    obj: Any,
    pointer: str,
    list_keys: frozenset[str],
    sink: Callable[[str, dict[str, Any]], None],
) -> None:
    """Visit operation objects only inside schema-defined operation arrays."""
    if isinstance(obj, dict):
        for key, value in obj.items():
            child_pointer = f"{pointer}.{key}"
            if key in list_keys and isinstance(value, list):
                for index, item in enumerate(value):
                    if isinstance(item, dict):
                        sink(f"{child_pointer}[{index}]", item)
            else:
                walk_operation_lists(value, child_pointer, list_keys, sink)
    elif isinstance(obj, list):
        for index, item in enumerate(obj):
            walk_operation_lists(item, f"{pointer}[{index}]", list_keys, sink)


def walk_conditions(
    obj: Any,
    pointer: str,
    sink: Callable[[str, dict[str, Any]], None],
) -> None:
    walk_operation_lists(obj, pointer, CONDITION_LIST_KEYS, sink)


def walk_effects(
    obj: Any,
    pointer: str,
    sink: Callable[[str, dict[str, Any]], None],
) -> None:
    walk_operation_lists(obj, pointer, EFFECT_LIST_KEYS, sink)


def validate_dialogue(
    diagnostics: list[Diagnostic],
    *,
    path: Path,
    record: dict[str, Any],
    index: dict[str, tuple[str, Path, dict[str, Any]]],
    root: Path,
) -> None:
    nodes = record.get("nodes") or []
    node_ids = local_ids(nodes)
    check_local_duplicates(diagnostics, path=path, pointer="$.nodes", ids=node_ids, root=root)

    id_to_index = {node_id: idx for idx, node_id in enumerate(node_ids)}
    start = record.get("start_node_id")
    if isinstance(start, str) and start not in id_to_index:
        diagnostics.append(
            diag("REFERENCE", path, "$.start_node_id", f"unknown dialogue node id {start!r}", root=root)
        )

    for node_index, node in enumerate(nodes):
        if not isinstance(node, dict):
            continue
        base = f"$.nodes[{node_index}]"
        speaker = node.get("speaker_id")
        if speaker:
            require_record_ref(
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
                diag("REFERENCE", path, f"{base}.next_node_id", f"unknown dialogue node id {next_node!r}", root=root)
            )
        choices = node.get("choices") or []
        choice_ids = local_ids(choices)
        check_local_duplicates(diagnostics, path=path, pointer=f"{base}.choices", ids=choice_ids, root=root)
        for choice_index, choice in enumerate(choices):
            if not isinstance(choice, dict):
                continue
            target = choice.get("target_node_id")
            if isinstance(target, str) and target not in id_to_index:
                diagnostics.append(
                    diag(
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
                    diag(
                        "REACHABILITY",
                        path,
                        f"$.nodes[{node_index}].id",
                        f"dialogue node {node_id!r} is unreachable from start_node_id",
                        root=root,
                    )
                )
