class_name MapViewMeshBuilder
extends RefCounted

## Converts immutable MapDefinition data into 3D view geometry (P0-052).
## View only: no collision shapes, physics bodies, or navigation are generated
## here - the logic plane keeps owning all gameplay geometry. All sizes are in
## world units where one logic cell equals one unit (MapViewBridge).
##
## Implementation is split across focused modules; this class keeps the public
## API stable for callers and tests.

# Re-export frequently referenced constants for backward compatibility.
const TERRAIN_SUBDIVISIONS := MapViewMeshBuilderConfig.TERRAIN_SUBDIVISIONS
const TRANSITION_MARKER_HEIGHT := MapViewMeshBuilderConfig.TRANSITION_MARKER_HEIGHT


static func ensure_height_field(definition: MapDefinition, grid: MapTerrainGrid) -> Dictionary:
	return MapViewMeshBuilderTerrain.ensure_height_field(definition, grid)


static func ground_height(definition: MapDefinition, world_xz: Vector2) -> float:
	return MapViewMeshBuilderTerrain.ground_height(definition, world_xz)


static func build_terrain(definition: MapDefinition, grid: MapTerrainGrid) -> Node3D:
	return MapViewMeshBuilderTerrain.build_terrain(definition, grid)


static func build_building(building: Dictionary, cell_size: int) -> Node3D:
	return MapViewMeshBuilderBuildings.build_building(building, cell_size)


static func interior_shell_wall_height_world(definition: MapDefinition) -> float:
	return MapViewMeshBuilderLandmarks.interior_shell_wall_height_world(definition)


static func build_landmark(
	landmark: Dictionary,
	cell_size: int,
	wall_height_world: float = -1.0
) -> Node3D:
	return MapViewMeshBuilderLandmarks.build_landmark(landmark, cell_size, wall_height_world)


static func transition_uses_landmark_visual(definition: MapDefinition, transition: Dictionary) -> bool:
	return MapViewMeshBuilderLandmarks.transition_uses_landmark_visual(definition, transition)


static func build_transition_door(
	transition: Dictionary,
	cell_size: int,
	wall_height_world: float = -1.0
) -> Node3D:
	return MapViewMeshBuilderLandmarks.build_transition_door(transition, cell_size, wall_height_world)


static func build_transition_marker(transition: Dictionary, cell_size: int) -> Node3D:
	return MapViewMeshBuilderLandmarks.build_transition_marker(transition, cell_size)


static func build_prop(prop: Dictionary, cell_size: int) -> Node3D:
	return MapViewMeshBuilderProps.build_prop(prop, cell_size)


static func build_scatter(
	definition: MapDefinition,
	grid: MapTerrainGrid,
	cell_bounds: Rect2i = Rect2i(Vector2i.ZERO, Vector2i.ZERO)
) -> Node3D:
	return MapViewMeshBuilderProps.build_scatter(definition, grid, cell_bounds)


static func build_surroundings(definition: MapDefinition) -> Node3D:
	return MapViewMeshBuilderSurroundings.build_surroundings(definition)
