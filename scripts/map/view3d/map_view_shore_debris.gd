class_name MapViewShoreDebris
extends RefCounted

## CO-02 shore debris scatter (P0-185 shard).
##
## WHY: MapViewTerrainDetails owned two change axes - first-person grass cover
## and always-built coastline scatter. Shore placements, GLB loading, and
## blocking-cell math change with CO-02 / R-1094 independently of vegetation
## realism. Keep the MapViewTerrainDetails public API as a facade so existing
## tests and MapViewMeshBuilderScatter still call one owner.

const SHORE_DEBRIS_DIR := "res://assets/props/environment/shore/"
const SHORE_BOULDER_SMALL := &"boulder_small"
const SHORE_BOULDER_MEDIUM := &"boulder_medium"
const SHORE_BOULDER_LARGE := &"boulder_large"
const SHORE_BOULDER_BARNACLED := &"boulder_barnacled"
const SHORE_STONE_CLUSTER_A := &"stone_cluster_a"
const SHORE_STONE_CLUSTER_B := &"stone_cluster_b"
const SHORE_PEBBLE_PATCH_A := &"pebble_patch_a"
const SHORE_PEBBLE_PATCH_B := &"pebble_patch_b"
const SHORE_WRACK_LINE_A := &"wrack_line_a"
const SHORE_WRACK_LINE_B := &"wrack_line_b"
const SHORE_ALGAE_SKIRT := &"algae_skirt"
## kind -> [GLB, nominal diameter in metres (0 = flat dressing), casts shadow,
## boulder height in metres from tools/build_shore_debris.py's report].
const SHORE_DEBRIS_KINDS := {
	SHORE_BOULDER_SMALL: ["shore_boulder_granite_small.glb", 0.6, true, 0.369],
	SHORE_BOULDER_MEDIUM: ["shore_boulder_granite_medium.glb", 1.2, true, 0.741],
	SHORE_BOULDER_LARGE: ["shore_boulder_granite_large.glb", 2.1, true, 1.187],
	SHORE_BOULDER_BARNACLED: ["shore_boulder_granite_barnacled.glb", 1.6, true, 1.204],
	SHORE_STONE_CLUSTER_A: ["shore_stone_cluster_a.glb", 0.0, true, 0.0],
	SHORE_STONE_CLUSTER_B: ["shore_stone_cluster_b.glb", 0.0, true, 0.0],
	SHORE_PEBBLE_PATCH_A: ["shore_pebble_patch_a.glb", 0.0, false, 0.0],
	SHORE_PEBBLE_PATCH_B: ["shore_pebble_patch_b.glb", 0.0, false, 0.0],
	SHORE_WRACK_LINE_A: ["shore_wrack_line_a.glb", 0.0, false, 0.0],
	SHORE_WRACK_LINE_B: ["shore_wrack_line_b.glb", 0.0, false, 0.0],
	SHORE_ALGAE_SKIRT: ["shore_algae_skirt.glb", 0.0, false, 0.0],
}
## Algae and barnacle crust live in the water; wrack rots at the swash line.
const SHORE_ALGAE_KINDS: Array[StringName] = [SHORE_ALGAE_SKIRT, SHORE_BOULDER_BARNACLED]
const SHORE_WRACK_KINDS: Array[StringName] = [SHORE_WRACK_LINE_A, SHORE_WRACK_LINE_B]
## CO-02: stones wider than this are obstacles; everything smaller is dressing.
const SHORE_BLOCKING_MIN_METRES := 1.0
## Hard cap per scatter chunk, applied in cell order so it is chunk-deterministic.
const SHORE_DEBRIS_MAX_PER_CHUNK := 384
## Signed shore-distance bands (cells, + = seaward).
const SHORE_WRACK_BAND := Vector2(-1.0, 0.25)
const SHORE_DRY_BAND := Vector2(-6.0, -1.2)
const SHORE_SHALLOWS_BAND := Vector2(0.3, 3.0)
const SHORE_ERRATIC_BAND := Vector2(0.6, 5.0)
## Prop anchors (boats, crates, cribs) keep this many cells of clear water/sand.
const SHORE_PROP_CLEARANCE := 2
const _SHORE_SEED := 9341

