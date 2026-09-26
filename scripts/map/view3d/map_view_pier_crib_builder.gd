class_name MapViewPierCribBuilder
extends RefCounted

## WS-13d: view-only log cribs and guide piles under timber landing decks.
##
## Timber decks (`SEA_BASIN_PIER_TERRAINS`) stand on the height field as solid ground,
## so under water the WS-13b basin showed them as a smooth earth mound. The basin now
## drops beside a deck within one terrain subvertex (`SEA_BASIN_PIER_SLOPE`) and this
## builder clads that face with stacked horizontal logs (a stone-filled crib, the
## reconstructed 1343 "timber/rubble landing" of docs/reports/reval_harbour_1343_research.md)
## plus a row of guide piles in front of it.
##
## Geometry reads the rendered bed vertices (`bed_positions`) directly, so every log
## follows the exact face the terrain mesh draws and pile feet meet the rendered bed.
## Everything stays `CRIB_TOP_CLEARANCE` under the rest water surface: no collision,
## navigation or gameplay change, and the top-down view keeps its water silhouette.

const LOG_SIDES := 7
const PILE_SIDES := 8
## Face offsets are measured this many terrain subvertex rows out from the deck edge.
const PROFILE_ROWS := 6
## A log is not placed where the bank shelves further out than this (world units):
## there a beach or quay limit shapes the bed, not the crib.
const MAX_FACE_OFFSET := 0.6
## Clear gap between the face and a log, so no log clips into the bank triangles.
const FACE_GAP := 0.02
## Stacked logs overlap slightly so no bank shows between them.
const LOG_STACK_STEP := 1.9
const SIDES: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]

static var _materials: Dictionary = {}


## Returns a `PierCribs` node, or null when the map has no timber deck beside a sea basin.
static func build(field: Dictionary) -> Node3D:
	var faces := crib_faces(field)
	if faces.is_empty():
		return null
	var logs := SurfaceTool.new()
	logs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rubble := SurfaceTool.new()
	rubble.begin(Mesh.PRIMITIVE_TRIANGLES)
	var piles := SurfaceTool.new()
	piles.begin(Mesh.PRIMITIVE_TRIANGLES)
	var log_count := 0
	var rubble_count := 0
	var pile_count := 0
	for face: Dictionary in faces:
		for log_spec: Dictionary in face["logs"]:
			_add_cylinder(
				logs,
				log_spec["from"],
				log_spec["to"],
				log_spec["radius"],
				LOG_SIDES,
				bool(log_spec.get("notch_from", false)),
				bool(log_spec.get("notch_to", false)),
			)
			log_count += 1
		for stone: Dictionary in face["rubble"]:
			_add_irregular_stone(
				rubble,
				stone["center"],
				stone["half"],
				float(stone["yaw"]),
				float(stone.get("pitch", 0.0)),
				float(stone.get("roll", 0.0)),
				float(stone.get("jitter", 0.5)),
			)
			rubble_count += 1
		for pile_spec: Dictionary in face["piles"]:
			_add_cylinder(
				piles, pile_spec["from"], pile_spec["to"], pile_spec["radius"], PILE_SIDES
			)
			pile_count += 1
	if log_count == 0 and pile_count == 0:
		return null
	var root := Node3D.new()
	root.name = "PierCribs"
	if log_count > 0:
		var log_mesh: ArrayMesh = logs.commit()
		if rubble_count > 0:
			rubble.commit(log_mesh)
		root.add_child(_instance_logs(log_mesh, rubble_count > 0))
	if pile_count > 0:
		root.add_child(_instance("PierCribPiles", piles, 1))
	return root


