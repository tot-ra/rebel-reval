extends "res://tests/godot/test_case.gd"

const LowerTownSliceDefinition := preload(
	"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
)


func test_lower_town_has_wall_exit_signs_outside_the_moat() -> void:
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	assert_eq(definition.direction_signs.size(), 4)

	var viru_road_sign := _sign_by_text(definition, "viru gate and eastern road")
	assert_false(viru_road_sign.is_empty())
	assert_eq(viru_road_sign["direction"], Vector2.RIGHT)
	# Viru's outer wall face ends at cell 67; the sign belongs on the glacis.
	assert_true(viru_road_sign["position"].x > float(definition.cell_size * 67))
	# Causeway centre is y=20; keep the post off the walkable road on the outer glacis.
	assert_true(viru_road_sign["position"].y > float(definition.cell_size * 21))

	var town_centre_sign := _sign_by_text(definition, "to town centre")
	assert_false(town_centre_sign.is_empty())
	assert_eq(town_centre_sign["direction"], Vector2.LEFT)
	# West exit is Vana Turg into the civic centre, not Karja Gate.
	assert_true(town_centre_sign["position"].x < float(definition.cell_size * 8))

	var south_sign := _sign_by_text(definition, "to knights district")
	assert_false(south_sign.is_empty())
	assert_eq(south_sign["direction"], Vector2.DOWN)
	# The southern quarter joins at the south edge, away from the Karja Gate moat.
	assert_true(south_sign["position"].x > float(definition.cell_size * 55))
	assert_true(south_sign["position"].y > float(definition.cell_size * 100))

	var karja_gate_sign := _sign_by_text(definition, "karja gate")
	assert_false(karja_gate_sign.is_empty())
	assert_eq(karja_gate_sign["direction"], Vector2.DOWN)
	assert_true(karja_gate_sign["position"].x > float(definition.cell_size * 55))
	assert_true(karja_gate_sign["position"].y > float(definition.cell_size * 100))

	assert_true(MapBuilder.validate(definition).is_empty())


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


func test_map_view_does_not_draw_direction_signs() -> void:
	# Road signs are authored map data only; the 3D view must not draw them.
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	var view := MapView3D.create(definition, grid)
	assert_false(view.has_node("DirectionSigns"))
	for sign in definition.direction_signs:
		var sign_id := StringName(String(sign.get("id", "")))
		if sign_id != &"":
			assert_eq(view.get_node("ObjectStreamer").loaded_instance(sign_id), null)
	view.free()


func _sign_by_text(definition: MapDefinition, text: String) -> Dictionary:
	for sign in definition.direction_signs:
		if String(sign.get("text", "")) == text:
			return sign
	return {}
