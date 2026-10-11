extends "res://scripts/global/BaseLevel.gd"

## Shared host for global-map placeholder destinations outside Reval.

const DistantDefs := preload("res://scripts/map/definitions/outdoor/distant_location_definitions.gd")

@export var location_id: StringName = &""

@onready var map_root: Node2D = $MapRoot
@onready var actors: Node2D = $Actors
@onready var player = $Actors/Player

var _bootstrap: Dictionary = {}
var _view_runtime: MapViewRuntime


func _ready() -> void:
	var definition: MapDefinition = DistantDefs.create(location_id)
	if definition == null:
		push_error("Unknown distant location id: %s" % String(location_id))
		return
	_bootstrap = MapSceneBootstrap.assemble(self, definition, actors, map_root)
	DoorNavigator.place_player(self, player, definition.player_spawn)
	if player != null and player.navigation_agent != null:
		var navigation: NavigationRegion2D = _bootstrap.get("navigation")
		if navigation != null:
			player.navigation_agent.set_navigation_map(navigation.get_navigation_map())
	MapSceneBootstrap.configure_player_movement(player, _bootstrap)
	_view_runtime = MapViewRuntime.install(self, _bootstrap, map_root, player)
