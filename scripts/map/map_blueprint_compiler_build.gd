class_name MapBlueprintCompilerBuild
extends RefCounted

## MapDefinition assembly from expanded compiler buckets.


static func build_definition(blueprint: MapBlueprint, expanded: Dictionary) -> MapDefinition:
	var definition := MapDefinition.new()
	definition.map_id = blueprint.map_id
	definition.location = blueprint.location
	definition.scope = blueprint.scope
	definition.active = blueprint.active
	definition.seed = blueprint.seed
	definition.palette = blueprint.palette
	definition.size_cells = blueprint.size_cells
	definition.base_terrain = blueprint.base_terrain
	definition.cell_size = blueprint.cell_size
	definition.ground_elevation = blueprint.ground_elevation

	var terrain: Array = expanded["terrain"]
	terrain.sort_custom(MapBlueprintCompiler._compare_terrain)
	for entry in terrain:
		var zone := {"terrain": entry["terrain"], "rect": entry["rect"]}
		if entry.has("style_variant"):
			zone["style_variant"] = entry["style_variant"]
		if entry.has("movement_speed_multiplier"):
			zone["movement_speed_multiplier"] = entry["movement_speed_multiplier"]
		definition.zones.append(zone)

	var buildings: Array = expanded["buildings"]
	buildings.sort_custom(MapBlueprintCompiler._compare_id_records)
	for values in buildings:
		definition.buildings.append(_compile_building(values, definition))
	var props: Array = expanded["props"]
	props.sort_custom(MapBlueprintCompiler._compare_id_records)
	for values in props:
		definition.props.append(_compile_prop(values, definition))

	var spawns: Array = expanded["spawns"]
	spawns.sort_custom(MapBlueprintCompiler._compare_id_records)
	if spawns.size() == 1:
		definition.player_spawn = MapBlueprintCompiler._placement_position(spawns[0], definition.cell_size)
		definition.set_meta("player_spawn_id", spawns[0]["id"])
	elif spawns.is_empty():
		# MapDefinition treats Vector2.ZERO as missing, so source validation keeps
		# this error tied to the authored primitive rather than a runtime index.
		definition.player_spawn = Vector2.ZERO
	else:
		definition.player_spawn = MapBlueprintCompiler._placement_position(spawns[0], definition.cell_size)

	var transitions: Array = expanded["transitions"]
	transitions.sort_custom(MapBlueprintCompiler._compare_id_records)
	for values in transitions:
		definition.transitions.append(_compile_transition(values, definition))
	var anchors: Array = expanded["anchors"]
	anchors.sort_custom(MapBlueprintCompiler._compare_id_records)
	for values in anchors:
		definition.interaction_anchors.append(_compile_anchor(values, definition))
	var patrols: Array = expanded["patrols"]
	patrols.sort_custom(MapBlueprintCompiler._compare_id_records)
	for values in patrols:
		var points: Array[Vector2] = []
		var point_rects: Variant = values.get("point_rects")
		if point_rects is Array and not point_rects.is_empty():
			for rect in point_rects:
				points.append(MapBlueprintCompiler._rect_center(rect, definition.cell_size))
		else:
			for cell in values["points"]:
				points.append(MapBlueprintCompiler._cell_center(cell, definition.cell_size))
		definition.patrols.append({"id": values["id"], "points": points})

	var signs: Array = expanded["signs"]
	signs.sort_custom(MapBlueprintCompiler._compare_id_records)
	for values in signs:
		definition.direction_signs.append(_compile_sign(values, definition))
	var landmarks: Array = expanded["landmarks"]
	landmarks.sort_custom(MapBlueprintCompiler._compare_id_records)
	for values in landmarks:
		definition.view_landmarks.append(_compile_landmark(values, definition))

	var exclusions: Array = expanded["exclusions"]
	exclusions.sort_custom(MapBlueprintCompiler._compare_id_records)
	for values in exclusions:
		definition.excluded_areas.append(values["rect"])
	var fades: Array = expanded["fades"]
	fades.sort_custom(MapBlueprintCompiler._compare_id_records)
	for values in fades:
		definition.fade_volumes.append({"id": values["id"], "rect": definition.cell_rect_to_world_rect(values["rect"])})

	definition.source_references = blueprint.source_references.duplicate()
	definition.source_references.sort()
	definition.surroundings_sides = blueprint.surroundings_sides.duplicate()
	definition.surroundings_town_sides = _town_sides_from_surroundings(definition.surroundings_sides)
	var camera_cells := blueprint.authored_camera_bounds if blueprint.has_authored_camera_bounds else Rect2i(Vector2i.ZERO, blueprint.size_cells)
	definition.camera_bounds = definition.cell_rect_to_world_rect(camera_cells)
	definition.fingerprint = _fingerprint(definition)
	return definition


