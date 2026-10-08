class_name CityGroundTrail
extends Node3D

## Soft ground remembers where it was walked. A square window of WINDOW_CELLS
## cells follows Kalev and holds a one-channel relief image (0.5 = untouched,
## below = pressed down, above = pushed up as a rim). Each footfall presses an
## oval into it and heaps a rim around it; wheels and hooves use the same
## `stamp_*` calls. The ground shader (`trail`, `trail_rect`) turns the image
## into relief, damp darkening and puddles: deep and glossy in rain, shallow
## and dusty when dry. Dry footfalls on soft ground also kick up a puff of dust.
## Prints are visual only: they do not change walking speed or the heightfield.
## Other walkers feed the same window through `track_walker`, `track_hooves` and
## `track_cart` (CityTrailFeed calls them every frame): only those inside
## TRACK_RADIUS of Kalev and inside the window leave marks, and depth follows
## `wetness` exactly as Kalev's own prints do.
## Near Kalev a fine relief mesh (`_relief`, the ground shader's trail mesh mode)
## lifts the prints into real geometry so a grazing camera sees their silhouette.

const WINDOW_CELLS := 1024
## One cell in world units: a boot is ~0.13 wu wide, so 0.04 gives it 3-4 cells.
## 1024 cells * 0.04 = a 41 wu window.
const CELL := 0.04
## Distance walked per footfall, in world units.
const STRIDE := 0.85
## Recentre when Kalev gets this close to the window edge.
const EDGE_MARGIN := 12.0
const NEUTRAL := 0.5
## Half extents of the whole print (along, across). A turnshoe is ~0.38 wu long.
const FOOT_RADIUS := Vector2(0.19, 0.075)
const FOOT_SPREAD := 0.1
## Toe-out of each foot in radians, left and right mirrored.
const TOE_OUT := 0.14
## Heel strike presses harder than the ball of the foot.
const HEEL_DEPTH := 1.25
## Footfalls only bite where the ground gives (splat earth/mud minus paving).
const MIN_SOFTNESS := 0.12
## Below this wetness the footfall raises dust instead of nothing.
const DRY_WETNESS := 0.35
## A jump further than this in one frame is a teleport: start a fresh window.
const TELEPORT := 10.0
## Other walkers, animals and carts mark the ground only this close to Kalev:
## beyond it nobody can see the print and the stamps would be wasted work.
const TRACK_RADIUS := 20.0
## Keep marks off the very edge of the window, where a recentre would clip them.
const TRACK_MARGIN := 1.0
## One walker moving further than this between two calls was moved, not walked.
const MARK_TELEPORT := 4.0
## Relief mesh half extent and fine vertex spacing in world units. The spacing is
## one trail cell and divides the height grid cell, so the vertices sit on trail
## texel corners and stay put in the world as the mesh re-snaps (no swimming or
## beat pattern against the trail texels). Only the core within RELIEF_FINE_HALF
## of the centre is that fine; outside it every other vertex is kept (0.08 wu),
## because the vertex stage is what the mesh costs.
const RELIEF_HALF := 6.2
const RELIEF_STEP := CELL
const RELIEF_FINE_HALF := 3.16
## Per species: hoof half extents (along, across), distance between the left and
## right hoof, distance walked per hoof pair, weight against a person's.
const HOOVES := {
	&"horse": {"radii": Vector2(0.075, 0.07), "gauge": 0.28, "stride": 1.1, "weight": 1.5},
	&"cow": {"radii": Vector2(0.06, 0.04), "gauge": 0.3, "stride": 0.95, "weight": 1.3},
	&"pig": {"radii": Vector2(0.045, 0.03), "gauge": 0.2, "stride": 0.5, "weight": 0.8},
	&"goat": {"radii": Vector2(0.045, 0.03), "gauge": 0.16, "stride": 0.45, "weight": 0.7},
	&"sheep": {"radii": Vector2(0.045, 0.03), "gauge": 0.18, "stride": 0.45, "weight": 0.7},
}

var wetness := 0.0

