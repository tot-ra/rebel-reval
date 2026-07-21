extends "res://tests/godot/test_case.gd"

const ToompeaQuarter := preload("res://scripts/map/definitions/prototypes/toompea_quarter_definition.gd")
const SouthQuarter := preload("res://scripts/map/definitions/prototypes/south_quarter_definition.gd")
const MerchantBoatBuilder := preload("res://scripts/map/view3d/map_view_merchant_boat_builder.gd")


func test_faction_heraldry_patterns_and_vitalien_fly_no_flag() -> void:
	assert_eq(FactionHeraldry.pattern_for(FactionHeraldry.DANISH_CROWN), FactionHeraldry.PATTERN_CROSS)
	assert_eq(FactionHeraldry.pattern_for(FactionHeraldry.LIVONIAN_ORDER), FactionHeraldry.PATTERN_CROSS)
	assert_eq(FactionHeraldry.pattern_for(FactionHeraldry.HANSEATIC), FactionHeraldry.PATTERN_PALE)
	assert_eq(FactionHeraldry.pattern_for(FactionHeraldry.NOVGOROD), FactionHeraldry.PATTERN_BEAR)
	assert_eq(FactionHeraldry.pattern_for(FactionHeraldry.PSKOV), FactionHeraldry.PATTERN_LYNX)
	assert_eq(FactionHeraldry.pattern_for(FactionHeraldry.BLACK_CLOAKS), FactionHeraldry.PATTERN_SWALLOW)
	assert_eq(FactionHeraldry.pattern_for(FactionHeraldry.PSKOV_NOVGOROD), FactionHeraldry.PATTERN_BEAR_LYNX)
	assert_false(FactionHeraldry.shows_flag(FactionHeraldry.VITALIENBRUDER))
	var danish_field := FactionHeraldry.color_at(FactionHeraldry.DANISH_CROWN, Vector2(0.9, 0.15))
	var danish_cross := FactionHeraldry.color_at(FactionHeraldry.DANISH_CROWN, Vector2(0.36, 0.5))
	assert_true(
		danish_field.is_equal_approx(FactionHeraldry.field_color(FactionHeraldry.DANISH_CROWN)),
		"Danish fly must stay the red field"
	)
	assert_true(
		danish_cross.is_equal_approx(FactionHeraldry.charge_color(FactionHeraldry.DANISH_CROWN)),
		"Danish hoist arm must stay the white cross"
	)
	assert_true(
		FactionHeraldry.color_at(FactionHeraldry.NOVGOROD, Vector2(0.46, 0.58)).is_equal_approx(
			FactionHeraldry.charge_color(FactionHeraldry.NOVGOROD)
		),
		"Novgorod body UV must hit the black bear charge from the logo"
	)
	assert_true(
		FactionHeraldry.color_at(FactionHeraldry.PSKOV, Vector2(0.66, 0.34)).is_equal_approx(
			FactionHeraldry.charge_color(FactionHeraldry.PSKOV)
		),
		"Pskov head UV must hit the gold lynx charge from the logo"
	)
	assert_true(
		FactionHeraldry.color_at(FactionHeraldry.BLACK_CLOAKS, Vector2(0.48, 0.48)).is_equal_approx(
			FactionHeraldry.charge_color(FactionHeraldry.BLACK_CLOAKS)
		),
		"Black Cloaks body UV must hit the dark swallow charge from the logo"
	)
	assert_true(
		FactionHeraldry.color_at(FactionHeraldry.BLACK_CLOAKS, Vector2(0.08, 0.08)).is_equal_approx(
			FactionHeraldry.field_color(FactionHeraldry.BLACK_CLOAKS)
		),
		"Black Cloaks corner UV must stay the logo white field"
	)
	assert_true(
		FactionHeraldry.color_at(FactionHeraldry.NOVGOROD, Vector2(0.08, 0.08)).is_equal_approx(
			FactionHeraldry.field_color(FactionHeraldry.NOVGOROD)
		),
		"Novgorod corner UV must stay the azure field"
	)
	# Joint east cloth: lynx in front (gold), bear behind (black), matching logo BR.
	assert_true(
		FactionHeraldry.color_at(FactionHeraldry.PSKOV_NOVGOROD, Vector2(0.70, 0.32)).is_equal_approx(
			FactionHeraldry.charge_color(FactionHeraldry.PSKOV_NOVGOROD)
		),
		"Joint cloth lynx UV must stay gold"
	)
	assert_true(
		FactionHeraldry.color_at(FactionHeraldry.PSKOV_NOVGOROD, Vector2(0.34, 0.70)).is_equal_approx(
			FactionHeraldry.secondary_charge_color(FactionHeraldry.PSKOV_NOVGOROD)
		),
		"Joint cloth bear UV must stay black behind the lynx"
	)


