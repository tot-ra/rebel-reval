class_name CityRuntime
extends RefCounted

## Installs the shared gameplay runtime (MapViewRuntime) on the seamless city
## view (ADR 0031). Same wiring as MapViewRuntimeBootstrap.install(), with the
## district-only steps left out: no flat 2D map to hide, no grid navigation
## click input and no district ambient fauna except the birds: flight and song
## run in a window that follows Kalev (see _install_birds). Sea and wind
## ambience run through the shared AmbienceController (see _install_ambience).

const Bootstrap := preload("res://scripts/map/view3d/map_view_runtime_bootstrap.gd")
const RuntimeActors := preload("res://scripts/map/view3d/map_view_runtime_actors.gd")
const MagicVfx := preload("res://scripts/map/view3d/map_view_magic_vfx.gd")
## Side of the square flight window around Kalev, and the lift above his ground
## so flights (7-15 m in the shared layer) clear 10 m eaves.
const BIRD_WINDOW := 160
const BIRD_LIFT := 8.0


static func install(
	scene_root: Node2D, view: CityMapView, player: CharacterBody2D
) -> MapViewRuntime:
	var runtime := MapViewRuntime.new()
	runtime.name = "MapViewRuntime"
	runtime._definition = view.definition
	runtime._player = player
	runtime._input.configure(runtime, player)
	runtime.view = view
	runtime.add_child(view)
	RuntimeActors.hide_player_canvas(player)

	runtime._player_rig = Bootstrap.PLAYER_RIG_SCENE.instantiate()
	runtime._player_rig.name = "PlayerRig"
	runtime._player_rig.add_to_group(&"player_view_rig")
	runtime.add_child(runtime._player_rig)

	runtime._camera = view.view_camera()
	runtime._camera.size = CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE
	runtime._camera_controller.configure(runtime._camera, runtime._player_rig, view, player)
	runtime._actor_controller.configure(
		runtime,
		runtime._definition,
		player,
		runtime._player_rig,
		view,
		runtime._camera_controller.follow_player,
		runtime._camera_controller.logic_direction_toward_camera
	)
	runtime._actor_controller.set_screen_shake_callback(runtime._camera_controller.add_screen_shake)

	scene_root.add_child(runtime)
	var magic_vfx: Node3D = MagicVfx.new()
	magic_vfx.name = "MagicVfx"
	runtime.add_child(magic_vfx)
	magic_vfx.call("bind", runtime._definition.cell_size, scene_root)
	magic_vfx.call("bind_world", runtime._definition, player, runtime._player_rig)
	runtime._player_rig.add_visual_layer(Bootstrap.PLAYER_LIGHT_LAYER)
	Bootstrap._install_player_fill_light(runtime._player_rig)
	runtime.set_process_unhandled_input(true)
	runtime._session.bind_session_state()
	runtime._actor_controller.register_view_actors(scene_root)
	runtime._configure_screen_relative_movement()
	runtime._sync_player(true)
	runtime._actor_controller.bind_player_health_ring()
	runtime._restore_cycle_from_music_director()
	view.set_calendar_date(runtime._session.current_calendar_date())
	view.apply_cycle_progress(runtime.cycle_progress)
	runtime._sync_music_cycle()
	runtime._bind_environment_runtime()
	_install_birds(runtime, view, player)
	_install_ambience(runtime)
	return runtime


## Birds over the city: the shared flight and song layers, with flights spawned
## across a BIRD_WINDOW square centred on Kalev and lifted above the local roofs
## (the district layer flies over the whole map box, which in a 1.6 km city
## would almost never pass near him).
static func _install_birds(runtime: MapViewRuntime, view: CityMapView, player: Node2D) -> void:
	var ambient: Variant = runtime._ambient_controller
	ambient.configure(runtime, runtime._definition, player, runtime._camera, view)
	ambient._install_bird_audio()
	ambient._install_bird_flight()
	var flight: Node = ambient.get("_bird_flight")
	flight.call(
		"configure", runtime._definition.map_id, &"lower_town", Vector2i(BIRD_WINDOW, BIRD_WINDOW)
	)
	flight.set("path_origin", _bird_origin.bind(player, view))


## Sea surf and wind (R-1550) through the shared AmbienceController, with the
## `reval_city` profile. Runs after _install_birds, which configures the ambient
## helper with the city definition, view and player.
static func _install_ambience(runtime: MapViewRuntime) -> void:
	runtime._ambient_controller._install_ambience()


static func _bird_origin(player: Node2D, view: CityMapView) -> Vector3:
	var xz := CityPlan.to_world_xz(player.global_position)
	# Fly over the highest ground in the window, so flights clear the Toompea klint.
	var top := view.plan.ground_height(xz)
	var half := BIRD_WINDOW * 0.5
	for dx: float in [-half, 0.0, half]:
		for dz: float in [-half, 0.0, half]:
			top = maxf(top, view.plan.ground_height(xz + Vector2(dx, dz)))
	return Vector3(xz.x - half, top + BIRD_LIFT, xz.y - half)
