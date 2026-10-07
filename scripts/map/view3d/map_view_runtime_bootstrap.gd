class_name MapViewRuntimeBootstrap
extends RefCounted

## One-shot MapViewRuntime wiring: hide 2D visuals, mount MapView3D, player rig,
## camera, session/environment bindings, and ambient installers.

const PLAYER_RIG_SCENE := preload("res://assets/characters/variants/apprentice.tscn")
const PLAYER_LIGHT_LAYER := 20
const PLAYER_FILL_LIGHT_COLOR := Color8(255, 226, 196)
const PLAYER_FILL_LIGHT_ENERGY := 0.65
const PLAYER_FILL_LIGHT_RANGE := 3.5

const RuntimeCamera := preload("res://scripts/map/view3d/map_view_runtime_camera.gd")
const RuntimeActors := preload("res://scripts/map/view3d/map_view_runtime_actors.gd")
const RuntimeFlatMap := preload("res://scripts/map/view3d/map_view_runtime_flat_map.gd")
const MagicVfx := preload("res://scripts/map/view3d/map_view_magic_vfx.gd")


static func install(
	scene_root: Node2D, bootstrap: Dictionary, map_root: CanvasItem, player: CharacterBody2D
) -> MapViewRuntime:
	var runtime := MapViewRuntime.new()
	runtime.name = "MapViewRuntime"
	runtime._definition = bootstrap["definition"]
	runtime._player = player
	runtime._input.configure(runtime, player)
	runtime.view = MapView3D.create(bootstrap["definition"], bootstrap["grid"])
	runtime.add_child(runtime.view)

	map_root.visible = false
	RuntimeFlatMap.hide_visuals(bootstrap)
	RuntimeFlatMap.bind_streamed_visual_hiding(bootstrap)
	RuntimeActors.hide_player_canvas(player)

	runtime._player_rig = PLAYER_RIG_SCENE.instantiate()
	runtime._player_rig.name = "PlayerRig"
	runtime._player_rig.add_to_group(&"player_view_rig")
	runtime.add_child(runtime._player_rig)

	runtime._camera = runtime.view.view_camera()
	runtime._camera.size = CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE
	runtime._camera_controller.configure(
		runtime._camera, runtime._player_rig, runtime.view, runtime._player
	)
	runtime._actor_controller.configure(
		runtime,
		runtime._definition,
		runtime._player,
		runtime._player_rig,
		runtime.view,
		runtime._camera_controller.follow_player,
		runtime._camera_controller.logic_direction_toward_camera
	)
	runtime._actor_controller.set_screen_shake_callback(runtime._camera_controller.add_screen_shake)
	if player.has_method("set_mud_wetness_provider"):
		player.call("set_mud_wetness_provider", runtime.view.mud_wetness)

	scene_root.add_child(runtime)
	# WHY: MagicAreaPulse2D still frees in the same frame. The view-only wind
	# cone has to watch the 2D tree from the installed 3D runtime or Air Gust
	# stays a debug arc. CombatKnockbackEffect is unchanged.
	var magic_vfx: Node3D = MagicVfx.new()
	magic_vfx.name = "MagicVfx"
	runtime.add_child(magic_vfx)
	magic_vfx.call("bind", runtime._definition.cell_size, scene_root)
	# R-1198: ground height under effects and the iron-ward overlay on Kalev.
	magic_vfx.call("bind_world", runtime._definition, runtime._player, runtime._player_rig)
	# The rig's _ready() creates distance LOD meshes; assign the isolated light
	# layer only after the runtime enters the tree so every generated visual gets it.
	runtime._player_rig.add_visual_layer(PLAYER_LIGHT_LAYER)
	_install_player_fill_light(runtime._player_rig)
	# Created at runtime, so enable input explicitly before the first frame.
	runtime.set_process_unhandled_input(true)
	runtime._session.bind_session_state()
	runtime._actor_controller.register_view_actors(scene_root)
	runtime._configure_screen_relative_movement()
	runtime._sync_player(true)

	runtime._actor_controller.bind_player_health_ring()
	# WHY: Each district used to restart at DEFAULT_PROGRESS, so harbor kept a
	# moving sun while Workers' District (and any fresh map) snapped morning.
	# MusicDirector holds both clock fractions and completed solar days so scene
	# transitions cannot rewind the date or lunar phase.
	runtime._restore_cycle_from_music_director()
	runtime.view.set_calendar_date(runtime._session.current_calendar_date())
	runtime.view.apply_cycle_progress(runtime.cycle_progress)
	runtime._sync_music_cycle()
	# `SessionState` owns the canonical weather snapshot; this runtime only binds
	# its renderer after the shared clock has been restored.
	runtime._bind_environment_runtime()
	runtime._ambient_controller.configure(
		runtime,
		runtime._definition,
		runtime._player,
		runtime._camera,
		runtime.view
	)
	runtime._ambient_controller.install()
	runtime._input.install_click_input()
	return runtime


