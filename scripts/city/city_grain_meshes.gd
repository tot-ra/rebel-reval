class_name CityGrainMeshes
extends RefCounted

## Procedural cereal clumps for the strip fields round Reval (R-2112, FLORA-1):
## winter rye, bread wheat, six-row barley and oats, each a clump of curved
## stalks with nodes, leaf blades and its own ear, so the four crops read apart
## by silhouette: rye tall with a slim bearded spike that nods when ripe, wheat
## shorter with a plump beardless ear held upright, barley short with a long
## brush of awns that hangs over at harvest, oats with an open panicle of
## drooping spikelets. Built once from fixed seeds and cached; CityFarmland
## scatters them with MultiMesh. Original geometry only.
##
## Stages follow the field calendar (CityFarmland.grain_stage):
##   leafy    tillers of leaf blades before heading (the April winter grain)
##   headed   green stalks and green ears
##   ripe     straw stalks, gold ears, barley and rye heads nodding
##   stubble  short cut straw after the harvest
## Every model has a near variant (the ring round the player) and a light far
## variant (the mid tier, planted at half density, so it is drawn wider).
##
## Vertex contract, read by city_grain.gdshader (CityForbMeshes.Builder):
##   COLOR.rgb  albedo (sRGB in, stored linear), COLOR.a  light transmitted
##   UV.x       flex: 0 rigid at the root .. 1 free at the top of the stalk
##   UV.y       ear weight: 1 on ears, awns and panicles, which trail the stalk
##              in a gust; 0 on stalks and leaves

const ForbMeshes := preload("res://scripts/city/city_forb_meshes.gd")
const SHADER := preload("res://scripts/city/city_grain.gdshader")
const WindMaterials := preload("res://scripts/map/view3d/map_view_wind_materials.gd")

const CROP_RYE := &"rye"
const CROP_WHEAT := &"wheat"
const CROP_BARLEY := &"barley"
const CROP_OAT := &"oat"
const ALL_CROPS: Array[StringName] = [CROP_RYE, CROP_WHEAT, CROP_BARLEY, CROP_OAT]

const STAGE_LEAFY := &"leafy"
const STAGE_HEADED := &"headed"
const STAGE_RIPE := &"ripe"
const STAGE_STUBBLE := &"stubble"
const ALL_STAGES: Array[StringName] = [STAGE_LEAFY, STAGE_HEADED, STAGE_RIPE, STAGE_STUBBLE]

## Triangle caps per clump, checked by tests: the grain layer budget is 250,000
## triangles per camera (docs/SYSTEMS/VEGETATION_ENGINEERING.md).
const NEAR_TRI_BUDGET := 240
const FAR_TRI_BUDGET := 24

## Fade of the mid tier, in metres on the ground from the player (lod_focus),
## so the light clumps are gone before the farmland cell selection drops them.
const MID_FADE := Vector2(36.0, 44.0)

## Per crop: stalks per clump, ripe height (m; medieval landraces stood taller
## than modern cultivars, rye tallest), clump spread radius (m), ear length,
## ear radius, awn length (0 = beardless), awns per ear side, ripe nod (radians
## the ear bends from the stalk at harvest), green and ripe ear colours.
const PROFILES := {
	&"rye": {
		"stalks": 4, "height": 1.55, "spread": 0.07, "ear": 0.11, "ear_r": 0.0055,
		"awn": 0.035, "awns": 3, "nod": 0.55, "flat": 0.6,
		"ear_green": Color(0.47, 0.56, 0.42), "ear_ripe": Color(0.66, 0.57, 0.40),
		"leaf": Color(0.33, 0.47, 0.32),
	},
	&"wheat": {
		"stalks": 4, "height": 1.15, "spread": 0.06, "ear": 0.085, "ear_r": 0.0095,
		"awn": 0.0, "awns": 0, "nod": 0.12, "flat": 0.8,
		"ear_green": Color(0.44, 0.56, 0.26), "ear_ripe": Color(0.84, 0.66, 0.32),
		"leaf": Color(0.31, 0.48, 0.18),
	},
	&"barley": {
		"stalks": 3, "height": 0.85, "spread": 0.06, "ear": 0.065, "ear_r": 0.0085,
		"awn": 0.12, "awns": 3, "nod": 2.0, "flat": 1.0,
		"ear_green": Color(0.50, 0.60, 0.32), "ear_ripe": Color(0.86, 0.74, 0.46),
		"leaf": Color(0.34, 0.50, 0.22),
	},
	&"oat": {
		"stalks": 3, "height": 1.05, "spread": 0.07, "ear": 0.18, "ear_r": 0.0,
		"awn": 0.0, "awns": 0, "nod": 0.35, "flat": 1.0,
		"ear_green": Color(0.52, 0.62, 0.36), "ear_ripe": Color(0.76, 0.68, 0.46),
		"leaf": Color(0.32, 0.49, 0.22),
	},
}
# sRGB swatches from field photographs.
const STALK_GREEN := Color(0.40, 0.53, 0.25)
const NODE_GREEN := Color(0.30, 0.42, 0.18)
const STRAW := Color(0.70, 0.58, 0.34)
const STRAW_NODE := Color(0.60, 0.48, 0.28)
const DEAD_LEAF := Color(0.60, 0.50, 0.31)
const STUBBLE_STRAW := Color(0.66, 0.56, 0.36)
const LEAFY_HEIGHT := 0.45
const STUBBLE_HEIGHT := 0.16