var _plan: CityPlan
var _surface: Callable
var _image: Image
var _texture: ImageTexture
var _origin := Vector2.ZERO
var _last := Vector2.INF
var _travelled := 0.0
var _left_foot := true
var _dirty := false
var _dust: CPUParticles3D
## Walkers seen this frame: key -> {at, travelled, left, seen}. A walker that
## stops being fed (out of range, despawned) is forgotten after a frame.
var _marks: Dictionary = {}
var _tick := 0
var _relief: MeshInstance3D
var _relief_centre := Vector2.INF


static func create(city_plan: CityPlan, surface: Callable) -> CityGroundTrail:
	var node := CityGroundTrail.new()
	node.name = "GroundTrail"
	node._plan = city_plan
	node._surface = surface
	node._image = Image.create_empty(WINDOW_CELLS, WINDOW_CELLS, false, Image.FORMAT_R8)
	node._image.fill(Color(NEUTRAL, 0.0, 0.0))
	node._texture = ImageTexture.create_from_image(node._image)
	node._build_dust()
	node._build_relief()
	return node


## World rectangle the window covers: Vector4(origin.x, origin.z, size.x, size.z).
func window_rect() -> Vector4:
	var size := float(WINDOW_CELLS) * CELL
	return Vector4(_origin.x, _origin.y, size, size)


## Relief at a world position, 0.5 untouched (tests and debugging).
func value_at(world_xz: Vector2) -> float:
	var c := _cell_of(world_xz)
	if not _in_window(c):
		return NEUTRAL
	return _image.get_pixel(c.x, c.y).r


func update_for(world_xz: Vector2, _delta: float) -> void:
	if _last == Vector2.INF or _last.distance_to(world_xz) > TELEPORT:
		_recentre(world_xz)
		_place_relief(world_xz)
		_last = world_xz
		return
	var half := float(WINDOW_CELLS) * CELL * 0.5
	if absf(world_xz.x - (_origin.x + half)) > half - EDGE_MARGIN or (
		absf(world_xz.y - (_origin.y + half)) > half - EDGE_MARGIN
	):
		_recentre(world_xz)
	_place_relief(world_xz)
	var step := world_xz - _last
	_travelled += step.length()
	if _travelled >= STRIDE and step.length() > 0.0001:
		_travelled = fmod(_travelled, STRIDE)
		_footfall(world_xz, step.normalized())
	_last = world_xz
	_forget_unseen()
	if _dirty:
		_texture.update(_image)
		_dirty = false


## A person on foot (a citizen): one boot print per STRIDE, left and right
## alternating, lighter than Kalev's own. `key` is any stable id of the walker.
func track_walker(key: Variant, world_xz: Vector2) -> void:
	var mark := _advance_mark(key, world_xz)
	if mark.is_empty() or float(mark["travelled"]) < STRIDE:
		return
	mark["travelled"] = fmod(float(mark["travelled"]), STRIDE)
	var soft := _softness_at(world_xz)
	if soft.x < MIN_SOFTNESS:
		return
	var facing: Vector2 = mark["facing"]
	var foot_sign := 1.0 if mark["left"] else -1.0
	mark["left"] = not mark["left"]
	var side := Vector2(-facing.y, facing.x)
	stamp_foot(
		world_xz + side * FOOT_SPREAD * foot_sign,
		facing.rotated(TOE_OUT * foot_sign),
		_weight() * 0.85
	)


## A hoofed animal (`species` is a key of HOOVES, anything else leaves nothing):
## a left and a right hoof per stride, the right one half a stride behind.
func track_hooves(key: Variant, world_xz: Vector2, species: StringName) -> void:
	if not HOOVES.has(species):
		return
	var spec: Dictionary = HOOVES[species]
	var mark := _advance_mark(key, world_xz)
	if mark.is_empty() or float(mark["travelled"]) < float(spec["stride"]):
		return
	mark["travelled"] = fmod(float(mark["travelled"]), float(spec["stride"]))
	if _softness_at(world_xz).x < MIN_SOFTNESS:
		return
	var facing: Vector2 = mark["facing"]
	var side := Vector2(-facing.y, facing.x)
	var half := float(spec["gauge"]) * 0.5
	var radii: Vector2 = spec["radii"]
	var depth := minf(0.5 * _weight() * float(spec["weight"]), 0.95)
	var back := facing * float(spec["stride"]) * 0.5
	stamp_oval(world_xz + side * half, radii, facing, depth, 0.14 * _weight())
	stamp_oval(world_xz - side * half - back, radii, facing, depth, 0.14 * _weight())


