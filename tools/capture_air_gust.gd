extends SceneTree

## R-913 studio plates plus R-927 in-map gameplay-camera plates.
## Run with a rendering-capable process (no --headless):
##   tools/godot_render.sh --script tools/capture_air_gust.gd

const KALEV_SCENE := preload("res://assets/characters/kalev/kalev.tscn")
const WATCHMAN_SCENE := preload("res://assets/characters/variants/watchman.tscn")
const BANDIT_SCENE := preload("res://assets/characters/variants/bandit.tscn")
const ENEMY_SCRIPT := preload("res://scripts/combat/combat_room_enemy.gd")
const LowerTownSlice := preload(
	"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
)
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const CharacterScale := preload("res://assets/characters/shared/character_scale.gd")
const CONTENT_DIRS: Array[String] = [
	"res://content/examples/valid",
	"res://content/examples/support",
]
const OUTPUT_DIR := "res://docs/reports/images/air_gust"
const VIEWPORT_SIZE := Vector2i(1440, 810)
const CELL_SIZE := 32
const GUST_RADIUS := 112.0
const GUST_ARC := 90.0
const CASTER_LOGIC := Vector2.ZERO
const TARGET_LOGIC := Vector2(64.0, 0.0)
const CAST_DIR := Vector2.RIGHT
const MID_SLIDE_SEC := 0.10
const IN_MAP_FOCUS_ANCHOR := &"street_start"
const IN_MAP_WARMUP_FRAMES := 16
const AIR: Array[StringName] = [&"element.air"]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	# WHY: rerunning the in-map pair must not rewrite the accepted R-924 studio plates.
	var skip_studio := "--skip-studio" in OS.get_cmdline_user_args()
	if not skip_studio:
		if not await _capture_combat_room_watchman():
			quit(1)
			return
		if not await _capture_workers_district_bandit():
			quit(1)
			return
	if not await _capture_in_map_lower_town():
		quit(1)
		return
	quit(0)


func _capture_combat_room_watchman() -> bool:
	# The combat-room scene pulls SessionState/HUD autoloads that the render
	# wrapper's first compile can miss. Use the same CombatRoomEnemy host the
	# room uses, so the plate is the watchman actor without booting the HUD.
	var host := Node2D.new()
	root.add_child(host)
	var caster := Node2D.new()
	host.add_child(caster)
	caster.global_position = CASTER_LOGIC
	var watchman := ENEMY_SCRIPT.new() as CombatRoomEnemy
	host.add_child(watchman)
	watchman.configure(EnemyArchetype.watchman(), Color.WHITE)
	watchman.global_position = TARGET_LOGIC
	watchman.set_ai_target(caster)
	watchman.set_process(false)
	watchman.set_physics_process(false)
	var ok := await _capture_pair(
		"combat_room_watchman",
		caster,
		watchman,
		KALEV_SCENE,
		WATCHMAN_SCENE
	)
	host.free()
	return ok


func _capture_workers_district_bandit() -> bool:
	var host := Node2D.new()
	root.add_child(host)
	var caster := Node2D.new()
	host.add_child(caster)
	caster.global_position = CASTER_LOGIC
	var bandit := WorkersDistrictBandit.new()
	host.add_child(bandit)
	bandit.configure_bandit(caster)
	bandit.global_position = TARGET_LOGIC
	bandit.set_process(false)
	bandit.set_physics_process(false)
	var ok := await _capture_pair(
		"workers_district_bandit",
		caster,
		bandit,
		KALEV_SCENE,
		BANDIT_SCENE
	)
	host.free()
	return ok