## One entry per deck cell edge that borders a sea-basin cell: the edge, its outward
## direction, the crib logs (`from`, `to`, `radius`) and the guide piles.
static func crib_faces(field: Dictionary) -> Array[Dictionary]:
	var faces: Array[Dictionary] = []
	if not field.has("basin_pier") or not field.has("bed_positions"):
		return faces
	var size: Vector2i = field["size"]
	var pier: PackedFloat32Array = field["basin_pier"]
	var targets: PackedFloat32Array = field["basin_targets"]
	for y in size.y:
		for x in size.x:
			if pier[y * size.x + x] > 0.0:
				continue
			for side in SIDES:
				var neighbour := Vector2i(x, y) + side
				if (
					neighbour.x < 0
					or neighbour.y < 0
					or neighbour.x >= size.x
					or neighbour.y >= size.y
				):
					continue
				if targets[neighbour.y * size.x + neighbour.x] <= 0.0:
					continue
				var face := _face(field, Vector2i(x, y), side)
				if not face.is_empty():
					faces.append(face)
	_mark_corner_notches(faces)
	for face: Dictionary in faces:
		face["rubble"] = _rubble_for_face(face)
	_add_corner_rubble(faces)
	return faces


static func _face(field: Dictionary, cell: Vector2i, side: Vector2i) -> Dictionary:
	var sub := MapViewMeshBuilderConfig.TERRAIN_SUBDIVISIONS
	var bed: PackedVector3Array = field["bed_positions"]
	var columns: int = field["vertex_columns"]
	var rows := bed.size() / columns
	# Edge vertex at along-index 0, the along step and the outward step, in vertex units.
	var along := Vector2i(absi(side.y), absi(side.x))
	var origin := cell * sub + Vector2i(maxi(side.x, 0), maxi(side.y, 0)) * sub
	var outward := Vector3(side.x, 0.0, side.y)
	var along_3d := Vector3(along.x, 0.0, along.y)
	var start := Vector3(float(origin.x) / sub, 0.0, float(origin.y) / sub)
	# Terrain vertices are jittered in XZ, so each profile keeps the real outward
	# distance of every vertex row from the nominal deck edge next to its height.
	var profiles: Array[PackedVector2Array] = []
	var floor_y := INF
	for j in sub + 1:
		var profile := PackedVector2Array()
		for k in PROFILE_ROWS + 1:
			var vertex := origin + along * j + side * k
			vertex.x = clampi(vertex.x, 0, columns - 1)
			vertex.y = clampi(vertex.y, 0, rows - 1)
			var position := bed[vertex.y * columns + vertex.x]
			profile.append(Vector2((position - start).dot(outward), position.y))
			floor_y = minf(floor_y, position.y)
		profiles.append(profile)
	var top_y := (
		-MapViewMeshBuilderConfig.WATER_RECESS
		+ MapViewMeshBuilderConfig.WATER_SURFACE_LIFT
		- MapViewMeshBuilderConfig.CRIB_TOP_CLEARANCE
	)
	if floor_y >= top_y:
		return {}
	var radius := MapViewMeshBuilderConfig.CRIB_LOG_RADIUS
	var logs: Array[Dictionary] = []
	var widest := 0.0
	var step := radius * LOG_STACK_STEP
	for index in ceili((top_y - floor_y + radius) / step):
		var y := top_y - step * float(index)
		var offset := -1.0
		for profile in profiles:
			offset = maxf(offset, _face_offset(profile, y))
		if offset < 0.0 or offset > MAX_FACE_OFFSET:
			continue
		var jitter := _unit_hash(cell, side, index)
		var log_radius := radius * (0.85 + 0.3 * jitter)
		var centre := offset + log_radius + FACE_GAP
		# Where the floor ripples back up over the footprint a log would only add
		# hidden triangles.
		if _buried(profiles, centre, y + log_radius * 0.5):
			continue
		widest = maxf(widest, centre + log_radius)
		# Logs overhang the cell edge by one radius so crib corners interlock.
		var overhang := along_3d * (log_radius + 0.04 * jitter)
		var base := start + outward * centre + Vector3.UP * y
		var log_spec := {
			"from": base - overhang,
			"to": base + along_3d + overhang,
			"radius": log_radius,
			"notch_from": false,
			"notch_to": false,
		}
		logs.append(log_spec)
	if logs.is_empty():
		return {}
	var piles: Array[Dictionary] = []
	var pile_radius := MapViewMeshBuilderConfig.CRIB_PILE_RADIUS
	var spacing := MapViewMeshBuilderConfig.CRIB_PILE_SPACING
	var count := maxi(roundi(1.0 / spacing), 1)
	for p in count:
		var t := (float(p) + 0.5) / float(count)
		var foot := start + along_3d * t + outward * (widest + pile_radius)
		# Foot on the rendered bed under the pile, driven CRIB_BED_EMBED into it.
		var bed_y := _view_bed_height(field, Vector2(foot.x, foot.z))
		foot.y = bed_y - MapViewMeshBuilderConfig.CRIB_BED_EMBED
		var head := Vector3(foot.x, top_y + radius, foot.z)
		if head.y > foot.y:
			piles.append({"from": foot, "to": head, "radius": pile_radius, "bed_y": bed_y})
	return {
		"cell": cell,
		"side": side,
		"start": start,
		"top_y": top_y,
		"floor_y": floor_y,
		"logs": logs,
		"piles": piles,
		"rubble": [],
	}


