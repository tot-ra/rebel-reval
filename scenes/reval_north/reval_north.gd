extends "res://scripts/global/BaseLevel.gd"

const DEFINITION_SCRIPT := preload(
	"res://scripts/map/definitions/prototypes/north_quarter_definition.gd"
)

var _bootstrap: Dictionary = {}
var _world_host: WorldHost
var _view_runtime: MapViewRuntime

@onready var map_root: Node2D = $MapRoot
@onready var actors: Node2D = $Actors
@onready var player = $Actors/Player


func _ready() -> void:
	var definition: MapDefinition = DEFINITION_SCRIPT.create()
	_bootstrap = _launch_location(definition)
	DoorNavigator.place_player(self, player, definition.player_spawn)
	if player != null and player.navigation_agent != null:
		var navigation: NavigationRegion2D = _bootstrap.get("navigation")
		if navigation != null:
			player.navigation_agent.set_navigation_map(navigation.get_navigation_map())
	_view_runtime = _install_view_runtime(definition)


func _launch_location(definition: MapDefinition) -> Dictionary:
	if WorldHost.launch_enabled():
		_world_host = WorldHost.launch_scene_location(self, definition, player)
		if _world_host != null:
			player = _world_host.player_owner
			return _world_host.hosted_bootstrap(definition.map_id)
	return MapSceneBootstrap.assemble(self, definition, actors, map_root)


func _install_view_runtime(definition: MapDefinition) -> MapViewRuntime:
	if _world_host != null:
		return MapViewRuntime.install_hosted(self, _world_host, definition.map_id)
	return MapViewRuntime.install(self, _bootstrap, map_root, player)