func test_rrmap_faction_compiles_onto_towers_and_banners() -> void:
	var source := """rrmap 1
map heraldry loc.heraldry 16 12 grass
style wall.tower wall_height=240 wall_color=8c8a80ff faction=danish_crown
building keep wall 2 2 4 4 style=wall.tower tower=true door_side=south
prop crown_banner banner 8 6 rect=2,2 faction=danish_crown
prop order_banner banner 11 6 rect=2,2 faction=livonian_order
spawn spawn.main 6 8
"""
	var parsed := MapRrmapParser.parse(source, "res://heraldry.rrmap")
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	var keep: Dictionary = parsed.definition.buildings[0]
	assert_eq(keep.get("faction"), FactionHeraldry.DANISH_CROWN)
	var banner_factions: Dictionary = {}
	for prop in parsed.definition.props:
		banner_factions[prop["id"]] = prop.get("faction")
	assert_eq(banner_factions[&"crown_banner"], FactionHeraldry.DANISH_CROWN)
	assert_eq(banner_factions[&"order_banner"], FactionHeraldry.LIVONIAN_ORDER)


func test_toompea_castle_tower_flies_danish_pennant() -> void:
	var definition := ToompeaQuarter.create()
	var keep: Dictionary = {}
	for building in definition.buildings:
		if building["id"] == &"castle_keep_tower":
			keep = building
			break
	assert_false(keep.is_empty(), "Toompea must keep castle_keep_tower")
	assert_eq(FactionHeraldry.resolve(keep), FactionHeraldry.DANISH_CROWN)
	var node := MapViewMeshBuilder.build_building(keep, definition.cell_size)
	assert_true(node.has_node("Pennant"), "Danish keep needs a roof pennant")
	var pennant := node.get_node("Pennant") as MeshInstance3D
	assert_eq(pennant.get_meta(&"faction"), FactionHeraldry.DANISH_CROWN)
	assert_true(pennant.material_override is ShaderMaterial)
	node.free()


func test_south_quarter_knight_banner_is_livonian_cloth() -> void:
	var definition := SouthQuarter.create()
	var banner: Dictionary = {}
	for prop in definition.props:
		if prop["id"] == &"knights_hall_banner":
			banner = prop
			break
	assert_false(banner.is_empty(), "south quarter needs knights_hall_banner on the hall")
	assert_eq(banner.get("kind"), MapTypes.PROP_KIND_BANNER)
	assert_eq(FactionHeraldry.resolve(banner), FactionHeraldry.LIVONIAN_ORDER)
	var node := MapViewMeshBuilder.build_prop(banner, definition.cell_size, definition)
	assert_true(node.has_node("BannerCloth"))
	assert_true(node.has_node("BannerArm"), "courtyard banners hang from a wall arm, not a freestanding mast")
	assert_false(node.has_node("BannerStaff"), "freestanding banner masts were removed as empty-pole clutter")
	assert_eq(node.get_node("BannerCloth").get_meta(&"faction"), FactionHeraldry.LIVONIAN_ORDER)
	node.free()


func test_ordinary_wall_towers_do_not_fly_pennants_without_faction() -> void:
	# Garden mid-wall towers used to inherit style faction=danish_crown and fill
	# the skyline with poles. Unmarked wall.tower must stay bare.
	var building := {
		"id": &"garden_wall_tower_south_mid",
		"kind": MapTypes.BUILDING_KIND_WALL,
		"footprint": Rect2(0, 0, 64, 64),
		"tower": true,
		"door_side": &"north",
		"wall_height": 240.0,
	}
	assert_eq(FactionHeraldry.resolve(building), &"")
	assert_false(FactionHeraldry.shows_flag(&""))
	var node := MapViewMeshBuilder.build_building(building, 32.0)
	assert_true(node.has_node("TowerRoof"))
	assert_false(node.has_node("Pennant"), "unmarked wall towers must not sprout pennant staffs")
	assert_false(node.has_node("PennantStaff"))
	node.free()


