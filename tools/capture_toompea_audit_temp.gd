extends SceneTree

const Registry := preload("res://scripts/map/map_audit_registry.gd")
const Renderer := preload("res://scripts/map/definitions/outdoor/outdoor_prototype_renderer.gd")
const MANIFEST_PATH := "res://content/map_audit_manifest.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manifest := _load_manifest()
	if manifest.is_empty():
		quit(1)
		return
	var capture: Dictionary = manifest["capture"]
	var output_dir := "res://%s" % String(capture["directory"])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var definitions := Registry.by_id()
	var viewport_size := _vector2i(capture["viewport_px"])
	var panel_size := Vector2(_vector2i(capture["panel_world_px"]))
	var world_scale := float(capture["world_scale"])

	for row in manifest["maps"]:
		var map_id := String(row["id"])
		if map_id != "toompea_quarter":
			continue
		if not definitions.has(map_id):
			push_error("Capture manifest map is not executable: %s" % map_id)
			quit(1)
			return
		var definition: MapDefinition = definitions[map_id]
		var viewport := SubViewport.new()
		viewport.size = viewport_size
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		viewport.transparent_bg = false
		viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		root.add_child(viewport)
		_add_background(viewport, viewport_size)
		_add_map(viewport, definition, world_scale, panel_size)
		_add_overlay(viewport, row, definition, world_scale)

		await process_frame
		await process_frame
		var image := viewport.get_texture().get_image()
		var output := "%s/%s" % [output_dir, row["capture"]]
		var error := image.save_png(ProjectSettings.globalize_path(output))
		if error != OK:
			push_error("Could not save map audit capture %s: %s" % [output, error_string(error)])
			quit(1)
			return
		print("Map audit capture: %s" % output)
		viewport.queue_free()
		await process_frame
	quit(0)


func _add_background(viewport: SubViewport, viewport_size: Vector2i) -> void:
	var background := ColorRect.new()
	background.color = Color8(31, 30, 28)
	background.size = Vector2(viewport_size)
	viewport.add_child(background)
	var panel := ColorRect.new()
	panel.position = Vector2(31, 99)
	panel.size = Vector2(1026, 578)
	panel.color = Color8(75, 71, 64)
	viewport.add_child(panel)
	var map_background := ColorRect.new()
	map_background.position = Vector2(32, 100)
	map_background.size = Vector2(1024, 576)
	map_background.color = Color8(45, 44, 41)
	viewport.add_child(map_background)


func _add_map(viewport: SubViewport, definition: MapDefinition, world_scale: float, panel_size: Vector2) -> void:
	var renderer := Renderer.new()
	renderer.configure(definition, MapBuilder.build(definition))
	renderer.scale = Vector2.ONE * world_scale
	renderer.position = Vector2(32, 100)
	viewport.add_child(renderer)
	var rendered_size := definition.world_size() * world_scale
	assert(rendered_size.x <= panel_size.x and rendered_size.y <= panel_size.y)


func _add_overlay(
	viewport: SubViewport,
	row: Dictionary,
	definition: MapDefinition,
	world_scale: float
) -> void:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(overlay)
	_add_label(overlay, row["location_name"], Vector2(32, 24), 30, Color8(239, 227, 204), 1000.0)
	_add_label(
		overlay,
		"%s  |  %d x %d cells  |  fixed world scale %.2f"
			% [definition.map_id, definition.size_cells.x, definition.size_cells.y, world_scale],
		Vector2(34, 64),
		17,
		Color8(184, 177, 163),
		1000.0
	)
	_add_label(overlay, "TERRAIN LEGEND", Vector2(1110, 104), 22, Color8(239, 227, 204), 430.0)
	var used := MapBuilder.build(definition).used_terrain_ids()
	for index in used.size():
		var terrain: StringName = used[index]
		var y := 150.0 + float(index) * 34.0
		var swatch := ColorRect.new()
		swatch.position = Vector2(1110, y)
		swatch.size = Vector2(24, 24)
		swatch.color = OutdoorTerrainPalette.color(terrain)
		overlay.add_child(swatch)
		_add_label(overlay, String(terrain).replace("_", " "), Vector2(1146, y - 1), 18, Color8(218, 211, 198), 380.0)
	_add_label(overlay, "Red marker: required spawn", Vector2(1110, 765), 16, Color8(201, 193, 179), 430.0)
	_add_label(overlay, "Gold line: declared inspection/patrol route", Vector2(1110, 792), 16, Color8(201, 193, 179), 450.0)
	_add_label(overlay, "Fingerprint: %s" % definition.fingerprint.left(24), Vector2(32, 710), 16, Color8(184, 177, 163), 1020.0)
	_add_label(overlay, "Source scene retained: %s" % row["scene"], Vector2(32, 742), 16, Color8(184, 177, 163), 1020.0)


func _add_label(
	parent: Control,
	text: String,
	position: Vector2,
	font_size: int,
	color: Color,
	width: float
) -> void:
	var label := Label.new()
	label.position = position
	label.size = Vector2(width, float(font_size + 10))
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.04, 0.03, 0.02, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(label)


func _load_manifest() -> Dictionary:
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		push_error("Cannot read %s" % MANIFEST_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Invalid map audit manifest JSON")
		return {}
	return parsed


func _vector2i(values: Array) -> Vector2i:
	return Vector2i(int(values[0]), int(values[1]))