## WB-06b: the same wiring as install(), but the Player, PlayerRig, camera, view,
## environment and minimap are the WorldHost's. The runtime creates none of them,
## so it binds instead of instantiating and the host census stays one of each.
## The runtime itself stays under `scene_root` (WorldHost rejects a runtime inside
## a location package), and the host clock replaces the MusicDirector restore.
static func install_hosted(
	scene_root: Node2D, host: Node, location_id: StringName
) -> MapViewRuntime:
	# `host` is a WorldHost, typed Node so this preload chain never compiles it.
	var bootstrap: Dictionary = host.call(&"hosted_bootstrap", location_id)
	var hosted_view := host.call(&"hosted_view", location_id) as MapView3D
	var player := host.get(&"player_owner") as CharacterBody2D
	var player_rig := host.get(&"player_rig") as SharedCharacterRig
	if bootstrap.is_empty() or hosted_view == null or player == null or player_rig == null:
		push_error("MapViewRuntime.install_hosted: %s is not mounted with globals" % location_id)
		return null
	var runtime := MapViewRuntime.new()
	runtime.name = "MapViewRuntime"
	runtime.world_host = host
	runtime._environment.world_host = host
	runtime._definition = bootstrap["definition"]
	runtime._player = player
	runtime._input.configure(runtime, player)
	# Host-owned: never re-parented here, so freeing the runtime leaves it alive.
	runtime.view = hosted_view
	RuntimeActors.hide_player_canvas(player)
	runtime._player_rig = player_rig
	runtime._camera = host.get(&"camera_owner") as Camera3D
	runtime._camera.size = CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE
	runtime._camera_controller.configure(
		runtime._camera, runtime._player_rig, runtime.view, runtime._player
	)
	runtime._actor_controller.configure(
		runtime,
		runtime._definition,
		runtime._player,
		runtime._player_rig,
		runtime.view,
		runtime._camera_controller.follow_player,
		runtime._camera_controller.logic_direction_toward_camera
	)
	runtime._actor_controller.set_screen_shake_callback(runtime._camera_controller.add_screen_shake)
	if player.has_method("set_mud_wetness_provider"):
		player.call("set_mud_wetness_provider", runtime.view.mud_wetness)

	scene_root.add_child(runtime)
	var magic_vfx: Node3D = MagicVfx.new()
	magic_vfx.name = "MagicVfx"
	runtime.add_child(magic_vfx)
	magic_vfx.call("bind", runtime._definition.cell_size, scene_root)
	# R-1198: ground height under effects and the iron-ward overlay on Kalev.
	magic_vfx.call("bind_world", runtime._definition, runtime._player, runtime._player_rig)
	# The host rig outlives this runtime; add the light layer and fill only once.
	if runtime._player_rig.get_node_or_null("ReadabilityFill") == null:
		runtime._player_rig.add_visual_layer(PLAYER_LIGHT_LAYER)
		_install_player_fill_light(runtime._player_rig)
	runtime.set_process_unhandled_input(true)
	runtime._session.bind_session_state()
	runtime._actor_controller.register_view_actors(scene_root)
	runtime._configure_screen_relative_movement()
	runtime._sync_player(true)

	runtime._actor_controller.bind_player_health_ring()
	runtime._environment.restore_from_world_host()
	runtime.view.set_calendar_date(runtime._session.current_calendar_date())
	host.call(&"set_clock_progress", runtime.cycle_progress)
	runtime._sync_music_cycle()
	runtime._bind_environment_runtime()
	runtime._ambient_controller.configure(
		runtime,
		runtime._definition,
		runtime._player,
		runtime._camera,
		runtime.view
	)
	runtime._ambient_controller.install()
	runtime._input.install_click_input()
	# Seed location-space terrain sampling. Full consumer rebind waits for a
	# seam crossing so launch teardown stays identical to the flag-on path.
	var origin: Vector2 = host.call(&"location_origin_logic_position", location_id)
	if player.has_method("configure_map_movement"):
		player.call(
			"configure_map_movement",
			runtime._definition,
			bootstrap["grid"],
			origin
		)
	runtime._owning_location_id = location_id
	return runtime


static func _install_player_fill_light(player_rig: SharedCharacterRig) -> void:
	# A layer-isolated fill keeps Kalev readable when his front faces away from
	# the sun, without flattening authored map lighting or illuminating NPCs.
	var fill := OmniLight3D.new()
	fill.name = "ReadabilityFill"
	fill.position = Vector3(0.0, 1.35, 0.75)
	fill.light_color = PLAYER_FILL_LIGHT_COLOR
	fill.light_energy = PLAYER_FILL_LIGHT_ENERGY
	fill.omni_range = PLAYER_FILL_LIGHT_RANGE
	fill.shadow_enabled = false
	fill.light_cull_mask = 1 << (PLAYER_LIGHT_LAYER - 1)
	player_rig.add_child(fill)
