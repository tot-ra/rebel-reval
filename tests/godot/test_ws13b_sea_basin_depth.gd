extends "res://tests/godot/test_case.gd"

## WS-13b: open-sea cells get a real rendered basin under the flat gameplay bed.

const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MeshConfig := preload("res://scripts/map/view3d/map_view_mesh_builder_config.gd")
const TerrainBuilder := preload("res://scripts/map/view3d/map_view_mesh_builder_terrain.gd")
const RevalHarborNorthDefinition := preload(
	"res://scripts/map/definitions/outdoor/reval_harbor_north_definition.gd"
)
const WATER_SHADER_PATH := "res://scripts/map/view3d/map_view_water.gdshader"

## Synthetic sea: deep rows 0-9, shallow rows 10-11, a grass bank from row 12 and a
## timber pier (hard edge) at x 11-12 running out to row 5.
const SEA_SIZE := Vector2i(24, 16)
const PIER := Rect2i(11, 5, 2, 7)


func test_open_sea_bed_drops_while_the_gameplay_bed_stays_flat() -> void:
	var definition := _sea_definition()
	var grid := MapBuilder.build(definition)
	TerrainBuilder.build_terrain(definition, grid).free()
	var deep_point := Vector2(4.5, 2.5)
	assert_almost_eq(
		TerrainBuilder.view_bed_height(definition, deep_point),
		-MeshConfig.WATER_RECESS - float(MeshConfig.SEA_BASIN_DEPTH[MapTypes.TERRAIN_DEEP_WATER]),
		0.001,
		"deep sea away from every bank must reach the full basin depth",
	)
	assert_almost_eq(
		TerrainBuilder.ground_height(definition, deep_point),
		-MeshConfig.WATER_RECESS,
		0.0001,
		"gameplay ground height must keep the flat recessed bed",
	)
	var shallow := TerrainBuilder.view_bed_height(definition, Vector2(4.5, 10.5))
	assert_true(
		shallow > TerrainBuilder.view_bed_height(definition, deep_point) + 1.0,
		"shallow water must stay far shallower than the deep basin (got %s)" % shallow,
	)


func test_waterline_vertices_keep_their_flat_bed_position_and_normal() -> void:
	var definition := _sea_definition()
	var grid := MapBuilder.build(definition)
	var field := TerrainBuilder.ensure_height_field(definition, grid)
	var positions: PackedVector3Array = field["positions"]
	var normals: PackedVector3Array = field["normals"]
	var bed: PackedVector3Array = field["bed_positions"]
	var bed_normals: PackedVector3Array = field["bed_normals"]
	var columns: int = field["vertex_columns"]
	var waterline := 0
	var deepened := 0
	for index in positions.size():
		var vx := index % columns
		var vy := index / columns
		if TerrainBuilder.subvertex_touches_dry(field, vx, vy):
			if TerrainBuilder.subvertex_touches_water(field, vx, vy):
				waterline += 1
			assert_eq(bed[index], positions[index], "dry or waterline vertex %d must not move" % index)
			assert_eq(bed_normals[index], normals[index], "waterline normal %d must not change" % index)
		elif bed[index].y < positions[index].y - 0.01:
			deepened += 1
	assert_true(waterline > 0, "the synthetic sea must have a waterline")
	assert_true(deepened > 0, "open sea vertices must deepen")


func test_hard_edges_drop_faster_than_natural_banks() -> void:
	var definition := _sea_definition()
	var grid := MapBuilder.build(definition)
	var field := TerrainBuilder.ensure_height_field(definition, grid)
	var third := 1.0 / 3.0
	var off_pier := TerrainBuilder.basin_extra_depth(field, Vector2(PIER.position.x - third, 8.5))
	var off_beach := TerrainBuilder.basin_extra_depth(field, Vector2(4.5, 12.0 - third))
	assert_almost_eq(
		off_beach,
		third * MeshConfig.SEA_BASIN_NATURAL_SLOPE,
		0.02,
		"a natural bank must shelve gently",
	)
	assert_true(
		off_pier > off_beach * 3.0,
		"a pier face must drop like a crib, not a beach (%s vs %s)" % [off_pier, off_beach],
	)


func test_inland_water_keeps_the_flat_bed_and_gets_no_apron() -> void:
	var definition := _sea_definition(MapTypes.TERRAIN_WATER, MapTypes.TERRAIN_WATER)
	var grid := MapBuilder.build(definition)
	var field := TerrainBuilder.ensure_height_field(definition, grid)
	assert_false(field.has("basin_targets"), "ponds and ditches must not bake a basin")
	assert_eq(field["bed_positions"], field["positions"], "inland water must render the flat bed")
	var terrain := TerrainBuilder.build_terrain(definition, grid)
	assert_true(
		terrain.get_node_or_null("SeaBedApron") == null,
		"inland water must not extrude a seabed apron",
	)
	terrain.free()


