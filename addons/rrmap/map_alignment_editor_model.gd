@tool
class_name MapAlignmentEditorModel
extends RefCounted

## Mutable editor session for one .rrmap source.
##
## The blueprint is the editable source of truth. Every mutation is compiled
## before the preview is updated, so the canvas never renders a definition that
## the normal map pipeline would reject. Saving intentionally uses the existing
## canonical serializer instead of inventing a second editor format.

var source_path := ""
var blueprint: MapBlueprint
var definition: MapDefinition
var dirty := false
var last_error := ""


func load_source(path: String) -> bool:
	var parsed := MapRrmapParser.parse_file(path)
	if not parsed.is_ok():
		last_error = "\n".join(parsed.formatted_diagnostics())
		return false
	source_path = path
	blueprint = parsed.blueprint
	definition = parsed.definition
	dirty = false
	last_error = ""
	return true


func compile_preview() -> bool:
	if blueprint == null:
		last_error = "No map blueprint is loaded."
		return false
	var result: MapBlueprintCompileResult = MapBlueprintCompiler.compile_with_diagnostics(blueprint)
	if not result.is_ok():
		last_error = "\n".join(result.formatted_diagnostics())
		return false
	definition = result.definition
	last_error = ""
	return true


func save() -> bool:
	if blueprint == null or source_path.is_empty():
		last_error = "No map source is loaded."
		return false
	if not compile_preview():
		return false
	var file := FileAccess.open(source_path, FileAccess.WRITE)
	if file == null:
		last_error = "Could not open %s for writing: %s" % [source_path, error_string(FileAccess.get_open_error())]
		return false
	file.store_string(MapRrmapSerializer.canonical_print(blueprint))
	file.close()
	dirty = false
	return true


func revert() -> bool:
	if source_path.is_empty():
		last_error = "No map source is loaded."
		return false
	return load_source(source_path)


func set_size(size_cells: Vector2i) -> bool:
	if blueprint == null:
		return false
	var next_size := Vector2i(maxi(size_cells.x, 1), maxi(size_cells.y, 1))
	blueprint.size_cells = next_size
	_clip_to_bounds()
	return _commit_edit()


func set_ground_elevation(value: float) -> bool:
	if blueprint == null:
		return false
	blueprint.ground_elevation = clampf(value, 0.0, 8.0)
	return _commit_edit()


func paint_terrain(cell: Vector2i, terrain: StringName) -> bool:
	if blueprint == null or not MapTypes.ALL_TERRAINS.has(terrain):
		last_error = "Unknown terrain: %s" % String(terrain)
		return false
	if not _cell_inside(cell):
		return false
	var id := _next_editor_id("editor.terrain")
	blueprint.terrain_rect(id, terrain, Rect2i(cell, Vector2i.ONE), 0, 1000000)
	return _commit_edit()


func add_building(kind: StringName, cell: Vector2i, footprint_size: Vector2i, requested_id := "") -> StringName:
	if blueprint == null or not MapTypes.ALL_BUILDING_KINDS.has(kind):
		last_error = "Unknown building kind: %s" % String(kind)
		return &""
	var size := Vector2i(maxi(footprint_size.x, 1), maxi(footprint_size.y, 1))
	var rect := Rect2i(cell, size).intersection(Rect2i(Vector2i.ZERO, blueprint.size_cells))
	if rect.size.x <= 0 or rect.size.y <= 0:
		last_error = "Building must overlap the map bounds."
		return &""
	var building_id := StringName(requested_id.strip_edges()) if not requested_id.strip_edges().is_empty() else _next_editor_id("editor.building")
	if _primitive_id_exists(building_id):
		building_id = _next_editor_id(String(building_id))
	blueprint.building(building_id, kind, rect)
	if not _commit_edit():
		return &""
	return building_id


func remove_building(building_id: StringName) -> bool:
	if blueprint == null or building_id.is_empty():
		return false
	var kept: Array[Dictionary] = []
	var removed := false
	for primitive in blueprint.primitives:
		var primitive_id: StringName = primitive.get("id", &"")
		var primitive_kind: StringName = primitive.get("primitive", &"")
		if primitive_id == building_id and primitive_kind in [&"structure_rect", &"wall_run"]:
			removed = true
			continue
		kept.append(primitive)
	if not removed:
		return false
	blueprint.primitives = kept
	return _commit_edit()


