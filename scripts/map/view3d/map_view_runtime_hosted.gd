class_name MapViewRuntimeHosted
extends RefCounted

## WB-08 owner rebinding for a hosted MapViewRuntime. Seam crossings retarget
## terrain, view, ambient, camera and minimap while the Player, camera and HUD
## instances stay put. Kept beside the runtime facade because this axis changes
## independently of install, camera and ambient.

var _host: MapViewRuntime


func configure(runtime_host: MapViewRuntime) -> void:
	_host = runtime_host


func bind_owning_location(location_id: StringName) -> bool:
	if _host == null or _host.world_host == null or location_id.is_empty():
		return false
	var bootstrap: Dictionary = _host.world_host.call(&"hosted_bootstrap", location_id)
	var hosted_view := _host.world_host.call(&"hosted_view", location_id) as MapView3D
	var definition := bootstrap.get("definition") as MapDefinition
	var grid := bootstrap.get("grid") as MapTerrainGrid
	if bootstrap.is_empty() or hosted_view == null or definition == null or grid == null:
		return false
	_host._owning_location_id = location_id
	_host._definition = definition
	_host.view = hosted_view
	var origin: Vector2 = _host.world_host.call(
		&"location_origin_logic_position", location_id
	)
	var player: CharacterBody2D = _host._player
	if player != null and player.has_method("configure_map_movement"):
		player.call("configure_map_movement", definition, grid, origin)
	if player != null and player.has_method("set_mud_wetness_provider"):
		player.call("set_mud_wetness_provider", _host.view.mud_wetness)
	_host._camera_controller.view = _host.view
	_host._actor_controller.rebind_view(definition, _host.view)
	_host._ambient_controller.rebind_map(definition, _host.view)
	bind_minimap(definition, grid)
	return true


func bind_minimap(definition: MapDefinition, grid: MapTerrainGrid) -> void:
	if _host == null or _host.world_host == null:
		return
	var minimap: Node = _host.world_host.get("minimap_hud") as Node
	if minimap == null or not minimap.has_method("configure"):
		return
	if _host._minimap_logic_tracker == null:
		_host._minimap_logic_tracker = Node2D.new()
		_host._minimap_logic_tracker.name = "MinimapLogicTracker"
		_host.add_child(_host._minimap_logic_tracker)
	sync_minimap_tracker()
	minimap.call("configure", definition, grid, _host._minimap_logic_tracker)


func sync_minimap_tracker() -> void:
	if (
		_host == null
		or _host._minimap_logic_tracker == null
		or _host.world_host == null
		or _host._player == null
	):
		return
	if not is_instance_valid(_host._player):
		return
	var origin: Vector2 = _host.world_host.call(
		&"location_origin_logic_position", _host._owning_location_id
	)
	_host._minimap_logic_tracker.position = _host._player.global_position - origin
