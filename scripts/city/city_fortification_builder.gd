class_name CityFortificationBuilder
extends RefCounted

## Lower Town curtain, gates and dated towers, the Toompea plateau wall and the
## castle, from the city plan (ADR 0031; 1343 states per
## history/dossiers/topography/walls-gates-towers.md). Curtains follow the
## ground: the top runs parallel to the terrain between anchors. States:
##   stone         ~6.2 m limestone curtain, merlons on the field-side parapet
##                 and a covered timber wall-walk under a tile lean-to roof
##   construction  lower unfinished course with putlog scaffolding, no merlons
##   palisade      timber stakes (the hill-side boundary and SW slope)

const MERLON_W := 1.1
const MERLON_GAP := 0.9
const MERLON_H := 1.0
const GATE_DEPTH_FACTOR := 2.4
const SAMPLE_STEP := 3.0

static var _stone: Material
static var _tile: Material


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
		var p0 := a
		var p1 := b
		if gates_by_anchor.has(i):
			p0 = gate_joint(gates_by_anchor[i], dir)
		if gates_by_anchor.has((i + 1) % curtains.size()):
			p1 = gate_joint(gates_by_anchor[(i + 1) % curtains.size()], -dir)
		if (p1 - p0).dot(dir) <= 0.5:
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
	# Barbican (Viru): an outer gate and two bailey walls; the four drums come from
	# the tower list.
	for bb: Dictionary in plan.data.get("barbicans", []):
		_gate(shell, plan, bb["outer_gate"])
		for w: Dictionary in bb["walls"]:
			_curtain(
				shell,
				plan,
				Vector2(w["from"][0], w["from"][1]),
				Vector2(w["to"][0], w["to"][1]),
				"stone",
				float(w["height"]),
				float(w["thickness"]),
				town_centroid
			)
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
	add_gate_banners(plan, root)
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
			return _tile_material()
		"dark":
			return CityBuildingBuilder.opening_material()
		"banner":
			return MapViewMaterials.hanging_banner_cloth(null, true)
	return _stone_material()


## Red ceramic tile in world-unit UVs, shared by gallery roofs and tower cones.
static func _tile_material() -> Material:
	if _tile == null:
		var mat := (
			MapViewMaterials.roof_tile_world(Color(0.70, 0.33, 0.22)).duplicate()
			as StandardMaterial3D
		)
		mat.vertex_color_use_as_albedo = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_tile = mat
	return _tile


static func _stone_material() -> Material:
	if _stone == null:
		# Warm, sun-bleached Reval limestone with rising damp at the wall foot.
		var plate := MapViewMaterials.fortification_masonry(Color(0.86, 0.83, 0.76))
		_stone = CityBuildingBuilder.weathered_wall(plate, Color(1.06, 0.98, 0.84))
	return _stone


## Drops cached materials so the next build binds the current city heightfield.
static func bind_ground() -> void:
	_stone = null
	_tile = null


static func _centroid_of(points: Array) -> Vector2:
	var c := Vector2.ZERO
	for p: Vector2 in points:
		c += p
	return c / maxf(points.size(), 1)


## Where a curtain leaving a gate (towards `toward`) meets the gate house: the
## middle of the house's end face on the curtain's side, sunk 0.3 m into it. The
## gate house is aligned to its street, not to the wall, so trimming the curtain
## along its own line (the old way) left a wedge-shaped hole at the corner.
static func gate_joint(g: Dictionary, toward: Vector2) -> Vector2:
	var at := Vector2(g["at"][0], g["at"][1])
	var along := Vector2(cos(float(g["angle"])), sin(float(g["angle"])))
	var side := 1.0 if toward.dot(along) >= 0.0 else -1.0
	return at + along * side * (_gate_half_extent(g) - 0.3)


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
		if thickness >= 1.2:
			_gallery(shell, plan, p0, p1, height, thickness, field_sign)
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