static var _shore_meshes: Dictionary = {}


# Boulders, stone clusters, shingle lenses, wrack and algae placed by signed
# distance to the WS-08 shore field (positive = water side, in cells). Every
# decision is a pure function of (map seed, cell) plus map-global data, so a
# chunk yields the same instances whatever order chunks load in. Debris is part
# of the always-built scatter chunk: an erratic in the shallows has to read at
# the gameplay camera.


## View node for one scatter chunk: one MultiMesh per debris kind.
static func build_shore_debris(
	definition: MapDefinition, grid: MapTerrainGrid, cell_bounds: Rect2i
) -> Node3D:
	var root := Node3D.new()
	root.name = "ShoreDebris"
	var by_kind: Dictionary = {}
	for placement in shore_debris_placements(definition, grid, cell_bounds):
		var kind: StringName = placement["kind"]
		if not by_kind.has(kind):
			by_kind[kind] = [[] as Array[Transform3D], [] as Array[Color]]
		by_kind[kind][0].append(placement["transform"])
		by_kind[kind][1].append(placement["color"])
	var kinds := by_kind.keys()
	kinds.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for kind: StringName in kinds:
		var mesh := shore_debris_mesh(kind)
		if mesh == null:
			continue
		# Surface materials live on the mesh, so no override: the barnacled
		# boulder keeps its granite crown and crusted foot on one instance.
		var layer := MapViewMeshBuilderPrimitives.multi_mesh(
			"Shore_%s" % String(kind), mesh, by_kind[kind][0], by_kind[kind][1], null, Vector3.ZERO
		)
		layer.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if bool(SHORE_DEBRIS_KINDS[kind][2])
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
		root.add_child(layer)
	return root


## Imported GLB mesh with the shared CO-02 family materials bound per surface.
static func shore_debris_mesh(kind: StringName) -> Mesh:
	var mesh: Mesh = _shore_meshes.get(kind, null)
	if mesh == null:
		mesh = _load_shore_debris_mesh(kind)
		if mesh == null:
			return null
		_shore_meshes[kind] = mesh
	# Rebound on every use: MapViewMaterials.reset() replaces the shared family
	# materials, and the slot name survives because each family material keeps it.
	for surface in mesh.get_surface_count():
		var imported := mesh.surface_get_material(surface)
		var family := StringName(imported.resource_name if imported != null else "")
		var shared := MapViewMaterials.shore_debris(family)
		if shared != null and shared != imported:
			mesh.surface_set_material(surface, shared)
	return mesh


static func _load_shore_debris_mesh(kind: StringName) -> Mesh:
	if not SHORE_DEBRIS_KINDS.has(kind):
		return null
	var scene := load(SHORE_DEBRIS_DIR + String(SHORE_DEBRIS_KINDS[kind][0])) as PackedScene
	if scene == null:
		push_error("CO-02 shore debris GLB missing for %s" % kind)
		return null
	var instance := scene.instantiate()
	var mesh: Mesh = null
	for node in instance.find_children("*", "MeshInstance3D", true, false):
		mesh = (node as MeshInstance3D).mesh
		break
	instance.free()
	return mesh


