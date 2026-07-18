extends "res://tests/godot/test_case.gd"


func test_load_unload_lifecycle_preserves_global_transform_and_recreates_once() -> void:
	var definition := _definition()
	var index := MapChunkRuntimeIndex.build(definition, 32)
	var root := Node2D.new()
	var streamer := MapObjectChunkStreamer.new()
	root.add_child(streamer)
	var created := {"count": 0}
	streamer.configure(index, func(record: Dictionary) -> Node:
		created["count"] += 1
		var node := Node2D.new()
		node.position = (record["source"] as Dictionary).get("position", Vector2.ZERO)
		return node
	)

	streamer.load_chunk(Vector2i(2, 0))
	var first := streamer.loaded_instance(&"prop.decorative") as Node2D
	assert_true(first != null)
	assert_eq(first.position, Vector2(70 * 32, 4 * 32))
	assert_eq(first.global_position, first.position, "streaming roots must not rebase authored transforms")
	assert_eq(created["count"], 1)

	streamer.unload_chunk(Vector2i(2, 0))
	assert_true(streamer.loaded_instance(&"prop.decorative") == null)
	streamer.load_chunk(Vector2i(2, 0))
	var second := streamer.loaded_instance(&"prop.decorative") as Node2D
	assert_true(second != null and second != first)
	assert_eq(second.position, Vector2(70 * 32, 4 * 32))
	assert_eq(created["count"], 2)
	root.free()


func test_boundary_spanning_object_has_one_owner_full_footprint_and_no_duplicate() -> void:
	var index := MapChunkRuntimeIndex.build(_definition(), 32)
	var record := index.record(&"building.crossing")
	assert_eq(record["owner_chunk"], Vector2i(0, 0))
	assert_eq(record["consumer_chunks"], [Vector2i(0, 0), Vector2i(1, 0)])

	var root := Node2D.new()
	var streamer := MapObjectChunkStreamer.new()
	root.add_child(streamer)
	var created := {"count": 0}
	streamer.configure(index, func(indexed: Dictionary) -> Node:
		created["count"] += 1
		var body := StaticBody2D.new()
		body.set_meta(&"footprint", (indexed["source"] as Dictionary)["footprint"])
		return body
	)
	streamer.load_chunk(Vector2i(0, 0))
	var first := streamer.loaded_instance(&"building.crossing")
	streamer.load_chunk(Vector2i(1, 0))
	assert_eq(streamer.loaded_instance(&"building.crossing"), first)
	assert_eq(created["count"], 1)
	assert_eq(first.get_meta(&"footprint"), Rect2(31 * 32, 2 * 32, 2 * 32, 2 * 32))
	assert_true(streamer.duplicate_instance_ids().is_empty())

	streamer.unload_chunk(Vector2i(0, 0))
	assert_eq(streamer.loaded_instance(&"building.crossing"), first, "consumer keeps the complete object resident")
	streamer.unload_chunk(Vector2i(1, 0))
	assert_true(streamer.loaded_instance(&"building.crossing") == null)
	root.free()


func test_lookup_remains_stable_while_unloaded_and_persistent_records_do_not_unload() -> void:
	var index := MapChunkRuntimeIndex.build(_definition(), 32)
	var root := Node2D.new()
	var streamer := MapObjectChunkStreamer.new()
	root.add_child(streamer)
	streamer.configure(index, func(record: Dictionary) -> Node:
		return Node2D.new() if record["kind"] in [&"prop", &"anchor"] else null
	)

	var unloaded := streamer.resolve(&"prop.decorative")
	assert_false(unloaded["loaded"])
	assert_eq(unloaded["handle"], {"location_id": "loc.chunk_streaming_test", "object_id": "prop.decorative"})
	assert_eq(unloaded["source"]["position"], Vector2(70 * 32, 4 * 32))
	assert_true(streamer.loaded_instance(&"anchor.gameplay") != null)
	streamer.update_active_chunks([Vector2i(2, 0)])
	streamer.unload_all_chunks()
	assert_true(streamer.loaded_instance(&"prop.decorative") == null)
	assert_true(streamer.loaded_instance(&"anchor.gameplay") != null, "gameplay-critical records outlive decorative chunks")
	assert_eq(streamer.resolve(&"prop.decorative")["handle"], unloaded["handle"])
	root.free()


