extends "res://tests/godot/test_case.gd"

## WS-13d: timber landing decks stand on a log crib with guide piles down to the
## WS-13b rendered bed, all of it under the water surface and view only.

const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MeshConfig := preload("res://scripts/map/view3d/map_view_mesh_builder_config.gd")
const TerrainBuilder := preload("res://scripts/map/view3d/map_view_mesh_builder_terrain.gd")
const CribBuilder := preload("res://scripts/map/view3d/map_view_pier_crib_builder.gd")
const RevalHarborNorthDefinition := preload(
	"res://scripts/map/definitions/outdoor/reval_harbor_north_definition.gd"
)
const RevalHarborEastDefinition := preload(
	"res://scripts/map/definitions/outdoor/reval_harbor_east_definition.gd"
)
const DistantLocationDefinitions := preload(
	"res://scripts/map/definitions/outdoor/distant_location_definitions.gd"
)

## Synthetic sea as in test_ws13b_sea_basin_depth: deep rows 0-9, shallow rows 10-11,
## a grass bank from row 12, a timber pier at x 11-12 out to row 5 and a stone
## landing at x 3-4 out to row 8 (hard edge, no crib).
const SEA_SIZE := Vector2i(24, 16)
const PIER := Rect2i(11, 5, 2, 7)
const STONE := Rect2i(3, 8, 2, 4)
const SURFACE_Y := -MeshConfig.WATER_RECESS + MeshConfig.WATER_SURFACE_LIFT


func test_pier_face_drops_to_basin_depth_within_one_subvertex() -> void:
	var definition := _sea_definition()
	var field := TerrainBuilder.ensure_height_field(definition, MapBuilder.build(definition))
	var third := 1.0 / 3.0
	var off_pier := TerrainBuilder.basin_extra_depth(field, Vector2(PIER.position.x - third, 7.5))
	var off_stone := TerrainBuilder.basin_extra_depth(field, Vector2(STONE.position.x - third, 9.5))
	# Away from every deck the grass bank four cells south limits this row's depth.
	var open_basin := TerrainBuilder.basin_extra_depth(field, Vector2(PIER.position.x - 3.5, 7.5))
	assert_true(open_basin > 1.5, "the synthetic row must be deep (got %s)" % open_basin)
	assert_almost_eq(
		off_pier,
		open_basin,
		0.01,
		"one subvertex off a timber deck the bed must already reach the open basin depth",
	)
	assert_almost_eq(
		off_stone,
		third * MeshConfig.SEA_BASIN_HARD_SLOPE,
		0.02,
		"a stone landing keeps the WS-13b hard bank",
	)


func test_every_sea_facing_deck_edge_gets_a_crib_below_the_surface() -> void:
	var definition := _sea_definition()
	var field := TerrainBuilder.ensure_height_field(definition, MapBuilder.build(definition))
	var faces := CribBuilder.crib_faces(field)
	# West and east sides of rows 5-11 plus the two tip edges on row 5.
	assert_eq(faces.size(), PIER.size.y * 2 + PIER.size.x, "one crib face per sea-facing edge")
	for face: Dictionary in faces:
		var cell: Vector2i = face["cell"]
		assert_true(PIER.has_point(cell), "cribs must only clad timber decks, got %s" % cell)
		# Beside the shallow root the natural bank already limits the bed to ~1 unit.
		if float(face["floor_y"]) < -1.5:
			assert_true((face["logs"] as Array).size() >= 5, "a deep crib face stacks logs")
		for log_spec: Dictionary in face["logs"]:
			var top: float = (log_spec["from"] as Vector3).y + float(log_spec["radius"])
			assert_true(top < SURFACE_Y - 0.1, "crib logs must stay under the surface")
		for pile: Dictionary in face["piles"]:
			assert_true(
				(pile["to"] as Vector3).y < SURFACE_Y - 0.05,
				"pile heads must stay under the surface",
			)


