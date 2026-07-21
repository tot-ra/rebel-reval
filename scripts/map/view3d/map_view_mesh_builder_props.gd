class_name MapViewMeshBuilderProps
extends RefCounted

## Stable facade for authored props and decorative terrain scatter.

const _PropModels := preload("res://scripts/map/view3d/map_view_mesh_builder_prop_models.gd")
const _Scatter := preload("res://scripts/map/view3d/map_view_mesh_builder_scatter.gd")

# Re-export barrel dimensions used by mesh regression tests and callers.
const BARREL_HEIGHT := _PropModels.BARREL_HEIGHT
const BARREL_BELLY_RADIUS := _PropModels.BARREL_BELLY_RADIUS
const BARREL_HEAD_RADIUS := _PropModels.BARREL_HEAD_RADIUS
const BARREL_HEAD_THICKNESS := _PropModels.BARREL_HEAD_THICKNESS
const BARREL_HOOP_PROFILE := _PropModels.BARREL_HOOP_PROFILE


static func build_prop(
	prop: Dictionary,
	cell_size: int,
	definition: MapDefinition = null
) -> Node3D:
	return _PropModels.build_prop(prop, cell_size, definition)


static func build_scatter(
	definition: MapDefinition,
	grid: MapTerrainGrid,
	cell_bounds: Rect2i = Rect2i(Vector2i.ZERO, Vector2i.ZERO)
) -> Node3D:
	return _Scatter.build_scatter(definition, grid, cell_bounds)
