extends "res://tests/godot/test_case.gd"

const ViruGateForelandDefinition := preload(
	"res://scripts/map/definitions/outdoor/viru_gate_foreland_definition.gd"
)


func test_pirita_neighbor_preview_keeps_city_wall_gallery_and_tower_roofs() -> void:
	var definition := ViruGateForelandDefinition.create()
	var view := MapView3D.create(definition, MapBuilder.build(definition))
	var buildings := view.get_node("Surroundings/Neighbor_west/Buildings") as Node3D

	assert_true(
		buildings.get_node("Building_city_wall_north").has_node("WalkRoof"),
		"Pirita's Reval backdrop must retain the city-wall gallery roof"
	)
	for tower_id in [&"wall_tower_northeast", &"viru_gate_north_tower", &"viru_gate_south_tower"]:
		assert_true(
			buildings.get_node("Building_%s" % tower_id).has_node("TowerRoof"),
			"Pirita's Reval backdrop must retain %s roof" % tower_id
		)
	view.free()
