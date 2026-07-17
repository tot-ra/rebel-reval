extends "res://tests/godot/test_case.gd"

const SmithyCourtyard := preload("res://scripts/map/smithy_courtyard_definition.gd")


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
