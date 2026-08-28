extends "res://tests/godot/test_case.gd"

const KuldjalaDefinition := preload(
	"res://scripts/map/definitions/prototypes/kuldjala_interior_definition.gd"
)
const KuldjalaFactory := preload(
	"res://scripts/map/definitions/prototypes/kuldjala_interior_rrmap_factory.gd"
)
const EnterableTowerContract := preload("res://scripts/tower/enterable_tower_contract.gd")

const SOURCE_PATH := "res://content/maps/kuldjala_interior.rrmap"
const REQUIRED_ANCHORS: Array[StringName] = [
	&"kuldjala_interior_entry",
	&"kuldjala_floor_ground",
	&"kuldjala_floor_watch",
	&"kuldjala_floor_roof",
	&"kuldjala_wall_walk",
	&"kuldjala_wall_walk_entry",
	&"kuldjala_boss",
	&"kuldjala_boss_alternate_resolution",
	&"kuldjala_loot",
	&"kuldjala_evidence",
]


func test_kuldjala_map_has_reachable_two_chambers_and_wall_walk() -> void:
	var parsed := MapRrmapParser.parse_file(SOURCE_PATH)
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	var definition: MapDefinition = KuldjalaDefinition.create()
	var blueprint: MapBlueprint = KuldjalaFactory.create()
	assert_eq(definition.map_id, &"kuldjala_interior")
	assert_eq(blueprint.map_id, &"kuldjala_interior")
	assert_false(definition.active, "Kuldjala remains developer-only pending human sign-off")
	assert_eq(definition.size_cells, Vector2i(18, 16))
	assert_eq(definition.get_meta("player_spawn_id"), &"spawn.kuldjala_interior_entry")

	var grid := MapBuilder.build(definition)
	for anchor_id in REQUIRED_ANCHORS:
		assert_true(MapVerification.has_anchor(definition, anchor_id), "missing %s" % anchor_id)
		assert_true(
			MapVerification.route_exists_exact(
				definition,
				grid,
				definition.player_spawn,
				MapVerification.anchor_position(definition, anchor_id),
			),
			"Kuldjala anchor %s must be reachable" % anchor_id,
		)

	var wall_ids: Array[String] = []
	for building in definition.buildings:
		wall_ids.append(String(building.get("id", "")))
	for required_wall in [
		"shell.west", "shell.north_arc", "shell.north_return",
		"shell.south_arc", "shell.south_return",
	]:
		assert_true(wall_ids.has(required_wall), "horseshoe shell needs %s" % required_wall)
	assert_false(wall_ids.has("shell.east"), "city-facing horseshoe opening must stay open")

	var contract := KuldjalaDefinition.enterable_tower_contract()
	assert_eq(EnterableTowerContract.validate(contract), [])
	assert_eq(contract["floors"].size(), 3)
	assert_eq(contract["wall_walk_route"]["entry_anchor"], "kuldjala_wall_walk_entry")


func test_kuldjala_rrmap_is_canonical_and_scene_is_catalogued_developer_only() -> void:
	var parsed := MapRrmapParser.parse_file(SOURCE_PATH)
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	var canonical := MapRrmapParser.canonical_print(parsed.blueprint)
	var reparsed := MapRrmapParser.parse(canonical, "res://kuldjala.canonical.rrmap")
	assert_true(reparsed.is_ok(), str(reparsed.formatted_diagnostics()))
	if reparsed.is_ok():
		assert_eq(MapRrmapParser.canonical_print(reparsed.blueprint), canonical)
	var catalog := MapCatalog.get_map(&"kuldjala_interior")
	assert_eq(catalog["path"], "res://scenes/reval_monastery/kuldjala_interior.tscn")
	assert_false(catalog["active"])
