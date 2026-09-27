extends "res://scripts/global/BaseLevel.gd"

const DEFINITION_SCRIPT := preload(
	"res://scripts/map/definitions/prototypes/toompea_small_castle_definition.gd"
)
const DOOR_SCENE := preload("res://scenes/elements/door.tscn")
const ENTRY_SPAWN_ID := &"small_castle_entry"

var _bootstrap: Dictionary = {}
var _view_runtime: MapViewRuntime

@onready var map_root: Node2D = $MapRoot
@onready var actors: Node2D = $Actors
@onready var player = $Actors/Player


func _ready() -> void:
	var definition: MapDefinition = DEFINITION_SCRIPT.create()
	_bootstrap = MapSceneBootstrap.assemble(self, definition, actors, map_root)
	_ensure_entry_spawn_door(definition)
	DoorNavigator.place_player(self, player, definition.player_spawn)
	if player != null and player.navigation_agent != null:
		var navigation: NavigationRegion2D = _bootstrap.get("navigation")
		if navigation != null:
			player.navigation_agent.set_navigation_map(navigation.get_navigation_map())
	_view_runtime = MapViewRuntime.install(self, _bootstrap, map_root, player)


func _ensure_entry_spawn_door(definition: MapDefinition) -> void:
	# WHY: DoorNavigator only resolves pending arrivals through Door.spawn_id.
	# The authored entry is a spawn primitive; the return transition uses
	# from_small_castle. Bind a disabled door so Toompea -> Small Castle
	# lands on small_castle_entry instead of warning and falling through.
	if DoorNavigator.get_spawn_node(self, &"toompea_small_castle", ENTRY_SPAWN_ID) != null:
		return
	var doors_root := find_child("Doors", true, false) as Node2D
	if doors_root == null:
		return
	var door: Door = DOOR_SCENE.instantiate()
	door.name = "door_small_castle_entry"
	door.position = definition.player_spawn
	door.spawn_id = ENTRY_SPAWN_ID
	door.transition_enabled = false
	var collision := door.get_node("CollisionShape2D") as CollisionShape2D
	if collision != null:
		var shape := collision.shape as RectangleShape2D
		if shape == null:
			shape = RectangleShape2D.new()
			collision.shape = shape
		shape.size = Vector2(32, 32)
		collision.position = Vector2.ZERO
	doors_root.add_child(door)