## Covered wall-walk: timber posts on the town edge of the wall top carry a
## lean-to tile roof that rises to the parapet, the gallery Reval's curtain
## carried by mid-century (arcaded wall-walk, wooden fighting platforms).
static func _gallery(
	shell: CityBuildingBuilder.Shell,
	plan: CityPlan,
	p0: Vector2,
	p1: Vector2,
	height: float,
	thickness: float,
	field_sign: float
) -> void:
	var length := p0.distance_to(p1)
	if length < 3.0:
		return
	var dir := (p1 - p0) / length
	var field := Vector2(-dir.y, dir.x) * field_sign
	var outer_off := thickness * 0.5 - 0.15
	var inner_off := -(thickness * 0.5 + 1.1)
	var post_off := -(thickness * 0.5 - 0.15)
	var steps := maxi(1, int(ceil(length / SAMPLE_STEP)))
	var tint := Color(1, 1, 1)
	for s in steps:
		var u := p0.lerp(p1, float(s) / steps)
		var v := p0.lerp(p1, float(s + 1) / steps)
		var tu := plan.ground_height(u) + height
		var tv := plan.ground_height(v) + height
		var hi := MERLON_H + 2.0
		var lo := 2.35
		var a := Vector3(u.x + field.x * outer_off, tu + hi, u.y + field.y * outer_off)
		var b := Vector3(v.x + field.x * outer_off, tv + hi, v.y + field.y * outer_off)
		var c := Vector3(v.x + field.x * inner_off, tv + lo, v.y + field.y * inner_off)
		var d := Vector3(u.x + field.x * inner_off, tu + lo, u.y + field.y * inner_off)
		var along_u := float(s) / steps * length
		var along_v := float(s + 1) / steps * length
		var slant := Vector2(outer_off - inner_off, hi - lo).length()
		shell.tri_out(
			"tile",
			a,
			b,
			c,
			tint,
			Vector3.UP,
			Vector2(along_u, 0),
			Vector2(along_v, 0),
			Vector2(along_v, slant)
		)
		shell.tri_out(
			"tile",
			a,
			c,
			d,
			tint,
			Vector3.UP,
			Vector2(along_u, 0),
			Vector2(along_v, slant),
			Vector2(along_u, slant)
		)
		# Eave board.
		shell.quad_out(
			"timber",
			d - Vector3(0, 0.25, 0),
			c - Vector3(0, 0.25, 0),
			c,
			d,
			tint,
			Vector3(-field.x, 0, -field.y)
		)
	var t := 1.2
	while t < length - 0.6:
		var p := p0 + dir * t + field * post_off
		var top := plan.ground_height(p) + height
		_box_between(shell, "timber", p - dir * 0.13, p + dir * 0.13, 0.26, top - 0.05, top + 2.45)
		# Knee brace under the eave.
		_box_between(shell, "timber", p - dir * 0.6, p + dir * 0.6, 0.16, top + 2.05, top + 2.25)
		t += 2.6


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


## Gate house: a stone block across the curtain with a round-arched passage,
## open timber leaves inside the arch and a steep tiled roof. The Coastal Gate
## house stands taller (its 1311-1340 tower).
static func _gate(shell: CityBuildingBuilder.Shell, plan: CityPlan, g: Dictionary) -> void:
	var at := Vector2(g["at"][0], g["at"][1])
	var along := Vector2(cos(float(g["angle"])), sin(float(g["angle"])))
	var opening := float(g["opening"])
	var ground := plan.ground_height(at)
	if String(g["state"]) == "wooden":
		_timber_gate(shell, plan, at, along, opening, 1.6)
		return
	var depth := 1.72 * GATE_DEPTH_FACTOR
	var half_w := opening * 0.5 + 2.4
	var height := gate_height(g)
	var spring := ground + 3.0
	var across := Vector2(-along.y, along.x)
	for s: float in [-1.0, 1.0]:
		var face := at + across * s * depth * 0.5
		_arch_face(shell, face, along, across * s, half_w, opening, ground, spring, ground + height)
	_arch_passage(shell, at, along, across, depth, opening, ground, spring)
	# Block ends where the curtain meets the gate house.
	for s: float in [-1.0, 1.0]:
		var e := at + along * s * half_w
		var a := e - across * depth * 0.5
		var b := e + across * depth * 0.5
		shell.quad_out(
			"stone",
			Vector3(a.x, ground - 1.6, a.y),
			Vector3(b.x, ground - 1.6, b.y),
			Vector3(b.x, ground + height, b.y),
			Vector3(a.x, ground + height, a.y),
			Color(1, 1, 1),
			Vector3(along.x * s, 0, along.y * s)
		)
	# An unfinished gate (Viru, 1343) carries a low shed roof, not the steep cap.
	var roof_rise := 2.2 if String(g["state"]) == "unfinished" else 5.5
	_pyramid(shell, "tile", at, along, half_w + 0.45, depth * 0.5 + 0.45, ground + height, roof_rise)
	# Leaves stand open against the passage walls.
	for s: float in [-1.0, 1.0]:
		var leaf := at + along * s * (opening * 0.5 - 0.1) + across * (opening * 0.25)
		_obox(shell, "timber", leaf, across, opening * 0.25, 0.08, ground, spring + opening * 0.4)


static func gate_height(g: Dictionary) -> float:
	return 12.5 if String(g["id"]) == "gate.coastal" else 9.0


