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

## WB-10 dressing-and-ground density contract (R-982). These codes are a
## stable API like the ones above. Relief span reuses VIOLATION_ELEVATION_FLAT.
## Building appearance repetition is AR-13's metric and is deliberately absent.
const VIOLATION_PROP_DENSITY := &"MAP_COMPOSITION_PROP_DENSITY"
const VIOLATION_DECAL_DENSITY := &"MAP_COMPOSITION_DECAL_DENSITY"
const VIOLATION_PROP_VARIETY := &"MAP_COMPOSITION_PROP_VARIETY"
const VIOLATION_PROP_KIND_SHARE := &"MAP_COMPOSITION_PROP_KIND_SHARE"
const VIOLATION_GROUND_COVER := &"MAP_COMPOSITION_GROUND_COVER"
const VIOLATION_FOOTPRINT_RUN := &"MAP_COMPOSITION_FOOTPRINT_RUN"
const VIOLATION_TIER_SPREAD := &"MAP_COMPOSITION_TIER_SPREAD"

## Vegetation props count toward ground cover, not toward dressing density, so
## a district cannot meet its prop floor by planting trees.
const VEGETATION_PROP_KINDS: Array[StringName] = [
	MapTypes.PROP_KIND_TREE,
	MapTypes.PROP_KIND_BUSH,
]
const GROUND_COVER_PROP_KINDS: Array[StringName] = [
	MapTypes.PROP_KIND_TREE,
	MapTypes.PROP_KIND_BUSH,
	MapTypes.PROP_KIND_ORCHARD_ROW,
	MapTypes.PROP_KIND_KITCHEN_GARDEN,
	MapTypes.PROP_KIND_FIELD_STRIP,
]
const GROUND_COVER_VARIANT_PREFIXES: Array[String] = ["grass.", "reed.", "bush.", "tree."]

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
	var dressing := _dressing_metrics(definition, grid, occupancy, surface)
	dressing["relief_span_m"] = elevation
	return {
		"dressing": dressing,
		"scope": String(definition.scope),
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


## WB-10: checks the dressing-and-ground metrics from measure()["dressing"]
## against one map-class card from map_composition_thresholds.json
## `density_contract.classes`. Pure over the metrics dictionary so fixtures
## and the headless tool share one code path. Absent keys are not checked.
static func audit_density(
	map_id: String,
	dressing: Dictionary,
	class_thresholds: Dictionary,
	source_refs: Array = [],
) -> Array[Dictionary]:
	var violations: Array[Dictionary] = []
	var floors := [
		["props_per_1000_min", "props_per_1000", VIOLATION_PROP_DENSITY],
		["decals_per_1000_min", "decals_per_1000", VIOLATION_DECAL_DENSITY],
		["distinct_prop_kinds_min", "distinct_prop_kinds", VIOLATION_PROP_VARIETY],
		["ground_cover_pct_min", "ground_cover_pct", VIOLATION_GROUND_COVER],
		["elevation_range_min", "relief_span_m", VIOLATION_ELEVATION_FLAT],
	]
	for row in floors:
		if class_thresholds.get(row[0]) == null:
			continue
		var floor_value := float(class_thresholds[row[0]])
		var measured := float(dressing.get(row[1], 0.0))
		if measured < floor_value:
			violations.append(
				_bound_violation(row[2], map_id, row[1], measured, ">= %s" % floor_value, source_refs)
			)
	var caps := [
		["max_prop_kind_share_pct", "max_prop_kind_share_pct", VIOLATION_PROP_KIND_SHARE],
		["max_identical_footprint_run", "max_identical_footprint_run", VIOLATION_FOOTPRINT_RUN],
	]
	for row in caps:
		if class_thresholds.get(row[0]) == null:
			continue
		var cap_value := float(class_thresholds[row[0]])
		var measured := float(dressing.get(row[1], 0.0))
		if measured > cap_value:
			violations.append(
				_bound_violation(row[2], map_id, row[1], measured, "<= %s" % cap_value, source_refs)
			)
	# Wealth/age tiers arrive with R-981 (.rrmap v2 semantic layer). Until the
	# class card flips tier_spread_active, the spread is reported, never judged.
	if bool(class_thresholds.get("tier_spread_active", false)):
		for row in [
			["min_wealth_tiers", "wealth_tiers"],
			["min_age_tiers", "age_tiers"],
		]:
			if class_thresholds.get(row[0]) == null:
				continue
			var tier_floor := float(class_thresholds[row[0]])
			var tier_count := float(dressing.get(row[1], 0))
			if tier_count < tier_floor:
				violations.append(
					_bound_violation(
						VIOLATION_TIER_SPREAD,
						map_id,
						row[1],
						tier_count,
						">= %s" % tier_floor,
						source_refs,
					)
				)
	return violations


static func _bound_violation(
	code: StringName,
	map_id: String,
	metric: String,
	measured: float,
	expected: String,
	source_refs: Array,
) -> Dictionary:
	return {
		"code": code,
		"map_id": map_id,
		"metric": metric,
		"measured": measured,
		"expected": expected,
		"source_refs": source_refs,
		"message": "%s %s measured %s, expected %s" % [map_id, metric, measured, expected],
	}


static func _dressing_metrics(
	definition: MapDefinition,
	grid: MapTerrainGrid,
	occupancy: Dictionary,
	surface: Dictionary,
) -> Dictionary:
	var walkable := int(surface.get("unbuilt_cells", 0))
	var built_cells: Dictionary = occupancy["built_cells"]
	var pixel := float(definition.cell_size)
	var kind_counts: Dictionary = {}
	var dressing_total := 0
	var vegetation_props := 0
	var cover_cells: Dictionary = {}
	for prop in definition.props:
		var kind := StringName(prop.get("kind", &""))
		if GROUND_COVER_PROP_KINDS.has(kind) and prop.get("position") is Vector2:
			var position: Vector2 = prop["position"]
			cover_cells[Vector2i(int(floor(position.x / pixel)), int(floor(position.y / pixel)))] = true
		if VEGETATION_PROP_KINDS.has(kind):
			vegetation_props += 1
			continue
		dressing_total += 1
		kind_counts[String(kind)] = int(kind_counts.get(String(kind), 0)) + 1
	var max_kind := ""
	var max_kind_count := 0
	for kind_name in kind_counts:
		var count := int(kind_counts[kind_name])
		# Tie-break by name so the baseline report is deterministic.
		if count > max_kind_count or (count == max_kind_count and String(kind_name) < max_kind):
			max_kind = String(kind_name)
			max_kind_count = count
	for zone in definition.zones:
		var variant := String(zone.get("style_variant", ""))
		if not _is_ground_cover_variant(variant) or not zone.get("rect") is Rect2i:
			continue
		var rect: Rect2i = zone["rect"]
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				cover_cells[Vector2i(x, y)] = true
	var covered := 0
	for y in grid.size_cells.y:
		for x in grid.size_cells.x:
			var cell := Vector2i(x, y)
			var terrain := grid.get_terrain(cell)
			if MapTypes.WATER_TERRAINS.has(terrain) or built_cells.has(cell):
				continue
			if GRASS_TERRAINS.has(terrain) or cover_cells.has(cell):
				covered += 1
	var per_1000 := 1000.0 / float(walkable) if walkable > 0 else 0.0
	var tiers := _tier_spread(definition)
	return {
		"walkable_cells": walkable,
		"props_total": definition.props.size(),
		"dressing_props": dressing_total,
		"vegetation_props": vegetation_props,
		"decals": definition.decals.size(),
		"props_per_1000": float(dressing_total) * per_1000,
		"decals_per_1000": float(definition.decals.size()) * per_1000,
		"distinct_prop_kinds": kind_counts.size(),
		"max_prop_kind": max_kind,
		"max_prop_kind_share_pct":
		100.0 * float(max_kind_count) / float(dressing_total) if dressing_total > 0 else 0.0,
		"ground_cover_pct": 100.0 * float(covered) / float(walkable) if walkable > 0 else 0.0,
		"max_identical_footprint_run": _max_identical_footprint_run(definition),
		"wealth_tiers": tiers["wealth"],
		"age_tiers": tiers["age"],
	}


static func _is_ground_cover_variant(variant: String) -> bool:
	for prefix in GROUND_COVER_VARIANT_PREFIXES:
		if variant.begins_with(prefix):
			return true
	return false


## Distinct wealth_tier / age_tier values on counted buildings. Both are 0
## until R-981 adds the semantic fields; audit_density ignores them until then.
static func _tier_spread(definition: MapDefinition) -> Dictionary:
	var wealth: Dictionary = {}
	var age: Dictionary = {}
	for building in definition.buildings:
		if not _counts_toward_density(building, false):
			continue
		if building.has("wealth_tier"):
			wealth[String(building["wealth_tier"])] = true
		if building.has("age_tier"):
			age[String(building["age_tier"])] = true
	return {"wealth": wealth.size(), "age": age.size()}


## Largest group of houses that share one footprint size (rotation-agnostic,
## in whole cells) and stand next to each other along a street: rects at most
## one cell apart that overlap on the other axis. This is the authoring-side
## "row of boxes" failure; how the houses look is AR-13's concern, not this.
static func _max_identical_footprint_run(definition: MapDefinition) -> int:
	var rects: Array[Rect2i] = []
	var keys: Array[Vector2i] = []
	var pixel := float(definition.cell_size)
	for building in definition.buildings:
		if not _counts_toward_density(building, false) or not building.get("footprint") is Rect2:
			continue
		var footprint: Rect2 = building["footprint"]
		var rect := Rect2i(
			int(round(footprint.position.x / pixel)),
			int(round(footprint.position.y / pixel)),
			maxi(1, int(round(footprint.size.x / pixel))),
			maxi(1, int(round(footprint.size.y / pixel))),
		)
		rects.append(rect)
		keys.append(Vector2i(mini(rect.size.x, rect.size.y), maxi(rect.size.x, rect.size.y)))
	var visited: Array[bool] = []
	visited.resize(rects.size())
	var largest := 0
	for start in rects.size():
		if visited[start]:
			continue
		visited[start] = true
		var queue: Array[int] = [start]
		var size := 0
		while not queue.is_empty():
			var current: int = queue.pop_back()
			size += 1
			for other in rects.size():
				if visited[other] or keys[other] != keys[current]:
					continue
				if _street_neighbours(rects[current], rects[other]):
					visited[other] = true
					queue.append(other)
		largest = maxi(largest, size)
	return largest


static func _street_neighbours(a: Rect2i, b: Rect2i) -> bool:
	var gap_x := maxi(b.position.x - a.end.x, a.position.x - b.end.x)
	var gap_y := maxi(b.position.y - a.end.y, a.position.y - b.end.y)
	# Side by side in a row (y ranges overlap) or stacked in a column.
	return (gap_y < 0 and gap_x >= 0 and gap_x <= 1) or (gap_x < 0 and gap_y >= 0 and gap_y <= 1)


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
