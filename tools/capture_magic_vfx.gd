extends SceneTree

## R-1198 studio plates for the 3D Fireball, Earth Tremor and Iron Skin looks,
## plus in-map plates on Lower Town at the shipped gameplay camera (day, night).
## Run with a rendering-capable process (no --headless):
##   tools/godot_render.sh --script tools/capture_magic_vfx.gd [-- --skip-studio]

const KALEV_SCENE := preload("res://assets/characters/kalev/kalev.tscn")
const LowerTownSlice := preload(
	"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
)
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const CharacterScale := preload("res://assets/characters/shared/character_scale.gd")
const OUTPUT_DIR := "res://docs/reports/images/magic_vfx"
const VIEWPORT_SIZE := Vector2i(1440, 810)
const CELL_SIZE := 32
const FIRE_IMPACT_LOGIC := Vector2(112.0, 0.0)
const FIRE_SPLASH_PX := 72.0
const TREMOR_RADIUS_PX := 96.0
const IN_MAP_FOCUS_ANCHOR := &"street_start"
const IN_MAP_WARMUP_FRAMES := 16
## Kalev stands this far from street_start: at the anchor itself a south-side
## chimney's night smoke column covers him on screen, and the smoke drifts
## east. Then the cast heading (north, open cobbles toward the gabled houses)
## and distances in logic px.
const IN_MAP_CASTER_OFFSET := Vector2(144.0, -16.0)
const IN_MAP_HEADING := Vector2.UP
const IN_MAP_FIRE_START := 24.0
const IN_MAP_FIRE_IMPACT := 112.0
const IN_MAP_TREMOR_CENTER := 48.0
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
	# WHY: rerunning the in-map pass must not rewrite the accepted studio plates.
	if not "--skip-studio" in OS.get_cmdline_user_args():
		for capture: Callable in [_capture_fireball, _capture_tremor, _capture_iron_skin]:
			if not await capture.call():
				quit(1)
				return
	for time_of_day: StringName in [MapView3D.TIME_DAY, MapView3D.TIME_NIGHT]:
		if not await _capture_in_map_lower_town(time_of_day):
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
	host.add_child(projectile)
	# Logic stays still so the flight plate frames the trail behind the core.
	# WHY after add_child: entering the tree re-enables _physics_process, and
	# the projectile then flew ~200 px past the framed impact point.
	projectile.set_physics_process(false)
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


