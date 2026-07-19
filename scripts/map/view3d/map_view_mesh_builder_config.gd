class_name MapViewMeshBuilderConfig
extends RefCounted

## Shared constants for 3D map view mesh generation (split from MapViewMeshBuilder).

const TRANSITION_MARKER_SCRIPT := preload("res://scripts/map/view3d/transition_marker_3d.gd")

## Converts immutable MapDefinition data into 3D view geometry (P0-052).
## View only: no collision shapes, physics bodies, or navigation are generated
## here - the logic plane keeps owning all gameplay geometry. All sizes are in
## world units where one logic cell equals one unit (MapViewBridge).

const WATER_RECESS := 0.08
const ROOF_PITCH := 0.9
const ROOF_OVERHANG := 0.15
const CAP_HEIGHT := 0.12
const CAP_OVERHANG := 0.05
## Doorways must read taller than the frozen 2.0-unit character.
const DOOR_WIDTH := 1.5
const DOOR_HEIGHT := 2.5
const DOOR_THICKNESS := 0.14
const DOOR_FRAME_THICKNESS := 0.16
const TRANSITION_MARKER_HEIGHT := 0.035
const TRANSITION_MARKER_COLOR := Color(0.55, 0.78, 0.48, 0.3)

## Fallback wall heights in logic pixels when a building omits wall_height.
## Houses carry a full storey plus loft over the 2.0-unit character; freestanding
## walls stay chest-high so courtyards read open.
const DEFAULT_WALL_HEIGHT_PX := {
	MapTypes.BUILDING_KIND_HOUSE: 112.0,
	MapTypes.BUILDING_KIND_WALL: 64.0,
	MapTypes.BUILDING_KIND_INTERIOR_WALL: 72.0,
	MapTypes.BUILDING_KIND_INTERIOR_BLOCK: 56.0,
}

const DEFAULT_WALL_COLOR := Color(0.46, 0.44, 0.40)
const DEFAULT_ROOF_COLOR := Color(0.24, 0.20, 0.16)

## Per-cell ground tone variation so large terrain fields stop reading as one
## flat tint: fine per-cell jitter plus a broader patch drift, both deterministic.
const TERRAIN_JITTER := 0.07
const TERRAIN_PATCH_STRENGTH := 0.06
const TERRAIN_PATCH_CELLS := 5

## Gentle rolling ground relief. Heights flatten to zero around buildings,
## transitions, water, and the map border so gameplay-relevant geometry keeps
## sitting on level pads and the logic plane's flat collision stays honest.
const HEIGHT_BROAD_AMPLITUDE := 0.38
const HEIGHT_FINE_AMPLITUDE := 0.09
const HEIGHT_BROAD_PERIOD := 9.0
const HEIGHT_FINE_PERIOD := 3.1
## Each logic cell becomes a 3 x 3 visual patch (18 triangles). Gameplay stays
## on the original grid while relief and surface borders gain finer curvature.
const TERRAIN_SUBDIVISIONS := 3
## Shared grid vertices shift laterally up to this much so terrain borders
## (road edges, shorelines) curve organically instead of running cell-straight.
const EDGE_JITTER := 0.26
## Terrain identity is sampled through a smooth offset at sub-cell centers.
## This visually rounds rectangle-authored roads and banks while the immutable
## terrain grid continues to own gameplay semantics.
const VISUAL_EDGE_WARP := 0.38
const FLATTEN_START := 0.3
const FLATTEN_END := 2.4
const BORDER_FLATTEN_CELLS := 2.5
const WATER_FLATTEN_CELLS := 3

## House construction families: visible building material per dwelling.
## 1343 Reval mix: horizontal log construction dominates the lower town, local
## limestone marks wealthy merchants and church buildings, brick stays rare
## (Tallinn built in limestone, unlike the brick-Gothic towns further south).
const HOUSE_STYLE_TIMBER := &"timber_frame"
const HOUSE_STYLE_BRICK := &"brick"
const HOUSE_STYLE_PLANK := &"plank"
const HOUSE_STYLE_LOG := &"log"
const HOUSE_STYLE_STONE := &"limestone"
const PLASTER_TONE := Color(0.87, 0.81, 0.67)
const BRICK_TONE := Color(0.64, 0.36, 0.25)
const LOG_TONE := Color(0.45, 0.35, 0.25)
const LIMESTONE_TONE := Color(0.72, 0.70, 0.62)

## Roof cover families and the weathered-straw tint pulled over authored roof
## colors when a fallback house resolves to thatch (authored dark browns read
## as rotten reed otherwise).
const ROOF_STYLE_TILE := &"tile"
const ROOF_STYLE_SHINGLE := &"shingle"
const ROOF_STYLE_THATCH := &"thatch"
const THATCH_TONE := Color(0.55, 0.47, 0.32)
const FRAME_BEAM_THICKNESS := 0.11
const PLINTH_HEIGHT := 0.24

## Tallinn town-wall dressing: round limestone towers wear tall conical
## red-tile roofs, and wall walks carry a red saddle roof on timber posts.
const TOWER_MAX_FOOTPRINT := 5.2
const TOWER_MIN_ASPECT := 0.65
const TOWER_RADIUS_FACTOR := 0.48
const TOWER_ROOF_COLOR := Color8(158, 64, 44)
const WALL_ROOF_COLOR := Color8(150, 66, 48)
const TOWER_ROOF_PITCH := 1.45
const WALL_WALK_ROOF_LIFT := 0.75
const WALL_WALK_TIMBER_TONE := Color(0.50, 0.36, 0.24)

const CHIMNEY_SIZE := 0.5
const CHIMNEY_WALL_THICKNESS := 0.09
## Stone lip above the flue so the mouth reads as a tube, not a flat cube top.
const CHIMNEY_FLUE_LIP := 0.05
## Fixed stack height on the ridge - must not scale with roof span or chimneys
## tower above the whole building.
const CHIMNEY_STACK_HEIGHT := 0.58
const CHIMNEY_STACK_EMBED := 0.16
const CHIMNEY_SMOKE_SCRIPT := preload("res://scripts/map/view3d/chimney_smoke_3d.gd")
const WINDOW_LIGHTS_SCRIPT := preload("res://scripts/map/view3d/building_window_lights_3d.gd")
const INTERIOR_WINDOW_LIGHTS_SCRIPT := preload("res://scripts/map/view3d/interior_window_lights_3d.gd")
const CANDLE_LIGHT_SCRIPT := preload("res://scripts/map/view3d/candle_light_3d.gd")

## House facades: every house gets a street door and shuttered windows so the
## dwellings read as inhabited from the dimetric camera.
const HOUSE_DOOR_WIDTH := 0.95
const HOUSE_DOOR_HEIGHT := 2.1
const HOUSE_WINDOW_SIZE := Vector2(0.6, 0.75)
const HOUSE_WINDOW_SILL := 1.15
const HOUSE_WINDOW_SPACING := 2.1
const HOUSE_WINDOW_FRAME := 0.08
const HOUSE_WINDOW_OUTER_DEPTH := 0.11
const HOUSE_WINDOW_GLASS_DEPTH := 0.035
const HOUSE_WINDOW_MULLION := 0.045
const HOUSE_WINDOW_MULLION_DEPTH := 0.09
const FACADE_RELIEF := 0.05
## Interior glazing sits above a low sill and below a stone/timber lintel band.
const INTERIOR_WINDOW_SILL_RATIO := 0.22
const INTERIOR_WINDOW_LINTEL := 0.12
const INTERIOR_WINDOW_MIN_HEIGHT := 0.55

## Enclosed interior shells need a shared ceiling so first-person look-up does
## not expose the sky dome through open wall tops.
const INTERIOR_CEILING_THICKNESS := 0.1
const INTERIOR_CEILING_COLOR := Color(0.34, 0.28, 0.22)
const INTERIOR_BEAM_SPACING := 3.6
const INTERIOR_BEAM_THICKNESS := 0.13
const INTERIOR_BEAM_DEPTH := 0.2

## Fortification dressing: town-wall segments and towers above this height get
## battlements; towers additionally get arrow slits.
const BATTLEMENT_MIN_HEIGHT_PX := 160.0
const TOWER_MIN_HEIGHT_PX := 220.0
const MERLON_SIZE := Vector3(0.42, 0.5, 0.3)
const MERLON_SPACING := 0.95
const ARROW_SLIT_SIZE := Vector3(0.14, 0.7, 0.08)
const ARROW_SLIT_FRAME_PAD := Vector2(0.1, 0.12)
const ARROW_SLIT_FRAME_DEPTH := 0.12

## Gate arch landmark: view-only mass bridging a walkable gate passage.
const GATE_ARCH_CLEARANCE := 3.2
const GATE_JAMB_THICKNESS := 0.55
const GATE_DOOR_HEIGHT := 2.45
const GATE_DOOR_THICKNESS := 0.12
## Fortification wall prisms grow slightly past their authored footprint so
## thin segments visually seal against wider towers at bends and gate throats.
const WALL_SEAL_OVERHANG := 0.45

## Background town silhouette on `surroundings_town_sides`.
const TOWN_GRID_SPACING := 6.5
const TOWN_KEEP_RATIO := 0.6
const TOWN_BAND_INNER := 2.5
const GLACIS_CLEARANCE := 6.0

## View-only landscape ring past the playable bounds. Authors opt in per side via
## `surroundings_sides`; unlisted sides stay empty instead of default woodland.
const SURROUNDINGS_SIZE_WORLD := 512.0
const SURROUNDINGS_COLOR := Color8(74, 88, 60)
const SURROUNDINGS_WATER_SHALLOW_DEPTH := 10.0
const SURROUNDINGS_WATER_DEEP_DEPTH := 56.0
const SURROUNDINGS_WOODLAND_DEPTH := 48.0
## Urban continuation strip on `surroundings_sides` town entries so silhouettes
## do not float over the void past the playable terrain edge.
const SURROUNDINGS_TOWN_DEPTH := 48.0
const TREE_BAND_INNER := 1.5
const TREE_BAND_OUTER := 18.0
const TREE_GRID_SPACING := 3.0
const TREE_KEEP_RATIO := 0.5

## Ground scatter (grass tufts, pebbles) is decorative only; it never implies
## collision, so every piece stays well under knee height.
const SCATTER_TUFT_CHANCE := {
	MapTypes.TERRAIN_GRASS: 0.85,
	MapTypes.TERRAIN_MEADOW: 0.9,
	MapTypes.TERRAIN_FOREST_FLOOR: 0.6,
	MapTypes.TERRAIN_BOG: 0.4,
	MapTypes.TERRAIN_HAY: 0.35,
	MapTypes.TERRAIN_STRAW: 0.3,
}
const SCATTER_STONE_CHANCE := {
	MapTypes.TERRAIN_DIRT: 0.12,
	MapTypes.TERRAIN_COBBLESTONE: 0.06,
	MapTypes.TERRAIN_MUD: 0.1,
	MapTypes.TERRAIN_SAND: 0.08,
	MapTypes.TERRAIN_COAST_SAND: 0.1,
	MapTypes.TERRAIN_GRASS: 0.05,
}

