extends Node2D

const DEFINITION_SCRIPT := preload("res://scripts/map/definitions/prototypes/market_square_definition.gd")

@onready var map_root: Node2D = $MapRoot
@onready var actors: Node2D = $Actors
@onready var player: Player = $Actors/Player


func _ready() -> void:
	var definition: MapDefinition = DEFINITION_SCRIPT.create()
	var bootstrap := MapSceneBootstrap.assemble(self, definition, actors, map_root)
	if player != null and player.navigation_agent != null:
		player.global_position = definition.player_spawn
		var navigation: NavigationRegion2D = bootstrap.get("navigation")
		if navigation != null:
			player.navigation_agent.set_navigation_map(navigation.get_navigation_map())
