"""Validators for world content records."""

from __future__ import annotations

from validate_content_record_context import RecordValidationContext


def validate_location(context: RecordValidationContext) -> None:
    record = context.record
    for connection_index, location_id in enumerate(record.get("connected_location_ids") or []):
        context.require_ref(
            f"$.connected_location_ids[{connection_index}]",
            location_id if isinstance(location_id, str) else None,
            "location",
        )
    for occupant_index, character_id in enumerate(record.get("occupant_ids") or []):
        context.require_ref(
            f"$.occupant_ids[{occupant_index}]",
            character_id if isinstance(character_id, str) else None,
            "character",
        )
    context.check_record_duplicates("phase_states")
    context.check_duplicates("$.spawn_ids", [str(item) for item in record.get("spawn_ids") or []])
    _validate_scene_path(context)


def _validate_scene_path(context: RecordValidationContext) -> None:
    scene_path = context.record.get("scene_path")
    if not isinstance(scene_path, str) or not scene_path.startswith("res://"):
        return

    relative_path = scene_path.removeprefix("res://")
    asset = (context.project_root / relative_path).resolve()
    try:
        asset.relative_to(context.project_root.resolve())
    except ValueError:
        context.diagnose(
            "INPUT",
            "$.scene_path",
            f"res:// path escapes project root: {scene_path!r}",
        )
    else:
        if not asset.is_file():
            context.diagnose(
                "MISSING_ASSET",
                "$.scene_path",
                f"scene file not found at {relative_path!r}",
            )
