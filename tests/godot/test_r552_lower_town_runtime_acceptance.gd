extends "res://tests/godot/test_case.gd"

const RRMAP_PATH := "res://content/maps/lower_town_slice.rrmap"
const CONTRACT_PATH := "res://docs/data/lower_town_authoring_contract.json"
const LowerTownFactory := preload(
	"res://scripts/map/definitions/lower_town/lower_town_slice_rrmap_factory.gd"
)
const LowerTownDefinition := preload(
	"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
)
const MapBuilderScript := preload("res://scripts/map/map_builder.gd")
const MapChunkRuntimeIndexScript := preload("res://scripts/map/map_chunk_runtime_index.gd")
const MapObjectChunkStreamerScript := preload("res://scripts/map/map_object_chunk_streamer.gd")
const MapParitySnapshotScript := preload("res://scripts/map/map_parity_snapshot.gd")
const MapVerificationScript := preload("res://scripts/map/map_verification.gd")

const QUEST_ANCHOR_IDS: Array[StringName] = [
	&"workers_yard",
	&"carriers_lane",
	&"merchants_market",
	&"customers_street",
]
const FIXED_ACCESS_ANCHOR_IDS: Array[StringName] = [
	&"street_start",
	&"smithy_door",
	&"brewery_door",
	&"checkpoint_west",
	&"checkpoint_east",
	&"watch_west_checkpoint",
	&"watch_east_checkpoint",
]
const PATROL_IDS: Array[StringName] = [&"viru_watch", &"iron_convoy"]


func test_lower_town_rrmap_factory_and_runtime_preserve_canonical_parity() -> void:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return

	var factory_result := MapBlueprintCompiler.compile_with_diagnostics(LowerTownFactory.create())
	assert_true(factory_result.is_ok(), str(factory_result.formatted_diagnostics()))
	if not factory_result.is_ok():
		return

	var runtime_definition: MapDefinition = LowerTownDefinition.create()
	var source_snapshot := MapParitySnapshotScript.serialize(
		parsed.definition, MapBuilderScript.build(parsed.definition)
	)
	var factory_snapshot := MapParitySnapshotScript.serialize(
		factory_result.definition, MapBuilderScript.build(factory_result.definition)
	)
	var runtime_snapshot := MapParitySnapshotScript.serialize(
		runtime_definition, MapBuilderScript.build(runtime_definition)
	)
	assert_eq(factory_snapshot, source_snapshot, "Factory compilation must match RRMap semantics")
	assert_eq(runtime_snapshot, source_snapshot, "Runtime adapter must match RRMap semantics")
	assert_eq(runtime_definition.fingerprint, parsed.definition.fingerprint)


func test_lower_town_required_gameplay_anchors_are_walkable_and_connected() -> void:
	var definition: MapDefinition = LowerTownDefinition.create()
	var grid := MapBuilderScript.build(definition)
	var contract := _load_contract()
	var start := MapVerificationScript.anchor_position(definition, &"street_start")
	assert_true(
		MapVerificationScript.is_walkable_point(definition, grid, start),
		"street_start must be walkable"
	)

	var anchor_ids: Array[StringName] = []
	for section in [&"work_anchors", &"route_anchors"]:
		for raw_id in contract.get(section, []):
			_append_unique(anchor_ids, StringName(raw_id))
	for anchor_id in QUEST_ANCHOR_IDS:
		_append_unique(anchor_ids, anchor_id)
	for anchor_id in FIXED_ACCESS_ANCHOR_IDS:
		_append_unique(anchor_ids, anchor_id)

	for anchor_id in anchor_ids:
		var position := MapVerificationScript.anchor_position(definition, anchor_id)
		assert_true(
			MapVerificationScript.has_anchor(definition, anchor_id),
			"Lower Town is missing required anchor %s" % String(anchor_id)
		)
		assert_true(
			MapVerificationScript.is_walkable_point(definition, grid, position),
			"Lower Town anchor %s is not walkable" % String(anchor_id)
		)
		assert_true(
			MapVerificationScript.route_exists_exact(definition, grid, start, position),
			"Lower Town cannot route from street_start to %s" % String(anchor_id)
		)

	var cistern := _record_by_id(definition.props, &"cistern")
	assert_false(cistern.is_empty(), "The checkpoint cistern must remain a stable prop")
	var cistern_position: Vector2 = cistern.get("position", Vector2.ZERO)
	assert_true(
		MapVerificationScript.is_walkable_point(definition, grid, cistern_position),
		"cistern must be walkable"
	)
	assert_true(
		MapVerificationScript.route_exists_exact(definition, grid, start, cistern_position),
		"Lower Town cannot route from street_start to cistern"
	)


