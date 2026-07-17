class_name MapNavBuilder
extends RefCounted

## Builds a coarse NavigationRegion2D from the world rectangle minus building
## footprints and excluded areas.
##
## Building footprints may legitimately overlap (wall segments sealed by
## towers) or sit flush against the world edge, so the outlines are baked
## through NavigationServer2D source geometry, which unions obstructions
## before triangulating; feeding raw overlapping outlines to
## make_polygons_from_outlines fails its convex partition.


static func create_navigation_region(definition: MapDefinition, grid: MapTerrainGrid) -> NavigationRegion2D:
	var region := NavigationRegion2D.new()
	region.name = "NavigationRegion2D"

	var source := NavigationMeshSourceGeometryData2D.new()
	source.add_traversable_outline(_rect_outline(Rect2(Vector2.ZERO, definition.world_size())))
	for building in definition.buildings:
		source.add_obstruction_outline(_rect_outline(building["footprint"]))
	for rect in definition.excluded_areas:
		source.add_obstruction_outline(_rect_outline(definition.cell_rect_to_world_rect(rect)))

	var nav_polygon := NavigationPolygon.new()
	nav_polygon.agent_radius = 0.0
	NavigationServer2D.bake_from_source_geometry_data(nav_polygon, source)
	region.navigation_polygon = nav_polygon
	return region


static func _rect_outline(rect: Rect2) -> PackedVector2Array:
	var outline := PackedVector2Array()
	outline.append(rect.position)
	outline.append(Vector2(rect.end.x, rect.position.y))
	outline.append(rect.end)
	outline.append(Vector2(rect.position.x, rect.end.y))
	return outline
