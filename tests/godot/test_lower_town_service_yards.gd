extends "res://tests/godot/test_case.gd"

## R-546 / P0-100d: authored density contract for Lower Town service yards.
## WHY: yard details must be reviewable as semantic map authoring, not inferred
## from generic prop counts or renderer-only geometry.

const LowerTownSliceDefinition := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapTypes := preload("res://scripts/map/map_types.gd")
const MapVerification := preload("res://scripts/map/map_verification.gd")


const SERVICE_YARD_BUILDINGS: Array[StringName] = [
	&"brewery_rear_store",
	&"smithy_rear_shed",
	&"carriers_barn",
	&"smithy_yard_fence_north",
	&"smithy_yard_fence_east",
]
const SERVICE_YARD_PROPS: Array[StringName] = [
	&"service_yard_gate_west",
	&"service_yard_gate_east",
	&"service_yard_firewood",
	&"service_yard_hay",
	&"service_yard_scrub_west",
	&"service_yard_scrub_east",
]
const SERVICE_YARD_DECALS: Array[StringName] = [
	&"decal.wet_service_gate",
	&"decal.mud_carriers_lane",
	&"decal.grime_service_firewood",
]


func test_service_yard_has_authored_fences_sheds_fuel_and_greenery() -> void:
	var definition := LowerTownSliceDefinition.create()
	var source_ids := _source_ids()
	for building_id in SERVICE_YARD_BUILDINGS:
		assert_true(source_ids["building"].has(String(building_id)), "service yard building is missing: %s" % building_id)
	for prop_id in SERVICE_YARD_PROPS:
		assert_true(source_ids["prop"].has(String(prop_id)), "service yard prop is missing: %s" % prop_id)

	var building_ids := _ids(definition.buildings)
	var prop_ids := _ids(definition.props)
	for building_id in SERVICE_YARD_BUILDINGS:
		assert_true(building_ids.has(String(building_id)), "service yard building is not compiled: %s" % building_id)
	for prop_id in SERVICE_YARD_PROPS:
		assert_true(prop_ids.has(String(prop_id)), "service yard prop is not compiled: %s" % prop_id)

	assert_true(_prop_of_kind(definition, MapTypes.PROP_KIND_TIMBER_FENCE).size() >= 2, "yard gates need two timber fence runs")
	assert_true(_prop_of_kind(definition, MapTypes.PROP_KIND_FIREWOOD_STACK).size() >= 2, "service yards need fuel storage")
	assert_true(_prop_of_kind(definition, MapTypes.PROP_KIND_HAY_STACK).size() >= 2, "service yards need hay storage")
	assert_true(_prop_of_kind(definition, MapTypes.PROP_KIND_BUSH).size() >= 3, "Lower Town needs sparse authored yard greenery")
	assert_true(_building_of_id(definition, &"brewery_rear_store").get("house_tier") == &"craft_boda", "brewery rear store must keep craft-boda tier")
	assert_true(_building_of_id(definition, &"smithy_rear_shed").get("house_tier") == &"craft_boda", "smithy rear shed must keep craft-boda tier")


func test_service_yard_drainage_is_view_only_and_contextual() -> void:
	var definition := LowerTownSliceDefinition.create()
	var grid := MapBuilder.build(definition)
	var decal_ids := _ids(definition.decals)
	for decal_id in SERVICE_YARD_DECALS:
		assert_true(decal_ids.has(String(decal_id)), "service yard drainage cue is missing: %s" % decal_id)

	assert_eq(_decal_kind(definition, &"decal.wet_service_gate"), MapTypes.DECAL_KIND_WET_THRESHOLD)
	assert_eq(_decal_kind(definition, &"decal.mud_carriers_lane"), MapTypes.DECAL_KIND_MUD)
	assert_eq(_decal_kind(definition, &"decal.grime_service_firewood"), MapTypes.DECAL_KIND_GRIME)
	var fingerprint_before := grid.fingerprint()
	var definition_fingerprint := definition.fingerprint
	definition.decals.clear()
	assert_eq(MapBuilder.build(definition).fingerprint(), fingerprint_before, "yard drainage must not alter gameplay terrain")
	assert_eq(definition.fingerprint, definition_fingerprint, "view-only decal removal must not mutate authored gameplay data")


