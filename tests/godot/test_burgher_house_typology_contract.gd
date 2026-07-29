extends "res://tests/godot/test_case.gd"

const PropStyleVariants := preload("res://scripts/map/map_prop_style_variants.gd")

const CONTRACT_PATH := "res://docs/reports/burgher_house_typology_contract.md"
const MAP_AUTHORING_PATH := "res://docs/MAP_AUTHORING.md"


func test_house_tier_allowlist_is_closed_r003_set() -> void:
	assert_eq(PropStyleVariants.HOUSE_TIERS.size(), 3)
	assert_array_contains(PropStyleVariants.HOUSE_TIERS, PropStyleVariants.HOUSE_TIER_MERCHANT_STONE)
	assert_array_contains(PropStyleVariants.HOUSE_TIERS, PropStyleVariants.HOUSE_TIER_MERCHANT_TIMBER)
	assert_array_contains(PropStyleVariants.HOUSE_TIERS, PropStyleVariants.HOUSE_TIER_CRAFT_BODA)
	assert_true(PropStyleVariants.is_known_house_tier(&""), "empty house_tier stays optional until P2-067")
	assert_true(PropStyleVariants.is_known_house_tier(PropStyleVariants.HOUSE_TIER_MERCHANT_STONE))
	assert_false(PropStyleVariants.is_known_house_tier(&"late_gothic_tourist"))
	assert_true(PropStyleVariants.house_tier_allows_hoist(PropStyleVariants.HOUSE_TIER_MERCHANT_STONE))
	assert_true(PropStyleVariants.house_tier_allows_hoist(PropStyleVariants.HOUSE_TIER_MERCHANT_TIMBER))
	assert_false(PropStyleVariants.house_tier_allows_hoist(PropStyleVariants.HOUSE_TIER_CRAFT_BODA))


func test_house_tier_round_trips_and_rejects_unknown_value() -> void:
	var source := """rrmap 1
map house_tiers loc.house_tiers 16 12 timber_floor
building merchant_a house 2 2 4 5 house_tier=merchant_stone
building timber_b house 7 2 4 4 house_tier=merchant_timber
building boda_c house 12 2 3 3 house_tier=craft_boda
spawn spawn.main 1 1
"""
	var parsed := MapRrmapParser.parse(source, "res://house_tiers.rrmap")
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	var by_id := {}
	for building in parsed.definition.buildings:
		by_id[building["id"]] = building
	assert_eq(by_id[&"merchant_a"].get("house_tier"), PropStyleVariants.HOUSE_TIER_MERCHANT_STONE)
	assert_eq(by_id[&"timber_b"].get("house_tier"), PropStyleVariants.HOUSE_TIER_MERCHANT_TIMBER)
	assert_eq(by_id[&"boda_c"].get("house_tier"), PropStyleVariants.HOUSE_TIER_CRAFT_BODA)

	var canonical := MapRrmapParser.canonical_print(parsed.blueprint)
	assert_true("house_tier=merchant_stone" in canonical)
	assert_true("house_tier=merchant_timber" in canonical)
	assert_true("house_tier=craft_boda" in canonical)
	var reparsed := MapRrmapParser.parse(canonical, "res://house_tiers.canonical.rrmap")
	assert_true(reparsed.is_ok(), str(reparsed.formatted_diagnostics()))

	var invalid := source.replace("house_tier=craft_boda", "house_tier=late_gothic_tourist")
	var rejected := MapRrmapParser.parse(invalid, "res://invalid_house_tier.rrmap")
	assert_false(rejected.is_ok(), "unknown house_tier must fail compilation")
	assert_true(
		str(rejected.formatted_diagnostics()).contains("house_tier is unknown"),
		"invalid house_tier needs the stable diagnostic"
	)


func test_contract_docs_name_tiers_and_rejection_rules() -> void:
	var contract := _read_text(CONTRACT_PATH)
	var authoring := _read_text(MAP_AUTHORING_PATH)
	for required in [
		"merchant_stone",
		"merchant_timber",
		"craft_boda",
		"diele",
		"dornse",
		"55–65%",
		"35–45%",
		"house_tier is unknown",
		"Late-Gothic",
		"plausible composite",
	]:
		assert_true(required in contract, "contract must mention %s" % required)
	for required in ["house_tier", "merchant_stone", "merchant_timber", "craft_boda", "house_tier is unknown"]:
		assert_true(required in authoring, "MAP_AUTHORING must mention %s" % required)


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	assert_true(file != null, "missing %s" % path)
	if file == null:
		return ""
	return file.get_as_text()
