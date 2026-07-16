class_name MapViewBridge
extends RefCounted

## Deterministic logic-plane to 3D-view coordinate bridge (P0-052, ADR 0007).
## The flat orthogonal logic plane stays the single source of truth: logic
## pixels (x, y) map to world (x, 0, z) with one logic cell equal to one world
## unit. The bridge is one-directional in authority - view code may read logic
## positions through it but must never write world positions back.

const WORLD_UNITS_PER_CELL := 1.0


static func world_scale(cell_size: int) -> float:
	assert(cell_size > 0)
	return WORLD_UNITS_PER_CELL / float(cell_size)


static func logic_to_world(logic_position: Vector2, cell_size: int, height: float = 0.0) -> Vector3:
	var scale := world_scale(cell_size)
	return Vector3(logic_position.x * scale, height, logic_position.y * scale)


static func world_to_logic(world_position: Vector3, cell_size: int) -> Vector2:
	var scale := world_scale(cell_size)
	return Vector2(world_position.x / scale, world_position.z / scale)


static func cell_center_to_world(cell: Vector2i, cell_size: int, height: float = 0.0) -> Vector3:
	var center := (Vector2(cell) + Vector2(0.5, 0.5)) * float(cell_size)
	return logic_to_world(center, cell_size, height)


static func world_to_cell(world_position: Vector3, cell_size: int) -> Vector2i:
	var logic := world_to_logic(world_position, cell_size)
	return Vector2i(floori(logic.x / float(cell_size)), floori(logic.y / float(cell_size)))


## Places a view actor at the logic simulation's position, preserving any
## view-side vertical offset the actor already carries.
static func sync_actor(actor: Node3D, logic_position: Vector2, cell_size: int) -> void:
	var world := logic_to_world(logic_position, cell_size)
	actor.position = Vector3(world.x, actor.position.y, world.z)