func test_lower_town_collision_entrances_transitions_and_patrols_are_accessible() -> void:
	var definition: MapDefinition = LowerTownDefinition.create()
	var grid := MapBuilderScript.build(definition)
	assert_true(
		MapVerificationScript.collision_parity(definition),
		"Lower Town collision must match authored footprints"
	)

	var smithy := _record_by_id(definition.buildings, &"kalev_smithy")
	var smithy_transition := _record_by_id(definition.transitions, &"smithy_door_transition")
	assert_eq(smithy_transition.get("building_id"), &"kalev_smithy")
	assert_true(
		MapBuildingEntrance.approach_aligns_with_facade(smithy, smithy_transition, definition.cell_size),
		"Smithy transition must approach the Kalev smithy facade"
	)

	var start := MapVerificationScript.anchor_position(definition, &"street_start")
	for transition_id in _string_names(_load_contract().get("transitions", [])):
		var transition_rect := MapVerificationScript.transition_rect(definition, transition_id)
		assert_false(transition_rect == Rect2(), "Missing required transition %s" % String(transition_id))
		var transition_center := transition_rect.get_center()
		assert_true(
			MapVerificationScript.is_walkable_point(definition, grid, transition_center),
			"Transition %s must open onto walkable ground" % String(transition_id)
		)
		assert_true(
			MapVerificationScript.route_exists_exact(definition, grid, start, transition_center),
			"Transition %s must be reachable from street_start" % String(transition_id)
		)

	for patrol_id in PATROL_IDS:
		var patrol := _record_by_id(definition.patrols, patrol_id)
		var points: Array = patrol.get("points", [])
		assert_true(points.size() >= 2, "Patrol %s needs at least two points" % String(patrol_id))
		for patrol_point_index in range(points.size()):
			var patrol_point: Vector2 = points[patrol_point_index]
			var patrol_cell := Vector2i(
				floori(patrol_point.x / definition.cell_size),
				floori(patrol_point.y / definition.cell_size)
			)
			assert_true(
				MapVerificationScript.is_walkable_point(definition, grid, patrol_point),
				"Patrol %s point %d at cell %s is blocked" % [
					String(patrol_id), patrol_point_index, patrol_cell
				]
			)
		for point_index in range(1, points.size()):
			var previous_point: Vector2 = points[point_index - 1]
			var current_point: Vector2 = points[point_index]
			assert_true(
				MapVerificationScript.route_exists(definition, grid, previous_point, current_point),
				"Patrol %s segment %d is disconnected" % [String(patrol_id), point_index]
			)


func test_lower_town_runtime_chunk_index_streams_every_record_without_duplicates() -> void:
	var definition: MapDefinition = LowerTownDefinition.create()
	var index := MapChunkRuntimeIndexScript.build(definition, 32)
	assert_true(index.diagnostics().is_empty(), str(index.diagnostics()))
	assert_eq(index.object_ids().size(), _stable_object_count(definition))

	var streamer_root := Node2D.new()
	var streamer := MapObjectChunkStreamerScript.new()
	streamer_root.add_child(streamer)
	streamer.configure(index, func(_record: Dictionary) -> Node: return Node2D.new())
	for persistent_record in index.persistent_records():
		assert_true(
			streamer.loaded_instance(persistent_record["id"]) != null,
			"Persistent gameplay record %s must load during configure" % String(persistent_record["id"])
		)

	var all_chunks: Array[Vector2i] = []
	for object_id in index.object_ids():
		var record := index.record(object_id)
		assert_false(
			record.get("consumer_chunks", []).is_empty(),
			"%s has no consumer chunk" % String(object_id)
		)
		for chunk: Vector2i in record["consumer_chunks"]:
			if not all_chunks.has(chunk):
				all_chunks.append(chunk)
	all_chunks.sort_custom(_chunk_less)
	streamer.update_active_chunks(all_chunks)

	for object_id in index.object_ids():
		assert_true(
			streamer.loaded_instance(object_id) != null,
			"%s was not streamed" % String(object_id)
		)
		var record := index.record(object_id)
		for chunk: Vector2i in record["consumer_chunks"]:
			var consumed_ids: Array[StringName] = []
			for consumed in index.records_consumed_by(chunk):
				consumed_ids.append(consumed["id"])
			assert_eq(
				consumed_ids.count(object_id),
				1,
				"%s must appear once in consumer %s" % [String(object_id), chunk]
			)
	assert_true(
		streamer.duplicate_instance_ids().is_empty(),
		"Streaming must not duplicate stable IDs"
	)

	streamer.unload_all_chunks()
	assert_true(
		streamer.loaded_instance(&"smithy_door_transition") != null,
		"Transitions must persist across chunk unload"
	)
	assert_true(
		streamer.loaded_instance(&"smithy_door") != null,
		"Gameplay anchors must persist across chunk unload"
	)
	assert_true(
		streamer.loaded_instance(&"cistern") == null,
		"Decorative props must unload with their chunks"
	)
	streamer_root.free()


func _load_contract() -> Dictionary:
	var file := FileAccess.open(CONTRACT_PATH, FileAccess.READ)
	assert_true(file != null, "Missing Lower Town authoring contract")
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	assert_true(parsed is Dictionary, "Lower Town authoring contract must be a JSON object")
	return parsed if parsed is Dictionary else {}


func _record_by_id(records: Array, object_id: StringName) -> Dictionary:
	for record in records:
		if record.get("id") == object_id:
			return record
	return {}


func _string_names(values: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for value in values:
		result.append(StringName(value))
	return result


func _append_unique(values: Array[StringName], value: StringName) -> void:
	if not values.has(value):
		values.append(value)


func _stable_object_count(definition: MapDefinition) -> int:
	return (
		definition.buildings.size()
		+ definition.props.size()
		+ definition.transitions.size()
		+ definition.interaction_anchors.size()
		+ definition.view_landmarks.size()
		+ definition.direction_signs.size()
	)


func _chunk_less(left: Vector2i, right: Vector2i) -> bool:
	return left.y < right.y or (left.y == right.y and left.x < right.x)
