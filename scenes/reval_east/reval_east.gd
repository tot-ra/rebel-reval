extends "res://scripts/global/BaseLevel.gd"

const DEFINITION_SCRIPT := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")

@onready var map_root: Node2D = $MapRoot
@onready var actors: Node2D = $Actors
@onready var player: Player = $Actors/Player

var _bootstrap: Dictionary = {}
var _view_runtime: MapViewRuntime
var _mart_encounter: DemoMartEncounter


func _ready() -> void:
	super()
	var definition: MapDefinition = DEFINITION_SCRIPT.create()
	_bootstrap = MapSceneBootstrap.assemble(self, definition, actors, map_root)
	DoorNavigator.spawn_player_at_pending_spawn(self)
	_wire_player_navigation()
	MapSceneBootstrap.configure_player_movement(player, _bootstrap)

	_mart_encounter = DemoMartEncounter.new()
	_mart_encounter.name = "DemoMartEncounter"
	add_child(_mart_encounter)
	_mart_encounter.spawn_mart(actors, definition)

	_view_runtime = MapViewRuntime.install(self, _bootstrap, map_root, player)
	_mart_encounter.wire(self, definition, player)


func _unhandled_input(event: InputEvent) -> void:
	if player == null or _view_runtime == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		player.navigation_agent.set_target_position(_view_runtime.logic_position_at_screen(event.position))


func _wire_player_navigation() -> void:
	var navigation: NavigationRegion2D = _bootstrap.get("navigation")
	if player != null and navigation != null and player.navigation_agent != null:
		player.navigation_agent.set_navigation_map(navigation.get_navigation_map())
