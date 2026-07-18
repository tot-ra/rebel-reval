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
	DoorNavigator.spawn_player_at_pending_spawn(self)
	MapSceneBootstrap.configure_player_movement(player, _bootstrap)
	if player != null and player.navigation_agent != null:
		var navigation: NavigationRegion2D = _bootstrap.get("navigation")
		if navigation != null:
			player.navigation_agent.set_navigation_map(navigation.get_navigation_map())
		if DoorNavigator.pending_spawn_id.is_empty():
			player.global_position = definition.player_spawn
	_view_runtime = MapViewRuntime.install(self, _bootstrap, map_root, player)


func _unhandled_input(event: InputEvent) -> void:
	if player == null or _view_runtime == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		player.navigation_agent.set_target_position(_view_runtime.logic_position_at_screen(event.position))