## A cart, wagon, barrow or sledge rolling: one groove per wheel (or runner)
## from where it was last fed to where it is now. `vehicle_class` is a
## CartTransportModel class; one it has no wheel track for leaves nothing.
func track_cart(key: Variant, world_xz: Vector2, vehicle_class: StringName) -> void:
	var spec := CartTransportModel.wheel_track_spec(vehicle_class)
	if spec.is_empty():
		return
	var previous: Vector2 = _marks[key]["at"] if _marks.has(key) else world_xz
	# A groove is drawn per segment of at least two cells: a slow cart is not
	# lost to many tiny steps, and a fresh mark has no earlier point to draw from.
	var mark := _advance_mark(key, world_xz, CELL * 2.0)
	if mark.is_empty():
		return
	if _softness_at(world_xz).x < MIN_SOFTNESS:
		return
	var dir: Vector2 = mark["facing"]
	var side := Vector2(-dir.y, dir.x)
	var depth := minf((0.3 + 0.9 * clampf(wetness, 0.0, 1.0)) * float(spec["load"]), 0.95)
	var gauge := float(spec["gauge"])
	var offsets: Array[float] = []
	if gauge <= 0.0:
		offsets.append(0.0)
	else:
		offsets.append(gauge * 0.5)
		offsets.append(-gauge * 0.5)
	for off in offsets:
		stamp_track(previous + side * off, world_xz + side * off, float(spec["half_width"]), depth)


## One footprint: an oval pressed in, a rim heaped round it. `facing` is the
## direction of travel in world XZ; `weight` scales depth (running is heavier).
func stamp_foot(world_xz: Vector2, facing: Vector2, weight := 1.0) -> void:
	# A boot is two lobes, a narrow heel and a broad ball with the toes: that
	# reads as a footprint where a single oval reads as a puddle.
	var fwd := facing.normalized()
	var ball_depth := minf(0.55 * weight, 0.9)
	var heel_depth := minf(0.55 * weight * HEEL_DEPTH, 0.95)
	var rim := 0.16 * weight
	stamp_oval(world_xz + fwd * 0.07, Vector2(0.125, 0.075), fwd, ball_depth, rim)
	stamp_oval(world_xz - fwd * 0.09, Vector2(0.095, 0.062), fwd, heel_depth, rim)
	# The arch barely touches the ground; it joins the lobes into one sole.
	stamp_oval(world_xz - fwd * 0.01, Vector2(0.08, 0.045), fwd, ball_depth * 0.45, 0.0)


## A pressed oval with a rim. `radii` are the half extents (along, across the
## facing direction) in world units; depth and rim are 0..1 of full relief.
func stamp_oval(
	world_xz: Vector2, radii: Vector2, facing: Vector2, depth: float, rim: float
) -> void:
	var reach := maxf(radii.x, radii.y) * 1.6
	var lo := _cell_of(world_xz - Vector2(reach, reach))
	var hi := _cell_of(world_xz + Vector2(reach, reach))
	var fwd := facing.normalized()
	var side := Vector2(-fwd.y, fwd.x)
	for cy in range(maxi(lo.y, 0), mini(hi.y, WINDOW_CELLS - 1) + 1):
		for cx in range(maxi(lo.x, 0), mini(hi.x, WINDOW_CELLS - 1) + 1):
			var p := _origin + (Vector2(cx, cy) + Vector2(0.5, 0.5)) * CELL - world_xz
			var u := p.dot(fwd) / radii.x
			var v := p.dot(side) / radii.y
			var r2 := u * u + v * v
			var current := _image.get_pixel(cx, cy).r
			if r2 < 1.0:
				# Steep walls and a flat floor, softened so a print is not a stencil.
				var press := depth * smoothstep(1.0, 0.3, r2)
				current = minf(current, NEUTRAL - NEUTRAL * press)
				current = clampf(current, 0.0, 1.0)
				_image.set_pixel(cx, cy, Color(current, 0.0, 0.0))
			elif r2 < 2.4 and current >= NEUTRAL - 0.02:
				var heap := rim * (1.0 - (r2 - 1.0) / 1.4)
				current = maxf(current, NEUTRAL + NEUTRAL * heap)
				_image.set_pixel(cx, cy, Color(minf(current, 1.0), 0.0, 0.0))
	_dirty = true