static var _cache: Dictionary = {}
static var _materials: Dictionary = {}


static func mesh_for(crop: StringName, stage: StringName, far: bool = false) -> ArrayMesh:
	var key := "%s:%s:%s" % [crop, stage, "far" if far else "near"]
	if _cache.has(key):
		return _cache[key]
	var profile: Dictionary = PROFILES.get(crop, PROFILES[CROP_RYE])
	var b := ForbMeshes.Builder.new()
	var rng := RandomNumberGenerator.new()
	# One seed per crop: every stage and both variants are the same plants.
	rng.seed = 1343 + hash(String(crop))
	match stage:
		STAGE_LEAFY:
			_leafy(b, rng, profile, far)
		STAGE_STUBBLE:
			_stubble(b, rng, profile, far)
		_:
			_clump(b, rng, crop, profile, stage == STAGE_RIPE, far)
	var mesh := b.commit()
	_cache[key] = mesh
	return mesh


static func triangle_count(crop: StringName, stage: StringName, far: bool = false) -> int:
	return mesh_for(crop, stage, far).surface_get_array_index_len(0) / 3


## Shared material per tier. Both bend round the player and press along the
## R-1327 footfall trail (registered with MapViewWindMaterials); the far tier
## also shrinks away between MID_FADE metres from the player.
static func material(far: bool) -> ShaderMaterial:
	var key := "far" if far else "near"
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("trail", WindMaterials.empty_trail())
	if far:
		m.set_shader_parameter("fade_start", MID_FADE.x)
		m.set_shader_parameter("fade_end", MID_FADE.y)
	WindMaterials.register_interaction_material(m)
	_materials[key] = m
	return m


# --- Headed and ripe clumps ---------------------------------------------------


static func _clump(
	b: ForbMeshes.Builder, rng: RandomNumberGenerator, crop: StringName, profile: Dictionary,
	ripe: bool, far: bool
) -> void:
	var count: int = profile["stalks"]
	var height: float = profile["height"]
	var spread: float = profile["spread"] * (1.5 if far else 1.0)
	for i in count:
		var yaw := TAU * (float(i) + rng.randf_range(0.0, 0.7)) / float(count)
		var out := Vector3(cos(yaw), 0.0, sin(yaw))
		var base := out * spread * rng.randf_range(0.3, 1.0)
		var h := height * rng.randf_range(0.86, 1.06)
		# Stalks lean out of the clump; ripe heads add their own nod.
		var lean := rng.randf_range(0.04, 0.12) * h
		var pts := _stalk_path(base, out, h, lean, 3 if not far else 1)
		var stalk_c := STRAW if ripe else STALK_GREEN
		var node_c := STRAW_NODE if ripe else NODE_GREEN
		var ear_rng := ForbMeshes._child_rng(rng)
		var leaf_rng := ForbMeshes._child_rng(rng)
		if far:
			# Far stalks and heads are drawn several times their real width: past
			# ten metres (and from the gameplay camera) true 4 mm straws are
			# sub-pixel and the field would read as bare soil.
			_ribbon(b, pts, PackedFloat32Array([0.011, 0.007]), out, stalk_c, 0.0)
		else:
			_tube(b, pts, 0.0032, 0.002, 3, stalk_c, node_c)
			# A leaf at a lower node: green while growing, dry and limp when ripe.
			var leaf_yaw := yaw + PI * 0.6 * (1.0 if i % 2 == 0 else -1.0) + leaf_rng.randf_range(-0.4, 0.4)
			var leaf_c: Color = DEAD_LEAF if ripe else profile["leaf"]
			_blade(b, pts[1], leaf_yaw, leaf_rng.randf_range(0.16, 0.24), 0.007,
				leaf_rng.randf_range(0.5, 0.9), 1.6 if ripe else 1.1, leaf_c, 0.33, 3)
		var top := pts[pts.size() - 1]
		var axis := (top - pts[pts.size() - 2]).normalized()
		var nod: float = float(profile["nod"]) * (1.0 if ripe else 0.15) * ear_rng.randf_range(0.8, 1.15)
		var ear_c: Color = profile["ear_ripe"] if ripe else profile["ear_green"]
		if crop == CROP_OAT:
			_panicle(b, ear_rng, top, axis, out, profile, nod, ear_c, far)
		else:
			_spike(b, ear_rng, top, axis, out, profile, nod, ear_c, far)


