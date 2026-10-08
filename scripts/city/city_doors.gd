class_name CityDoors
extends Node3D

## Hinged street doors for every city building (ADR 0031). Each door is a leaf
## on a hinge at one side of the door gap the building and its collision leave.
## Enterable houses swing their door inward when Kalev comes within OPEN_RADIUS
## of it and shut it again once he has moved on; other houses keep it closed.
## Styles vary per building (deterministic by building id): plank with iron
## strap hinges, braced boarding, studded oak, round-headed doors for stone
## houses, and double leaves for wide halls.

const OPEN_RADIUS := 2.4
const OPEN_ANGLE := deg_to_rad(100.0)
const SWING_SPEED := deg_to_rad(220.0)
const LEAF_THICKNESS := 0.09
const CHECK_RADIUS := 12.0
const TIMBER_ALBEDO := "res://assets/materials/pbr/timber/timber_albedo.png"
const TIMBER_NORMAL := "res://assets/materials/pbr/timber/timber_normal.png"

## Rectangular leaves only: the openings are rectangular.
const STYLES: Array[StringName] = [&"plank", &"braced", &"studded", &"ledged"]
## Outbuilding doors: bare weathered or tarred boards, no paint and no ironwork.
const ROUGH_PAINTS: Array[Color] = [
	Color(0.44, 0.40, 0.34),  # weathered grey oak
	Color(0.36, 0.31, 0.25),  # old pine
	Color(0.24, 0.20, 0.17),  # tarred
]
const PAINTS: Array[Color] = [
	Color(0.52, 0.38, 0.25),  # oiled oak
	Color(0.24, 0.20, 0.17),  # tarred
	Color(0.55, 0.24, 0.17),  # ochre red
	Color(0.30, 0.38, 0.30),  # faded verdigris green
	Color(0.44, 0.40, 0.34),  # weathered grey oak
]

static var _mesh_cache: Dictionary = {}
static var _materials: Dictionary = {}

var plan: CityPlan
## building index (int) or "site:<door id>" (String) ->
## {hinges, inward, open, target, enterable, center[, site_floor]}
var doors: Dictionary = {}


static func create(city_plan: CityPlan) -> CityDoors:
	var node := CityDoors.new()
	node.name = "Doors"
	node.plan = city_plan
	node._build()
	return node


func _build() -> void:
	for i in plan.buildings.size():
		var b: Dictionary = plan.buildings[i]
		if b.get("door") == null:
			continue
		var gap := door_gap(plan, i)
		if gap.is_empty():
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(String(b["id"]) + ":door")
		var style: StringName = STYLES[rng.randi() % STYLES.size()]
		if String(b["material"]) == "limestone" and rng.randf() < 0.5:
			style = &"studded"
		var paint: Color = PAINTS[rng.randi() % PAINTS.size()]
		# WHY: sheds, sties and byres had cheap ledged boarding, not the strapped
		# or studded doors of dwellings (their openings are also smaller, see
		# CityBuildingBuilder.door_size).
		var rough := (
			String(b.get("kind", "")) == "outbuilding"
			and CityBuildingBuilder.OUTBUILDING_DOORS.has(StringName(String(b.get("type", ""))))
		)
		if rough:
			style = &"rough"
			paint = ROUGH_PAINTS[rng.randi() % ROUGH_PAINTS.size()]
		var double := float(gap["width"]) > 2.2 or String(b.get("landmark_id", "")) != ""
		doors[i] = _hang(
			"Door_%d" % i,
			gap["a"],
			gap["b"],
			float(gap["floor"]),
			gap["inward"],
			style,
			paint,
			CityBuildingBuilder.door_size(b).y - 0.05,
			double
		)
		doors[i]["enterable"] = bool(b.get("enterable", false))
	# Landmark site doors (ADR 0032), keyed "site:<door id>".
	for site in plan.sites:
		for d: Dictionary in site.doors:
			var width: float = (d["a"] as Vector2).distance_to(d["b"])
			var floor_y := site.level
			for f: Dictionary in site.floors:
				if f["id"] == d["floor"]:
					floor_y = float(f["height"])
			var key := "site:%s" % d["id"]
			doors[key] = _hang(
				key.replace(".", "_").replace(":", "_"),
				d["a"],
				d["b"],
				floor_y,
				d["inward"],
				d["style"],
				d["paint"],
				float(d["height"]) - 0.05,
				width > 2.2
			)
			doors[key]["site_floor"] = d["floor"]


