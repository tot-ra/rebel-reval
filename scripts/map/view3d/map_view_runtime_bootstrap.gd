class_name MapViewRuntimeBootstrap
extends RefCounted

## One-shot MapViewRuntime wiring: hide 2D visuals, mount MapView3D, player rig,
## camera, session/environment bindings, and ambient installers.

const PLAYER_RIG_SCENE := preload("res://assets/characters/kalev/kalev.tscn")
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
