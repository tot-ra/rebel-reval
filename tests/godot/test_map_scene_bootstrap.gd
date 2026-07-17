extends "res://tests/godot/test_case.gd"

const SmithyCourtyard := preload("res://scripts/map/smithy_courtyard_definition.gd")
const LowerTownSlice := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapTypes := preload("res://scripts/map/map_types.gd")


func test_bootstrap_adds_current_location_hud() -> void:
	var definition: MapDefinition = LowerTownSlice.create()
	var root := Node2D.new()
	var actors := Node2D.new()
	root.add_child(actors)
	var bootstrap := MapSceneBootstrap.assemble(root, definition, actors)
	var hud := bootstrap.get("location_hud") as LocationHud
	assert_true(hud != null, "playable maps need a location HUD")
	assert_eq(hud.get_parent(), root, "HUD must be camera-independent")
	assert_eq((hud.get_node("LocationLabel") as Label).text, "Eastern District")
	root.free()


func test_location_hud_falls_back_to_humanized_map_id() -> void:
	var definition := MapDefinition.new()
	definition.map_id = &"prototype.reval_harbor_surroundings"
	assert_eq(LocationHud.display_name_for(definition), "Reval Harbor Surroundings")


func test_bootstrap_adds_physics_bounds_for_direct_keyboard_movement() -> void:
	var definition: MapDefinition = SmithyCourtyard.create()
	var root := Node2D.new()
	var actors := Node2D.new()
	root.add_child(actors)
	var bootstrap := MapSceneBootstrap.assemble(root, definition, actors)
	var bounds := bootstrap.get("world_bounds") as StaticBody2D
	assert_true(bounds != null, "programmatic maps need physical world bounds")
	assert_true(bounds.is_in_group(&"map_world_bounds"))
	assert_eq(bounds.get_child_count(), 4, "all four map edges must block direct movement")
	var world := definition.world_size()
	var top := bounds.get_node("Boundary0") as CollisionShape2D
	var bottom := bounds.get_node("Boundary1") as CollisionShape2D
	var left := bounds.get_node("Boundary2") as CollisionShape2D
	var right := bounds.get_node("Boundary3") as CollisionShape2D
	assert_true(top.position.y < 0.0 and bottom.position.y > world.y)
	assert_true(left.position.x < 0.0 and right.position.x > world.x)
	root.free()


func test_bootstrap_adds_water_collision_for_direct_keyboard_movement() -> void:
	var definition: MapDefinition = SmithyCourtyard.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	var root := Node2D.new()
	var actors := Node2D.new()
	root.add_child(actors)
	var bootstrap := MapSceneBootstrap.assemble(root, definition, actors)
	var water_blocks := bootstrap.get("water_blocks") as StaticBody2D
	assert_true(water_blocks != null, "maps with water terrain need physical water blocks")
	assert_true(water_blocks.is_in_group(&"map_water_collision"))
	var water_cells: Dictionary = {}
	for y in range(definition.size_cells.y):
		for x in range(definition.size_cells.x):
			var cell := Vector2i(x, y)
			if MapTypes.WATER_TERRAINS.has(grid.get_terrain(cell)):
				water_cells[cell] = true
	var covered_cells: Dictionary = {}
	for child in water_blocks.get_children():
		var collision := child as CollisionShape2D
		var shape := collision.shape as RectangleShape2D
		var world_rect := Rect2(collision.position - shape.size * 0.5, shape.size)
		var cell_rect := Rect2i(
			Vector2i(world_rect.position / float(definition.cell_size)),
			Vector2i(world_rect.size / float(definition.cell_size))
		)
		for y in range(cell_rect.position.y, cell_rect.end.y):
			for x in range(cell_rect.position.x, cell_rect.end.x):
				var cell := Vector2i(x, y)
				assert_false(covered_cells.has(cell), "merged water collisions must not overlap")
				covered_cells[cell] = true
	assert_eq(covered_cells, water_cells, "merged collisions must cover exactly the water cells")
	assert_true(water_blocks.get_child_count() < water_cells.size(), "contiguous water must use fewer collision shapes")
	root.free()
