extends "res://tests/godot/test_case.gd"

## CO-02: shore debris (boulders, stone clusters, shingle, wrack, algae) placed by
## distance to the WS-08 shore field.

const MapBuilder := preload("res://scripts/map/map_builder.gd")
const Details := preload("res://scripts/map/view3d/map_view_terrain_details.gd")
const HarborEastDefinition := preload(
	"res://scripts/map/definitions/outdoor/reval_harbor_east_definition.gd"
)
const HarborNorthDefinition := preload(
	"res://scripts/map/definitions/outdoor/reval_harbor_north_definition.gd"
)

## Largest walkable regions, re-measured 2026-10-07 (was 4326 / 6333 at CO-02).
## R-1206 removed stale blocked.water.shallow_* exclusions so swimmers can climb out.
const HARBOR_EAST_WALKABLE := 4628
const HARBOR_NORTH_WALKABLE := 6578
## ADR 0025-style per-part triangle ceiling for scatter props.
const MAX_PART_TRIANGLES := 1500
const PIER_RECT := Rect2i(30, 8, 3, 12)


func test_same_seed_gives_identical_placements() -> void:
	var definition := _beach_definition()
	var grid := MapBuilder.build(definition)
	var all := Rect2i(Vector2i.ZERO, grid.size_cells)
	var first := _signature(Details.shore_debris_placements(definition, grid, all))
	var second := _signature(Details.shore_debris_placements(definition, grid, all))
	assert_true(first.size() > 20, "a beach must receive shore debris (got %d)" % first.size())
	assert_eq(first, second, "the same map seed must give identical placements")
	definition.seed += 1
	var reseeded := _signature(
		Details.shore_debris_placements(definition, MapBuilder.build(definition), all)
	)
	assert_ne(first, reseeded, "a different map seed must rearrange the debris")


func test_chunk_order_does_not_change_placements() -> void:
	var definition := _beach_definition()
	var grid := MapBuilder.build(definition)
	var whole := _signature(
		Details.shore_debris_placements(definition, grid, Rect2i(Vector2i.ZERO, grid.size_cells))
	)
	var pieces: Array[String] = []
	# Reverse, uneven chunks: nothing may depend on which chunk loaded first.
	for rect in [
		Rect2i(24, 16, 24, 16), Rect2i(0, 16, 24, 16), Rect2i(24, 0, 24, 16), Rect2i(0, 0, 24, 16)
	]:
		pieces.append_array(_signature(Details.shore_debris_placements(definition, grid, rect)))
	pieces.sort()
	assert_eq(pieces, whole, "chunked placements must equal the whole-map placements")


func test_no_debris_on_reserved_cells_or_pier_decks() -> void:
	var definition := _beach_definition()
	var grid := MapBuilder.build(definition)
	var excluded := Details.shore_debris_excluded_cells(definition)
	for cell in [Vector2i(10, 17), Vector2i(20, 14), Vector2i(40, 20), Vector2i(6, 26)]:
		assert_true(
			excluded.has(cell), "transition, anchor, prop and spawn cells are reserved: %s" % cell
		)
	var placements := Details.shore_debris_placements(
		definition, grid, Rect2i(Vector2i.ZERO, grid.size_cells)
	)
	for placement in placements:
		var cell: Vector2i = placement["cell"]
		assert_false(
			excluded.has(cell), "%s placed on reserved cell %s" % [placement["kind"], cell]
		)
		assert_false(
			PIER_RECT.grow(1).has_point(cell),
			"%s placed on or against the pier deck at %s" % [placement["kind"], cell]
		)
		for footprint_cell in placement["footprint"]:
			assert_false(
				excluded.has(footprint_cell), "blocking stone covers reserved %s" % footprint_cell
			)
			assert_false(PIER_RECT.has_point(footprint_cell), "blocking stone covers the pier deck")


