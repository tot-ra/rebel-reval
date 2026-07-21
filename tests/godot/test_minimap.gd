extends "res://tests/godot/test_case.gd"

const KalevSmithy := preload("res://scripts/map/definitions/lower_town/kalev_smithy_definition.gd")
const LowerTownSlice := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const GameCalendarScript := preload("res://scripts/global/game_calendar.gd")


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
	(_tree().root as Node).add_child(root)
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
	assert_eq(minimap.get_location_label().text, "Workers' District")
	root.free()


func test_bootstrap_adds_minimap_to_forge_map() -> void:
	var definition: MapDefinition = KalevSmithy.create()
	var root := Node2D.new()
	(_tree().root as Node).add_child(root)
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


func test_location_label_sits_above_map_block() -> void:
	var root := _make_root()
	var hud := MinimapHud.new()
	root.add_child(hud)
	var stack := hud.get_node("MinimapRoot/MinimapStack") as VBoxContainer
	assert_eq(stack.get_child_count(), 2)
	assert_eq(stack.get_child(0).name, "LocationLabel")
	assert_eq(stack.get_child(1).name, "MinimapPanel")
	var location_label := hud.get_location_label()
	assert_eq(
		location_label.horizontal_alignment,
		HORIZONTAL_ALIGNMENT_CENTER,
		"location label should align with minimap center"
	)
	_cleanup_root(root)

func test_minimap_shows_story_date_and_day_night_indicator() -> void:
	var root := _make_root()
	var hud := MinimapHud.new()
	root.add_child(hud)
	assert_eq(hud.get_date_label().text, "21.04.1343")
	assert_true(hud.get_celestial_indicator() != null)
	assert_eq(hud.get_celestial_indicator().name, "DayNightIndicator")
	_cleanup_root(root)


func test_minimap_follow_pans_with_player() -> void:
	var definition: MapDefinition = LowerTownSlice.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	var root := _make_root()
	var player := Node2D.new()
	player.name = "Player"
	player.global_position = definition.player_spawn
	root.add_child(player)
	var hud := MinimapHud.new()
	root.add_child(hud)
	hud.configure(definition, grid, player)

	var first := MinimapTextureBuilder.world_to_normalized(definition, player.global_position)
	assert_eq(hud.get_follow_view_cells(), 56.0, "follow zoom must stay fixed for local radar scale")
	assert_true(
		hud.get_follow_center_uv().distance_to(first) < 0.001,
		"minimap texture must center on the player"
	)
	var marker := hud.find_child("PlayerMarker", true, false) as ColorRect
	assert_true(marker != null)
	assert_true(marker.visible, "follow mode keeps the marker fixed at the circle center")
	var expected_marker := Vector2(MinimapHud.MAX_DISPLAY_SIZE, MinimapHud.MAX_DISPLAY_SIZE) * 0.5 - MinimapHud.MARKER_SIZE * 0.5
	assert_true(
		marker.position.distance_to(expected_marker) < 0.01,
		"player marker stays centered while the map pans"
	)

	player.global_position = definition.player_spawn + Vector2(definition.cell_size * 24.0, definition.cell_size * 18.0)
	hud._process(0.0)
	var second := MinimapTextureBuilder.world_to_normalized(definition, player.global_position)
	assert_true(second.distance_to(first) > 0.01, "test must move the player enough to pan")
	assert_true(
		hud.get_follow_center_uv().distance_to(second) < 0.001,
		"minimap content must pan with the character"
	)
	assert_true(
		marker.position.distance_to(expected_marker) < 0.01,
		"marker must stay centered after the player moves"
	)
	_cleanup_root(root)


func test_story_calendar_tracks_slice_timeline_without_visual_cycle_days() -> void:
	assert_eq(
		GameCalendarScript.formatted_date_for_phase(GameState.PHASE_PROLOGUE_DAY),
		"21.04.1343"
	)
	assert_eq(
		GameCalendarScript.formatted_date_for_phase(GameState.PHASE_INVESTIGATION_NIGHT),
		"22.04.1343"
	)
	assert_eq(
		GameCalendarScript.formatted_date_for_phase(GameState.PHASE_REFLECTION_MORNING),
		"23.04.1343"
	)



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
