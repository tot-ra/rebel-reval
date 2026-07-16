extends Node2D

## Playable prototype for the Smithy Courtyard + Lower Town street spike.

const DEFINITION_SCRIPT := preload("res://scripts/map/smithy_courtyard_definition.gd")

@onready var camera: Camera2D = $Camera2D
@onready var actors: Node2D = $Actors
@onready var player: MapPrototypePlayer = $Actors/Player

var definition: MapDefinition
var grid: MapTerrainGrid


func _ready() -> void:
	definition = DEFINITION_SCRIPT.create()
	grid = MapBuilder.build(definition)
	MapAssembler.assemble(self, definition, grid, actors)

	player.global_position = definition.player_spawn
	camera.position = definition.world_size() * 0.5
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(definition.world_size().x)
	camera.limit_bottom = int(definition.world_size().y)
