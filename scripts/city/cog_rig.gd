class_name CogRig
extends RefCounted

## Mast, yard, sail, standing and running rigging, masthead top and stern rudder
## of the cog (metres, CogHull frame). Dimensions: mast ~19 m (Bremen cog 21 m),
## yard 13.6 m (Bremen-class band 14.6-18 m), sail ~95 m2 (Bremen ~200 m2 with
## bonnets). Counts of shrouds and braces are plausible composites, not
## attested (docs/reports/baltic_vessels_1343.md, V1 Rig).
##
## Rope and sail motion is not simulated on the CPU: `cog_rope.gdshader` sags and
## bellies every rope with the shared wind, `cog_sail.gdshader` fills the sail from
## the wind seen in the ship's own frame, so a hull at anchor, a hull under way
## and a ship that turns each get the right answer from the same code.

const MAST_X := CogInterior.MAST_X
const MAST_BASE_Y := -1.4
const MAST_TOP_Y := 17.4
const TOP_Y := 13.4
const YARD_X := MAST_X + 0.45
const YARD_Y := 12.0
const YARD_HALF := 6.8
const SAIL_DEPTH := 7.4
const SAIL_HEAD_HALF := 6.4
const SAIL_FOOT_HALF := 5.7

const HEMP := Color(0.66, 0.55, 0.38)
const TARRED := Color(0.2, 0.16, 0.12)
const CANVAS := Color(0.92, 0.88, 0.78)
const IRON := Color(0.17, 0.17, 0.19)

const SAIL_SHADER := preload("res://scripts/city/cog_sail.gdshader")
const ROPE_SHADER := preload("res://scripts/city/cog_rope.gdshader")

static var _sail_material: ShaderMaterial
static var _rope_material: ShaderMaterial


static func sail_material() -> ShaderMaterial:
	if _sail_material == null:
		_sail_material = ShaderMaterial.new()
		_sail_material.shader = SAIL_SHADER
	return _sail_material


static func rope_material() -> ShaderMaterial:
	if _rope_material == null:
		_rope_material = ShaderMaterial.new()
		_rope_material.shader = ROPE_SHADER
	return _rope_material


## Wood, iron and rope parts of the mast and rigging. `sail_set` selects a
## wind-filled sail; otherwise the sail is furled along the yard (the normal state
## of a ship lying at anchor with her bow to the wind).
static func add_all(
	timber: CogParts, iron: CogParts, ropes: CogParts, sail_set: bool, anchored: bool
) -> void:
	_add_mast(timber, iron)
	_add_yard(timber, iron, ropes)
	_add_standing(ropes, timber)
	_add_running(ropes, sail_set)
	if anchored:
		_add_anchor_cable(ropes)
	else:
		_add_stowed_anchor(timber, iron)


static func _add_mast(t: CogParts, iron: CogParts) -> void:
	# One tapered spar: a stout heel in the hold narrowing to the masthead.
	var segs := 7
	for i in segs:
		var f0 := float(i) / segs
		var f1 := float(i + 1) / segs
		t.tube(
			Vector3(MAST_X, lerpf(MAST_BASE_Y, MAST_TOP_Y, f0), 0),
			Vector3(MAST_X, lerpf(MAST_BASE_Y, MAST_TOP_Y, f1), 0),
			lerpf(0.3, 0.14, f0),
			lerpf(0.3, 0.14, f1),
			10,
			CogInterior.OAK,
			i == 0 or i == segs - 1
		)
	# Woolding bands (iron-pinned wraps) on the mast above the deck.
	for y: float in [4.2, 7.5, 10.8]:
		iron.lathe(
			Vector3(MAST_X, y, 0),
			(
				[Vector2(0.31 - (y - 4.0) * 0.012, 0.0), Vector2(0.31 - (y - 4.0) * 0.012, 0.07)]
				as Array[Vector2]
			),
			10,
			TARRED
		)
	# The top (fighting platform, seen on period seals): planked floor, rail, brackets.
	t.box(Vector3(MAST_X, TOP_Y, 0), Vector3(2.0, 0.12, 2.0), CogInterior.PINE)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			t.tube(
				Vector3(MAST_X + sx * 0.95, TOP_Y, sz * 0.95),
				Vector3(MAST_X + sx * 0.95, TOP_Y + 0.85, sz * 0.95),
				0.04,
				0.04,
				5,
				CogInterior.DARK
			)
	for side: float in [-1.0, 1.0]:
		t.beam(
			Vector3(MAST_X - 0.95, TOP_Y + 0.8, side * 0.95),
			Vector3(MAST_X + 0.95, TOP_Y + 0.8, side * 0.95),
			0.06,
			0.06,
			CogInterior.DARK
		)
		t.beam(
			Vector3(MAST_X + side * 0.95, TOP_Y + 0.8, -0.95),
			Vector3(MAST_X + side * 0.95, TOP_Y + 0.8, 0.95),
			0.06,
			0.06,
			CogInterior.DARK
		)
		t.beam(
			Vector3(MAST_X, TOP_Y - 0.9, side * 0.2),
			Vector3(MAST_X, TOP_Y - 0.06, side * 1.0),
			0.1,
			0.12,
			CogInterior.DARK
		)
	# Masthead sheave block and cap.
	iron.box(Vector3(MAST_X + 0.12, MAST_TOP_Y - 0.3, 0), Vector3(0.18, 0.4, 0.5), IRON)