## Points of a stalk from `base`: up `h`, bowing out along `out` by `lean` at
## the top (a quadratic arc, so the lower stalk stays near vertical).
static func _stalk_path(
	base: Vector3, out: Vector3, h: float, lean: float, segments: int
) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for k in segments + 1:
		var t := float(k) / float(segments)
		pts.append(base + Vector3.UP * h * t + out * lean * t * t)
	return pts


## A spike ear (rye, wheat, barley): a spindle of `ear` length on a curved axis
## that bends `nod` radians toward `out`, its spikelets as alternating bulges,
## with awns along it when the crop is bearded.
static func _spike(
	b: ForbMeshes.Builder, rng: RandomNumberGenerator, top: Vector3, axis: Vector3,
	out: Vector3, profile: Dictionary, nod: float, color: Color, far: bool
) -> void:
	var length: float = profile["ear"]
	var radius: float = profile["ear_r"]
	var flat: float = profile["flat"]
	var rows := 2 if far else 3
	# Ear axis: starts along the stalk and turns toward the lean (`out`) as the
	# head nods. A hanging barley head turns most of the way on a short arched
	# neck above the last node, so the ear itself hangs nearly straight down.
	var bend_axis := axis.cross(out).normalized()
	if bend_axis.length_squared() < 0.5:
		bend_axis = Vector3.RIGHT
	var neck := 0.03 if nod > 1.0 else 0.0
	var neck_turn := nod * 0.7 if neck > 0.0 else 0.0
	var p := top
	# The far card has no neck tube, so its ear starts on the stalk top.
	if neck > 0.0 and not far:
		var neck_pts := PackedVector3Array([top])
		# One straight segment at half the turn; the ear carries on bending.
		p += axis.rotated(bend_axis, neck_turn * 0.5) * neck
		neck_pts.append(p)
		_tube(b, neck_pts, 0.0018, 0.0016, 3, color.darkened(0.15), color.darkened(0.15), 1.0)
	var spine := PackedVector3Array([p])
	var dirs: Array[Vector3] = [axis.rotated(bend_axis, neck_turn)]
	for k in rows:
		var t := float(k + 1) / float(rows)
		var d := axis.rotated(bend_axis, lerpf(neck_turn, nod, t))
		p += d * length / float(rows)
		spine.append(p)
		dirs.append(d)
	var start_dir: Vector3 = dirs[0]
	if far:
		# A crossed pair of diamond cards reads as the ear past ten metres.
		# One diamond card per ear, turned with the stalk's yaw (clumps are
		# yawed at random, so the field shows every angle).
		var w := out.cross(start_dir).normalized() * radius * 3.5
		var a := b.vertex(spine[0], color, 1.0, 1.0, 0.3)
		var m1 := b.vertex(spine[1] - w, color, 1.0, 1.0, 0.3)
		var m2 := b.vertex(spine[1] + w, color, 1.0, 1.0, 0.3)
		var tip := b.vertex(spine[2], color.lightened(0.05), 1.0, 1.0, 0.3)
		b.quad(a, m1, tip, m2, out)
		# Only barley's long brush shows past ten metres; rye's short awns do not.
		if float(profile["awn"]) > 0.06:
			var awn_tip: Vector3 = spine[2] + dirs[2] * float(profile["awn"]) * 0.8
			var aw := out.cross(dirs[2]).normalized() * radius * 4.0
			var a0 := b.vertex(spine[1] - aw * 0.5, color, 1.0, 1.0, 0.5)
			var a1 := b.vertex(spine[1] + aw * 0.5, color, 1.0, 1.0, 0.5)
			var a2 := b.vertex(awn_tip + aw, color.lightened(0.1), 1.0, 1.0, 0.5)
			var a3 := b.vertex(awn_tip - aw, color.lightened(0.1), 1.0, 1.0, 0.5)
			b.quad(a0, a1, a2, a3, out)
		return
	# Spindle: four sides, flattened across the two spikelet rows; radius swells
	# mid-ear and alternates per row so the spikelets read as steps.
	var sides := 4
	var ring_prev: Array[int] = []
	var dirs_prev: Array[Vector3] = []
	for k in spine.size():
		var t := float(k) / float(spine.size() - 1)
		var d: Vector3 = dirs[k]
		var u := d.cross(bend_axis).normalized()
		var v := bend_axis
		var swell := sin(PI * (0.15 + 0.85 * t)) * (1.0 + 0.18 * float(k % 2))
		var r := radius * maxf(swell, 0.25)
		if k == spine.size() - 1:
			r *= 0.35
		var ring: Array[int] = []
		var ring_dirs: Array[Vector3] = []
		for s in sides:
			var a := TAU * float(s) / float(sides) + 0.25 * PI
			var radial := u * cos(a) + v * sin(a) * flat
			var c := color.darkened(0.12 * (1.0 - t)) if s % 2 == 0 else color.lightened(0.04)
			ring.append(b.vertex(spine[k] + radial * r, c, 1.0, 1.0, 0.35))
			ring_dirs.append(radial)
		if not ring_prev.is_empty():
			for s in sides:
				var n := (s + 1) % sides
				b.quad(ring_prev[s], ring_prev[n], ring[n], ring[s], dirs_prev[s] + ring_dirs[n])
		ring_prev = ring
		dirs_prev = ring_dirs
	var awn: float = profile["awn"]
	var per_side: int = profile["awns"]
	if awn <= 0.0:
		return
	# Awns leave both spikelet rows and run along the ear, splaying slightly; on
	# barley they are as long again as the ear and make the brush.
	for s: float in [-1.0, 1.0]:
		for k in per_side:
			var t := (float(k) + 0.5) / float(per_side)
			var at := spine[0].lerp(spine[spine.size() - 1], t)
			var d: Vector3 = dirs[mini(int(t * float(dirs.size() - 1)) + 1, dirs.size() - 1)]
			var splay := d.rotated(d.cross(bend_axis).normalized(), s * rng.randf_range(0.12, 0.3))
			var tip := at + splay * awn * rng.randf_range(0.8, 1.1) + bend_axis * s * radius
			# Rye's short awns are one straight segment; barley's long ones arch.
			var strip: Array = [at + bend_axis * s * radius * 0.6, tip]
			if awn > 0.06:
				strip.insert(1, (strip[0] + tip) * 0.5)
			_blade_strip(b, strip, 0.0007, color.lightened(0.08), out)


