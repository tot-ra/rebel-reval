class_name MapTerrainMovement
extends RefCounted

## Resolves locomotion speed penalties from authored terrain variants, bushes, and
## rain-softened mud. Weather remains an optional input so logic-only maps retain
## deterministic dry-terrain behavior.

const MUD_DRY_SPEED_MULTIPLIER := 0.88
const MUD_SATURATED_SPEED_MULTIPLIER := 0.58
## Same tolerance as the MAP_RELIEF_SLOPE validator, so a face exactly at the
## 1/64-quantised limit is walkable in both places.
const RELIEF_RISE_EPSILON := 0.0001
## Point props without a footprint slow inside this world-unit radius.
const POINT_PROP_RADIUS := 24.0
const _NEIGHBOR_CELLS: Array[Vector2i] = [
	Vector2i.ZERO,
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i(-1, -1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(1, 1),
]

## Per MapDefinition instance: slowing props bucketed by overlapping cells.
static var _prop_index_cache: Dictionary = {}


static func speed_multiplier_at(
	definition: MapDefinition,
	grid: MapTerrainGrid,
	world_position: Vector2,
	mud_wetness: float = 0.0
) -> float:
	return _speed_multiplier_at(definition, grid, world_position, mud_wetness, true)


## Linear scan used by tests to prove the cell index matches the old loop.
static func speed_multiplier_at_linear(
	definition: MapDefinition,
	grid: MapTerrainGrid,
	world_position: Vector2,
	mud_wetness: float = 0.0
) -> float:
	return _speed_multiplier_at(definition, grid, world_position, mud_wetness, false)


static func slowing_prop_index_size(definition: MapDefinition) -> int:
	if definition == null:
		return 0
	return int(_index_for(definition).get("slowing_count", 0))


static func _speed_multiplier_at(
	definition: MapDefinition,
	grid: MapTerrainGrid,
	world_position: Vector2,
	mud_wetness: float,
	use_index: bool
) -> float:
	if definition == null or grid == null:
		return 1.0
	var cell := _world_to_cell(definition, world_position)
	var multiplier := grid.get_movement_speed_multiplier(cell)
	if grid.get_terrain(cell) == MapTypes.TERRAIN_MUD:
		multiplier = minf(multiplier, mud_speed_multiplier(mud_wetness))
	if use_index:
		multiplier = minf(
			multiplier, _indexed_prop_multiplier_at(definition, cell, world_position)
		)
	else:
		for prop in definition.props:
			multiplier = minf(multiplier, _prop_multiplier_at(prop, world_position))
	multiplier *= slope_speed_multiplier(definition, world_position)
	return TerrainVegetation.clamp_speed_multiplier(multiplier)


## ADR 0023 / WB-03 (R-975): speed scales by cos(slope) of the compiled ground up
## to the walkable limit. Steeper ground is impassable, so the curve never goes
## below cos(35 deg) ~= 0.82. The ADR curve is direction-free, so descending a
## bank costs the same as climbing it; it is monotonic in slope either way.
static func slope_speed_multiplier(definition: MapDefinition, world_position: Vector2) -> float:
	if not has_relief(definition):
		return 1.0
	return slope_cost_multiplier(definition.slope_at_world(world_position))


static func slope_cost_multiplier(slope: float) -> float:
	return cos(clampf(slope, 0.0, MapDefinition.RELIEF_MAX_WALKABLE_SLOPE))


## True when the definition has any non-planar ground (compiled relief or an
## `elevation=` datum with its edge taper). Flat maps skip every relief query.
static func has_relief(definition: MapDefinition) -> bool:
	return not definition.relief_heights.is_empty() or definition.ground_elevation != 0.0


## True when some cell of the map can be relief-blocked. The datum taper is a
## smoothstep over DATUM_TAPER_CELLS, whose steepest rise is 1.5 * datum / taper
## per cell; a datum below the walkable rise can never block, so today's flat and
## `elevation=` maps keep their walkable-cell census exactly.
static func relief_can_block(definition: MapDefinition) -> bool:
	if not definition.relief_heights.is_empty():
		return true
	var datum_rise := 1.5 * absf(definition.ground_elevation) / MapDefinition.DATUM_TAPER_CELLS
	return datum_rise > tan(MapDefinition.RELIEF_MAX_WALKABLE_SLOPE)


## ADR 0023: a cell is impassable when any 4-neighbour face it shares is steeper
## than the walkable slope, or crosses an authored relief_cliff. Both cells of such
## a face are blocked, so a cliff reads as a band nobody can stand in rather than a
## ledge whose outcome depends on walking direction. Pure and thread-safe: the nav
## bake calls it on a worker.
static func is_relief_blocked_cell(definition: MapDefinition, cell: Vector2i) -> bool:
	if not relief_can_block(definition):
		return false
	var size := definition.size_cells
	if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y:
		return false
	var max_rise := tan(MapDefinition.RELIEF_MAX_WALKABLE_SLOPE) + RELIEF_RISE_EPSILON
	var here := definition.height_at(cell)
	for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbor: Vector2i = cell + offset
		if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= size.x or neighbor.y >= size.y:
			continue
		if absf(here - definition.height_at(neighbor)) > max_rise:
			return true
		for feature in definition.relief_features:
			if feature.get("kind") != &"cliff":
				continue
			if is_cliff_lowered(feature, cell) != is_cliff_lowered(feature, neighbor):
				return true
	return false


## Single-cell form of MapBlueprintCompilerExpandTerrain.cliff_lowered_mask (the
## compiler builds the whole-map mask; walkability needs one cell at a time).
## test_relief_traversal pins the two to the same answer on every cell.
static func is_cliff_lowered(feature: Dictionary, cell: Vector2i) -> bool:
	var start := Vector2(feature["start"])
	var direction := Vector2(feature["end"]) - start
	var length := direction.length()
	if length <= 0.0:
		return false
	direction /= length
	var offset := Vector2(cell) - start
	var along := offset.dot(direction)
	if along < 0.0 or along > length:
		return false
	return direction.x * offset.y - direction.y * offset.x > 0.0


static func mud_speed_multiplier(wetness: float) -> float:
	# Freshly saturated mud yields underfoot; granular dry mud still drags a little.
	var saturation := smoothstep(0.0, 1.0, clampf(wetness, 0.0, 1.0))
	return lerpf(MUD_DRY_SPEED_MULTIPLIER, MUD_SATURATED_SPEED_MULTIPLIER, saturation)


static func _prop_multiplier_at(prop: Dictionary, world_position: Vector2) -> float:
	var authored: Variant = prop.get("movement_speed_multiplier")
	var kind_value: Variant = prop.get("kind", &"")
	var kind: StringName = kind_value
	var base := TerrainVegetation.resolved_prop_speed(kind, authored)
	if base >= 1.0:
		return 1.0
	if prop.has("footprint"):
		var footprint: Rect2 = prop["footprint"]
		if footprint.has_point(world_position):
			return base
		return 1.0
	var position: Vector2 = prop.get("position", Vector2.ZERO)
	if position.distance_squared_to(world_position) <= POINT_PROP_RADIUS * POINT_PROP_RADIUS:
		return base
	return 1.0


static func _world_to_cell(definition: MapDefinition, world_position: Vector2) -> Vector2i:
	var cell_size := float(definition.cell_size)
	return Vector2i(
		int(floor(world_position.x / cell_size)),
		int(floor(world_position.y / cell_size))
	)


static func _indexed_prop_multiplier_at(
	definition: MapDefinition, cell: Vector2i, world_position: Vector2
) -> float:
	var index := _index_for(definition)
	var cells: Dictionary = index.get("cells", {})
	var multiplier := 1.0
	# WHY: index buckets a prop into every overlapping cell; neighbours cover
	# cell-boundary float error without scanning the whole dressed district.
	for offset in _NEIGHBOR_CELLS:
		var bucket: Variant = cells.get(cell + offset)
		if not (bucket is Array):
			continue
		var bucket_props: Array = bucket
		for prop: Dictionary in bucket_props:
			multiplier = minf(multiplier, _prop_multiplier_at(prop, world_position))
	return multiplier


static func _index_for(definition: MapDefinition) -> Dictionary:
	var key := definition.get_instance_id()
	var cached: Variant = _prop_index_cache.get(key)
	if cached is Dictionary:
		var entry: Dictionary = cached
		var holder_value: Variant = entry.get("holder")
		var holder := holder_value as WeakRef
		if (
			holder != null
			and holder.get_ref() == definition
			and String(entry.get("fingerprint", "")) == definition.fingerprint
			and int(entry.get("prop_count", -1)) == definition.props.size()
		):
			return entry
	var built := _build_prop_index(definition)
	_prune_prop_index_cache()
	_prop_index_cache[key] = built
	return built


static func _build_prop_index(definition: MapDefinition) -> Dictionary:
	var cells := {}
	var slowing_count := 0
	var cell_size: int = definition.cell_size
	for prop in definition.props:
		var authored: Variant = prop.get("movement_speed_multiplier")
		var kind_value: Variant = prop.get("kind", &"")
		var kind: StringName = kind_value
		if TerrainVegetation.resolved_prop_speed(kind, authored) >= 1.0:
			continue
		slowing_count += 1
		for cell in _cells_for_slowing_prop(prop, cell_size):
			if not cells.has(cell):
				var bucket: Array[Dictionary] = []
				cells[cell] = bucket
			(cells[cell] as Array).append(prop)
	return {
		"holder": weakref(definition),
		"fingerprint": definition.fingerprint,
		"prop_count": definition.props.size(),
		"slowing_count": slowing_count,
		"cells": cells,
	}


static func _cells_for_slowing_prop(prop: Dictionary, cell_size: int) -> Array[Vector2i]:
	if cell_size <= 0:
		return []
	if prop.has("footprint"):
		var footprint: Rect2 = prop["footprint"]
		return _cells_overlapping_world_rect(footprint, cell_size)
	var position: Vector2 = prop.get("position", Vector2.ZERO)
	var extent := Vector2(POINT_PROP_RADIUS, POINT_PROP_RADIUS)
	return _cells_overlapping_world_rect(Rect2(position - extent, extent * 2.0), cell_size)


static func _cells_overlapping_world_rect(rect: Rect2, cell_size: int) -> Array[Vector2i]:
	# Rect2.has_point excludes the right/bottom edges, so the last covered cell
	# is the one holding (end - epsilon), not the cell of the exclusive end.
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return []
	var scale := float(cell_size)
	var min_cell := Vector2i(
		int(floor(rect.position.x / scale)), int(floor(rect.position.y / scale))
	)
	var max_cell := Vector2i(
		int(floor((rect.position.x + rect.size.x - 0.0001) / scale)),
		int(floor((rect.position.y + rect.size.y - 0.0001) / scale))
	)
	var cells: Array[Vector2i] = []
	for y in range(min_cell.y, max_cell.y + 1):
		for x in range(min_cell.x, max_cell.x + 1):
			cells.append(Vector2i(x, y))
	return cells


static func _prune_prop_index_cache() -> void:
	if _prop_index_cache.size() < 32:
		return
	var dead: Array = []
	for key in _prop_index_cache.keys():
		var entry: Variant = _prop_index_cache[key]
		if not (entry is Dictionary):
			dead.append(key)
			continue
		var holder_value: Variant = (entry as Dictionary).get("holder")
		var holder := holder_value as WeakRef
		if holder == null or holder.get_ref() == null:
			dead.append(key)
	for key in dead:
		_prop_index_cache.erase(key)