## Outward distance from the deck edge where a (distance, height) bed profile first
## drops below `y`, or -1 when it never does (the log would sit inside the bank). The
## result is never less than any earlier row's distance, so a jittered vertex that
## leans out over the face still pushes the log clear of it.
static func _face_offset(profile: PackedVector2Array, y: float) -> float:
	var reach := maxf(profile[0].x, 0.0)
	if profile[0].y < y:
		return reach
	for k in range(1, profile.size()):
		var previous := profile[k - 1]
		var current := profile[k]
		if current.y < y:
			var fraction := (previous.y - y) / maxf(previous.y - current.y, 0.0001)
			return maxf(reach, lerpf(previous.x, current.x, fraction))
		reach = maxf(reach, current.x)
	return -1.0


## True when every profile column's bed at outward `distance` stands above `y`.
static func _buried(profiles: Array[PackedVector2Array], distance: float, y: float) -> bool:
	for profile in profiles:
		for k in range(1, profile.size()):
			if profile[k].x < distance and k < profile.size() - 1:
				continue
			var previous := profile[k - 1]
			var current := profile[k]
			var span := maxf(current.x - previous.x, 0.0001)
			var height := lerpf(
				previous.y, current.y, clampf((distance - previous.x) / span, 0.0, 1.0)
			)
			if height <= y:
				return false
			break
	return true


## Same rendered bed as MapViewMeshBuilderTerrain.view_bed_height, from the field.
static func _view_bed_height(field: Dictionary, world_xz: Vector2) -> float:
	var height := MapViewMeshBuilderTerrain.field_height(field, world_xz)
	if (field["water"] as Dictionary).has(Vector2i(floori(world_xz.x), floori(world_xz.y))):
		height -= MapViewMeshBuilderTerrain.basin_extra_depth(field, world_xz)
	return height


## Deterministic 0..1 value per log so stacks do not read as extruded pipes.
static func _unit_hash(cell: Vector2i, side: Vector2i, index: int) -> float:
	var h := hash([cell.x, cell.y, side.x, side.y, index])
	return float(posmod(h, 1000)) / 999.0


## Perpendicular crib faces that share a tip corner (same cell or a staggered
## adjacent-cell tip) mark those log ends so the builder carves a U-saddle
## instead of a round saw-cut cap. Stacked ends snap to one tip plane so the
## joint does not read as truncated pipes of mixed length.
static func _mark_corner_notches(faces: Array[Dictionary]) -> void:
	for i in faces.size():
		for j in range(i + 1, faces.size()):
			var first: Dictionary = faces[i]
			var second: Dictionary = faces[j]
			var first_side: Vector2i = first["side"]
			var second_side: Vector2i = second["side"]
			if first_side.x * second_side.x + first_side.y * second_side.y != 0:
				continue
			var corner := _shared_tip_corner(first, second)
			if corner.x >= 100000.0:
				continue
			_notch_face_at_corner(first, corner)
			_notch_face_at_corner(second, corner)


static func _face_end_points(face: Dictionary) -> Array[Vector3]:
	var start: Vector3 = face["start"]
	var side: Vector2i = face["side"]
	var along := Vector3(float(absi(side.y)), 0.0, float(absi(side.x)))
	return [start, start + along]


