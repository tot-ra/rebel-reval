extends SceneTree

## City wall, Viru gate and fortification roof evidence for the Lower Town slice.
##
## WHY: masonry scale, seam flicker, tower cone tiles, wall-walk roof tiles and
## gate/beam timber are all procedural material or primitive changes, so review
## needs matched before/after plates of the same authored gate and wall. Presets
## mix eye-level poses (masonry scale, gate leaves) with elevated poses close to
## the gameplay camera pitch, because roofs are mostly read from above.
##
## Requires a rendering-capable run (no --headless):
##   tools/godot_render.sh \
##     --rendering-method gl_compatibility --rendering-driver opengl3 \
##     --script tools/capture_fortification_realism.gd -- --label before

const LowerTownSlice := preload(
	"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
)
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")

const OUTPUT_DIR := "res://docs/reports/images/fortification_realism"
const VIEWPORT_SIZE := Vector2i(1280, 720)
const WARMUP_FRAMES := 16

## Poses are authored in logic cells (one cell equals one world unit) so they stay
## readable next to the .rrmap source that owns the same coordinates.
const PRESETS: Array[Dictionary] = [
	{
		"id": "viru_gate_approach",
		"eye": Vector3(96.0, 2.4, 55.5),
		"target": Vector3(112.0, 3.0, 55.5),
		"fov": 62.0,
	},
	{
		"id": "gate_passage",
		"eye": Vector3(105.0, 1.8, 53.0),
		"target": Vector3(113.0, 2.0, 54.5),
		"fov": 60.0,
	},
	{
		"id": "gate_leaves_close",
		"eye": Vector3(107.5, 1.7, 54.5),
		"target": Vector3(112.0, 1.4, 52.5),
		"fov": 55.0,
	},
	{
		"id": "gate_leaf_face",
		"eye": Vector3(112.2, 1.5, 54.6),
		"target": Vector3(113.2, 1.3, 52.0),
		"fov": 62.0,
	},
	{
		"id": "city_wall_masonry",
		"eye": Vector3(105.0, 2.2, 36.0),
		"target": Vector3(111.0, 3.0, 38.0),
		"fov": 55.0,
	},
	{
		"id": "wall_walk_gallery",
		"eye": Vector3(113.0, 11.2, 12.0),
		"target": Vector3(113.2, 10.4, 22.0),
		"fov": 62.0,
	},
	{
		"id": "wall_walk_stairs",
		"eye": Vector3(100.0, 3.2, 38.0),
		"target": Vector3(107.0, 3.4, 34.0),
		"fov": 58.0,
	},
	{
		"id": "gate_roofs_elevated",
		"eye": Vector3(92.0, 18.0, 70.0),
		"target": Vector3(112.0, 6.0, 55.0),
		"fov": 50.0,
	},
	{
		"id": "wall_walk_roof_elevated",
		"eye": Vector3(100.0, 13.0, 20.0),
		"target": Vector3(112.0, 7.0, 30.0),
		"fov": 50.0,
	},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var label := _label_from_args(OS.get_cmdline_user_args())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var definition := LowerTownSlice.create()
	var grid := MapBuilder.build(definition)
	for preset: Dictionary in PRESETS:
		var error := await _capture(definition, grid, preset, label)
		if error != OK:
			quit(1)
			return
	print("Fortification captures (%s) written under %s" % [label, OUTPUT_DIR])
	quit(0)


static func _label_from_args(args: Array) -> String:
	var index := 0
	while index < args.size():
		if String(args[index]) == "--label" and index + 1 < args.size():
			return String(args[index + 1])
		index += 1
	return "after"


func _capture(
	definition: MapDefinition, grid: Variant, preset: Dictionary, label: String
) -> Error:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var view := MapView3D.create(definition, grid, MapView3D.TIME_DAY)
	viewport.add_child(view)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = float(preset.get("fov", 60.0))
	camera.near = 0.05
	camera.far = 400.0
	view.add_child(camera)
	camera.global_position = preset["eye"]
	camera.look_at(preset["target"], Vector3.UP)
	camera.current = true

	for _frame in WARMUP_FRAMES:
		await process_frame
	var texture := viewport.get_texture()
	if texture == null:
		push_error("Fortification viewport has no texture for %s" % preset["id"])
		viewport.queue_free()
		await process_frame
		return ERR_CANT_CREATE
	var output := "%s/%s_%s.png" % [OUTPUT_DIR, preset["id"], label]
	var error := texture.get_image().save_png(ProjectSettings.globalize_path(output))
	if error != OK:
		push_error("Could not save fortification capture %s: %s" % [output, error_string(error)])
	else:
		print("Fortification capture: %s" % output)
	viewport.queue_free()
	await process_frame
	return error
