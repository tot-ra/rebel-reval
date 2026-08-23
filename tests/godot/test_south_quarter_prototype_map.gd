extends "res://tests/godot/test_case.gd"

const SouthQuarterDefinition := preload(
	"res://scripts/map/definitions/prototypes/south_quarter_definition.gd"
)

const CONTRACT_PATH := "res://docs/reports/south_quarter_1343_fabric_contract.md"
const THRESHOLDS_PATH := "res://docs/data/map_composition_thresholds.json"
const ACTIVATION_MANIFEST_PATH := "res://docs/data/location_activation_manifest.json"
const AUDIT_MANIFEST_PATH := "res://content/map_audit_manifest.json"
const RRMAP_PATH := "res://content/maps/south_quarter.rrmap"


func test_south_quarter_contract_freezes_sources_evidence_and_exclusions() -> void:
	var contract := FileAccess.get_file_as_string(CONTRACT_PATH)
	assert_true(contract.contains("H08 - Tallinn defensive walls"))
	assert_true(contract.contains("H09 - Viru/Vana Turg/Kuninga archaeology"))
	assert_true(contract.contains("H10 - Karja Gate archaeology"))
	for evidence_id in [
		"p4_024.south.rataskaev_well.day",
		"p4_024.south.rataskaev_well.night",
		"p4_024.south.western_connector.day",
		"p4_024.south.western_connector.night",
		"p4_024.south.eastern_ward.day",
		"p4_024.south.eastern_ward.night",
		"p4_024.south.knights_court.day",
		"p4_024.south.knights_court.night",
		"p4_024.south.service_plots.day",
		"p4_024.south.service_plots.night",
		"p4_024.south.karja_gate.day",
		"p4_024.south.karja_gate.night",
		"p4_024.south.neighbor_seams.day",
		"p4_024.south.neighbor_seams.night",
	]:
		assert_true(contract.contains(evidence_id), "Missing South Quarter evidence ID %s" % evidence_id)
	for excluded_form in [
		"saunatorn",
		"neitsitorn",
		"kiek_in_de_kok",
		"fat_margaret",
		"later Karja/Viru barbicans",
	]:
		assert_true(contract.contains(excluded_form), "Missing historical exclusion %s" % excluded_form)
	assert_true(contract.contains("GateDoor0"), "Contract must reserve the Karja GateDoor0 affordance")
	assert_true(
		contract.contains("Rataskaev") and contract.contains("1375"),
		"Rataskaev uncertainty must remain explicit",
	)

	var thresholds: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(THRESHOLDS_PATH))
	var card: Dictionary = thresholds["maps"]["south_quarter"]
	assert_true(card.get("enforce", false), "South Quarter composition must be enforced")
	assert_eq(card.get("enforcement_state"), "enforced")
	assert_eq(card.get("ownership_contract"), "docs/reports/south_quarter_1343_fabric_contract.md")
	assert_eq(card.get("source_refs"), ["H08-H10"])

	var activation: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(ACTIVATION_MANIFEST_PATH)
	)
	var activation_rows: Array = activation["maps"].filter(
		func(row): return row.get("map_id") == "south_quarter"
	)
	assert_eq(activation_rows.size(), 1)
	var activation_row: Dictionary = activation_rows[0]
	assert_false(activation_row.get("implementation_delivered", true))
	assert_eq(activation_row["composition"]["enforce"], true)
	assert_eq(activation_row["composition"]["status"], "BLOCKED")
	assert_eq(activation_row["landmarks"]["present_affordances"], [])
	assert_eq(activation_row["population"]["profile_ids"], [])
	assert_eq(activation_row["gameplay"]["loop_ids"], [])

	var audit_manifest: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(AUDIT_MANIFEST_PATH)
	)
	var audit_rows: Array = audit_manifest["maps"].filter(
		func(row): return row.get("id") == "south_quarter"
	)
	assert_eq(audit_rows.size(), 1)
	assert_eq(audit_rows[0]["composition_enforcement"]["state"], "enforced")
	assert_eq(
		audit_rows[0]["composition_enforcement"]["ownership"],
		"docs/reports/south_quarter_1343_fabric_contract.md",
	)

	var rrmap := FileAccess.get_file_as_string(RRMAP_PATH)
	assert_true(rrmap.contains("map south_quarter"))
	assert_true(rrmap.contains("active=false"), "South Quarter must remain inactive")