static func _shared_tip_corner(first: Dictionary, second: Dictionary) -> Vector3:
	var first_ends := _face_end_points(first)
	var second_ends := _face_end_points(second)
	for a: Vector3 in first_ends:
		for b: Vector3 in second_ends:
			if Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z)) <= 0.05:
				return Vector3((a.x + b.x) * 0.5, 0.0, (a.z + b.z) * 0.5)
	return Vector3(100000.0, 0.0, 100000.0)


static func _notch_face_at_corner(face: Dictionary, corner: Vector3) -> void:
	var side: Vector2i = face["side"]
	var along := Vector3(float(absi(side.y)), 0.0, float(absi(side.x)))
	var start: Vector3 = face["start"]
	var at_start := (
		Vector2(start.x, start.z).distance_to(Vector2(corner.x, corner.z)) <= 0.08
	)
	# One shared plane past the corner, no per-log overhang jitter.
	var snap := along * 0.14
	var floor_y: float = face["floor_y"]
	for log_spec: Dictionary in face["logs"]:
		# Bed-level logs leave a stray U-ring on the sand; keep saddles on the
		# readable mid and upper courses.
		if ((log_spec["from"] as Vector3).y) < floor_y + 0.28:
			continue
		var end_key := "from" if at_start else "to"
		if at_start:
			log_spec["notch_from"] = true
		else:
			log_spec["notch_to"] = true
		var pos: Vector3 = log_spec[end_key]
		var target: Vector3 = (corner - snap) if at_start else (corner + snap)
		log_spec[end_key] = pos + along * ((target - pos).dot(along))


## Irregular stones packed between the deck edge and the innermost log so the
## crib reads as stone-filled rather than a hollow timber cage.
static func _rubble_for_face(face: Dictionary) -> Array[Dictionary]:
	var logs: Array = face["logs"]
	var stones: Array[Dictionary] = []
	if logs.is_empty():
		return stones
	var top_y: float = face["top_y"]
	var floor_y: float = face["floor_y"]
	if top_y - floor_y < MapViewMeshBuilderConfig.CRIB_LOG_RADIUS * 3.0:
		return stones
	var start: Vector3 = face["start"]
	var side: Vector2i = face["side"]
	var cell: Vector2i = face["cell"]
	var outward := Vector3(float(side.x), 0.0, float(side.y))
	var along := Vector3(float(absi(side.y)), 0.0, float(absi(side.x)))
	var inner := INF
	for log_spec: Dictionary in logs:
		var mid: Vector3 = (
			(log_spec["from"] as Vector3) + (log_spec["to"] as Vector3)
		) * 0.5
		var radius: float = log_spec["radius"]
		inner = minf(inner, (mid - start).dot(outward) - radius)
	if inner <= 0.06:
		return stones
	var layers := mini(
		MapViewMeshBuilderConfig.CRIB_RUBBLE_MAX_LAYERS,
		maxi(1, int((top_y - floor_y) / 0.7)),
	)
	var along_count := MapViewMeshBuilderConfig.CRIB_RUBBLE_ALONG
	for layer in layers:
		var y := lerpf(
			floor_y + 0.1, top_y - 0.1, (float(layer) + 0.5) / float(layers)
		)
		for slot in along_count:
			var jitter := _unit_hash(cell, side, 100 + layer * 10 + slot)
			var drift := _unit_hash(cell, side, 200 + layer * 10 + slot)
			var along_t := (float(slot) + 0.5) / float(along_count)
			along_t = clampf(along_t + (jitter - 0.5) * 0.35, 0.08, 0.92)
			var out := clampf(inner * (0.28 + 0.45 * drift), 0.05, inner - 0.03)
			var center := start + along * along_t + outward * out + Vector3.UP * y
			if center.y + 0.08 >= top_y:
				continue
			stones.append(
				_stone_spec(
					center,
					Vector3(
						0.05 + 0.035 * jitter,
						0.038 + 0.028 * drift,
						0.048 + 0.03 * (1.0 - jitter),
					),
					jitter,
					drift,
				)
			)
	return stones