func _capture_in_map_lower_town() -> bool:
	# WHY: R-924 only judged the studio floor. R-927 needs the same cone on a
	# playable Lower Town street at the shipped gameplay orthographic size.
	var definition := LowerTownSlice.create()
	if definition == null or String(definition.map_id) != "lower_town_slice":
		push_error("R-927 expected lower_town_slice, got %s" % definition.map_id)
		return false
	if not MapVerification.has_anchor(definition, IN_MAP_FOCUS_ANCHOR):
		push_error("R-927 missing anchor %s" % String(IN_MAP_FOCUS_ANCHOR))
		return false
	# street_start is the playable Lower Town spawn on the east-west spine.
	# Midpoint of checkpoint_west -> brewery_door sat inside roof mass.
	var heading := Vector2.RIGHT
	var focus_logic := MapVerification.anchor_position(definition, IN_MAP_FOCUS_ANCHOR)
	var caster_logic := focus_logic - heading * 32.0
	var target_logic := focus_logic + heading * 32.0
	var cell_size := definition.cell_size
	var host := Node2D.new()
	root.add_child(host)
	var caster := Node2D.new()
	host.add_child(caster)
	caster.global_position = caster_logic
	var watchman := ENEMY_SCRIPT.new() as CombatRoomEnemy
	host.add_child(watchman)
	watchman.configure(EnemyArchetype.watchman(), Color.WHITE)
	watchman.global_position = target_logic
	watchman.set_ai_target(caster)
	watchman.set_process(false)
	watchman.set_physics_process(false)

	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var view := MapView3D.create(
		definition, MapBuilder.build(definition), MapView3D.TIME_DAY
	)
	viewport.add_child(view)
	var vfx := MapViewMagicVfx.new()
	vfx.name = "MagicVfx"
	view.add_child(vfx)
	var caster_rig := KALEV_SCENE.instantiate() as SharedCharacterRig
	var target_rig := WATCHMAN_SCENE.instantiate() as SharedCharacterRig
	view.add_child(caster_rig)
	view.add_child(target_rig)
	caster_rig.add_to_group(&"player_view_rig")
	_sync_in_map_rig(view, caster_rig, caster_logic, heading)
	_sync_in_map_rig(view, target_rig, target_logic, -heading)
	caster_rig.play_animation(&"idle")
	target_rig.play_animation(&"idle")
	var camera := view.view_camera()
	if camera == null:
		push_error("R-927 MapView3D has no camera")
		viewport.queue_free()
		host.free()
		return false
	var focus_world := view.world_position(focus_logic, 0.8)
	_configure_gameplay_camera(camera, focus_world)
	print(
		"R-927 focus_logic=%s focus_world=%s caster_y=%.3f"
		% [focus_logic, focus_world, caster_rig.position.y]
	)
	_add_caption(viewport, "in map lower town day")
	var fog := view.get_node_or_null("FogOfWar")
	if fog != null:
		fog.call("update_view", caster_rig.global_position)
	for _frame in IN_MAP_WARMUP_FRAMES:
		await process_frame

	if not await _save(viewport, "in_map_lower_town_before"):
		return false
	if not _cast_gust(caster, watchman.get_parent(), heading):
		push_error("Air Gust cast failed for in-map Lower Town")
		return false
	var burst := vfx.play_knockback_cone(
		caster_logic, heading, GUST_RADIUS, GUST_ARC, cell_size
	)
	if burst != null:
		# Street terrain may sit above y=0; keep the studio-authored wedge on the road.
		burst.position.y = caster_rig.position.y
	target_rig.play_animation(&"hit")
	_step_knockback(watchman, caster, MID_SLIDE_SEC)
	_sync_in_map_rig(view, target_rig, watchman.global_position, -heading)
	if fog != null:
		fog.call("update_view", caster_rig.global_position)
	if not await _save(viewport, "in_map_lower_town_mid"):
		return false
	_step_knockback(watchman, caster, CombatKnockbackEffect.SLIDE_SEC)
	_sync_in_map_rig(view, target_rig, watchman.global_position, -heading)
	if not await _save(viewport, "in_map_lower_town_after"):
		return false
	viewport.queue_free()
	host.free()
	await process_frame
	return true


func _configure_gameplay_camera(camera: Camera3D, focus_world: Vector3) -> void:
	# Studio plates use size 7.0 so the wedge fills the frame. In-map plates
	# must use the shipped gameplay crop so cobble and foliage stay in shot.
	camera.rotation_degrees = Vector3(
		MapView3D.CAMERA_PITCH_DEGREES, MapView3D.CAMERA_YAW_DEGREES, 0.0
	)
	camera.size = CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE
	camera.global_position = (
		focus_world + camera.global_transform.basis.z * MapView3D.CAMERA_DISTANCE
	)
	camera.current = true


func _sync_in_map_rig(
	view: MapView3D, rig: SharedCharacterRig, logic: Vector2, facing: Vector2
) -> void:
	view.sync_actor(rig, logic)
	rig.set_facing(facing)


