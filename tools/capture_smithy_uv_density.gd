extends SceneTree

## R-1000 evidence: Kalev smithy interior wall plaster density before/after the
## R-997 uv1_scale fix. "after" is the shipped material; "before" rewrites each
## library wall material to the old BoxMesh-sized uv1_scale, in memory only.
## Run: tools/godot_render.sh --script tools/capture_smithy_uv_density.gd
## Optional tag after "--": --tag=metal (suffix for the output file names).

const OUTPUT_DIR := "res://docs/reports/images"
const VIEWPORT_SIZE := Vector2i(1280, 720)
const EYE_HEIGHT := 1.65
## 90 faces along the long wall.
const YAWS: Array[float] = [90.0]


func _initialize() -> void:
	call_deferred("_run")


func _tag() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			return "_" + arg.substr(6)
	return ""


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var definition: MapDefinition = KalevSmithyDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)

	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var view := MapView3D.create(definition, grid, MapView3D.TIME_DAY)
	viewport.add_child(view)
	view.set_interior_shell_for_first_person(true)

	var scale := MapViewBridge.world_scale(definition.cell_size)
	var spawn := definition.player_spawn
	var eye := Vector3(spawn.x * scale, EYE_HEIGHT, spawn.y * scale)
	var camera := Camera3D.new()
	camera.fov = 75.0
	camera.near = 0.05
	camera.position = eye
	viewport.add_child(camera)
	camera.make_current()

	# After first: the shipped state.
	var ok := await _shoot(viewport, camera, "after")
	if ok:
		var rewritten := _revert_to_box_scale(view)
		print("before: rewrote %d library wall materials" % rewritten)
		ok = rewritten > 0 and await _shoot(viewport, camera, "before")
	quit(0 if ok else 1)


## Restores the pre-R-997 uv1_scale (BoxMesh atlas, length-dependent) on every
## interior wall mesh that carries a library stem, and logs both values.
func _revert_to_box_scale(node: Node) -> int:
	var count := 0
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		var box := mi.mesh as BoxMesh
		if box == null:
			continue
		# Interior walls are a BoxMesh with material_override (see
		# map_view_mesh_builder_buildings.gd), not per-surface materials.
		var mat := mi.material_override as StandardMaterial3D
		if mat == null or not mat.has_meta(MapViewMaterials.BUILDING_MATERIALS.LIBRARY_STEM_META):
			continue
		var stem := String(mat.get_meta(MapViewMaterials.BUILDING_MATERIALS.LIBRARY_STEM_META))
		var old: Vector3 = MapViewMaterials.BUILDING_MATERIALS.library_box_uv_scale(stem, box.size)
		print("wall %s size %s uv1_scale after=%s before=%s" % [mi.name, box.size, mat.uv1_scale, old])
		var copy := mat.duplicate() as StandardMaterial3D
		copy.uv1_scale = old
		mi.material_override = copy
		count += 1
	return count


func _shoot(viewport: SubViewport, camera: Camera3D, phase: String) -> bool:
	for yaw in YAWS:
		camera.rotation_degrees = Vector3(-10.0, yaw, 0.0)
		for frame in 6:
			await process_frame
		var out := "%s/r997_interior_uv_%s_yaw%03d%s.png" % [OUTPUT_DIR, phase, int(yaw), _tag()]
		if viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(out)) != OK:
			push_error("Could not save " + out)
			return false
		print("capture: " + out)
	return true