## Stones in the interior corner of two notched faces. The previous exterior L
## pile read as a diamond of boxes on Harbor East; keep fill behind both walls
## so it shows through the saddle, not as cubes on the front face.
static func _add_corner_rubble(faces: Array[Dictionary]) -> void:
	for i in faces.size():
		for j in range(i + 1, faces.size()):
			var first: Dictionary = faces[i]
			var second: Dictionary = faces[j]
			var first_side: Vector2i = first["side"]
			var second_side: Vector2i = second["side"]
			if first_side.x * second_side.x + first_side.y * second_side.y != 0:
				continue
			var corner := _shared_tip_corner(first, second)
			if corner.x >= 100000.0:
				continue
			var cell: Vector2i = first["cell"]
			var top_y: float = minf(float(first["top_y"]), float(second["top_y"]))
			var floor_y: float = minf(float(first["floor_y"]), float(second["floor_y"]))
			if top_y - floor_y < 0.35:
				continue
			var inward := Vector3(
				-float(first_side.x + second_side.x),
				0.0,
				-float(first_side.y + second_side.y),
			)
			if inward.length_squared() > 0.0001:
				inward = inward.normalized()
			var stones: Array = first["rubble"]
			for layer in 3:
				var jitter := _unit_hash(cell, first_side, 400 + layer)
				var drift := _unit_hash(cell, second_side, 500 + layer)
				var y := lerpf(floor_y + 0.12, top_y - 0.12, (float(layer) + 0.4) / 3.0)
				if y + 0.1 >= top_y:
					continue
				stones.append(
					_stone_spec(
						corner + inward * (0.11 + 0.05 * jitter) + Vector3.UP * y,
						Vector3(
							0.07 + 0.025 * jitter,
							0.05 + 0.02 * drift,
							0.065 + 0.025 * (1.0 - jitter),
						),
						jitter,
						drift,
					)
				)
			first["rubble"] = stones


static func _stone_spec(
	center: Vector3, half: Vector3, jitter: float, drift: float
) -> Dictionary:
	return {
		"center": center,
		"half": half,
		"yaw": (jitter - 0.5) * 2.2,
		"pitch": (drift - 0.5) * 0.9,
		"roll": (jitter - drift) * 1.1,
		"jitter": jitter,
	}


## Capped cylinder from `a` to `b`; U runs along the axis so the wood grain follows it.
## A notched end stops the full barrel short, keeps the lower half, and carves a
## U-trough so the tip reads as a cabin saddle instead of a boxed pipe end.
static func _add_cylinder(
	surface: SurfaceTool,
	a: Vector3,
	b: Vector3,
	radius: float,
	sides: int,
	notch_a: bool = false,
	notch_b: bool = false,
) -> void:
	var axis := b - a
	var length := axis.length()
	if length <= 0.0001:
		return
	var direction := axis / length
	var helper := Vector3.UP if absf(direction.y) < 0.9 else Vector3.RIGHT
	var u_axis := direction.cross(helper).normalized()
	var v_axis := direction.cross(u_axis)
	var ring: Array[Vector3] = []
	for i in sides + 1:
		var angle := TAU * float(i) / float(sides)
		ring.append(u_axis * cos(angle) + v_axis * sin(angle))
	var inset := radius * 0.95
	var a_mid := a + direction * (inset if notch_a else 0.0)
	var b_mid := b - direction * (inset if notch_b else 0.0)
	if (b_mid - a_mid).dot(direction) <= 0.0001:
		a_mid = a
		b_mid = b
		notch_a = false
		notch_b = false
	for i in sides:
		var n0 := ring[i]
		var n1 := ring[i + 1]
		var v0 := float(i) / float(sides)
		var v1 := float(i + 1) / float(sides)
		_add_side_quad(
			surface, a_mid, b_mid, n0, n1, radius, Vector2(0.0, v0), Vector2(length, v1)
		)
		if notch_a and n0.y <= 0.2 and n1.y <= 0.2:
			_add_side_quad(
				surface, a, a_mid, n0, n1, radius, Vector2(0.0, v0), Vector2(inset, v1)
			)
		if notch_b and n0.y <= 0.2 and n1.y <= 0.2:
			_add_side_quad(
				surface,
				b_mid,
				b,
				n0,
				n1,
				radius,
				Vector2(length - inset, v0),
				Vector2(length, v1),
			)
		if not notch_a:
			_add_disk_cap(surface, a, -direction, n1, n0, u_axis, v_axis, radius)
		if not notch_b:
			_add_disk_cap(surface, b, direction, n0, n1, u_axis, v_axis, radius)
	if notch_a:
		_add_saddle_notch(surface, a, -direction, radius)
	if notch_b:
		_add_saddle_notch(surface, b, direction, radius)


