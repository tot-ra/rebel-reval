extends "res://tests/godot/test_case.gd"

## Boats are solid on the logic plane even though ADR 0021 lets Kalev enter water.


func test_boat_props_get_hull_sized_capsules_on_the_world_layer() -> void:
	var definition := _definition()
	var parent := Node2D.new()
	var body := MapSceneBootstrap._create_boat_blocks(definition, parent)
	assert_true(body != null, "maps with boat props need a BoatBlocks body")
	assert_eq(body.collision_layer, CollisionLayers.WORLD, "boats must stop the player")
	assert_eq(body.get_child_count(), 2, "one capsule per boat prop, none for other props")

	var tall := body.get_node("Boat_boat_tall") as CollisionShape2D
	var capsule := tall.shape as CapsuleShape2D
	var cell := float(definition.cell_size)
	assert_almost_eq(
		capsule.height, MapViewFishingBoatBuilder.HULL_HALF_LENGTH * 2.0 * cell, 0.01,
		"capsule must span the 3D hull length"
	)
	assert_almost_eq(
		capsule.radius, MapViewFishingBoatBuilder.HULL_HALF_BEAM * cell, 0.01,
		"capsule must match the 3D hull beam"
	)
	assert_eq(tall.position, Vector2(160, 160), "capsule sits on the prop centre")
	# A tall footprint turns the hull north-south, so the capsule stays upright.
	assert_almost_eq(sin(tall.rotation), 0.0, 0.001, "tall boat runs along logic y")
	var wide := body.get_node("Boat_boat_wide") as CollisionShape2D
	assert_almost_eq(cos(wide.rotation), 0.0, 0.001, "wide boat runs along logic x")
	parent.free()


func test_maps_without_boats_get_no_boat_body() -> void:
	var definition := _definition()
	definition.props = [definition.props[2]]
	var parent := Node2D.new()
	assert_true(MapSceneBootstrap._create_boat_blocks(definition, parent) == null)
	assert_eq(parent.get_child_count(), 0, "no empty body is left behind")
	parent.free()


func _definition() -> MapDefinition:
	var definition := MapDefinition.new()
	definition.cell_size = 32
	var props: Array[Dictionary] = [
		{
			"id": &"boat_tall",
			"kind": MapTypes.PROP_KIND_FISHING_BOAT,
			"position": Vector2(160, 160),
			"footprint": Rect2(128, 80, 64, 160),
		},
		{
			"id": &"boat_wide",
			"kind": MapTypes.PROP_KIND_FISHING_BOAT,
			"position": Vector2(480, 160),
			"footprint": Rect2(400, 128, 160, 64),
		},
		{"id": &"crates", "kind": MapTypes.PROP_KIND_CARGO_CRATES, "position": Vector2(64, 64)},
	]
	definition.props = props
	return definition