## A wheel track along a segment: a groove `half_width` each side of the line.
func stamp_track(a: Vector2, b: Vector2, half_width: float, depth: float) -> void:
	var length := a.distance_to(b)
	if length < 0.0001:
		return
	var dir := (b - a) / length
	var steps := maxi(int(ceil(length / (CELL * 2.0))), 1)
	for i in steps + 1:
		var at := a.lerp(b, float(i) / float(steps))
		stamp_oval(at, Vector2(CELL * 2.5, half_width), dir, depth, 0.1)


## Vector2(give, softness) of the ground at a spot: give is what a print needs
## (grass and sand take a faint one, paving none), softness is bare earth/mud.
func _softness_at(world_xz: Vector2) -> Vector2:
	var s: Color = _surface.call(world_xz)
	var softness := clampf(maxf(s.g, s.a) - s.r, 0.0, 1.0)
	var give := maxf(softness, (1.0 - s.r) * 0.25)
	if _plan.ground_height(world_xz) < 0.4:
		give = 0.0
	return Vector2(give, softness)


## Dry ground only crumbles; wet clay gives under the full weight.
func _weight() -> float:
	return 0.4 + 1.15 * clampf(wetness, 0.0, 1.0)


## Update a walker's mark with its new position. Returns the mark (with the
## direction of travel in `facing` and the distance walked since the last
## print in `travelled`), or {} if the walker may not leave a print now: outside
## the tracked area, just appeared, or moved less than `min_step` (its mark then
## keeps the old position so slow movement still adds up).
func _advance_mark(key: Variant, world_xz: Vector2, min_step := 0.0001) -> Dictionary:
	if _last == Vector2.INF or _last.distance_to(world_xz) > TRACK_RADIUS:
		_marks.erase(key)
		return {}
	var c := _cell_of(world_xz)
	var margin := int(TRACK_MARGIN / CELL)
	if (
		c.x < margin or c.y < margin
		or c.x >= WINDOW_CELLS - margin or c.y >= WINDOW_CELLS - margin
	):
		_marks.erase(key)
		return {}
	var mark: Dictionary = _marks.get(key, {})
	if mark.is_empty() or (mark["at"] as Vector2).distance_to(world_xz) > MARK_TELEPORT:
		_marks[key] = {
			"at": world_xz, "travelled": 0.0, "left": true, "seen": _tick,
			"facing": Vector2.RIGHT,
		}
		return {}
	var step := world_xz - (mark["at"] as Vector2)
	mark["seen"] = _tick
	if step.length() < min_step:
		return {}
	mark["travelled"] = float(mark["travelled"]) + step.length()
	mark["facing"] = step.normalized()
	mark["at"] = world_xz
	return mark


## Drop walkers that were not fed during the last frame, then start a new one.
func _forget_unseen() -> void:
	for key in _marks.keys():
		if int(_marks[key]["seen"]) < _tick:
			_marks.erase(key)
	_tick += 1


func _footfall(world_xz: Vector2, facing: Vector2) -> void:
	var soft := _softness_at(world_xz)
	var softness := soft.y
	if soft.x < MIN_SOFTNESS:
		return
	var side := Vector2(-facing.y, facing.x)
	var foot_sign := 1.0 if _left_foot else -1.0
	var foot := world_xz + side * FOOT_SPREAD * foot_sign
	_left_foot = not _left_foot
	stamp_foot(foot, facing.rotated(TOE_OUT * foot_sign), _weight())
	if wetness < DRY_WETNESS and softness >= 0.4:
		_puff(foot)


