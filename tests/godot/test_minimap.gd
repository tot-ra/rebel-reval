extends "res://tests/godot/test_case.gd"

const LowerTownSlice := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")


func test_texture_builder_matches_map_dimensions() -> void:
	var definition: MapDefinition = LowerTownSlice.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	var image := MinimapTextureBuilder.build_image(definition, grid)
	assert_eq(image.get_width(), definition.size_cells.x, "minimap width should match map cells")
	assert_eq(image.get_height(), definition.size_cells.y, "minimap height should match map cells")


func test_world_to_normalized_maps_spawn_to_corner() -> void:
	var definition: MapDefinition = LowerTownSlice.create()
	var normalized := MinimapTextureBuilder.world_to_normalized(definition, definition.player_spawn)
	assert_true(normalized.x >= 0.0 and normalized.x <= 1.0)
	assert_true(normalized.y >= 0.0 and normalized.y <= 1.0)


func test_bootstrap_adds_minimap_hud() -> void:
	var definition: MapDefinition = LowerTownSlice.create()
	var root := Node2D.new()
	var actors := Node2D.new()
	var player := CharacterBody2D.new()
	player.name = "Player"
	actors.add_child(player)
	root.add_child(actors)
	var bootstrap := MapSceneBootstrap.assemble(root, definition, actors)
	var minimap := bootstrap.get("minimap_hud") as MinimapHud
	assert_true(minimap != null, "playable maps need a minimap HUD")
	assert_eq(minimap.get_parent(), root, "minimap must be camera-independent")
	assert_true(minimap.is_enabled(), "minimap should start visible")
	root.free()