func test_only_stones_over_one_metre_block() -> void:
	var definition := _beach_definition()
	var grid := MapBuilder.build(definition)
	var placements := Details.shore_debris_placements(
		definition, grid, Rect2i(Vector2i.ZERO, grid.size_cells)
	)
	var blocking := 0
	for placement in placements:
		var kind: StringName = placement["kind"]
		var nominal := float(Details.SHORE_DEBRIS_KINDS[kind][1])
		var metres: float = (
			nominal
			* placement["transform"].basis.get_scale().x
			* MapViewMaterials.METERS_PER_WORLD_UNIT
		)
		if placement["blocks"]:
			blocking += 1
			assert_true(
				metres >= Details.SHORE_BLOCKING_MIN_METRES, "%s blocks at %.2f m" % [kind, metres]
			)
			assert_false(
				(placement["footprint"] as Array).is_empty(), "a blocking stone has a footprint"
			)
			for cell in placement["footprint"]:
				assert_false(
					MapVerification.is_walkable_cell(definition, grid, cell),
					"blocking stone footprint %s must already be impassable water" % cell
				)
		else:
			assert_true(
				metres < Details.SHORE_BLOCKING_MIN_METRES or nominal == 0.0,
				"%s at %.2f m must block" % [kind, metres]
			)
			assert_true((placement["footprint"] as Array).is_empty(), "decoration has no footprint")
	assert_true(blocking > 0, "the shallows must hold at least one blocking erratic")
	var node := Details.build_shore_debris(definition, grid, Rect2i(Vector2i.ZERO, grid.size_cells))
	assert_eq(_count_collision(node), 0, "debris adds no physics bodies; gameplay owns collision")
	assert_true(node.get_child_count() >= 4, "several debris families are batched")
	for child in node.get_children():
		assert_true(child is MultiMeshInstance3D, "%s is a MultiMesh batch" % child.name)
	node.free()


func test_algae_below_and_wrack_at_the_waterline() -> void:
	var definition := _beach_definition()
	var grid := MapBuilder.build(definition)
	var seen: Dictionary = {}
	for placement in Details.shore_debris_placements(
		definition, grid, Rect2i(Vector2i.ZERO, grid.size_cells)
	):
		var kind: StringName = placement["kind"]
		var d: float = placement["shore_distance"]
		seen[kind] = true
		if kind in Details.SHORE_ALGAE_KINDS:
			assert_true(d > 0.0, "%s must sit below the waterline (d=%.2f)" % [kind, d])
		if kind in Details.SHORE_WRACK_KINDS:
			assert_true(absf(d) <= 1.0, "wrack must lie within one cell of the line (d=%.2f)" % d)
		if (
			kind
			in [
				Details.SHORE_PEBBLE_PATCH_A,
				Details.SHORE_PEBBLE_PATCH_B,
				Details.SHORE_STONE_CLUSTER_A
			]
		):
			assert_true(d < 0.0, "dry shingle and stones sit above the line (d=%.2f)" % d)
	for kind in [
		Details.SHORE_ALGAE_SKIRT, Details.SHORE_WRACK_LINE_A, Details.SHORE_BOULDER_BARNACLED
	]:
		assert_true(seen.has(kind), "the beach fixture must exercise %s" % kind)


func test_per_chunk_count_is_bounded_on_the_harbours() -> void:
	for definition in [HarborEastDefinition.create(), HarborNorthDefinition.create()]:
		var grid := MapBuilder.build(definition)
		var total := 0
		for coordinates in grid.chunk_coordinates():
			var count := (
				Details
				. shore_debris_placements(definition, grid, grid.chunk_bounds(coordinates))
				. size()
			)
			total += count
			assert_true(
				count <= Details.SHORE_DEBRIS_MAX_PER_CHUNK,
				"%s chunk %s holds %d debris" % [definition.map_id, coordinates, count]
			)
		assert_true(total > 40, "%s shore must be dressed (got %d)" % [definition.map_id, total])


func test_harbour_walkable_regions_are_unchanged() -> void:
	for entry in [
		[HarborEastDefinition.create(), HARBOR_EAST_WALKABLE],
		[HarborNorthDefinition.create(), HARBOR_NORTH_WALKABLE],
	]:
		var definition: MapDefinition = entry[0]
		var grid := MapBuilder.build(definition)
		var blocking := Details.shore_debris_blocking_cells(definition, grid)
		assert_true(
			blocking.size() > 0, "%s shallows must hold blocking erratics" % definition.map_id
		)
		for cell in blocking:
			assert_false(
				MapVerification.is_walkable_cell(definition, grid, cell),
				"%s erratic at %s must stand on impassable water" % [definition.map_id, cell]
			)
		var before := _largest_walkable_region(definition, grid, {})
		var after := _largest_walkable_region(definition, grid, blocking)
		assert_eq(before, int(entry[1]), "%s largest walkable region" % definition.map_id)
		assert_eq(
			after, before, "%s erratics must not shrink the walkable region" % definition.map_id
		)


