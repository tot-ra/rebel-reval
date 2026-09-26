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
	var piles := SurfaceTool.new()
	piles.begin(Mesh.PRIMITIVE_TRIANGLES)
	var log_count := 0
	var pile_count := 0
	for face: Dictionary in faces:
		for log_spec: Dictionary in face["logs"]:
			_add_cylinder(logs, log_spec["from"], log_spec["to"], log_spec["radius"], LOG_SIDES)
			log_count += 1
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
		root.add_child(_instance("PierCribLogs", logs, 0))
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
			"from": base - overhang, "to": base + along_3d + overhang, "radius": log_radius
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
		"top_y": top_y,
		"floor_y": floor_y,
		"logs": logs,
		"piles": piles,
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


## Capped cylinder from `a` to `b`; U runs along the axis so the wood grain follows it.
static func _add_cylinder(
	surface: SurfaceTool, a: Vector3, b: Vector3, radius: float, sides: int
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
	for i in sides:
		var n0 := ring[i]
		var n1 := ring[i + 1]
		var v0 := float(i) / float(sides)
		var v1 := float(i + 1) / float(sides)
		var quad := [
			[a + n0 * radius, n0, Vector2(0.0, v0)],
			[b + n0 * radius, n0, Vector2(length, v0)],
			[b + n1 * radius, n1, Vector2(length, v1)],
			[a + n1 * radius, n1, Vector2(0.0, v1)],
		]
		for corner in [0, 1, 2, 0, 2, 3]:
			surface.set_normal(quad[corner][1])
			surface.set_uv(quad[corner][2])
			surface.add_vertex(quad[corner][0])
		# End caps as fans; the saw-cut end grain uses the same wood texture.
		for cap: Array in [[a, -direction, n1, n0], [b, direction, n0, n1]]:
			var centre: Vector3 = cap[0]
			for corner: Vector3 in [Vector3.ZERO, cap[2], cap[3]]:
				surface.set_normal(cap[1])
				surface.set_uv(Vector2(corner.dot(u_axis), corner.dot(v_axis)) * radius)
				surface.add_vertex(centre + corner * radius)


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