func _capture_pair(
	slug: String,
	caster: Node2D,
	target: CombatRoomEnemy,
	caster_scene: PackedScene,
	target_scene: PackedScene
) -> bool:
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
	var caster_rig := caster_scene.instantiate() as SharedCharacterRig
	var target_rig := target_scene.instantiate() as SharedCharacterRig
	stage.add_child(caster_rig)
	stage.add_child(target_rig)
	_sync_rig(caster_rig, caster.global_position, CAST_DIR)
	_sync_rig(target_rig, target.global_position, -CAST_DIR)
	caster_rig.play_animation(&"idle")
	target_rig.play_animation(&"idle")
	var camera := _build_camera()
	viewport.add_child(camera)
	var mid := MapViewBridge.logic_to_world(Vector2(48.0, 0.0), CELL_SIZE, 0.7)
	camera.look_at(mid, Vector3.UP)
	camera.current = true
	_add_caption(viewport, slug.replace("_", " "))

	if not await _save(viewport, "%s_before" % slug):
		return false

	if not _cast_gust(caster, target.get_parent()):
		push_error("Air Gust cast failed for %s" % slug)
		return false
	vfx.play_knockback_cone(caster.global_position, CAST_DIR, GUST_RADIUS, GUST_ARC, CELL_SIZE)
	target_rig.play_animation(&"hit")
	_step_knockback(target, caster, MID_SLIDE_SEC)
	_sync_rig(target_rig, target.global_position, -CAST_DIR)
	if not await _save(viewport, "%s_mid" % slug):
		return false

	_step_knockback(target, caster, CombatKnockbackEffect.SLIDE_SEC)
	_sync_rig(target_rig, target.global_position, -CAST_DIR)
	if not await _save(viewport, "%s_after" % slug):
		return false

	viewport.queue_free()
	await process_frame
	return true


func _cast_gust(caster: Node2D, host: Node, heading: Vector2 = CAST_DIR) -> bool:
	var db := ContentDB.new()
	if not db.load_from_directories(CONTENT_DIRS):
		return false
	var state := GameState.new()
	state.set_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER, 1)
	if not MagicResolver.apply_grant_operation(state, db, &"magic.grant.starter_air_gust"):
		return false
	var result := MagicResolver.cast(state, db, &"", AIR)
	if not bool(result.get("ok", false)):
		return false
	return MagicCastExecutor2D.execute(result, caster, heading, host) != null


func _step_knockback(target: CombatRoomEnemy, caster: Node2D, seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.0:
		var step := minf(0.05, remaining)
		target.tick_ai(step, caster)
		remaining -= step


func _sync_rig(
	rig: SharedCharacterRig,
	logic: Vector2,
	facing: Vector2,
	cell_size: int = CELL_SIZE
) -> void:
	MapViewBridge.sync_actor(rig, logic, cell_size)
	rig.set_facing(facing)


func _build_camera() -> Camera3D:
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	# Tighter than gameplay 33.75 so the 3.5-unit cone and 3-unit slide read.
	camera.size = 7.0
	camera.near = 0.05
	camera.far = 80.0
	var mid := MapViewBridge.logic_to_world(Vector2(48.0, 0.0), CELL_SIZE, 0.7)
	var offset := Vector3(5.4, 4.2, 5.4)
	camera.position = mid + offset
	return camera


func _build_stage() -> Node3D:
	var stage := Node3D.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.10, 0.12, 0.13)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.68, 0.72)
	environment.ambient_light_energy = 0.48
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, -38.0, 0.0)
	sun.light_color = Color(1.0, 0.88, 0.72)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	stage.add_child(sun)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(18.0, 18.0)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color8(118, 108, 92)
	floor_material.roughness = 1.0
	var floor := MeshInstance3D.new()
	floor.mesh = floor_mesh
	floor.material_override = floor_material
	stage.add_child(floor)
	return stage


func _add_caption(viewport: SubViewport, title: String) -> void:
	var layer := CanvasLayer.new()
	viewport.add_child(layer)
	var label := Label.new()
	label.text = "Air Gust - %s" % title
	label.position = Vector2(28.0, 20.0)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(0.94, 0.93, 0.88))
	layer.add_child(label)


func _save(viewport: SubViewport, slug: String) -> bool:
	for _frame in 10:
		await process_frame
	var output := "%s/%s.png" % [OUTPUT_DIR, slug]
	var error := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(output))
	if error != OK:
		push_error("Could not save Air Gust capture %s: %s" % [output, error_string(error)])
		return false
	print("Air Gust capture: %s" % output)
	return true
