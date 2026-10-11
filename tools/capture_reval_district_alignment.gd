extends SceneTree

const OUTPUT_PATH := "res://docs/reports/images/map_audit/reval_district_alignment.png"
const VIEWPORT_SIZE := Vector2i(1800, 1200)
const MAP_PATHS: PackedStringArray = [
	"res://content/maps/lower_town_slice.rrmap",
	"res://content/maps/market_civic_quarter.rrmap",
	"res://content/maps/south_quarter.rrmap",
	"res://content/maps/toompea_quarter.rrmap",
	"res://content/maps/archbishops_garden.rrmap",
	"res://content/maps/monastery_quarter.rrmap",
	"res://content/maps/north_quarter.rrmap",
	"res://content/maps/reval_harbor_north.rrmap",
	"res://content/maps/reval_harbor_east.rrmap",
	"res://content/maps/viru_gate_foreland.rrmap",
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var definitions: Array[MapDefinition] = []
	for path in MAP_PATHS:
		var parsed := MapRrmapParser.parse_file(path)
		if not parsed.is_ok():
			push_error("Cannot capture alignment; %s: %s" % [path, parsed.formatted_diagnostics()])
			quit(1)
			return
		definitions.append(parsed.definition)

	var layout := MapAlignmentMath.layout_connected_maps(definitions, &"lower_town_slice")
	if not (layout["unplaced"] as Array).is_empty():
		push_error("Cannot capture alignment; unplaced maps: %s" % str(layout["unplaced"]))
		quit(1)
		return
	print("Reval district alignment offsets: %s" % str(layout["offsets"]))

	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)

	var canvas := MapAlignmentCanvas.new()
	canvas.position = Vector2.ZERO
	canvas.show_grid = false
	canvas.show_ids = false
	canvas.show_features = true
	viewport.add_child(canvas)
	canvas.size = Vector2(VIEWPORT_SIZE)
	canvas.configure(definitions, layout["offsets"], layout["seams"])
	print("Reval district canvas size: %s; bounds: %s" % [canvas.size, canvas.visible_world_bounds()])
	canvas.fit_to_maps()

	await process_frame
	await process_frame
	await process_frame
	var image := viewport.get_texture().get_image()
	var absolute_path := ProjectSettings.globalize_path(OUTPUT_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var error := image.save_png(absolute_path)
	if error != OK:
		push_error("Could not save %s: %s" % [OUTPUT_PATH, error_string(error)])
		quit(1)
		return
	print("Reval district alignment capture: %s" % OUTPUT_PATH)
	quit(0)