## Placements for the cells in `cell_bounds`: kind, cell, transform, colour,
## blocks and (for blocking stones) footprint cells. Deterministic and chunk-order
## independent; empty on maps without a beach shoreline.
static func shore_debris_placements(
	definition: MapDefinition, grid: MapTerrainGrid, cell_bounds: Rect2i
) -> Array[Dictionary]:
	var placements: Array[Dictionary] = []
	if definition.suppresses_exterior_surroundings():
		return placements
	var field := MapViewMeshBuilderTerrain.ensure_height_field(definition, grid)
	if field.get("flat_floor", false):
		return placements
	var shore := MapViewMeshBuilderTerrainWater.bake_shore_field(field, grid)
	if shore.is_empty() or not bool(shore.get("has_beach", false)):
		return placements
	var bounds := cell_bounds.intersection(Rect2i(Vector2i.ZERO, grid.size_cells))
	if bounds.size == Vector2i.ZERO:
		return placements
	var excluded := shore_debris_excluded_cells(definition)
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			_shore_debris_for_cell(
				placements, definition, grid, field, shore, excluded, Vector2i(x, y)
			)
			if placements.size() >= SHORE_DEBRIS_MAX_PER_CHUNK:
				placements.resize(SHORE_DEBRIS_MAX_PER_CHUNK)
				return placements
	return placements


## Cells whose stones stand as obstacles, for the whole map. Every one is already
## impassable water, so the walkable region is unchanged; swimming (WS-14b) and
## boats must treat these as solid.
static func shore_debris_blocking_cells(
	definition: MapDefinition, grid: MapTerrainGrid
) -> Dictionary:
	var cells: Dictionary = {}
	for placement in shore_debris_placements(
		definition, grid, Rect2i(Vector2i.ZERO, grid.size_cells)
	):
		if placement["blocks"]:
			for cell in placement["footprint"]:
				cells[cell] = true
	return cells


## Cells no debris may occupy: transitions, spawn, interaction anchors, prop
## footprints (boats, cribs, crates) with clearance, and building footprints.
static func shore_debris_excluded_cells(definition: MapDefinition) -> Dictionary:
	var excluded: Dictionary = {}
	var cell_size := float(maxi(definition.cell_size, 1))
	for transition in definition.transitions:
		_exclude_world_rect(excluded, transition.get("rect", Rect2()), cell_size, 1)
	_exclude_world_point(excluded, definition.player_spawn, cell_size, 1)
	for anchor in definition.interaction_anchors:
		_exclude_world_point(
			excluded, anchor.get("position", Vector2(-1.0e6, -1.0e6)), cell_size, 1
		)
	for prop in definition.props:
		if prop.has("footprint"):
			_exclude_world_rect(excluded, prop["footprint"], cell_size, SHORE_PROP_CLEARANCE)
		_exclude_world_point(
			excluded, prop.get("position", Vector2(-1.0e6, -1.0e6)), cell_size, SHORE_PROP_CLEARANCE
		)
	for building in definition.buildings:
		_exclude_world_rect(excluded, building.get("footprint", Rect2()), cell_size, 1)
	# excluded_areas are deliberately not reserved: harbours use them to make
	# the shallow band impassable, which is exactly where erratics belong.
	return excluded


static func _exclude_world_rect(
	excluded: Dictionary, rect: Rect2, cell_size: float, grow: int
) -> void:
	if rect.size == Vector2.ZERO:
		return
	var start := Vector2i(floori(rect.position.x / cell_size), floori(rect.position.y / cell_size))
	var end := Vector2i(ceili(rect.end.x / cell_size), ceili(rect.end.y / cell_size))
	for y in range(start.y - grow, end.y + grow):
		for x in range(start.x - grow, end.x + grow):
			excluded[Vector2i(x, y)] = true


static func _exclude_world_point(
	excluded: Dictionary, point: Vector2, cell_size: float, grow: int
) -> void:
	var cell := Vector2i(floori(point.x / cell_size), floori(point.y / cell_size))
	for y in range(cell.y - grow, cell.y + grow + 1):
		for x in range(cell.x - grow, cell.x + grow + 1):
			excluded[Vector2i(x, y)] = true


