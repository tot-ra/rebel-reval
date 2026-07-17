class_name MapBlueprintSemanticValidator
extends RefCounted

## Strict checks that require canonical compiled output or cross-map registries.
## Source-shape errors remain in MapBlueprintCompiler; this pass reasons about
## navigation, relationships, collision geometry, overlaps, and future chunks.

const FUTURE_CHUNK_SIZE_CELLS := 16
const TRANSITION_MANIFEST_PATH := "res://content/transitions/active_destinations.json"


static func validate(
	definition: MapDefinition,
	required_anchor_ids: Array[StringName] = [],
	transition_registry: Dictionary = {}
) -> Array[MapBlueprintDiagnostic]:
	var diagnostics: Array[MapBlueprintDiagnostic] = []
	if definition == null:
		return diagnostics
	var registry := transition_registry if not transition_registry.is_empty() else load_transition_registry(diagnostics)
	_validate_transition_relationships(definition, registry, diagnostics)
	_validate_navigation(definition, required_anchor_ids, diagnostics)
	_validate_overlaps(definition, diagnostics)
	_validate_chunk_boundaries(definition, diagnostics)
	diagnostics.sort_custom(_compare_diagnostics)
	return diagnostics


static func load_transition_registry(diagnostics: Array[MapBlueprintDiagnostic] = []) -> Dictionary:
	var text := FileAccess.get_file_as_string(TRANSITION_MANIFEST_PATH)
	if text.is_empty():
		_add(diagnostics, &"MAP_TRANSITION_REGISTRY_INVALID", MapBlueprintDiagnostic.SEVERITY_ERROR,
			"transition registry is missing or empty: %s" % TRANSITION_MANIFEST_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary or not parsed.get("scenes", null) is Array:
		_add(diagnostics, &"MAP_TRANSITION_REGISTRY_INVALID", MapBlueprintDiagnostic.SEVERITY_ERROR,
			"transition registry must contain a scenes array: %s" % TRANSITION_MANIFEST_PATH)
		return {}
	var registry: Dictionary = {}
	for scene_value in parsed["scenes"]:
		if not scene_value is Dictionary:
			continue
		var scene: Dictionary = scene_value
		if not bool(scene.get("active", false)):
			continue
		var scene_id := StringName(scene.get("id", ""))
		var spawns: Dictionary = {}
		for spawn_value in scene.get("spawns", []):
			if spawn_value is Dictionary:
				spawns[StringName(spawn_value.get("id", ""))] = true
		registry[scene_id] = spawns
	return registry


static func _validate_transition_relationships(
	definition: MapDefinition,
	registry: Dictionary,
	diagnostics: Array[MapBlueprintDiagnostic]
) -> void:
	for index in definition.transitions.size():
		var transition: Dictionary = definition.transitions[index]
		var transition_id: StringName = transition.get("id", &"")
		var path := "transitions[%d]" % index
		var destination: StringName = transition.get("destination_scene_id", &"")
		var destination_spawn: StringName = transition.get("destination_spawn_id", &"")
		var own_spawn: StringName = transition.get("spawn_id", &"")
		var has_destination := not destination.is_empty()
		var has_destination_spawn := not destination_spawn.is_empty()
		if has_destination != has_destination_spawn:
			_add(diagnostics, &"MAP_TRANSITION_SPAWN_RELATION_INVALID", MapBlueprintDiagnostic.SEVERITY_ERROR,
				"transition must declare destination_scene_id and destination_spawn_id together", definition.map_id, path, transition_id)
		elif has_destination:
			if not registry.has(destination):
				_add(diagnostics, &"MAP_TRANSITION_DESTINATION_UNKNOWN", MapBlueprintDiagnostic.SEVERITY_ERROR,
					"transition references unknown or inactive destination scene '%s'" % String(destination), definition.map_id, path, transition_id)
			elif not (registry[destination] as Dictionary).has(destination_spawn):
				_add(diagnostics, &"MAP_TRANSITION_DESTINATION_SPAWN_UNKNOWN", MapBlueprintDiagnostic.SEVERITY_ERROR,
					"destination '%s' has no registered spawn '%s'" % [String(destination), String(destination_spawn)], definition.map_id, path, transition_id)
		if own_spawn.is_empty():
			_add(diagnostics, &"MAP_TRANSITION_SPAWN_RELATION_INVALID", MapBlueprintDiagnostic.SEVERITY_ERROR,
				"transition must declare its local spawn_id", definition.map_id, path, transition_id)


static func _validate_navigation(
	definition: MapDefinition,
	required_anchor_ids: Array[StringName],
	diagnostics: Array[MapBlueprintDiagnostic]
) -> void:
	var grid := MapBuilder.build(definition)
	var blocked := MapVerification.blocked_cells(definition)
	for index in definition.interaction_anchors.size():
		var anchor: Dictionary = definition.interaction_anchors[index]
		var anchor_id: StringName = anchor.get("id", &"")
		var position: Vector2 = anchor.get("position", Vector2.ZERO)
		var cell := _point_cell(position, definition.cell_size)
		if blocked.has(cell) or MapTypes.WATER_TERRAINS.has(grid.get_terrain(cell)):
			_add(diagnostics, &"MAP_ANCHOR_BLOCKED", MapBlueprintDiagnostic.SEVERITY_ERROR,
				"anchor is inside blocking geometry or terrain at cell %s" % cell, definition.map_id,
				"interaction_anchors[%d]" % index, anchor_id, {"cell": str(cell)})
	var required := required_anchor_ids.duplicate()
	required.sort_custom(_compare_string_values)
	for anchor_id in required:
		if not MapVerification.has_anchor(definition, anchor_id):
			_add(diagnostics, &"MAP_REQUIRED_ANCHOR_MISSING", MapBlueprintDiagnostic.SEVERITY_ERROR,
				"required anchor is not present", definition.map_id, "required_anchors", anchor_id)
			continue
		var target := MapVerification.anchor_position(definition, anchor_id)
		if not MapVerification.route_exists_exact(definition, grid, definition.player_spawn, target):
			_add(diagnostics, &"MAP_REQUIRED_ANCHOR_UNREACHABLE", MapBlueprintDiagnostic.SEVERITY_ERROR,
				"required anchor is not reachable from the player spawn", definition.map_id, "required_anchors", anchor_id)


static func _validate_overlaps(definition: MapDefinition, diagnostics: Array[MapBlueprintDiagnostic]) -> void:
	var buildings := definition.buildings
	for left_index in buildings.size():
		var left: Dictionary = buildings[left_index]
		var left_rect: Rect2 = left.get("footprint", Rect2())
		for right_index in range(left_index + 1, buildings.size()):
			var right: Dictionary = buildings[right_index]
			var right_rect: Rect2 = right.get("footprint", Rect2())
			var intersection := left_rect.intersection(right_rect)
			if intersection.size.x <= 0.0 or intersection.size.y <= 0.0:
				continue
			# Shared wall/tower seams are intentional in existing city packages. A full
			# duplicate footprint is unambiguously accidental and remains actionable.
			if intersection == left_rect or intersection == right_rect:
				var left_id: StringName = left.get("id", &"")
				var right_id: StringName = right.get("id", &"")
				_add(diagnostics, &"MAP_GEOMETRY_OVERLAP", MapBlueprintDiagnostic.SEVERITY_WARNING,
					"blocking footprints overlap completely: '%s' and '%s'" % [String(left_id), String(right_id)],
					definition.map_id, "buildings", left_id, {"other_id": String(right_id)})


static func _validate_chunk_boundaries(definition: MapDefinition, diagnostics: Array[MapBlueprintDiagnostic]) -> void:
	for index in definition.buildings.size():
		var building: Dictionary = definition.buildings[index]
		var cell_rect := _world_rect_to_cells(building.get("footprint", Rect2()), definition.cell_size)
		_warn_if_crosses_chunk(definition, cell_rect, "buildings[%d]" % index, building.get("id", &""), diagnostics)
	for index in definition.transitions.size():
		var transition: Dictionary = definition.transitions[index]
		var cell_rect := _world_rect_to_cells(transition.get("rect", Rect2()), definition.cell_size)
		_warn_if_crosses_chunk(definition, cell_rect, "transitions[%d]" % index, transition.get("id", &""), diagnostics)
	for index in definition.excluded_areas.size():
		_warn_if_crosses_chunk(definition, definition.excluded_areas[index], "excluded_areas[%d]" % index,
			StringName("excluded.%03d" % index), diagnostics)


static func _warn_if_crosses_chunk(
	definition: MapDefinition,
	rect: Rect2i,
	path: String,
	subject: StringName,
	diagnostics: Array[MapBlueprintDiagnostic]
) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	var first_chunk := Vector2i(rect.position.x / FUTURE_CHUNK_SIZE_CELLS, rect.position.y / FUTURE_CHUNK_SIZE_CELLS)
	var last_cell := rect.end - Vector2i.ONE
	var last_chunk := Vector2i(last_cell.x / FUTURE_CHUNK_SIZE_CELLS, last_cell.y / FUTURE_CHUNK_SIZE_CELLS)
	if first_chunk == last_chunk:
		return
	_add(diagnostics, &"MAP_CHUNK_BOUNDARY_AMBIGUOUS", MapBlueprintDiagnostic.SEVERITY_WARNING,
		"object crosses future %dx%d-cell chunk boundaries (%s to %s); split it or document ownership before chunking" % [
			FUTURE_CHUNK_SIZE_CELLS, FUTURE_CHUNK_SIZE_CELLS, first_chunk, last_chunk,
		], definition.map_id, path, subject, {"rect": str(rect), "chunk_size_cells": FUTURE_CHUNK_SIZE_CELLS})


static func _world_rect_to_cells(rect: Rect2, cell_size: int) -> Rect2i:
	var start := Vector2i(floori(rect.position.x / cell_size), floori(rect.position.y / cell_size))
	var finish := Vector2i(ceili(rect.end.x / cell_size), ceili(rect.end.y / cell_size))
	return Rect2i(start, finish - start)


static func _point_cell(point: Vector2, cell_size: int) -> Vector2i:
	return Vector2i(floori(point.x / cell_size), floori(point.y / cell_size))


static func _add(
	diagnostics: Array[MapBlueprintDiagnostic],
	code: StringName,
	severity: StringName,
	message: String,
	map_id: StringName = &"",
	path: String = "",
	subject: StringName = &"",
	details: Dictionary = {}
) -> void:
	diagnostics.append(MapBlueprintDiagnostic.new(code, severity, message, map_id, path, subject, details))


static func _compare_diagnostics(left: MapBlueprintDiagnostic, right: MapBlueprintDiagnostic) -> bool:
	return [String(left.severity), String(left.code), String(left.path), String(left.subject), left.message] < \
		[String(right.severity), String(right.code), String(right.path), String(right.subject), right.message]


static func _compare_string_values(left: Variant, right: Variant) -> bool:
	return String(left) < String(right)
