extends SceneTree

## Review plate for blueprint-map forbs (R-1559, docs/SYSTEMS/VEGETATION_REALISM.md):
## a synthetic meadow with one patch each of plant.plantain, plant.dandelion,
## plant.clover and plant.burdock, rendered through MapView3D. Needs a renderer:
##   tools/godot_render.sh --script tools/capture_blueprint_forbs.gd [-- --tag=after]
## Output: build/forbs/blueprint_<patch>_<tag>.png

const OUTPUT_DIR := "res://build/forbs"
const MAP_TEXT := """rrmap 1
map test.forb_meadow loc.test_forb_meadow 32 20 meadow scope=prototype active=false \
palette=clean_painted_outdoor seed=1343 cell_size=32
terrain ground grass 0 0 32 20 order=1
style v_plantain style_variant=plant.plantain
style v_dandelion style_variant=plant.dandelion
style v_clover style_variant=plant.clover
style v_burdock style_variant=plant.burdock
terrain plantain_patch grass 2 2 12 7 order=2 style=v_plantain
terrain dandelion_patch grass 18 2 12 7 order=2 style=v_dandelion
terrain clover_patch grass 2 11 12 7 order=2 style=v_clover
terrain burdock_patch grass 18 11 12 7 order=2 style=v_burdock
spawn start 16 10
"""

var _tag := "now"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			_tag = arg.substr(6)
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var parsed := MapRrmapParser.parse(MAP_TEXT)
	if not parsed.is_ok():
		push_error(str(parsed.formatted_diagnostics()))
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600, 900)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var view := MapView3D.create(
		parsed.definition, MapBuilder.build(parsed.definition), MapView3D.ALL_TIMES[0]
	)
	viewport.add_child(view)
	for frame in 6:
		await process_frame
	var camera := _find_camera(view)
	if camera == null:
		push_error("MapView3D has no Camera3D")
		quit(1)
		return
	# One close orthographic shot per patch (cell centre, one cell = one metre).
	for shot: Array in [["plantain", Vector2(8, 5.5)], ["dandelion", Vector2(24, 5.5)],
			["clover", Vector2(8, 14.5)], ["burdock", Vector2(24, 14.5)]]:
		var focus := Vector3(shot[1].x, 0.0, shot[1].y)
		var offset := camera.global_transform.basis.z * 30.0
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 6.0
		for frame in 4:
			camera.global_position = focus + offset
			await process_frame
		var path := "%s/blueprint_%s_%s.png" % [OUTPUT_DIR, shot[0], _tag]
		viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		print("blueprint forb plate: ", path)
	quit(0)


func _find_camera(node: Node) -> Camera3D:
	if node is Camera3D:
		return node
	for child in node.get_children():
		var found := _find_camera(child)
		if found != null:
			return found
	return null