func test_house_bargeboards_are_flat_boards_not_stick_poles() -> void:
	var building := {
		"id": &"artisan_house",
		"kind": MapTypes.BUILDING_KIND_HOUSE,
		"footprint": Rect2(0, 0, 96, 64),
		"wall_height": 96.0,
		"wall_material": &"plank",
		"roof_material": &"shingle",
		"door_side": &"south",
		"ridge_axis": &"x",
	}
	var node := MapViewMeshBuilder.build_building(building, 32.0)
	assert_true(node.has_node("Bargeboard_1_1"), "tiled roofs keep bargeboards")
	var board := node.get_node("Bargeboard_1_1") as MeshInstance3D
	var mesh := board.mesh as BoxMesh
	var size := mesh.size
	var cross_min := minf(size.x, minf(size.y, size.z))
	var cross_mid := size.x + size.y + size.z - maxf(size.x, maxf(size.y, size.z)) - cross_min
	assert_true(
		cross_mid > cross_min * 2.5,
		"bargeboard face must be much wider than thickness so it reads as a board, not a pole"
	)
	node.free()


func test_merchant_cog_flies_hanseatic_masthead_pennant() -> void:
	var root := Node3D.new()
	MerchantBoatBuilder.add_to(root, FactionHeraldry.HANSEATIC)
	assert_true(root.has_node("MastheadPennant"), "Hanse cogs need a masthead identity cloth")
	assert_eq(root.get_node("MastheadPennant").get_meta(&"faction"), FactionHeraldry.HANSEATIC)
	root.free()


func test_market_eastern_trade_banners_use_animal_charges() -> void:
	var source := FileAccess.get_file_as_string("res://content/maps/market_civic_quarter.rrmap")
	var parsed := MapRrmapParser.parse(source, "res://content/maps/market_civic_quarter.rrmap")
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	var by_id: Dictionary = {}
	for prop in parsed.definition.props:
		by_id[prop["id"]] = prop
	assert_eq(by_id[&"novgorod_trade_banner"].get("faction"), FactionHeraldry.NOVGOROD)
	assert_eq(by_id[&"pskov_trade_banner"].get("faction"), FactionHeraldry.PSKOV)
	var novgorod := MapViewMeshBuilder.build_prop(by_id[&"novgorod_trade_banner"], parsed.definition.cell_size, parsed.definition)
	var pskov := MapViewMeshBuilder.build_prop(by_id[&"pskov_trade_banner"], parsed.definition.cell_size, parsed.definition)
	assert_eq(novgorod.get_node("BannerCloth").get_meta(&"faction"), FactionHeraldry.NOVGOROD)
	assert_eq(pskov.get_node("BannerCloth").get_meta(&"faction"), FactionHeraldry.PSKOV)
	novgorod.free()
	pskov.free()


func test_forge_cloak_banner_flies_swallow_cloth() -> void:
	var source := FileAccess.get_file_as_string("res://content/maps/kalev_smithy.rrmap")
	var parsed := MapRrmapParser.parse(source, "res://content/maps/kalev_smithy.rrmap")
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	var banner: Dictionary = {}
	for prop in parsed.definition.props:
		if prop["id"] == &"cloak_banner":
			banner = prop
			break
	assert_false(banner.is_empty(), "forge needs cloak_banner")
	assert_eq(FactionHeraldry.resolve(banner), FactionHeraldry.BLACK_CLOAKS)
	assert_eq(FactionHeraldry.pattern_for(FactionHeraldry.BLACK_CLOAKS), FactionHeraldry.PATTERN_SWALLOW)
	var node := MapViewMeshBuilder.build_prop(banner, parsed.definition.cell_size, parsed.definition)
	assert_eq(node.get_node("BannerCloth").get_meta(&"faction"), FactionHeraldry.BLACK_CLOAKS)
	node.free()


func test_unknown_faction_fails_map_validation() -> void:
	var definition := MapDefinition.new()
	definition.map_id = &"bad_faction"
	definition.size_cells = Vector2i(8, 8)
	definition.cell_size = 32
	definition.buildings = [{
		"id": &"tower",
		"kind": MapTypes.BUILDING_KIND_WALL,
		"footprint": Rect2(32, 32, 64, 64),
		"tower": true,
		"door_side": &"south",
		"wall_height": 240.0,
		"faction": &"not_a_faction",
	}]
	var errors := definition.validate()
	assert_true(_contains(errors, "faction is unknown"), "unknown faction ids must fail validation")


func _contains(errors: Array[String], needle: String) -> bool:
	for error in errors:
		if needle in error:
			return true
	return false
