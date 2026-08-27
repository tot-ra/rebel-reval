extends "res://tests/godot/test_case.gd"

const RentenitornDefinition := preload(
	"res://scripts/map/definitions/prototypes/rentenitorn_interior_definition.gd"
)
const RentenitornFactory := preload(
	"res://scripts/map/definitions/prototypes/rentenitorn_interior_rrmap_factory.gd"
)
const EnterableTowerContract := preload("res://scripts/tower/enterable_tower_contract.gd")

const SOURCE_PATH := "res://content/maps/rentenitorn_interior.rrmap"
const REQUIRED_ANCHORS: Array[StringName] = [
	&"rentenitorn_interior_entry",
	&"rentenitorn_floor_ground",
	&"rentenitorn_floor_watch",
	&"rentenitorn_floor_roof",
	&"rentenitorn_wall_walk",
	&"rentenitorn_wall_walk_entry",
	&"rentenitorn_boss",
	&"rentenitorn_boss_alternate_resolution",
	&"rentenitorn_loot",
	&"rentenitorn_evidence",
]


func test_rentenitorn_map_reaches_every_band_and_the_wall_walk() -> void:
	var parsed := MapRrmapParser.parse_file(SOURCE_PATH)
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	var definition: MapDefinition = RentenitornDefinition.create()
	var blueprint: MapBlueprint = RentenitornFactory.create()
	assert_eq(definition.map_id, &"rentenitorn_interior")
	assert_eq(blueprint.map_id, &"rentenitorn_interior")
	assert_false(definition.active, "Rentenitorn remains developer-only pending human sign-off")
	assert_eq(definition.size_cells, Vector2i(18, 18))
	assert_eq(definition.get_meta("player_spawn_id"), &"spawn.rentenitorn_interior_entry")

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
			"Rentenitorn anchor %s must be reachable" % anchor_id,
		)


## The Rent Tower is authored as a lockable closed tower, so the shell must stay
## sealed apart from the south city door and the west wall-walk door. A missing
## side would silently turn it into another open-backed Nunnatorn copy.
func test_closed_shell_keeps_only_the_two_authored_doors() -> void:
	var definition: MapDefinition = RentenitornDefinition.create()
	# Walls that declare openings are compiled into "<id>/segment.NNN" pieces, so
	# count segments per authored wall instead of matching the bare id.
	var segments_by_wall: Dictionary = {}
	for building in definition.buildings:
		var base_id := String(building.get("id", "")).split("/")[0]
		segments_by_wall[base_id] = int(segments_by_wall.get(base_id, 0)) + 1
	for required_wall in [
		"shell.west", "shell.north", "shell.east",
		"shell.south_west", "shell.south_east",
		"floor.partition.strongroom", "floor.partition.counting",
	]:
		assert_true(segments_by_wall.has(required_wall), "closed shell needs %s" % required_wall)
	# The wall-walk door is the only break in the west face; the south door is the
	# gap authored between the two south returns.
	assert_eq(segments_by_wall.get("shell.west", 0), 2, "west face carries exactly one door")
	assert_eq(segments_by_wall.get("shell.north", 0), 1, "north face must stay unbroken")
	assert_eq(segments_by_wall.get("shell.east", 0), 1, "east face must stay unbroken")

	var contract := RentenitornDefinition.enterable_tower_contract()
	assert_eq(EnterableTowerContract.validate(contract), [])
	assert_eq(contract["floors"].size(), 3)
	assert_eq(contract["wall_walk_route"]["entry_anchor"], "rentenitorn_wall_walk_entry")
	assert_eq(contract["exterior_map_id"], "north_quarter")
	assert_eq(contract["exterior_building_id"], "merchant_wall_tower_northwest")


func test_rentenitorn_rrmap_is_canonical_and_catalogued_developer_only() -> void:
	var parsed := MapRrmapParser.parse_file(SOURCE_PATH)
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	var canonical := MapRrmapParser.canonical_print(parsed.blueprint)
	var reparsed := MapRrmapParser.parse(canonical, "res://rentenitorn.canonical.rrmap")
	assert_true(reparsed.is_ok(), str(reparsed.formatted_diagnostics()))
	if reparsed.is_ok():
		assert_eq(MapRrmapParser.canonical_print(reparsed.blueprint), canonical)
	var catalog := MapCatalog.get_map(&"rentenitorn_interior")
	assert_eq(catalog["path"], "res://scenes/reval_north/rentenitorn_interior.tscn")
	assert_false(catalog["active"])