func test_every_family_loads_with_shared_pbr_materials() -> void:
	for kind: StringName in Details.SHORE_DEBRIS_KINDS:
		var mesh := Details.shore_debris_mesh(kind)
		assert_true(mesh != null, "%s mesh must load from its GLB" % kind)
		if mesh == null:
			continue
		var triangles := 0
		for surface in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface) as StandardMaterial3D
			assert_true(material != null, "%s surface %d has a material" % [kind, surface])
			if material == null:
				continue
			assert_eq(
				material,
				MapViewMaterials.shore_debris(StringName(material.resource_name)),
				"%s surface %d uses the shared %s family" % [kind, surface, material.resource_name]
			)
			assert_true(material.albedo_texture != null, "%s albedo plate" % material.resource_name)
			assert_true(material.normal_texture != null, "%s normal plate" % material.resource_name)
			assert_true(
				material.roughness_texture != null, "%s roughness plate" % material.resource_name
			)
			var indices: PackedInt32Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX]
			triangles += indices.size() / 3
		assert_true(
			triangles > 0 and triangles <= MAX_PART_TRIANGLES,
			"%s triangle budget (%d)" % [kind, triangles]
		)
	var barnacled := Details.shore_debris_mesh(Details.SHORE_BOULDER_BARNACLED)
	if barnacled != null:
		assert_eq(
			barnacled.get_surface_count(), 2, "the barnacled boulder has a crusted foot surface"
		)


func test_dry_and_interior_maps_get_no_debris() -> void:
	var definition := _beach_definition()
	definition.zones = []
	var grid := MapBuilder.build(definition)
	assert_true(
		(
			Details
			. shore_debris_placements(definition, grid, Rect2i(Vector2i.ZERO, grid.size_cells))
			. is_empty()
		),
		"a map without sea gets no shore debris"
	)


## 48x32 beach: sea in the top rows, coast sand below, a timber pier crossing the
## line, and reserved gameplay cells on the sand and in the shallows.
func _beach_definition() -> MapDefinition:
	var definition := MapDefinition.new()
	definition.map_id = &"test_co02_shore_debris"
	definition.size_cells = Vector2i(48, 32)
	definition.base_terrain = MapTypes.TERRAIN_COAST_SAND
	definition.seed = 1343
	definition.cell_size = 32
	definition.player_spawn = Vector2(6.5, 26.5) * 32.0
	definition.location = &"test"
	definition.scope = &"prototype"
	definition.palette = &"spring"
	definition.fingerprint = "test-co02-shore-debris"
	definition.zones = [
		{"rect": Rect2i(0, 0, 48, 6), "terrain": MapTypes.TERRAIN_DEEP_WATER},
		{"rect": Rect2i(0, 6, 48, 9), "terrain": MapTypes.TERRAIN_SHALLOW_WATER},
		{"rect": PIER_RECT, "terrain": MapTypes.TERRAIN_TIMBER_FLOOR},
	]
	definition.transitions = [
		{"id": &"test.exit", "rect": Rect2(Vector2(9, 16) * 32.0, Vector2(3, 2) * 32.0)}
	]
	definition.interaction_anchors = [
		{"id": &"test.anchor", "position": Vector2(20.5, 14.5) * 32.0}
	]
	definition.props = [
		{"id": &"test.boat", "kind": &"fishing_boat", "position": Vector2(40.5, 20.5) * 32.0}
	]
	return definition


func _signature(placements: Array[Dictionary]) -> Array[String]:
	var lines: Array[String] = []
	for placement in placements:
		var transform: Transform3D = placement["transform"]
		(
			lines
			. append(
				(
					"%s|%s|%s|%s|%s"
					% [
						placement["kind"],
						placement["cell"],
						transform.origin.snapped(Vector3.ONE * 0.0001),
						transform.basis.x.snapped(Vector3.ONE * 0.0001),
						placement["blocks"],
					]
				)
			)
		)
	lines.sort()
	return lines


func _largest_walkable_region(
	definition: MapDefinition, grid: MapTerrainGrid, extra_blocked: Dictionary
) -> int:
	var seen: Dictionary = {}
	var best := 0
	for y in definition.size_cells.y:
		for x in definition.size_cells.x:
			var start := Vector2i(x, y)
			if seen.has(start) or not _walkable(definition, grid, start, extra_blocked):
				continue
			var size := 0
			var stack: Array[Vector2i] = [start]
			seen[start] = true
			while not stack.is_empty():
				var cell: Vector2i = stack.pop_back()
				size += 1
				for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var next: Vector2i = cell + step
					if not seen.has(next) and _walkable(definition, grid, next, extra_blocked):
						seen[next] = true
						stack.append(next)
			best = maxi(best, size)
	return best


func _walkable(
	definition: MapDefinition, grid: MapTerrainGrid, cell: Vector2i, extra_blocked: Dictionary
) -> bool:
	return not extra_blocked.has(cell) and MapVerification.is_walkable_cell(definition, grid, cell)


func _count_collision(node: Node) -> int:
	var count := 1 if node is CollisionObject3D or node is CollisionShape3D else 0
	for child in node.get_children():
		count += _count_collision(child)
	return count
