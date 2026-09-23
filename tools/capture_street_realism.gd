extends SceneTree

## Street-surface and fortification realism evidence for the Lower Town slice.
##
## WHY: the ground/masonry realism pass changes procedural materials only, so the
## review needs matched gameplay-range plates of the same authored map instead of
## a synthetic showcase. Each preset is a fixed perspective pose over production
## content (Viru Gate approach, road surface, city wall), so before/after images
## are directly comparable.
##
## Requires a rendering-capable run (no --headless):
##   /Applications/Godot.app/Contents/MacOS/Godot --path . \
##     --rendering-method gl_compatibility --rendering-driver opengl3 \
##     --script tools/capture_street_realism.gd -- --label before

const LowerTownSlice := preload(
	"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
)
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")

const OUTPUT_DIR := "res://docs/reports/images/street_realism"
const VIEWPORT_SIZE := Vector2i(1280, 720)
const WARMUP_FRAMES := 16

## Poses are authored in logic cells (one cell equals one world unit) so they stay
## readable next to the .rrmap source that owns the same coordinates.
const PRESETS: Array[Dictionary] = [
	{
		"id": "viru_gate_approach",
		"eye": Vector3(96.0, 2.4, 55.5),
		"target": Vector3(112.0, 1.6, 55.5),
		"fov": 62.0,
		"coverage": "Viru Street looking east into the gate towers and city wall",
	},
	{
		"id": "road_surface",
		"eye": Vector3(99.0, 1.5, 52.0),
		"target": Vector3(104.0, 0.0, 55.5),
		"fov": 55.0,
		"coverage": "packed-earth/cobble street surface, puddles and loose stones",
	},
	{
		"id": "city_wall",
		"eye": Vector3(104.0, 2.6, 30.0),
		"target": Vector3(111.0, 3.4, 33.0),
		"fov": 58.0,
		"coverage": "north city wall curtain and round wall tower masonry",
	},
	{
		"id": "gate_passage",
		"eye": Vector3(105.0, 1.8, 53.0),
		"target": Vector3(113.0, 2.4, 54.5),
		"fov": 60.0,
		"coverage": "Viru gate arch, jambs and tower bases at walking range",
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
	print("Street realism captures (%s) written under %s" % [label, OUTPUT_DIR])
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

	# The shipped gameplay camera is orthographic; evidence for surface detail needs
	# eye-level perspective, so the capture adds its own camera instead of moving the
	# production one out of its authored dimetric pose.
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
		push_error("Street realism viewport has no texture for %s" % preset["id"])
		viewport.queue_free()
		await process_frame
		return ERR_CANT_CREATE
	var output := "%s/%s_%s.png" % [OUTPUT_DIR, preset["id"], label]
	var error := texture.get_image().save_png(ProjectSettings.globalize_path(output))
	if error != OK:
		push_error("Could not save street realism capture %s: %s" % [output, error_string(error)])
	else:
		print("Street realism capture: %s" % output)
	viewport.queue_free()
	await process_frame
	return error
