class_name MapBlueprintSemanticValidator
extends RefCounted

## Strict checks that require canonical compiled output or cross-map registries.
## Source-shape errors remain in MapBlueprintCompiler; this pass reasons about
## navigation, relationships, collision geometry, overlaps, and future chunks.

const FUTURE_CHUNK_SIZE_CELLS := 16
const TRANSITION_MANIFEST_PATH := "res://content/transitions/active_destinations.json"
## A footprint whose ground varies more than this (world units, about 43 cm) needs
## a terrace or a stepped plinth; the house mesh stays level.
const RELIEF_MAX_BUILDING_SPAN := 0.5
## Reciprocal physical seams must meet within this height (world units).
const RELIEF_SEAM_TOLERANCE := 0.05


static func validate(
	definition: MapDefinition,
	required_anchor_ids: Array[StringName] = [],
	transition_registry: Dictionary = {}
) -> Array[MapBlueprintDiagnostic]:
	var diagnostics: Array[MapBlueprintDiagnostic] = []
	if definition == null:
		return diagnostics
	var registry := (
		transition_registry
		if not transition_registry.is_empty()
		else load_transition_registry(diagnostics)
	)
	_validate_transition_relationships(definition, registry, diagnostics)
	_validate_navigation(definition, required_anchor_ids, diagnostics)
	_validate_overlaps(definition, diagnostics)
	_validate_chunk_boundaries(definition, diagnostics)
	_validate_relief(definition, diagnostics)
	diagnostics.sort_custom(_compare_diagnostics)
	return diagnostics


static func load_transition_registry(diagnostics: Array[MapBlueprintDiagnostic] = []) -> Dictionary:
	var text := FileAccess.get_file_as_string(TRANSITION_MANIFEST_PATH)
	if text.is_empty():
		_add(
			diagnostics,
			&"MAP_TRANSITION_REGISTRY_INVALID",
			MapBlueprintDiagnostic.SEVERITY_ERROR,
			"transition registry is missing or empty: %s" % TRANSITION_MANIFEST_PATH
		)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary or not parsed.get("scenes", null) is Array:
		_add(
			diagnostics,
			&"MAP_TRANSITION_REGISTRY_INVALID",
			MapBlueprintDiagnostic.SEVERITY_ERROR,
			"transition registry must contain a scenes array: %s" % TRANSITION_MANIFEST_PATH
		)
		return {}
	var registry: Dictionary = {}
	for scene_value in parsed["scenes"]:
		if not scene_value is Dictionary:
			continue
		var scene: Dictionary = scene_value
		var scene_id := StringName(scene.get("id", ""))
		if scene_id.is_empty():
			continue
		var spawns: Dictionary = {}
		for spawn_value in scene.get("spawns", []):
			if spawn_value is Dictionary:
				spawns[StringName(spawn_value.get("id", ""))] = true
		registry[scene_id] = {
			"active": bool(scene.get("active", false)),
			"spawns": spawns,
		}
	return registry


