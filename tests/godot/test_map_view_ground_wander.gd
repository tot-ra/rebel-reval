extends "res://tests/godot/test_case.gd"

const GroundWander := preload("res://scripts/map/view3d/map_view_ground_wander.gd")


func test_ground_wander_rejects_building_waypoints_and_steps() -> void:
	var actor := Node3D.new()
	actor.position = Vector3.ZERO
	GroundWander.setup(
		actor,
		&"wall_regression",
		0,
		{
			"home": Vector3.ZERO,
			"radius": 3.0,
			"speed": 2.0,
			"pause_range": Vector2.ZERO,
			"blocked_rects": [Rect2(Vector2(0.5, -4.0), Vector2(2.0, 8.0))],
		}
	)
	actor.set_meta(&"pause_remaining", 0.0)
	actor.set_meta(&"target", Vector3(3.0, 0.0, 0.0))
	GroundWander.advance(actor, &"wall_regression", Vector3.INF, 1.0)
	assert_eq(actor.position, Vector3.ZERO, "animal must stay at the last valid point")
	var target: Vector3 = actor.get_meta(&"target", Vector3.INF)
	assert_false(
		Rect2(Vector2(0.5, -4.0), Vector2(2.0, 8.0)).has_point(Vector2(target.x, target.z)),
		"replacement waypoint must not be inside a building footprint"
	)
	actor.free()