func test_state_delta_restores_after_streamed_reload() -> void:
	var definition := _definition()
	var store := MapStableStateStore.new()
	assert_true(store.record_object_delta(definition.location, &"prop.decorative", {"used": true, "charges": 2}))
	var index := MapChunkRuntimeIndex.build(definition, 32)
	var root := Node2D.new()
	var streamer := MapObjectChunkStreamer.new()
	root.add_child(streamer)
	streamer.configure(index, func(record: Dictionary) -> Node:
		var node := Node2D.new()
		node.set_meta(&"restored_state", store.object_delta(definition.location, record["id"]))
		return node
	)
	streamer.load_chunk(Vector2i(2, 0))
	assert_eq(streamer.loaded_instance(&"prop.decorative").get_meta(&"restored_state"), {"used": true, "charges": 2})
	streamer.unload_chunk(Vector2i(2, 0))
	streamer.load_chunk(Vector2i(2, 0))
	assert_eq(streamer.loaded_instance(&"prop.decorative").get_meta(&"restored_state"), {"used": true, "charges": 2})
	root.free()


func test_duplicate_ids_produce_deterministic_diagnostic_without_second_record() -> void:
	var definition := _definition()
	definition.props.append({"id": &"building.crossing", "kind": MapTypes.PROP_KIND_CART, "position": Vector2(8, 8)})
	var index := MapChunkRuntimeIndex.build(definition, 32)
	assert_eq(index.diagnostics(), ["duplicate compiled stable id: building.crossing"])
	assert_eq(index.object_ids().count(&"building.crossing"), 1)
	assert_eq(index.record(&"building.crossing")["kind"], &"building")


func test_lower_town_streaming_preserves_complete_current_renderer_output() -> void:
	var definition: MapDefinition = preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd").create()
	var grid := MapBuilder.build(definition)
	var parent := Node2D.new()
	var actors := Node2D.new()
	parent.add_child(actors)
	var assembled := MapAssembler.assemble(parent, definition, grid, actors)
	var streamer := assembled["object_streamer"] as MapObjectChunkStreamer
	assert_eq((assembled["terrain"] as MapTerrainRenderer).loaded_chunk_count(), grid.chunk_coordinates().size())
	assert_eq(streamer.loaded_instance_count(), definition.buildings.size() + definition.props.size())
	assert_eq(assembled["buildings"].size(), definition.buildings.size())
	assert_eq(assembled["props"].size(), definition.props.size())
	assert_true(streamer.duplicate_instance_ids().is_empty())
	for building in definition.buildings:
		var body := streamer.loaded_instance(building["id"]) as StaticBody2D
		assert_eq(body.position, MapBuildingRenderer.footprint_y_sort_anchor(building["footprint"]))
		assert_eq(body.get_meta(&"footprint"), building["footprint"])
	parent.free()


func _definition() -> MapDefinition:
	var definition := MapDefinition.new()
	definition.map_id = &"chunk_streaming_test"
	definition.location = &"loc.chunk_streaming_test"
	definition.cell_size = 32
	definition.size_cells = Vector2i(96, 32)
	definition.fingerprint = "chunk-streaming-test-v1"
	definition.buildings = [
		{"id": &"building.crossing", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": Rect2(31 * 32, 2 * 32, 2 * 32, 2 * 32)},
	]
	definition.props = [
		{"id": &"prop.decorative", "kind": MapTypes.PROP_KIND_CART, "position": Vector2(70 * 32, 4 * 32)},
	]
	definition.interaction_anchors = [
		{"id": &"anchor.gameplay", "kind": &"interaction", "position": Vector2(4 * 32, 4 * 32)},
	]
	return definition
