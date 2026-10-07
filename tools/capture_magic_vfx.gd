extends SceneTree

## R-1198 studio plates for the 3D Fireball, Earth Tremor and Iron Skin looks.
## Run with a rendering-capable process (no --headless):
##   tools/godot_render.sh --script tools/capture_magic_vfx.gd

const KALEV_SCENE := preload("res://assets/characters/kalev/kalev.tscn")
const OUTPUT_DIR := "res://docs/reports/images/magic_vfx"
const VIEWPORT_SIZE := Vector2i(1440, 810)
const CELL_SIZE := 32
const FIRE_IMPACT_LOGIC := Vector2(112.0, 0.0)
const FIRE_SPLASH_PX := 72.0
const TREMOR_RADIUS_PX := 96.0
const WARD_MODULE := {
	"kind": "damage_reduction",
	"modifier_id": "modifier.capture_ward",
	"amount": 0.35,
	"duration_sec": 30.0,
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for capture: Callable in [_capture_fireball, _capture_tremor, _capture_iron_skin]:
		if not await capture.call():
			quit(1)
			return
	quit(0)


func _capture_fireball() -> bool:
	var stage := _open_stage("Fireball", Vector2(56.0, 0.0))
	var host: Node2D = stage.host
	var vfx: MapViewMagicVfx = stage.vfx
	var caster := Node2D.new()
	host.add_child(caster)
	var projectile := MagicProjectile2D.new()
	var configured := projectile.configure(
		caster,
		&"spell.capture",
		Vector2.RIGHT,
		{
			"delivery": {"kind": "projectile", "speed": 320.0, "range": 640.0},
			"impact": {"kind": "damage", "amount": 1.0, "damage_type": "fire"},
		}
	)
	if not configured:
		push_error("Fireball capture projectile did not configure")
		return false
	# Logic stays still so the flight plate frames the trail behind the core.
	projectile.set_physics_process(false)
	host.add_child(projectile)
	projectile.global_position = Vector2(24.0, 0.0)
	for _step in 12:
		projectile.global_position += Vector2(4.0, 0.0)
		await process_frame
	if not await _save(stage.viewport, "fireball_flight"):
		return false
	projectile.queue_free()
	vfx.play_fire_burst(FIRE_IMPACT_LOGIC, FIRE_SPLASH_PX, CELL_SIZE)
	await _wait(0.18)
	if not await _save(stage.viewport, "fireball_impact", 2):
		return false
	await _wait(1.3)
	if not await _save(stage.viewport, "fireball_aftermath", 2):
		return false
	return await _close_stage(stage)


func _capture_tremor() -> bool:
	var stage := _open_stage("Earth Tremor", Vector2(40.0, 0.0))
	var vfx: MapViewMagicVfx = stage.vfx
	vfx.play_area_pulse_ring(Vector2.ZERO, TREMOR_RADIUS_PX, CELL_SIZE)
	await _wait(0.3)
	if not await _save(stage.viewport, "earth_tremor_shock", 2):
		return false
	await _wait(0.9)
	if not await _save(stage.viewport, "earth_tremor_cracks", 2):
		return false
	return await _close_stage(stage)


func _capture_iron_skin() -> bool:
	var stage := _open_stage("Iron Skin", Vector2.ZERO, 4.2)
	var vfx: MapViewMagicVfx = stage.vfx
	var actor := CombatTestDummy.new()
	stage.host.add_child(actor)
	vfx.bind_world(null, actor, stage.rig)
	if not await _save(stage.viewport, "iron_skin_before"):
		return false
	if not CombatTimedModifiers.apply_module_to(actor, WARD_MODULE):
		push_error("Iron Skin capture could not apply damage_reduction")
		return false
	await _wait(0.25)
	if not await _save(stage.viewport, "iron_skin_cast", 2):
		return false
	await _wait(1.4)
	if not await _save(stage.viewport, "iron_skin_held", 2):
		return false
	return await _close_stage(stage)


## Studio stage: Kalev at the logic origin facing +X, an orthographic camera on
## `focus_logic`, and a MapViewMagicVfx bound to a 2D host for logic nodes.
func _open_stage(title: String, focus_logic: Vector2, camera_size: float = 7.0) -> Dictionary:
	var host := Node2D.new()
	root.add_child(host)
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stage := _build_stage()
	viewport.add_child(stage)
	var vfx := MapViewMagicVfx.new()
	vfx.name = "MagicVfx"
	stage.add_child(vfx)
	vfx.bind(CELL_SIZE, host)
	var rig := KALEV_SCENE.instantiate() as SharedCharacterRig
	stage.add_child(rig)
	MapViewBridge.sync_actor(rig, Vector2.ZERO, CELL_SIZE)
	rig.set_facing(Vector2.RIGHT)
	rig.play_animation(&"idle")
	var focus := MapViewBridge.logic_to_world(focus_logic, CELL_SIZE, 0.7)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = camera_size
	camera.near = 0.05
	camera.far = 80.0
	viewport.add_child(camera)
	camera.position = focus + Vector3(5.4, 4.2, 5.4)
	camera.look_at(focus, Vector3.UP)
	camera.current = true
	var layer := CanvasLayer.new()
	viewport.add_child(layer)
	var label := Label.new()
	label.text = title
	label.position = Vector2(28.0, 20.0)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(0.94, 0.93, 0.88))
	layer.add_child(label)
	return {"host": host, "viewport": viewport, "vfx": vfx, "rig": rig}


func _close_stage(stage: Dictionary) -> bool:
	(stage.viewport as Node).queue_free()
	(stage.host as Node).queue_free()
	await process_frame
	return true


func _build_stage() -> Node3D:
	# Dusk-lit floor so flame light and the iron sheen read against ambient.
	var stage := Node3D.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.08, 0.09, 0.10)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.6, 0.66)
	environment.ambient_light_energy = 0.4
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, -38.0, 0.0)
	sun.light_color = Color(1.0, 0.86, 0.7)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	stage.add_child(sun)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(24.0, 24.0)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color8(112, 104, 90)
	floor_material.roughness = 1.0
	var floor := MeshInstance3D.new()
	floor.mesh = floor_mesh
	floor.material_override = floor_material
	stage.add_child(floor)
	return stage


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _save(viewport: SubViewport, slug: String, settle_frames: int = 10) -> bool:
	for _frame in settle_frames:
		await process_frame
	var output := "%s/%s.png" % [OUTPUT_DIR, slug]
	var error := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(output))
	if error != OK:
		push_error("Could not save magic VFX capture %s: %s" % [output, error_string(error)])
		return false
	print("Magic VFX capture: %s" % output)
	return true