func test_south_quarter_prototype_bounds_and_anchors() -> void:
	var definition: MapDefinition = SouthQuarterDefinition.create()
	assert_eq(definition.size_cells, Vector2i(336, 96))
	assert_true(MapBuilder.validate(definition).is_empty())
	for anchor_id in [&"rataskaev_well", &"karja_approach", &"king_street_climb"]:
		assert_true(
			MapVerification.has_anchor(definition, anchor_id),
			"Missing south-quarter anchor %s" % anchor_id,
		)


func test_south_quarter_district_life_dressing() -> void:
	var definition: MapDefinition = SouthQuarterDefinition.create()
	var dressing_kinds := {
		MapTypes.PROP_KIND_WASH_TUB: false,
		MapTypes.PROP_KIND_BARRELS: false,
		MapTypes.PROP_KIND_WEAPON_RACK: false,
		MapTypes.PROP_KIND_BANNER: false,
		MapTypes.PROP_KIND_CHARCOAL_PILE: false,
		MapTypes.PROP_KIND_IRON_SCRAP_PILE: false,
	}
	for prop in definition.props:
		var kind: StringName = prop.get("kind", &"")
		if dressing_kinds.has(kind):
			dressing_kinds[kind] = true
	for dressing_kind in dressing_kinds:
		assert_true(
			dressing_kinds[dressing_kind],
			"South quarter needs district-life prop %s" % String(dressing_kind),
		)
	assert_true(
		_prop_near_prop(definition, &"rataskaev_well_wash", &"rataskaev_well_prop", 6),
		"Wash tub must sit beside Rataskaev well"
	)
	assert_true(
		_prop_near_prop(definition, &"rataskaev_well_buckets", &"rataskaev_well_prop", 6),
		"Well buckets must sit beside Rataskaev well"
	)
	assert_true(
		_prop_near_building(definition, &"knights_court_weapon", &"knights_hall", 8),
		"Weapon rack must sit beside knights_hall"
	)
	assert_true(
		_prop_near_building(definition, &"knights_hall_banner", &"knights_hall", 8),
		"Knights' court banner must sit beside knights_hall"
	)
	assert_true(
		_prop_near_building(definition, &"knights_court_barrels", &"knights_hall", 10),
		"Service barrels must sit in the knights' court"
	)
	assert_true(
		_prop_near_building(definition, &"karja_yard_charcoal", &"karja_gate_house_west", 8),
		"Charcoal pile must sit in the Karja gate service yard"
	)
	assert_true(
		_prop_near_building(definition, &"swordsmith_scrap", &"swordsmith_row", 8),
		"Iron scrap must sit beside swordsmith_row"
	)
	var grid := MapBuilder.build(definition)
	for point in (definition.patrols[0]["points"] as Array):
		assert_true(
			MapVerification.is_walkable_point(definition, grid, point),
			"Patrol point %s must stay walkable after south-quarter dressing" % point
		)


func _building_by_id(definition: MapDefinition, building_id: StringName) -> Dictionary:
	for building in definition.buildings:
		if building["id"] == building_id:
			return building
	return {}


func _prop_by_id(definition: MapDefinition, prop_id: StringName) -> Dictionary:
	for prop in definition.props:
		if prop["id"] == prop_id:
			return prop
	return {}


func _prop_near_prop(
	definition: MapDefinition,
	prop_id: StringName,
	other_prop_id: StringName,
	max_distance_cells: int
) -> bool:
	var prop := _prop_by_id(definition, prop_id)
	var other := _prop_by_id(definition, other_prop_id)
	if prop.is_empty() or other.is_empty():
		return false
	var prop_pos: Vector2 = prop.get("position", Vector2.ZERO)
	var other_pos: Vector2 = other.get("position", Vector2.ZERO)
	return prop_pos.distance_to(other_pos) <= float(max_distance_cells * definition.cell_size)


func _prop_near_building(
	definition: MapDefinition,
	prop_id: StringName,
	building_id: StringName,
	max_distance_cells: int
) -> bool:
	var prop := _prop_by_id(definition, prop_id)
	var building := _building_by_id(definition, building_id)
	if prop.is_empty() or building.is_empty():
		return false
	var prop_pos: Vector2 = prop.get("position", Vector2.ZERO)
	var footprint: Rect2 = building["footprint"]
	var closest := Vector2(
		clampf(prop_pos.x, footprint.position.x, footprint.end.x),
		clampf(prop_pos.y, footprint.position.y, footprint.end.y)
	)
	return prop_pos.distance_to(closest) <= float(max_distance_cells * definition.cell_size)