func remove_building_at(cell: Vector2i) -> StringName:
	if definition == null or not _cell_inside(cell):
		return &""
	var point := Vector2(cell) * float(definition.cell_size) + Vector2.ONE * float(definition.cell_size) * 0.5
	for index in range(definition.buildings.size() - 1, -1, -1):
		var building: Dictionary = definition.buildings[index]
		if Rect2(building.get("footprint", Rect2())).has_point(point):
			var building_id: StringName = building.get("id", &"")
			if remove_building(building_id):
				return building_id
	return &""


func building_at(cell: Vector2i) -> StringName:
	if definition == null or not _cell_inside(cell):
		return &""
	var point := Vector2(cell) * float(definition.cell_size) + Vector2.ONE * float(definition.cell_size) * 0.5
	for index in range(definition.buildings.size() - 1, -1, -1):
		var building: Dictionary = definition.buildings[index]
		if Rect2(building.get("footprint", Rect2())).has_point(point):
			return building.get("id", &"")
	return &""


func _commit_edit() -> bool:
	if not compile_preview():
		return false
	dirty = true
	return true


func _cell_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < blueprint.size_cells.x and cell.y < blueprint.size_cells.y


func _primitive_id_exists(candidate: StringName) -> bool:
	for primitive in blueprint.primitives:
		if primitive.get("id", &"") == candidate:
			return true
	for entry in blueprint.object_overrides:
		if entry.get("id", &"") == candidate:
			return true
	return false


func _next_editor_id(prefix: String) -> StringName:
	var index := 1
	while _primitive_id_exists(StringName("%s.%03d" % [prefix, index])):
		index += 1
	return StringName("%s.%03d" % [prefix, index])


func _clip_to_bounds() -> void:
	var bounds := Rect2i(Vector2i.ZERO, blueprint.size_cells)
	var kept: Array[Dictionary] = []
	for original in blueprint.primitives:
		var primitive: Dictionary = original.duplicate(true)
		var kind: StringName = primitive.get("primitive", &"")
		var data: Dictionary = primitive.get("data", {})
		var keep := true
		match kind:
			&"terrain_rect":
				var clipped := _clip_rect(data.get("rects", [Rect2i()])[0], bounds)
				keep = clipped.size.x > 0 and clipped.size.y > 0
				if keep:
					data["rects"] = [clipped]
			&"terrain_rects":
				var rects: Array[Rect2i] = []
				for rect in data.get("rects", []):
					var clipped_rect := _clip_rect(rect, bounds)
					if clipped_rect.size.x > 0 and clipped_rect.size.y > 0:
						rects.append(clipped_rect)
				keep = not rects.is_empty()
				if keep:
					data["rects"] = rects
			&"terrain_stroke":
				var points: Array[Vector2i] = []
				for point in data.get("points", []):
					points.append(_clamp_cell(point))
				data["points"] = points
				keep = not points.is_empty()
			&"structure_rect", &"transition", &"interaction_anchor", &"excluded_rect", &"fade_rect", &"decal_rect", &"view_landmark":
				if data.has("rect"):
					var clipped_rect := _clip_rect(data["rect"], bounds)
					keep = clipped_rect.size.x > 0 and clipped_rect.size.y > 0
					if keep:
						data["rect"] = clipped_rect
			&"wall_run":
				data["start"] = _clamp_cell(data.get("start", Vector2i.ZERO))
				data["end"] = _clamp_cell(data.get("end", Vector2i.ZERO))
			&"prop", &"player_spawn", &"direction_sign":
				if data.has("cell"):
					data["cell"] = _clamp_cell(data["cell"])
				elif data.has("rect"):
					var clipped_placement := _clip_rect(data["rect"], bounds)
					keep = clipped_placement.size.x > 0 and clipped_placement.size.y > 0
					if keep:
						data["rect"] = clipped_placement
			&"patrol_path":
				var patrol_points: Array[Vector2i] = []
				for point in data.get("points", []):
					patrol_points.append(_clamp_cell(point))
				data["points"] = patrol_points
			_:
				pass
		primitive["data"] = data
		if keep:
			kept.append(primitive)
	blueprint.primitives = kept
	if blueprint.has_authored_camera_bounds:
		blueprint.authored_camera_bounds = _clip_rect(blueprint.authored_camera_bounds, bounds)


func _clip_rect(rect: Rect2i, bounds: Rect2i) -> Rect2i:
	return rect.intersection(bounds)


func _clamp_cell(cell: Vector2i) -> Vector2i:
	return Vector2i(
		clampi(cell.x, 0, blueprint.size_cells.x - 1),
		clampi(cell.y, 0, blueprint.size_cells.y - 1)
	)
