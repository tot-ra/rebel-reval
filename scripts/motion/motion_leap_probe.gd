extends RefCounted

## What lies ahead of a body, as the leap network reads it (ADR 0053): every `spacing` leg lengths
## along `direction`, the height of whatever is solid there relative to the feet and the depth of
## water on it, and whether it can be stood on. The ground and the water surface come from
## `ground_fn(world_xz) -> Vector2(ground_y, water_surface_y)` (the city plan's walk height and
## water); walls and buildings come from the logic-plane collision: a shape that carries
## `TOP_META` (CityCollisionBuilder tags walls with the world height of their top) is that high,
## any other solid shape counts as `UNKNOWN_HEIGHT` above the ground (a house). Nothing can be
## stood on inside a solid shape.

const TOP_META := &"top_y"
const UNKNOWN_HEIGHT := 12.0
## CollisionLayers.WORLD
const WORLD_MASK := 1


static func profile(
	space: PhysicsDirectSpaceState2D,
	ground_fn: Callable,
	from_logic: Vector2,
	direction: Vector2,
	leg: float,
	n: int,
	spacing: float,
	px_per_m: float
) -> Dictionary:
	var g0: Vector2 = ground_fn.call(from_logic / px_per_m)
	var ground0 := g0.x
	var z := PackedFloat32Array()
	var w := PackedFloat32Array()
	var standable: Array = []
	var points: Array = []
	for i in n:
		var logic := from_logic + direction * spacing * float(i + 1) * leg * px_per_m
		var xz := logic / px_per_m
		var g: Vector2 = ground_fn.call(xz)
		var top := barrier_top(space, logic, g.x)
		if is_nan(top):
			z.append(g.x - ground0)
			w.append(maxf(g.y - g.x, 0.0))
			standable.append(true)
		else:
			z.append(maxf(top, g.x) - ground0)
			w.append(0.0)
			standable.append(false)
		points.append(xz)
	return {"z": z, "w": w, "standable": standable, "points": points, "ground0": ground0}


## World height of the top of a solid shape at a logic point, or NAN where there is none.
static func barrier_top(space: PhysicsDirectSpaceState2D, logic: Vector2, ground_y: float) -> float:
	if space == null:
		return NAN
	var query := PhysicsPointQueryParameters2D.new()
	query.position = logic
	query.collision_mask = WORLD_MASK
	query.collide_with_areas = false
	var hits := space.intersect_point(query, 8)
	var top := NAN
	for hit: Dictionary in hits:
		var body := hit.get("collider") as CollisionObject2D
		var h := ground_y + UNKNOWN_HEIGHT
		if body != null:
			var owner_id := body.shape_find_owner(int(hit.get("shape", 0)))
			var shape_node := body.shape_owner_get_owner(owner_id) as Node
			if shape_node != null and shape_node.has_meta(TOP_META):
				h = float(shape_node.get_meta(TOP_META))
		top = h if is_nan(top) else maxf(top, h)
	return top
