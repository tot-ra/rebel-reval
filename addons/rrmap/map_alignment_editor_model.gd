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
var selected_primitive_id: StringName = &""


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
	selected_primitive_id = &""
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
		last_error = "Could not open %s for writing: %s" % [source_path, error_string(
			FileAccess.get_open_error())]
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
	var original_size := blueprint.size_cells
	var original_primitives: Array[Dictionary] = blueprint.primitives.duplicate(true)
	var original_camera_bounds := blueprint.authored_camera_bounds
	var original_has_camera_bounds := blueprint.has_authored_camera_bounds
	var next_size := Vector2i(maxi(size_cells.x, 1), maxi(size_cells.y, 1))
	blueprint.size_cells = next_size
	_clip_to_bounds()
	if _commit_edit():
		return true
	var error_message := last_error
	blueprint.size_cells = original_size
	blueprint.primitives = original_primitives
	blueprint.authored_camera_bounds = original_camera_bounds
	blueprint.has_authored_camera_bounds = original_has_camera_bounds
	compile_preview()
	last_error = error_message
	return false


func set_ground_elevation(value: float) -> bool:
	if blueprint == null:
		return false
	var original_elevation := blueprint.ground_elevation
	blueprint.ground_elevation = clampf(value, 0.0, 8.0)
	if _commit_edit():
		return true
	var error_message := last_error
	blueprint.ground_elevation = original_elevation
	compile_preview()
	last_error = error_message
	return false


func paint_terrain(cell: Vector2i, terrain: StringName) -> bool:
	if blueprint == null or not MapTypes.ALL_TERRAINS.has(terrain):
		last_error = "Unknown terrain: %s" % String(terrain)
		return false
	if not _cell_inside(cell):
		return false
	var original_primitives: Array[Dictionary] = blueprint.primitives.duplicate(true)
	var id := _next_editor_id("editor.terrain")
	blueprint.terrain_rect(id, terrain, Rect2i(cell, Vector2i.ONE), 0, 1000000)
	if _commit_edit():
		return true
	var error_message := last_error
	blueprint.primitives = original_primitives
	compile_preview()
	last_error = error_message
	return false


func add_building(
	kind: StringName,
	cell: Vector2i,
	footprint_size: Vector2i,
	requested_id := ""
) -> StringName:
	if blueprint == null or not MapTypes.ALL_BUILDING_KINDS.has(kind):
		last_error = "Unknown building kind: %s" % String(kind)
		return &""
	var size := Vector2i(maxi(footprint_size.x, 1), maxi(footprint_size.y, 1))
	var rect := Rect2i(cell, size).intersection(Rect2i(Vector2i.ZERO, blueprint.size_cells))
	if rect.size.x <= 0 or rect.size.y <= 0:
		last_error = "Building must overlap the map bounds."
		return &""
	var original_primitives: Array[Dictionary] = blueprint.primitives.duplicate(true)
	var building_id: StringName
	if requested_id.strip_edges().is_empty():
		building_id = _next_editor_id("editor.building")
	else:
		building_id = StringName(requested_id.strip_edges())
	if _primitive_id_exists(building_id):
		building_id = _next_editor_id(String(building_id))
	blueprint.building(building_id, kind, rect)
	if _commit_edit():
		return building_id
	var error_message := last_error
	blueprint.primitives = original_primitives
	compile_preview()
	last_error = error_message
	return &""


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
	var original_primitives: Array[Dictionary] = blueprint.primitives.duplicate(true)
	blueprint.primitives = kept
	if _commit_edit():
		return true
	var error_message := last_error
	blueprint.primitives = original_primitives
	compile_preview()
	last_error = error_message
	return false


func remove_building_at(cell: Vector2i) -> StringName:
	if definition == null or not _cell_inside(cell):
		return &""
	var point := (
		Vector2(cell) * float(definition.cell_size)
		+ Vector2.ONE * float(definition.cell_size) * 0.5
	)
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
	var point := (
		Vector2(cell) * float(definition.cell_size)
		+ Vector2.ONE * float(definition.cell_size) * 0.5
	)
	for index in range(definition.buildings.size() - 1, -1, -1):
		var building: Dictionary = definition.buildings[index]
		if Rect2(building.get("footprint", Rect2())).has_point(point):
			return building.get("id", &"")
	return &""


func primitive_at(cell: Vector2i) -> Dictionary:
	if blueprint == null or not _cell_inside(cell):
		return {}
	# Reverse declaration order matches the visual/editor stacking rule: the last
	# authored primitive at a cell is the one users expect to select first.
	for index in range(blueprint.primitives.size() - 1, -1, -1):
		var primitive: Dictionary = blueprint.primitives[index]
		if _primitive_contains_cell(primitive, cell):
			return primitive
	return {}


func select_primitive_at(cell: Vector2i) -> Dictionary:
	var primitive := primitive_at(cell)
	selected_primitive_id = primitive.get("id", &"")
	return primitive


func remove_primitive(primitive_id: StringName) -> bool:
	if blueprint == null or primitive_id.is_empty():
		return false
	var original_primitives: Array[Dictionary] = blueprint.primitives.duplicate(true)
	var kept: Array[Dictionary] = []
	var removed := false
	for primitive in blueprint.primitives:
		if primitive.get("id", &"") == primitive_id:
			removed = true
			continue
		kept.append(primitive)
	if not removed:
		last_error = "Primitive '%s' was not found." % primitive_id
		return false
	blueprint.primitives = kept
	if not _commit_edit():
		var error_message := last_error
		blueprint.primitives = original_primitives
		compile_preview()
		last_error = error_message
		return false
	if selected_primitive_id == primitive_id:
		selected_primitive_id = &""
	return true


