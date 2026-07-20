extends "res://tests/godot/test_case.gd"

const NORTH_PATH := "res://content/maps/reval_harbor_north.rrmap"
const EAST_PATH := "res://content/maps/reval_harbor_east.rrmap"

var _definitions: Array[MapDefinition] = []


func after_each() -> void:
	# Releasing the strong references is sufficient for RefCounted definitions.
	_definitions.clear()


func _definition(path: String) -> MapDefinition:
	var parsed := MapRrmapParser.parse_file(path)
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return null
	var definition: MapDefinition = parsed.definition
	_definitions.append(definition)
	return definition


func test_finds_reciprocal_harbor_transition_and_aligns_touching_edges() -> void:
	var north := _definition(NORTH_PATH)
	var east := _definition(EAST_PATH)
	if north == null or east == null:
		return

	var pairs := MapAlignmentMath.find_transition_pairs(north, east)
	assert_eq(pairs.size(), 1)
	if pairs.is_empty():
		return
	var pair: Dictionary = pairs[0]
	assert_eq(pair["base"]["id"], &"to_harbor_east")
	assert_eq(pair["neighbor"]["id"], &"to_harbor_north")
	assert_eq(pair["base_side"], &"south")
	assert_eq(pair["neighbor_side"], &"north")

	var offset := MapAlignmentMath.aligned_neighbor_offset(
		north,
		east,
		pair["base"],
		pair["neighbor"]
	)
	assert_eq(offset, Vector2(31 * 32, 72 * 32))
	assert_eq(
		MapAlignmentMath.offset_in_neighbor_cells(east, offset),
		Vector2(31, 72)
	)
	assert_eq(MapAlignmentMath.seam_span_cells(north, pair["base"], &"south"), 12.0)
	assert_eq(MapAlignmentMath.seam_span_cells(east, pair["neighbor"], &"north"), 10.0)


func test_layout_connected_city_maps_places_every_reciprocal_neighbor() -> void:
	var definitions: Array[MapDefinition] = []
	for path in [
		"res://content/maps/lower_town_slice.rrmap",
		"res://content/maps/market_civic_quarter.rrmap",
		"res://content/maps/north_quarter.rrmap",
		"res://content/maps/south_quarter.rrmap",
		"res://content/maps/toompea_quarter.rrmap",
	]:
		var definition := _definition(path)
		if definition != null:
			definitions.append(definition)
	if definitions.size() != 5:
		return

	var layout := MapAlignmentMath.layout_connected_maps(definitions, &"lower_town_slice")
	var offsets: Dictionary = layout["offsets"]
	assert_eq(offsets.size(), 5)
	assert_true(layout["unplaced"].is_empty())
	assert_true(layout["seams"].size() >= 4)
	assert_eq(offsets[&"lower_town_slice"], Vector2.ZERO)


func test_layout_all_maps_keeps_disconnected_interiors_visible() -> void:
	var definitions: Array[MapDefinition] = []
	for path in [
		"res://content/maps/lower_town_slice.rrmap",
		"res://content/maps/market_civic_quarter.rrmap",
		"res://tests/fixtures/maps/rrmap_courtyard_example.rrmap",
	]:
		var definition := _definition(path)
		if definition != null:
			definitions.append(definition)
	if definitions.size() != 3:
		return

	var layout := MapAlignmentMath.layout_all_maps(definitions, &"lower_town_slice")
	assert_eq(layout["offsets"].size(), 3)
	assert_array_contains(layout["unplaced"], &"rrmap_courtyard_example")


func test_unlinked_maps_have_no_automatic_transition_pair() -> void:
	var north := _definition(NORTH_PATH)
	var smithy := _definition("res://content/maps/kalev_smithy.rrmap")
	if north != null and smithy != null:
		assert_true(MapAlignmentMath.find_transition_pairs(north, smithy).is_empty())