## Hangs one or two leaves in the gap a-b on `floor_y`; returns the door record.
func _hang(
	label: String,
	a: Vector2,
	b: Vector2,
	floor_y: float,
	inward: Vector2,
	style: StringName,
	paint: Color,
	height: float,
	double: bool
) -> Dictionary:
	var leaves := 2 if double else 1
	var leaf_w := a.distance_to(b) / leaves
	var hinge_nodes: Array[Node3D] = []
	for k in leaves:
		var hinge := Node3D.new()
		hinge.name = "%s_%d" % [label, k]
		var from: Vector2 = a if k == 0 else b
		var toward: Vector2 = (b - a).normalized() * (1.0 if k == 0 else -1.0)
		hinge.position = Vector3(from.x, floor_y, from.y)
		hinge.basis = Basis(Vector3.UP, atan2(-toward.y, toward.x))
		var leaf := MeshInstance3D.new()
		leaf.mesh = _leaf_mesh(style, leaf_w, height)
		leaf.material_override = _material(paint)
		# Mesh spans +X from the hinge; mirror the second leaf so it opens the same way.
		if k == 1:
			leaf.scale = Vector3(1, 1, -1)
		hinge.add_child(leaf)
		add_child(hinge)
		hinge_nodes.append(hinge)
	return {
		"hinges": hinge_nodes,
		"inward": inward,
		"open": 0.0,
		"target": 0.0,
		"enterable": true,
		"center": (a + b) * 0.5,
	}


## Door gap of building `index` exactly as CityBuildingBuilder cuts it:
## {a, b (gap ends on the outer face), width, floor, inward (unit vector)}.
static func door_gap(city_plan: CityPlan, index: int) -> Dictionary:
	var b: Dictionary = city_plan.buildings[index]
	var ring := CityBuildingBuilder.wall_ring(b, city_plan.footprint(index))
	if ring.size() < 3:
		return {}
	var door := Vector2(b["door"][0], b["door"][1])
	var edge := CityBuildingBuilder._closest_edge(ring, door)
	var a := ring[edge]
	var c := ring[(edge + 1) % ring.size()]
	var length := a.distance_to(c)
	if length < 0.5:
		return {}
	var t := clampf((door - a).dot(c - a) / maxf((c - a).length_squared(), 0.001), 0.2, 0.8)
	var hg := minf(CityBuildingBuilder.door_size(b).x * 0.5, length * 0.35) / maxf(length, 0.01)
	var g0 := a.lerp(c, t - hg)
	var g1 := a.lerp(c, t + hg)
	var dir := (c - a) / length
	var inward := Vector2(-dir.y, dir.x)
	if not Geometry2D.is_point_in_polygon((g0 + g1) * 0.5 + inward * 0.3, ring):
		inward = -inward
	# Hang the leaf just inside the outer face.
	g0 += inward * 0.12
	g1 += inward * 0.12
	return {
		"a": g0,
		"b": g1,
		"width": g0.distance_to(g1),
		"floor": city_plan.floor_height(index),
		"inward": inward,
	}


