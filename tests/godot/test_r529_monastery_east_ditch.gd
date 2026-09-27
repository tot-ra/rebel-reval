extends "res://tests/godot/test_case.gd"

## R-529: enclosed still-water contours must not flood a dirt causeway, and the
## Monastery east ditch must stay local to the wall road.

const MonasteryQuarter := preload(
	"res://scripts/map/definitions/prototypes/monastery_quarter_definition.gd"
)
const TerrainBuilder := preload("res://scripts/map/view3d/map_view_mesh_builder_terrain.gd")
const WaterBuilder := preload("res://scripts/map/view3d/map_view_mesh_builder_terrain_water.gd")
const MapView := preload("res://scripts/map/view3d/map_view_3d.gd")
const MapViewMaterials := preload("res://scripts/map/view3d/map_view_materials.gd")

const CAUSEWAY_SOURCE := """rrmap 1
map r529_ditch loc.r529_ditch 16 32 dirt seed=529
terrain ditch water 6 2 4 28 order=10
terrain gate dirt 6 12 4 8 order=11
spawn spawn.main 2 2
"""

const CAUSEWAY_CELLS: Array[Vector2i] = [
	Vector2i(7, 14),
	Vector2i(8, 15),
	Vector2i(9, 16),
]
const DITCH_CELLS: Array[Vector2i] = [
	Vector2i(7, 6),
	Vector2i(8, 8),
	Vector2i(7, 24),
]
const MONASTERY_DITCH_CELLS: Array[Vector2i] = [
	Vector2i(229, 8),
	Vector2i(229, 24),
	Vector2i(229, 56),
	Vector2i(229, 88),
	Vector2i(229, 104),
]
const MONASTERY_CAUSEWAY_CELLS: Array[Vector2i] = [
	Vector2i(229, 40),
	Vector2i(229, 44),
	Vector2i(229, 48),
]


func test_enclosed_ditch_contour_keeps_a_dirt_causeway_dry() -> void:
	var definition := _compile(CAUSEWAY_SOURCE, "res://r529_ditch.rrmap")
	if definition == null:
		return
	var grid := MapBuilder.build(definition)
	var field := TerrainBuilder.ensure_height_field(definition, grid)
	for cell in DITCH_CELLS:
		assert_eq(grid.get_terrain(cell), MapTypes.TERRAIN_WATER, "ditch cell %s" % cell)
		var ditch_sample := Vector2(cell) + Vector2(0.5, 0.5)
		assert_true(
			WaterBuilder.water_coverage_at(field, ditch_sample, MapTypes.TERRAIN_WATER)
			>= MapViewMeshBuilderConfig.WATER_CONTOUR_THRESHOLD,
			"ditch centre %s must stay wet" % cell,
		)
	for cell in CAUSEWAY_CELLS:
		assert_eq(grid.get_terrain(cell), MapTypes.TERRAIN_DIRT, "causeway cell %s" % cell)
		var dry_sample := Vector2(cell) + Vector2(0.5, 0.5)
		assert_true(
			WaterBuilder.water_coverage_at(field, dry_sample, MapTypes.TERRAIN_WATER)
			< MapViewMeshBuilderConfig.WATER_CONTOUR_THRESHOLD,
			"causeway centre %s must stay below the water iso-line" % cell,
		)
		assert_false(
			WaterBuilder.cell_near_terrain(field, cell, MapTypes.TERRAIN_WATER, grid),
			"causeway cell %s must not emit a water quad" % cell,
		)


