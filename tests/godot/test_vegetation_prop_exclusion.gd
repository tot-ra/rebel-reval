extends "res://tests/godot/test_case.gd"

## Grass must not grow through solid props. The regression that started this was
## a tuft standing inside the `civic_well_wash_tub` basin on the forum.
##
## Both view-only vegetation layers block cells independently, so both are
## covered: the mesh-builder scatter (`map_view_mesh_builder_scatter.gd`) and the
## dense first-person ground cover (`map_view_terrain_details.gd`).
##
## Headless note: MultiMesh instance buffers live on the GPU and read back as
## zero transforms, so the ground-cover layer is checked by instance count and
## the scatter layer by its plain `Array[Transform3D]` state.

const Details := preload("res://scripts/map/view3d/map_view_terrain_details.gd")
const Primitives := preload("res://scripts/map/view3d/map_view_mesh_builder_primitives.gd")
const Scatter := preload("res://scripts/map/view3d/map_view_mesh_builder_scatter.gd")

const MEADOW_CELLS := Vector2i(16, 16)
## Tubs on a loose grid, so the meadow keeps open ground between them.
const TUB_CELLS: Array[Vector2i] = [
	Vector2i(3, 3),
	Vector2i(3, 8),
	Vector2i(3, 13),
	Vector2i(8, 3),
	Vector2i(8, 8),
	Vector2i(8, 13),
	Vector2i(13, 3),
	Vector2i(13, 8),
	Vector2i(13, 13),
]


## The exclusion contract both layers consume: a solid prop claims its cell, a
## soft prop kind claims nothing.
func test_solid_props_claim_their_cells_and_soft_props_do_not() -> void:
	var rects := Primitives.prop_cell_rects(_meadow_definition(MapTypes.PROP_KIND_WASH_TUB))
	assert_eq(rects.size(), TUB_CELLS.size(), "every wash tub must claim a rect")
	for cell in TUB_CELLS:
		assert_true(
			Primitives.cell_blocked(cell, rects), "cell %s carries a wash tub" % cell
		)
	assert_false(Primitives.cell_blocked(Vector2i(0, 0), rects), "open meadow must stay plantable")
	assert_true(
		Primitives.prop_cell_rects(_meadow_definition(MapTypes.PROP_KIND_PLOT_WALL)).is_empty(),
		"soft props such as plot walls must not clear the verge they stand on"
	)


## Ground cover is the dense eye-level layer, so a tuft here is what grows
## through a basin. Instance counts prove it skips the cells the tubs claim.
func test_ground_cover_skips_solid_prop_cells() -> void:
	var bare := _ground_cover_instances(_meadow_definition(&""))
	var with_tubs := _ground_cover_instances(_meadow_definition(MapTypes.PROP_KIND_WASH_TUB))
	var with_plot_walls := _ground_cover_instances(_meadow_definition(MapTypes.PROP_KIND_PLOT_WALL))
	assert_true(bare > 0, "the bare meadow must grow ground cover, otherwise this proves nothing")
	assert_true(
		with_tubs < bare,
		"wash tubs must remove the ground cover in their cells (bare=%d, tubs=%d)"
			% [bare, with_tubs]
	)
	assert_eq(with_plot_walls, bare, "a soft prop must not thin the meadow")


## The scatter layer keeps readable transforms, so its tufts are checked by
## position against the same exclusion rects.
func test_scatter_tufts_avoid_solid_prop_cells() -> void:
	var bare_definition := _meadow_definition(&"")
	var rects := Primitives.prop_cell_rects(_meadow_definition(MapTypes.PROP_KIND_WASH_TUB))
	var bare_hits := 0
	for point in _scatter_points(bare_definition):
		for rect in rects:
			if rect.grow(0.5).has_point(point):
				bare_hits += 1
				break
	assert_true(bare_hits > 0, "the bare meadow must scatter tufts where the tubs will stand")
	for point in _scatter_points(_meadow_definition(MapTypes.PROP_KIND_WASH_TUB)):
		for rect in rects:
			assert_false(rect.has_point(point), "tuft at %s is inside prop rect %s" % [point, rect])


## Map-level guard on the authored forum: no scatter tuft inside a solid prop.
func test_market_civic_quarter_scatter_avoids_solid_props() -> void:
	var definition: MapDefinition = MapAuditRegistry.by_id()["market_civic_quarter"]
	var rects := Primitives.prop_cell_rects(definition)
	assert_true(rects.size() > 0, "the forum's solid props must produce scatter exclusion rects")
	var points := _scatter_points(definition)
	assert_true(points.size() > 0, "market_civic_quarter must still scatter tufts")
	for point in points:
		for rect in rects:
			assert_false(
				rect.has_point(point), "tuft at %s is inside prop rect %s" % [point, rect]
			)


func _ground_cover_instances(definition: MapDefinition) -> int:
	var grid := MapBuilder.build(definition)
	var chunk := Details.build_chunk(definition, grid, Rect2i(Vector2i.ZERO, grid.size_cells), true)
	var total := 0
	var first_person := chunk.get_node_or_null("FirstPerson")
	if first_person != null:
		for layer in first_person.get_children():
			if layer is MultiMeshInstance3D:
				total += (layer as MultiMeshInstance3D).multimesh.instance_count
	chunk.free()
	return total


## World XZ of every scatter tuft. One world unit is one cell, so these compare
## directly against `prop_cell_rects` output.
func _scatter_points(definition: MapDefinition) -> Array[Vector2]:
	var grid := MapBuilder.build(definition)
	var state := Scatter.begin_scatter(definition, grid)
	Scatter.collect_rows(state, grid.size_cells.y)
	var points: Array[Vector2] = []
	for key in ["small_grass", "large_grass", "clovers", "hay_stubble"]:
		for xform: Transform3D in state.get(key, [] as Array[Transform3D]):
			points.append(Vector2(xform.origin.x, xform.origin.z))
	return points


## A plain meadow, optionally dressed with one prop kind on every tub cell.
func _meadow_definition(prop_kind: StringName) -> MapDefinition:
	var definition := MapDefinition.new()
	definition.map_id = &"test_prop_vegetation_exclusion"
	definition.size_cells = MEADOW_CELLS
	definition.base_terrain = MapTypes.TERRAIN_MEADOW
	definition.player_spawn = Vector2(16.0, 16.0)
	definition.location = &"test"
	definition.scope = &"prototype"
	definition.palette = &"spring"
	definition.fingerprint = "test-prop-vegetation-exclusion"
	if prop_kind.is_empty():
		return definition
	var props: Array[Dictionary] = []
	for index in TUB_CELLS.size():
		props.append(
			{
				"id": StringName("test_prop_%d" % index),
				"kind": prop_kind,
				# Props are authored in logic units, so a cell centre is cell * cell_size.
				"position": (
					(Vector2(TUB_CELLS[index]) + Vector2(0.5, 0.5)) * float(definition.cell_size)
				),
			}
		)
	definition.props = props
	return definition
