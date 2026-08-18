class_name MapCompositionAudit
extends RefCounted

## Evidence-driven composition metrics and threshold checks for P1-036.
## Threshold bands come from docs/data/map_composition_thresholds.json, which
## mirrors the signed P0-072 dossier ranges in docs/HISTORICAL_AUDIT.md.

const VIOLATION_EXCESS_COBBLE := &"MAP_COMPOSITION_EXCESS_COBBLE"
const VIOLATION_SURFACE_SHARE := &"MAP_COMPOSITION_SURFACE_SHARE"
const VIOLATION_DENSITY := &"MAP_COMPOSITION_DENSITY"
const VIOLATION_REPEATED_STYLE := &"MAP_COMPOSITION_REPEATED_STYLE"
const VIOLATION_EMPTY_REGION := &"MAP_COMPOSITION_EMPTY_REGION"
const VIOLATION_ELEVATION_FLAT := &"MAP_COMPOSITION_ELEVATION_FLAT"
const VIOLATION_MISSING_LANDMARK := &"MAP_COMPOSITION_MISSING_LANDMARK"

const TerrainBuilder := preload("res://scripts/map/view3d/map_view_mesh_builder_terrain.gd")

const STONE_TERRAINS: Array[StringName] = [
	MapTypes.TERRAIN_COBBLESTONE,
	MapTypes.TERRAIN_STONE,
	MapTypes.TERRAIN_CASTLE_PAVING,
]

const EARTH_TERRAINS: Array[StringName] = [
	MapTypes.TERRAIN_DIRT,
	MapTypes.TERRAIN_MUD,
	MapTypes.TERRAIN_SAND,
	MapTypes.TERRAIN_FARM_SOIL,
	MapTypes.TERRAIN_TIMBER_FLOOR,
	MapTypes.TERRAIN_PLASTER,
	MapTypes.TERRAIN_ASH,
	MapTypes.TERRAIN_COAST_SAND,
]

const GRASS_TERRAINS: Array[StringName] = [
	MapTypes.TERRAIN_GRASS,
	MapTypes.TERRAIN_MEADOW,
	MapTypes.TERRAIN_HAY,
	MapTypes.TERRAIN_STRAW,
	MapTypes.TERRAIN_FOREST_FLOOR,
	MapTypes.TERRAIN_BOG,
]


static func measure(
	definition: MapDefinition,
	grid: MapTerrainGrid,
	authoring_contract: Dictionary = {},
) -> Dictionary:
	var interior := definition.suppresses_exterior_surroundings()
	var occupancy := _build_occupancy(definition, grid, interior)
	var surface := _surface_shares(grid, occupancy)
	var density := _built_density(occupancy)
	var style := _style_distribution(definition, interior)
	var excluded_open_cells := _excluded_open_region_cells(grid, authoring_contract)
	var empty_region := _largest_empty_region(grid, occupancy, excluded_open_cells)
	var elevation := _elevation_range(definition, grid)
	return {
		"map_id": definition.map_id,
		"surface_shares": surface,
		"built_density_pct": density,
		"style_counts": style.get("counts", {}),
		"max_style_share_pct": style.get("max_share_pct", 0.0),
		"largest_empty_region_cells": empty_region,
		"excluded_open_region_cells": excluded_open_cells.size(),
		"elevation_range": elevation,
		"developable_cells": occupancy.get("developable_cells", 0),
		"interior": interior,
	}


