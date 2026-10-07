extends "res://tests/godot/test_case.gd"

## ADR 0021: the player-only water layer. Depth comes from the rendered basin, the
## player body ignores traversable water colliders, and walkability stays unchanged.

const HarborEast := preload("res://scripts/map/definitions/outdoor/reval_harbor_east_definition.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapVerification := preload("res://scripts/map/map_verification.gd")
const PLAYER_SCENE := preload("res://player.tscn")
const CELL := 32.0


func _depth(definition: MapDefinition, grid: MapTerrainGrid, cell: Vector2i) -> float:
	return PlayerWaterTraversal.depth_at(definition, grid, (Vector2(cell) + Vector2(0.5, 0.5)) * CELL)


func test_rivers_stay_blocking_and_other_water_is_traversable() -> void:
	assert_false(PlayerWaterTraversal.is_traversable_terrain(MapTypes.TERRAIN_RIVER_WATER))
	for terrain in [
		MapTypes.TERRAIN_WATER, MapTypes.TERRAIN_SHALLOW_WATER, MapTypes.TERRAIN_DEEP_WATER
	]:
		assert_true(PlayerWaterTraversal.is_traversable_terrain(terrain), str(terrain))
	assert_false(PlayerWaterTraversal.is_traversable_terrain(MapTypes.TERRAIN_GRASS))


func test_kalamaja_depth_profile_wades_then_drops_to_swimming_depth() -> void:
	var definition: MapDefinition = HarborEast.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	# Column x=100: coast sand at row 36, cove water from row 35, shelf plateau, then the drop.
	assert_eq(_depth(definition, grid, Vector2i(100, 37)), 0.0, "dry sand")
	var ankle := _depth(definition, grid, Vector2i(100, 35))
	var knee := _depth(definition, grid, Vector2i(100, 34))
	var plateau := _depth(definition, grid, Vector2i(100, 30))
	var deep := _depth(definition, grid, Vector2i(100, 20))
	assert_true(ankle > 0.0 and ankle < knee and knee < plateau, "the bed shelves down from the beach")
	assert_true(plateau < PlayerSwimState.SWIM_ENTER_DEPTH, "the shallow shelf is wading depth")
	assert_true(deep > PlayerSwimState.DIVE_MIN_DEPTH, "past the shelf there is room to dive")


func test_water_blocks_sit_on_the_water_layer_and_the_player_ignores_them() -> void:
	var definition: MapDefinition = HarborEast.create()
	var root := Node2D.new()
	var actors := Node2D.new()
	root.add_child(actors)
	var bootstrap := MapSceneBootstrap.assemble(root, definition, actors)
	var water := bootstrap.get("water_blocks") as StaticBody2D
	assert_true(water != null)
	assert_eq(water.collision_layer, CollisionLayers.WATER)
	var player := CharacterBody2D.new()
	CollisionLayers.apply_player(player)
	var npc := CharacterBody2D.new()
	CollisionLayers.apply_npc(npc)
	assert_eq(player.collision_mask & water.collision_layer, 0, "the player walks into water")
	assert_true((npc.collision_mask & water.collision_layer) != 0, "NPCs still treat water as a wall")
	player.free()
	npc.free()
	root.free()


func test_exclusions_over_water_no_longer_wall_off_the_swimmer_but_dry_cells_stay_blocked() -> void:
	var definition: MapDefinition = HarborEast.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	var rects := MapSceneBootstrap._excluded_collision_rects(definition, grid)
	assert_false(rects.is_empty())
	for rect in rects:
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				assert_false(
					PlayerWaterTraversal.is_traversable_terrain(grid.get_terrain(Vector2i(x, y))),
					"physical exclusion over traversable water at %d,%d" % [x, y]
				)
	# The authored rects themselves are untouched, so navigation and audits read the same data.
	assert_true(definition.excluded_areas.size() > 0)


## A swimmer must be able to climb out onto any beach cell that touches the sea. Stale
## shallow-band exclusions once covered sand spits and walled the shore off.
func test_harbour_beach_cells_beside_water_are_not_physically_excluded() -> void:
	for path: String in [
		"res://scripts/map/definitions/outdoor/reval_harbor_east_definition.gd",
		"res://scripts/map/definitions/outdoor/reval_harbor_north_definition.gd",
	]:
		var definition: MapDefinition = load(path).create()
		var grid: MapTerrainGrid = MapBuilder.build(definition)
		var blocked := {}
		for rect in MapSceneBootstrap._excluded_collision_rects(definition, grid):
			for y in range(rect.position.y, rect.end.y):
				for x in range(rect.position.x, rect.end.x):
					blocked[Vector2i(x, y)] = true
		var shore_cells := 0
		for y in definition.size_cells.y:
			for x in definition.size_cells.x:
				var cell := Vector2i(x, y)
				if grid.get_terrain(cell) != MapTypes.TERRAIN_COAST_SAND:
					continue
				var beside_water := false
				for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					if PlayerWaterTraversal.is_traversable_terrain(grid.get_terrain(cell + offset)):
						beside_water = true
				if not beside_water:
					continue
				shore_cells += 1
				assert_false(
					blocked.has(cell),
					"%s beach cell %s beside water is excluded" % [definition.map_id, cell]
				)
		assert_true(shore_cells > 100, "%s must have a long beach" % definition.map_id)


func test_walkability_audits_still_treat_water_as_blocked() -> void:
	var definition: MapDefinition = HarborEast.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	assert_false(MapVerification.is_walkable_cell(definition, grid, Vector2i(100, 30)))
	assert_false(MapVerification.is_walkable_cell(definition, grid, Vector2i(100, 20)))



func _create_player_at(definition: MapDefinition, grid: MapTerrainGrid, cell: Vector2i) -> Player:
	if not SessionState.content_db.is_loaded():
		assert_true(SessionState.content_db.load_from_directories(SessionState.DEMO_CONTENT_DIRS))
	if SessionState.state == null:
		SessionState.state = GameState.new()
		SessionState.state.bag.set_content_db(SessionState.content_db)
	var player := PLAYER_SCENE.instantiate() as Player
	(Engine.get_main_loop() as SceneTree).root.add_child(player)
	player.configure_map_movement(definition, grid)
	player.global_position = (Vector2(cell) + Vector2(0.5, 0.5)) * CELL
	return player


func test_player_reads_its_medium_from_the_water_column_under_it() -> void:
	var definition: MapDefinition = HarborEast.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	var player := _create_player_at(definition, grid, Vector2i(100, 37))
	player._update_water(0.016)
	assert_eq(player.water_medium(), PlayerSwimState.Medium.WALK, "dry sand")
	player.global_position = (Vector2(100.5, 30.5)) * CELL
	player._update_water(0.016)
	assert_eq(player.water_medium(), PlayerSwimState.Medium.WADE, "shelf plateau")
	var wading_speed := player.terrain_speed_multiplier()
	assert_true(wading_speed < 1.0, "wading drags")
	player.global_position = (Vector2(100.5, 20.5)) * CELL
	player._update_water(0.016)
	assert_eq(player.water_medium(), PlayerSwimState.Medium.SWIM, "open sea")
	assert_true(player.terrain_speed_multiplier() < wading_speed, "swimming is slower than wading")
	player.free()


func test_swimming_disables_attacks_but_wading_does_not() -> void:
	var definition: MapDefinition = HarborEast.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	var player := _create_player_at(definition, grid, Vector2i(100, 30))
	player.combat_input_enabled = true
	player._update_water(0.016)
	assert_eq(player.water_medium(), PlayerSwimState.Medium.WADE)
	assert_false(player._swim.blocks_combat(), "wading keeps combat available")
	player.global_position = (Vector2(100.5, 20.5)) * CELL
	player._update_water(0.016)
	assert_eq(player.water_medium(), PlayerSwimState.Medium.SWIM)
	assert_false(player.request_primary_attack(), "no attacks while swimming")
	assert_false(player.try_start_dodge(), "no dodge while swimming")
	player.free()