static func _shore_debris_for_cell(
	placements: Array[Dictionary],
	definition: MapDefinition,
	grid: MapTerrainGrid,
	field: Dictionary,
	shore: Dictionary,
	excluded: Dictionary,
	cell: Vector2i
) -> void:
	if excluded.has(cell):
		return
	var terrain := grid.get_terrain(cell)
	var is_water := terrain in MapTypes.WATER_TERRAINS
	var is_beach := terrain in MapViewMeshBuilderTerrainWater.SHORE_BEACH_TERRAINS
	if not is_water and not is_beach:
		return
	var map_seed := definition.seed + _SHORE_SEED
	# 4x4 blocks carry at most one erratic, 2x2 blocks at most one piece of each
	# smaller layer; a block's candidate cell is hashed from the block alone.
	if is_water and _is_block_candidate(cell, 4, map_seed + 11):
		_place_erratic(placements, grid, field, shore, excluded, cell, map_seed)
	if not _is_block_candidate(cell, 2, map_seed + 29):
		return
	var centre := Vector2(cell) + Vector2(0.5, 0.5)
	if MapViewMeshBuilderTerrainWater.shore_type_at(shore, centre) < 0.5:
		return
	var d := MapViewMeshBuilderTerrainWater.shore_distance_at(shore, centre)
	if is_water and d >= SHORE_SHALLOWS_BAND.x and d <= SHORE_SHALLOWS_BAND.y:
		if MapViewMeshBuilderPrimitives.hash01(cell.x, cell.y, map_seed + 41) < 0.22:
			_place_submerged_stone(placements, field, cell, map_seed)
	if _surrounded_by_shore(grid, cell) and d >= SHORE_WRACK_BAND.x and d <= SHORE_WRACK_BAND.y:
		if MapViewMeshBuilderPrimitives.hash01(cell.x, cell.y, map_seed + 53) < 0.7:
			_place_wrack(placements, field, shore, cell, map_seed)
	if (
		is_beach
		and _surrounded_by_shore(grid, cell)
		and d >= SHORE_DRY_BAND.x
		and d <= SHORE_DRY_BAND.y
	):
		var falloff := 1.0 - 0.6 * inverse_lerp(-SHORE_DRY_BAND.y, -SHORE_DRY_BAND.x, -d)
		if MapViewMeshBuilderPrimitives.hash01(cell.x, cell.y, map_seed + 67) < 0.5 * falloff:
			_place_dry_stone(placements, field, cell, d, map_seed)


static func _is_block_candidate(cell: Vector2i, block: int, noise_seed: int) -> bool:
	var origin := Vector2i(floori(float(cell.x) / block), floori(float(cell.y) / block))
	var pick := Vector2i(
		mini(
			int(MapViewMeshBuilderPrimitives.hash01(origin.x, origin.y, noise_seed) * block),
			block - 1
		),
		mini(
			int(MapViewMeshBuilderPrimitives.hash01(origin.x, origin.y, noise_seed + 3) * block),
			block - 1
		)
	)
	return cell == origin * block + pick