func remove_primitive_at(cell: Vector2i) -> StringName:
	var primitive := primitive_at(cell)
	var primitive_id: StringName = primitive.get("id", &"")
	if not primitive_id.is_empty() and remove_primitive(primitive_id):
		return primitive_id
	return &""


func move_primitive(primitive_id: StringName, cell_delta: Vector2i) -> bool:
	if blueprint == null or primitive_id.is_empty() or cell_delta == Vector2i.ZERO:
		return false
	var original_primitives: Array[Dictionary] = blueprint.primitives.duplicate(true)
	var original_selection := selected_primitive_id
	for index in blueprint.primitives.size():
		var primitive: Dictionary = blueprint.primitives[index]
		if primitive.get("id", &"") != primitive_id:
			continue
		var moved := _translated_primitive(primitive, cell_delta)
		if moved.is_empty():
			last_error = "Primitive '%s' cannot be moved by the visual editor yet." % primitive_id
			return false
		blueprint.primitives[index] = moved
		selected_primitive_id = primitive_id
		if _commit_edit():
			return true
		var error_message := last_error
		blueprint.primitives = original_primitives
		selected_primitive_id = original_selection
		compile_preview()
		last_error = error_message
		return false
	last_error = "Primitive '%s' was not found." % primitive_id
	return false


func add_prop(kind: StringName, cell: Vector2i, requested_id := "") -> StringName:
	if blueprint == null or not MapTypes.ALL_PROP_KINDS.has(kind) or not _cell_inside(cell):
		last_error = "Unknown prop kind or out-of-bounds cell: %s" % String(kind)
		return &""
	var prop_id: StringName
	if requested_id.strip_edges().is_empty():
		prop_id = _next_editor_id("editor.prop")
	else:
		prop_id = StringName(requested_id.strip_edges())
	if _primitive_id_exists(prop_id):
		prop_id = _next_editor_id(String(prop_id))
	var original_primitives: Array[Dictionary] = blueprint.primitives.duplicate(true)
	blueprint.prop(prop_id, kind, cell)
	if not _commit_edit():
		var error_message := last_error
		blueprint.primitives = original_primitives
		compile_preview()
		last_error = error_message
		return &""
	selected_primitive_id = prop_id
	return prop_id


func _commit_edit() -> bool:
	if not compile_preview():
		return false
	dirty = true
	return true


func _cell_inside(cell: Vector2i) -> bool:
	return (
		cell.x >= 0 and cell.y >= 0
		and cell.x < blueprint.size_cells.x
		and cell.y < blueprint.size_cells.y
	)


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


func _primitive_contains_cell(primitive: Dictionary, cell: Vector2i) -> bool:
	var data: Dictionary = primitive.get("data", {})
	if data.has("cell"):
		return Vector2i(data["cell"]) == cell
	if data.has("rect"):
		return Rect2i(data["rect"]).has_point(cell)
	if data.has("rects"):
		for rect in data["rects"]:
			if Rect2i(rect).has_point(cell):
				return true
	if data.has("points"):
		for point in data["points"]:
			if Vector2i(point) == cell:
				return true
	if data.has("start") and data.has("end"):
		var start := Vector2i(data["start"])
		var end := Vector2i(data["end"])
		return cell.x >= mini(start.x, end.x) and cell.x <= maxi(start.x, end.x) \
			and cell.y >= mini(start.y, end.y) and cell.y <= maxi(start.y, end.y)
	return false


func _translated_primitive(original: Dictionary, delta: Vector2i) -> Dictionary:
	var primitive: Dictionary = original.duplicate(true)
	var data: Dictionary = primitive.get("data", {})
	if data.has("cell"):
		data["cell"] = _clamp_cell(Vector2i(data["cell"]) + delta)
	elif data.has("rect"):
		data["rect"] = _translated_rect_in_bounds(Rect2i(data["rect"]), delta)
	elif data.has("rects"):
		var rects: Array[Rect2i] = []
		for rect in data["rects"]:
			rects.append(_translated_rect_in_bounds(Rect2i(rect), delta))
		data["rects"] = rects
	elif data.has("points"):
		var points: Array[Vector2i] = []
		for point in data["points"]:
			points.append(_clamp_cell(Vector2i(point) + delta))
		data["points"] = points
	elif data.has("start") and data.has("end"):
		data["start"] = _clamp_cell(Vector2i(data["start"]) + delta)
		data["end"] = _clamp_cell(Vector2i(data["end"]) + delta)
	else:
		return {}
	primitive["data"] = data
	return primitive


func _translated_rect_in_bounds(rect: Rect2i, delta: Vector2i) -> Rect2i:
	var max_position := Vector2i(
		maxi(blueprint.size_cells.x - rect.size.x, 0),
		maxi(blueprint.size_cells.y - rect.size.y, 0)
	)
	return Rect2i(
		Vector2i(
			clampi(rect.position.x + delta.x, 0, max_position.x),
			clampi(rect.position.y + delta.y, 0, max_position.y)
		),
		rect.size
	)
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
			&"structure_rect", &"transition", &"interaction_anchor", &"excluded_rect", \
			&"fade_rect", &"decal_rect", &"view_landmark":
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