static func audit(
	definition: MapDefinition,
	grid: MapTerrainGrid,
	thresholds: Dictionary,
	authoring_contract: Dictionary = {},
) -> Array[Dictionary]:
	var violations: Array[Dictionary] = []
	var metrics := measure(definition, grid, authoring_contract)
	var map_id := String(definition.map_id)
	var source_refs: Array = thresholds.get("source_refs", [])

	if bool(thresholds.get("interior", metrics.get("interior", false))):
		return _audit_interior(definition, metrics, thresholds, source_refs)

	var surface: Dictionary = metrics["surface_shares"]
	var stone_band: Array = thresholds.get("surface_shares", {}).get("stone_pct", [])
	if not stone_band.is_empty():
		var stone_pct := float(surface.get("stone_pct", 0.0))
		if stone_pct < float(stone_band[0]) or stone_pct > float(stone_band[1]):
			(
				violations
				. append(
					_violation(
						VIOLATION_SURFACE_SHARE,
						map_id,
						"stone_pct",
						stone_pct,
						stone_band,
						source_refs,
					)
				)
			)
		var cobble_cap: float = float(thresholds.get("max_cobblestone_pct", stone_band[1]))
		var cobble_pct := float(surface.get("cobblestone_pct", 0.0))
		if cobble_pct > cobble_cap:
			(
				violations
				. append(
					_violation(
						VIOLATION_EXCESS_COBBLE,
						map_id,
						"cobblestone_pct",
						cobble_pct,
						[0.0, cobble_cap],
						source_refs,
					)
				)
			)

	for band_key in ["earth_pct", "grass_pct"]:
		var band: Array = thresholds.get("surface_shares", {}).get(band_key, [])
		if band.is_empty():
			continue
		var measured := float(surface.get(band_key, 0.0))
		if measured < float(band[0]) or measured > float(band[1]):
			(
				violations
				. append(
					_violation(
						VIOLATION_SURFACE_SHARE,
						map_id,
						band_key,
						measured,
						band,
						source_refs,
					)
				)
			)

	var density_band: Array = thresholds.get("built_density_pct", [])
	if not density_band.is_empty():
		var built_pct := float(metrics.get("built_density_pct", 0.0))
		if built_pct < float(density_band[0]) or built_pct > float(density_band[1]):
			(
				violations
				. append(
					_violation(
						VIOLATION_DENSITY,
						map_id,
						"built_density_pct",
						built_pct,
						density_band,
						source_refs,
					)
				)
			)

	var max_style_share: float = float(thresholds.get("max_style_share_pct", 100.0))
	if float(metrics.get("max_style_share_pct", 0.0)) > max_style_share:
		(
			violations
			. append(
				_violation(
					VIOLATION_REPEATED_STYLE,
					map_id,
					"max_style_share_pct",
					float(metrics["max_style_share_pct"]),
					[0.0, max_style_share],
					source_refs,
				)
			)
		)

	var max_empty: int = int(thresholds.get("max_empty_region_cells", 1_000_000))
	if int(metrics.get("largest_empty_region_cells", 0)) > max_empty:
		(
			violations
			. append(
				_violation(
					VIOLATION_EMPTY_REGION,
					map_id,
					"largest_empty_region_cells",
					float(metrics["largest_empty_region_cells"]),
					[0.0, float(max_empty)],
					source_refs,
				)
			)
		)

	var elevation_min: float = float(thresholds.get("elevation_range_min", 0.0))
	if elevation_min > 0.0:
		var elevation_range: float = float(metrics.get("elevation_range", 0.0))
		if elevation_range < elevation_min:
			(
				violations
				. append(
					_violation(
						VIOLATION_ELEVATION_FLAT,
						map_id,
						"elevation_range",
						elevation_range,
						[elevation_min, 999.0],
						source_refs,
					)
				)
			)

	for landmark_id in thresholds.get("required_landmark_building_ids", []):
		if not _has_building_id(definition, StringName(String(landmark_id))):
			(
				violations
				. append(
					{
						"code": VIOLATION_MISSING_LANDMARK,
						"map_id": map_id,
						"metric": "required_landmark_building_ids",
						"measured": landmark_id,
						"expected": "present",
						"source_refs": source_refs,
						"message":
						"%s missing required landmark building `%s`" % [map_id, landmark_id],
					}
				)
			)

	return violations


static func format_violation(violation: Dictionary) -> String:
	return (
		"ERROR[%s] (map=%s, metric=%s): measured %s, expected %s; sources=%s"
		% [
			String(violation.get("code", &"")),
			String(violation.get("map_id", "")),
			String(violation.get("metric", "")),
			str(violation.get("measured", "")),
			str(violation.get("expected", "")),
			", ".join(violation.get("source_refs", [])),
		]
	)


static func _audit_interior(
	definition: MapDefinition,
	metrics: Dictionary,
	thresholds: Dictionary,
	source_refs: Array,
) -> Array[Dictionary]:
	var violations: Array[Dictionary] = []
	var map_id := String(definition.map_id)
	var surface: Dictionary = metrics["surface_shares"]
	for band_name in ["timber_pct", "stone_pct", "earth_pct"]:
		var band: Array = thresholds.get("surface_shares", {}).get(band_name, [])
		if band.is_empty():
			continue
		var measured := float(surface.get(band_name, 0.0))
		if measured < float(band[0]) or measured > float(band[1]):
			(
				violations
				. append(
					_violation(
						VIOLATION_SURFACE_SHARE,
						map_id,
						band_name,
						measured,
						band,
						source_refs,
					)
				)
			)
	var open_band: Array = thresholds.get("open_floor_pct", [])
	if not open_band.is_empty():
		var open_pct := 100.0 - float(metrics.get("built_density_pct", 100.0))
		if open_pct < float(open_band[0]) or open_pct > float(open_band[1]):
			(
				violations
				. append(
					_violation(
						VIOLATION_DENSITY,
						map_id,
						"open_floor_pct",
						open_pct,
						open_band,
						source_refs,
					)
				)
			)
	for landmark_id in thresholds.get("required_landmark_building_ids", []):
		if not _has_building_id(definition, StringName(String(landmark_id))):
			(
				violations
				. append(
					{
						"code": VIOLATION_MISSING_LANDMARK,
						"map_id": map_id,
						"metric": "required_landmark_building_ids",
						"measured": landmark_id,
						"expected": "present",
						"source_refs": source_refs,
						"message":
						"%s missing required landmark building `%s`" % [map_id, landmark_id],
					}
				)
			)
	return violations