## Sea and natural ground only, all eight neighbours: keeps debris off pier
## decks, timber landings, paved slips, tracks and roads that meet the sand.
static func _surrounded_by_shore(grid: MapTerrainGrid, cell: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var other := cell + Vector2i(dx, dy)
			if (
				other.x < 0
				or other.y < 0
				or other.x >= grid.size_cells.x
				or other.y >= grid.size_cells.y
			):
				continue
			var terrain := grid.get_terrain(other)
			if terrain in MapTypes.WATER_TERRAINS:
				continue
			# Dirt is left out: on the harbours it is the trodden shore track.
			if (
				terrain not in MapViewMeshBuilderConfig.NATURAL_SHORE_TERRAINS
				or terrain == MapTypes.TERRAIN_DIRT
			):
				return false
	return true


static func _place_erratic(
	placements: Array[Dictionary],
	grid: MapTerrainGrid,
	field: Dictionary,
	shore: Dictionary,
	excluded: Dictionary,
	cell: Vector2i,
	map_seed: int
) -> void:
	var centre := Vector2(cell) + Vector2(0.5, 0.5)
	if MapViewMeshBuilderTerrainWater.shore_type_at(shore, centre) < 0.5:
		return
	var d := MapViewMeshBuilderTerrainWater.shore_distance_at(shore, centre)
	if d < SHORE_ERRATIC_BAND.x or d > SHORE_ERRATIC_BAND.y:
		return
	if MapViewMeshBuilderPrimitives.hash01(cell.x, cell.y, map_seed + 101) >= 0.6:
		return
	var scale := lerpf(
		0.9, 1.25, MapViewMeshBuilderPrimitives.hash01(cell.x, cell.y, map_seed + 107)
	)
	var spot := centre + _cell_jitter(cell, map_seed + 109, 0.25)
	var bed := _sea_bed_y(field, spot)
	var depth := (
		MapViewMeshBuilderTerrain.field_height(field, spot)
		+ MapViewMeshBuilderConfig.WATER_SURFACE_LIFT
		- bed
	)
	var kind := _erratic_kind_for_depth(depth, scale, d, cell, map_seed)
	if kind == &"":
		return
	var diameter_cells := (
		float(SHORE_DEBRIS_KINDS[kind][1]) * scale / MapViewMaterials.METERS_PER_WORLD_UNIT
	)
	var footprint := _footprint_cells(spot, diameter_cells * 0.5)
	# The stone itself covers only open water, so the obstacle never takes a
	# walkable cell; a one-cell ring around it stays clear of reserved cells and
	# of anything but sea and beach, so no deck, landing or boat berth is crowded.
	for ring_cell in _footprint_cells(spot, diameter_cells * 0.5 + 1.0):
		if (
			ring_cell.x < 0
			or ring_cell.y < 0
			or ring_cell.x >= grid.size_cells.x
			or ring_cell.y >= grid.size_cells.y
			or excluded.has(ring_cell)
		):
			return
		var ring_terrain := grid.get_terrain(ring_cell)
		var in_footprint := ring_cell in footprint
		if (
			ring_terrain not in MapTypes.WATER_TERRAINS
			and (
				in_footprint
				or ring_terrain not in MapViewMeshBuilderTerrainWater.SHORE_BEACH_TERRAINS
			)
		):
			return
	var sink := _erratic_sink(kind, scale)
	var transform := _debris_transform(spot, bed - sink, scale, cell, map_seed + 113)
	var blocks := float(SHORE_DEBRIS_KINDS[kind][1]) * scale >= SHORE_BLOCKING_MIN_METRES
	(
		placements
		. append(
			{
				"kind": kind,
				"cell": cell,
				"shore_distance": d,
				"transform": transform,
				"color": _stone_tint(cell, map_seed + 127, 0.78),
				"blocks": blocks,
				"footprint": footprint if blocks else [] as Array[Vector2i],
			}
		)
	)
	_append_algae_skirt(placements, spot, bed, diameter_cells, cell, d, map_seed)


## Picks the erratic whose crown clears the water at this depth: the WS-13b basin
## drops fast, and a boulder hidden under the surface reads as nothing from the
## gameplay camera. The barnacled stone is chosen where its crusted foot lands at
## the waterline. A minority of stones stay drowned for the underwater view.
static func _erratic_kind_for_depth(
	depth: float, scale: float, shore_distance: float, cell: Vector2i, map_seed: int
) -> StringName:
	var roll := MapViewMeshBuilderPrimitives.hash01(cell.x, cell.y, map_seed + 103)
	var order: Array[StringName] = [SHORE_BOULDER_MEDIUM, SHORE_BOULDER_LARGE]
	if roll < 0.5:
		order = [SHORE_BOULDER_LARGE, SHORE_BOULDER_MEDIUM]
	if shore_distance < 2.6:
		order.push_front(SHORE_BOULDER_BARNACLED)
	for kind in order:
		var height := _erratic_height_cells(kind, scale)
		var emerged := (height - _erratic_sink(kind, scale) - depth) / height
		var band := Vector2(0.2, 0.85)
		if kind == SHORE_BOULDER_BARNACLED:
			# The crust reaches 55% of the height: keep the waterline near its edge.
			band = Vector2(0.3, 0.65)
		if emerged >= band.x and emerged <= band.y:
			return kind
	if MapViewMeshBuilderPrimitives.hash01(cell.x, cell.y, map_seed + 105) < 0.3:
		return order.back()
	return &""


static func _erratic_height_cells(kind: StringName, scale: float) -> float:
	return float(SHORE_DEBRIS_KINDS[kind][3]) * scale / MapViewMaterials.METERS_PER_WORLD_UNIT


## Settled into the bed by a tenth of its height, like a stone bedded in till.
static func _erratic_sink(kind: StringName, scale: float) -> float:
	return 0.1 * _erratic_height_cells(kind, scale)


static func _place_submerged_stone(
	placements: Array[Dictionary], field: Dictionary, cell: Vector2i, map_seed: int
) -> void:
	var spot := Vector2(cell) + Vector2(0.5, 0.5) + _cell_jitter(cell, map_seed + 131, 0.3)
	var scale := lerpf(
		0.8, 1.2, MapViewMeshBuilderPrimitives.hash01(cell.x, cell.y, map_seed + 137)
	)
	var bed := _sea_bed_y(field, spot)
	var diameter_cells := 0.6 * scale / MapViewMaterials.METERS_PER_WORLD_UNIT
	(
		placements
		. append(
			{
				"kind": SHORE_BOULDER_SMALL,
				"cell": cell,
				"shore_distance": _cell_shore_distance(field, spot),
				"transform": _debris_transform(spot, bed - 0.05, scale, cell, map_seed + 139),
				"color": _stone_tint(cell, map_seed + 149, 0.72),
				"blocks": false,
				"footprint": [] as Array[Vector2i],
			}
		)
	)
	_append_algae_skirt(
		placements, spot, bed, diameter_cells, cell, _cell_shore_distance(field, spot), map_seed
	)


static func _append_algae_skirt(
	placements: Array[Dictionary],
	spot: Vector2,
	bed: float,
	diameter_cells: float,
	cell: Vector2i,
	shore_distance: float,
	map_seed: int
) -> void:
	# The weed apron is 1 m across at its lip and 1.7 m at its foot; at 0.8 of
	# the stone's width the lip tucks under the flattened base and the clumps
	# spread onto the bed round it.
	var scale := diameter_cells * MapViewMaterials.METERS_PER_WORLD_UNIT * 0.8
	(
		placements
		. append(
			{
				"kind": SHORE_ALGAE_SKIRT,
				"cell": cell,
				"shore_distance": shore_distance,
				"transform": _debris_transform(spot, bed + 0.02, scale, cell, map_seed + 151),
				"color":
				Color(1.0, 1.0, 1.0).lerp(
					Color(0.82, 0.9, 0.78),
					MapViewMeshBuilderPrimitives.hash01(cell.x, cell.y, map_seed + 157)
				),
				"blocks": false,
				"footprint": [] as Array[Vector2i],
			}
		)
	)


static func _place_wrack(
	placements: Array[Dictionary],
	field: Dictionary,
	shore: Dictionary,
	cell: Vector2i,
	map_seed: int
) -> void:
	var spot := Vector2(cell) + Vector2(0.5, 0.5) + _cell_jitter(cell, map_seed + 163, 0.2)
	var d := MapViewMeshBuilderTerrainWater.shore_distance_at(shore, spot)
	if d < SHORE_WRACK_BAND.x or d > SHORE_WRACK_BAND.y:
		return
	# Drift lies along the swash line: local X follows the shore tangent.
	var towards_land := MapViewMeshBuilderTerrainWater.shore_direction_at(shore, spot)
	var tangent := Vector2(-towards_land.y, towards_land.x)
	var yaw := atan2(-tangent.y, tangent.x) if tangent.length_squared() > 0.0001 else 0.0
	yaw += (MapViewMeshBuilderPrimitives.hash01(cell.x, cell.y, map_seed + 167) - 0.5) * 0.5
	var kind := (
		SHORE_WRACK_LINE_A
		if MapViewMeshBuilderPrimitives.hash01(cell.x, cell.y, map_seed + 173) < 0.55
		else SHORE_WRACK_LINE_B
	)
	var scale := (
		lerpf(0.85, 1.15, MapViewMeshBuilderPrimitives.hash01(cell.x, cell.y, map_seed + 179))
		/ MapViewMaterials.METERS_PER_WORLD_UNIT
	)
	var transform := _ground_hugging_transform(
		field, spot, Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale), 0.01
	)
	(
		placements
		. append(
			{
				"kind": kind,
				"cell": cell,
				"shore_distance": d,
				"transform": transform,
				"color":
				Color(1.0, 1.0, 1.0).lerp(
					Color(0.86, 0.8, 0.7),
					MapViewMeshBuilderPrimitives.hash01(cell.x, cell.y, map_seed + 181)
				),
				"blocks": false,
				"footprint": [] as Array[Vector2i],
			}
		)
	)


