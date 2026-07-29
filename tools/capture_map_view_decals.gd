extends SceneTree

## P0-157 evidence: before/after orthographic captures of a synthetic courtyard
## with and without soot/mud/blood projected wear decals.
## Run (needs a display): godot --path . --script tools/capture_map_view_decals.gd

const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")
const MapViewBridge := preload("res://scripts/map/view3d/map_view_bridge.gd")
const OUTPUT_DIR := "res://docs/reports/images/decals"
const VIEWPORT_SIZE := Vector2i(960, 540)


func _initialize() -> void:
	call_deferred("_run")


func _showcase(with_decals: bool) -> MapDefinition:
	var definition := MapDefinition.new()
	definition.map_id = &"decal_showcase"
	definition.seed = MapTypes.DEFAULT_SEED
	definition.cell_size = MapTypes.DEFAULT_CELL_SIZE
	definition.size_cells = Vector2i(12, 12)
	definition.base_terrain = MapTypes.TERRAIN_COBBLESTONE
	definition.player_spawn = Vector2(6.0, 6.0) * float(definition.cell_size)
	definition.location = &"test"
	definition.scope = &"prototype"
	definition.active = false
	definition.palette = &"clean_painted"
	definition.fingerprint = "decal_showcase_v1"
	definition.camera_bounds = definition.cell_rect_to_world_rect(Rect2i(0, 0, 12, 12))
	definition.source_references = ["tools/capture_map_view_decals.gd"]
	definition.surroundings_sides = {}
	if with_decals:
		definition.decals = [
			{"id": &"soot_forge", "kind": MapTypes.DECAL_KIND_SOOT, "position": Vector2(160.0, 150.0), "radius": 2.2},
			{"id": &"mud_threshold", "kind": MapTypes.DECAL_KIND_MUD, "position": Vector2(200.0, 175.0), "radius": 1.8},
			{"id": &"blood_aftermath", "kind": MapTypes.DECAL_KIND_BLOOD, "position": Vector2(185.0, 200.0), "radius": 1.5},
			{"id": &"scorch_mark", "kind": MapTypes.DECAL_KIND_SCORCH, "position": Vector2(145.0, 190.0), "radius": 1.7},
		]
	return definition


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for pair in [["before", false], ["after", true]]:
		var label: String = pair[0]
		var with_decals: bool = pair[1]
		var error := await _capture(_showcase(with_decals), label)
		if error != OK:
			quit(1)
			return
	print("P0-157 decal captures written under %s" % OUTPUT_DIR)
	quit(0)


func _capture(definition: MapDefinition, label: String) -> Error:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var view := MapView3D.create(definition, MapBuilder.build(definition), MapView3D.TIME_DAY)
	viewport.add_child(view)
	# Zoom in so soot/mud/blood patches read clearly in the before/after pair.
	var camera := view.view_camera()
	if camera != null and camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		camera.size = 8.0
		var focus := MapViewBridge.logic_to_world(Vector2(180.0, 170.0), definition.cell_size)
		camera.global_position = focus + Vector3(6.0, 8.0, 6.0)
		camera.look_at(focus, Vector3.UP)

	for _frame in 8:
		await process_frame
	var image := viewport.get_texture().get_image()
	var output := "%s/decal_showcase_%s.png" % [OUTPUT_DIR, label]
	var error := image.save_png(ProjectSettings.globalize_path(output))
	if error != OK:
		push_error("Could not save decal capture %s: %s" % [output, error_string(error)])
	else:
		print("Decal capture: %s" % output)
	viewport.queue_free()
	await process_frame
	return error