static func _add_yard(t: CogParts, iron: CogParts, ropes: CogParts) -> void:
	# Yard of two scarfed spars, tapering to the arms, with a fish at the scarf.
	t.tube(
		Vector3(YARD_X, YARD_Y, 0),
		Vector3(YARD_X, YARD_Y, -YARD_HALF),
		0.17,
		0.07,
		8,
		CogInterior.OAK
	)
	t.tube(
		Vector3(YARD_X, YARD_Y, 0),
		Vector3(YARD_X, YARD_Y, YARD_HALF),
		0.17,
		0.07,
		8,
		CogInterior.OAK
	)
	t.tube(
		Vector3(YARD_X, YARD_Y, -0.9), Vector3(YARD_X, YARD_Y, 0.9), 0.2, 0.2, 8, CogInterior.DARK
	)
	# Parrel: a collar of rope holding the yard to the mast.
	ropes.rope(
		Vector3(YARD_X - 0.1, YARD_Y, 0.25),
		Vector3(MAST_X - 0.27, YARD_Y - 0.05, 0.25),
		0.04,
		0.0,
		TARRED
	)
	ropes.rope(
		Vector3(YARD_X - 0.1, YARD_Y, -0.25),
		Vector3(MAST_X - 0.27, YARD_Y - 0.05, -0.25),
		0.04,
		0.0,
		TARRED
	)
	iron.box(Vector3(YARD_X, YARD_Y + 0.2, 0), Vector3(0.12, 0.12, 0.24), IRON)


## Fixed rigging: stays, shrouds with ratlines to the top, backstays.
static func _add_standing(r: CogParts, t: CogParts) -> void:
	var stem_head := Vector3(
		CogHull.x_fore(CogHull.FORECASTLE_Y) - 0.1, CogHull.FORECASTLE_Y + 0.35, 0
	)
	r.rope(Vector3(MAST_X, MAST_TOP_Y - 0.45, 0), stem_head, 0.035, 0.05, TARRED)
	for side: float in [-1.0, 1.0]:
		var rail := Vector3(
			-7.4,
			CogHull.STERNCASTLE_Y,
			CogHull.half_width_at(-7.4, CogHull.STERNCASTLE_Y, false) * side
		)
		r.rope(Vector3(MAST_X - 0.15, MAST_TOP_Y - 0.5, side * 0.2), rail, 0.03, 0.08, TARRED)
	# Shrouds: three a side. Lower ends on the sheer strake, upper in the top.
	var feet: Array[float] = [-0.6, 0.5, 1.6]
	for side: float in [-1.0, 1.0]:
		var lowers: Array[Vector3] = []
		var uppers: Array[Vector3] = []
		for k in feet.size():
			var fx := feet[k]
			var low := Vector3(
				fx,
				CogHull.SHEER_Y,
				(CogHull.half_width_at(fx, CogHull.SHEER_Y, false) + 0.06) * side
			)
			var up := Vector3(MAST_X - 0.3 - 0.12 * k, TOP_Y - 0.15, side * (0.45 + 0.08 * k))
			lowers.append(low)
			uppers.append(up)
			r.rope(low, up, 0.032, 0.0, TARRED)
			# Deadeye and lanyard block at the foot, wooden chain-plate on the hull.
			t.box(low + Vector3(0, -0.12, 0.05 * side), Vector3(0.2, 0.4, 0.07), CogInterior.DARK)
		# Ratlines: rope rungs between the outer shrouds, spaced for a climbing foot.
		var y := CogHull.SHEER_Y + 1.15
		while y < TOP_Y - 0.6:
			var ends: Array[Vector3] = []
			for k: int in [0, 2]:
				var f := (y - lowers[k].y) / (uppers[k].y - lowers[k].y)
				ends.append(lowers[k].lerp(uppers[k], f))
			r.rope(ends[0], ends[1], 0.022, 0.0, HEMP)
			y += 0.42
	# Hanging ladder ropes for the boarding rungs (CogInterior._add_boarding_ladder).
	var top_z := -(CogHull.half_width_at(0.6, CogHull.SHEER_Y, false) + 0.05)
	var low_z := -(CogHull.half_width_at(0.6, 0.0, false) + 0.35)
	for dx: float in [-0.31, 0.31]:
		r.rope(
			Vector3(0.6 + dx * 0.0, CogHull.SHEER_Y, top_z + 0.0),
			Vector3(0.6 + dx * 0.0, 0.2, low_z),
			0.02,
			0.04,
			HEMP
		)


