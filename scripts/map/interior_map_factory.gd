class_name InteriorMapFactory
extends RefCounted

## Shared authoring helpers for interior and compact urban declarative maps.
## WHY: keeps room shells, doorway gaps, anchors, and fade volumes consistent across conversions.


static func init_definition(
	definition: MapDefinition,
	map_id: StringName,
	location: StringName,
	scope: StringName,
	active: bool,
	palette: StringName,
	size_cells: Vector2i,
	base_terrain: StringName,
	fingerprint: String,
	player_spawn_cell: Rect2i
) -> MapDefinition:
	definition.map_id = map_id
	definition.seed = MapTypes.DEFAULT_SEED
	definition.cell_size = MapTypes.DEFAULT_CELL_SIZE
	definition.size_cells = size_cells
	definition.base_terrain = base_terrain
	definition.player_spawn = definition.cell_rect_center(player_spawn_cell)
	definition.location = location
	definition.scope = scope
	definition.active = active
	definition.palette = palette
	definition.fingerprint = fingerprint
	definition.camera_bounds = definition.cell_rect_to_world_rect(Rect2i(0, 0, size_cells.x, size_cells.y))
	return definition


static func add_floor_zone(definition: MapDefinition, terrain: StringName, rect: Rect2i) -> void:
	definition.zones.append({"terrain": terrain, "rect": rect})


static func add_perimeter_walls(
	definition: MapDefinition,
	inner: Rect2i,
	wall_thickness_cells: int,
	wall_height: float,
	wall_color: Color,
	south_doorway_gap: Rect2i = Rect2i(-1, -1, 0, 0),
	north_doorway_gap: Rect2i = Rect2i(-1, -1, 0, 0)
) -> void:
	var thickness := maxi(1, wall_thickness_cells)
	var outer := Rect2i(
		inner.position.x - thickness,
		inner.position.y - thickness,
		inner.size.x + thickness * 2,
		inner.size.y + thickness * 2
	)

	_add_wall_segment(definition, &"wall_north", _north_wall_rect(outer, thickness), wall_height, wall_color, north_doorway_gap, true)
	_add_wall_segment(definition, &"wall_south", _south_wall_rect(outer, thickness), wall_height, wall_color, south_doorway_gap, true)
	_add_wall_segment(definition, &"wall_west", _west_wall_rect(outer, thickness), wall_height, wall_color)
	_add_wall_segment(definition, &"wall_east", _east_wall_rect(outer, thickness), wall_height, wall_color)


static func add_interior_block(
	definition: MapDefinition,
	block_id: StringName,
	cell_rect: Rect2i,
	wall_height: float = 48.0,
	wall_color: Color = Color(0.38, 0.34, 0.30)
) -> void:
	definition.buildings.append(
		{
			"id": block_id,
			"kind": MapTypes.BUILDING_KIND_INTERIOR_BLOCK,
			"footprint": definition.cell_rect_to_world_rect(cell_rect),
			"wall_height": wall_height,
			"wall_color": wall_color,
		}
	)


static func add_interaction_anchor(definition: MapDefinition, anchor_id: StringName, cell_rect: Rect2i) -> void:
	definition.interaction_anchors.append(
		{"id": anchor_id, "position": definition.cell_rect_center(cell_rect)}
	)


static func add_transition(
	definition: MapDefinition,
	transition_id: StringName,
	cell_rect: Rect2i,
	destination_scene_id: StringName = &"",
	destination_spawn_id: StringName = &"",
	spawn_id: StringName = &"",
	spawn_offset: Vector2 = Vector2.ZERO,
	highlight_area: bool = false,
	view_landmark_id: StringName = &""
) -> void:
	var entry := {
		"id": transition_id,
		"rect": definition.cell_rect_to_world_rect(cell_rect),
	}
	if not destination_scene_id.is_empty():
		entry["destination_scene_id"] = destination_scene_id
	if not destination_spawn_id.is_empty():
		entry["destination_spawn_id"] = destination_spawn_id
	if not spawn_id.is_empty():
		entry["spawn_id"] = spawn_id
	if spawn_offset != Vector2.ZERO:
		entry["spawn_offset"] = spawn_offset
	if highlight_area:
		entry["highlight_area"] = true
	if not String(view_landmark_id).is_empty():
		entry["view_landmark_id"] = view_landmark_id
	definition.transitions.append(entry)