## Oat panicle: the axis carries on above the last node in whorls of slender
## branches; each branch arches out and hangs two spikelets like small lanterns.
static func _panicle(
	b: ForbMeshes.Builder, rng: RandomNumberGenerator, top: Vector3, axis: Vector3,
	out: Vector3, profile: Dictionary, nod: float, color: Color, far: bool
) -> void:
	var length: float = profile["ear"]
	var bend_axis := axis.cross(out).normalized()
	if bend_axis.length_squared() < 0.5:
		bend_axis = Vector3.RIGHT
	var tip := top + axis.rotated(bend_axis, -nod) * length
	var whorls := 1 if far else 3
	if not far:
		_tube(b, PackedVector3Array([top, tip]), 0.0015, 0.0008, 3,
			color.darkened(0.2), color.darkened(0.2), 1.0)
	for w in whorls:
		var t := float(w) / float(whorls)
		var at := top.lerp(tip, t * 0.85)
		var branches := 3 if w == 0 else 2
		for k in branches:
			var yaw := TAU * (float(k) + rng.randf()) / float(branches) + float(w) * 1.3
			var dir := Vector3(cos(yaw), 0.0, sin(yaw))
			var reach := lerpf(0.07, 0.03, t) * rng.randf_range(0.8, 1.2)
			var mid := at + dir * reach * 0.6 + Vector3.UP * reach * 0.25
			var end := at + dir * reach - Vector3.UP * reach * 0.35
			if far:
				_blade_strip(b, [at, end], 0.014, color, dir.cross(Vector3.UP))
				continue
			_blade_strip(b, [at, mid, end] if w == 0 else [at, end], 0.0008, color.darkened(0.15),
				dir.cross(Vector3.UP))
			# Spikelets: a pair of glumes hanging from the branch end, open below.
			for g in 2:
				var hang := end + dir * 0.008 * float(g) - Vector3.UP * 0.004 * float(g)
				var low := hang - Vector3.UP * 0.022 + dir * 0.004
				# The two glumes of a pair hang crosswise, so the lantern reads from any side.
				var side := (dir if g == 1 else dir.cross(Vector3.UP)).normalized() * 0.0055
				var c := color.lightened(0.06 * float(g))
				var a := b.vertex(hang, c, 1.0, 1.0, 0.45)
				var l := b.vertex(hang.lerp(low, 0.55) - side, c, 1.0, 1.0, 0.45)
				var r := b.vertex(hang.lerp(low, 0.55) + side, c, 1.0, 1.0, 0.45)
				var bottom := b.vertex(low, c.lightened(0.05), 1.0, 1.0, 0.45)
				b.quad(a, l, bottom, r, dir)


