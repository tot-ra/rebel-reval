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


func test_finds_reciprocal_harbor_transition_and_aligns_kalamaja_to_west() -> void:
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
	assert_eq(pair["base_side"], &"west")
	assert_eq(pair["neighbor_side"], &"east")

	var offset := MapAlignmentMath.aligned_neighbor_offset(
		north,
		east,
		pair["base"],
		pair["neighbor"]
	)
	# Kalamaja is the fishing shore north-west of the walled town.
	assert_eq(offset, Vector2(-144 * 32, 20 * 32))
	assert_eq(
		MapAlignmentMath.offset_in_neighbor_cells(east, offset),
		Vector2(-144, 20)
	)
	assert_eq(MapAlignmentMath.seam_span_cells(north, pair["base"], &"west"), 8.0)
	assert_eq(MapAlignmentMath.seam_span_cells(east, pair["neighbor"], &"east"), 8.0)


func test_layout_connected_city_maps_places_every_reciprocal_neighbor() -> void:
	var definitions: Array[MapDefinition] = []
	for path in [
		"res://content/maps/lower_town_slice.rrmap",
		"res://content/maps/market_civic_quarter.rrmap",
		"res://content/maps/monastery_quarter.rrmap",
		"res://content/maps/north_quarter.rrmap",
		"res://content/maps/south_quarter.rrmap",
		"res://content/maps/toompea_quarter.rrmap",
		"res://content/maps/archbishops_garden.rrmap",
	]:
		var definition := _definition(path)
		if definition != null:
			definitions.append(definition)
	if definitions.size() != 7:
		return

	var layout := MapAlignmentMath.layout_connected_maps(definitions, &"lower_town_slice")
	var offsets: Dictionary = layout["offsets"]
	assert_eq(offsets.size(), 7)
	assert_true(layout["unplaced"].is_empty())
	assert_true(layout["seams"].size() >= 5)
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


func test_long_distance_travel_transitions_do_not_become_physical_seams() -> void:
	var town := _definition("res://content/maps/lower_town_slice.rrmap")
	var harbor := _definition("res://content/maps/reval_harbor_east.rrmap")
	assert_true(MapAlignmentMath.find_transition_pairs(town, harbor).is_empty())


func test_reval_city_cycles_resolve_to_one_physical_offset() -> void:
	var definitions: Array[MapDefinition] = []
	for path in [
		"res://content/maps/lower_town_slice.rrmap",
		"res://content/maps/market_civic_quarter.rrmap",
		"res://content/maps/monastery_quarter.rrmap",
		"res://content/maps/north_quarter.rrmap",
		"res://content/maps/south_quarter.rrmap",
		"res://content/maps/toompea_quarter.rrmap",
		"res://content/maps/archbishops_garden.rrmap",
	]:
		definitions.append(_definition(path))
	var layout := MapAlignmentMath.layout_connected_maps(definitions, &"lower_town_slice")
	var offsets: Dictionary = layout["offsets"]
	for seam in layout["seams"]:
		var base: MapDefinition = definitions.filter(func(d): return d.map_id == seam["base_map_id"])[0]
		var neighbor: MapDefinition = definitions.filter(func(d): return d.map_id == seam["neighbor_map_id"])[0]
		var expected := Vector2(offsets[base.map_id]) + MapAlignmentMath.aligned_neighbor_offset(base, neighbor, seam["base"], seam["neighbor"])
		assert_eq(Vector2(offsets[neighbor.map_id]), expected, "Conflicting map cycle at %s/%s" % [base.map_id, neighbor.map_id])
