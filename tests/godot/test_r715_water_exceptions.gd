extends "res://tests/godot/test_case.gd"

const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapVerification := preload("res://scripts/map/map_verification.gd")
const MapView := preload("res://scripts/map/view3d/map_view_3d.gd")
const MapTypesContract := preload("res://scripts/map/map_types.gd")
const SmithyCourtyard := preload("res://scripts/map/smithy_courtyard_definition.gd")
const LowerTownSlice := preload(
	"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
)
const SouthQuarter := preload(
	"res://scripts/map/definitions/prototypes/south_quarter_definition.gd"
)
const ViruGateForeland := preload(
	"res://scripts/map/definitions/outdoor/viru_gate_foreland_definition.gd"
)
const RevalHarborNorth := preload(
	"res://scripts/map/definitions/outdoor/reval_harbor_north_definition.gd"
)
const RevalHarborEast := preload(
	"res://scripts/map/definitions/outdoor/reval_harbor_east_definition.gd"
)
const CoastHarbor := preload("res://scripts/map/definitions/outdoor/coast_harbor_definitions.gd")
const WildernessEvents := preload(
	"res://scripts/map/definitions/outdoor/wilderness_event_definitions.gd"
)
const DistantLocations := preload(
	"res://scripts/map/definitions/outdoor/distant_location_definitions.gd"
)

const EXCEPTIONS_REPORT := "res://docs/reports/r715_water_exceptions.md"
const EXPECTED_EXCEPTION_MATRIX := {
	&"smithy_courtyard": {
		"water_ids": [&"water"],
		"classes": [&"enclosed"],
		"shoreline": false,
	},
	&"lower_town_slice": {
		"water_ids": [&"water"],
		"classes": [&"enclosed"],
		"shoreline": false,
	},
	&"south_quarter": {
		"water_ids": [&"water"],
		"classes": [&"enclosed"],
		"shoreline": false,
	},
	&"viru_gate_foreland": {
		"water_ids": [&"river_water"],
		"classes": [&"river"],
		"shoreline": false,
	},
	&"reval_harbor_north": {
		"water_ids": [&"shallow_water", &"deep_water"],
		"classes": [&"shallow_coastal", &"deep_coastal", &"harbour"],
		"shoreline": true,
	},
	&"reval_harbor_east": {
		"water_ids": [&"shallow_water", &"deep_water"],
		"classes": [&"shallow_coastal", &"deep_coastal", &"harbour"],
		"shoreline": true,
	},
	&"prototype.paldiski_coastal_outpost": {
		"water_ids": [&"shallow_water", &"deep_water"],
		"classes": [&"shallow_coastal", &"deep_coastal", &"shoreline"],
		"shoreline": true,
	},
	&"prototype.sacred_grove": {
		"water_ids": [&"shallow_water"],
		"classes": [&"shallow_coastal", &"shoreline"],
		"shoreline": true,
	},
	&"prototype.saaremaa": {
		"water_ids": [&"shallow_water", &"deep_water"],
		"classes": [&"shallow_coastal", &"deep_coastal", &"shoreline"],
		"shoreline": true,
	},
	&"prototype.swedish_arrival": {
		"water_ids": [&"shallow_water", &"deep_water"],
		"classes": [&"shallow_coastal", &"deep_coastal", &"shoreline"],
		"shoreline": true,
	},
	&"world.sacred_grove": {
		"water_ids": [&"shallow_water"],
		"classes": [&"shallow_coastal", &"shoreline"],
		"shoreline": true,
	},
	&"world.padise": {
		"water_ids": [&"water", &"river_water", &"shallow_water"],
		"classes": [&"enclosed", &"river", &"shallow_coastal", &"shoreline"],
		"shoreline": true,
	},
	&"world.saaremaa": {
		"water_ids": [&"shallow_water", &"deep_water"],
		"classes": [&"shallow_coastal", &"deep_coastal", &"shoreline"],
		"shoreline": true,
	},
}

const EXTERNALLY_EXCLUDED_MAP := &"monastery_quarter"