## No rendered bank vertex may stand above a log in the upper half of a crib (well
## clear of the basin floor) further out than the log's deck-side flank: that would
## be bank earth in front of the crib.
func test_no_bank_vertex_overhangs_a_crib_log() -> void:
	var definition := _sea_definition()
	var field := TerrainBuilder.ensure_height_field(definition, MapBuilder.build(definition))
	var bed: PackedVector3Array = field["bed_positions"]
	var logs := 0
	for face: Dictionary in CribBuilder.crib_faces(field):
		var side: Vector2i = face["side"]
		var cell: Vector2i = face["cell"]
		var outward := Vector3(side.x, 0.0, side.y)
		var along := Vector3(absf(side.y), 0.0, absf(side.x))
		var edge := Vector3(cell.x, 0.0, cell.y) + Vector3(maxi(side.x, 0), 0.0, maxi(side.y, 0))
		var middle_y := (float(face["top_y"]) + float(face["floor_y"])) * 0.5
		for log_spec: Dictionary in face["logs"]:
			var from: Vector3 = log_spec["from"]
			if from.y < middle_y:
				continue
			logs += 1
			var radius: float = log_spec["radius"]
			var flank := (from - edge).dot(outward) - radius
			for vertex in bed:
				var along_t := (vertex - edge).dot(along)
				var out := (vertex - edge).dot(outward)
				if along_t < 0.0 or along_t > 1.0 or out > 1.0:
					continue
				assert_false(
					vertex.y > from.y + radius and out > flank + 0.001,
					"bank vertex %s stands in front of the crib log at %s" % [vertex, from],
				)
	assert_true(logs > 60, "the synthetic pier must stack many crib logs (got %d)" % logs)


func test_pile_feet_meet_the_rendered_bed() -> void:
	var definition := _sea_definition()
	var field := TerrainBuilder.ensure_height_field(definition, MapBuilder.build(definition))
	var piles := 0
	for face: Dictionary in CribBuilder.crib_faces(field):
		for pile: Dictionary in face["piles"]:
			piles += 1
			var foot: Vector3 = pile["from"]
			var bed_y := TerrainBuilder.view_bed_height(definition, Vector2(foot.x, foot.z))
			assert_almost_eq(
				foot.y,
				bed_y - MeshConfig.CRIB_BED_EMBED,
				0.06,
				"pile foot must be driven into the rendered bed at %s" % foot,
			)
	assert_true(piles >= PIER.size.y * 2, "every long pier face needs guide piles")


func test_terrain_builds_one_shadowless_crib_node_and_inland_maps_none() -> void:
	var definition := _sea_definition()
	var terrain := TerrainBuilder.build_terrain(definition, MapBuilder.build(definition))
	var cribs := terrain.get_node_or_null("PierCribs")
	assert_true(cribs != null, "a sea pier must build PierCribs")
	if cribs != null:
		for name in ["PierCribLogs", "PierCribPiles"]:
			var instance := cribs.get_node_or_null(name) as MeshInstance3D
			assert_true(instance != null and instance.mesh != null, "%s mesh" % name)
			if instance != null:
				assert_eq(
					instance.cast_shadow,
					GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
					"%s must not cast shadows" % name,
				)
				assert_true(
					instance.get_aabb().end.y < SURFACE_Y,
					"%s must stay under the water surface" % name,
				)
		var logs_mesh := cribs.get_node("PierCribLogs").mesh as ArrayMesh
		assert_true(
			logs_mesh != null and logs_mesh.get_surface_count() >= 2,
			"rubble must share the logs node as a second surface",
		)
	terrain.free()
	var pond := _sea_definition(MapTypes.TERRAIN_WATER, MapTypes.TERRAIN_WATER)
	var inland := TerrainBuilder.build_terrain(pond, MapBuilder.build(pond))
	assert_true(inland.get_node_or_null("PierCribs") == null, "flat-bed ponds get no crib")
	inland.free()


func test_harbor_north_landings_stand_on_cribs() -> void:
	var definition: MapDefinition = RevalHarborNorthDefinition.create()
	var field := TerrainBuilder.ensure_height_field(definition, MapBuilder.build(definition))
	var faces := CribBuilder.crib_faces(field)
	var west := 0
	var east := 0
	for face: Dictionary in faces:
		var cell: Vector2i = face["cell"]
		if cell.x >= 57 and cell.x <= 58:
			west += 1
		elif cell.x >= 113 and cell.x <= 114:
			east += 1
	assert_true(west >= 6, "pier.west must stand on crib faces (got %d)" % west)
	assert_true(east >= 6, "pier.east must stand on crib faces (got %d)" % east)


func test_tip_corners_use_saddle_notches() -> void:
	var definition := _sea_definition()
	var field := TerrainBuilder.ensure_height_field(definition, MapBuilder.build(definition))
	var notched := 0
	for face: Dictionary in CribBuilder.crib_faces(field):
		var cell: Vector2i = face["cell"]
		var side: Vector2i = face["side"]
		var west_tip := cell == PIER.position and (side == Vector2i.LEFT or side == Vector2i.UP)
		var east_tip := (
			cell == Vector2i(PIER.end.x - 1, PIER.position.y)
			and (side == Vector2i.RIGHT or side == Vector2i.UP)
		)
		if not west_tip and not east_tip:
			continue
		for log_spec: Dictionary in face["logs"]:
			assert_true(
				bool(log_spec["notch_from"]) or bool(log_spec["notch_to"]),
				"tip corner logs must use a saddle notch at %s %s" % [cell, side],
			)
			notched += 1
	assert_true(notched >= 8, "both tip corners must notch stacked logs (got %d)" % notched)


