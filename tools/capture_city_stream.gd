extends SceneTree

## Review plates of the Hareapea stream in the city: the banks (water reaches the
## waterline, reed belt, no trees in the bed, murky brown water) and a wader's
## wake (ripple sim impulses walked along the stream, as MapViewSwimmerPresenter
## feeds them). Needs a renderer:
##   tools/godot_render.sh --script tools/capture_city_stream.gd [-- --tag=<t>]
## Output: build/stream/{bank_up,bank_low,bank_mouth,top,wake,pool_swim}_<t>.png

const OUTPUT_DIR := "res://build/stream"
const VIEWPORT_SIZE := Vector2i(1600, 900)
const DAY_PROGRESS := 0.42

var _tag := "now"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			_tag = arg.substr(6)
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
	await process_frame  # Register autoloads before loading the real player for the pool plate.
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
	camera.fov = 60.0
	view.world.apply_time(DAY_PROGRESS)
	var shots: Array[Dictionary] = []
	var specs := [
		["bank_up", 1, 0.5, 16.0, 3.0], ["bank_low", 3, 0.4, 18.0, 2.2], ["bank_mouth", 4, 0.3, 20.0, 4.0]
	]
	for spec: Array in specs:
		var s := _on_stream(plan, int(spec[1]), float(spec[2]))
		var dir: Vector2 = s["dir"]
		var surface := float(s["surface"])
		var eye: Vector2 = s["at"] + dir.orthogonal() * float(spec[3]) - dir * 10.0
		shots.append(
			{
				"name": spec[0],
				"eye": Vector3(eye.x, maxf(plan.ground_height(eye), surface) + float(spec[4]), eye.y),
				"look": Vector3(s["at"].x, surface, s["at"].y) + Vector3(dir.x, 0, dir.y) * 12.0,
			}
		)
	var top := _on_stream(plan, 1, 0.5)
	shots.append(
		{
			"name": "top",
			"eye": Vector3(top["at"].x + 0.5, float(top["surface"]) + 70.0, top["at"].y),
			"look": Vector3(top["at"].x, top["surface"], top["at"].y),
		}
	)
	var water := view.world.get_node("Water/Harjapea") as MeshInstance3D
	print("stream ribbon aabb %s" % water.get_aabb())
	for shot in shots:
		var lk: Vector3 = shot["look"]
		var lk2 := Vector2(lk.x, lk.z)
		print(
			"%s look ground %.2f surface %.2f"
			% [shot["name"], plan.ground_height(lk2), view.world.water_surface_at(lk2)]
		)
		camera.look_at_from_position(shot["eye"], shot["look"], Vector3.UP)
		for i in 8:
			await process_frame
		_save(viewport, shot["name"])
	# Wake: walk a wader 12 units down the middle of the stream at 2.5 units/s.
	var sim := view.water_ripple_sim()
	if sim == null:
		push_error("no ripple sim on this tier")
	else:
		var w := _on_stream(plan, 2, 0.5)
		var dir: Vector2 = w["dir"]
		var start: Vector2 = w["at"] - dir * 6.0
		var side := dir.orthogonal()
		var eye := start + side * 9.0 - dir * 4.0
		camera.look_at_from_position(
			Vector3(eye.x, float(w["surface"]) + 5.0, eye.y),
			Vector3(w["at"].x, w["surface"], w["at"].y),
			Vector3.UP
		)
		var speed := 2.5
		for f in 300:
			var p := start + dir * minf(speed * float(f) / 60.0, 12.0)
			if f < 290:
				sim.add_moving_body(p, dir * speed, 0.7 * 0.9, 0.32 * 0.9)
			await process_frame
		_save(viewport, "wake")
	await _capture_pool(viewport, view, camera)
	viewport.queue_free()
	for frame in 3:
		await process_frame
	quit(0)


## Controlled traversal through the Viru pool with the real Player water state
## and swimmer presenter, not a posed mesh or a manually forced SWIM enum.
func _capture_pool(viewport: SubViewport, view: CityMapView, camera: Camera3D) -> void:
	var player: CharacterBody2D = load("res://player.tscn").instantiate()
	viewport.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.hide()
	player.call("set_water_depth_provider", func(logic: Vector2) -> float:
		return view.water_depth_at(CityPlan.to_world_xz(logic)))
	var rig: SharedCharacterRig = load("res://assets/characters/kalev/kalev.tscn").instantiate()
	view.add_child(rig)
	rig.play_animation(&"idle")
	var presenter: RefCounted = load(
		"res://scripts/map/view3d/map_view_swimmer_presenter.gd"
	).new()
	var pool := Vector2(617.64, 294.69)
	var direction := Vector2(-30, -110).normalized()
	var speed := 1.5
	player.velocity = CityPlan.to_logic(direction * speed)
	rig.set_facing(direction)
	var surface := view.world.water_surface_at(pool)
	var eye := pool + direction.orthogonal() * 4.5 - direction * 3.0
	camera.look_at_from_position(
		Vector3(eye.x, surface + 2.5, eye.y),
		Vector3(pool.x, surface + 0.1, pool.y), Vector3.UP)
	for frame in 120:
		var p := pool + direction * (float(frame) / 60.0 - 1.0) * speed
		player.global_position = CityPlan.to_logic(p)
		player.call("_update_water", 1.0 / 60.0)
		view.sync_actor(rig, player.global_position)
		presenter.call("apply", rig, player, view, Vector2.ZERO,
			player.velocity.length(), 1.0 / 60.0)
		if int(player.call("water_medium")) != PlayerSwimState.Medium.SWIM:
			push_error("Viru pool traversal did not enter SWIM")
			quit(1)
			return
		await process_frame
	print("POOL_SWIM medium=%d depth=%.3f position=%s" % [
		player.call("water_medium"), player.call("water_depth"), rig.position])
	_save(viewport, "pool_swim")
	rig.queue_free()
	player.queue_free()
	await process_frame


func _save(viewport: SubViewport, name: String) -> void:
	var path := "%s/%s_%s.png" % [OUTPUT_DIR, name, _tag]
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("captured %s" % path)
