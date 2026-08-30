extends "res://tests/godot/test_case.gd"

const NunnatornDefinition := preload(
	"res://scripts/map/definitions/prototypes/nunnatorn_interior_definition.gd"
)
const NunnatornFactory := preload(
	"res://scripts/map/definitions/prototypes/nunnatorn_interior_rrmap_factory.gd"
)

const SOURCE_PATH := "res://content/maps/nunnatorn_interior.rrmap"
const REQUIRED_ANCHORS: Array[StringName] = [
	&"nunnatorn_interior_entry",
	&"nunnatorn_floor_ground",
	&"nunnatorn_floor_watch",
	&"nunnatorn_floor_roof",
	&"nunnatorn_wall_walk",
	&"nunnatorn_wall_walk_entry",
	&"nunnatorn_boss",
	&"nunnatorn_boss_alternate_resolution",
	&"nunnatorn_loot",
	&"nunnatorn_evidence",
]


func test_nunnatorn_interior_map() -> void:
	var parsed := MapRrmapParser.parse_file(SOURCE_PATH)
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return

	var definition: MapDefinition = NunnatornDefinition.create()
	var blueprint: MapBlueprint = NunnatornFactory.create()
	assert_true(definition != null)
	assert_true(blueprint != null)
	assert_eq(blueprint.map_id, &"nunnatorn_interior")
	assert_eq(definition.map_id, &"nunnatorn_interior")
	assert_eq(blueprint.source_references.size(), 4)
	assert_true(blueprint.source_references.has("docs/reports/nunnatorn_interior_contract.md"))
	assert_false(definition.active, "Nunnatorn remains developer-only until activation gates pass")
	assert_eq(definition.scope, &"prototype")
	assert_eq(definition.size_cells, Vector2i(18, 18))
	assert_eq(definition.get_meta("player_spawn_id"), &"spawn.nunnatorn_interior_entry")

	for anchor_id in REQUIRED_ANCHORS:
		assert_true(
			MapVerification.has_anchor(definition, anchor_id),
			"Missing Nunnatorn anchor %s" % anchor_id
		)

	var grid := MapBuilder.build(definition)
	for anchor_id in REQUIRED_ANCHORS:
		assert_true(
			MapVerification.route_exists_exact(
				definition,
				grid,
				definition.player_spawn,
				MapVerification.anchor_position(definition, anchor_id)
			),
			"Nunnatorn anchor %s must be reachable from the safe entry" % anchor_id
		)

	assert_eq(definition.excluded_areas.size(), 2)
	assert_eq(definition.fade_volumes.size(), 1)
	var candle_count := 0
	for prop in definition.props:
		if prop.get("kind", &"") == MapTypes.PROP_KIND_CANDLE:
			candle_count += 1
	assert_eq(candle_count, 3, "Each reconstructed level needs a readable tallow light")

	var access_props := 0
	var platform_props := 0
	for prop in definition.props:
		if MapWallWalkAccess.is_access_prop(prop):
			access_props += 1
		if MapWallWalkAccess.is_platform_prop(prop):
			platform_props += 1
	assert_eq(access_props, 1)
	assert_eq(platform_props, 2)
	assert_true(MapVerification.has_anchor(definition, &"nunnatorn_wall_walk_entry"))

	var south_segments := 0
	for building in definition.buildings:
		var building_id := String(building.get("id", ""))
		if building_id in ["wall.south.west", "wall.south.east"]:
			south_segments += 1
	assert_eq(south_segments, 2, "Open-backed south edge must retain both boundary returns")

	var canonical := MapRrmapParser.canonical_print(blueprint)
	var reparsed := MapRrmapParser.parse(canonical, "res://nunnatorn_interior.canonical.rrmap")
	assert_true(reparsed.is_ok(), str(reparsed.formatted_diagnostics()))
	if reparsed.is_ok():
		assert_eq(MapRrmapParser.canonical_print(reparsed.blueprint), canonical)

	var source_again := MapRrmapParser.parse_file(SOURCE_PATH)
	assert_true(source_again.is_ok(), str(source_again.formatted_diagnostics()))
	if source_again.is_ok():
		assert_eq(source_again.definition.fingerprint, definition.fingerprint)

	var source := FileAccess.get_file_as_string(SOURCE_PATH).to_lower()
	for forbidden in ["horseshoe", "fat margaret", "cannon", "post-1343"]:
		assert_false(forbidden in source, "Forbidden later-form token leaked into source: %s" % forbidden)


func test_nunnatorn_floor_partitions_keep_central_vertical_openings() -> void:
	var definition: MapDefinition = NunnatornDefinition.create()
	var expected_segments := {
		&"floor.partition.ground/segment.000": Rect2(32, 192, 192, 32),
		&"floor.partition.ground/segment.001": Rect2(320, 192, 224, 32),
		&"floor.partition.watch/segment.000": Rect2(32, 384, 384, 32),
		&"floor.partition.watch/segment.001": Rect2(512, 384, 32, 32),
	}

	var actual_segments := {}
	for building in definition.buildings:
		var building_id := StringName(building.get("id", ""))
		if expected_segments.has(building_id):
			actual_segments[building_id] = building.get("footprint")
	assert_eq(
		actual_segments,
		expected_segments,
		"Floor partitions must preserve their authored openings"
	)
	assert_eq(actual_segments.size(), 4, "Both floor partitions need a compiled gap")
