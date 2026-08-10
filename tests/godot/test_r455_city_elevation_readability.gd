extends GutTest

# R-455 acceptance coverage is intentionally data-first: visual readability is
# only marked PASS when the runtime exposes measurable geometry/metadata.
const TOOMPEA_GROUND_ELEVATION := 2.8

func _new_toompea():
	return ToompeaDefinition.create()

func _new_monastery():
	return MonasteryQuarterDefinition.create()

func _new_harbor():
	return RevalHarborEastDefinition.create()

func _new_lower_town():
	return LowerTownSliceDefinition.create()

func _terrain_grid(definition):
	return MapBuilder.build(definition)

func _water_count(grid) -> int:
	var width := int(grid.get("width"))
	var height := int(grid.get("height"))
	var count := 0
	for y in range(height):
		for x in range(width):
			if MapTypes.WATER_TERRAINS.has(grid.get_terrain(Vector2i(x, y))):
				count += 1
	return count

func _water_shore_edges(grid) -> int:
	var width := int(grid.get("width"))
	var height := int(grid.get("height"))
	var edges := 0
	for y in range(height):
		for x in range(width):
			var cell := Vector2i(x, y)
			if not MapTypes.WATER_TERRAINS.has(grid.get_terrain(cell)):
				continue
			for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var neighbour := cell + direction
				if neighbour.x < 0 or neighbour.y < 0 or neighbour.x >= width or neighbour.y >= height:
					continue
				if not MapTypes.WATER_TERRAINS.has(grid.get_terrain(neighbour)):
					edges += 1
	return edges

func _assert_camera_bounds(label: String, definition) -> void:
	var bounds = definition.get("camera_bounds")
	assert_true(bounds is Rect2, "%s camera bounds must be a Rect2" % label)
	if bounds is Rect2:
		assert_gt(bounds.size.x, 0.0, "%s camera bounds width" % label)
		assert_gt(bounds.size.y, 0.0, "%s camera bounds height" % label)

func test_r455_toompea_ground_elevation_and_deterministic_height() -> void:
	var definition = _new_toompea()
	assert_almost_eq(float(definition.get("ground_elevation")), TOOMPEA_GROUND_ELEVATION, 0.001, "Toompea authored elevation")
	_assert_camera_bounds("Toompea", definition)
	var cell := Vector2i.ZERO
	var first := float(MapViewMeshBuilder.ground_height(definition, cell))
	var second := float(MapViewMeshBuilder.ground_height(definition, cell))
	assert_almost_eq(first, second, 0.0001, "ground height must be deterministic")

func test_r455_target_maps_expose_or_explicitly_lack_grade_metadata() -> void:
	for item in [
		["Toompea", _new_toompea()],
		["Monastery", _new_monastery()],
		["Harbor North", _new_harbor()],
	]:
		var label: String = item[0]
		var definition = item[1]
		var profiles = definition.get("elevation_profiles")
		assert_true(profiles is Array, "%s elevation_profiles contract" % label)
		# Empty profiles are a passing regression guard for the known BLOCKED
		# state, not evidence that grades have been accepted.
		if profiles is Array and profiles.is_empty():
			print("[R-455][BLOCKED] %s has no authored elevation_profiles" % label)

func test_r455_recessed_water_and_shoreline_have_runtime_cells() -> void:
	var monastery_grid = _terrain_grid(_new_monastery())
	var harbor_grid = _terrain_grid(_new_harbor())
	var monastery_water := _water_count(monastery_grid)
	var harbor_water := _water_count(harbor_grid)
	assert_gt(monastery_water, 0, "Monastery ditch/water cells must be authored")
	assert_gt(harbor_water, 0, "Harbor North water cells must be authored")
	assert_gt(_water_shore_edges(harbor_grid), 0, "Harbor North water must meet non-water shoreline cells")
	print("[R-455][BLOCKED] no public ditch-depth field proves the recessed offset; visual/mesh evidence remains required")

func test_r455_objects_patrols_and_camera_contracts() -> void:
	for item in [
		["Toompea", _new_toompea()],
		["Lower Town", _new_lower_town()],
	]:
		var label: String = item[0]
		var definition = item[1]
		var buildings = definition.get("buildings")
		assert_true(buildings is Array, "%s buildings contract" % label)
		if buildings is Array:
			assert_gt(buildings.size(), 0, "%s must contain placed objects" % label)
		_assert_camera_bounds(label, definition)
		var patrols = definition.get("patrols")
		assert_true(patrols is Array, "%s patrols contract" % label)
		if patrols is Array:
			assert_gt(patrols.size(), 0, "%s must contain patrol routes" % label)
			for patrol in patrols:
				assert_true(patrol is Dictionary, "%s patrol entries must be dictionaries" % label)
				var route = patrol.get("route", patrol.get("points", patrol.get("waypoints", []))) if patrol is Dictionary else []
				assert_true(route is Array, "%s patrol route must be an array" % label)
				if route is Array:
					assert_gte(route.size(), 2, "%s patrol route must have a segment" % label)
		print("[R-455][BLOCKED] player-eye/top-down readability and exact object-to-terrain alignment need rendered camera evidence")