func _recentre(world_xz: Vector2) -> void:
	var half := float(WINDOW_CELLS) * CELL * 0.5
	# Snap to whole cells so existing prints stay put under the new window.
	var new_origin := (world_xz - Vector2(half, half) / 1.0)
	new_origin = (new_origin / CELL).round() * CELL
	var shift := ((new_origin - _origin) / CELL).round()
	var fresh := Image.create_empty(WINDOW_CELLS, WINDOW_CELLS, false, Image.FORMAT_R8)
	fresh.fill(Color(NEUTRAL, 0.0, 0.0))
	if absf(shift.x) < WINDOW_CELLS and absf(shift.y) < WINDOW_CELLS:
		var src := Rect2i(Vector2i.ZERO, Vector2i(WINDOW_CELLS, WINDOW_CELLS))
		var dst := -Vector2i(shift)
		fresh.blit_rect(_image, src, dst)
	_image = fresh
	_origin = new_origin
	_texture.update(_image)
	_dirty = false
	_apply_to_ground()


func _apply_to_ground() -> void:
	var ground := CityTerrainBuilder.shared_material()
	if ground == null:
		return
	ground.set_shader_parameter("trail", _texture)
	ground.set_shader_parameter("trail_rect", window_rect())


func _exit_tree() -> void:
	# Stop the chunks sinking with no mesh over them; re-entering places it afresh.
	_relief_centre = Vector2.INF
	var ground := CityTerrainBuilder.shared_material()
	if ground != null:
		ground.set_shader_parameter("trail_mesh_rect", Vector4.ZERO)


## A flat grid; the ground shader sets every vertex height, so the AABB spans
## any height the city has. Vertex colour alpha 0 is what tells the shader this
## is the relief mesh and not a terrain chunk.
func _build_relief() -> void:
	_relief = MeshInstance3D.new()
	_relief.name = "TrailRelief"
	_relief.mesh = relief_mesh()
	_relief.top_level = true
	_relief.visible = false
	_relief.custom_aabb = AABB(
		Vector3(-RELIEF_HALF, -100.0, -RELIEF_HALF), Vector3(RELIEF_HALF * 2.0, 600.0, RELIEF_HALF * 2.0)
	)
	add_child(_relief)