func test_water_exceptions_are_closed_and_preserve_gameplay_topology() -> void:
	var found: Dictionary = {}
	for definition: MapDefinition in _water_definitions():
		if definition.map_id.is_empty():
			continue
		var grid := MapBuilder.build(definition)
		var water_ids := _water_ids(grid)
		if water_ids.is_empty():
			continue
		var map_id := definition.map_id
		assert_true(
			EXPECTED_EXCEPTION_MATRIX.has(map_id),
			"unexpected water-bearing definition requires an exception-matrix update: %s" % map_id,
		)
		if not EXPECTED_EXCEPTION_MATRIX.has(map_id):
			continue
		var expected: Dictionary = EXPECTED_EXCEPTION_MATRIX[map_id]
		assert_eq(
			water_ids,
			expected["water_ids"],
			"%s must retain its authored water family" % map_id,
		)
		found[map_id] = expected

		var fingerprint_before := grid.fingerprint()
		var walkability_before := _walkability_signature(definition, grid)
		var view := MapView.create(definition, grid)
		assert_true(view != null, "%s exception must build through the shared view" % map_id)
		if view == null:
			continue
		assert_eq(
			grid.fingerprint(),
			fingerprint_before,
			"%s view construction must not mutate terrain fingerprints" % map_id,
		)
		assert_eq(
			_walkability_signature(definition, grid),
			walkability_before,
			"%s view construction must not mutate gameplay walkability" % map_id,
		)
		_free_view(view)

	var expected_ids: Array[StringName] = []
	for expected_id: StringName in EXPECTED_EXCEPTION_MATRIX.keys():
		expected_ids.append(expected_id)
	expected_ids.sort()
	var found_ids: Array[StringName] = []
	for found_id: StringName in found.keys():
		found_ids.append(found_id)
	found_ids.sort()
	assert_eq(found_ids, expected_ids, "exception matrix must cover every inventoried water row")


func test_water_exception_handoff_is_fail_closed() -> void:
	var report := FileAccess.get_file_as_string(EXCEPTIONS_REPORT)
	assert_true(not report.is_empty(), "water exception handoff report must exist")
	for map_id: StringName in EXPECTED_EXCEPTION_MATRIX:
		assert_true(
			report.contains("| `%s` |" % String(map_id)),
			"exception report must contain the inventory row for %s" % map_id,
		)
		var expected: Dictionary = EXPECTED_EXCEPTION_MATRIX[map_id]
		for water_id: StringName in expected["water_ids"]:
			assert_true(
				report.contains("`%s`" % String(water_id)),
				"exception report must name %s for %s" % [water_id, map_id],
			)
		for exception_class: StringName in expected["classes"]:
			assert_true(
				report.contains("`%s`" % String(exception_class)),
				"exception report must classify %s as %s" % [map_id, exception_class],
			)
	assert_true(report.contains("13/13 green"), "handoff must state the green exception count")
	assert_true(
		report.contains("monastery_quarter") and report.contains("intentionally excluded"),
		"handoff must keep the Monastery map explicitly excluded",
	)
	assert_true(
		report.contains("R-529") and report.contains("external map blocker"),
		"handoff must name R-529 as the external map blocker",
	)
	assert_true(
		report.contains("R-713") and report.contains("weather/presentation owner"),
		"handoff must name R-713 as the weather/presentation owner",
	)


func _water_definitions() -> Array[MapDefinition]:
	# Keep this list aligned with the 13 report rows so unrelated invalid prototype
	# definitions cannot mask the water exception and topology checks.
	return [
		SmithyCourtyard.create(),
		LowerTownSlice.create(),
		SouthQuarter.create(),
		ViruGateForeland.create(),
		RevalHarborNorth.create(),
		RevalHarborEast.create(),
		CoastHarbor.paldiski_outpost(),
		WildernessEvents.sacred_grove(),
		WildernessEvents.saaremaa(),
		WildernessEvents.swedish_arrival(),
		DistantLocations.create(&"world_sacred_grove"),
		DistantLocations.create(&"world_padise"),
		DistantLocations.create(&"world_saaremaa"),
	]


func _water_ids(grid: MapTerrainGrid) -> Array[StringName]:
	var result: Array[StringName] = []
	for terrain_id: StringName in MapTypesContract.WATER_TERRAINS:
		if grid.used_terrain_ids().has(terrain_id):
			result.append(terrain_id)
	return result


func _walkability_signature(definition: MapDefinition, grid: MapTerrainGrid) -> String:
	var blocked := MapVerification.blocked_cells(definition)
	var cells := PackedByteArray()
	cells.resize(definition.size_cells.x * definition.size_cells.y)
	for y in definition.size_cells.y:
		for x in definition.size_cells.x:
			var cell := Vector2i(x, y)
			var walkable := not MapTypesContract.WATER_TERRAINS.has(grid.get_terrain(cell))
			walkable = walkable and not blocked.has(cell)
			cells[y * definition.size_cells.x + x] = 1 if walkable else 0
	return cells.hex_encode()


func _free_view(view: MapView) -> void:
	if not is_instance_valid(view):
		return
	MapView._strip_geometry_materials(view)
	view.free()
