class_name SurfaceResolver
extends RefCounted

## Maps authored terrain IDs onto the footstep surface vocabulary (ADR 0035
## phase 2). Eight surfaces cover the twenty-terrain palette, so several
## terrains share one surface. Listeners classify surface *type* reliably and
## materials inside a type poorly (Turchet/Nordahl/Serafin), so folding hay into
## grass or farm soil into dirt is cheap and inaudible. Wet mud and a puddle are
## different types to the ear (squelch, splash), so they are surfaces of their
## own since R-1641.
##
## Nothing here touches game state: callers pass a terrain grid or a terrain ID
## and get a StringName back.

const SURFACE_WOOD := &"wood"
const SURFACE_STONE := &"stone"
const SURFACE_DIRT := &"dirt"
const SURFACE_MUD := &"mud"
const SURFACE_GRASS := &"grass"
## gravel and sand share one surface.
const SURFACE_GRAVEL := &"gravel"
const SURFACE_WATER_SHALLOW := &"water_shallow"
## Shin-deep and deeper: the leg is pulled out and pushed back through the
## water, a long gurgling slosh instead of a splash (R-1648). No terrain maps to
## it: the view picks it from the water column under the foot.
const SURFACE_WATER_WADE := &"water_wade"
## Standing rain water over another surface. No terrain maps to it: the view
## reports it where a visible puddle lies under the foot (R-1641).
const SURFACE_PUDDLE := &"puddle"
## Settled snow over turf, earth, mud or gravel: a dry crunch (ADR 0045). No terrain
## maps to it: the city view reports it where snow lies under the foot.
const SURFACE_SNOW := &"snow"

const SURFACES: Array[StringName] = [
	SURFACE_WOOD,
	SURFACE_STONE,
	SURFACE_DIRT,
	SURFACE_MUD,
	SURFACE_GRASS,
	SURFACE_GRAVEL,
	SURFACE_WATER_SHALLOW,
	SURFACE_WATER_WADE,
	SURFACE_PUDDLE,
	SURFACE_SNOW,
]

const GAIT_WALK := &"walk"
const GAIT_RUN := &"run"
const GAIT_SNEAK := &"sneak"
const GAITS: Array[StringName] = [GAIT_WALK, GAIT_RUN, GAIT_SNEAK]

## Logic px/s above which locomotion reads as running. Mirrors
## MapViewRuntimeActors.RUN_ANIMATION_MIN_SPEED so sound and animation agree.
const RUN_SPEED_THRESHOLD := 170.0

## Water column (world units, Kalev about 2 tall) from which a step wades
## instead of splashing: mid-shin, where the leg starts to push water aside.
## Deeper than PlayerSwimState.SWIM_ENTER_DEPTH the feet leave the bed and no
## step plays at all; the swimmer presenter plays strokes instead.
const WADE_SURFACE_DEPTH := 0.3

## One arm pull of a swimmer (R-1648); played by the swimmer presenter, not by a
## foot plant, so it is not a footstep surface.
const SWIM_STROKE_SOUND_ID := &"sfx.water.swim_stroke"

## Every MapTypes terrain maps to exactly one surface, or to &"" when footsteps
## must stay silent (deep water is swimming; the swimmer owns those sounds).
const TERRAIN_SURFACES: Dictionary = {
	MapTypes.TERRAIN_TIMBER_FLOOR: SURFACE_WOOD,
	MapTypes.TERRAIN_STONE: SURFACE_STONE,
	MapTypes.TERRAIN_COBBLESTONE: SURFACE_STONE,
	MapTypes.TERRAIN_CASTLE_PAVING: SURFACE_STONE,
	MapTypes.TERRAIN_PLASTER: SURFACE_STONE,
	MapTypes.TERRAIN_DIRT: SURFACE_DIRT,
	MapTypes.TERRAIN_MUD: SURFACE_MUD,
	MapTypes.TERRAIN_FARM_SOIL: SURFACE_DIRT,
	MapTypes.TERRAIN_BOG: SURFACE_MUD,
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
## Every surface has its own recorded pool since R-1641, so no chain is left.
## The table stays as the documented seam for a future surface whose pool lands
## later than its terrain.
const SURFACE_FALLBACKS: Dictionary = {
	SURFACE_WOOD: [],
	SURFACE_STONE: [],
	SURFACE_GRAVEL: [],
	SURFACE_DIRT: [],
	SURFACE_MUD: [],
	SURFACE_GRASS: [],
	SURFACE_WATER_SHALLOW: [],
	SURFACE_WATER_WADE: [],
	SURFACE_PUDDLE: [],
	SURFACE_SNOW: [],
}

## Surfaces a puddle can lie on. A step onto a board or into a stream is never
## a puddle, whatever the rain did.
const PUDDLE_HOSTS: Array[StringName] = [
	SURFACE_STONE, SURFACE_DIRT, SURFACE_MUD, SURFACE_GRASS, SURFACE_GRAVEL
]


## Ground snow can bury: turf, earth, mud and gravel. Boards, flagstones and water
## stay what they are (a path is swept; a bridge is not snow).
const SNOW_HOSTS: Array[StringName] = [SURFACE_DIRT, SURFACE_MUD, SURFACE_GRASS, SURFACE_GRAVEL]


## The surface a foot hears when snow lies on the ground it stands on.
static func with_snow(surface: StringName, in_snow: bool) -> StringName:
	if in_snow and surface in SNOW_HOSTS:
		return SURFACE_SNOW
	return surface


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


## The surface a foot hears: a visible puddle under the sole wins over the
## ground it lies on.
static func with_puddle(surface: StringName, in_puddle: bool) -> StringName:
	if in_puddle and surface in PUDDLE_HOSTS:
		return SURFACE_PUDDLE
	return surface


## The water surface a foot hears in a column `depth` deep: a splash up to
## mid-shin, wading above it. The column, not the terrain ID, decides, so the
## shelving edge of the sea splashes and its deeper water wades on every map.
static func water_surface_for_depth(depth: float) -> StringName:
	return SURFACE_WATER_WADE if depth >= WADE_SURFACE_DEPTH else SURFACE_WATER_SHALLOW


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
