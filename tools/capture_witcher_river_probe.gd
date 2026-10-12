extends SceneTree

## Gap-analysis probe against a Witcher 3 autumn river village shot (still water
## mirroring an autumn wood, log houses with thatch, stone arch bridge, rowing boat,
## reeds and a plank jetty in the foreground). Frames the Hareapea stream of the
## seamless city at eye height over the water, early October, low afternoon sun,
## stock grade. Report: docs/reports/witcher_river_village_gap_2026-10-12.md.
##   tools/godot_render.sh --script tools/capture_witcher_river_probe.gd [-- --progress=0.68]
## Output: build/witcher_river/{reach,bend,mouth,village}.png

const OUTPUT_DIR := "res://build/witcher_river"
const VIEWPORT_SIZE := Vector2i(1600, 768)
const DATE := {"year": 1343, "month": 10, "day": 5}

var _progress := 0.68


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--progress="):
			_progress = float(arg.substr(11))
	call_deferred("_run")


## Point `t` of the way along stream segment `i`, its downstream direction and surface.
func _on_stream(plan: CityPlan, i: int, t: float) -> Dictionary:
	var hj: Dictionary = plan.data["harjapea"]
	var pts := CityPlan.points(hj["points"])
	var a: Vector2 = pts[i]
	var b: Vector2 = pts[i + 1]
	var s := lerpf(float(hj["surfaces"][i]), float(hj["surfaces"][i + 1]), t)
	return {"at": a.lerp(b, t), "dir": (b - a).normalized(), "surface": s}


func _run() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var plan := CityPlan.load_default()
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var view := CityMapView.create_city(plan)
	viewport.add_child(view)
	var camera: Camera3D = view._camera
	camera.fov = 55.0
	MapViewMaterials.apply_vegetation_season(DATE)
	view.world.apply_season(DATE)
	view.world.apply_time(_progress)
	# [name, segment, t, eye height over water, look distance downstream, side offset]
	var specs := [
		["reach", 1, 0.2, 1.6, 40.0, 0.0], ["bend", 3, 0.1, 1.6, 45.0, 2.0],
		["mouth", 4, 0.1, 1.8, 50.0, -2.0], ["village", 2, 0.3, 2.5, 60.0, 6.0],
	]
	for spec: Array in specs:
		var s := _on_stream(plan, int(spec[1]), float(spec[2]))
		var dir: Vector2 = s["dir"]
		var surface := float(s["surface"])
		var eye: Vector2 = s["at"] + dir.orthogonal() * float(spec[5])
		var look: Vector2 = eye + dir * float(spec[4])
		camera.look_at_from_position(
			Vector3(eye.x, surface + float(spec[3]), eye.y),
			Vector3(look.x, surface + 2.0, look.y), Vector3.UP)
		for i in 30:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/%s.png" % [OUTPUT_DIR, spec[0]]
		viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		print("witcher river plate: ", path)
	viewport.queue_free()
	for frame in 3:
		await process_frame
	quit(0)