# --- Leafy tillers and stubble ------------------------------------------------


## Before heading: a tuft of arching blades from one crown, outer ones lower.
static func _leafy(
	b: ForbMeshes.Builder, rng: RandomNumberGenerator, profile: Dictionary, far: bool
) -> void:
	var count := 4 if far else 9
	var leaf_c: Color = profile["leaf"]
	for i in count:
		var yaw := TAU * (float(i) + rng.randf_range(0.0, 0.8)) / float(count)
		var base := Vector3(cos(yaw), 0.0, sin(yaw)) * rng.randf_range(0.0, 0.025)
		var length := LEAFY_HEIGHT * rng.randf_range(0.6, 1.0) * (1.15 if far else 1.0)
		var rise := rng.randf_range(1.2, 1.45)
		var tone := rng.randf_range(0.9, 1.08)
		_blade(b, base, yaw, length, 0.008 * (1.6 if far else 1.0), rise, rng.randf_range(0.4, 0.8),
			Color(leaf_c.r * tone, leaf_c.g * tone, leaf_c.b * tone), 0.0, 2 if far else 3)


## After the harvest: a ring of cut straw stems a hand high, a few laid over.
static func _stubble(
	b: ForbMeshes.Builder, rng: RandomNumberGenerator, profile: Dictionary, far: bool
) -> void:
	var count: int = int(profile["stalks"]) + (1 if far else 2)
	for i in count:
		var yaw := TAU * (float(i) + rng.randf()) / float(count)
		var out := Vector3(cos(yaw), 0.0, sin(yaw))
		var base := out * float(profile["spread"]) * rng.randf_range(0.2, 1.0)
		var h := STUBBLE_HEIGHT * rng.randf_range(0.7, 1.15)
		var pts := _stalk_path(base, out, h, h * rng.randf_range(0.05, 0.25), 1)
		if far:
			_ribbon(b, pts, PackedFloat32Array([0.008, 0.006]), out, STUBBLE_STRAW, 0.0)
		else:
			_tube(b, pts, 0.0032, 0.003, 3, STUBBLE_STRAW, STUBBLE_STRAW.darkened(0.1), 0.0, 0.2)


# --- Geometry helpers -----------------------------------------------------------


