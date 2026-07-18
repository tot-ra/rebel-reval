extends "res://tests/godot/test_case.gd"

const KalevSmithy := preload("res://scripts/map/definitions/lower_town/kalev_smithy_definition.gd")
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
	assert_eq(minimap.get_location_label().text, "Eastern District")
	root.free()


func test_bootstrap_adds_minimap_to_forge_map() -> void:
	var definition: MapDefinition = KalevSmithy.create()
	var root := Node2D.new()
	var actors := Node2D.new()
	var player := CharacterBody2D.new()
	player.name = "Player"
	actors.add_child(player)
	root.add_child(actors)
	var bootstrap := MapSceneBootstrap.assemble(root, definition, actors)
	var minimap := bootstrap.get("minimap_hud") as MinimapHud
	assert_true(minimap != null, "forge maps need a minimap HUD")
	root.free()


func test_toggle_hides_and_shows_minimap() -> void:
	var hud := MinimapHud.new()
	assert_true(hud.is_enabled(), "minimap should start visible")
	hud.toggle()
	assert_false(hud.is_enabled(), "toggle should hide the minimap")
	hud.toggle()
	assert_true(hud.is_enabled(), "second toggle should restore the minimap")
	hud.free()


func test_location_label_sits_below_map_block() -> void:
	var root := _make_root()
	var hud := MinimapHud.new()
	root.add_child(hud)
	var stack := hud.get_node("MinimapRoot/MinimapStack") as VBoxContainer
	assert_eq(stack.get_child_count(), 2)
	assert_eq(stack.get_child(0).name, "MinimapPanel")
	assert_eq(stack.get_child(1).name, "LocationLabel")
	_cleanup_root(root)


func _make_root() -> Node:
	var root := Node.new()
	(_tree().root as Node).add_child(root)
	return root


func _cleanup_root(root: Node) -> void:
	if is_instance_valid(root):
		root.free()


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func test_texture_marks_transition_exits() -> void:
	var definition: MapDefinition = LowerTownSlice.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	var image := MinimapTextureBuilder.build_image(definition, grid)
	var transition_color := MinimapPalette.transition_color()
	var painted := false
	for transition in definition.transitions:
		if String(transition.get("destination_scene_id", "")).is_empty():
			continue
		var rect: Rect2 = transition["rect"]
		var cell := Vector2i(
			int(floor(rect.position.x / definition.cell_size)),
			int(floor(rect.position.y / definition.cell_size))
		)
		if _pixel_matches_color(image.get_pixel(cell.x, cell.y), transition_color):
			painted = true
			break
	assert_true(painted, "transition exits should be painted on the minimap")


func test_texture_marks_blocked_cells() -> void:
	var definition: MapDefinition = LowerTownSlice.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	var image := MinimapTextureBuilder.build_image(definition, grid)
	var blocked := MapVerification.blocked_cells(definition)
	assert_false(blocked.is_empty(), "slice maps should contain blocked building cells")
	var blocked_cell: Vector2i = blocked.keys()[0]
	var blocked_color := MinimapPalette.color_for_cell(definition, grid, blocked_cell, blocked)
	assert_true(
		_pixel_matches_color(image.get_pixel(blocked_cell.x, blocked_cell.y), blocked_color),
		"blocked cells should use the blocked palette color"
	)


func _pixel_matches_color(pixel: Color, expected: Color) -> bool:
	var reference := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	reference.set_pixel(0, 0, expected)
	return pixel == reference.get_pixel(0, 0)
