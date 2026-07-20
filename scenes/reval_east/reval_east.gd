extends "res://scripts/global/BaseLevel.gd"

const DEFINITION_SCRIPT := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")

@onready var map_root: Node2D = $MapRoot
@onready var actors: Node2D = $Actors
@onready var player: Player = $Actors/Player

var _bootstrap: Dictionary = {}
var _view_runtime: MapViewRuntime
var _mart_encounter: DemoMartEncounter
var _phase_binder: MapPhaseBinder
var _patrol_controller: MapPatrolController


func _ready() -> void:
	super()
	var definition: MapDefinition = DEFINITION_SCRIPT.create()
	_bootstrap = MapSceneBootstrap.assemble(self, definition, actors, map_root)
	DoorNavigator.place_player(self, player, definition.player_spawn)
	_wire_player_navigation()
	MapSceneBootstrap.configure_player_movement(player, _bootstrap)

	_mart_encounter = DemoMartEncounter.new()
	_mart_encounter.name = "DemoMartEncounter"
	add_child(_mart_encounter)
	_mart_encounter.spawn_mart(actors, definition)

	_view_runtime = MapViewRuntime.install(self, _bootstrap, map_root, player)
	_setup_phase_binder(definition)
	_mart_encounter.wire(self, definition, player)


func _setup_phase_binder(definition: MapDefinition) -> void:
	_phase_binder = MapPhaseBinder.new()
	_phase_binder.name = "MapPhaseBinder"
	add_child(_phase_binder)
	_phase_binder.setup(&"loc.lower_town_slice", definition, _view_runtime)
	_patrol_controller = MapPatrolController.new()
	_patrol_controller.name = "ViruWatchPatrol"
	add_child(_patrol_controller)
	_patrol_controller.setup(definition, &"viru_watch", actors)
	_phase_binder.register_patrol(&"viru_watch", _patrol_controller)
	if _mart_encounter != null:
		_mart_encounter.register_phase_binder(_phase_binder, definition)


func _wire_player_navigation() -> void:
	var navigation: NavigationRegion2D = _bootstrap.get("navigation")
	if player != null and navigation != null and player.navigation_agent != null:
		player.navigation_agent.set_navigation_map(navigation.get_navigation_map())
