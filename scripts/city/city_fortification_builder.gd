class_name CityFortificationBuilder
extends RefCounted

## Lower Town curtain, gates and dated towers, the Toompea plateau wall and the
## castle, from the city plan (ADR 0031; 1343 states per
## history/dossiers/topography/walls-gates-towers.md). Curtains follow the
## ground: the top runs parallel to the terrain between anchors. States:
##   stone         ~6.2 m limestone curtain, merlons on a parapet
##   construction  lower unfinished course with putlog scaffolding, no merlons
##   palisade      timber stakes (the hill-side boundary and SW slope)

const MERLON_W := 1.1
const MERLON_GAP := 0.9
const MERLON_H := 1.0
const GATE_DEPTH_FACTOR := 2.4
const SAMPLE_STEP := 3.0

static var _stone: Material


static func build(plan: CityPlan, parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Fortifications"
	parent.add_child(root)
	var shell := CityBuildingBuilder.Shell.new()
	var gates_by_anchor := {}
	var gate_by_id := {}
	for g: Dictionary in plan.data["gates"]:
		gate_by_id[g["id"]] = g
	var circuit: Array = plan.data["circuit"]
	for i in circuit.size():
		var ref := String(circuit[i]["ref"])
		if gate_by_id.has(ref):
			gates_by_anchor[i] = gate_by_id[ref]
	var curtains: Array = plan.data["curtains"]
	var town_centroid := _centroid_of(
		circuit.map(func(a: Dictionary) -> Vector2: return Vector2(a["at"][0], a["at"][1]))
	)
	var toompea_centroid := _centroid_of(Array(CityPlan.points(plan.data["toompea_edge"])))
	for i in curtains.size():
		var c: Dictionary = curtains[i]
		var a := Vector2(c["from"][0], c["from"][1])
		var b := Vector2(c["to"][0], c["to"][1])
		var dir := (b - a).normalized()
		var trim_a := 0.0
		var trim_b := 0.0
		if gates_by_anchor.has(i):
			trim_a = _gate_half_extent(gates_by_anchor[i])
		if gates_by_anchor.has((i + 1) % curtains.size()):
			trim_b = _gate_half_extent(gates_by_anchor[(i + 1) % curtains.size()])
		var p0 := a + dir * trim_a
		var p1 := b - dir * trim_b
		if p0.distance_to(b) <= trim_b:
			continue
		_curtain(
			shell,
			plan,
			p0,
			p1,
			String(c["state"]),
			float(c["height"]),
			float(c["thickness"]),
			town_centroid
		)
	for g: Dictionary in plan.data["gates"]:
		_gate(shell, plan, g)
	for t: Dictionary in plan.data["towers"]:
		_tower(shell, plan, t)
	# Toompea castrum maius wall with openings where the hill ways arrive.
	var openings := {}
	for o: Dictionary in plan.data.get("toompea_openings", []):
		openings[o["wall_id"]] = o
	for w: Dictionary in plan.data.get("toompea_walls", []):
		var a := Vector2(w["from"][0], w["from"][1])
		var b := Vector2(w["to"][0], w["to"][1])
		if openings.has(w["id"]):
			var o: Dictionary = openings[w["id"]]
			var at := Vector2(o["at"][0], o["at"][1])
			var half := float(o["width"]) * 0.5
			var dir := (b - a).normalized()
			if a.distance_to(at) > half + 0.5:
				_curtain(
					shell,
					plan,
					a,
					at - dir * half,
					"stone",
					float(w["height"]),
					float(w["thickness"]),
					toompea_centroid
				)
			if b.distance_to(at) > half + 0.5:
				_curtain(
					shell,
					plan,
					at + dir * half,
					b,
					"stone",
					float(w["height"]),
					float(w["thickness"]),
					toompea_centroid
				)
			_timber_gate(shell, plan, at, dir, float(o["width"]), float(w["thickness"]))
		else:
			_curtain(
				shell,
				plan,
				a,
				b,
				"stone",
				float(w["height"]),
				float(w["thickness"]),
				toompea_centroid
			)
	_castle(shell, plan)
	var inst := MeshInstance3D.new()
	inst.name = "Masonry"
	inst.mesh = shell.to_mesh(_material_for)
	root.add_child(inst)
	return root


static func _material_for(key: String) -> Material:
	match key:
		"stone":
			return _stone_material()
		"timber":
			return CityBuildingBuilder.timber_material()
		"roof":
			return CityBuildingBuilder.roof_material(&"shingle")
		"tile":
			return CityBuildingBuilder.roof_material(&"tile")
		"dark":
			return CityBuildingBuilder.opening_material()
	return _stone_material()


static func _stone_material() -> Material:
	if _stone == null:
		var mat := (
			(
				MapViewMaterials
				. wall_surface_triplanar(&"limestone", Color(0.76, 0.74, 0.69))
				. duplicate()
			)
			as StandardMaterial3D
		)
		mat.vertex_color_use_as_albedo = true
		mat.cull_mode = BaseMaterial3D.CULL_BACK
		_stone = mat
	return _stone


static func _centroid_of(points: Array) -> Vector2:
	var c := Vector2.ZERO
	for p: Vector2 in points:
		c += p
	return c / maxf(points.size(), 1)


static func _gate_half_extent(g: Dictionary) -> float:
	var opening := float(g["opening"])
	if String(g["state"]) == "wooden":
		return opening * 0.5 + 0.6
	return opening * 0.5 + 2.4


## A wall prism between p0 and p1 whose bottom sinks into the ground and whose
## top follows the terrain. Thickness is centred on the line.
static func _curtain(
	shell: CityBuildingBuilder.Shell,
	plan: CityPlan,
	p0: Vector2,
	p1: Vector2,
	state: String,
	height: float,
	thickness: float,
	enclosure := Vector2(INF, INF)
) -> void:
	var length := p0.distance_to(p1)
	if length < 0.2:
		return
	var dir := (p1 - p0) / length
	var side := Vector2(-dir.y, dir.x)
	var steps := maxi(1, int(ceil(length / SAMPLE_STEP)))
	var key := "timber" if state == "palisade" else "stone"
	var tint := Color(1, 1, 1)
	if state == "construction":
		tint = Color(0.93, 0.9, 0.84)
	for s in steps:
		var u := p0.lerp(p1, float(s) / steps)
		var v := p0.lerp(p1, float(s + 1) / steps)
		var gu := plan.ground_height(u)
		var gv := plan.ground_height(v)
		var bottom := minf(gu, gv) - 1.6
		if state == "palisade":
			_palisade_run(shell, plan, u, v, height)
			continue
		var tu := gu + height
		var tv := gv + height
		var ul := u + side * thickness * 0.5
		var ur := u - side * thickness * 0.5
		var vl := v + side * thickness * 0.5
		var vr := v - side * thickness * 0.5
		# Two faces, top, and the parapet.
		var sd := Vector3(side.x, 0, side.y)
		var dd := Vector3(dir.x, 0, dir.y)
		shell.quad_out(
			key,
			Vector3(ur.x, bottom, ur.y),
			Vector3(vr.x, bottom, vr.y),
			Vector3(vr.x, tv, vr.y),
			Vector3(ur.x, tu, ur.y),
			tint,
			-sd
		)
		shell.quad_out(
			key,
			Vector3(vl.x, bottom, vl.y),
			Vector3(ul.x, bottom, ul.y),
			Vector3(ul.x, tu, ul.y),
			Vector3(vl.x, tv, vl.y),
			tint,
			sd
		)
		shell.quad_out(
			key,
			Vector3(ul.x, tu, ul.y),
			Vector3(ur.x, tu, ur.y),
			Vector3(vr.x, tv, vr.y),
			Vector3(vl.x, tv, vl.y),
			tint,
			Vector3.UP
		)
		if s == 0:
			shell.quad_out(
				key,
				Vector3(ul.x, bottom, ul.y),
				Vector3(ur.x, bottom, ur.y),
				Vector3(ur.x, tu, ur.y),
				Vector3(ul.x, tu, ul.y),
				tint,
				-dd
			)
		if s == steps - 1:
			shell.quad_out(
				key,
				Vector3(vr.x, bottom, vr.y),
				Vector3(vl.x, bottom, vl.y),
				Vector3(vl.x, tv, vl.y),
				Vector3(vr.x, tv, vr.y),
				tint,
				dd
			)
	if state == "stone":
		var field_sign := 1.0
		if enclosure.x != INF:
			var m := (p0 + p1) * 0.5
			field_sign = (
				1.0
				if (m + side).distance_to(enclosure) > (m - side).distance_to(enclosure)
				else -1.0
			)
		_merlons(shell, plan, p0, p1, height, thickness, field_sign)
	elif state == "construction":
		_scaffold(shell, plan, p0, p1, height, thickness)


static func _merlons(
	shell: CityBuildingBuilder.Shell,
	plan: CityPlan,
	p0: Vector2,
	p1: Vector2,
	height: float,
	thickness: float,
	field_sign: float
) -> void:
	var length := p0.distance_to(p1)
	var dir := (p1 - p0) / length
	# Parapet on the field side (away from the enclosure the wall defends).
	var side := Vector2(-dir.y, dir.x) * field_sign
	var depth := thickness * 0.38
	var t := 0.6
	while t + MERLON_W < length - 0.4:
		var a := p0 + dir * t
		var b := p0 + dir * (t + MERLON_W)
		var ga := plan.ground_height(a) + height
		var gb := plan.ground_height(b) + height
		var base := minf(ga, gb)
		_box_between(
			shell,
			"stone",
			a + side * (thickness * 0.5 - depth * 0.5),
			b + side * (thickness * 0.5 - depth * 0.5),
			depth,
			base - 0.05,
			base + MERLON_H
		)
		t += MERLON_W + MERLON_GAP


static func _scaffold(
	shell: CityBuildingBuilder.Shell,
	plan: CityPlan,
	p0: Vector2,
	p1: Vector2,
	height: float,
	thickness: float
) -> void:
	var length := p0.distance_to(p1)
	var dir := (p1 - p0) / length
	var side := Vector2(-dir.y, dir.x)
	var t := 1.5
	while t < length - 1.0:
		for s: float in [-1.0, 1.0]:
			var p := p0 + dir * t + side * s * (thickness * 0.5 + 0.9)
			var g := plan.ground_height(p)
			_box_between(
				shell, "timber", p - dir * 0.09, p + dir * 0.09, 0.18, g - 0.3, g + height + 2.2
			)
		# Ledger and plank deck on the field side.
		var a := p0 + dir * maxf(t - 3.2, 0.0) + side * (thickness * 0.5 + 0.9)
		var b := p0 + dir * t + side * (thickness * 0.5 + 0.9)
		var deck := minf(plan.ground_height(a), plan.ground_height(b)) + height * 0.7
		_box_between(shell, "timber", a, b, 1.0, deck, deck + 0.08)
		t += 3.2


static func _palisade_run(
	shell: CityBuildingBuilder.Shell, plan: CityPlan, a: Vector2, b: Vector2, height: float
) -> void:
	var length := a.distance_to(b)
	var dir := (b - a) / maxf(length, 0.001)
	var t := 0.0
	var i := 0
	while t < length:
		var p := a + dir * t
		var g := plan.ground_height(p)
		var h := height * (0.92 + 0.08 * sin(float(i) * 2.3))
		_stake(shell, p, dir, g - 0.8, g + h)
		t += 0.34
		i += 1
	# Two rails tie the stakes.
	for rail: float in [0.35, 0.7]:
		var ga := plan.ground_height(a) + height * rail
		var gb := plan.ground_height(b) + height * rail
		var side := Vector2(-dir.y, dir.x) * 0.22
		_box_between_sloped(shell, "timber", a + side, b + side, 0.14, ga, gb, 0.16)


static func _stake(
	shell: CityBuildingBuilder.Shell, p: Vector2, dir: Vector2, y0: float, y1: float
) -> void:
	var side := Vector2(-dir.y, dir.x)
	var r := 0.16
	var c0 := p - dir * r - side * r
	var c1 := p + dir * r - side * r
	var c2 := p + dir * r + side * r
	var c3 := p - dir * r + side * r
	var tip := Vector3(p.x, y1 + 0.35, p.y)
	var ring := [c0, c1, c2, c3]
	for k in 4:
		var u: Vector2 = ring[k]
		var v: Vector2 = ring[(k + 1) % 4]
		var o := (u + v) * 0.5 - p
		var out := Vector3(o.x, 0, o.y)
		shell.quad_out(
			"timber",
			Vector3(v.x, y0, v.y),
			Vector3(u.x, y0, u.y),
			Vector3(u.x, y1, u.y),
			Vector3(v.x, y1, v.y),
			Color(1, 1, 1),
			out
		)
		shell.tri_out(
			"timber",
			Vector3(v.x, y1, v.y),
			Vector3(u.x, y1, u.y),
			tip,
			Color(1, 1, 1),
			out + Vector3.UP * 0.2
		)


## Axis-aligned-to-segment box from a to b (centre line), given width and heights.
static func _box_between(
	shell: CityBuildingBuilder.Shell,
	key: String,
	a: Vector2,
	b: Vector2,
	width: float,
	y0: float,
	y1: float
) -> void:
	_box_between_sloped(shell, key, a, b, width, y0, y0, y1 - y0)


static func _box_between_sloped(
	shell: CityBuildingBuilder.Shell,
	key: String,
	a: Vector2,
	b: Vector2,
	width: float,
	ya: float,
	yb: float,
	h: float
) -> void:
	var dir := (b - a).normalized()
	var side := Vector2(-dir.y, dir.x) * width * 0.5
	var corners := [a + side, b + side, b - side, a - side]
	var bottoms := [ya, yb, yb, ya]
	var tint := Color(1, 1, 1)
	var center := (a + b) * 0.5
	for k in 4:
		var u: Vector2 = corners[k]
		var v: Vector2 = corners[(k + 1) % 4]
		var yu: float = bottoms[k]
		var yv: float = bottoms[(k + 1) % 4]
		var o := (u + v) * 0.5 - center
		shell.quad_out(
			key,
			Vector3(v.x, yv, v.y),
			Vector3(u.x, yu, u.y),
			Vector3(u.x, yu + h, u.y),
			Vector3(v.x, yv + h, v.y),
			tint,
			Vector3(o.x, 0, o.y)
		)
	var c0: Vector2 = corners[0]
	var c1: Vector2 = corners[1]
	var c2: Vector2 = corners[2]
	var c3: Vector2 = corners[3]
	shell.quad_out(
		key,
		Vector3(c0.x, ya + h, c0.y),
		Vector3(c3.x, ya + h, c3.y),
		Vector3(c2.x, yb + h, c2.y),
		Vector3(c1.x, yb + h, c1.y),
		tint,
		Vector3.UP
	)
	shell.quad_out(
		key,
		Vector3(c0.x, ya, c0.y),
		Vector3(c3.x, ya, c3.y),
		Vector3(c2.x, yb, c2.y),
		Vector3(c1.x, yb, c1.y),
		tint,
		Vector3.DOWN
	)


## Oriented box from its centre, half extents along `dir` and its side, heights.
static func _obox(
	shell: CityBuildingBuilder.Shell,
	key: String,
	center: Vector2,
	dir: Vector2,
	half_len: float,
	half_wid: float,
	y0: float,
	y1: float,
	tint := Color(1, 1, 1)
) -> void:
	var side := Vector2(-dir.y, dir.x)
	var corners := [
		center - dir * half_len - side * half_wid,
		center + dir * half_len - side * half_wid,
		center + dir * half_len + side * half_wid,
		center - dir * half_len + side * half_wid,
	]
	for k in 4:
		var u: Vector2 = corners[k]
		var v: Vector2 = corners[(k + 1) % 4]
		var o := (u + v) * 0.5 - center
		shell.quad_out(
			key,
			Vector3(u.x, y0, u.y),
			Vector3(v.x, y0, v.y),
			Vector3(v.x, y1, v.y),
			Vector3(u.x, y1, u.y),
			tint,
			Vector3(o.x, 0, o.y)
		)
	var c0: Vector2 = corners[0]
	var c1: Vector2 = corners[1]
	var c2: Vector2 = corners[2]
	var c3: Vector2 = corners[3]
	shell.quad_out(
		key,
		Vector3(c0.x, y1, c0.y),
		Vector3(c1.x, y1, c1.y),
		Vector3(c2.x, y1, c2.y),
		Vector3(c3.x, y1, c3.y),
		tint,
		Vector3.UP
	)
	shell.quad_out(
		key,
		Vector3(c0.x, y0, c0.y),
		Vector3(c1.x, y0, c1.y),
		Vector3(c2.x, y0, c2.y),
		Vector3(c3.x, y0, c3.y),
		tint,
		Vector3.DOWN
	)


static func _pyramid(
	shell: CityBuildingBuilder.Shell,
	key: String,
	center: Vector2,
	dir: Vector2,
	half_len: float,
	half_wid: float,
	y0: float,
	rise: float
) -> void:
	var side := Vector2(-dir.y, dir.x)
	var corners := [
		center - dir * half_len - side * half_wid,
		center + dir * half_len - side * half_wid,
		center + dir * half_len + side * half_wid,
		center - dir * half_len + side * half_wid,
	]
	var apex := Vector3(center.x, y0 + rise, center.y)
	for k in 4:
		var u: Vector2 = corners[k]
		var v: Vector2 = corners[(k + 1) % 4]
		var o := (u + v) * 0.5 - center
		shell.tri_out(
			key,
			Vector3(u.x, y0, u.y),
			apex,
			Vector3(v.x, y0, v.y),
			Color(1, 1, 1),
			Vector3(o.x, rise * 0.5, o.y),
			Vector2(0, 0),
			Vector2(0.5, rise),
			Vector2(1, 0)
		)
	var c0: Vector2 = corners[0]
	var c2: Vector2 = corners[2]
	shell.quad_out(
		key,
		Vector3(c0.x, y0, c0.y),
		Vector3(corners[1].x, y0, corners[1].y),
		Vector3(c2.x, y0, c2.y),
		Vector3(corners[3].x, y0, corners[3].y),
		Color(1, 1, 1),
		Vector3.DOWN
	)


## Gate house: two jambs and a vault over a passage across the curtain line.
static func _gate(shell: CityBuildingBuilder.Shell, plan: CityPlan, g: Dictionary) -> void:
	var at := Vector2(g["at"][0], g["at"][1])
	var along := Vector2(cos(float(g["angle"])), sin(float(g["angle"])))
	var opening := float(g["opening"])
	var ground := plan.ground_height(at)
	var state := String(g["state"])
	if state == "wooden":
		_timber_gate(shell, plan, at, along, opening, 1.6)
		return
	var depth := 1.72 * GATE_DEPTH_FACTOR
	var jamb := 2.4
	var height := 7.6 if state != "unfinished" else 5.0
	if String(g["id"]) == "gate.coastal":
		height = 12.5
	if state == "present_construction":
		height = 6.0
	var across := Vector2(-along.y, along.x)
	for s: float in [-1.0, 1.0]:
		var c := at + along * s * (opening * 0.5 + jamb * 0.5)
		_obox(shell, "stone", c, along, jamb * 0.5, depth * 0.5, ground - 1.6, ground + height)
	# Vault / upper storey over the passage.
	var top_y := ground + height
	var lintel_y := ground + 4.1
	_obox(shell, "stone", at, along, opening * 0.5 + 0.05, depth * 0.5, lintel_y, top_y)
	# Passage ceiling darkness and a gate leaf hinged open against the jamb.
	_obox(shell, "dark", at, along, opening * 0.5, depth * 0.48, lintel_y - 0.08, lintel_y)
	var leaf_c := at + along * (opening * 0.5 - 0.1) + across * (depth * 0.25)
	_obox(shell, "timber", leaf_c, across, opening * 0.25, 0.08, ground, ground + 3.6)
	if state == "unfinished" or state == "present_construction":
		_scaffold(
			shell,
			plan,
			at - along * (opening * 0.5 + jamb),
			at + along * (opening * 0.5 + jamb),
			height,
			depth
		)
	else:
		_pyramid(
			shell, "roof", at, along, opening * 0.5 + jamb + 0.3, depth * 0.5 + 0.3, top_y, 3.4
		)


## Wooden hill gate (1343): two posts, a high lintel and open leaves. No hood:
## a roof over the passage would sit in the third-person camera's path.
static func _timber_gate(
	shell: CityBuildingBuilder.Shell,
	plan: CityPlan,
	at: Vector2,
	along: Vector2,
	opening: float,
	_thickness: float
) -> void:
	var ground := plan.ground_height(at)
	var across := Vector2(-along.y, along.x)
	for s: float in [-1.0, 1.0]:
		var post := at + along * s * (opening * 0.5 + 0.2)
		_obox(shell, "timber", post, along, 0.24, 0.24, ground - 0.6, ground + 6.2)
	_obox(shell, "timber", at, along, opening * 0.5 + 0.5, 0.26, ground + 5.6, ground + 6.0)
	# Leaves stand open against the posts, swung toward the town.
	for s: float in [-1.0, 1.0]:
		var leaf := at + along * s * (opening * 0.5 - 0.05) + across * (opening * 0.25 + 0.1)
		_obox(shell, "timber", leaf, across, opening * 0.25, 0.07, ground, ground + 3.4)


static func _tower(shell: CityBuildingBuilder.Shell, plan: CityPlan, t: Dictionary) -> void:
	var at := Vector2(t["at"][0], t["at"][1])
	var along := Vector2(cos(float(t["angle"])), sin(float(t["angle"])))
	var w := float(t["w"])
	var d := float(t["d"])
	var h := float(t["h"])
	var ground := plan.ground_height(at)
	var form := String(t["form"])
	if form == "gate_rect":
		return  # the gate house carries it
	# Project outward (field side) by half the depth.
	var c := _toward_field(plan, at, along, d * 0.35)
	var state := String(t["state"])
	if form == "horseshoe":
		_drum(shell, c, w * 0.5, ground - 1.6, ground + h, 14)
		if state == "completed":
			_cone(shell, "roof", c, w * 0.5 + 0.35, ground + h, 4.2, 14)
	else:
		_obox(shell, "stone", c, along, w * 0.5, d * 0.5, ground - 1.6, ground + h)
		if state == "completed":
			_pyramid(shell, "roof", c, along, w * 0.5 + 0.35, d * 0.5 + 0.35, ground + h, 3.6)
	if state == "construction":
		_scaffold(shell, plan, c - along * w * 0.5, c + along * w * 0.5, h, d)


static func _toward_field(plan: CityPlan, at: Vector2, along: Vector2, offset: float) -> Vector2:
	var circuit: Array = plan.data["circuit"]
	var centroid := Vector2.ZERO
	for a: Dictionary in circuit:
		centroid += Vector2(a["at"][0], a["at"][1])
	centroid /= maxf(circuit.size(), 1)
	var side := Vector2(-along.y, along.x)
	if (at + side).distance_to(centroid) < (at - side).distance_to(centroid):
		side = -side
	return at + side * offset


static func _drum(
	shell: CityBuildingBuilder.Shell, c: Vector2, r: float, y0: float, y1: float, segments: int
) -> void:
	for k in segments:
		var a0 := TAU * float(k) / segments
		var a1 := TAU * float(k + 1) / segments
		var u := c + Vector2(cos(a0), sin(a0)) * r
		var v := c + Vector2(cos(a1), sin(a1)) * r
		var o := (u + v) * 0.5 - c
		shell.quad_out(
			"stone",
			Vector3(v.x, y0, v.y),
			Vector3(u.x, y0, u.y),
			Vector3(u.x, y1, u.y),
			Vector3(v.x, y1, v.y),
			Color(1, 1, 1),
			Vector3(o.x, 0, o.y)
		)
		shell.tri_out(
			"stone",
			Vector3(c.x, y1, c.y),
			Vector3(v.x, y1, v.y),
			Vector3(u.x, y1, u.y),
			Color(1, 1, 1),
			Vector3.UP
		)


static func _cone(
	shell: CityBuildingBuilder.Shell,
	key: String,
	c: Vector2,
	r: float,
	y0: float,
	rise: float,
	segments: int
) -> void:
	var apex := Vector3(c.x, y0 + rise, c.y)
	for k in segments:
		var a0 := TAU * float(k) / segments
		var a1 := TAU * float(k + 1) / segments
		var u := c + Vector2(cos(a0), sin(a0)) * r
		var v := c + Vector2(cos(a1), sin(a1)) * r
		var o := (u + v) * 0.5 - c
		shell.tri_out(
			key,
			Vector3(v.x, y0, v.y),
			apex,
			Vector3(u.x, y0, u.y),
			Color(1, 1, 1),
			Vector3(o.x, rise * 0.5, o.y),
			Vector2(0, 0),
			Vector2(0.5, rise),
			Vector2(1, 0)
		)


static func _castle(shell: CityBuildingBuilder.Shell, plan: CityPlan) -> void:
	var castle: Dictionary = plan.data.get("castle", {})
	if castle.is_empty():
		return
	var ring := CityPlan.points(castle["ring"])
	var wall_h := float(castle["wall_h"])
	var tower_h := float(castle["tower_h"])
	for i in ring.size():
		var a := ring[i]
		var b := ring[(i + 1) % ring.size()]
		_curtain(shell, plan, a, b, "stone", wall_h, 2.0, _centroid_of(Array(ring)))
	for tower: Dictionary in castle_tower_points(plan):
		var p: Vector2 = tower["at"]
		var g := plan.ground_height(p)
		_obox(shell, "stone", p, Vector2(1, 0), 4.2, 4.2, g - 1.6, float(tower["top"]) - 4.5)
		_pyramid(shell, "tile", p, Vector2(1, 0), 4.6, 4.6, float(tower["top"]) - 4.5, 4.5)


## Castle corner towers at the sharpest corners of the castle ring (up to
## four): {at, top} where top is the spire apex. Shared with the pennants.
static func castle_tower_points(plan: CityPlan) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var castle: Dictionary = plan.data.get("castle", {})
	if castle.is_empty():
		return out
	var ring := CityPlan.points(castle["ring"])
	var corners: Array = []
	for i in ring.size():
		var p := ring[i]
		var u := (ring[(i - 1 + ring.size()) % ring.size()] - p).normalized()
		var v := (ring[(i + 1) % ring.size()] - p).normalized()
		corners.append([u.dot(v), i])
	corners.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0])
	for k in mini(4, corners.size()):
		var p := ring[int(corners[k][1])]
		out.append({"at": p, "top": plan.ground_height(p) + float(castle["tower_h"]) + 4.5})
	return out