func test_service_yard_detail_keeps_routes_and_interaction_approaches_open() -> void:
	var definition := LowerTownSliceDefinition.create()
	var grid := MapBuilder.build(definition)
	var workers_yard := MapVerification.anchor_position(definition, &"workers_yard")
	var carriers_lane := MapVerification.anchor_position(definition, &"carriers_lane")
	var brewery_door := MapVerification.anchor_position(definition, &"brewery_door")
	assert_true(MapVerification.route_exists(definition, grid, workers_yard, brewery_door), "yard dressing must preserve workers-to-brewery access")
	assert_true(MapVerification.route_exists(definition, grid, carriers_lane, brewery_door), "yard dressing must preserve carrier-to-brewery access")

	for prop_id in SERVICE_YARD_PROPS:
		var prop := _prop_by_id(definition, prop_id)
		assert_true(not prop.is_empty(), "missing compiled service-yard prop %s" % prop_id)
		# Bushes are view-only edge dressing and may sit against an existing wall or
		# gate-house footprint; route checks below are the gameplay non-blocking proof.
		if prop.get("kind", &"") != MapTypes.PROP_KIND_BUSH:
			assert_true(MapVerification.is_walkable_point(definition, grid, prop["position"]), "service detail must remain gameplay-walkable: %s" % prop_id)
		if prop.has("footprint"):
			var footprint: Rect2 = prop["footprint"]
			assert_true(footprint.position.x >= 0.0 and footprint.position.y >= 0.0, "prop footprint must stay inside map: %s" % prop_id)
			assert_true(footprint.end.x <= definition.size_cells.x * definition.cell_size and footprint.end.y <= definition.size_cells.y * definition.cell_size, "prop footprint must stay inside map: %s" % prop_id)

	assert_true(_landmark_by_id(definition, &"viru_gate_arch").has("rect"), "required Viru gate context must remain authored")
	assert_true(_landmark_by_id(definition, &"viru_foregate_arch").has("rect"), "required foregate context must remain authored")


func _source_ids() -> Dictionary:
	var result := {"building": {}, "prop": {}}
	var file := FileAccess.open("res://content/maps/lower_town_slice.rrmap", FileAccess.READ)
	assert_true(file != null, "Lower Town RRMap source must be readable")
	if file == null:
		return result
	for raw in file.get_as_text().split("\n"):
		var tokens := String(raw).strip_edges().split(" ", false)
		if tokens.size() >= 2 and result.has(tokens[0]):
			result[tokens[0]][String(tokens[1])] = true
	return result


func _ids(rows: Array) -> Dictionary:
	var result := {}
	for row in rows:
		result[String(row.get("id", ""))] = true
	return result


func _prop_of_kind(definition: MapDefinition, kind: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for prop in definition.props:
		if prop.get("kind", &"") == kind:
			result.append(prop)
	return result


func _prop_by_id(definition: MapDefinition, prop_id: StringName) -> Dictionary:
	for prop in definition.props:
		if prop.get("id", &"") == prop_id:
			return prop
	return {}


func _building_of_id(definition: MapDefinition, building_id: StringName) -> Dictionary:
	for building in definition.buildings:
		if building.get("id", &"") == building_id:
			return building
	return {}


func _decal_kind(definition: MapDefinition, decal_id: StringName) -> StringName:
	for decal in definition.decals:
		if decal.get("id", &"") == decal_id:
			return decal.get("kind", &"")
	return &""


func _landmark_by_id(definition: MapDefinition, landmark_id: StringName) -> Dictionary:
	for landmark in definition.view_landmarks:
		if landmark.get("id", &"") == landmark_id:
			return landmark
	return {}