## In-map pass: the studio floor hid how the effects sit on real cobbles under
## map lighting (no reflection probes, night lamps). Same LowerTownSlice,
## street_start focus and gameplay orthographic crop as capture_air_gust.gd.
func _capture_in_map_lower_town(time_of_day: StringName) -> bool:
	var definition := LowerTownSlice.create()
	if definition == null or String(definition.map_id) != "lower_town_slice":
		push_error("In-map magic VFX expected lower_town_slice")
		return false
	if not MapVerification.has_anchor(definition, IN_MAP_FOCUS_ANCHOR):
		push_error("In-map magic VFX missing anchor %s" % String(IN_MAP_FOCUS_ANCHOR))
		return false
	var prefix := "in_map_%s" % String(time_of_day)
	var focus_logic := (
		MapVerification.anchor_position(definition, IN_MAP_FOCUS_ANCHOR) + IN_MAP_CASTER_OFFSET
	)
	var host := Node2D.new()
	root.add_child(host)
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var view := MapView3D.create(definition, MapBuilder.build(definition), time_of_day)
	viewport.add_child(view)
	# create() only stages assembly; without finishing it only sky and ground render.
	await view.assemble_async(200.0)
	view.update_active_chunks_from_logic_positions([focus_logic])
	view.set_weather_time_scale(0.0)
	var vfx := MapViewMagicVfx.new()
	vfx.name = "MagicVfx"
	view.add_child(vfx)
	vfx.bind(definition.cell_size, host)
	var actor := CombatTestDummy.new()
	host.add_child(actor)
	actor.global_position = focus_logic
	var rig := KALEV_SCENE.instantiate() as SharedCharacterRig
	view.add_child(rig)
	rig.add_to_group(&"player_view_rig")
	view.sync_actor(rig, focus_logic)
	rig.set_facing(IN_MAP_HEADING)
	rig.play_animation(&"idle")
	# Same binding as map_view_runtime_bootstrap.gd: terrain height plus ward rig.
	vfx.bind_world(definition, actor, rig)
	var camera := view.view_camera()
	if camera == null:
		push_error("In-map magic VFX: MapView3D has no camera")
		return false
	view.set_close_camera_mode(false)
	var focus_world := view.world_position(focus_logic + IN_MAP_HEADING * IN_MAP_TREMOR_CENTER, 0.8)
	_configure_gameplay_camera(camera, focus_world)
	_add_caption(viewport, "Lower Town %s" % String(time_of_day))
	var fog := view.get_node_or_null("FogOfWar")
	if fog != null:
		fog.call("update_view", rig.global_position)
	for _frame in IN_MAP_WARMUP_FRAMES:
		await process_frame

	var projectile := MagicProjectile2D.new()
	var configured := projectile.configure(
		actor,
		&"spell.capture",
		IN_MAP_HEADING,
		{
			"delivery": {"kind": "projectile", "speed": 320.0, "range": 640.0},
			"impact": {"kind": "damage", "amount": 1.0, "damage_type": "fire"},
		}
	)
	if not configured:
		push_error("In-map fireball projectile did not configure")
		return false
	host.add_child(projectile)
	projectile.set_physics_process(false)
	projectile.global_position = focus_logic + IN_MAP_HEADING * IN_MAP_FIRE_START
	for _step in 12:
		projectile.global_position += IN_MAP_HEADING * 4.0
		await process_frame
	if not await _save(viewport, "%s_fireball_flight" % prefix):
		return false
	projectile.queue_free()
	vfx.play_fire_burst(
		focus_logic + IN_MAP_HEADING * IN_MAP_FIRE_IMPACT, FIRE_SPLASH_PX, definition.cell_size
	)
	await _wait(0.18)
	if not await _save(viewport, "%s_fireball_impact" % prefix, 2):
		return false
	# Let the fire burst finish so the tremor plate is not lit by its embers.
	await _wait(MapViewMagicVfx.FIRE_BURST_DURATION_SEC)
	vfx.play_area_pulse_ring(
		focus_logic + IN_MAP_HEADING * IN_MAP_TREMOR_CENTER, TREMOR_RADIUS_PX, definition.cell_size
	)
	await _wait(1.2)
	if not await _save(viewport, "%s_earth_tremor_cracks" % prefix, 2):
		return false
	await _wait(MapViewMagicVfx.PULSE_DURATION_SEC)
	if not CombatTimedModifiers.apply_module_to(actor, WARD_MODULE):
		push_error("In-map Iron Skin could not apply damage_reduction")
		return false
	await _wait(1.65)
	if not await _save(viewport, "%s_iron_skin_held" % prefix, 2):
		return false
	viewport.queue_free()
	host.queue_free()
	await process_frame
	return true


func _configure_gameplay_camera(camera: Camera3D, focus_world: Vector3) -> void:
	camera.rotation_degrees = Vector3(
		MapView3D.CAMERA_PITCH_DEGREES, MapView3D.CAMERA_YAW_DEGREES, 0.0
	)
	camera.size = CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE
	camera.global_position = (
		focus_world + camera.global_transform.basis.z * MapView3D.CAMERA_DISTANCE
	)
	camera.current = true


func _add_caption(viewport: SubViewport, title: String) -> void:
	var layer := CanvasLayer.new()
	viewport.add_child(layer)
	var label := Label.new()
	label.text = title
	label.position = Vector2(28.0, 20.0)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(0.94, 0.93, 0.88))
	layer.add_child(label)


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
	print("Magic VFX capture: %s %s" % [output, _luma_stats(viewport.get_texture().get_image())])
	return true


## Mean luma and the share of near-white pixels, so blow-out is judged by numbers.
func _luma_stats(image: Image) -> String:
	var total := 0.0
	var clipped := 0
	var count := 0
	for y in range(0, image.get_height(), 4):
		for x in range(0, image.get_width(), 4):
			var pixel: Color = image.get_pixel(x, y)
			total += pixel.get_luminance()
			if minf(pixel.r, minf(pixel.g, pixel.b)) > 0.96:
				clipped += 1
			count += 1
	return "mean_luma=%.1f clipped=%.2f%%" % [total / count * 255.0, 100.0 * clipped / count]