static func _violation(
	code: StringName,
	map_id: String,
	metric: String,
	measured: float,
	expected_band: Array,
	source_refs: Array,
) -> Dictionary:
	return {
		"code": code,
		"map_id": map_id,
		"metric": metric,
		"measured": measured,
		"expected": "%s-%s" % [expected_band[0], expected_band[1]],
		"source_refs": source_refs,
		"message":
		(
			"%s %s measured %s outside %s-%s"
			% [map_id, metric, measured, expected_band[0], expected_band[1]]
		),
	}


static func _build_occupancy(
	definition: MapDefinition, grid: MapTerrainGrid, interior: bool
) -> Dictionary:
	var built_cells: Dictionary = {}
	var developable_cells := 0
	var water_cells := 0
	for y in grid.size_cells.y:
		for x in grid.size_cells.x:
			var cell := Vector2i(x, y)
			var terrain := grid.get_terrain(cell)
			if MapTypes.WATER_TERRAINS.has(terrain):
				water_cells += 1
				continue
			developable_cells += 1
	for building in definition.buildings:
		if not _counts_toward_density(building, interior):
			continue
		for cell in _footprint_cells(definition, building):
			if not _cell_inside(grid, cell):
				continue
			if MapTypes.WATER_TERRAINS.has(grid.get_terrain(cell)):
				continue
			built_cells[cell] = true
	return {
		"built_cells": built_cells,
		"developable_cells": developable_cells,
		"water_cells": water_cells,
	}


static func _surface_shares(grid: MapTerrainGrid, occupancy: Dictionary) -> Dictionary:
	var built_cells: Dictionary = occupancy["built_cells"]
	var stone := 0
	var cobblestone := 0
	var earth := 0
	var grass := 0
	var timber := 0
	var unbuilt_total := 0
	for y in grid.size_cells.y:
		for x in grid.size_cells.x:
			var cell := Vector2i(x, y)
			var terrain := grid.get_terrain(cell)
			if MapTypes.WATER_TERRAINS.has(terrain):
				continue
			if built_cells.has(cell):
				continue
			unbuilt_total += 1
			if terrain == MapTypes.TERRAIN_COBBLESTONE:
				cobblestone += 1
				stone += 1
			elif STONE_TERRAINS.has(terrain):
				stone += 1
			elif EARTH_TERRAINS.has(terrain):
				if terrain == MapTypes.TERRAIN_TIMBER_FLOOR:
					timber += 1
				else:
					earth += 1
			elif GRASS_TERRAINS.has(terrain):
				grass += 1
			elif terrain == MapTypes.TERRAIN_TIMBER_FLOOR:
				timber += 1
	if unbuilt_total <= 0:
		return {
			"stone_pct": 0.0,
			"cobblestone_pct": 0.0,
			"earth_pct": 0.0,
			"grass_pct": 0.0,
			"timber_pct": 0.0,
			"unbuilt_cells": 0,
		}
	return {
		"stone_pct": 100.0 * float(stone) / float(unbuilt_total),
		"cobblestone_pct": 100.0 * float(cobblestone) / float(unbuilt_total),
		"earth_pct": 100.0 * float(earth) / float(unbuilt_total),
		"grass_pct": 100.0 * float(grass) / float(unbuilt_total),
		"timber_pct": 100.0 * float(timber) / float(unbuilt_total),
		"unbuilt_cells": unbuilt_total,
	}


static func _built_density(occupancy: Dictionary) -> float:
	var developable: int = occupancy.get("developable_cells", 0)
	if developable <= 0:
		return 0.0
	var built_cells: Dictionary = occupancy.get("built_cells", {})
	return 100.0 * float(built_cells.size()) / float(developable)


static func _style_distribution(definition: MapDefinition, interior: bool) -> Dictionary:
	var counts: Dictionary = {}
	var total := 0
	for building in definition.buildings:
		if not _counts_toward_density(building, interior):
			continue
		var style := String(building.get("style", building.get("wall_material", "unknown")))
		if style.is_empty():
			style = "unknown"
		counts[style] = int(counts.get(style, 0)) + 1
		total += 1
	if total <= 0:
		return {"counts": counts, "max_share_pct": 0.0}
	var max_count := 0
	for style in counts:
		max_count = maxi(max_count, int(counts[style]))
	return {
		"counts": counts,
		"max_share_pct": 100.0 * float(max_count) / float(total),
	}


