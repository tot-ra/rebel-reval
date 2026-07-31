extends "res://tests/godot/test_case.gd"

const PropStyleVariants := preload("res://scripts/map/map_prop_style_variants.gd")

const CONTRACT_PATH := "res://docs/reports/toompea_1343_fabric_contract.md"
const MAP_AUTHORING_PATH := "res://docs/MAP_AUTHORING.md"
const HISTORICAL_AUDIT_PATH := "res://docs/HISTORICAL_AUDIT.md"


func test_toompea_fabric_allowlists_are_closed_r006_r035_set() -> void:
	assert_eq(PropStyleVariants.TOOMPEA_ZONES.size(), 3)
	assert_array_contains(PropStyleVariants.TOOMPEA_ZONES, PropStyleVariants.TOOMPEA_ZONE_SMALL_CASTLE)
	assert_array_contains(PropStyleVariants.TOOMPEA_ZONES, PropStyleVariants.TOOMPEA_ZONE_GREAT_CASTLE)
	assert_array_contains(PropStyleVariants.TOOMPEA_ZONES, PropStyleVariants.TOOMPEA_ZONE_OUTER_WARD)
	assert_false(PropStyleVariants.is_known_toompea_zone(&"order_convent"))

	assert_eq(PropStyleVariants.TOOMPEA_HOUSE_TIERS.size(), 3)
	assert_array_contains(PropStyleVariants.TOOMPEA_HOUSE_TIERS, PropStyleVariants.TOOMPEA_HOUSE_VASSAL_CURIA)
	assert_array_contains(PropStyleVariants.TOOMPEA_HOUSE_TIERS, PropStyleVariants.TOOMPEA_HOUSE_CANON_LODGING)
	assert_array_contains(PropStyleVariants.TOOMPEA_HOUSE_TIERS, PropStyleVariants.TOOMPEA_HOUSE_SERVICE_WING)
	assert_true(PropStyleVariants.is_known_house_tier(PropStyleVariants.TOOMPEA_HOUSE_VASSAL_CURIA))
	assert_false(PropStyleVariants.is_known_toompea_house_tier(&"merchant_palace"))

	assert_eq(PropStyleVariants.REVAL_JURISDICTIONS.size(), 2)
	assert_true(PropStyleVariants.is_known_reval_jurisdiction(PropStyleVariants.JURISDICTION_TOOMPEA_DANISH))
	assert_true(PropStyleVariants.is_known_reval_jurisdiction(PropStyleVariants.JURISDICTION_ALL_LINN_LUBECK))
	assert_false(PropStyleVariants.is_known_reval_jurisdiction(&"livonian_order"))

	assert_eq(PropStyleVariants.TOOMPEA_HILL_GATE_STYLES.size(), 2)
	assert_true(PropStyleVariants.is_known_toompea_hill_gate_style(PropStyleVariants.TOOMPEA_HILL_GATE_PIKK_JALG_TIMBER))
	assert_true(PropStyleVariants.is_known_toompea_hill_gate_style(PropStyleVariants.TOOMPEA_HILL_GATE_LUHIKE_JALG_TIMBER))
	assert_false(PropStyleVariants.is_known_toompea_hill_gate_style(&"hill_gate.pikk_jalg.stone_tower"))


func test_toompea_house_and_danish_jurisdiction_round_trip() -> void:
	var source := """rrmap 1
map toompea_contract loc.toompea_contract 20 16 timber_floor
building vassal_house house 2 2 5 5 house_tier=vassal_curia faction=danish_crown
building canon_house house 9 2 4 4 house_tier=canon_lodging
building service_house house 14 2 3 3 house_tier=service_wing
spawn spawn.main 1 1
"""
	var parsed := MapRrmapParser.parse(source, "res://toompea_contract.rrmap")
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	var by_id := {}
	for building in parsed.definition.buildings:
		by_id[building["id"]] = building
	assert_eq(by_id[&"vassal_house"].get("house_tier"), PropStyleVariants.TOOMPEA_HOUSE_VASSAL_CURIA)
	assert_eq(by_id[&"vassal_house"].get("faction"), &"danish_crown")
	assert_eq(by_id[&"canon_house"].get("house_tier"), PropStyleVariants.TOOMPEA_HOUSE_CANON_LODGING)
	assert_eq(by_id[&"service_house"].get("house_tier"), PropStyleVariants.TOOMPEA_HOUSE_SERVICE_WING)

	var canonical := MapRrmapParser.canonical_print(parsed.blueprint)
	assert_true("house_tier=vassal_curia" in canonical)
	assert_true("house_tier=canon_lodging" in canonical)
	assert_true("house_tier=service_wing" in canonical)
	assert_true("faction=danish_crown" in canonical)
	var reparsed := MapRrmapParser.parse(canonical, "res://toompea_contract.canonical.rrmap")
	assert_true(reparsed.is_ok(), str(reparsed.formatted_diagnostics()))


func test_hill_gate_leaf_round_trips_and_stone_tower_style_is_rejected() -> void:
	var source := """rrmap 1
map toompea_hill_gate loc.toompea_hill_gate 20 16 timber_floor
landmark pikk_jalg_gate gate_arch 8 5 4 5 gate_variant=oak passage_axis=x
spawn spawn.main 1 1
"""
	var parsed := MapRrmapParser.parse(source, "res://toompea_hill_gate.rrmap")
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	assert_eq(parsed.definition.view_landmarks[0].get("gate_variant"), PropStyleVariants.GATE_VARIANT_OAK)
	var canonical := MapRrmapParser.canonical_print(parsed.blueprint)
	assert_true("gate_variant=oak" in canonical)

	var invalid := source.replace("gate_variant=oak", "gate_variant=stone_tower")
	var rejected := MapRrmapParser.parse(invalid, "res://invalid_toompea_hill_gate.rrmap")
	assert_false(rejected.is_ok(), "unknown hill-gate stone tower styles must fail parsing")
	assert_true(
		str(rejected.formatted_diagnostics()).contains("gate_variant is unknown: stone_tower"),
		"invalid gate_variant needs the stable diagnostic"
	)


func test_contract_docs_name_fabric_keys_confidence_and_exclusions() -> void:
	var contract := _read_text(CONTRACT_PATH)
	var authoring := _read_text(MAP_AUTHORING_PATH)
	var audit := _read_text(HISTORICAL_AUDIT_PATH)
	for required in [
		"small_castle",
		"great_castle",
		"outer_ward",
		"vassal_curia",
		"canon_lodging",
		"service_wing",
		"toompea_danish",
		"all_linn_lubeck",
		"hill_gate.pikk_jalg.timber",
		"hill_gate.luhike_jalg.timber",
		"gate_variant is unknown: stone_tower",
		"Pikk Hermann",
		"Order convent",
		"16 May 1343",
		"attested",
		"plausible composite",
		"unknown",
	]:
		assert_true(required in contract, "contract must mention %s" % required)
	for required in [
		"vassal_curia",
		"canon_lodging",
		"service_wing",
		"toompea_danish",
		"all_linn_lubeck",
		"gate_variant is unknown",
	]:
		assert_true(required in authoring, "MAP_AUTHORING must mention %s" % required)
	for required in ["wooden", "Pikk jalg", "Lühike jalg", "1454", "R-006", "R-035"]:
		assert_true(required in audit, "HISTORICAL_AUDIT must mention %s" % required)
	assert_false("gate superstructures require separate dating review **C/U**" in audit)


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	assert_true(file != null, "missing %s" % path)
	if file == null:
		return ""
	return file.get_as_text()