static func add_fade_volume(definition: MapDefinition, cell_rect: Rect2i) -> void:
	definition.fade_volumes.append({"rect": definition.cell_rect_to_world_rect(cell_rect)})


static func add_prop_at_cell(definition: MapDefinition, prop_id: StringName, kind: StringName, cell_rect: Rect2i) -> void:
	definition.props.append(
		{"id": prop_id, "kind": kind, "position": definition.cell_rect_center(cell_rect)}
	)


static func add_source_references(definition: MapDefinition, paths: Array[String]) -> void:
	for path in paths:
		if not definition.source_references.has(path):
			definition.source_references.append(path)


static func _add_wall_segment(
	definition: MapDefinition,
	wall_id: StringName,
	segments: Array[Rect2i],
	wall_height: float,
	wall_color: Color,
	doorway_gap: Rect2i = Rect2i(-1, -1, 0, 0),
	is_horizontal: bool = false
) -> void:
	var index := 0
	for segment in segments:
		if is_horizontal and doorway_gap.size.x > 0:
			var gap_start := doorway_gap.position.x
			var gap_end := doorway_gap.end.x
			if segment.end.x > gap_start and segment.position.x < gap_end:
				if segment.position.x < gap_start:
					var left := Rect2i(segment.position.x, segment.position.y, gap_start - segment.position.x, segment.size.y)
					if left.size.x > 0:
						_append_wall(definition, StringName("%s_%d" % [String(wall_id), index]), left, wall_height, wall_color)
						index += 1
				if segment.end.x > gap_end:
					var right := Rect2i(gap_end, segment.position.y, segment.end.x - gap_end, segment.size.y)
					if right.size.x > 0:
						_append_wall(definition, StringName("%s_%d" % [String(wall_id), index]), right, wall_height, wall_color)
						index += 1
				continue
		if not is_horizontal and doorway_gap.size.y > 0:
			var gap_start_y := doorway_gap.position.y
			var gap_end_y := doorway_gap.end.y
			if segment.end.y > gap_start_y and segment.position.y < gap_end_y:
				if segment.position.y < gap_start_y:
					var top := Rect2i(segment.position.x, segment.position.y, segment.size.x, gap_start_y - segment.position.y)
					if top.size.y > 0:
						_append_wall(definition, StringName("%s_%d" % [String(wall_id), index]), top, wall_height, wall_color)
						index += 1
				if segment.end.y > gap_end_y:
					var bottom := Rect2i(segment.position.x, gap_end_y, segment.size.x, segment.end.y - gap_end_y)
					if bottom.size.y > 0:
						_append_wall(definition, StringName("%s_%d" % [String(wall_id), index]), bottom, wall_height, wall_color)
						index += 1
				continue
		_append_wall(definition, StringName("%s_%d" % [String(wall_id), index]), segment, wall_height, wall_color)
		index += 1


static func _append_wall(
	definition: MapDefinition,
	wall_id: StringName,
	cell_rect: Rect2i,
	wall_height: float,
	wall_color: Color
) -> void:
	definition.buildings.append(
		{
			"id": wall_id,
			"kind": MapTypes.BUILDING_KIND_INTERIOR_WALL,
			"footprint": definition.cell_rect_to_world_rect(cell_rect),
			"wall_height": wall_height,
			"wall_color": wall_color,
		}
	)


static func _north_wall_rect(outer: Rect2i, thickness: int) -> Array[Rect2i]:
	return [Rect2i(outer.position.x, outer.position.y, outer.size.x, thickness)]


static func _south_wall_rect(outer: Rect2i, thickness: int) -> Array[Rect2i]:
	return [Rect2i(outer.position.x, outer.end.y - thickness, outer.size.x, thickness)]


static func _west_wall_rect(outer: Rect2i, thickness: int) -> Array[Rect2i]:
	return [Rect2i(outer.position.x, outer.position.y + thickness, thickness, outer.size.y - thickness * 2)]


static func _east_wall_rect(outer: Rect2i, thickness: int) -> Array[Rect2i]:
	return [Rect2i(outer.end.x - thickness, outer.position.y + thickness, thickness, outer.size.y - thickness * 2)]
