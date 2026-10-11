extends "res://tests/godot/test_case.gd"

const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapRrmapParser := preload("res://scripts/map/rrmap/map_rrmap_parser.gd")
const MapTypes := preload("res://scripts/map/map_types.gd")
const MapVerification := preload("res://scripts/map/map_verification.gd")
const PropStyleVariants := preload("res://scripts/map/map_prop_style_variants.gd")

const CONTRACT_PATH := "res://docs/reports/merchant_cart_transport_contract.md"
const MAP_PATHS: Array[String] = [
	"res://content/maps/lower_town_slice.rrmap",
	"res://content/maps/north_quarter.rrmap",
	"res://content/maps/reval_harbor_east.rrmap",
	"res://content/maps/reval_harbor_north.rrmap",
]


func test_merchant_cart_corridors_have_authored_staging_props() -> void:
	var expected := {
		"res://content/maps/lower_town_slice.rrmap": {
			"vanaturg_cart_queue": PropStyleVariants.VEHICLE_CLASS_CART_2W,
			"gate_cart": PropStyleVariants.VEHICLE_CLASS_CART_2W,
			"viru_apron_grain_cart": PropStyleVariants.VEHICLE_CLASS_CART_2W,
		},
		"res://content/maps/north_quarter.rrmap": {
			"pikk_lai_delivery_cart": PropStyleVariants.VEHICLE_CLASS_CART_2W,
		},
		"res://content/maps/reval_harbor_east.rrmap": {
			"boatwright_cart": PropStyleVariants.VEHICLE_CLASS_CART_2W,
			"harbour_timber_wagon": PropStyleVariants.VEHICLE_CLASS_WAGON_4W,
		},
		"res://content/maps/reval_harbor_north.rrmap": {
			"quay_crane": PropStyleVariants.VEHICLE_CLASS_CART_2W,
			"coastal_gate_timber_wagon": PropStyleVariants.VEHICLE_CLASS_WAGON_4W,
		},
	}
	for path in MAP_PATHS:
		var parsed := MapRrmapParser.parse_file(path)
		assert_true(parsed.is_ok(), "%s must parse: %s" % [path, str(parsed.formatted_diagnostics())])
		if not parsed.is_ok():
			continue
		var definition: MapDefinition = parsed.definition
		var grid := MapBuilder.build(definition)
		var props := _props_by_id(definition)
		for prop_id in expected[path]:
			assert_true(props.has(prop_id), "%s is missing %s" % [path, prop_id])
			if not props.has(prop_id):
				continue
			var prop: Dictionary = props[prop_id]
			assert_eq(prop.get("kind"), MapTypes.PROP_KIND_CART, "%s must be a cart prop" % prop_id)
			assert_eq(prop.get("vehicle_class"), expected[path][prop_id], "%s has the wrong vehicle class" % prop_id)
			assert_true(
				MapVerification.is_walkable_point(definition, grid, prop["position"]),
				"cart staging must not block the authored route: %s" % prop_id
			)


func test_merchant_cart_corridors_keep_wagon_and_toll_rules_closed() -> void:
	var contract := _read_text(CONTRACT_PATH)
	for required in [
		"vanaturg_throat",
		"pikk_lai_delivery",
		"harbour_margin",
		"viru_apron",
		"wheel_rut_spacing",
		"1.3",
		"cart_path_width_min",
		"2.5",
	]:
		assert_true(required in contract, "transport contract must retain %s" % required)

	for path in MAP_PATHS:
		var parsed := MapRrmapParser.parse_file(path)
		assert_true(parsed.is_ok(), "%s must parse before corridor audit" % path)
		if not parsed.is_ok():
			continue
		var definition: MapDefinition = parsed.definition
		for prop in definition.props:
			var prop_id := String(prop.get("id", "")).to_lower()
			var prop_kind := String(prop.get("kind", "")).to_lower()
			assert_false("toll_booth" in prop_id or "toll_booth" in prop_kind, "invented toll booth: %s" % prop_id)
			assert_false("twin_cart" in prop_id or "twin_cart" in prop_kind, "twin-cart staging is forbidden: %s" % prop_id)
			if prop.get("vehicle_class", &"") != PropStyleVariants.VEHICLE_CLASS_WAGON_4W:
				continue
			assert_true(
				path in [
					"res://content/maps/reval_harbor_east.rrmap",
					"res://content/maps/reval_harbor_north.rrmap",
				],
				"wagon_4w is restricted to harbour margins: %s" % prop_id
			)


func _props_by_id(definition: MapDefinition) -> Dictionary:
	var result := {}
	for prop in definition.props:
		result[String(prop.get("id", ""))] = prop
	return result


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	assert_true(file != null, "missing contract: %s" % path)
	if file == null:
		return ""
	return file.get_as_text()
