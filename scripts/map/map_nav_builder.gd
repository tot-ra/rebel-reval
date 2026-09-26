class_name MapNavBuilder
extends RefCounted

const GridRegionMergerScript := preload("res://scripts/map/grid_region_merger.gd")

const AGENT_RADIUS := 16.0
# Godot's 2D bake can leave a zero-width partition when two authored
# obstructions meet exactly at the agent-radius boundary. A sub-pixel
# expansion keeps navigation conservative while preserving the authored
# collision rectangles and the player's configured clearance.
const NAVIGATION_OUTLINE_EPSILON := 0.01
const NAV_BAKE_PUBLISHER_NAME := "NavBakePublisher"

## Builds a coarse NavigationRegion2D from the world rectangle minus building
## footprints and excluded areas.
##
## Building footprints may legitimately overlap (wall segments sealed by
## towers) or sit flush against the world edge, so the outlines are baked
## through NavigationServer2D source geometry, which unions obstructions
## before triangulating; feeding raw overlapping outlines to
## make_polygons_from_outlines fails its convex partition.


static func create_navigation_region(
	definition: MapDefinition, grid: MapTerrainGrid
) -> NavigationRegion2D:
	var region := NavigationRegion2D.new()
	region.name = "NavigationRegion2D"
	region.navigation_polygon = bake_navigation_polygon(definition, grid)
	return region


## WB-07: same region, but the bake runs on a WorkerThreadPool task. The region is
## returned immediately with no polygon and a publisher child that assigns the
## finished polygon in one step, so pathing never sees a partial mesh. Tests and
## callers that must block can use NavBakeJob.wait() via bake_job_of(region).
static func create_navigation_region_threaded(
	definition: MapDefinition, grid: MapTerrainGrid
) -> NavigationRegion2D:
	var region := NavigationRegion2D.new()
	region.name = "NavigationRegion2D"
	var publisher := NavBakePublisher.new()
	publisher.name = NAV_BAKE_PUBLISHER_NAME
	publisher.job = start_bake(definition, grid)
	region.add_child(publisher)
	return region


## The pending job of a region built by create_navigation_region_threaded(), or null
## once it has been published.
static func bake_job_of(region: NavigationRegion2D) -> NavBakeJob:
	var publisher := region.get_node_or_null(NAV_BAKE_PUBLISHER_NAME) as NavBakePublisher
	return publisher.job if publisher != null else null


static func start_bake(definition: MapDefinition, grid: MapTerrainGrid) -> NavBakeJob:
	var job := NavBakeJob.new()
	# Both inputs are immutable once compiled, so the worker can read them while
	# the main thread keeps assembling the view.
	job.task_id = WorkerThreadPool.add_task(
		func() -> void: job.result = bake_navigation_polygon(definition, grid),
		false,
		"MapNavBuilder bake %s" % String(definition.map_id)
	)
	return job


## Thread-safe: builds source geometry from immutable data and bakes it through
## NavigationServer2D's generator, which does not touch the scene tree.
static func bake_navigation_polygon(
	definition: MapDefinition, grid: MapTerrainGrid
) -> NavigationPolygon:
	var source := NavigationMeshSourceGeometryData2D.new()
	source.add_traversable_outline(_rect_outline(Rect2(Vector2.ZERO, definition.world_size())))
	for building in definition.buildings:
		for collision_rect in MapWallWalkAccess.collision_rects(definition, building):
			_source_add_obstruction(source, collision_rect)
	for rect in definition.excluded_areas:
		_source_add_obstruction(source, definition.cell_rect_to_world_rect(rect))
	var water_rects := GridRegionMergerScript.merge_matching_cells(
		definition.size_cells,
		func(cell: Vector2i) -> bool: return MapTypes.WATER_TERRAINS.has(grid.get_terrain(cell))
	)
	for rect in water_rects:
		_source_add_obstruction(source, definition.cell_rect_to_world_rect(rect))

	var nav_polygon := NavigationPolygon.new()
	# Match the player's physics capsule so click paths cannot cut through
	# building corners that direct movement cannot physically clear.
	nav_polygon.agent_radius = AGENT_RADIUS
	NavigationServer2D.bake_from_source_geometry_data(nav_polygon, source)
	return nav_polygon


static func _source_add_obstruction(
	source: NavigationMeshSourceGeometryData2D, rect: Rect2
) -> void:
	source.add_obstruction_outline(_rect_outline(rect.grow(NAVIGATION_OUTLINE_EPSILON)))


static func _rect_outline(rect: Rect2) -> PackedVector2Array:
	var outline := PackedVector2Array()
	outline.append(rect.position)
	outline.append(Vector2(rect.end.x, rect.position.y))
	outline.append(rect.end)
	outline.append(Vector2(rect.position.x, rect.end.y))
	return outline


## A navigation bake running on the WorkerThreadPool. The result is written once by
## the worker and only read after the task is known to be complete.
class NavBakeJob:
	extends RefCounted

	var task_id := -1
	var result: NavigationPolygon
	var _joined := false

	func is_done() -> bool:
		return _joined or WorkerThreadPool.is_task_completed(task_id)

	## Blocks until the worker finishes. Every started task must be joined once,
	## including cancelled ones, or WorkerThreadPool keeps its bookkeeping.
	func wait() -> NavigationPolygon:
		if not _joined:
			WorkerThreadPool.wait_for_task_completion(task_id)
			_joined = true
		return result


## Polls its job each frame and swaps the finished polygon into the parent region
## in one assignment. Freeing the region early (cancelled mount) joins the worker
## and drops the result, so no partial region is ever published.
class NavBakePublisher:
	extends Node

	signal published(polygon: NavigationPolygon)

	var job: NavBakeJob

	func _process(_delta: float) -> void:
		if job != null and job.is_done():
			publish()

	## Blocks if needed, publishes, and removes itself. Safe to call directly.
	func publish() -> void:
		if job == null:
			return
		var polygon := job.wait()
		job = null
		var region := get_parent() as NavigationRegion2D
		if region != null:
			region.navigation_polygon = polygon
		published.emit(polygon)
		queue_free()

	func _notification(what: int) -> void:
		# Cancellation path: the region is freed before publish, so join the worker
		# and drop the polygon instead of leaving a task nobody waits for.
		if what == NOTIFICATION_PREDELETE and job != null:
			job.wait()
			job = null
