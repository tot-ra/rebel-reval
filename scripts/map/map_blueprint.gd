class_name MapBlueprint
extends RefCounted

## Typed, cell-space authoring model compiled into the unchanged MapDefinition.
## Primitive payload dictionaries are private compiler input. Authors use only the
## named methods below, so runtime dictionary keys never become an authoring API.

const OBJECT_BUILDING := &"building"
const OBJECT_PROP := &"prop"

var map_id: StringName
var location: StringName
var scope: StringName
var active: bool
var seed: int
var palette: StringName
var size_cells: Vector2i
var base_terrain: StringName
var cell_size: int

var primitives: Array[Dictionary] = []
var styles: Array[Dictionary] = []
var source_references: Array[String] = []
var surroundings_town_sides: Array[StringName] = []
var authored_camera_bounds: Rect2i = Rect2i()
var has_authored_camera_bounds := false
var object_overrides: Array[Dictionary] = []


func _init(
	map_id_value: StringName,
	location_value: StringName,
	size_cells_value: Vector2i,
	base_terrain_value: StringName,
	scope_value: StringName = &"prototype",
	active_value: bool = false,
	palette_value: StringName = &"clean_painted",
	seed_value: int = MapTypes.DEFAULT_SEED,
	cell_size_value: int = MapTypes.DEFAULT_CELL_SIZE
) -> void:
	map_id = map_id_value
	location = location_value
	size_cells = size_cells_value
	base_terrain = base_terrain_value
	scope = scope_value
	active = active_value
	palette = palette_value
	seed = seed_value
	cell_size = cell_size_value


func define_style(style_id: StringName, values: Dictionary, parent_style: StringName = &"") -> MapBlueprint:
	styles.append({"id": style_id, "parent": parent_style, "values": values.duplicate(true)})
	return self


func style(style_id: StringName, values: Dictionary, parent_style: StringName = &"") -> MapBlueprint:
	return define_style(style_id, values, parent_style)


func add_source_reference(path: String) -> MapBlueprint:
	source_references.append(path)
	return self


func add_source_references(paths: Array[String]) -> MapBlueprint:
	for path in paths:
		add_source_reference(path)
	return self


func terrain_rect(
	terrain_id: StringName,
	terrain: StringName,
	rect: Rect2i,
	layer: int = 0,
	order: int = 0,
	style_id: StringName = &"",
	overrides: Dictionary = {}
) -> MapBlueprint:
	_append_primitive(&"terrain_rect", terrain_id, {
		"terrain": terrain,
		"rects": [rect],
		"layer": layer,
		"order": order,
	}, style_id, overrides)
	return self


func terrain_rects(
	group_id: StringName,
	terrain: StringName,
	rects: Array[Rect2i],
	layer: int = 0,
	order: int = 0,
	style_id: StringName = &"",
	overrides: Dictionary = {}
) -> MapBlueprint:
	_append_primitive(&"terrain_rects", group_id, {
		"terrain": terrain,
		"rects": rects.duplicate(),
		"layer": layer,
		"order": order,
	}, style_id, overrides)
	return self


func terrain_stroke(
	stroke_id: StringName,
	terrain: StringName,
	points: Array[Vector2i],
	thickness: int = 1,
	layer: int = 0,
	order: int = 0,
	style_id: StringName = &"",
	overrides: Dictionary = {}
) -> MapBlueprint:
	_append_primitive(&"terrain_stroke", stroke_id, {
		"terrain": terrain,
		"points": points.duplicate(),
		"thickness": thickness,
		"layer": layer,
		"order": order,
	}, style_id, overrides)
	return self


func structure_rect(
	structure_id: StringName,
	kind: StringName,
	footprint: Rect2i,
	style_id: StringName = &"",
	overrides: Dictionary = {}
) -> MapBlueprint:
	_append_primitive(&"structure_rect", structure_id, {
		"kind": kind,
		"rect": footprint,
	}, style_id, overrides)
	return self


func building(
	building_id: StringName,
	kind: StringName,
	footprint: Rect2i,
	style_id: StringName = &"",
	overrides: Dictionary = {}
) -> MapBlueprint:
	return structure_rect(building_id, kind, footprint, style_id, overrides)


func wall_run(
	wall_id: StringName,
	start_cell: Vector2i,
	end_cell: Vector2i,
	thickness: int = 1,
	openings: Array[Rect2i] = [],
	style_id: StringName = &"",
	overrides: Dictionary = {},
	kind: StringName = MapTypes.BUILDING_KIND_WALL
) -> MapBlueprint:
	_append_primitive(&"wall_run", wall_id, {
		"kind": kind,
		"start": start_cell,
		"end": end_cell,
		"thickness": thickness,
		"openings": openings.duplicate(),
	}, style_id, overrides)
	return self