static func _place_dry_stone(
	placements: Array[Dictionary], field: Dictionary, cell: Vector2i, d: float, map_seed: int
) -> void:
	var roll := MapViewMeshBuilderPrimitives.hash01(cell.x, cell.y, map_seed + 191)
	var kind := SHORE_BOULDER_SMALL
	# Shingle is thrown up in the storm ridge just above the line; loose stones
	# and the odd small erratic spread further up the beach.
	var storm_ridge := d > -3.5
	if roll < (0.55 if storm_ridge else 0.25):
		kind = (
			SHORE_PEBBLE_PATCH_A
			if MapViewMeshBuilderPrimitives.hash01(cell.x, cell.y, map_seed + 193) < 0.6
			else SHORE_PEBBLE_PATCH_B
		)
	elif roll < 0.86:
		kind = (
			SHORE_STONE_CLUSTER_A
			if MapViewMeshBuilderPrimitives.hash01(cell.x, cell.y, map_seed + 197) < 0.5
			else SHORE_STONE_CLUSTER_B
		)
	var spot := Vector2(cell) + Vector2(0.5, 0.5) + _cell_jitter(cell, map_seed + 199, 0.3)
	var scale := lerpf(
		0.82, 1.18, MapViewMeshBuilderPrimitives.hash01(cell.x, cell.y, map_seed + 211)
	)
	var y := MapViewMeshBuilderTerrain.field_height(field, spot)
	var transform := _debris_transform(spot, y, scale, cell, map_seed + 223)
	var color := _stone_tint(cell, map_seed + 227, 1.0)
	if kind == SHORE_BOULDER_SMALL:
		transform.origin.y -= 0.12 * 0.6 * scale / MapViewMaterials.METERS_PER_WORLD_UNIT
	elif kind in [SHORE_PEBBLE_PATCH_A, SHORE_PEBBLE_PATCH_B]:
		# A 2-3 m lens spans real beach relief: lie it on the local slope and
		# lift it clear, or the sand clips its faded rim into a hard cut edge.
		transform = _ground_hugging_transform(field, spot, transform.basis, 0.03)
		# Damp, sand-dusted shingle is darker than the clean CO-01 plate.
		color = Color(color.r * 0.74, color.g * 0.72, color.b * 0.7, 1.0)
	(
		placements
		. append(
			{
				"kind": kind,
				"cell": cell,
				"shore_distance": d,
				"transform": transform,
				"color": color,
				"blocks": false,
				"footprint": [] as Array[Vector2i],
			}
		)
	)