## Running rigging: halyard, lifts, braces, sheets, tacks, bowlines.
static func _add_running(r: CogParts, sail_set: bool) -> void:
	var head := Vector3(MAST_X + 0.1, MAST_TOP_Y - 0.45, 0)
	r.rope(Vector3(YARD_X, YARD_Y + 0.1, 0), head, 0.04, 0.12, HEMP)
	r.rope(head, Vector3(MAST_X - 0.5, CogHull.DECK_Y + 0.25, 0.9), 0.035, 0.35, HEMP)
	for side: float in [-1.0, 1.0]:
		var end := Vector3(YARD_X, YARD_Y, YARD_HALF * side)
		r.rope(end, Vector3(MAST_X - 0.1, MAST_TOP_Y - 0.7, 0.18 * side), 0.028, 0.18, HEMP)
		# Braces swing the yard: aft to the quarter rails.
		var quarter := Vector3(
			-3.4, CogHull.SHEER_Y, CogHull.half_width_at(-3.4, CogHull.SHEER_Y, false) * side
		)
		r.rope(end, quarter, 0.028, 0.5, HEMP)
		# Clews at the foot corners: sheet aft, tack forward, bowline to the bow.
		var clew := Vector3(YARD_X, YARD_Y - SAIL_DEPTH, SAIL_FOOT_HALF * side)
		if sail_set:
			var sheet_to := Vector3(
				-3.0,
				CogHull.SHEER_Y + 0.1,
				CogHull.half_width_at(-3.0, CogHull.SHEER_Y, false) * side
			)
			var tack_to := Vector3(
				5.6,
				CogHull.SHEER_Y + 0.1,
				CogHull.half_width_at(5.6, CogHull.SHEER_Y, false) * side
			)
			r.rope(clew, sheet_to, 0.032, 0.6, HEMP)
			r.rope(clew, tack_to, 0.032, 0.5, HEMP)
			var leech := Vector3(
				YARD_X,
				YARD_Y - SAIL_DEPTH * 0.55,
				lerpf(SAIL_HEAD_HALF, SAIL_FOOT_HALF, 0.55) * side
			)
			var bow_eye := Vector3(CogHull.x_fore(4.0) - 0.8, 4.2, 0.9 * side)
			r.rope(leech, bow_eye, 0.026, 0.55, HEMP)
		else:
			# Furled: the clews are gathered up to the yard arm and lashed.
			r.rope(
				Vector3(YARD_X, YARD_Y - 0.4, 4.2 * side),
				Vector3(YARD_X, YARD_Y - 0.5, 4.9 * side),
				0.03,
				0.04,
				HEMP
			)
		# Sheet and tack tails stay belayed to cleats either way.
		var cleat := Vector3(
			-3.0, CogHull.SHEER_Y + 0.1, CogHull.half_width_at(-3.0, CogHull.SHEER_Y, false) * side
		)
		r.rope(
			cleat, cleat + Vector3(0.5, -1.0, 0.0) + Vector3(0, 0, -0.5 * side), 0.03, 0.18, HEMP
		)
	if not sail_set:
		# Gaskets: the lashings that hold the furled canvas on the yard.
		var z := -YARD_HALF + 1.0
		while z < YARD_HALF - 0.8:
			r.rope(
				Vector3(YARD_X, YARD_Y + 0.17, z),
				Vector3(YARD_X, YARD_Y - 0.45, z + 0.12),
				0.028,
				0.0,
				HEMP
			)
			z += 1.35


static func _add_anchor_cable(r: CogParts) -> void:
	# Out through the hawse in the bow and down into the water; the sea hides the rest.
	var hawse := Vector3(CogHull.x_fore(2.9) - 0.1, 2.9, 0.55)
	r.rope(hawse, hawse + Vector3(11.0, -9.5, 0.0), 0.045, 2.5, HEMP)


static func _add_stowed_anchor(t: CogParts, iron: CogParts) -> void:
	# An iron anchor hung from the cathead on the starboard bow (type unattested for Reval).
	var base := Vector3(7.4, 3.2, 3.0)
	iron.tube(base + Vector3(0, 0.9, 0), base + Vector3(0, -0.9, 0), 0.05, 0.06, 6, IRON)
	iron.tube(base + Vector3(0, -0.8, -0.55), base + Vector3(0, -0.8, 0.55), 0.045, 0.045, 6, IRON)
	iron.tube(base + Vector3(0, -0.8, -0.55), base + Vector3(0, -0.5, -0.8), 0.045, 0.06, 6, IRON)
	iron.tube(base + Vector3(0, -0.8, 0.55), base + Vector3(0, -0.5, 0.8), 0.045, 0.06, 6, IRON)
	t.tube(
		base + Vector3(0, 0.6, -0.6), base + Vector3(0, 0.6, 0.6), 0.05, 0.05, 6, CogInterior.DARK
	)
	iron.lathe(
		base + Vector3(0, 0.95, 0),
		[Vector2(0.12, 0.0), Vector2(0.12, 0.03)] as Array[Vector2],
		8,
		IRON
	)