## Opens doors of enterable houses near `world_xz`, closes the rest; call each frame.
func update_for(world_xz: Vector2, delta: float) -> void:
	var seen := {}
	for index: int in plan.buildings_near(world_xz, CHECK_RADIUS):
		if not doors.has(index):
			continue
		var d: Dictionary = doors[index]
		if not bool(d["enterable"]):
			continue
		seen[index] = true
		var near := world_xz.distance_to(d["center"]) < OPEN_RADIUS
		d["target"] = 1.0 if near or plan.building_at(world_xz) == index else 0.0
	# Site doors: open near the door and while Kalev is in the room behind it.
	var room := plan.site_room_at(world_xz)
	var room_floor: StringName = room["room"]["floor"] if not room.is_empty() else &""
	for key: Variant in doors:
		if not key is String:
			continue
		var d: Dictionary = doors[key]
		var near := world_xz.distance_to(d["center"]) < OPEN_RADIUS
		if not near and room_floor != d["site_floor"]:
			continue
		seen[key] = true
		d["target"] = 1.0
	# Doors left behind (Kalev ran off or was moved) swing shut too.
	for index: Variant in doors:
		if not seen.has(index) and float(doors[index]["target"]) > 0.0:
			doors[index]["target"] = 0.0
	for index: Variant in doors:
		var d: Dictionary = doors[index]
		var open: float = d["open"]
		var target: float = d["target"]
		if is_equal_approx(open, target):
			continue
		var step := SWING_SPEED / OPEN_ANGLE * delta
		open = move_toward(open, target, step)
		d["open"] = open
		var eased := open * open * (3.0 - 2.0 * open)
		var hinges: Array[Node3D] = d["hinges"]
		for k in hinges.size():
			var leaf := hinges[k].get_child(0) as Node3D
			# Swing inward: positive yaw turns +X toward the house for the first leaf.
			var sign := _inward_sign(hinges[k], d["inward"])
			leaf.rotation.y = sign * OPEN_ANGLE * eased


## `index` is a building index, or "site:<door id>" for a landmark site door.
func is_open(index: Variant) -> bool:
	return doors.has(index) and float(doors[index]["open"]) > 0.5


static func _inward_sign(hinge: Node3D, inward: Vector2) -> float:
	# The leaf's local -Z (after a +90 deg yaw +X maps to -Z) must point inward.
	var minus_z := -hinge.basis.z
	return 1.0 if Vector2(minus_z.x, minus_z.z).dot(inward) > 0.0 else -1.0


static func _material(paint: Color) -> Material:
	var key := paint.to_html()
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = load(TIMBER_ALBEDO)
		mat.normal_enabled = true
		mat.normal_texture = load(TIMBER_NORMAL)
		# Boards run vertically: world-unit UVs on the leaf faces.
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3(0.9, 0.45, 0.9)
		mat.albedo_color = paint * 1.6
		mat.roughness = 0.85
		mat.vertex_color_use_as_albedo = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials[key] = mat
	return _materials[key]