## Rendered sea bed (gameplay bed minus the WS-13b basin), so stones stand on
## the floor the player sees rather than on the water plane.
static func _sea_bed_y(field: Dictionary, spot: Vector2) -> float:
	return (
		MapViewMeshBuilderTerrain.field_height(field, spot)
		- MapViewMeshBuilderTerrain.basin_extra_depth(field, spot)
	)


static func _cell_shore_distance(field: Dictionary, spot: Vector2) -> float:
	var shore: Dictionary = field.get("shore_field", {})
	if shore.is_empty():
		return 0.0
	return MapViewMeshBuilderTerrainWater.shore_distance_at(shore, spot)


static func _cell_jitter(cell: Vector2i, noise_seed: int, reach: float) -> Vector2:
	return Vector2(
		(MapViewMeshBuilderPrimitives.hash01(cell.x, cell.y, noise_seed) - 0.5) * 2.0 * reach,
		(MapViewMeshBuilderPrimitives.hash01(cell.x, cell.y, noise_seed + 1) - 0.5) * 2.0 * reach
	)


static func _footprint_cells(spot: Vector2, radius: float) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(floori(spot.y - radius), floori(spot.y + radius) + 1):
		for x in range(floori(spot.x - radius), floori(spot.x + radius) + 1):
			# Closest point of the cell to the stone centre decides overlap.
			var nearest := Vector2(clampf(spot.x, x, x + 1), clampf(spot.y, y, y + 1))
			if nearest.distance_to(spot) <= radius:
				cells.append(Vector2i(x, y))
	return cells