static func _add_side_quad(
	surface: SurfaceTool,
	a: Vector3,
	b: Vector3,
	n0: Vector3,
	n1: Vector3,
	radius: float,
	uv0: Vector2,
	uv1: Vector2,
) -> void:
	var quad := [
		[a + n0 * radius, n0, Vector2(uv0.x, uv0.y)],
		[b + n0 * radius, n0, Vector2(uv1.x, uv0.y)],
		[b + n1 * radius, n1, Vector2(uv1.x, uv1.y)],
		[a + n1 * radius, n1, Vector2(uv0.x, uv1.y)],
	]
	for corner in [0, 1, 2, 0, 2, 3]:
		surface.set_normal(quad[corner][1])
		surface.set_uv(quad[corner][2])
		surface.add_vertex(quad[corner][0])


static func _add_disk_cap(
	surface: SurfaceTool,
	centre: Vector3,
	normal: Vector3,
	n0: Vector3,
	n1: Vector3,
	u_axis: Vector3,
	v_axis: Vector3,
	radius: float,
) -> void:
	for corner: Vector3 in [Vector3.ZERO, n0, n1]:
		surface.set_normal(normal)
		surface.set_uv(Vector2(corner.dot(u_axis), corner.dot(v_axis)) * radius)
		surface.add_vertex(centre + corner * radius)


## U-trough at a log end: the profile sits in the (cross, up) plane so a tip
## camera reads a saddle, not a lintel box glued onto a pipe.
static func _add_saddle_notch(
	surface: SurfaceTool, end: Vector3, axis: Vector3, radius: float
) -> void:
	var along := axis.normalized()
	var cross := Vector3(-along.z, 0.0, along.x)
	if cross.length_squared() < 0.0001:
		cross = Vector3.RIGHT
	cross = cross.normalized()
	var up := Vector3.UP
	var trough_r := radius * 1.02
	var inset := radius * 0.95
	var inner := end - along * inset
	var outer := end + along * (radius * 0.12)
	var segs := 6
	for i in segs:
		var t0 := float(i) / float(segs)
		var t1 := float(i + 1) / float(segs)
		var ang0 := PI + PI * t0
		var ang1 := PI + PI * t1
		var n0 := cross * cos(ang0) + up * sin(ang0)
		var n1 := cross * cos(ang1) + up * sin(ang1)
		var inward := -(n0 + n1)
		if inward.length_squared() > 0.0001:
			inward = inward.normalized()
		_add_tri_quad(
			surface,
			inner + n0 * trough_r,
			outer + n0 * trough_r,
			outer + n1 * trough_r,
			inner + n1 * trough_r,
			inward,
		)
	for sign: float in [-1.0, 1.0]:
		var lip := cross * sign * trough_r
		_add_tri_quad(
			surface,
			inner + lip,
			outer + lip,
			outer + lip + up * radius,
			inner + lip + up * radius,
			-cross * sign,
		)


static func _add_tri_quad(
	surface: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	normal: Vector3,
) -> void:
	var corners: Array[Vector3] = [a, b, c, d]
	for index in [0, 1, 2, 0, 2, 3]:
		var point: Vector3 = corners[index]
		surface.set_normal(normal)
		surface.set_uv(Vector2(point.x, point.z))
		surface.add_vertex(point)


