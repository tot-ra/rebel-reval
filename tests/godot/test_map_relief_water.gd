extends "res://tests/godot/test_case.gd"

## R-1003: view water recess and the WS-13b basin sit on compiled relief.
## Maps that author no relief_* statement keep the historic world-zero recess.

const MeshConfig := preload("res://scripts/map/view3d/map_view_mesh_builder_config.gd")
const TerrainBuilder := preload("res://scripts/map/view3d/map_view_mesh_builder_terrain.gd")
const RevalHarborNorthDefinition := preload(
	"res://scripts/map/definitions/outdoor/reval_harbor_north_definition.gd"
)

const MOAT_SOURCE := """rrmap 1
map relief_moat_water loc.relief_moat_water 32 24 grass seed=7
relief_terrace plateau 0 0 32 24 2 edge=0
relief_ditch moat 6 12 26 12 5 0.8
terrain moat_water water 10 10 12 5 order=1
spawn spawn.main 2 2
"""

const QUAY_SEA_SOURCE := """rrmap 1
map relief_quay_sea loc.relief_quay_sea 32 16 grass seed=11
relief_terrace quay 16 0 16 16 2 edge=0
terrain basin deep_water 0 0 16 16 order=1
spawn spawn.main 24 8
"""

const FLAT_POND_SOURCE := """rrmap 1
map relief_flat_pond loc.relief_flat_pond 24 16 grass seed=7
terrain pond water 6 4 12 8 order=1
spawn spawn.main 2 2
"""


func _compile(source: String, path: String) -> MapDefinition:
	var parsed := MapRrmapParser.parse(source, path)
	assert_true(parsed.is_ok(), "%s: %s" % [path, parsed.formatted_diagnostics()])
	if not parsed.is_ok():
		return null
	return parsed.definition


func _field(definition: MapDefinition) -> Dictionary:
	return TerrainBuilder.ensure_height_field(definition, MapBuilder.build(definition))


func test_moat_water_sits_inside_the_ditch_below_both_banks() -> void:
	var definition := _compile(MOAT_SOURCE, "res://relief_moat_water.rrmap")
	if definition == null:
		return
	var field := _field(definition)
	var water_at := Vector2(16.5, 12.5)
	var north_bank := Vector2i(16, 8)
	var south_bank := Vector2i(16, 16)
	assert_true(field["water"].has(Vector2i(16, 12)), "moat cells must be water")
	var bed := TerrainBuilder.field_height(field, water_at)
	var surface := bed + MeshConfig.WATER_SURFACE_LIFT
	var view_bed := TerrainBuilder.view_bed_height(definition, water_at)
	var north := definition.height_at(north_bank)
	var south := definition.height_at(south_bank)
	assert_true(north > 1.5 and south > 1.5, "both banks stay on the terrace")
	assert_true(surface < north, "water surface must sit below the north bank")
	assert_true(surface < south, "water surface must sit below the south bank")
	assert_true(view_bed <= bed + 0.0001, "rendered bed must not rise above the gameplay bed")
	assert_true(bed < surface, "gameplay bed must stay below the lifted water surface")
	assert_true(
		bed > 1.0,
		"moat water must sit on the terrace, not at the world-zero recess (got %s)" % bed
	)
	var terrain := TerrainBuilder.build_terrain(definition, MapBuilder.build(definition))
	var mesh := terrain.get_node_or_null("Terrain_water") as MeshInstance3D
	assert_true(mesh != null, "the moat must build a water surface mesh")
	if mesh != null:
		var vertices: PackedVector3Array = (mesh.mesh as ArrayMesh).surface_get_arrays(0)[
			Mesh.ARRAY_VERTEX
		]
		assert_true(not vertices.is_empty(), "moat water mesh needs vertices")
		for vertex in vertices:
			assert_true(
				vertex.y < north and vertex.y < south,
				"every water vertex must stay below both banks"
			)
			assert_true(vertex.y > 1.0, "water vertices must follow the terrace, not world zero")
	terrain.free()


func test_maps_without_relief_keep_the_world_zero_recess() -> void:
	var definition := _compile(FLAT_POND_SOURCE, "res://relief_flat_pond.rrmap")
	if definition == null:
		return
	assert_true(definition.relief_heights.is_empty(), "flat pond authors no relief")
	var field := _field(definition)
	assert_false(field.has("water_surface_bases"), "empty relief must skip the shore bake")
	var water_at := Vector2(12.5, 8.5)
	assert_almost_eq(
		TerrainBuilder.field_height(field, water_at),
		-MeshConfig.WATER_RECESS,
		0.0001,
		"flat pond gameplay bed stays at the historic recess"
	)
	assert_almost_eq(
		TerrainBuilder.view_bed_height(definition, water_at),
		-MeshConfig.WATER_RECESS,
		0.0001,
		"inland pond bed stays flat"
	)
	var terrain := TerrainBuilder.build_terrain(definition, MapBuilder.build(definition))
	var mesh := terrain.get_node_or_null("Terrain_water") as MeshInstance3D
	assert_true(mesh != null, "flat pond must build a water surface")
	if mesh != null:
		var expected := -MeshConfig.WATER_RECESS + MeshConfig.WATER_SURFACE_LIFT
		var vertices: PackedVector3Array = (mesh.mesh as ArrayMesh).surface_get_arrays(0)[
			Mesh.ARRAY_VERTEX
		]
		var uv2: PackedVector2Array = (mesh.mesh as ArrayMesh).surface_get_arrays(0)[
			Mesh.ARRAY_TEX_UV2
		]
		for vertex in vertices:
			assert_almost_eq(vertex.y, expected, 0.0001, "flat pond surface Y is unchanged")
		for value in uv2:
			assert_eq(
				value,
				Vector2(1.0, -MeshConfig.WATER_RECESS),
				"flat pond UV2 keeps the historic gameplay bed"
			)
	terrain.free()


func test_raised_quay_does_not_lift_datum_sea() -> void:
	var definition := _compile(QUAY_SEA_SOURCE, "res://relief_quay_sea.rrmap")
	if definition == null:
		return
	var field := _field(definition)
	var sea_at := Vector2(8.5, 8.5)
	assert_true(field["water"].has(Vector2i(8, 8)), "left half is sea")
	assert_almost_eq(
		TerrainBuilder.field_height(field, sea_at),
		-MeshConfig.WATER_RECESS,
		0.0001,
		"sea cells at compiled relief 0 stay on the datum recess"
	)
	assert_true(
		TerrainBuilder.view_bed_height(definition, sea_at)
		< TerrainBuilder.field_height(field, sea_at),
		"open sea still deepens the rendered basin below the gameplay bed"
	)
	assert_eq(definition.height_at(Vector2i(24, 8)), 2.0, "the quay terrace stays at +2")


func test_harbor_north_gameplay_bed_stays_on_the_historic_recess() -> void:
	var definition: MapDefinition = RevalHarborNorthDefinition.create()
	assert_true(definition.relief_heights.is_empty(), "Harbor North authors no relief yet")
	var field := _field(definition)
	assert_false(field.has("water_surface_bases"))
	var roadstead := Vector2(80.5, 20.5)
	assert_almost_eq(
		TerrainBuilder.field_height(field, roadstead),
		-MeshConfig.WATER_RECESS,
		0.0001,
		"Harbor North gameplay bed must stay bit-identical"
	)
	assert_almost_eq(
		TerrainBuilder.ground_height(definition, roadstead),
		-MeshConfig.WATER_RECESS,
		0.0001,
		"Harbor North ground_height must stay bit-identical"
	)