## GLB metres -> world cells, random yaw and a small settle tilt.
static func _debris_transform(
	spot: Vector2, y: float, scale: float, cell: Vector2i, noise_seed: int
) -> Transform3D:
	var yaw := MapViewMeshBuilderPrimitives.hash01(cell.x, cell.y, noise_seed) * TAU
	var tilt := (MapViewMeshBuilderPrimitives.hash01(cell.x, cell.y, noise_seed + 5) - 0.5) * 0.16
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt)
	return Transform3D(
		basis.scaled(Vector3.ONE * scale / MapViewMaterials.METERS_PER_WORLD_UNIT),
		Vector3(spot.x, y, spot.y)
	)


## Tilts `basis` onto the terrain slope sampled half a cell around `spot` and
## lifts it by `lift` world units; used for flat dressing only.
static func _ground_hugging_transform(
	field: Dictionary, spot: Vector2, basis: Basis, lift: float
) -> Transform3D:
	var step := 0.5
	var east := MapViewMeshBuilderTerrain.field_height(field, spot + Vector2(step, 0.0))
	var west := MapViewMeshBuilderTerrain.field_height(field, spot - Vector2(step, 0.0))
	var south := MapViewMeshBuilderTerrain.field_height(field, spot + Vector2(0.0, step))
	var north := MapViewMeshBuilderTerrain.field_height(field, spot - Vector2(0.0, step))
	var normal := Vector3(west - east, 2.0 * step, north - south).normalized()
	var tilt := Basis(Quaternion(Vector3.UP, normal))
	var y := maxf(
		MapViewMeshBuilderTerrain.field_height(field, spot),
		maxf(maxf(east, west), maxf(south, north))
	)
	return Transform3D(tilt * basis, Vector3(spot.x, y + lift, spot.y))


## Grey-to-pink granite spread; `wet` < 1 darkens stones standing in the sea.
static func _stone_tint(cell: Vector2i, noise_seed: int, wet: float) -> Color:
	var tint := Color(0.9, 0.9, 0.92).lerp(
		Color(1.06, 0.97, 0.93), MapViewMeshBuilderPrimitives.hash01(cell.x, cell.y, noise_seed)
	)
	return Color(tint.r * wet, tint.g * wet, tint.b * wet, 1.0)