## Square sail as a grid hung from the yard: UV.x runs across the sail, UV.y
## down it (0 at the yard). The shader pins the head to the yard and the foot
## corners to the clews, and fills the pocket from the wind.
static func sail_mesh() -> ArrayMesh:
	var cols := 18
	var rows := 12
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in rows:
		for c in cols:
			var corners: Array[Vector2] = [
				Vector2(c, r), Vector2(c + 1, r), Vector2(c + 1, r + 1), Vector2(c, r + 1)
			]
			var pts: Array[Vector3] = []
			var uvs: Array[Vector2] = []
			var cols_c: Array[Color] = []
			for k in corners:
				var u := k.x / cols
				var v := k.y / rows
				var half := lerpf(SAIL_HEAD_HALF, SAIL_FOOT_HALF, v)
				# The foot is cut slightly hollow between the clews.
				var y := YARD_Y - SAIL_DEPTH * v + 0.35 * sin(PI * u) * v * v
				pts.append(Vector3(YARD_X, y, (u * 2.0 - 1.0) * half))
				uvs.append(Vector2(u, v))
				# Sewn cloths: alternating tone per cloth, a darker reef band.
				var cloth := 0.95 + 0.03 * float(int(k.x) % 2)
				var band := 0.9 if absf(v - 0.62) < 0.035 else 1.0
				cols_c.append(Color(cloth * band, cloth * band * 0.98, cloth * band * 0.9))
			# Double-sided cloth: the shader flips normals on back faces (cull disabled).
			for idx: int in [0, 2, 1, 0, 3, 2]:
				st.set_color(cols_c[idx])
				st.set_uv(uvs[idx])
				st.set_normal(Vector3.RIGHT)
				st.add_vertex(pts[idx])
	return st.commit()


## Furled canvas: a lumpy sausage lying along the yard.
static func furled_sail(parts: CogParts) -> void:
	var n := 14
	var rng := RandomNumberGenerator.new()
	rng.seed = 1343
	for i in n:
		var z0 := lerpf(-YARD_HALF + 0.5, YARD_HALF - 0.5, float(i) / n)
		var z1 := lerpf(-YARD_HALF + 0.5, YARD_HALF - 0.5, float(i + 1) / n)
		var r0 := 0.34 + rng.randf() * 0.1
		var r1 := 0.34 + rng.randf() * 0.1
		parts.tube(
			Vector3(YARD_X + 0.05, YARD_Y - 0.28, z0),
			Vector3(YARD_X + 0.05, YARD_Y - 0.3, z1),
			r0,
			r1,
			8,
			Color(0.84, 0.8, 0.7)
		)


## Stern rudder on the raked sternpost (gudgeons attested on Lootsi). Returns the
## pivot at the post; the "Rudder" child yaws about the post axis and carries the
## blade and the tiller that enters the stern cabin.
static func rudder_pivot_position() -> Vector3:
	var y := CogHull.KEEL_Y - 0.4
	return Vector3(CogHull.x_aft(y) - 0.2, y, 0.0)


static func rudder_rake() -> float:
	return atan(CogHull.STERN_RAKE)


static func add_rudder(timber: CogParts, iron: CogParts, tiller: CogParts) -> void:
	# Blade: three vertical planks on the aft side of the post axis (local -X).
	for k in 3:
		var x := -0.14 - 0.32 * k
		timber.box(
			Vector3(x - 0.04, 3.15, 0),
			Vector3(0.3, 6.4 - 0.25 * k, 0.12),
			CogInterior.OAK * (0.92 + 0.05 * k)
		)
	for l: float in CogRig.pintle_heights():
		iron.box(Vector3(-0.5, l, 0), Vector3(1.0, 0.1, 0.16), IRON)
		iron.tube(Vector3(0.0, l - 0.16, 0), Vector3(0.0, l + 0.16, 0), 0.04, 0.04, 6, IRON)
	# Tiller in its own frame (the Tiller node undoes the post rake).
	tiller.box(Vector3(1.6, 0.0, 0), Vector3(3.8, 0.13, 0.15), CogInterior.DARK)
	tiller.box(Vector3(3.5, 0.18, 0), Vector3(0.14, 0.4, 0.14), CogInterior.DARK)


static func pintle_heights() -> Array[float]:
	return [0.9, 2.4, 3.9, 5.4]