static func _largest_empty_region(
	grid: MapTerrainGrid,
	occupancy: Dictionary,
	excluded_cells: Dictionary = {},
) -> int:
	var built_cells: Dictionary = occupancy["built_cells"]
	var visited: Dictionary = {}
	var largest := 0
	for y in grid.size_cells.y:
		for x in grid.size_cells.x:
			var start := Vector2i(x, y)
			if visited.has(start) or built_cells.has(start) or excluded_cells.has(start):
				continue
			var terrain := grid.get_terrain(start)
			if MapTypes.WATER_TERRAINS.has(terrain):
				continue
			var size := _flood_empty_region(grid, start, built_cells, visited, excluded_cells)
			largest = maxi(largest, size)
	return largest


static func _flood_empty_region(
	grid: MapTerrainGrid,
	start: Vector2i,
	built_cells: Dictionary,
	visited: Dictionary,
	excluded_cells: Dictionary = {},
) -> int:
	var queue: Array[Vector2i] = [start]
	var size := 0
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if visited.has(cell) or built_cells.has(cell) or excluded_cells.has(cell):
			continue
		if not _cell_inside(grid, cell):
			continue
		if MapTypes.WATER_TERRAINS.has(grid.get_terrain(cell)):
			continue
		visited[cell] = true
		size += 1
		queue.append(cell + Vector2i.LEFT)
		queue.append(cell + Vector2i.RIGHT)
		queue.append(cell + Vector2i.UP)
		queue.append(cell + Vector2i.DOWN)
	return size


static func _excluded_open_region_cells(
	grid: MapTerrainGrid,
	authoring_contract: Dictionary,
) -> Dictionary:
	var excluded: Dictionary = {}
	for region in authoring_contract.get("open_regions", []):
		if not bool(region.get("exclude_from_unowned_empty_region", false)):
			continue
		var bounds: Array = region.get("bounds_cells", [])
		if bounds.size() != 4:
			continue
		var rect := Rect2i(
			int(bounds[0]),
			int(bounds[1]),
			int(bounds[2]),
			int(bounds[3]),
		)
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var cell := Vector2i(x, y)
				if _cell_inside(grid, cell) and not MapTypes.WATER_TERRAINS.has(grid.get_terrain(cell)):
					excluded[cell] = true
	return excluded


static func _elevation_range(definition: MapDefinition, grid: MapTerrainGrid) -> float:
	if definition.suppresses_exterior_surroundings():
		return 0.0
	var field := TerrainBuilder.ensure_height_field(definition, grid)
	if bool(field.get("flat_floor", false)):
		return 0.0
	var min_height := INF
	var max_height := -INF
	var step := maxi(1, mini(grid.size_cells.x, grid.size_cells.y) / 16)
	for y in range(0, grid.size_cells.y, step):
		for x in range(0, grid.size_cells.x, step):
			if MapTypes.WATER_TERRAINS.has(grid.get_terrain(Vector2i(x, y))):
				continue
			var height := TerrainBuilder.field_height(
				field, Vector2(float(x) + 0.5, float(y) + 0.5)
			)
			min_height = minf(min_height, height)
			max_height = maxf(max_height, height)
	if not is_finite(min_height) or not is_finite(max_height):
		return 0.0
	return max_height - min_height


static func _counts_toward_density(building: Dictionary, interior: bool) -> bool:
	var kind: StringName = building.get("kind", MapTypes.BUILDING_KIND_HOUSE)
	if interior:
		return (
			kind == MapTypes.BUILDING_KIND_HOUSE
			or kind == MapTypes.BUILDING_KIND_INTERIOR_BLOCK
			or kind == MapTypes.BUILDING_KIND_INTERIOR_WALL
			or kind == MapTypes.BUILDING_KIND_WALL
		)
	return kind == MapTypes.BUILDING_KIND_HOUSE or kind == MapTypes.BUILDING_KIND_INTERIOR_BLOCK


static func _footprint_cells(definition: MapDefinition, building: Dictionary) -> Array[Vector2i]:
	var footprint: Rect2 = building["footprint"]
	var pixel := float(definition.cell_size)
	var cell_rect := Rect2i(
		int(floor(footprint.position.x / pixel)),
		int(floor(footprint.position.y / pixel)),
		maxi(1, int(ceil(footprint.size.x / pixel))),
		maxi(1, int(ceil(footprint.size.y / pixel))),
	)
	var cells: Array[Vector2i] = []
	for y in range(cell_rect.position.y, cell_rect.end.y):
		for x in range(cell_rect.position.x, cell_rect.end.x):
			cells.append(Vector2i(x, y))
	return cells


static func _has_building_id(definition: MapDefinition, building_id: StringName) -> bool:
	for building in definition.buildings:
		if building.get("id", &"") == building_id:
			return true
	return false


static func _cell_inside(grid: MapTerrainGrid, cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid.size_cells.x and cell.y < grid.size_cells.y