func test_monastery_east_ditch_keeps_travel_openings_dry() -> void:
	var definition: MapDefinition = MonasteryQuarter.create()
	assert_eq(definition.map_id, &"monastery_quarter")
	var grid := MapBuilder.build(definition)
	var field := TerrainBuilder.ensure_height_field(definition, grid)
	for cell in MONASTERY_DITCH_CELLS:
		assert_eq(
			grid.get_terrain(cell),
			MapTypes.TERRAIN_WATER,
			"outer ditch must follow the east wall at %s" % cell,
		)
	for cell in MONASTERY_CAUSEWAY_CELLS:
		assert_eq(
			grid.get_terrain(cell),
			MapTypes.TERRAIN_DIRT,
			"outer gate must keep a dirt causeway at %s" % cell,
		)
		assert_true(
			MapVerification.is_walkable_cell(definition, grid, cell),
			"causeway %s must remain walkable" % cell,
		)
		var causeway_sample := Vector2(cell) + Vector2(0.5, 0.5)
		assert_true(
			WaterBuilder.water_coverage_at(field, causeway_sample, MapTypes.TERRAIN_WATER)
			< MapViewMeshBuilderConfig.WATER_CONTOUR_THRESHOLD,
			"causeway %s must not be inside the water contour" % cell,
		)
	for transition in definition.transitions:
		var transition_id: StringName = transition.get("id", &"")
		if transition_id not in [&"to_reval_north_outer", &"to_reval_east_outer"]:
			continue
		var area: Rect2i = transition.get("area", Rect2i())
		for y in range(area.position.y, area.position.y + area.size.y):
			for x in range(area.position.x, area.position.x + area.size.x):
				var cell := Vector2i(x, y)
				assert_false(
					MapTypes.WATER_TERRAINS.has(grid.get_terrain(cell)),
					"%s must not author a water step at %s" % [transition_id, cell],
				)
				assert_true(
					WaterBuilder.water_coverage_at(
						field, Vector2(cell) + Vector2(0.5, 0.5), MapTypes.TERRAIN_WATER
					)
					< MapViewMeshBuilderConfig.WATER_CONTOUR_THRESHOLD,
					"%s contour must stay off %s" % [transition_id, cell],
				)


func test_monastery_east_ditch_builds_shared_view_water() -> void:
	var definition: MapDefinition = MonasteryQuarter.create()
	var grid := MapBuilder.build(definition)
	var fingerprint_before := grid.fingerprint()
	var walkability_before := _walkability_signature(definition, grid)
	var view := MapView.create(definition, grid)
	assert_true(view != null, "monastery_quarter must create a 3D view")
	if view == null:
		return
	var surface := view.get_node_or_null("Terrain/Terrain_water") as MeshInstance3D
	assert_true(surface != null, "the east ditch must build Terrain_water")
	if surface != null:
		assert_true(
			surface.mesh != null and surface.mesh.get_surface_count() > 0,
			"the east ditch surface must contain geometry",
		)
		assert_eq(
			surface.material_override,
			MapViewMaterials.water_surface(MapTypes.TERRAIN_WATER),
			"the ditch must use the shared enclosed-water material",
		)
	assert_eq(grid.fingerprint(), fingerprint_before, "view build must not mutate the grid")
	assert_eq(
		_walkability_signature(definition, grid),
		walkability_before,
		"view build must not mutate walkability",
	)
	_free_view(view)


func _compile(source: String, path: String) -> MapDefinition:
	var parsed := MapRrmapParser.parse(source, path)
	assert_true(parsed.is_ok(), "%s: %s" % [path, parsed.formatted_diagnostics()])
	if not parsed.is_ok():
		return null
	return parsed.definition


func _walkability_signature(definition: MapDefinition, grid: MapTerrainGrid) -> String:
	var blocked := MapVerification.blocked_cells(definition)
	var cells := PackedByteArray()
	cells.resize(definition.size_cells.x * definition.size_cells.y)
	for y in definition.size_cells.y:
		for x in definition.size_cells.x:
			var cell := Vector2i(x, y)
			var walkable := not MapTypes.WATER_TERRAINS.has(grid.get_terrain(cell))
			walkable = walkable and not blocked.has(cell)
			cells[y * definition.size_cells.x + x] = 1 if walkable else 0
	return cells.hex_encode()


func _free_view(view: MapView) -> void:
	if not is_instance_valid(view):
		return
	MapView._strip_geometry_materials(view)
	view.free()
