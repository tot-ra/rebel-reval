class_name CityDoors
extends Node3D

## Hinged street doors for every city building (ADR 0031). Each door is a leaf
## on a hinge at one side of the door gap the building and its collision leave.
## Enterable houses swing their door inward when Kalev comes within OPEN_RADIUS
## of it and shut it again once he has moved on; other houses keep it closed.
## Profiles follow census wealth and explicit landmark entrance roles (R-1692).
## Rectangular leaves retain the authored apertures; see SYSTEMS/CITY_DOORS.md.

const OPEN_RADIUS := 2.4
const OPEN_ANGLE := deg_to_rad(100.0)
const SWING_SPEED := deg_to_rad(220.0)
const CHECK_RADIUS := 12.0
const TIMBER_ALBEDO := "res://assets/materials/pbr/timber/timber_albedo.png"
const TIMBER_NORMAL := "res://assets/materials/pbr/timber/timber_normal.png"
const Details := preload("res://scripts/city/city_door_details.gd")

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
	CityHouseWealth.bind(plan)
	for i in plan.buildings.size():
		var b: Dictionary = plan.buildings[i]
		if b.get("door") == null:
			continue
		var gap := door_gap(plan, i)
		if gap.is_empty():
			continue
		var tier := CityHouseWealth.tier_of(b, plan.footprint(i))
		var look := Details.look(b, tier)
		var double := float(gap["width"]) > 2.2 or String(b.get("landmark_id", "")) != ""
		doors[i] = _hang(
			"Door_%d" % i,
			gap["a"],
			gap["b"],
			float(gap["floor"]),
			gap["inward"],
			look["style"],
			look["paint"],
			CityBuildingBuilder.door_size(b).y - 0.05,
			double,
			{"variant": look["variant"]}
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
			var hang := portal_hang(site, d, floor_y)
			doors[key] = _hang(
				key.replace(".", "_").replace(":", "_"),
				hang["a"],
				hang["b"],
				floor_y,
				d["inward"],
				Details.site_style(d),
				d["paint"],
				hang["height"],
				width > 2.2,
				{"head": hang["head"]}
			)
			doors[key]["site_floor"] = d["floor"]
			# Proximity stays on the authored door line, not the recessed leaf.
			doors[key]["center"] = (d["a"] + d["b"]) * 0.5
			doors[key]["angle"] = hang["angle"]


## Where and how a site door's leaves hang: {a, b, height, head, angle}. In a
## profiled portal (R-1693) the leaves sit deeper, behind the stop they overlap,
## are cut to the pointed head and open flat against the rear arch.
static func portal_hang(site: CitySite, d: Dictionary, floor_y: float) -> Dictionary:
	var frame := CitySitePortals.leaf(site, StringName(d["id"]), floor_y)
	if frame.is_empty():
		return {
			"a": d["a"],
			"b": d["b"],
			"height": float(d["height"]) - 0.05,
			"head": Vector2.ZERO,
			"angle": OPEN_ANGLE,
		}
	var along: Vector2 = (d["b"] - d["a"]).normalized()
	var shift: Vector2 = d["inward"] * float(frame["depth_shift"])
	var ov := float(frame["overlap"])
	return {
		"a": d["a"] + shift - along * ov,
		"b": d["b"] + shift + along * ov,
		"height": float(frame["spring"]),
		"head": Vector2(frame["span"], frame["apex"]),
		"angle": CitySitePortals.OPEN_ANGLE,
	}


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
	double: bool,
	shape := {}
) -> Dictionary:
	# `shape`: {variant (board variant), head (arch span, apex) for portal leaves}.
	var variant: int = shape.get("variant", 0)
	var head: Vector2 = shape.get("head", Vector2.ZERO)
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
		leaf.mesh = Details.mesh(style, leaf_w, height, variant, head)
		for surface in leaf.mesh.get_surface_count():
			if leaf.mesh.surface_get_name(surface) == "wood":
				leaf.set_surface_override_material(surface, _material(paint))
		# The authored inward normal, not endpoint order, determines the facade.
		# Otherwise one leaf or an entire north-facing entrance hides its ironwork.
		if _inward_sign(hinge, inward) < 0.0:
			leaf.scale = Vector3(1, 1, -1)
		hinge.add_child(leaf)
		add_child(hinge)
		hinge_nodes.append(hinge)
	return {
		"style": style,
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
			leaf.rotation.y = sign * float(d.get("angle", OPEN_ANGLE)) * eased


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


## Kept for existing geometry probes; production materials are per surface.
static func _leaf_mesh(style: StringName, width: float, height: float) -> ArrayMesh:
	return Details.mesh(style, width, height)
