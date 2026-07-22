extends "res://tests/godot/test_case.gd"

const RRMAP_PATH := "res://content/maps/viru_gate_foreland.rrmap"
const ForelandDefinition := preload("res://scripts/map/definitions/outdoor/viru_gate_foreland_definition.gd")


func test_viru_gate_foreland_parses_and_stays_inactive() -> void:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	assert_eq(parsed.blueprint.map_id, &"viru_gate_foreland")
	assert_eq(parsed.definition.location, &"loc.reval.viru_gate_foreland")
	assert_eq(parsed.definition.size_cells, Vector2i(112, 80))
	assert_eq(parsed.definition.scope, &"prototype")
	assert_false(parsed.definition.active)
	assert_eq(parsed.definition.surroundings_sides.get(&"west"), &"town")
	assert_eq(parsed.definition.surroundings_sides.get(&"east"), &"woodland")


func test_viru_gate_foreland_reciprocates_workers_district() -> void:
	var foreland: MapDefinition = ForelandDefinition.create()
	var town: MapDefinition = preload(
		"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
	).create()
	var from_town := _transition(town, &"viru_road_boundary")
	var to_town := _transition(foreland, &"to_reval_east")
	assert_eq(from_town["destination_scene_id"], &"viru_gate_foreland")
	assert_eq(from_town["destination_spawn_id"], &"from_reval_east")
	assert_eq(to_town["destination_scene_id"], &"reval_east")
	assert_eq(to_town["destination_spawn_id"], &"viru_road_boundary")
	assert_true(DoorNavigator.has_spawn(&"viru_gate_foreland", &"from_reval_east"))


func test_kalamaja_is_not_a_viru_road_neighbor() -> void:
	var kalamaja: MapDefinition = preload(
		"res://scripts/map/definitions/outdoor/reval_harbor_east_definition.gd"
	).create()
	for transition in kalamaja.transitions:
		assert_ne(transition.get("destination_scene_id"), &"reval_east")
	assert_false(DoorNavigator.has_spawn(&"reval_harbor_east", &"from_reval_east"))


func test_foreland_masks_off_limits_edges_with_dense_woodland() -> void:
	var definition: MapDefinition = ForelandDefinition.create()
	var view := MapView3D.create(definition, MapBuilder.build(definition))
	assert_true(view.has_node("Surroundings/WoodlandApron_north"))
	assert_true(view.has_node("Surroundings/WoodlandApron_east"))
	assert_true(view.has_node("Surroundings/WoodlandApron_south"))
	assert_true(_tree_instance_count(view.get_node("Surroundings")) > 100)
	view.free()


func _tree_instance_count(root: Node) -> int:
	# Species-aware foliage uses one deterministic trunk batch per silhouette;
	# the woodland density contract applies to their combined forest screen.
	var total := 0
	for child in root.get_children():
		if child is MultiMeshInstance3D and String(child.name).begins_with("TreeTrunks"):
			total += (child as MultiMeshInstance3D).multimesh.instance_count
	return total


func _transition(definition: MapDefinition, transition_id: StringName) -> Dictionary:
	for transition in definition.transitions:
		if transition["id"] == transition_id:
			return transition
	fail("missing transition %s on %s" % [transition_id, definition.map_id])
	return {}
