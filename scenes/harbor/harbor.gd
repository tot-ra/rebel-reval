extends "res://scripts/global/BaseLevel.gd"

const DEFINITION_SCRIPT := preload("res://scripts/map/definitions/outdoor/reval_harbor_definition.gd")

@onready var map_root: Node2D = $MapRoot
@onready var actors: Node2D = $Actors
@onready var player = $Actors/Player

var _bootstrap: Dictionary = {}
var _view_runtime: MapViewRuntime


func _ready() -> void:
	super()
	var definition: MapDefinition = DEFINITION_SCRIPT.create()
	_bootstrap = MapSceneBootstrap.assemble(self, definition, actors, map_root)
	DoorNavigator.place_player(self, player, definition.player_spawn)
	MapSceneBootstrap.configure_player_movement(player, _bootstrap)
	if player != null and player.navigation_agent != null:
		var navigation: NavigationRegion2D = _bootstrap.get("navigation")
		if navigation != null:
			player.navigation_agent.set_navigation_map(navigation.get_navigation_map())
	_view_runtime = MapViewRuntime.install(self, _bootstrap, map_root, player)

