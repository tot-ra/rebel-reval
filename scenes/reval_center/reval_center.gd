extends "res://scripts/global/BaseLevel.gd"

const DEFINITION_SCRIPT := preload("res://scripts/map/definitions/prototypes/market_civic_quarter_definition.gd")

@onready var map_root: Node2D = $MapRoot
@onready var actors: Node2D = $Actors
@onready var player = $Actors/Player

var _bootstrap: Dictionary = {}
var _view_runtime: MapViewRuntime


func _ready() -> void:
	var definition: MapDefinition = DEFINITION_SCRIPT.create()
	_bootstrap = MapSceneBootstrap.assemble(self, definition, actors, map_root)
	DoorNavigator.spawn_player_at_pending_spawn(self)
	if player != null and player.navigation_agent != null:
		var navigation: NavigationRegion2D = _bootstrap.get("navigation")
		if navigation != null:
			player.navigation_agent.set_navigation_map(navigation.get_navigation_map())
		if DoorNavigator.pending_spawn_id.is_empty():
			player.global_position = definition.player_spawn
	_view_runtime = MapViewRuntime.install(self, _bootstrap, map_root, player)

