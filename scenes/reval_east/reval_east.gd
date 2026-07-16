extends "res://scripts/global/BaseLevel.gd"

const DEFINITION_SCRIPT := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")

@onready var map_root: Node2D = $MapRoot
@onready var actors: Node2D = $Actors
@onready var player = $Actors/Player

var _bootstrap: Dictionary = {}


func _ready() -> void:
	super()
	var definition: MapDefinition = DEFINITION_SCRIPT.create()
	_bootstrap = MapSceneBootstrap.assemble(self, definition, actors, map_root)
	DoorNavigator.spawn_player_at_pending_spawn(self)
	if player != null and player.navigation_agent != null:
		var navigation: NavigationRegion2D = _bootstrap.get("navigation")
		if navigation != null:
			player.navigation_agent.set_navigation_map(navigation.get_navigation_map())


func _unhandled_input(event: InputEvent) -> void:
	if player == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		player.navigation_agent.set_target_position(get_global_mouse_position())
