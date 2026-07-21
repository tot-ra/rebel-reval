class_name MapViewMeshBuilder
extends RefCounted

## Converts immutable MapDefinition data into 3D view geometry (P0-052).
## View only: no collision shapes, physics bodies, or navigation are generated
## here - the logic plane keeps owning all gameplay geometry. All sizes are in
## world units where one logic cell equals one unit (MapViewBridge).
##
## Implementation is split across focused modules; this class keeps the public
## API stable for callers and tests.

# Preload submodules so this facade parses before sibling class_name scripts register.
const _Config := preload("res://scripts/map/view3d/map_view_mesh_builder_config.gd")
const _Terrain := preload("res://scripts/map/view3d/map_view_mesh_builder_terrain.gd")
const _Buildings := preload("res://scripts/map/view3d/map_view_mesh_builder_buildings.gd")
const _Landmarks := preload("res://scripts/map/view3d/map_view_mesh_builder_landmarks.gd")
const _Props := preload("res://scripts/map/view3d/map_view_mesh_builder_props.gd")
const _Surroundings := preload("res://scripts/map/view3d/map_view_mesh_builder_surroundings.gd")
const _Interior := preload("res://scripts/map/view3d/map_view_mesh_builder_interior.gd")

# Re-export frequently referenced constants for backward compatibility.
const TERRAIN_SUBDIVISIONS := _Config.TERRAIN_SUBDIVISIONS
const TRANSITION_MARKER_HEIGHT := _Config.TRANSITION_MARKER_HEIGHT


static func ensure_height_field(definition: MapDefinition, grid: MapTerrainGrid) -> Dictionary:
	return _Terrain.ensure_height_field(definition, grid)


static func ground_height(definition: MapDefinition, world_xz: Vector2) -> float:
	return _Terrain.ground_height(definition, world_xz)


static func build_terrain(definition: MapDefinition, grid: MapTerrainGrid) -> Node3D:
	return _Terrain.build_terrain(definition, grid)


static func build_building(building: Dictionary, cell_size: int) -> Node3D:
	return _Buildings.build_building(building, cell_size)


static func interior_shell_wall_height_world(definition: MapDefinition) -> float:
	return _Landmarks.interior_shell_wall_height_world(definition)


static func build_landmark(
	landmark: Dictionary,
	cell_size: int,
	wall_height_world: float = -1.0
) -> Node3D:
	return _Landmarks.build_landmark(landmark, cell_size, wall_height_world)


static func transition_uses_landmark_visual(definition: MapDefinition, transition: Dictionary) -> bool:
	return _Landmarks.transition_uses_landmark_visual(definition, transition)


static func build_transition_door(
	transition: Dictionary,
	cell_size: int,
	wall_height_world: float = -1.0
) -> Node3D:
	return _Landmarks.build_transition_door(transition, cell_size, wall_height_world)


static func build_transition_marker(transition: Dictionary, cell_size: int) -> Node3D:
	return _Landmarks.build_transition_marker(transition, cell_size)


static func build_prop(
	prop: Dictionary,
	cell_size: int,
	definition: MapDefinition = null
) -> Node3D:
	return _Props.build_prop(prop, cell_size, definition)


static func build_scatter(
	definition: MapDefinition,
	grid: MapTerrainGrid,
	cell_bounds: Rect2i = Rect2i(Vector2i.ZERO, Vector2i.ZERO)
) -> Node3D:
	return _Props.build_scatter(definition, grid, cell_bounds)


static func build_surroundings(definition: MapDefinition) -> Node3D:
	return _Surroundings.build_surroundings(definition)


static func build_interior_shell(definition: MapDefinition) -> Node3D:
	return _Interior.build_interior_shell(definition)
