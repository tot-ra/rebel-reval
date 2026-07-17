extends "res://tests/godot/test_case.gd"

const DirectionSign3D := preload("res://scripts/map/view3d/direction_sign_3d.gd")
const LowerTownSliceDefinition := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")


func test_lower_town_has_wall_exit_signs_outside_the_moat() -> void:
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	assert_eq(definition.direction_signs.size(), 2)

	var harbour_sign: Dictionary = definition.direction_signs[0]
	assert_eq(harbour_sign["text"], "to harbour")
	assert_eq(harbour_sign["direction"], Vector2.RIGHT)
	# Viru's outer wall face ends at cell 67; the sign belongs on the glacis.
	assert_true(harbour_sign["position"].x > float(definition.cell_size * 67))
	# Causeway centre is y=20; keep the post off the walkable road.
	assert_true(harbour_sign["position"].y < float(definition.cell_size * 19))

	var karja_sign: Dictionary = definition.direction_signs[1]
	assert_eq(karja_sign["text"], "to town centre")
	assert_eq(karja_sign["direction"], Vector2.DOWN)
	# South wall mass ends at cell 50; the sign sits on the outer glacis.
	assert_true(karja_sign["position"].y > float(definition.cell_size * 50))
	# Karja causeway centre is x=37.5; keep the post east of the road.
	assert_true(karja_sign["position"].x > float(definition.cell_size * 39))

	assert_true(MapBuilder.validate(definition).is_empty())


func test_direction_sign_builds_wooden_arrow_with_two_sided_text() -> void:
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	var sign: Dictionary = definition.direction_signs[0]
	var node := DirectionSign3D.build(sign, definition.cell_size)
	assert_true(node.has_node("Post"))
	assert_true(node.has_node("ArrowBody"))
	assert_true(node.has_node("ArrowHead"))
	assert_eq((node.get_node("TextFront") as Label3D).text, "to harbour")
	assert_eq((node.get_node("TextBack") as Label3D).text, "to harbour")
	assert_eq(node.get_meta("outside_direction"), Vector2.RIGHT)
	assert_true(is_zero_approx(node.rotation.y), "right-pointing sign must face world +X")
	node.free()


func test_karja_sign_points_south_along_outgoing_road() -> void:
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	var sign: Dictionary = definition.direction_signs[1]
	var node := DirectionSign3D.build(sign, definition.cell_size)
	assert_eq((node.get_node("TextFront") as Label3D).text, "to town centre")
	var world_arrow_direction := (node.transform.basis * Vector3.RIGHT).normalized()
	assert_true(
		world_arrow_direction.is_equal_approx(Vector3.BACK),
		"Karja gate sign must point south along the causeway"
	)
	node.free()


func test_direction_sign_rotates_arrow_toward_outgoing_direction() -> void:
	var down_sign := {
		"text": "to the southern road",
		"position": Vector2(32.0, 32.0),
		"direction": Vector2.DOWN,
	}
	var node := DirectionSign3D.build(down_sign, MapTypes.DEFAULT_CELL_SIZE)
	var world_arrow_direction := (node.transform.basis * Vector3.RIGHT).normalized()
	assert_true(
		world_arrow_direction.is_equal_approx(Vector3.BACK),
		"down on the logic map must rotate the arrow toward world +Z"
	)
	node.free()


func test_direction_sign_validation_rejects_missing_text_and_zero_direction() -> void:
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	definition.direction_signs = [
		{
			"text": " ",
			"position": Vector2(32.0, 32.0),
			"direction": Vector2.ZERO,
		},
	]
	var errors: Array[String] = MapBuilder.validate(definition)
	assert_array_contains(errors, "direction_signs[0].text is required")
	assert_array_contains(errors, "direction_signs[0].direction must not be zero")


func test_map_view_assembles_direction_signs_without_logic_geometry() -> void:
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	var view := MapView3D.create(definition, grid)
	var signs := view.get_node("DirectionSigns") as Node3D
	assert_eq(signs.get_child_count(), definition.direction_signs.size())
	assert_eq(signs.get_child(0).get_meta("direction_text"), "to harbour")
	assert_eq(signs.get_child(1).get_meta("direction_text"), "to town centre")
	view.free()