static func _add_irregular_stone(
	surface: SurfaceTool,
	center: Vector3,
	half: Vector3,
	yaw: float,
	pitch: float,
	roll: float,
	jitter: float,
) -> void:
	var x_axis := Vector3(cos(yaw), 0.0, -sin(yaw))
	var z_axis := Vector3(sin(yaw), 0.0, cos(yaw))
	var y_axis := Vector3.UP
	var pitched := x_axis * cos(pitch) + y_axis * sin(pitch)
	y_axis = (y_axis * cos(pitch) - x_axis * sin(pitch)).normalized()
	x_axis = pitched.normalized()
	var rolled := y_axis * cos(roll) + z_axis * sin(roll)
	z_axis = (z_axis * cos(roll) - y_axis * sin(roll)).normalized()
	y_axis = rolled.normalized()
	var signs: Array[Vector3] = [
		Vector3(-1.0, -1.0, -1.0),
		Vector3(1.0, -1.0, -1.0),
		Vector3(1.0, -1.0, 1.0),
		Vector3(-1.0, -1.0, 1.0),
		Vector3(-1.0, 1.0, -1.0),
		Vector3(1.0, 1.0, -1.0),
		Vector3(1.0, 1.0, 1.0),
		Vector3(-1.0, 1.0, 1.0),
	]
	var verts: Array[Vector3] = []
	for i in signs.size():
		var s: Vector3 = signs[i]
		var scale := 0.72 + 0.4 * _unit_hash(Vector2i(i, int(jitter * 99.0)), Vector2i.ZERO, i + 17)
		verts.append(
			center
			+ x_axis * (half.x * s.x * scale)
			+ y_axis * (half.y * s.y * scale)
			+ z_axis * (half.z * s.z * scale)
		)
	var faces: Array = [
		[0, 1, 2, 3, -y_axis],
		[4, 7, 6, 5, y_axis],
		[0, 4, 5, 1, -z_axis],
		[3, 2, 6, 7, z_axis],
		[1, 5, 6, 2, x_axis],
		[0, 3, 7, 4, -x_axis],
	]
	for face: Array in faces:
		var normal: Vector3 = face[4]
		for index in [0, 1, 2, 0, 2, 3]:
			var point: Vector3 = verts[int(face[index])]
			surface.set_normal(normal)
			surface.set_uv(Vector2((point - center).dot(x_axis), (point - center).dot(z_axis)))
			surface.add_vertex(point)


static func _instance_logs(log_mesh: ArrayMesh, has_rubble: bool) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = "PierCribLogs"
	instance.mesh = log_mesh
	if log_mesh.get_surface_count() > 0:
		log_mesh.surface_set_material(0, wet_timber(0))
	if has_rubble and log_mesh.get_surface_count() > 1:
		log_mesh.surface_set_material(1, wet_rubble())
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


static func _instance(node_name: String, surface: SurfaceTool, variant: int) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = surface.commit()
	instance.material_override = wet_timber(variant)
	# Under water the sun shadow of the deck mound already darkens the face; crib
	# shadows would only add cost and speckle the top-down bed through the surface.
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


## Hewn oak darkened and tinted by long immersion (wet wood, algae film).
static func wet_timber(variant: int) -> StandardMaterial3D:
	if _materials.has(variant):
		return _materials[variant]
	var material := MapViewMaterials.hewn_timber(true, variant).duplicate() as StandardMaterial3D
	material.albedo_color = Color8(74, 70, 52).lerp(material.albedo_color, 0.35)
	material.roughness = 0.62
	_materials[variant] = material
	return material


## Wet fieldstone for the crib fill. Shares the logs MeshInstance as a second
## surface so the map stays on two nodes (logs+rubble, piles).
static func wet_rubble() -> StandardMaterial3D:
	if _materials.has("rubble"):
		return _materials["rubble"]
	var material := (
		MapViewMaterials.fortification_masonry(Color8(78, 72, 62)).duplicate()
		as StandardMaterial3D
	)
	material.albedo_color = Color8(96, 88, 74)
	material.roughness = 0.86
	material.metallic = 0.0
	_materials["rubble"] = material
	return material