## Leaf from the hinge (x = 0) along +X, bottom at y = 0, centred on z = 0.
## Vertex colour darkens iron and shadows the boarding joints.
static func _leaf_mesh(style: StringName, width: float, height: float) -> ArrayMesh:
	var key := "%s:%.2f:%.2f" % [style, width, height]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var shell := CityBuildingBuilder.Shell.new()
	var wood := Color(1, 1, 1)
	var iron := Color(0.16, 0.15, 0.14)
	var t := LEAF_THICKNESS
	var top := height
	_box(shell, Vector3(0.0, 0.0, -t * 0.5), Vector3(width, top, t * 0.5), wood)
	# Board joints.
	var boards := maxi(3, int(width / 0.22))
	for k in range(1, boards):
		var x := width * float(k) / boards
		_box(
			shell,
			Vector3(x - 0.008, 0.02, t * 0.5),
			Vector3(x + 0.008, top * 0.97, t * 0.5 + 0.004),
			Color(0.45, 0.45, 0.45)
		)
	match style:
		&"rough":
			# Two plain wooden ledges and a wooden latch bar; nothing forged.
			for y: float in [0.25, top - 0.3]:
				_box(
					shell,
					Vector3(0.03, y, t * 0.5),
					Vector3(width - 0.03, y + 0.11, t * 0.5 + 0.03),
					wood * 0.8
				)
			_box(
				shell,
				Vector3(width * 0.62, top * 0.5, t * 0.5),
				Vector3(width * 0.9, top * 0.5 + 0.04, t * 0.5 + 0.035),
				wood * 0.7
			)
			var rough_mesh := shell.to_mesh(func(_k: String) -> Material: return null)
			_mesh_cache[key] = rough_mesh
			return rough_mesh
		&"plank":
			for y: float in [0.35, top - 0.45]:
				_box(
					shell,
					Vector3(0.0, y, t * 0.5),
					Vector3(width * 0.78, y + 0.07, t * 0.5 + 0.02),
					iron
				)
		&"braced":
			for y: float in [0.3, top * 0.5, top - 0.35]:
				_box(
					shell,
					Vector3(0.04, y, t * 0.5),
					Vector3(width - 0.04, y + 0.12, t * 0.5 + 0.035),
					wood * 0.85
				)
			_brace(shell, width, top, t, wood * 0.85)
		&"studded":
			for row in 7:
				for col in 4:
					var cx := width * (float(col) + 0.5) / 4.0
					var cy := top * (float(row) + 0.7) / 7.6
					_box(
						shell,
						Vector3(cx - 0.025, cy - 0.025, t * 0.5),
						Vector3(cx + 0.025, cy + 0.025, t * 0.5 + 0.02),
						iron
					)
	# Ring handle.
	_box(
		shell,
		Vector3(width * 0.82, top * 0.45, t * 0.5),
		Vector3(width * 0.86, top * 0.5, t * 0.5 + 0.05),
		iron
	)
	var mesh := shell.to_mesh(func(_k: String) -> Material: return null)
	_mesh_cache[key] = mesh
	return mesh


static func _box(shell: CityBuildingBuilder.Shell, lo: Vector3, hi: Vector3, color: Color) -> void:
	var c := (lo + hi) * 0.5
	var corners := [
		Vector3(lo.x, lo.y, lo.z),
		Vector3(hi.x, lo.y, lo.z),
		Vector3(hi.x, hi.y, lo.z),
		Vector3(lo.x, hi.y, lo.z),
		Vector3(lo.x, lo.y, hi.z),
		Vector3(hi.x, lo.y, hi.z),
		Vector3(hi.x, hi.y, hi.z),
		Vector3(lo.x, hi.y, hi.z),
	]
	var faces := [
		[0, 1, 2, 3], [5, 4, 7, 6], [4, 0, 3, 7], [1, 5, 6, 2], [3, 2, 6, 7], [4, 5, 1, 0]
	]
	for f: Array in faces:
		var a: Vector3 = corners[f[0]]
		var b: Vector3 = corners[f[1]]
		var cc: Vector3 = corners[f[2]]
		var d: Vector3 = corners[f[3]]
		shell.quad_out("leaf", a, b, cc, d, color, (a + b + cc + d) * 0.25 - c)


static func _brace(
	shell: CityBuildingBuilder.Shell, width: float, top: float, t: float, color: Color
) -> void:
	var a := Vector2(0.08, 0.42)
	var b := Vector2(width - 0.08, top * 0.5 - 0.02)
	var dir := (b - a).normalized()
	var n := Vector2(-dir.y, dir.x) * 0.055
	var z := t * 0.5 + 0.035
	shell.quad_out(
		"leaf",
		Vector3(a.x - n.x, a.y - n.y, z),
		Vector3(b.x - n.x, b.y - n.y, z),
		Vector3(b.x + n.x, b.y + n.y, z),
		Vector3(a.x + n.x, a.y + n.y, z),
		color,
		Vector3.BACK
	)
