class_name MapVerification
extends RefCounted

## Deterministic map checks shared by conversion tests.


static func blocked_cells(definition: MapDefinition) -> Dictionary:
	var blocked: Dictionary = {}
	for building in definition.buildings:
		var footprint: Rect2 = building["footprint"]
		var start_cell := Vector2i(
			int(floor(footprint.position.x / definition.cell_size)),
			int(floor(footprint.position.y / definition.cell_size))
		)
		var end_cell := Vector2i(
			int(ceil(footprint.end.x / definition.cell_size)),
			int(ceil(footprint.end.y / definition.cell_size))
		)
		for y in range(start_cell.y, end_cell.y):
			for x in range(start_cell.x, end_cell.x):
				blocked[Vector2i(x, y)] = true
	for rect in definition.excluded_areas:
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				blocked[Vector2i(x, y)] = true
	return blocked


static func is_walkable_cell(definition: MapDefinition, grid: MapTerrainGrid, cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= definition.size_cells.x or cell.y >= definition.size_cells.y:
		return false
	if MapTypes.WATER_TERRAINS.has(grid.get_terrain(cell)):
		return false
	if blocked_cells(definition).has(cell):
		return false
	return true


static func cell_center(definition: MapDefinition, cell: Vector2i) -> Vector2:
	return definition.cell_rect_center(Rect2i(cell, Vector2i.ONE))


static func nearest_walkable_cell(definition: MapDefinition, grid: MapTerrainGrid, target: Vector2) -> Vector2i:
	var origin := Vector2i(
		int(clampf(floor(target.x / definition.cell_size), 0, definition.size_cells.x - 1)),
		int(clampf(floor(target.y / definition.cell_size), 0, definition.size_cells.y - 1))
	)
	if is_walkable_cell(definition, grid, origin):
		return origin
	var max_radius := maxi(definition.size_cells.x, definition.size_cells.y)
	for radius in range(1, max_radius + 1):
		for y in range(origin.y - radius, origin.y + radius + 1):
			for x in range(origin.x - radius, origin.x + radius + 1):
				var cell := Vector2i(x, y)
				if is_walkable_cell(definition, grid, cell):
					return cell
	return origin


static func is_walkable_point(definition: MapDefinition, grid: MapTerrainGrid, point: Vector2) -> bool:
	var cell := Vector2i(
		int(floor(point.x / definition.cell_size)),
		int(floor(point.y / definition.cell_size))
	)
	return is_walkable_cell(definition, grid, cell)


static func route_exists_exact(definition: MapDefinition, grid: MapTerrainGrid, from_pos: Vector2, to_pos: Vector2) -> bool:
	## Required points must themselves be walkable. Snapping a blocked spawn or
	## transition to a nearby cell would hide parity regressions in final audits.
	if not is_walkable_point(definition, grid, from_pos) or not is_walkable_point(definition, grid, to_pos):
		return false
	var start := Vector2i(floori(from_pos.x / definition.cell_size), floori(from_pos.y / definition.cell_size))
	var goal := Vector2i(floori(to_pos.x / definition.cell_size), floori(to_pos.y / definition.cell_size))
	return _route_between_cells(definition, grid, start, goal)


static func route_exists(definition: MapDefinition, grid: MapTerrainGrid, from_pos: Vector2, to_pos: Vector2) -> bool:
	var start := nearest_walkable_cell(definition, grid, from_pos)
	var goal := nearest_walkable_cell(definition, grid, to_pos)
	return _route_between_cells(definition, grid, start, goal)


static func _route_between_cells(definition: MapDefinition, grid: MapTerrainGrid, start: Vector2i, goal: Vector2i) -> bool:
	if start == goal:
		return true

	var queue: Array[Vector2i] = [start]
	var visited: Dictionary = {start: true}
	var directions := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current == goal:
			return true
		for direction in directions:
			var next: Vector2i = current + direction
			if visited.has(next):
				continue
			if not is_walkable_cell(definition, grid, next):
				continue
			visited[next] = true
			queue.append(next)
	return false


static func anchor_position(definition: MapDefinition, anchor_id: StringName) -> Vector2:
	for anchor in definition.interaction_anchors:
		if anchor["id"] == anchor_id:
			return anchor["position"]
	return Vector2.ZERO


static func transition_rect(definition: MapDefinition, transition_id: StringName) -> Rect2:
	for transition in definition.transitions:
		if transition["id"] == transition_id:
			return transition["rect"]
	return Rect2()


static func has_anchor(definition: MapDefinition, anchor_id: StringName) -> bool:
	return anchor_position(definition, anchor_id) != Vector2.ZERO


static func collision_parity(definition: MapDefinition) -> bool:
	for building in definition.buildings:
		var body := MapBuildingRenderer.create_building(building)
		var footprint: Rect2 = building["footprint"]
		var collision := body.get_child(0) as CollisionShape2D
		if collision == null:
			body.free()
			return false
		var shape := collision.shape as RectangleShape2D
		if shape == null:
			body.free()
			return false
		var collision_rect := Rect2(body.position + collision.position - shape.size * 0.5, shape.size)
		if collision_rect != footprint:
			body.free()
			return false
		body.free()
	return true