## Stalk tube along `pts` with `sides` faces; nodes are darker bands at every
## other ring. `ear` is the UV.y ear weight; flex runs from flex0 at the root.
static func _tube(
	b: ForbMeshes.Builder, pts: PackedVector3Array, r0: float, r1: float, sides: int,
	color: Color, node: Color, ear: float = 0.0, flex0: float = 0.0
) -> void:
	var prev: Array[int] = []
	var prev_dirs: Array[Vector3] = []
	var count := pts.size()
	for i in count:
		var t := float(i) / float(count - 1)
		var tangent := (pts[mini(i + 1, count - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var frame := ForbMeshes._frame(tangent)
		var c := node if i > 0 and i < count - 1 and i % 2 == 1 else color
		var ring: Array[int] = []
		var dirs: Array[Vector3] = []
		for k in sides:
			var a := TAU * float(k) / float(sides)
			var radial: Vector3 = frame[0] * cos(a) + frame[1] * sin(a)
			# Ear parts (barley necks) bend as a whole with the head.
			var flex := 1.0 if ear >= 0.5 else lerpf(flex0, 1.0, t)
			ring.append(b.vertex(pts[i] + radial * lerpf(r0, r1, t), c, flex, ear, 0.25))
			dirs.append(radial)
		if not prev.is_empty():
			for k in sides:
				var n := (k + 1) % sides
				b.quad(prev[k], prev[n], ring[n], ring[k], prev_dirs[k] + dirs[n])
		prev = ring
		prev_dirs = dirs


## A flat strip along `pts` (far stalks), widths per point, facing `facing`.
static func _ribbon(
	b: ForbMeshes.Builder, pts: PackedVector3Array, widths: PackedFloat32Array,
	facing: Vector3, color: Color, ear: float
) -> void:
	var prev := PackedInt32Array()
	for i in pts.size():
		var t := float(i) / float(pts.size() - 1)
		var w := widths[mini(i, widths.size() - 1)]
		var tangent := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var side := tangent.cross(facing).normalized()
		var row := PackedInt32Array([
			b.vertex(pts[i] - side * w, color.darkened(0.1 * (1.0 - t)), t, ear, 0.25),
			b.vertex(pts[i] + side * w, color.darkened(0.1 * (1.0 - t)), t, ear, 0.25),
		])
		if not prev.is_empty():
			b.quad(prev[0], prev[1], row[1], row[0], facing)
		prev = row


## A thin ear-weighted strip (awns, panicle branches) through three points.
static func _blade_strip(
	b: ForbMeshes.Builder, pts: Array, half_width: float, color: Color, facing: Vector3
) -> void:
	var prev := PackedInt32Array()
	for i in pts.size():
		var p: Vector3 = pts[i]
		var ahead: Vector3 = pts[mini(i + 1, pts.size() - 1)]
		var behind: Vector3 = pts[maxi(i - 1, 0)]
		var side := (ahead - behind).normalized().cross(facing)
		if side.length_squared() < 0.0001:
			side = ForbMeshes._frame((ahead - behind).normalized())[0]
		side = side.normalized() * half_width * (1.0 - 0.5 * float(i) / float(pts.size() - 1))
		var row := PackedInt32Array([
			b.vertex(p - side, color, 1.0, 1.0, 0.5), b.vertex(p + side, color, 1.0, 1.0, 0.5)
		])
		if not prev.is_empty():
			b.quad(prev[0], prev[1], row[1], row[0], facing)
		prev = row


## A grass-type leaf blade from `at`: rises at `rise` radians, loses `droop`
## radians by the tip, tapers to a point; V-folded along the midrib.
static func _blade(
	b: ForbMeshes.Builder, at: Vector3, yaw: float, length: float, half_width: float,
	rise: float, droop: float, color: Color, flex0: float, segments: int
) -> void:
	var fwd_h := Vector3(cos(yaw), 0.0, sin(yaw))
	var side := Vector3(-sin(yaw), 0.0, cos(yaw))
	var p := at
	var prev := PackedInt32Array()
	for k in segments + 1:
		var t := float(k) / float(segments)
		var pitch := rise - droop * t
		var fwd := fwd_h * cos(pitch) + Vector3.UP * sin(pitch)
		if k > 0:
			p += fwd * length / float(segments)
		var w := half_width * (1.0 - t * t) + 0.0004
		var up := side.cross(fwd)
		var c := color.darkened(0.15 * (1.0 - t))
		var flex := lerpf(flex0, 1.0, t)
		var row := PackedInt32Array([
			b.vertex(p - side * w + up * w * 0.3, c, flex, 0.0, 0.4),
			b.vertex(p + side * w + up * w * 0.3, c, flex, 0.0, 0.4),
		])
		if not prev.is_empty():
			b.quad(prev[0], prev[1], row[1], row[0], up)
		prev = row