## One face of the gate house: a rectangle with a round-headed opening.
static func _arch_face(
	shell: CityBuildingBuilder.Shell,
	center: Vector2,
	along: Vector2,
	out: Vector2,
	half_w: float,
	opening: float,
	ground: float,
	spring: float,
	top: float
) -> void:
	var r := opening * 0.5
	var outline := PackedVector2Array([Vector2(-half_w, ground - 1.6), Vector2(-r, ground - 1.6)])
	for k in range(0, 13):
		var ang := PI - PI * float(k) / 12.0
		outline.append(Vector2(cos(ang) * r, spring + sin(ang) * r))
	outline.append_array(
		PackedVector2Array(
			[
				Vector2(r, ground - 1.6),
				Vector2(half_w, ground - 1.6),
				Vector2(half_w, top),
				Vector2(-half_w, top)
			]
		)
	)
	var tris := Geometry2D.triangulate_polygon(outline)
	var normal := Vector3(out.x, 0, out.y)
	for i in range(0, tris.size(), 3):
		var pts: Array[Vector3] = []
		for k in 3:
			var q := outline[tris[i + k]]
			var w := center + along * q.x
			pts.append(Vector3(w.x, q.y, w.y))
		shell.tri_out("stone", pts[0], pts[1], pts[2], Color(1, 1, 1), normal)


## Passage walls and the barrel vault between the two faces.
static func _arch_passage(
	shell: CityBuildingBuilder.Shell,
	at: Vector2,
	along: Vector2,
	across: Vector2,
	depth: float,
	opening: float,
	ground: float,
	spring: float
) -> void:
	var r := opening * 0.5
	var f := across * depth * 0.5
	for s: float in [-1.0, 1.0]:
		var x := at + along * s * r
		shell.quad_out(
			"stone",
			Vector3(x.x - f.x, ground - 0.2, x.y - f.y),
			Vector3(x.x + f.x, ground - 0.2, x.y + f.y),
			Vector3(x.x + f.x, spring, x.y + f.y),
			Vector3(x.x - f.x, spring, x.y - f.y),
			Color(0.8, 0.8, 0.8),
			Vector3(-along.x * s, 0, -along.y * s)
		)
	for k in 12:
		var a0 := PI - PI * float(k) / 12.0
		var a1 := PI - PI * float(k + 1) / 12.0
		var p0 := at + along * cos(a0) * r
		var p1 := at + along * cos(a1) * r
		var y0 := spring + sin(a0) * r
		var y1 := spring + sin(a1) * r
		var mid := Vector3((p0.x + p1.x) * 0.5, (y0 + y1) * 0.5, (p0.y + p1.y) * 0.5)
		var inward := Vector3(at.x, spring, at.y) - mid
		shell.quad_out(
			"stone",
			Vector3(p0.x - f.x, y0, p0.y - f.y),
			Vector3(p1.x - f.x, y1, p1.y - f.y),
			Vector3(p1.x + f.x, y1, p1.y + f.y),
			Vector3(p0.x + f.x, y0, p0.y + f.y),
			Color(0.7, 0.7, 0.7),
			inward
		)