func test_sea_border_extrudes_an_apron_from_the_border_bed() -> void:
	var definition := _sea_definition()
	var grid := MapBuilder.build(definition)
	var field := TerrainBuilder.ensure_height_field(definition, grid)
	var terrain := TerrainBuilder.build_terrain(definition, grid)
	var apron := terrain.get_node_or_null("SeaBedApron") as MeshInstance3D
	assert_true(apron != null, "a sea reaching the map border must get a seabed apron")
	if apron != null:
		var vertices: PackedVector3Array = (apron.mesh as ArrayMesh).surface_get_arrays(0)[
			Mesh.ARRAY_VERTEX
		]
		var bed: PackedVector3Array = field["bed_positions"]
		var border_bed := {}
		for vertex in bed:
			border_bed[Vector2(vertex.x, vertex.z)] = vertex.y
		var inner := 0
		for vertex in vertices:
			assert_true(
				vertex.y < -MeshConfig.WATER_RECESS - 0.1,
				"apron vertices must lie on the deepened bed",
			)
			var key := Vector2(vertex.x, vertex.z)
			if border_bed.has(key):
				inner += 1
				assert_almost_eq(vertex.y, border_bed[key], 0.0001, "apron must meet the bed")
		assert_true(inner > 0, "the apron inner edge must reuse the border bed vertices")
		# The grass bank (south) and the land-free east/west ends of the bank rows
		# must not get a floor: every vertex stays beside a sea border.
		for vertex in vertices:
			assert_true(vertex.z < float(SEA_SIZE.y) - 3.9, "no apron along the land border")
	terrain.free()


func test_in_map_water_marks_the_flat_bed_for_the_shader() -> void:
	var definition := _sea_definition()
	var grid := MapBuilder.build(definition)
	var terrain := TerrainBuilder.build_terrain(definition, grid)
	var water := terrain.get_node_or_null("Terrain_deep_water") as MeshInstance3D
	assert_true(water != null, "deep sea must build a water surface")
	if water != null:
		var uv2: PackedVector2Array = (water.mesh as ArrayMesh).surface_get_arrays(0)[
			Mesh.ARRAY_TEX_UV2
		]
		assert_true(uv2.size() > 0, "in-map water must carry UV2")
		for value in uv2:
			assert_eq(
				value,
				Vector2(1.0, -MeshConfig.WATER_RECESS),
				"UV2 must flag the flat gameplay bed plane",
			)
	terrain.free()
	var source := FileAccess.get_file_as_string(WATER_SHADER_PATH)
	assert_true(
		source.contains("_flat_bed_view_depth(") and source.contains("flat_bed_flag"),
		"the water shader must measure its optical column to the flat bed",
	)


func test_harbor_north_has_a_real_basin_under_the_roadstead() -> void:
	var definition: MapDefinition = RevalHarborNorthDefinition.create()
	var grid := MapBuilder.build(definition)
	TerrainBuilder.ensure_height_field(definition, grid)
	var roadstead := Vector2(80.5, 20.5)
	assert_true(
		TerrainBuilder.view_bed_height(definition, roadstead) < -3.0,
		"the Harbor North roadstead must be metres deep under the gameplay surface",
	)
	assert_almost_eq(
		TerrainBuilder.ground_height(definition, roadstead),
		-MeshConfig.WATER_RECESS,
		0.0001,
		"Harbor North gameplay bed must stay flat",
	)


func _sea_definition(
	deep: StringName = MapTypes.TERRAIN_DEEP_WATER,
	shallow: StringName = MapTypes.TERRAIN_SHALLOW_WATER
) -> MapDefinition:
	var definition := MapDefinition.new()
	definition.map_id = &"test_ws13b_sea_basin_depth_%s" % String(deep)
	definition.size_cells = SEA_SIZE
	definition.base_terrain = MapTypes.TERRAIN_GRASS
	definition.seed = 1343
	definition.player_spawn = Vector2(0.5, 15.5)
	definition.location = &"test"
	definition.scope = &"prototype"
	definition.palette = &"spring"
	definition.fingerprint = "test-ws13b-sea-basin-%s" % String(deep)
	definition.zones = [
		{"rect": Rect2i(0, 0, SEA_SIZE.x, 10), "terrain": deep},
		{"rect": Rect2i(0, 10, SEA_SIZE.x, 2), "terrain": shallow},
		{"rect": PIER, "terrain": MapTypes.TERRAIN_TIMBER_FLOOR},
	]
	return definition
