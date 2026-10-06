extends "res://tests/godot/test_case.gd"

## R-1160 follow-up: the water shader drives a river from the channel centreline,
## so the current bends with a meander and the banks drag it. These cover the
## extraction itself and the Pirita it was written for.

const RiverFlow := preload("res://scripts/map/view3d/map_view_river_flow.gd")
const MapAuditRegistry := preload("res://scripts/map/map_audit_registry.gd")

const DOWNSTREAM_NORTH := Vector2(0.0, -1.0)
## Row counts that straddle the downsampling threshold, where the strided walk
## can land on the final sample. 25 rows (stride 2 over 24 slots) is the case
## that actually regressed.
const MAX_POINTS_PROBE_MIN := 25
const MAX_POINTS_PROBE_MAX := 60


func test_straight_channel_gives_one_downstream_heading() -> void:
	var grid := _channel_grid(Vector2i(12, 24), func(_row: int) -> int: return 4, 4)
	var path := RiverFlow.channel_centreline(grid, DOWNSTREAM_NORTH)

	assert_true(path.size() >= 2, "a straight channel must still produce a reach")
	for index in path.size() - 1:
		var step := Vector2(path[index + 1].x - path[index].x, path[index + 1].y - path[index].y)
		assert_true(step.y < 0.0, "the reach must be ordered downstream (north, -Z)")
		assert_true(absf(step.x) < 0.001, "a straight channel must not wander sideways")
	for point in path:
		assert_eq(point.z, 2.0, "half width must be half the authored span")


func test_meander_turns_the_local_heading_with_the_channel() -> void:
	# A channel that swings east in its middle rows, like the Pirita's bends.
	var grid := _channel_grid(
		Vector2i(20, 24), func(row: int) -> int: return 4 + (6 if row >= 8 and row < 16 else 0), 4
	)
	var path := RiverFlow.channel_centreline(grid, DOWNSTREAM_NORTH)
	var headings: Array[Vector2] = []
	for index in path.size() - 1:
		headings.append(
			Vector2(path[index + 1].x - path[index].x, path[index + 1].y - path[index].y).normalized()
		)

	var widest := 0.0
	for a in headings:
		for b in headings:
			widest = maxf(widest, a.angle_to(b))
	assert_true(
		widest > deg_to_rad(20.0),
		"a meander must give its reaches visibly different headings, not one global flow",
	)


func test_a_map_without_river_cells_has_no_channel() -> void:
	var grid := _channel_grid(Vector2i(10, 10), func(_row: int) -> int: return -1, 0)
	assert_eq(
		RiverFlow.channel_centreline(grid, DOWNSTREAM_NORTH).size(),
		0,
		"only authored river water may bind a current",
	)


func test_channel_is_downsampled_to_the_shader_uniform_capacity() -> void:
	var grid := _channel_grid(Vector2i(12, 160), func(_row: int) -> int: return 4, 4)
	var path := RiverFlow.channel_centreline(grid, DOWNSTREAM_NORTH)
	assert_true(
		path.size() <= RiverFlow.MAX_POINTS,
		"the centreline must fit the river_path uniform",
	)
	assert_true(path.size() >= 2, "downsampling must keep a usable reach")


## Invariant: every reach must have a length, because the shader reads its
## heading from the segment. A stride that divides the last sample index appends
## the final point twice; only the smoothing pass then kept the closing reach
## from collapsing to zero length, so pin the invariant itself.
func test_downsampling_never_closes_on_a_zero_length_reach() -> void:
	for rows in range(MAX_POINTS_PROBE_MIN, MAX_POINTS_PROBE_MAX):
		var grid := _channel_grid(Vector2i(12, rows), func(_row: int) -> int: return 4, 4)
		var path := RiverFlow.channel_centreline(grid, DOWNSTREAM_NORTH)
		for index in path.size() - 1:
			var step := Vector2(path[index + 1].x - path[index].x, path[index + 1].y - path[index].y)
			assert_true(
				step.length() > 0.001,
				"every reach of a %d-row channel needs a length to have a heading" % rows,
			)


func test_east_west_channel_is_read_along_its_own_axis() -> void:
	var grid := _empty_grid(Vector2i(24, 12))
	for x in 24:
		for y in range(5, 9):
			grid.set_terrain(Vector2i(x, y), MapTypes.TERRAIN_RIVER_WATER)
	var path := RiverFlow.channel_centreline(grid, Vector2(1.0, 0.0))

	assert_true(path.size() >= 2, "a west-east river must also reduce to a reach")
	for index in path.size() - 1:
		assert_true(
			path[index + 1].x > path[index].x,
			"the reach must run downstream along the authored channel axis",
		)
		assert_eq(path[index].z, 2.0, "half width must come from the across-channel span")


func test_pirita_channel_runs_north_and_bends() -> void:
	var definition: MapDefinition = MapAuditRegistry.by_id()["viru_gate_foreland"]
	var grid := MapBuilder.build(definition)
	var path := RiverFlow.channel_centreline(grid, DOWNSTREAM_NORTH)

	assert_true(path.size() >= 4, "the Pirita must resolve into several reaches")
	var bends := false
	for index in path.size() - 1:
		var step := Vector2(path[index + 1].x - path[index].x, path[index + 1].y - path[index].y)
		assert_true(step.y < 0.0, "the Pirita flows north (-Z) along its whole length")
		bends = bends or absf(step.x) > 0.1
		assert_true(path[index].z > 2.0, "the Pirita channel is several cells wide")
	assert_true(bends, "the authored Pirita meanders; its current must meander with it")


## Grid whose river cells start at `start_for_row(row)` (negative: no river in
## that row) and run `span` cells east.
func _channel_grid(size: Vector2i, start_for_row: Callable, span: int) -> MapTerrainGrid:
	var grid := _empty_grid(size)
	for y in size.y:
		var start: int = start_for_row.call(y)
		if start < 0:
			continue
		for offset in span:
			grid.set_terrain(Vector2i(start + offset, y), MapTypes.TERRAIN_RIVER_WATER)
	return grid


## Grass grid. The first terrain written takes index 0, which is also what every
## untouched cell reads as, so grass must be registered before any river cell.
func _empty_grid(size: Vector2i) -> MapTerrainGrid:
	var grid := MapTerrainGrid.new()
	grid.initialize_chunks(size, MapTypes.DEFAULT_CELL_SIZE, 1)
	grid.set_terrain(Vector2i.ZERO, MapTypes.TERRAIN_GRASS)
	return grid