static func _validate_transition_relationships(
	definition: MapDefinition, registry: Dictionary, diagnostics: Array[MapBlueprintDiagnostic]
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
			_add(
				diagnostics,
				&"MAP_TRANSITION_SPAWN_RELATION_INVALID",
				MapBlueprintDiagnostic.SEVERITY_ERROR,
				"transition must declare destination_scene_id and destination_spawn_id together",
				definition.map_id,
				path,
				transition_id
			)
		elif has_destination:
			if not registry.has(destination):
				_add(
					diagnostics,
					&"MAP_TRANSITION_DESTINATION_UNKNOWN",
					MapBlueprintDiagnostic.SEVERITY_ERROR,
					(
						"transition references unknown or inactive destination scene '%s'"
						% String(destination)
					),
					definition.map_id,
					path,
					transition_id
				)
			else:
				var destination_registry := registry[destination] as Dictionary
				var destination_spawns: Dictionary = destination_registry.get("spawns", destination_registry)
				# Inactive maps retain authored reciprocal wiring, but an active map
				# must never expose a transition into an inactive destination.
				var destination_active := bool(
					destination_registry.get("active", destination_registry.get("__active", true))
				)
				if definition.active and not destination_active:
					_add(
						diagnostics,
						&"MAP_TRANSITION_DESTINATION_UNKNOWN",
						MapBlueprintDiagnostic.SEVERITY_ERROR,
						(
							"active map cannot reference inactive destination scene '%s'"
							% String(destination)
						),
						definition.map_id,
						path,
						transition_id
					)
				elif not destination_spawns.has(destination_spawn):
					_add(
						diagnostics,
						&"MAP_TRANSITION_DESTINATION_SPAWN_UNKNOWN",
						MapBlueprintDiagnostic.SEVERITY_ERROR,
						(
							"destination '%s' has no registered spawn '%s'"
							% [String(destination), String(destination_spawn)]
						),
						definition.map_id,
						path,
						transition_id
					)
		if own_spawn.is_empty():
			_add(
				diagnostics,
				&"MAP_TRANSITION_SPAWN_RELATION_INVALID",
				MapBlueprintDiagnostic.SEVERITY_ERROR,
				"transition must declare its local spawn_id",
				definition.map_id,
				path,
				transition_id
			)


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
			_add(
				diagnostics,
				&"MAP_ANCHOR_BLOCKED",
				MapBlueprintDiagnostic.SEVERITY_ERROR,
				"anchor is inside blocking geometry or terrain at cell %s" % cell,
				definition.map_id,
				"interaction_anchors[%d]" % index,
				anchor_id,
				{"cell": str(cell)}
			)
	var required := required_anchor_ids.duplicate()
	required.sort_custom(_compare_string_values)
	for anchor_id in required:
		if not MapVerification.has_anchor(definition, anchor_id):
			_add(
				diagnostics,
				&"MAP_REQUIRED_ANCHOR_MISSING",
				MapBlueprintDiagnostic.SEVERITY_ERROR,
				"required anchor is not present",
				definition.map_id,
				"required_anchors",
				anchor_id
			)
			continue
		var target := MapVerification.anchor_position(definition, anchor_id)
		if not MapVerification.route_exists_exact(
			definition, grid, definition.player_spawn, target
		):
			_add(
				diagnostics,
				&"MAP_REQUIRED_ANCHOR_UNREACHABLE",
				MapBlueprintDiagnostic.SEVERITY_ERROR,
				"required anchor is not reachable from the player spawn",
				definition.map_id,
				"required_anchors",
				anchor_id
			)


static func _validate_overlaps(
	definition: MapDefinition, diagnostics: Array[MapBlueprintDiagnostic]
) -> void:
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
				_add(
					diagnostics,
					&"MAP_GEOMETRY_OVERLAP",
					MapBlueprintDiagnostic.SEVERITY_WARNING,
					(
						"blocking footprints overlap completely: '%s' and '%s'"
						% [String(left_id), String(right_id)]
					),
					definition.map_id,
					"buildings",
					left_id,
					{"other_id": String(right_id)}
				)


static func _validate_chunk_boundaries(
	definition: MapDefinition, diagnostics: Array[MapBlueprintDiagnostic]
) -> void:
	for index in definition.buildings.size():
		var building: Dictionary = definition.buildings[index]
		var cell_rect := _world_rect_to_cells(
			building.get("footprint", Rect2()), definition.cell_size
		)
		_warn_if_crosses_chunk(
			definition, cell_rect, "buildings[%d]" % index, building.get("id", &""), diagnostics
		)
	for index in definition.transitions.size():
		var transition: Dictionary = definition.transitions[index]
		var cell_rect := _world_rect_to_cells(transition.get("rect", Rect2()), definition.cell_size)
		_warn_if_crosses_chunk(
			definition, cell_rect, "transitions[%d]" % index, transition.get("id", &""), diagnostics
		)
	for index in definition.excluded_areas.size():
		_warn_if_crosses_chunk(
			definition,
			definition.excluded_areas[index],
			"excluded_areas[%d]" % index,
			StringName("excluded.%03d" % index),
			diagnostics
		)


static func _warn_if_crosses_chunk(
	definition: MapDefinition,
	rect: Rect2i,
	path: String,
	subject: StringName,
	diagnostics: Array[MapBlueprintDiagnostic]
) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	var first_chunk := Vector2i(
		rect.position.x / FUTURE_CHUNK_SIZE_CELLS, rect.position.y / FUTURE_CHUNK_SIZE_CELLS
	)
	var last_cell := rect.end - Vector2i.ONE
	var last_chunk := Vector2i(
		last_cell.x / FUTURE_CHUNK_SIZE_CELLS, last_cell.y / FUTURE_CHUNK_SIZE_CELLS
	)
	if first_chunk == last_chunk:
		return
	_add(
		diagnostics,
		&"MAP_CHUNK_BOUNDARY_AMBIGUOUS",
		MapBlueprintDiagnostic.SEVERITY_WARNING,
		(
			# gdlint: ignore=max-line-length
			"object crosses future %dx%d-cell chunk boundaries (%s to %s); split it or document ownership before chunking"
			% [
				FUTURE_CHUNK_SIZE_CELLS,
				FUTURE_CHUNK_SIZE_CELLS,
				first_chunk,
				last_chunk,
			]
		),
		definition.map_id,
		path,
		subject,
		{"rect": str(rect), "chunk_size_cells": FUTURE_CHUNK_SIZE_CELLS}
	)


## ADR 0023 single-map relief checks. Maps without relief_* statements compile to
## the legacy datum only and are left untouched, so no existing map gains noise.
static func _validate_relief(
	definition: MapDefinition, diagnostics: Array[MapBlueprintDiagnostic]
) -> void:
	if definition.relief_features.is_empty():
		return
	var size := definition.size_cells
	if definition.suppresses_exterior_surroundings():
		_add(
			diagnostics,
			&"MAP_RELIEF_RANGE",
			MapBlueprintDiagnostic.SEVERITY_ERROR,
			"enclosed interior shells keep a flat floor; relief_* statements are not allowed",
			definition.map_id,
			"relief_features"
		)
		return
	var heights := PackedFloat32Array()
	heights.resize(size.x * size.y)
	var out_of_range: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			var height := definition.height_at(Vector2i(x, y))
			heights[y * size.x + x] = height
			if height < MapDefinition.RELIEF_MIN_HEIGHT or height > MapDefinition.RELIEF_MAX_HEIGHT:
				out_of_range.append(Vector2i(x, y))
	if not out_of_range.is_empty():
		_add(
			diagnostics,
			&"MAP_RELIEF_RANGE",
			MapBlueprintDiagnostic.SEVERITY_ERROR,
			(
				"%d cell(s) leave the ADR 0023 height range %s..%s, first at %s"
				% [
					out_of_range.size(),
					MapDefinition.RELIEF_MIN_HEIGHT,
					MapDefinition.RELIEF_MAX_HEIGHT,
					out_of_range[0],
				]
			),
			definition.map_id,
			"relief_heights",
			&"",
			{"cells": out_of_range.size(), "first": str(out_of_range[0])}
		)
	_validate_relief_slope(definition, heights, diagnostics)
	for index in definition.buildings.size():
		var building: Dictionary = definition.buildings[index]
		var footprint := _world_rect_to_cells(building["footprint"], definition.cell_size)
		var low := INF
		var high := -INF
		for y in range(maxi(footprint.position.y, 0), mini(footprint.end.y, size.y)):
			for x in range(maxi(footprint.position.x, 0), mini(footprint.end.x, size.x)):
				low = minf(low, heights[y * size.x + x])
				high = maxf(high, heights[y * size.x + x])
		if high - low > RELIEF_MAX_BUILDING_SPAN:
			_add(
				diagnostics,
				&"MAP_RELIEF_UNDER_BUILDING",
				MapBlueprintDiagnostic.SEVERITY_WARNING,
				(
					"building ground spans %.2f world units (limit %.2f); add a terrace under it"
					% [high - low, RELIEF_MAX_BUILDING_SPAN]
				),
				definition.map_id,
				"buildings[%d]" % index,
				StringName(building.get("id", &"")),
				{"span": snappedf(high - low, 0.001)}
			)


## One warning per map listing the steep 4-neighbour faces that no relief_cliff
## explains; an authored cliff makes the same face intentional.
static func _validate_relief_slope(
	definition: MapDefinition, heights: PackedFloat32Array, diagnostics: Array[MapBlueprintDiagnostic]
) -> void:
	var size := definition.size_cells
	var cliff_masks: Array[PackedByteArray] = []
	for feature in definition.relief_features:
		if feature.get("kind") == &"cliff":
			cliff_masks.append(MapBlueprintCompilerExpandTerrain.cliff_lowered_mask(feature, size))
	var max_rise := tan(MapDefinition.RELIEF_MAX_WALKABLE_SLOPE)
	var steep: Array[String] = []
	for y in size.y:
		for x in size.x:
			var here := y * size.x + x
			for neighbor in [Vector2i(x + 1, y), Vector2i(x, y + 1)]:
				if neighbor.x >= size.x or neighbor.y >= size.y:
					continue
				var there: int = neighbor.y * size.x + neighbor.x
				if absf(heights[here] - heights[there]) <= max_rise + 0.0001:
					continue
				var authored := false
				for mask in cliff_masks:
					if mask[here] != mask[there]:
						authored = true
						break
				if not authored:
					steep.append("%s-%s" % [Vector2i(x, y), neighbor])
	if steep.is_empty():
		return
	_add(
		diagnostics,
		&"MAP_RELIEF_SLOPE",
		MapBlueprintDiagnostic.SEVERITY_WARNING,
		(
			"%d cell face(s) exceed the %d degree walkable slope without a relief_cliff, first %s"
			% [steep.size(), roundi(rad_to_deg(MapDefinition.RELIEF_MAX_WALKABLE_SLOPE)), steep[0]]
		),
		definition.map_id,
		"relief_heights",
		&"",
		{"faces": steep.size(), "first": steep[0]}
	)


## Cross-map ADR 0023 check: every physical (non-travel, opposite-side) reciprocal
## transition must meet its neighbour at the same height along the shared edge.
## Needs all compiled definitions, so tools/validate_map_blueprints.gd calls it.
static func validate_relief_seams(
	definitions: Array[MapDefinition]
) -> Array[MapBlueprintDiagnostic]:
	var diagnostics: Array[MapBlueprintDiagnostic] = []
	for base_index in definitions.size():
		var base := definitions[base_index]
		for neighbor_index in range(base_index + 1, definitions.size()):
			var neighbor := definitions[neighbor_index]
			for pair in MapAlignmentMath.find_transition_pairs(base, neighbor):
				_validate_seam_pair(base, neighbor, pair, diagnostics)
	diagnostics.sort_custom(_compare_diagnostics)
	return diagnostics


static func _validate_seam_pair(
	base: MapDefinition,
	neighbor: MapDefinition,
	pair: Dictionary,
	diagnostics: Array[MapBlueprintDiagnostic]
) -> void:
	var base_side := StringName(pair["base_side"])
	var opposite := {&"north": &"south", &"south": &"north", &"east": &"west", &"west": &"east"}
	if opposite.get(base_side) != StringName(pair["neighbor_side"]):
		return
	var base_transition: Dictionary = pair["base"]
	var offset := MapAlignmentMath.aligned_neighbor_offset(
		base, neighbor, base_transition, pair["neighbor"]
	)
	var rect: Rect2 = base_transition["rect"]
	var world := base.world_size()
	var along_x := base_side in [&"north", &"south"]
	var span := rect.size.x if along_x else rect.size.y
	var samples := maxi(1, ceili(span / float(base.cell_size)))
	var worst := 0.0
	var worst_point := Vector2.ZERO
	for index in samples:
		var t := (float(index) + 0.5) / float(samples)
		var point: Vector2
		match base_side:
			&"north":
				point = Vector2(rect.position.x + span * t, 0.0)
			&"south":
				point = Vector2(rect.position.x + span * t, world.y)
			&"west":
				point = Vector2(0.0, rect.position.y + span * t)
			_:
				point = Vector2(world.x, rect.position.y + span * t)
		var neighbor_point := point - offset
		var neighbor_world := neighbor.world_size()
		if (
			neighbor_point.x < 0.0
			or neighbor_point.y < 0.0
			or neighbor_point.x > neighbor_world.x
			or neighbor_point.y > neighbor_world.y
		):
			continue
		var delta := absf(base.height_at_world(point) - neighbor.height_at_world(neighbor_point))
		if delta > worst:
			worst = delta
			worst_point = point
	if worst <= RELIEF_SEAM_TOLERANCE:
		return
	_add(
		diagnostics,
		&"MAP_RELIEF_SEAM",
		MapBlueprintDiagnostic.SEVERITY_ERROR,
		(
			"height differs by %.3f world units from %s at the shared edge (tolerance %.2f)"
			% [worst, String(neighbor.map_id), RELIEF_SEAM_TOLERANCE]
		),
		base.map_id,
		"transitions",
		StringName(base_transition.get("id", &"")),
		{"neighbor": String(neighbor.map_id), "delta": snappedf(worst, 0.001), "at": str(worst_point)}
	)


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
	diagnostics.append(
		MapBlueprintDiagnostic.new(code, severity, message, map_id, path, subject, details)
	)


static func _compare_diagnostics(
	left: MapBlueprintDiagnostic, right: MapBlueprintDiagnostic
) -> bool:
	return (
		[
			String(left.severity),
			String(left.code),
			String(left.path),
			String(left.subject),
			left.message
		]
		< [
			String(right.severity),
			String(right.code),
			String(right.path),
			String(right.subject),
			right.message
		]
	)


static func _compare_string_values(left: Variant, right: Variant) -> bool:
	return String(left) < String(right)
