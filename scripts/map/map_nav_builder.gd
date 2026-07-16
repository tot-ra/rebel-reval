class_name MapNavBuilder
extends RefCounted

## Builds a coarse NavigationRegion2D from walkable terrain cells.


static func create_navigation_region(definition: MapDefinition, grid: MapTerrainGrid) -> NavigationRegion2D:
	var region := NavigationRegion2D.new()
	region.name = "NavigationRegion2D"

	var nav_polygon := NavigationPolygon.new()
	var outline := PackedVector2Array()
	var world := definition.world_size()
	outline.append(Vector2.ZERO)
	outline.append(Vector2(world.x, 0.0))
	outline.append(world)
	outline.append(Vector2(0.0, world.y))
	nav_polygon.add_outline(outline)

	for building in definition.buildings:
		var footprint: Rect2 = building["footprint"]
		var obstacle := PackedVector2Array()
		obstacle.append(footprint.position)
		obstacle.append(Vector2(footprint.end.x, footprint.position.y))
		obstacle.append(footprint.end)
		obstacle.append(Vector2(footprint.position.x, footprint.end.y))
		nav_polygon.add_outline(obstacle)

	for rect in definition.excluded_areas:
		var world_rect := definition.cell_rect_to_world_rect(rect)
		var obstacle := PackedVector2Array()
		obstacle.append(world_rect.position)
		obstacle.append(Vector2(world_rect.end.x, world_rect.position.y))
		obstacle.append(world_rect.end)
		obstacle.append(Vector2(world_rect.position.x, world_rect.end.y))
		nav_polygon.add_outline(obstacle)

	nav_polygon.make_polygons_from_outlines()
	region.navigation_polygon = nav_polygon
	return region
