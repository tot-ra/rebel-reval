extends SceneTree

## WB-07 (R-979) visual parity plates: the same map assembled synchronously and
## through the staged assemble_async() path, rendered in the same frame from two
## own-world SubViewports, then compared pixel by pixel. Needs a GPU renderer:
##   tools/godot_render.sh --script tools/capture_wb07_assembly_parity.gd
##   tools/godot_render.sh --rendering-method mobile --rendering-driver metal \
##     --script tools/capture_wb07_assembly_parity.gd
## Writes docs/reports/images/wb07/<map>_<renderer>_{sync,staged}.png and prints
## one PARITY line per map with the differing-pixel count. Append `-- --control`
## to compare two synchronous builds instead (the renderer's own noise floor).

const OUTPUT_DIR := "res://docs/reports/images/wb07"
const VIEWPORT_SIZE := Vector2i(1280, 720)
const SETTLE_FRAMES := 6
const TOLERANCE := 8.0 / 255.0
const MAP_SCRIPTS := {
	&"lower_town_slice": "res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd",
	&"kalev_smithy": "res://scripts/map/definitions/lower_town/kalev_smithy_definition.gd",
	&"reval_harbor_east": "res://scripts/map/definitions/outdoor/reval_harbor_east_definition.gd",
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var renderer := RenderingServer.get_current_rendering_method()
	var failed := false
	for map_id: StringName in MAP_SCRIPTS:
		var definition: MapDefinition = load(String(MAP_SCRIPTS[map_id])).create()
		var grid: MapTerrainGrid = MapBuilder.build(definition)
		var staged_viewport := _viewport()
		# --control swaps the staged view for a second synchronous one, so the
		# printed counts give the noise floor two identical builds already show
		# (particles, flame flicker) before any staged difference is claimed.
		var control := OS.get_cmdline_user_args().has("--control")
		var staged := (
			MapView3D.create(definition, grid) if control else MapView3D.create_staged(definition, grid)
		)
		# Assembled detached, like create(): nothing simulates or renders until the
		# finished view is mounted in one add_child, so no half-built location shows.
		if not control and not await staged.assemble_async():
			push_error("Staged assembly did not complete for %s" % map_id)
			failed = true
			continue
		var sync_viewport := _viewport()
		var synchronous := MapView3D.create(definition, grid)
		# Mounted in the same frame so both clocks and weather start together.
		staged_viewport.add_child(staged)
		sync_viewport.add_child(synchronous)
		for view: MapView3D in [synchronous, staged]:
			# Freeze weather drift so the plates compare geometry, not cloud motion.
			view.set_weather_time_scale(0.0)
		for frame in SETTLE_FRAMES:
			await process_frame
		var sync_image := sync_viewport.get_texture().get_image()
		var staged_image := staged_viewport.get_texture().get_image()
		var stem := "%s/%s_%s%s" % [OUTPUT_DIR, map_id, renderer, "_control" if control else ""]
		sync_image.save_png(ProjectSettings.globalize_path(stem + "_sync.png"))
		staged_image.save_png(ProjectSettings.globalize_path(stem + "_staged.png"))
		var mask := Image.create(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, false, Image.FORMAT_RGB8)
		var counts := _differing_pixels(sync_image, staged_image, mask)
		mask.save_png(ProjectSettings.globalize_path(stem + "_diff.png"))
		print(
			"PARITY %s %s%s exact_differing=%d over_tolerance=%d of %d"
			% [
				map_id,
				renderer,
				" control" if control else "",
				counts.x,
				counts.y,
				VIEWPORT_SIZE.x * VIEWPORT_SIZE.y
			]
		)
		sync_viewport.queue_free()
		staged_viewport.queue_free()
		await process_frame
	quit(1 if failed else 0)


func _viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	return viewport


## x = pixels that differ at all, y = pixels whose largest channel delta exceeds
## TOLERANCE (8/255). The mask paints tolerance failures red, sub-tolerance grey.
static func _differing_pixels(first: Image, second: Image, mask: Image) -> Vector2i:
	if first.get_size() != second.get_size():
		return Vector2i(first.get_width() * first.get_height(), first.get_width() * first.get_height())
	var counts := Vector2i.ZERO
	for y in first.get_height():
		for x in first.get_width():
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			if a == b:
				continue
			counts.x += 1
			var delta := maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))
			if delta > TOLERANCE:
				counts.y += 1
				mask.set_pixel(x, y, Color.RED)
			else:
				mask.set_pixel(x, y, Color(0.35, 0.35, 0.35))
	return counts
