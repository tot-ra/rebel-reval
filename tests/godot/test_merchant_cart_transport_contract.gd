extends "res://tests/godot/test_case.gd"

const PropStyleVariants := preload("res://scripts/map/map_prop_style_variants.gd")

const CONTRACT_PATH := "res://docs/reports/merchant_cart_transport_contract.md"
const MAP_AUTHORING_PATH := "res://docs/MAP_AUTHORING.md"


func test_vehicle_class_allowlist_is_closed_r068_set() -> void:
	assert_eq(PropStyleVariants.VEHICLE_CLASSES.size(), 4)
	assert_array_contains(PropStyleVariants.VEHICLE_CLASSES, PropStyleVariants.VEHICLE_CLASS_CART_2W)
	assert_array_contains(PropStyleVariants.VEHICLE_CLASSES, PropStyleVariants.VEHICLE_CLASS_WAGON_4W)
	assert_array_contains(PropStyleVariants.VEHICLE_CLASSES, PropStyleVariants.VEHICLE_CLASS_BARROW)
	assert_array_contains(PropStyleVariants.VEHICLE_CLASSES, PropStyleVariants.VEHICLE_CLASS_SLEDGE)
	assert_eq(PropStyleVariants.DEFAULT_URBAN_VEHICLE_CLASS, PropStyleVariants.VEHICLE_CLASS_CART_2W)
	assert_true(PropStyleVariants.is_known_vehicle_class(&""), "empty vehicle_class stays optional until P2-068")
	assert_true(PropStyleVariants.is_known_vehicle_class(PropStyleVariants.VEHICLE_CLASS_CART_2W))
	assert_false(PropStyleVariants.is_known_vehicle_class(&"war_wagon"))
	assert_true(PropStyleVariants.vehicle_class_is_default_urban(PropStyleVariants.VEHICLE_CLASS_CART_2W))
	assert_true(PropStyleVariants.vehicle_class_allows_harbour_or_wall_only(PropStyleVariants.VEHICLE_CLASS_WAGON_4W))
	assert_false(PropStyleVariants.vehicle_class_allows_harbour_or_wall_only(PropStyleVariants.VEHICLE_CLASS_CART_2W))
	assert_eq(PropStyleVariants.WHEEL_RUT_SPACING_M, 1.3)
	assert_eq(PropStyleVariants.CART_PATH_WIDTH_MIN_M, 2.5)
	assert_false(PropStyleVariants.CART_TOLL_ATTESTED)
	assert_true(PropStyleVariants.cart_toll_pfennig() == null)
	assert_eq(PropStyleVariants.CART_CORRIDORS.size(), 5)
	assert_true(PropStyleVariants.is_known_cart_corridor(PropStyleVariants.CART_CORRIDOR_VANATURG_THROAT))
	assert_false(PropStyleVariants.is_known_cart_corridor(&"gate_toll_booth"))


func test_vehicle_class_round_trips_and_rejects_unknown_value() -> void:
	var source := """rrmap 1
map cart_classes loc.cart_classes 16 12 timber_floor
prop karren cart 2 2 rect=2,2 vehicle_class=cart_2w
prop freight cart 6 2 rect=3,2 vehicle_class=wagon_4w
prop sack_barrow cart 10 2 rect=1,1 vehicle_class=barrow
prop mud_runner cart 13 2 rect=2,2 vehicle_class=sledge
spawn spawn.main 1 1
"""
	var parsed := MapRrmapParser.parse(source, "res://cart_classes.rrmap")
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	var by_id := {}
	for prop in parsed.definition.props:
		by_id[prop["id"]] = prop
	assert_eq(by_id[&"karren"].get("vehicle_class"), PropStyleVariants.VEHICLE_CLASS_CART_2W)
	assert_eq(by_id[&"freight"].get("vehicle_class"), PropStyleVariants.VEHICLE_CLASS_WAGON_4W)
	assert_eq(by_id[&"sack_barrow"].get("vehicle_class"), PropStyleVariants.VEHICLE_CLASS_BARROW)
	assert_eq(by_id[&"mud_runner"].get("vehicle_class"), PropStyleVariants.VEHICLE_CLASS_SLEDGE)

	var canonical := MapRrmapParser.canonical_print(parsed.blueprint)
	assert_true("vehicle_class=cart_2w" in canonical)
	assert_true("vehicle_class=wagon_4w" in canonical)
	assert_true("vehicle_class=barrow" in canonical)
	assert_true("vehicle_class=sledge" in canonical)
	var reparsed := MapRrmapParser.parse(canonical, "res://cart_classes.canonical.rrmap")
	assert_true(reparsed.is_ok(), str(reparsed.formatted_diagnostics()))

	var invalid := source.replace("vehicle_class=sledge", "vehicle_class=war_wagon")
	var rejected := MapRrmapParser.parse(invalid, "res://invalid_vehicle_class.rrmap")
	assert_false(rejected.is_ok(), "unknown vehicle_class must fail compilation")
	assert_true(
		str(rejected.formatted_diagnostics()).contains("vehicle_class is unknown"),
		"invalid vehicle_class needs the stable diagnostic"
	)


func test_contract_docs_name_classes_and_rejection_rules() -> void:
	var contract := _read_text(CONTRACT_PATH)
	var authoring := _read_text(MAP_AUTHORING_PATH)
	for required in [
		"cart_2w",
		"wagon_4w",
		"barrow",
		"sledge",
		"wheel_rut_spacing",
		"1.3",
		"cart_path_width_min",
		"2.5",
		"cart_toll_pfennig",
		"vehicle_class is unknown",
		"War-wagon",
		"plausible composite",
		"gap",
		"vanaturg_throat",
		"viru_apron",
	]:
		assert_true(required in contract, "contract must mention %s" % required)
	for required in [
		"vehicle_class",
		"cart_2w",
		"wagon_4w",
		"barrow",
		"sledge",
		"vehicle_class is unknown",
		"wheel_rut_spacing",
		"cart_toll_pfennig",
	]:
		assert_true(required in authoring, "MAP_AUTHORING must mention %s" % required)


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	assert_true(file != null, "missing %s" % path)
	if file == null:
		return ""
	return file.get_as_text()