## Two hanging town banners on the field face of each stone gate house.
static func add_gate_banners(plan: CityPlan, root: Node3D) -> void:
	const TownHallModel := preload("res://scripts/map/view3d/map_view_town_hall_model.gd")
	var mesh := TownHallModel._banner_mesh(1.1, 2.6, false, 1)
	var material := MapViewMaterials.hanging_banner_cloth(null, true)
	for g: Dictionary in plan.data["gates"]:
		if String(g["state"]) == "wooden":
			continue
		var at := Vector2(g["at"][0], g["at"][1])
		var along := Vector2(cos(float(g["angle"])), sin(float(g["angle"])))
		var field := _toward_field(plan, at, along, 1.0) - at
		var depth := 1.72 * GATE_DEPTH_FACTOR
		var ground := plan.ground_height(at)
		var opening := float(g["opening"])
		for s: float in [-1.0, 1.0]:
			var banner := MeshInstance3D.new()
			banner.name = "GateBanner_%s_%d" % [String(g["id"]).replace(".", "_"), int(s)]
			banner.mesh = mesh
			banner.material_override = material
			# Mesh hangs from its top-left corner along +X and faces -Z.
			var x_axis := Vector3(along.x, 0, along.y)
			var z_axis := Vector3(-field.x, 0, -field.y)
			banner.basis = Basis(x_axis, Vector3.UP, z_axis)
			var corner := (
				at + field * (depth * 0.5 + 0.06) + along * (s * (opening * 0.5 + 1.2) - 0.55)
			)
			banner.position = Vector3(corner.x, ground + 6.2, corner.y)
			root.add_child(banner)


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
	var c := tower_centre(plan, t)
	if form == "octagonal":
		_octagonal_keep(shell, c, w * 0.5, h, float(t.get("roof_h", w * 0.4)), ground)
		return
	if form == "horseshoe" or form == "round":
		var r := w * 0.5
		# Battered foot, then the drum, slit windows and a tile cone.
		_drum(shell, c, r + 0.35, ground - 1.6, ground + 1.2, 18)
		_drum(shell, c, r, ground + 1.2, ground + h, 18)
		for k in 4:
			var ang := TAU * (float(k) + 0.5) / 4.0
			var dir := Vector2(cos(ang), sin(ang))
			var pos := c + dir * (r + 0.03)
			var tang := Vector2(-dir.y, dir.x)
			for level: float in [0.45, 0.75]:
				var y := ground + h * level
				var a := pos - tang * 0.14
				var b := pos + tang * 0.14
				shell.quad_out(
					"dark",
					Vector3(a.x, y, a.y),
					Vector3(b.x, y, b.y),
					Vector3(b.x, y + 1.0, b.y),
					Vector3(a.x, y + 1.0, a.y),
					Color(1, 1, 1),
					Vector3(dir.x, 0, dir.y)
				)
		# Corbelled fighting gallery under the roof: the silhouette Tallinn's round
		# towers are known by. The cone is a moderate ~50 degrees (it was 66 and read
		# as a needle) with eaves overhanging the gallery.
		_drum(shell, c, r + 0.4, ground + h - 1.5, ground + h, 18)
		_cone(shell, "tile", c, r + 0.9, ground + h, float(t.get("roof_h", (r + 0.9) * 1.2)), 18)
	else:
		_obox(shell, "stone", c, along, w * 0.5, d * 0.5, ground - 1.6, ground + h)
		_pyramid(shell, "tile", c, along, w * 0.5 + 0.5, d * 0.5 + 0.5, ground + h, w * 1.1)


## Centre of a tower's body. Wall towers project outward (field side) by part
## of their depth; a free-standing keep (`octagonal`, ADR 0042 regional sites)
## stands on its own point. Shared with the collision builder.
static func tower_centre(plan: CityPlan, t: Dictionary) -> Vector2:
	var at := Vector2(t["at"][0], t["at"][1])
	if String(t["form"]) == "octagonal":
		return at
	var along := Vector2(cos(float(t["angle"])), sin(float(t["angle"])))
	return _toward_field(plan, at, along, float(t["d"]) * 0.35)


## Free-standing octagonal keep (the Paide main tower, about 30 m with 2.4 m
## walls after Tuulse): a battered plinth, the eight-sided shaft with slit
## windows on every face, a corbelled fighting level behind a parapet, and a
## low eight-sided cap.
static func _octagonal_keep(
	shell: CityBuildingBuilder.Shell, c: Vector2, r: float, h: float, roof_h: float, ground: float
) -> void:
	_drum(shell, c, r + 0.5, ground - 2.0, ground + 2.0, 8)
	_drum(shell, c, r, ground + 2.0, ground + h - 2.2, 8)
	for k in 8:
		var ang := TAU * (float(k) + 0.5) / 8.0
		var dir := Vector2(cos(ang), sin(ang))
		# Face midpoint of the octagon (apothem), slightly proud of the wall.
		var pos := c + dir * (r * cos(PI / 8.0) + 0.03)
		var tang := Vector2(-dir.y, dir.x)
		for level: float in [0.3, 0.5, 0.7]:
			var y := ground + h * level
			var a := pos - tang * 0.18
			var b := pos + tang * 0.18
			shell.quad_out(
				"dark",
				Vector3(a.x, y, a.y),
				Vector3(b.x, y, b.y),
				Vector3(b.x, y + 1.3, b.y),
				Vector3(a.x, y + 1.3, a.y),
				Color(1, 1, 1),
				Vector3(dir.x, 0, dir.y)
			)
	_drum(shell, c, r + 0.55, ground + h - 2.2, ground + h, 8)
	_cone(shell, "tile", c, r + 0.9, ground + h, roof_h, 8)


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
		var slant := sqrt(r * r + rise * rise)
		var arc0 := float(k) / segments * TAU * r
		var arc1 := float(k + 1) / segments * TAU * r
		shell.tri_out(
			key,
			Vector3(v.x, y0, v.y),
			apex,
			Vector3(u.x, y0, u.y),
			Color(1, 1, 1),
			Vector3(o.x, rise * 0.5, o.y),
			Vector2(arc1, slant),
			Vector2((arc0 + arc1) * 0.5, 0.0),
			Vector2(arc0, slant)
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