## The relief grid, centred on the origin: RELIEF_STEP quads in the core, double
## size quads outside it. A coarse quad on the core's edge also takes the fine
## vertex in the middle of that edge and is fanned into three triangles, so the
## two densities meet without T-junction cracks.
static func relief_mesh() -> ArrayMesh:
	var n := roundi(RELIEF_HALF * 2.0 / RELIEF_STEP)
	var mid := n / 2
	var core := roundi(RELIEF_FINE_HALF / RELIEF_STEP)
	# Core bounds on even indices so the coarse lattice (even indices) meets it.
	var lo := (mid - core) & ~1
	var hi := lo + 2 * core
	var ids := PackedInt32Array()
	ids.resize((n + 1) * (n + 1))
	ids.fill(-1)
	var verts := PackedVector3Array()
	for j in n + 1:
		for i in n + 1:
			var in_core := i >= lo and i <= hi and j >= lo and j <= hi
			if in_core or (i % 2 == 0 and j % 2 == 0):
				ids[j * (n + 1) + i] = verts.size()
				verts.append(Vector3(float(i - mid), 0.0, float(j - mid)) * RELIEF_STEP)
	var at := func(i: int, j: int) -> int: return ids[j * (n + 1) + i]
	var indices := PackedInt32Array()
	# Same winding as CityTerrainBuilder._chunk_mesh: (x0z0, x1z0, x1z1, x0z1).
	for j in range(lo, hi):
		for i in range(lo, hi):
			indices.append_array(
				[at.call(i, j), at.call(i + 1, j), at.call(i + 1, j + 1),
				at.call(i, j), at.call(i + 1, j + 1), at.call(i, j + 1)]
			)
	for j in range(0, n, 2):
		for i in range(0, n, 2):
			if i >= lo and i + 2 <= hi and j >= lo and j + 2 <= hi:
				continue
			# Corners and edge midpoints in winding order; a midpoint exists only
			# where the edge lies on the core boundary (at most one per quad).
			var ring: Array[int] = []
			var split := -1
			var candidates: Array[Vector2i] = [
				Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 2, j), Vector2i(i + 2, j + 1),
				Vector2i(i + 2, j + 2), Vector2i(i + 1, j + 2), Vector2i(i, j + 2), Vector2i(i, j + 1),
			]
			for c in candidates.size():
				var id: int = at.call(candidates[c].x, candidates[c].y)
				if id >= 0:
					if c % 2 == 1:
						split = ring.size()
					ring.append(id)
			# Fan from the corner two after the midpoint: it is off the split
			# edge, so no triangle is degenerate.
			var first := 0 if split < 0 else (split + 2) % ring.size()
			for k in range(1, ring.size() - 1):
				indices.append_array(
					[ring[first], ring[(first + k) % ring.size()], ring[(first + k + 1) % ring.size()]]
				)
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	var tangents := PackedFloat32Array()
	for v in verts.size():
		tangents.append_array([1.0, 0.0, 0.0, 1.0])
	var colors := PackedColorArray()
	colors.resize(verts.size())
	colors.fill(Color(0.0, 0.0, 0.0, 0.0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Keep the relief mesh round Kalev, centred on a height grid vertex: the chunk
## vertices the shader sinks under it are then a fixed set until the next snap,
## and the sunk cells always lie inside the mesh.
func _place_relief(world_xz: Vector2) -> void:
	var ground := CityTerrainBuilder.shared_material()
	if ground == null or _relief == null:
		return
	var cell := _plan.height_cell()
	var origin := _plan.height_origin()
	var centre := origin + ((world_xz - origin) / cell).round() * cell
	if centre == _relief_centre:
		return
	_relief_centre = centre
	_relief.material_override = ground
	# top_level: position is the world position, and works before the node enters the tree.
	_relief.position = Vector3(centre.x, 0.0, centre.y)
	_relief.visible = true
	# Sink grid vertices whose surrounding cells lie wholly inside the mesh.
	var sink_half := (floorf(RELIEF_HALF / cell) - 1.0) * cell + cell * 0.25
	ground.set_shader_parameter("trail_mesh_rect", Vector4(centre.x, centre.y, sink_half, 1.0))


func _cell_of(world_xz: Vector2) -> Vector2i:
	var c := ((world_xz - _origin) / CELL).floor()
	return Vector2i(int(c.x), int(c.y))


func _in_window(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < WINDOW_CELLS and c.y < WINDOW_CELLS


func _build_dust() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0.5))
	gradient.set_color(1, Color(1, 1, 1, 0.0))
	var sprite := GradientTexture2D.new()
	sprite.gradient = gradient
	sprite.fill = GradientTexture2D.FILL_RADIAL
	sprite.fill_from = Vector2(0.5, 0.5)
	sprite.fill_to = Vector2(0.5, 0.0)
	sprite.width = 64
	sprite.height = 64
	var quad := QuadMesh.new()
	quad.size = Vector2(0.55, 0.55)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = sprite
	mat.albedo_color = Color(0.74, 0.66, 0.52)
	quad.material = mat
	_dust = CPUParticles3D.new()
	_dust.name = "Dust"
	_dust.mesh = quad
	_dust.amount = 10
	_dust.lifetime = 1.1
	_dust.one_shot = true
	_dust.explosiveness = 1.0
	_dust.emitting = false
	_dust.direction = Vector3.UP
	_dust.spread = 55.0
	_dust.initial_velocity_min = 0.25
	_dust.initial_velocity_max = 0.7
	_dust.gravity = Vector3(0.0, 0.1, 0.0)
	_dust.damping_min = 0.6
	_dust.damping_max = 1.2
	_dust.scale_amount_min = 0.5
	_dust.scale_amount_max = 1.3
	_dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.55))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	_dust.color_ramp = fade
	add_child(_dust)


func _puff(world_xz: Vector2) -> void:
	if not is_inside_tree():
		return
	_dust.position = Vector3(world_xz.x, _plan.ground_height(world_xz) + 0.05, world_xz.y)
	_dust.restart()
	_dust.emitting = true
