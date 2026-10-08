class_name SurfaceResolver
extends RefCounted

## Maps authored terrain IDs onto the footstep surface vocabulary (ADR 0035
## phase 2). The first cut covers six surfaces; the terrain palette has twenty,
## so several terrains share one surface. Listeners classify surface *type*
## reliably and materials inside a type poorly (Turchet/Nordahl/Serafin), so
## folding hay into grass or farm soil into dirt is cheap and inaudible.
##
## Nothing here touches game state: callers pass a terrain grid or a terrain ID
## and get a StringName back.

const SURFACE_WOOD := &"wood"
const SURFACE_STONE := &"stone"
## dirt and mud share one surface in the first cut.
const SURFACE_DIRT := &"dirt"
const SURFACE_GRASS := &"grass"
## gravel and sand share one surface in the first cut.
const SURFACE_GRAVEL := &"gravel"
const SURFACE_WATER_SHALLOW := &"water_shallow"

const SURFACES: Array[StringName] = [
	SURFACE_WOOD,
	SURFACE_STONE,
	SURFACE_DIRT,
	SURFACE_GRASS,
	SURFACE_GRAVEL,
	SURFACE_WATER_SHALLOW,
]

const GAIT_WALK := &"walk"
const GAIT_RUN := &"run"
const GAIT_SNEAK := &"sneak"
const GAITS: Array[StringName] = [GAIT_WALK, GAIT_RUN, GAIT_SNEAK]

## Logic px/s above which locomotion reads as running. Mirrors
## MapViewRuntimeActors.RUN_ANIMATION_MIN_SPEED so sound and animation agree.
const RUN_SPEED_THRESHOLD := 170.0

## Every MapTypes terrain maps to exactly one surface, or to &"" when footsteps
## must stay silent (deep water is swimming; the swimmer owns those sounds).
const TERRAIN_SURFACES: Dictionary = {
	MapTypes.TERRAIN_TIMBER_FLOOR: SURFACE_WOOD,
	MapTypes.TERRAIN_STONE: SURFACE_STONE,
	MapTypes.TERRAIN_COBBLESTONE: SURFACE_STONE,
	MapTypes.TERRAIN_CASTLE_PAVING: SURFACE_STONE,
	MapTypes.TERRAIN_PLASTER: SURFACE_STONE,
	MapTypes.TERRAIN_DIRT: SURFACE_DIRT,
	MapTypes.TERRAIN_MUD: SURFACE_DIRT,
	MapTypes.TERRAIN_FARM_SOIL: SURFACE_DIRT,
	MapTypes.TERRAIN_BOG: SURFACE_DIRT,
	MapTypes.TERRAIN_FOREST_FLOOR: SURFACE_DIRT,
	MapTypes.TERRAIN_GRASS: SURFACE_GRASS,
	MapTypes.TERRAIN_MEADOW: SURFACE_GRASS,
	MapTypes.TERRAIN_HAY: SURFACE_GRASS,
	MapTypes.TERRAIN_STRAW: SURFACE_GRASS,
	MapTypes.TERRAIN_SAND: SURFACE_GRAVEL,
	MapTypes.TERRAIN_COAST_SAND: SURFACE_GRAVEL,
	MapTypes.TERRAIN_ASH: SURFACE_GRAVEL,
	MapTypes.TERRAIN_SHALLOW_WATER: SURFACE_WATER_SHALLOW,
	MapTypes.TERRAIN_WATER: SURFACE_WATER_SHALLOW,
	MapTypes.TERRAIN_RIVER_WATER: SURFACE_WATER_SHALLOW,
	MapTypes.TERRAIN_DEEP_WATER: &"",
}

## Wet mud is a vocabulary surface that the six-surface first cut folds into
## dirt. Phase 1 seeded its pool (sfx.footstep.mud.walk), so it stays a valid
## fallback target even though it is not a first-cut surface.
const VOCABULARY_MUD := &"mud"

## Stand-ins while a surface has no pool of its own. Chains are flat data, not a
## guess at play time, and are not resolved recursively: list every step. ADR
## 0035 requires placeholders to be replaceable by catalog ID without touching
## code, so adding sfx.footstep.stone.walk is enough to make stone audible.
##
## A stand-in may only name the *same* material, never a neighbouring one.
## R-1382 kept cross-material chains (stone and sand on the wood pool, grass on
## the mud pool) and the result was audibly wrong on every map outside the
## slice: walking world_saaremaa knocked like a plank on the beach and squelched
## like a swamp on the meadows. Listeners classify surface *type* reliably
## (Turchet/Nordahl/Serafin), so a wrong type is heard immediately, while
## missing steps are not heard as a defect. Silence is therefore the correct
## placeholder until the pool exists.
##
## Only dirt keeps a chain: the six-surface first cut deliberately folds mud
## into dirt, so sfx.footstep.mud.walk is that surface's own pool, not a
## neighbour's.
const SURFACE_FALLBACKS: Dictionary = {
	SURFACE_WOOD: [],
	SURFACE_STONE: [],
	SURFACE_GRAVEL: [],
	SURFACE_DIRT: [VOCABULARY_MUD],
	SURFACE_GRASS: [],
	SURFACE_WATER_SHALLOW: [],
}


static func surface_for_terrain(terrain_id: StringName) -> StringName:
	return TERRAIN_SURFACES.get(terrain_id, &"")


static func surface_at_cell(grid: MapTerrainGrid, cell: Vector2i) -> StringName:
	if grid == null:
		return &""
	return surface_for_terrain(grid.get_terrain(cell))


## Surface under a 2D logic position (the gameplay plane), in map-local pixels.
static func surface_at_logic_position(
	grid: MapTerrainGrid, cell_size: int, logic_position: Vector2
) -> StringName:
	if grid == null or cell_size <= 0:
		return &""
	var cell := Vector2i(
		floori(logic_position.x / float(cell_size)), floori(logic_position.y / float(cell_size))
	)
	return surface_at_cell(grid, cell)


static func gait_for_speed(speed: float, run_threshold: float = RUN_SPEED_THRESHOLD) -> StringName:
	return GAIT_RUN if speed > run_threshold else GAIT_WALK


static func footstep_sound_id(surface: StringName, gait: StringName = GAIT_WALK) -> StringName:
	if String(surface).is_empty():
		return &""
	return StringName("sfx.footstep.%s.%s" % [surface, gait])


## Preferred ID first, then the same surface at a walk, then the fallback
## surfaces. Returns &"" when the catalog has nothing for the surface at all.
static func resolve_footstep_sound_id(
	catalog: SfxCatalog, surface: StringName, gait: StringName = GAIT_WALK
) -> StringName:
	if catalog == null or String(surface).is_empty():
		return &""
	var candidates: Array[StringName] = [surface]
	for fallback in SURFACE_FALLBACKS.get(surface, []):
		candidates.append(fallback)
	for candidate in candidates:
		for candidate_gait: StringName in [gait, GAIT_WALK]:
			var sound_id := footstep_sound_id(candidate, candidate_gait)
			if catalog.has_entry(sound_id):
				return sound_id
	return &""
