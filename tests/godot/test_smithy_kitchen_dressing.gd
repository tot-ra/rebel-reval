extends "res://tests/godot/test_case.gd"

## Guards the living-bay kitchen tidy-up: fixtures must open into the room, wall
## hangings must sit on plaster, and small kitchen items must ride a surface.
##
## WHY: one cell is one metre and the kits are 0.1-1.6 m, so the earlier
## authoring on 2x2 and 3x3 zone footprints put a 1.0 m hearth mid-corner facing
## its own back wall, hung the Black Cloak banner in open air, and dropped every
## bowl, loaf, and crock on bare boards at y = 0.

const KalevSmithyDefinition := preload("res://scripts/map/definitions/lower_town/kalev_smithy_definition.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapTypes := preload("res://scripts/map/map_types.gd")
const MapVerification := preload("res://scripts/map/map_verification.gd")
const PropModels := preload("res://scripts/map/view3d/map_view_mesh_builder_prop_models.gd")

const DOMESTIC_FIXTURE_PATH := "res://tests/fixtures/maps/kalev_smithy_domestic_life.json"
const CARDINALS: Dictionary = {
	"north": Vector2(0.0, -1.0),
	"east": Vector2(1.0, 0.0),
	"south": Vector2(0.0, 1.0),
	"west": Vector2(-1.0, 0.0),
}


func test_prop_facing_yaw_turns_model_front_onto_authored_cardinal() -> void:
	# Kits front toward -Z, so an unturned prop keeps zero yaw and a north-wall
	# fixture asked to look south is a half turn.
	assert_eq(MapTypes.prop_facing_yaw({"kind": MapTypes.PROP_KIND_HEARTH}), 0.0)
	for expected: Array in [
		[&"north", 0.0],
		[&"south", PI],
		[&"east", -PI * 0.5],
		[&"west", PI * 0.5],
	]:
		var yaw := MapTypes.prop_facing_yaw({
			"kind": MapTypes.PROP_KIND_HEARTH,
			"facing": CARDINALS[String(expected[0])],
		})
		assert_true(
			is_equal_approx(wrapf(yaw, -PI, PI), wrapf(float(expected[1]), -PI, PI)),
			"hearth facing=%s should yaw %f, got %f" % [String(expected[0]), float(expected[1]), yaw]
		)
	# The banner kit faces +X, so east is its identity turn.
	assert_eq(
		MapTypes.prop_facing_yaw({"kind": MapTypes.PROP_KIND_BANNER, "facing": Vector2(1.0, 0.0)}),
		0.0
	)
	# Scatter kinds stay outside the allowlist so shipped maps cannot change
	# silhouette by inheriting a facing value meant for something else.
	assert_eq(
		MapTypes.prop_facing_yaw({"kind": MapTypes.PROP_KIND_CHARCOAL_PILE, "facing": Vector2(0.0, 1.0)}),
		0.0
	)


func test_authored_facing_reaches_the_built_prop_node() -> void:
	var definition: MapDefinition = KalevSmithyDefinition.create()
	var hearth := _prop_by_id(definition, &"domestic_hearth")
	assert_false(hearth.is_empty(), "domestic_hearth must exist")
	assert_eq(Vector2(hearth.get("facing", Vector2.ZERO)), Vector2(0.0, 1.0))
	var root := PropModels.build_prop(hearth, definition.cell_size, definition)
	assert_true(
		is_equal_approx(absf(wrapf(root.rotation.y, -PI, PI)), PI),
		"Hearth mouth must be turned off the north wall, yaw was %f" % root.rotation.y
	)
	root.free()


func test_domestic_fixtures_face_the_room_not_the_plaster() -> void:
	var definition: MapDefinition = KalevSmithyDefinition.create()
	var fixture := _load_fixture()
	for entry: Dictionary in fixture.get("required_domestic_props", []):
		if not entry.has("facing"):
			continue
		var prop_id := StringName(str(entry["id"]))
		var prop := _prop_by_id(definition, prop_id)
		assert_false(prop.is_empty(), "Missing prop %s" % String(prop_id))
		assert_eq(
			Vector2(prop.get("facing", Vector2.ZERO)),
			Vector2(CARDINALS[str(entry["facing"])]),
			"%s must be authored facing %s" % [String(prop_id), str(entry["facing"])]
		)


func test_small_kitchen_items_ride_a_surface_instead_of_the_floor() -> void:
	var definition: MapDefinition = KalevSmithyDefinition.create()
	var fixture := _load_fixture()
	var mounted: Array = fixture.get("surface_mounted_props", [])
	assert_false(mounted.is_empty(), "Fixture must list surface-mounted props")
	for prop_id_text: String in mounted:
		var prop := _prop_by_id(definition, StringName(prop_id_text))
		assert_false(prop.is_empty(), "Missing prop %s" % prop_id_text)
		assert_true(prop.has("visual_offset_px"), "%s must declare a lift" % prop_id_text)
		var offset := Vector2(prop["visual_offset_px"])
		# visual_offset_px y is screen-down, so the view bridge subtracts it:
		# a negative value is the only way to raise a prop off the boards.
		assert_true(
			offset.y < 0.0,
			"%s must be lifted onto its surface, offset was %s" % [prop_id_text, str(offset)]
		)


func test_meal_approach_cells_stay_clear_of_props() -> void:
	# Prop footprints do not feed navigation, so nothing stops an author from
	# seating a stool on the cell an eat/clear beat stands in. These cells south
	# of the eating board are reserved so the actor is never inside furniture.
	var definition: MapDefinition = KalevSmithyDefinition.create()
	var fixture := _load_fixture()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	for cell_entry: Dictionary in fixture.get("meal_approach_cells", []):
		var cell := Vector2i(int(cell_entry["x"]), int(cell_entry["y"]))
		assert_true(
			MapVerification.is_walkable_cell(definition, grid, cell),
			"Routine approach cell %s must stay walkable after kitchen dressing" % str(cell)
		)
		var cell_rect := definition.cell_rect_to_world_rect(Rect2i(cell, Vector2i.ONE))
		for prop: Dictionary in definition.props:
			if not prop.has("footprint"):
				continue
			assert_false(
				(prop["footprint"] as Rect2).intersects(cell_rect),
				"%s footprint covers meal approach cell %s" % [String(prop.get("id", &"")), str(cell)]
			)


func test_kitchen_range_uses_authored_furniture_kits() -> void:
	var definition: MapDefinition = KalevSmithyDefinition.create()
	# The kitchen must answer "what did they cook on": a trestle bench beside the
	# fire, a cupboard for dry stores, and a hand-wash stand rather than a tub.
	var bench := _prop_by_id(definition, &"kitchen_work_table")
	assert_eq(bench.get("kind"), MapTypes.PROP_KIND_TABLE)
	assert_eq(bench.get("style_variant"), &"table.trestle_work")
	var dresser := _prop_by_id(definition, &"kitchen_dresser")
	assert_eq(dresser.get("kind"), MapTypes.PROP_KIND_SHELF)
	assert_eq(dresser.get("style_variant"), &"shelf.burgher_cupboard")
	var wash := _prop_by_id(definition, &"wash_basin")
	assert_eq(wash.get("style_variant"), MapTypes.WASH_STAND_BASIN)
	# Seating uses the one authored chair GLB, never the neutral box fallback.
	for stool_id in [&"kitchen_stool", &"table_stool_west", &"table_stool_east", &"work_chair"]:
		var stool := _prop_by_id(definition, stool_id)
		assert_eq(stool.get("kind"), MapTypes.PROP_KIND_CHAIR, "%s must be a chair" % String(stool_id))
		assert_true(
			stool_id in PropModels.SMITHY_CHAIR_PROP_IDS,
			"%s must resolve to the authored smithy chair" % String(stool_id)
		)


func test_wash_stand_basin_builds_a_stand_and_sinks_its_water() -> void:
	var definition: MapDefinition = KalevSmithyDefinition.create()
	var wash := _prop_by_id(definition, &"wash_basin")
	var root := PropModels.build_prop(wash, definition.cell_size, definition)
	for part_name in ["StandTop", "Basin", "BasinRim", "EwerBody", "TowelRail"]:
		assert_true(root.find_child(part_name, true, false) != null, "Wash stand needs %s" % part_name)
	var water := root.find_child("BasinWater", true, false) as MeshInstance3D
	var rim := root.find_child("BasinRim", true, false) as MeshInstance3D
	assert_true(water != null and rim != null)
	if water != null and rim != null:
		# The yard tub's flat disc level with its rim is what read as a stray
		# puddle; indoor water must sit inside the bowl.
		assert_true(
			water.position.y < rim.position.y,
			"Basin water must sit below the rim (%f vs %f)" % [water.position.y, rim.position.y]
		)
	root.free()


func _load_fixture() -> Dictionary:
	var file := FileAccess.open(DOMESTIC_FIXTURE_PATH, FileAccess.READ)
	assert_true(file != null, "Domestic-life fixture must exist")
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	assert_true(parsed is Dictionary, "Domestic-life fixture must be JSON object")
	return parsed


func _prop_by_id(definition: MapDefinition, prop_id: StringName) -> Dictionary:
	for prop in definition.props:
		if prop.get("id", &"") == prop_id:
			return prop
	return {}
