extends SceneTree

## Review plates for the spirit-sight auras (R-1486, ADR 0041). GPU run:
##   tools/godot_render.sh --resolution 1280x720 --script tools/capture_spirit_auras.gd -- \
##     --out=res://docs/reports/images/spirit_auras
## Plates: a bright clear soul, a dim murky soul, a crowd (12 full auras, the
## rest as distant glows) and a dog. The real SpiritAuraManager picks the tiers.
## Frame budget in the same crowd, sight off vs on (add --disable-vsync):
##   tools/godot_render.sh --resolution 1280x720 --disable-vsync \
##     --script tools/capture_spirit_auras.gd -- --bench

const RIG_SCENE := preload("res://assets/characters/shared/shared_character_rig.tscn")
const AuraManager := preload("res://scripts/combat/spirit_aura_manager.gd")
const Animals := preload("res://scripts/map/view3d/map_view_medieval_animal_models.gd")

var _stage: Node3D
var _camera: Camera3D
var _manager: Node


func _init() -> void:
	var out := "res://build/spirit_auras"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	await process_frame
	if "--bench" in OS.get_cmdline_user_args():
		await _bench()
		quit()
		return
	await _plate(out + "/bright_clear_soul.png", _bright_clear)
	await _plate(out + "/dim_murky_soul.png", _dim_murky)
	await _plate(out + "/crowd.png", _crowd)
	await _plate(out + "/animal_dog.png", _animal)
	quit()


func _plate(path: String, build: Callable) -> void:
	_stage = Node3D.new()
	root.add_child(_stage)
	_add_world()
	_manager = AuraManager.new()
	_manager.follow_session = false
	_manager.state = GameState.new()
	_manager.fade = 1.0
	_stage.add_child(_manager)
	build.call()
	await _wait(0.4)
	_manager.refresh()
	# Let the comets run and the lights breathe before grabbing the frame.
	await _wait(1.6)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	# Retina viewports may double CLI resolution; evidence follows the 720p policy.
	if image.get_width() > 1280:
		image.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
	image.save_png(path)
	print("CAPTURED ", path)
	_stage.free()


## Mean frame time over the crowd with auras hidden, then shown. The same rigs
## and camera, so the difference is the aura cost (12 full + glows).
func _bench() -> void:
	_stage = Node3D.new()
	root.add_child(_stage)
	_add_world()
	_manager = AuraManager.new()
	_manager.follow_session = false
	_manager.state = GameState.new()
	_stage.add_child(_manager)
	_crowd()
	await _wait(1.0)
	var off: Dictionary = await _mean_frame_ms(240)
	_manager.fade = 1.0
	_manager.refresh()
	await _wait(0.5)
	var on: Dictionary = await _mean_frame_ms(240)
	var full := 0
	var glow := 0
	for body: Node3D in _manager.candidates():
		var view: SpiritAuraView = _manager.view_for(body)
		if view != null and view.tier == SpiritAuraView.Tier.FULL:
			full += 1
		elif view != null and view.tier == SpiritAuraView.Tier.GLOW:
			glow += 1
	print("AURA_BENCH ", JSON.stringify({
		"beings": _manager.candidates().size(), "full": full, "glow": glow,
		"sight_off": off, "sight_on": on,
		"gpu_delta_ms": snappedf(float(on["gpu_ms"]) - float(off["gpu_ms"]), 0.001),
	}))
	_stage.free()


## Mean measured viewport render time (GPU + CPU render thread). Wall-clock
## frame time is useless here: the render wrapper minimizes the window and
## macOS throttles it.
func _mean_frame_ms(frames: int) -> Dictionary:
	var viewport := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport, true)
	await RenderingServer.frame_post_draw
	var gpu := 0.0
	var cpu := 0.0
	for i in frames:
		await RenderingServer.frame_post_draw
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(viewport)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(viewport)
	# Deterministic cost; GL Compatibility reports no GPU timing (0).
	return {
		"gpu_ms": snappedf(gpu / frames, 0.001), "cpu_ms": snappedf(cpu / frames, 0.001),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
	}


func _bright_clear() -> void:
	var rig := _rig("PlayerRig", Vector3.ZERO, 0.0)
	_manager.register(rig, _profile([4, 3, 4, 5, 4, 5, 4], 1.0))
	_close_camera(Vector3(0.0, 1.35, 0.0), 4.6)


func _dim_murky() -> void:
	var rig := _rig("PlayerRig", Vector3.ZERO, 0.0)
	# Two closed lights (knots) and low clarity: choppy flow and smoke.
	_manager.register(rig, _profile([2, 0, 1, 1, 0, 2, 1], 0.12))
	_close_camera(Vector3(0.0, 1.35, 0.0), 4.6)


func _crowd() -> void:
	_rig("PlayerRig", Vector3.ZERO, 0.0)
	var index := 0
	for row in 4:
		for column in 6:
			var at := Vector3(float(column) * 2.3 - 5.0, 0.0, -float(row) * 3.2 + 2.0)
			if at.length() < 1.0:
				continue
			# Derived, deterministic profiles from stable fixture ids.
			var rig := _rig("Townsfolk%02dRig" % index, at, float(index) * 0.7)
			var id := StringName("capture.crowd_%02d" % index)
			_manager.register(rig, SpiritAuraProfile.from_record(id, {}))
			index += 1
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 16.0
	_stage.add_child(_camera)
	_camera.global_position = Vector3(14.0, 14.0, 14.0)
	_camera.look_at(Vector3(0.0, 1.0, -2.0))


func _animal() -> void:
	var dog := Node3D.new()
	dog.name = "Dog"
	_stage.add_child(dog)
	dog.rotation.y = 2.0
	Animals.add_model(dog, &"dog")
	_manager.register(dog, SpiritAuraProfile.for_species("dog"))
	_manager.center_override = Vector3.ZERO
	_close_camera(Vector3(0.0, 0.55, 0.0), 2.6)


func _rig(rig_name: String, at: Vector3, yaw: float) -> SharedCharacterRig:
	var rig := RIG_SCENE.instantiate() as SharedCharacterRig
	rig.name = rig_name
	_stage.add_child(rig)
	rig.global_position = at
	rig.rotation.y = yaw
	# The combat health ring is not part of the spirit-sight look.
	var ring := rig.get_node_or_null("HealthRing") as Node3D
	if ring != null:
		ring.visible = false
	return rig


func _close_camera(target: Vector3, distance: float) -> void:
	_camera = Camera3D.new()
	_camera.fov = 40.0
	_stage.add_child(_camera)
	_camera.global_position = target + Vector3(0.9, 0.35, 1.0).normalized() * distance
	_camera.look_at(target)


func _add_world() -> void:
	# A stand-in for the spirit-sight grade: dark, cold and desaturated.
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.06, 0.07, 0.12)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.45, 0.48, 0.62)
	environment.ambient_light_energy = 0.5
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 0.35
	var world := WorldEnvironment.new()
	world.environment = environment
	_stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.55
	sun.light_color = Color(0.7, 0.74, 1.0)
	_stage.add_child(sun)
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80.0, 80.0)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.22, 0.23, 0.27)
	ground.material_override = ground_material
	_stage.add_child(ground)


func _profile(values: Array, clarity: float) -> SpiritAuraProfile:
	var profile := SpiritAuraProfile.new()
	for i in values.size():
		profile.levels[SpiritAuraProfile.LIGHT_IDS[i]] = int(values[i])
	profile.clarity = clarity
	return profile


func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame
