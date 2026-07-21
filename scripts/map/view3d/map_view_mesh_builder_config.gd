class_name MapViewMeshBuilderConfig
extends RefCounted

## Shared constants for 3D map view mesh generation (split from MapViewMeshBuilder).

const TRANSITION_MARKER_SCRIPT := preload("res://scripts/map/view3d/transition_marker_3d.gd")

## Converts immutable MapDefinition data into 3D view geometry (P0-052).
## View only: no collision shapes, physics bodies, or navigation are generated
## here - the logic plane keeps owning all gameplay geometry. All sizes are in
## world units where one logic cell equals one unit (MapViewBridge).

const WATER_RECESS := 0.08
## Water sits just above the recessed bed. Keeping the lift tiny avoids z-fighting
## with the continuous ground mesh without making the shoreline look elevated.
const WATER_SURFACE_LIFT := 0.006
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
	## Interior walls carry the ceiling directly, so the default must leave
	## first-person headroom (eye height 1.65) under the exposed beams.
	MapTypes.BUILDING_KIND_INTERIOR_WALL: 96.0,
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
## Authored elevated districts taper into their neighboring map datum over a
## broad edge band. Gameplay transitions remain at the edge while the interior
## reads as a raised plateau.
const ELEVATION_SLOPE_CELLS := 10.0
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
## Width of the soft blend band between neighboring terrain families on the
## unified ground mesh. Wider bands hide cell-aligned road and yard borders.
const TERRAIN_BLEND_WIDTH := 0.46
const FLATTEN_START := 0.3
const FLATTEN_END := 2.4
const BORDER_FLATTEN_CELLS := 2.5
const WATER_FLATTEN_CELLS := 3
## Visible water is reconstructed from a broad center-sampled field rather than
## the literal cell outline. The multi-cell footprint is large enough to turn the
## authored 4-6-cell river steps into readable diagonal bends at gameplay zoom.
const WATER_CONTOUR_SIGMA_CELLS := 1.6
const WATER_CONTOUR_RADIUS_CELLS := 4
const WATER_CONTOUR_THRESHOLD := 0.42

## View-only riparian bands sampled from the same smoothed contour as the water.
## Inland banks use a wide damp-dirt → muted-silt → wet-mud ramp so grass never
## meets a hard bright sand stripe. Authored terrain IDs stay unchanged.
const SHORE_MUD_INNER_COVERAGE := 0.31
const SHORE_SAND_INNER_COVERAGE := 0.17
const SHORE_SAND_OUTER_COVERAGE := 0.01
const SHORE_COVERAGE_WARP := 0.045
## Cap how fully silt/mud replace authored ground so the bank stays mixed.
const SHORE_SILT_BLEND_CAP := 0.48
const SHORE_MUD_BLEND_CAP := 0.82
const SHORE_CATTAIL_CHANCE := 0.38
const SHORE_CATTAIL_MIN_COVERAGE := 0.12
const SHORE_CATTAIL_MAX_COVERAGE := WATER_CONTOUR_THRESHOLD - 0.015

## Only natural, porous surfaces receive an automatic riparian bank. Stone quay
## edges and indoor floors keep their authored materials and remain plant-free.
const NATURAL_SHORE_TERRAINS: Array[StringName] = [
	MapTypes.TERRAIN_GRASS,
	MapTypes.TERRAIN_MEADOW,
	MapTypes.TERRAIN_FOREST_FLOOR,
	MapTypes.TERRAIN_BOG,
	MapTypes.TERRAIN_DIRT,
	MapTypes.TERRAIN_MUD,
	MapTypes.TERRAIN_SAND,
	MapTypes.TERRAIN_COAST_SAND,
]

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
## Weathered Baltic reed: golden-olive straw, not rotten brown or flat yellow.
const THATCH_TONE := Color(0.58, 0.50, 0.34)
## Extra eaves hang so thatch reads thicker than shingle/tile at dimetric range.
const THATCH_ROOF_OVERHANG := 0.28
## Soft reed ridge roll and eaves fringe dimensions.
const THATCH_RIDGE_RADIUS := 0.14
const THATCH_EDGE_ROLL := 0.10
const THATCH_EAVES_FRINGE_HEIGHT := 0.16
const THATCH_EAVES_FRINGE_DEPTH := 0.08
const FRAME_BEAM_THICKNESS := 0.11
const PLINTH_HEIGHT := 0.24

## Tallinn town-wall dressing: round limestone towers wear tall conical
## red-tile roofs, while a character-height timber gallery carries the wall-walk
## roof. The gallery keeps a full two-metre actor clear beneath its eaves.
const TOWER_MAX_FOOTPRINT := 5.2
const TOWER_MIN_ASPECT := 0.65
## Ground-level access is visual-only, but it must stay character-scale and
## clearly separate from the much larger gate leaves.
const TOWER_DOOR_WIDTH := 1.1
const TOWER_DOOR_HEIGHT := 2.2
const TOWER_DOOR_FRAME_WIDTH := 0.16
const TOWER_DOOR_FRAME_DEPTH := 0.18
const TOWER_DOOR_STEP_DEPTH := 0.38
const TOWER_RADIUS_FACTOR := 0.48
const TOWER_ROOF_COLOR := Color8(158, 64, 44)
const WALL_ROOF_COLOR := Color8(150, 66, 48)
const TOWER_ROOF_PITCH := 1.45
const WALL_WALK_CLEAR_HEIGHT := 2.35
const WALL_WALK_MIN_WIDTH := 2.4
const WALL_WALK_TIMBER_TONE := Color(0.50, 0.36, 0.24)
const WALL_WALK_POST_SPACING := 1.8
const WALL_WALK_POST_SIZE := 0.11
const WALL_WALK_RAIL_HEIGHT := 0.86
const WALL_WALK_RAIL_SIZE := 0.09
const WALL_WALK_BRACKET_DROP := 0.62
const WALL_BASE_ARCADE_BAY_WIDTH := 2.0
const WALL_BASE_ARCADE_DEPTH := 0.24
const WALL_BASE_ARCADE_STONE_WIDTH := 0.2
const WALL_BASE_ARCADE_SPRING_HEIGHT := 0.62
const WALL_BASE_ARCADE_MAX_RADIUS := 0.92

## Large authored stair props opt into wall-walk access with
## primitive=wall_walk_access. Most of their footprint climbs; the final band is
## a level logical corridor mirrored onto the wall cap by the 3D view.
const WALL_WALK_ACCESS_CLIMB_FRACTION := 0.72
const WALL_WALK_ACCESS_STEP_RISE := 0.24
const WALL_WALK_ACCESS_STAIR_WIDTH := 1.65
const WALL_WALK_ACCESS_TREAD_THICKNESS := 0.1
const WALL_WALK_ACCESS_RAIL_HEIGHT := 1.0
const WALL_WALK_ACCESS_MAX_TARGET_DISTANCE_CELLS := 5.0

## Narrow shaft - cube-sized stacks read as roof ornaments, not chimneys.
const CHIMNEY_SIZE := 0.36
const CHIMNEY_WALL_THICKNESS := 0.07
## Stone lip above the flue so the mouth reads as a tube, not a flat cube top.
const CHIMNEY_FLUE_LIP := 0.05
## Fixed stack height - must not scale with roof span or chimneys tower above
## the whole building. Tall enough that after roof penetration a clear shaft
## remains above the tiles.
const CHIMNEY_STACK_HEIGHT := 1.35
## Depth below the downhill roof intersection so the stack goes through the
## slope instead of sitting on the ridge like a block.
const CHIMNEY_STACK_EMBED := 0.45
## Lateral clearance past the ridge so the chimney sits fully on one roof face.
const CHIMNEY_RIDGE_CLEARANCE := 0.06
const CHIMNEY_SMOKE_SCRIPT := preload("res://scripts/map/view3d/chimney_smoke_3d.gd")
const WINDOW_LIGHTS_SCRIPT := preload("res://scripts/map/view3d/building_window_lights_3d.gd")
const INTERIOR_WINDOW_LIGHTS_SCRIPT := preload("res://scripts/map/view3d/interior_window_lights_3d.gd")
const CANDLE_LIGHT_SCRIPT := preload("res://scripts/map/view3d/candle_light_3d.gd")
const BOAT_FLOAT_SCRIPT := preload("res://scripts/map/view3d/boat_float_3d.gd")

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
## Open shutters parked beside the frame (1343 dwellings used timber shutters;
## glass stayed rare). Depth stays thin so they read as boards, not boxes.
const HOUSE_SHUTTER_WIDTH := 0.28
const HOUSE_SHUTTER_THICKNESS := 0.045
const HOUSE_SHUTTER_GAP := 0.04
## Bound door leaves: two iron straps plus a simple latch block.
const HOUSE_DOOR_STRAP_THICKNESS := 0.035
const HOUSE_DOOR_STRAP_COUNT := 2
## Roof trim: bargeboards on gable ends and a fascia under the eaves keep the
## Nordic/Estonian wooden-town silhouette without inventing German Fachwerk.
## Width is the board face; thickness is the thin edge. A near-square stick
## silhouette reads as empty flagpoles against the sky - keep face >> edge.
const HOUSE_BARGEBOARD_WIDTH := 0.15
const HOUSE_BARGEBOARD_THICKNESS := 0.035
const HOUSE_EAVES_FASCIA_HEIGHT := 0.1
const HOUSE_RIDGE_BOARD_HEIGHT := 0.08
## Log-house corner heads protrude past the wall plane (horizontal log
## vernacular of 14th-century Reval lower town).
const HOUSE_LOG_END_PROTRUSION := 0.18
const HOUSE_LOG_END_THICKNESS := 0.16
const HOUSE_LOG_END_SPACING := 0.34
## Limestone merchant houses: shallow quoins and a cornice under the eaves.
const HOUSE_QUOIN_WIDTH := 0.28
const HOUSE_QUOIN_DEPTH := 0.1
const HOUSE_CORNICE_HEIGHT := 0.12
const HOUSE_CORNICE_DEPTH := 0.14
## Plank houses: vertical corner boards and sparse mid-wall battens.
const HOUSE_PLANK_BATTEN_WIDTH := 0.08
const HOUSE_PLANK_BATTEN_DEPTH := 0.05
## Interior glazing sits above a low sill and below a stone/timber lintel band.
const INTERIOR_WINDOW_SILL_RATIO := 0.22
const INTERIOR_WINDOW_LINTEL := 0.12
const INTERIOR_WINDOW_MIN_HEIGHT := 0.55

## Enclosed interior shells need a shared ceiling so first-person look-up does
## not expose the sky dome through open wall tops. The ceiling rests directly
## on the wall line - any offset opens a sky band between wall tops and the
## ceiling in first-person. Headroom comes from authored wall_height instead;
## top-down gameplay hides the shell entirely.
const INTERIOR_CEILING_FIRST_PERSON_HEADROOM := 0.0
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
## Open leaves sit against the jambs; keep them character-scale so a deep
## gatehouse does not stretch one leaf across the whole passage depth.
const GATE_DOOR_MAX_LEAF := 2.6
const GATE_THRESHOLD_WIDTH := 0.7
const GATE_THRESHOLD_HEIGHT := 0.08
const GATE_DOOR_STRAP_THICKNESS := 0.04
const GATE_DOOR_HINGE_RADIUS := 0.05
## Fortification wall prisms grow slightly past their authored footprint so
## thin segments visually seal against wider towers at bends and gate throats.
const WALL_SEAL_OVERHANG := 0.45

## Background town silhouette on `surroundings_town_sides`.
const TOWN_GRID_SPACING := 6.5
const TOWN_KEEP_RATIO := 0.6
const TOWN_BAND_INNER := 2.5
const TOWN_BAND_OUTER := 96.0
const GLACIS_CLEARANCE := 6.0

## View-only landscape ring past the playable bounds. Authors opt in per side via
## `surroundings_sides`; unlisted sides stay empty instead of default woodland.
## Depth must exceed the max-zoom dimetric frustum past a map edge (ortho size
## ~50, pitch -30, yaw 45) so the sky never reads as a blue void. Movement stays
## clamped to authored collision/nav; these meshes are view-only.
const SURROUNDINGS_SIZE_WORLD := 512.0
const SURROUNDINGS_CONTINUATION_DEPTH := 192.0
const SURROUNDINGS_COLOR := Color8(74, 88, 60)
const SURROUNDINGS_WATER_SHALLOW_DEPTH := 10.0
const SURROUNDINGS_WATER_DEEP_DEPTH := SURROUNDINGS_CONTINUATION_DEPTH - SURROUNDINGS_WATER_SHALLOW_DEPTH
const SURROUNDINGS_WOODLAND_DEPTH := SURROUNDINGS_CONTINUATION_DEPTH
## Urban continuation strip on `surroundings_sides` town entries so silhouettes
## do not float over the void past the playable terrain edge.
const SURROUNDINGS_TOWN_DEPTH := SURROUNDINGS_CONTINUATION_DEPTH
const TREE_BAND_INNER := 1.5
const TREE_BAND_OUTER := 18.0
const TREE_GRID_SPACING := 3.0
const TREE_KEEP_RATIO := 0.5

## Grass already reads continuously through the terrain texture. These values are
## only the sparse small-tuft layer; large grass, shrubs, and trees have separate
## profile probabilities in TerrainVegetation.
const SCATTER_SMALL_GRASS_CHANCE := {
	MapTypes.TERRAIN_GRASS: 0.28,
	MapTypes.TERRAIN_MEADOW: 0.34,
	MapTypes.TERRAIN_FOREST_FLOOR: 0.12,
	MapTypes.TERRAIN_BOG: 0.16,
	MapTypes.TERRAIN_HAY: 0.08,
	MapTypes.TERRAIN_STRAW: 0.06,
}
const SCATTER_TREE_CHANCE := {
	MapTypes.TERRAIN_FOREST_FLOOR: 0.09,
	MapTypes.TERRAIN_MEADOW: 0.02,
	MapTypes.TERRAIN_GRASS: 0.006,
}
const SCATTER_TREE_SPRUCE_RATIO := {
	MapTypes.TERRAIN_FOREST_FLOOR: 0.62,
}
const SCATTER_STONE_CHANCE := {
	MapTypes.TERRAIN_DIRT: 0.12,
	MapTypes.TERRAIN_COBBLESTONE: 0.06,
	MapTypes.TERRAIN_MUD: 0.1,
	MapTypes.TERRAIN_SAND: 0.08,
	MapTypes.TERRAIN_COAST_SAND: 0.1,
	MapTypes.TERRAIN_GRASS: 0.05,
}

## Flat reflective puddles on worked ground and worn paving. Deterministic from
## map seed; biased toward low relief and near water without affecting walkability.
const PUDDLE_CHANCE := {
	MapTypes.TERRAIN_MUD: 0.14,
	MapTypes.TERRAIN_DIRT: 0.08,
	MapTypes.TERRAIN_COBBLESTONE: 0.06,
	MapTypes.TERRAIN_CASTLE_PAVING: 0.05,
	MapTypes.TERRAIN_FARM_SOIL: 0.06,
}
const PUDDLE_LOW_HEIGHT_BIAS := 0.55
const PUDDLE_SCALE_MIN := 0.28
const PUDDLE_SCALE_MAX := 0.72