func test_crib_faces_carry_rubble_under_the_surface() -> void:
	var definition := _sea_definition()
	var field := TerrainBuilder.ensure_height_field(definition, MapBuilder.build(definition))
	var stones := 0
	for face: Dictionary in CribBuilder.crib_faces(field):
		if float(face["floor_y"]) < -1.5:
			assert_true(
				(face["rubble"] as Array).size() >= 2,
				"a deep crib face must show stone fill",
			)
		for stone: Dictionary in face["rubble"]:
			stones += 1
			var center: Vector3 = stone["center"]
			var half: Vector3 = stone["half"]
			assert_true(
				center.y + half.y < SURFACE_Y - 0.08,
				"rubble must stay under the surface at %s" % center,
			)
	assert_true(stones >= 16, "the synthetic pier must pack rubble (got %d)" % stones)


func test_harbor_east_and_saaremaa_landings_stand_on_cribs() -> void:
	var east_definition := RevalHarborEastDefinition.create()
	var east_faces := CribBuilder.crib_faces(
		TerrainBuilder.ensure_height_field(
			east_definition, MapBuilder.build(east_definition)
		)
	)
	var east_piers := {"west": 0, "mid": 0, "east": 0}
	var east_notches := 0
	var east_stones := 0
	for face: Dictionary in east_faces:
		var cell: Vector2i = face["cell"]
		if cell.x >= 26 and cell.x <= 27:
			east_piers["west"] = int(east_piers["west"]) + 1
		elif cell.x >= 64 and cell.x <= 65:
			east_piers["mid"] = int(east_piers["mid"]) + 1
		elif cell.x >= 111 and cell.x <= 112:
			east_piers["east"] = int(east_piers["east"]) + 1
		east_stones += (face["rubble"] as Array).size()
		for log_spec: Dictionary in face["logs"]:
			if bool(log_spec.get("notch_from", false)) or bool(log_spec.get("notch_to", false)):
				east_notches += 1
	assert_true(int(east_piers["west"]) >= 6, "pier.west on Harbor East")
	assert_true(int(east_piers["mid"]) >= 6, "pier.mid on Harbor East")
	assert_true(int(east_piers["east"]) >= 6, "pier.east on Harbor East")
	assert_true(east_notches >= 8, "Harbor East tip corners must notch")
	assert_true(east_stones >= 20, "Harbor East cribs must show fill")
	var saaremaa := DistantLocationDefinitions.create(&"world_saaremaa")
	assert_true(saaremaa != null, "world_saaremaa definition")
	var island_faces := CribBuilder.crib_faces(
		TerrainBuilder.ensure_height_field(saaremaa, MapBuilder.build(saaremaa))
	)
	var ferry := 0
	var strait := 0
	var island_stones := 0
	for face: Dictionary in island_faces:
		var cell: Vector2i = face["cell"]
		if cell.y >= 24 and cell.y <= 25:
			ferry += 1
		elif cell.y >= 36 and cell.y <= 37:
			strait += 1
		island_stones += (face["rubble"] as Array).size()
	assert_true(ferry >= 6, "pier.ferry on Saaremaa (got %d)" % ferry)
	assert_true(strait >= 6, "pier.strait on Saaremaa (got %d)" % strait)
	assert_true(island_stones >= 16, "Saaremaa cribs must show fill")


func _sea_definition(
	deep: StringName = MapTypes.TERRAIN_DEEP_WATER,
	shallow: StringName = MapTypes.TERRAIN_SHALLOW_WATER
) -> MapDefinition:
	var definition := MapDefinition.new()
	definition.map_id = &"test_ws13d_pier_cribs_%s" % String(deep)
	definition.size_cells = SEA_SIZE
	definition.base_terrain = MapTypes.TERRAIN_GRASS
	definition.seed = 1343
	definition.player_spawn = Vector2(0.5, 15.5)
	definition.location = &"test"
	definition.scope = &"prototype"
	definition.palette = &"spring"
	definition.fingerprint = "test-ws13d-pier-cribs-%s" % String(deep)
	definition.zones = [
		{"rect": Rect2i(0, 0, SEA_SIZE.x, 10), "terrain": deep},
		{"rect": Rect2i(0, 10, SEA_SIZE.x, 2), "terrain": shallow},
		{"rect": PIER, "terrain": MapTypes.TERRAIN_TIMBER_FLOOR},
		{"rect": STONE, "terrain": MapTypes.TERRAIN_STONE},
	]
	return definition