func placement_row(
	row_id: StringName,
	object_type: StringName,
	kind: StringName,
	origin: Vector2i,
	step: Vector2i,
	slot_ids: Array[StringName],
	footprint_size: Vector2i = Vector2i.ONE,
	style_id: StringName = &"",
	overrides_by_slot: Dictionary = {}
) -> MapBlueprint:
	_append_primitive(&"placement_row", row_id, {
		"object_type": object_type,
		"kind": kind,
		"origin": origin,
		"step": step,
		"slot_ids": slot_ids.duplicate(),
		"footprint_size": footprint_size,
		"overrides_by_slot": overrides_by_slot.duplicate(true),
	}, style_id, {})
	return self


func prop(
	prop_id: StringName,
	kind: StringName,
	cell: Vector2i,
	style_id: StringName = &"",
	overrides: Dictionary = {}
) -> MapBlueprint:
	_append_primitive(&"prop", prop_id, {"kind": kind, "cell": cell}, style_id, overrides)
	return self


func player_spawn(spawn_id: StringName, cell: Vector2i, overrides: Dictionary = {}) -> MapBlueprint:
	_append_primitive(&"player_spawn", spawn_id, {"cell": cell}, &"", overrides)
	return self


func transition(
	transition_id: StringName,
	rect: Rect2i,
	destination_scene_id: StringName = &"",
	destination_spawn_id: StringName = &"",
	spawn_id: StringName = &"",
	style_id: StringName = &"",
	overrides: Dictionary = {}
) -> MapBlueprint:
	_append_primitive(&"transition", transition_id, {
		"rect": rect,
		"destination_scene_id": destination_scene_id,
		"destination_spawn_id": destination_spawn_id,
		"spawn_id": spawn_id,
	}, style_id, overrides)
	return self


func interaction_anchor(
	anchor_id: StringName,
	cell: Vector2i,
	kind: StringName = &"",
	style_id: StringName = &"",
	overrides: Dictionary = {}
) -> MapBlueprint:
	_append_primitive(&"interaction_anchor", anchor_id, {"cell": cell, "kind": kind}, style_id, overrides)
	return self


func patrol_path(path_id: StringName, points: Array[Vector2i]) -> MapBlueprint:
	_append_primitive(&"patrol_path", path_id, {"points": points.duplicate()}, &"", {})
	return self


func excluded_rect(exclusion_id: StringName, rect: Rect2i, overrides: Dictionary = {}) -> MapBlueprint:
	_append_primitive(&"excluded_rect", exclusion_id, {"rect": rect}, &"", overrides)
	return self


func fade_rect(fade_id: StringName, rect: Rect2i, overrides: Dictionary = {}) -> MapBlueprint:
	_append_primitive(&"fade_rect", fade_id, {"rect": rect}, &"", overrides)
	return self


func direction_sign(
	sign_id: StringName,
	text: String,
	cell: Vector2i,
	direction: Vector2i,
	style_id: StringName = &"",
	overrides: Dictionary = {}
) -> MapBlueprint:
	_append_primitive(&"direction_sign", sign_id, {
		"text": text,
		"cell": cell,
		"direction": direction,
	}, style_id, overrides)
	return self


func view_landmark(
	landmark_id: StringName,
	kind: StringName,
	rect: Rect2i,
	style_id: StringName = &"",
	overrides: Dictionary = {}
) -> MapBlueprint:
	_append_primitive(&"view_landmark", landmark_id, {"kind": kind, "rect": rect}, style_id, overrides)
	return self


func surroundings(sides: Array[StringName]) -> MapBlueprint:
	surroundings_town_sides = sides.duplicate()
	return self


func camera_bounds(rect: Rect2i) -> MapBlueprint:
	authored_camera_bounds = rect
	has_authored_camera_bounds = true
	return self


func override_object(object_id: StringName, values: Dictionary) -> MapBlueprint:
	object_overrides.append({"id": object_id, "values": values.duplicate(true)})
	return self


func _append_primitive(
	primitive_kind: StringName,
	primitive_id: StringName,
	data: Dictionary,
	style_id: StringName,
	overrides: Dictionary
) -> void:
	primitives.append({
		"primitive": primitive_kind,
		"id": primitive_id,
		"data": data,
		"style": style_id,
		"overrides": overrides.duplicate(true),
	})