static func _compile_building(values: Dictionary, definition: MapDefinition) -> Dictionary:
	var output := {"id": values["id"], "kind": values["kind"], "footprint": definition.cell_rect_to_world_rect(values["rect"])}
	_copy_fields(values, output, [&"wall_height", &"wall_height_scale", &"wall_color", &"roof_color", &"door_side", &"ridge_axis", &"primitive", &"tower", &"wall_material", &"roof_material", &"faction"])
	return output


static func _compile_prop(values: Dictionary, definition: MapDefinition) -> Dictionary:
	var output := {
		"id": values["id"],
		"kind": values["kind"],
		"position": MapBlueprintCompiler._placement_position(values, definition.cell_size),
	}
	_copy_fields(values, output, [&"facing", &"style_variant", &"visual_offset_px", &"primitive", &"movement_speed_multiplier", &"faction"])
	if values.has("rect") and values["rect"] is Rect2i:
		output["footprint"] = definition.cell_rect_to_world_rect(values["rect"])
	return output


static func _compile_transition(values: Dictionary, definition: MapDefinition) -> Dictionary:
	var output := {"id": values["id"], "rect": definition.cell_rect_to_world_rect(values["rect"])}
	_copy_non_empty_names(values, output, [&"destination_scene_id", &"destination_spawn_id", &"spawn_id", &"building_id", &"transition_visual", &"view_landmark_id", &"alignment"])
	if values.has("spawn_offset_px"):
		output["spawn_offset"] = values["spawn_offset_px"]
	if bool(values.get("highlight_area", false)):
		output["highlight_area"] = true
	var transition_visual: StringName = values.get("transition_visual", MapTypes.TRANSITION_VISUAL_DOOR)
	if transition_visual != MapTypes.TRANSITION_VISUAL_DOOR:
		output["transition_visual"] = transition_visual
	return output


static func _compile_anchor(values: Dictionary, definition: MapDefinition) -> Dictionary:
	var output := {"id": values["id"], "position": MapBlueprintCompiler._placement_position(values, definition.cell_size)}
	if not String(values.get("kind", "")).is_empty():
		output["kind"] = values["kind"]
	return output


static func _compile_sign(values: Dictionary, definition: MapDefinition) -> Dictionary:
	var direction := Vector2(values["direction"]).normalized()
	return {
		"id": values["id"],
		"text": values["text"],
		"position": MapBlueprintCompiler._placement_position(values, definition.cell_size),
		"direction": direction,
	}


static func _compile_landmark(values: Dictionary, definition: MapDefinition) -> Dictionary:
	var output := {"id": values["id"], "kind": values["kind"], "rect": definition.cell_rect_to_world_rect(values["rect"])}
	_copy_fields(values, output, [&"wall_color", &"top_px", &"door_material", &"passage_axis"])
	return output


static func _copy_fields(source: Dictionary, destination: Dictionary, keys: Array[StringName]) -> void:
	for key in keys:
		if source.has(key):
			destination[key] = source[key]


static func _copy_non_empty_names(source: Dictionary, destination: Dictionary, keys: Array[StringName]) -> void:
	for key in keys:
		if source.has(key) and not String(source[key]).is_empty():
			destination[key] = source[key]


static func _fingerprint(definition: MapDefinition) -> String:
	var payload := {
		"compiler_version": MapBlueprintCompiler.COMPILER_VERSION,
		"map_id": definition.map_id,
		"location": definition.location,
		"scope": definition.scope,
		"active": definition.active,
		"seed": definition.seed,
		"palette": definition.palette,
		"size_cells": definition.size_cells,
		"cell_size": definition.cell_size,
		"base_terrain": definition.base_terrain,
		"ground_elevation": definition.ground_elevation,
		"zones": definition.zones,
		"buildings": definition.buildings,
		"props": definition.props,
		"player_spawn": definition.player_spawn,
		"player_spawn_id": definition.get_meta("player_spawn_id", &""),
		"transitions": definition.transitions,
		"direction_signs": definition.direction_signs,
		"excluded_areas": definition.excluded_areas,
		"patrols": definition.patrols,
		"interaction_anchors": definition.interaction_anchors,
		"camera_bounds": definition.camera_bounds,
		"fade_volumes": definition.fade_volumes,
		"source_references": definition.source_references,
		"view_landmarks": definition.view_landmarks,
		"surroundings_town_sides": definition.surroundings_town_sides,
		"surroundings_sides": definition.surroundings_sides,
	}
	return MapParitySnapshot.serialize_value(payload).sha256_text()


static func _town_sides_from_surroundings(sides: Dictionary) -> Array[StringName]:
	var town_sides: Array[StringName] = []
	for side in MapDefinition.WORLD_SIDES:
		if sides.get(side) == &"town":
			town_sides.append(side)
	town_sides.sort_custom(MapBlueprintCompiler._compare_string_values)
	return town_sides
