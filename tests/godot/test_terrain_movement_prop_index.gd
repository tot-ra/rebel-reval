extends "res://tests/godot/test_case.gd"

## R-1084: slowing-prop cell index must match the linear scan and stay empty
## when a map has no speed-reducing props.

const MonasteryQuarterDefinition := preload(
	"res://scripts/map/definitions/prototypes/monastery_quarter_definition.gd"
)
const SAMPLE_STRIDE := 8
const BENCH_QUERIES := 1000


func test_empty_map_builds_an_empty_slowing_index() -> void:
	var definition := _crate_only_definition()
	assert_eq(definition.props.size(), 1)
	assert_eq(MapTerrainMovement.slowing_prop_index_size(definition), 0)
	var grid := MapBuilder.build(definition)
	var at_crate := MapTerrainMovement.speed_multiplier_at(definition, grid, Vector2(48, 48))
	var linear := MapTerrainMovement.speed_multiplier_at_linear(
		definition, grid, Vector2(48, 48)
	)
	assert_eq(at_crate, 1.0)
	assert_eq(at_crate, linear)


func test_index_matches_linear_scan_on_monastery_and_lower_town() -> void:
	_assert_map_parity(MonasteryQuarterDefinition.create(), "monastery_quarter")
	_assert_map_parity(LowerTownSliceDefinition.create(), "lower_town_slice")


func test_prop_index_micro_benchmark_records_query_cost() -> void:
	var definition: MapDefinition = MonasteryQuarterDefinition.create()
	var grid := MapBuilder.build(definition)
	var samples := _sample_points(definition)
	assert_true(samples.size() > 0, "monastery_quarter must yield sample points")
	# Warm the cache so the timed loop does not include first-build cost.
	MapTerrainMovement.speed_multiplier_at(definition, grid, samples[0])
	var indexed_us := _time_queries(definition, grid, samples, true)
	var linear_us := _time_queries(definition, grid, samples, false)
	print(
		"R-1084 monastery_quarter %d queries indexed=%dus linear=%dus slowing=%d"
		% [
			BENCH_QUERIES,
			indexed_us,
			linear_us,
			MapTerrainMovement.slowing_prop_index_size(definition),
		]
	)
	assert_true(indexed_us >= 0)
	assert_true(linear_us >= 0)


func _assert_map_parity(definition: MapDefinition, map_id: String) -> void:
	assert_true(definition != null, "%s compiled" % map_id)
	assert_eq(String(definition.map_id), map_id)
	var grid := MapBuilder.build(definition)
	var mismatches := 0
	for point in _sample_points(definition):
		var indexed := MapTerrainMovement.speed_multiplier_at(definition, grid, point)
		var linear := MapTerrainMovement.speed_multiplier_at_linear(
			definition, grid, point
		)
		if not is_equal_approx(indexed, linear):
			mismatches += 1
			assert_almost_eq(indexed, linear, 0.0001, "mismatch at %s" % point)
	assert_eq(mismatches, 0, "%s index must match linear scan" % map_id)


func _sample_points(definition: MapDefinition) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var size: Vector2i = definition.size_cells
	for y in range(0, size.y, SAMPLE_STRIDE):
		for x in range(0, size.x, SAMPLE_STRIDE):
			points.append(MapVerification.cell_center(definition, Vector2i(x, y)))
	for prop in definition.props:
		var authored: Variant = prop.get("movement_speed_multiplier")
		var kind: StringName = prop.get("kind", &"")
		if TerrainVegetation.resolved_prop_speed(kind, authored) >= 1.0:
			continue
		if prop.has("footprint"):
			var footprint: Rect2 = prop["footprint"]
			points.append(footprint.position + footprint.size * 0.5)
			points.append(footprint.position + Vector2(1, 1))
		else:
			var position: Vector2 = prop.get("position", Vector2.ZERO)
			points.append(position)
	points.append(Vector2(-16, -16))
	points.append(Vector2(float(size.x * definition.cell_size + 16), 16.0))
	return points


func _time_queries(
	definition: MapDefinition,
	grid: MapTerrainGrid,
	samples: Array[Vector2],
	use_index: bool
) -> int:
	var start := Time.get_ticks_usec()
	for i in BENCH_QUERIES:
		var point: Vector2 = samples[i % samples.size()]
		if use_index:
			MapTerrainMovement.speed_multiplier_at(definition, grid, point)
		else:
			MapTerrainMovement.speed_multiplier_at_linear(definition, grid, point)
	return Time.get_ticks_usec() - start


func _crate_only_definition() -> MapDefinition:
	var definition := MapDefinition.new()
	definition.map_id = &"prop_index_empty"
	definition.location = &"loc.prop_index_empty"
	definition.scope = &"prototype"
	definition.palette = &"clean_painted"
	definition.fingerprint = "prop_index_empty"
	definition.size_cells = Vector2i(4, 4)
	definition.cell_size = 32
	definition.base_terrain = MapTypes.TERRAIN_GRASS
	definition.player_spawn = Vector2(16, 16)
	definition.props.append({
		"id": &"chest.test",
		"kind": MapTypes.PROP_KIND_CHEST,
		"position": Vector2(48, 48),
		"footprint": Rect2(32, 32, 32, 32),
	})
	return definition
