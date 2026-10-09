class_name CityForbMeshes
extends RefCounted

## Detailed procedural models of the commonest wayside and meadow forbs round
## Reval: dandelion, broadleaf plantain, white and red clover, burdock (R-1519).
## Each plant is built once from botanical proportions and cached; CityForbs
## scatters them with MultiMesh. Original geometry only, deterministic (fixed
## seed per kind).
##
## Vertex data contract, read by city_forb.gdshader:
##   COLOR.rgb  albedo (linear), COLOR.a  light transmitted through the part
##   UV.x       flex: 0 rigid at the root .. 1 (or more on tall stems) free tip
##   UV.y       underside paleness shown on the back face (burdock's grey wool)
## Leaves are wound so their front face is the upper side.
##
## Every kind also has a far variant (mesh_for(kind, true)) for beyond ~12 m:
## the same plant from the same random draws, with thinned grids and heads
## reduced to simple volumes, at a fifth to a tenth of the triangles.

const MeshMath := preload("res://scripts/map/view3d/map_view_mesh_builder_math.gd")

const KIND_DANDELION_FLOWER := &"dandelion_flower"
const KIND_DANDELION_CLOCK := &"dandelion_clock"
const KIND_DANDELION_LEAVES := &"dandelion_leaves"
const KIND_PLANTAIN := &"plantain"
const KIND_WHITE_CLOVER := &"white_clover"
const KIND_RED_CLOVER := &"red_clover"
const KIND_BURDOCK := &"burdock"
const KIND_BURDOCK_FLOWERING := &"burdock_flowering"

const ALL_KINDS: Array[StringName] = [
	KIND_DANDELION_FLOWER,
	KIND_DANDELION_CLOCK,
	KIND_DANDELION_LEAVES,
	KIND_PLANTAIN,
	KIND_WHITE_CLOVER,
	KIND_RED_CLOVER,
	KIND_BURDOCK,
	KIND_BURDOCK_FLOWERING,
]

# Colours are sRGB, picked from field photographs of each species.
const DANDELION_LEAF := Color(0.29, 0.47, 0.16)
const DANDELION_PETIOLE := Color(0.58, 0.42, 0.38)
# Kept below full brightness and a little lemony: the city's AgX tonemapper and
# warm grade bleach a bright saturated yellow to peach or push it to orange.
const DANDELION_YELLOW := Color(0.86, 0.75, 0.03)
const DANDELION_CORE := Color(0.84, 0.60, 0.02)
const BRACT_GREEN := Color(0.34, 0.48, 0.20)
const PAPPUS_WHITE := Color(0.93, 0.93, 0.89)
const PLANTAIN_LEAF := Color(0.27, 0.45, 0.15)
const PLANTAIN_VEIN := Color(0.52, 0.62, 0.34)
const PLANTAIN_SPIKE := Color(0.50, 0.50, 0.30)
const PLANTAIN_ANTHER := Color(0.48, 0.36, 0.42)
const CLOVER_LEAF := Color(0.25, 0.45, 0.17)
const CLOVER_WHITE := Color(0.94, 0.93, 0.86)
const CLOVER_FADED := Color(0.62, 0.55, 0.44)
const RED_CLOVER_LEAF := Color(0.30, 0.48, 0.20)
const RED_CLOVER_HEAD := Color(0.80, 0.32, 0.56)
const BURDOCK_LEAF := Color(0.25, 0.41, 0.15)
const BURDOCK_PETIOLE := Color(0.50, 0.30, 0.26)
const BURDOCK_STEM := Color(0.42, 0.34, 0.24)
const BURR_GREEN := Color(0.50, 0.56, 0.30)
const BURR_PURPLE := Color(0.62, 0.20, 0.50)

## Leaf-detail atlas tiles (tools/assets/generate_forb_leaf_atlas.py, 4 x 2).
## Strip tiles: u across the blade, v base to tip. Burdock: polar, petiole at
## the tile centre, midrib toward +v.
const TILE_DANDELION := 0
const TILE_PLANTAIN := 1
const TILE_WHITE_CLOVER := 2
const TILE_RED_CLOVER := 3
const TILE_BURDOCK := 4
const NEUTRAL_UV := Vector2(0.375, 0.75)
## Fraction of a tile kept clear at its border so mipmaps do not bleed tiles.
const TILE_INSET := 0.03

static var _cache: Dictionary = {}
## Set only while a far variant is being built; the geometry helpers read it.
static var _far := false


static func mesh_for(kind: StringName, far: bool = false) -> ArrayMesh:
	var key := "%s:%s" % [kind, "far" if far else "near"]
	if _cache.has(key):
		return _cache[key]
	_far = far
	var b := Builder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1343 + hash(String(kind))
	match kind:
		KIND_DANDELION_FLOWER:
			_dandelion(b, rng, 2, 0, 1)
		KIND_DANDELION_CLOCK:
			_dandelion(b, rng, 1, 1, 0)
		KIND_DANDELION_LEAVES:
			_dandelion(b, rng, 0, 0, 0)
		KIND_PLANTAIN:
			_plantain(b, rng)
		KIND_WHITE_CLOVER:
			_white_clover(b, rng)
		KIND_RED_CLOVER:
			_red_clover(b, rng)
		KIND_BURDOCK:
			_burdock(b, rng, false)
		KIND_BURDOCK_FLOWERING:
			_burdock(b, rng, true)
		_:
			push_error("CityForbMeshes: unknown kind %s" % kind)
	_far = false
	var mesh := b.commit()
	_cache[key] = mesh
	return mesh


static func triangle_count(kind: StringName, far: bool = false) -> int:
	return mesh_for(kind, far).surface_get_array_index_len(0) / 3


## Child generator for an optional part (heads, burrs), so skipping the part in
## the far variant does not shift the random draws of the rest of the plant.
static func _child_rng(rng: RandomNumberGenerator) -> RandomNumberGenerator:
	var child := RandomNumberGenerator.new()
	child.seed = rng.randi()
	return child


# --- Dandelion (Taraxacum officinale) ---------------------------------------
# A flat rosette of runcinate leaves (backward-hooked lobes, pale midrib, a
# purplish winged petiole), hollow leafless scapes, composite heads of strap
# florets in rings over reflexed green bracts, closed buds and seed clocks.


static func _dandelion(
	b: Builder, rng: RandomNumberGenerator, flowers: int, clocks: int, buds: int
) -> void:
	var leaf_count := rng.randi_range(8, 11)
	for i in leaf_count:
		var yaw := TAU * float(i) / float(leaf_count) + rng.randf_range(-0.25, 0.25)
		var length := rng.randf_range(0.13, 0.24)
		var half_w := length * rng.randf_range(0.13, 0.18)
		var lobes := rng.randi_range(3, 6)
		var lobe_seed := rng.randi() % 997
		var tone := rng.randf_range(0.88, 1.08)
		# Rosettes mix deeply cut and nearly entire leaves (young, shaded ones).
		var cut := rng.randf_range(0.35, 1.0) if rng.randf() < 0.75 else rng.randf_range(0.1, 0.3)
		var samples := _runcinate_samples(lobes)
		_strip_leaf(b, {
			"base": Vector3(cos(yaw), 0.0, sin(yaw)) * 0.008 + Vector3.UP * 0.004,
			"yaw": yaw,
			"rise": rng.randf_range(0.18, 0.55),
			"droop": rng.randf_range(0.25, 0.6),
			"length": length,
			"samples": samples,
			"cols": 3,
			"fold": 0.18,
			"width": func(t: float) -> float: return half_w * _runcinate_width(t, lobes, lobe_seed, cut),
			# The lobe tip hooks back toward the base: shift the margin backward there.
			"shift": func(t: float, s: float) -> float:
				return -absf(s) * length * 0.09 * cut * _runcinate_hook(t, lobes),
			# Midrib and laterals come from the detail atlas; the vertex colour
			# keeps the purplish petiole and a paler, yellower base.
			"color": func(t: float, s: float) -> Color:
				var c := DANDELION_LEAF * tone
				c = c.lerp(DANDELION_PETIOLE, (1.0 - smoothstep(0.0, 0.22, t)) * 0.7)
				if absf(s) < 0.01:
					c = c.lerp(DANDELION_PETIOLE, 0.35 * (1.0 - smoothstep(0.1, 0.5, t)))
				return c.darkened(absf(s) * 0.06),
			"tile": TILE_DANDELION,
			"flex": Vector2(0.0, 0.18),
			"under": 0.35,
			"trans": 0.35,
		})
	var scape_total := flowers + clocks + buds
	for i in scape_total:
		var yaw := TAU * (float(i) + rng.randf()) / float(maxi(scape_total, 1))
		var height := rng.randf_range(0.17, 0.30)
		var lean := rng.randf_range(0.03, 0.08)
		var bend := Vector3(cos(yaw), 0.0, sin(yaw))
		var pts := PackedVector3Array()
		var radii := PackedFloat32Array()
		for k in 7:
			var t := float(k) / 6.0
			# Scapes leave the rosette sideways, then turn up toward the light.
			pts.append(bend * (0.012 + lean * sin(t * PI * 0.5)) + Vector3.UP * height * t)
			radii.append(lerpf(0.0026, 0.0019, t))
		_tube(b, pts, radii, 5, func(t: float) -> Color:
			return Color(0.56, 0.62, 0.38).lerp(Color(0.62, 0.42, 0.40), 1.0 - smoothstep(0.0, 0.3, t)),
			0.0, 1.0, 0.25)
		var top := pts[6]
		var axis := (pts[6] - pts[5]).normalized()
		var head_rng := _child_rng(rng)
		if _far:
			# A yellow disc, a white ball or a green spindle reads the same past 12 m.
			var head: Array = [Vector3(0.017, 0.006, 0.017), DANDELION_YELLOW]
			if i >= flowers + clocks:
				head = [Vector3(0.004, 0.009, 0.004), BRACT_GREEN]
			elif i >= flowers:
				head = [Vector3(0.017, 0.017, 0.017), PAPPUS_WHITE]
			_blob(b, top + axis * 0.006, head[0], 3, 6, func(_d: Vector3) -> Color: return head[1],
				0.0, 1.0, 0.5)
		elif i < flowers:
			_dandelion_head(b, head_rng, top, axis)
		elif i < flowers + clocks:
			_dandelion_clock(b, head_rng, top, axis)
		else:
			_dandelion_bud(b, top, axis)


## Row positions along a runcinate leaf: three rows per lobe (sinus, hooked tip,
## lobe back) so each tooth is resolved without a dense grid.
static func _runcinate_samples(lobes: int) -> PackedFloat32Array:
	var out := PackedFloat32Array([0.0, 0.09, 0.18])
	var span := 0.60 / float(lobes)
	for i in lobes:
		var start := 0.20 + span * float(i)
		out.append_array([start, start + span * 0.16, start + span * 0.6])
	out.append_array([0.80, 0.83, 0.92, 1.0])
	return out


static func _runcinate_width(t: float, lobes: int, lobe_seed: int, cut: float) -> float:
	if t < 0.20:
		# Winged petiole widening into the blade.
		return lerpf(0.18, 0.42, t / 0.20)
	if t >= 0.80:
		# Terminal lobe: a broad triangle.
		var u := (t - 0.80) / 0.20
		return 0.95 * pow(1.0 - u, 0.9) * smoothstep(-0.05, 0.15, u)
	var lobe_pos := (t - 0.20) / 0.60 * float(lobes)
	var f := fmod(lobe_pos, 1.0)
	# Narrow at the sinus, widest just above it, tapering back in. Lobes differ
	# in depth, as on a real leaf, and the sinus is never cut to the midrib.
	# `cut` scales the whole leaf from nearly entire (0.1) to cut almost to the
	# midrib (1.0); each lobe also differs in depth and size.
	var depth := lerpf(0.40, 0.85, MeshMath.hash01(int(lobe_pos), lobe_seed, 4507)) * cut
	var size := lerpf(0.8, 1.15, MeshMath.hash01(int(lobe_pos), lobe_seed, 4513))
	var tooth := smoothstep(0.0, 0.12, f) * pow(1.0 - f, 1.4) / pow(0.88, 1.4)
	return lerpf(1.0 - depth, size, clampf(tooth, 0.0, 1.0)) * lerpf(0.7, 1.0, (t - 0.2) / 0.6)


static func _runcinate_hook(t: float, lobes: int) -> float:
	if t < 0.20 or t > 0.84:
		return 0.0
	if t >= 0.80:
		return 1.0
	var f := fmod((t - 0.20) / 0.60 * float(lobes), 1.0)
	return smoothstep(0.08, 0.16, f) * (1.0 - smoothstep(0.2, 0.5, f))


static func _dandelion_head(
	b: Builder, rng: RandomNumberGenerator, top: Vector3, axis: Vector3
) -> void:
	var frame := _frame(axis)
	# Reflexed outer bracts curl down round the scape.
	for i in 10:
		var a := TAU * float(i) / 10.0 + rng.randf() * 0.2
		var radial: Vector3 = frame[0] * cos(a) + frame[1] * sin(a)
		var root := top - axis * 0.004 + radial * 0.003
		_ribbon(b, [root, root + radial * 0.005 - axis * 0.003, root + radial * 0.006 - axis * 0.007],
			0.0012, BRACT_GREEN.darkened(0.1), 1.0, 0.3, radial)
	# Inner bracts hug the underside of the head.
	for i in 12:
		var a := TAU * (float(i) + 0.5) / 12.0
		var radial: Vector3 = frame[0] * cos(a) + frame[1] * sin(a)
		var root := top - axis * 0.004 + radial * 0.002
		_ribbon(b, [root, root + radial * 0.005 + axis * 0.004, root + radial * 0.006 + axis * 0.008],
			0.0016, BRACT_GREEN, 1.0, 0.2, radial)
	# Strap florets in four rings, flat outside, upright and deeper orange inside.
	var rings := [
		[28, 0.10, 0.016, 0.0030],
		[26, 0.32, 0.014, 0.0030],
		[22, 0.58, 0.011, 0.0028],
		[16, 0.88, 0.008, 0.0026],
		[10, 1.20, 0.005, 0.0022],
	]
	var base := top + axis * 0.005
	for r in rings.size():
		var ring: Array = rings[r]
		var count: int = ring[0]
		for i in count:
			var a := TAU * (float(i) + rng.randf() * 0.4 + 0.5 * float(r)) / float(count)
			var radial: Vector3 = frame[0] * cos(a) + frame[1] * sin(a)
			var tilt: float = ring[1] + rng.randf_range(-0.1, 0.1)
			var length: float = ring[2] * rng.randf_range(0.85, 1.1)
			var dir := (radial * cos(tilt) + axis * sin(tilt)).normalized()
			var curl := (radial * cos(tilt + 0.35) + axis * sin(tilt + 0.35)).normalized()
			var root := base + radial * 0.0012 * float(5 - r)
			var mid := root + dir * length * 0.55
			var tip := mid + curl * length * 0.45
			var color := DANDELION_YELLOW.lerp(DANDELION_CORE, float(r) / 4.0 * 0.8)
			# Little transmission: a back-lit head otherwise washes out to cream.
			_ribbon(b, [root, mid, tip], ring[3], color, 1.0, 0.15, axis, 0.3)
	_blob(b, base + axis * 0.002, Vector3.ONE * 0.003, 3, 6, func(_d: Vector3) -> Color:
		return DANDELION_CORE.darkened(0.1), 0.2, 1.0, 0.3)


static func _dandelion_bud(b: Builder, top: Vector3, axis: Vector3) -> void:
	var frame := _frame(axis)
	for i in 9:
		var a := TAU * float(i) / 9.0
		var radial: Vector3 = frame[0] * cos(a) + frame[1] * sin(a)
		var root := top - axis * 0.002 + radial * 0.002
		_ribbon(b, [root, root + radial * 0.0045 + axis * 0.008,
			root + radial * 0.0015 + axis * 0.018], 0.0022, BRACT_GREEN.lightened(0.05),
			1.0, 0.2, radial)
	_blob(b, top + axis * 0.017, Vector3(0.0022, 0.0035, 0.0022), 3, 6, func(_d: Vector3) -> Color:
		return DANDELION_YELLOW, 0.0, 1.0, 0.3)


static func _dandelion_clock(
	b: Builder, rng: RandomNumberGenerator, top: Vector3, axis: Vector3
) -> void:
	var frame := _frame(axis)
	var centre := top + axis * 0.004
	_blob(b, centre, Vector3.ONE * 0.0035, 3, 6, func(_d: Vector3) -> Color:
		return Color(0.55, 0.45, 0.30), 0.1, 1.0, 0.1)
	# Withered bracts left hanging under the clock.
	for i in 8:
		var a := TAU * float(i) / 8.0
		var radial: Vector3 = frame[0] * cos(a) + frame[1] * sin(a)
		var root := top + radial * 0.002
		_ribbon(b, [root, root + radial * 0.004 - axis * 0.006, root + radial * 0.005 - axis * 0.012],
			0.0012, Color(0.40, 0.42, 0.22), 1.0, 0.2, radial)
	# Seeds on a Fibonacci sphere: a fine beak and a white pappus umbrella each.
	# A few already blown away leave the ball ragged.
	var seeds := 44
	for i in seeds:
		var y := 1.0 - 2.0 * (float(i) + 0.5) / float(seeds)
		if y < -0.55 or rng.randf() < 0.12:
			continue
		var ring_r := sqrt(1.0 - y * y)
		var phi := float(i) * 2.39996
		var around: Vector3 = frame[0] * (cos(phi) * ring_r) + frame[1] * (sin(phi) * ring_r)
		var dir: Vector3 = (axis * y + around).normalized()
		var beak_end := centre + dir * 0.016
		_ribbon(b, [centre + dir * 0.003, beak_end], 0.00035, Color(0.80, 0.78, 0.68), 1.0, 0.3, axis)
		var umbrella := _frame(dir)
		# The pappus is a ring of fine bristles, not a disc: thin slivers with gaps
		# between them, so the clock reads as a see-through ball of fluff.
		var hub := b.vertex(beak_end, PAPPUS_WHITE.darkened(0.1), 1.0, 0.0, 0.7)
		var turn := rng.randf() * TAU
		for k in 8:
			var a := turn + TAU * float(k) / 8.0
			var s0: Vector3 = umbrella[0] * cos(a) + umbrella[1] * sin(a)
			var s1: Vector3 = umbrella[0] * cos(a + 0.2) + umbrella[1] * sin(a + 0.2)
			var lift := dir * 0.0028
			b.tri(hub, b.vertex(beak_end + s0 * 0.0062 + lift, PAPPUS_WHITE, 1.0, 0.0, 0.8),
				b.vertex(beak_end + s1 * 0.0062 + lift, PAPPUS_WHITE, 1.0, 0.0, 0.8), dir)


# --- Broadleaf plantain (Plantago major) ------------------------------------
# A flat rosette of broad ovate leaves on channelled petioles with five strong
# parallel veins converging at base and tip, and erect pencil-thin spikes whose
# upper part is a dense column of brownish flowers with purple anthers.


static func _plantain(b: Builder, rng: RandomNumberGenerator) -> void:
	var leaf_count := rng.randi_range(6, 8)
	for i in leaf_count:
		var yaw := TAU * float(i) / float(leaf_count) + rng.randf_range(-0.3, 0.3)
		var length := rng.randf_range(0.12, 0.20)
		# Broad ovate blade: about two thirds as wide as it is long.
		var half_w := length * rng.randf_range(0.24, 0.30)
		var tone := rng.randf_range(0.9, 1.08)
		_strip_leaf(b, {
			"base": Vector3(cos(yaw), 0.0, sin(yaw)) * 0.006 + Vector3.UP * 0.004,
			"yaw": yaw,
			"rise": rng.randf_range(0.30, 0.75),
			"droop": rng.randf_range(0.55, 0.95),
			"length": length,
			"samples": PackedFloat32Array([0.0, 0.16, 0.32, 0.42, 0.55, 0.68, 0.80, 0.91, 1.0]),
			"cols": 7,
			"fold": 0.10,
			"width": func(t: float) -> float:
				if t < 0.32:
					return half_w * lerpf(0.10, 0.16, t / 0.32)
				var u := (t - 0.32) / 0.68
				return half_w * pow(sin(PI * pow(u, 0.8)), 0.7) + half_w * 0.08 * (1.0 - u),
			# Blade puckers up between the sunken veins.
			"ridge": func(t: float, s: float) -> float:
				var vein := absf(s) < 0.01 or absf(absf(s) - 0.6667) < 0.01
				return 0.0 if vein or absf(s) > 0.99 else half_w * 0.08 * sin(PI * t),
			# The ribs come from the detail atlas (same columns as the ridge).
			"color": func(t: float, s: float) -> Color:
				var c := PLANTAIN_LEAF * tone
				if t < 0.32:
					return c.lerp(PLANTAIN_VEIN, 0.6)
				return c.darkened(0.06 if absf(s) > 0.99 else 0.0),
			"flex": Vector2(0.0, 0.2),
			"under": 0.3,
			"trans": 0.3,
			"tile": TILE_PLANTAIN,
		})
	# Leafless scapes ending in a long, dense, pencil-thick spike: ripe brown
	# capsules below, a band of flowering with pale filaments and lilac anthers,
	# green buds at the blunt top.
	var spikes := rng.randi_range(3, 5)
	for i in spikes:
		var yaw := rng.randf() * TAU
		var height := rng.randf_range(0.15, 0.28)
		var lean := Vector3(cos(yaw), 0.0, sin(yaw)) * rng.randf_range(0.015, 0.045)
		var bare := height * rng.randf_range(0.30, 0.45)
		var pts := PackedVector3Array()
		var radii := PackedFloat32Array()
		for k in 4:
			var t := float(k) / 3.0
			var u := bare * t / height
			pts.append(lean * u * u + Vector3.UP * bare * t)
			radii.append(lerpf(0.0018, 0.0014, t))
		_tube(b, pts, radii, 4, func(_t: float) -> Color: return Color(0.46, 0.54, 0.30),
			0.0, 0.55, 0.2)
		var spike_pts := PackedVector3Array()
		var spike_r := PackedFloat32Array()
		var rows := 16
		for k in rows + 1:
			var t := float(k) / float(rows)
			var h := lerpf(bare, height, t)
			var u := h / height
			spike_pts.append(lean * u * u + Vector3.UP * h)
			# Even thickness to a blunt rounded top; alternate rows swell where
			# the capsules sit, so the spike reads knobbly, not as a smooth blade.
			var knob := 1.0 + (0.22 if k % 2 == 0 else -0.12)
			spike_r.append(0.0026 * knob * (1.0 - pow(smoothstep(0.9, 1.0, t), 2.0) * 0.7))
		var seed := rng.randi()
		var bloom := rng.randf_range(0.45, 0.75)
		_tube(b, spike_pts, spike_r, 6, func(t: float) -> Color:
			var h := MeshMath.hash01(int(t * 40.0), seed % 997, 4211)
			var ripe := Color(0.44, 0.38, 0.24).lerp(PLANTAIN_SPIKE, smoothstep(0.0, bloom, t))
			var c := ripe.lerp(Color(0.40, 0.50, 0.26), smoothstep(bloom, 1.0, t))
			return c.lerp(PLANTAIN_ANTHER, 0.55) if h > 0.55 and absf(t - bloom) < 0.15 else c,
			0.55, 1.0, 0.2, 0.5)
		var stamen_rng := _child_rng(rng)
		if _far:
			continue
		# Stamens stick out of the flowering band.
		var frame := _frame(Vector3.UP)
		for k in 10:
			var t := bloom + stamen_rng.randf_range(-0.1, 0.1)
			var at := spike_pts[0].lerp(spike_pts[rows], clampf(t, 0.0, 1.0))
			var a := stamen_rng.randf() * TAU
			var radial: Vector3 = frame[0] * cos(a) + frame[1] * sin(a)
			var root := at + radial * 0.003
			_ribbon(b, [root, root + radial * 0.003 + Vector3.UP * 0.001], 0.0006,
				Color(0.74, 0.66, 0.70), 1.0, 0.3, radial.cross(Vector3.UP))


# --- White clover (Trifolium repens) ----------------------------------------
# A creeping patch: long petioles rising off stolons to trifoliate leaves held
# flat, each obovate leaflet notched at the tip with the pale V chevron, and a
# few globular white heads whose lowest florets fade brown and droop.


static func _white_clover(b: Builder, rng: RandomNumberGenerator) -> void:
	# A dense mat: leaves spread evenly over the patch (sqrt radius), the
	# petioles short so the leaflets overlap in a low, closed canopy.
	var leaves := 70
	var stolons := 6
	for i in leaves:
		var stolon := TAU * float(i % stolons) / float(stolons) + rng.randf_range(-0.5, 0.5)
		var reach := 0.22 * sqrt(rng.randf())
		var root := Vector3(cos(stolon), 0.0, sin(stolon)) * reach
		root += Vector3(rng.randf_range(-0.02, 0.02), 0.0, rng.randf_range(-0.02, 0.02))
		# Petioles lift the leaves into a low mat, a little higher in the middle.
		var height := rng.randf_range(0.012, 0.035) + 0.02 * (1.0 - reach / 0.22)
		var tip := root + Vector3(rng.randf_range(-0.012, 0.012), height, rng.randf_range(-0.012, 0.012))
		var leaf_rng := _child_rng(rng)
		var size := rng.randf_range(0.015, 0.023)
		var tone := rng.randf_range(0.86, 1.1)
		if _far:
			# A third of the leaves, no petioles: past 12 m the mat is a green texture.
			if i % 3 == 0:
				_trifoliate(b, leaf_rng, tip, size * 1.4, 0.66, CLOVER_LEAF * tone, 0.8, TILE_WHITE_CLOVER)
			continue
		_tube(b, PackedVector3Array([root, root.lerp(tip, 0.5) + Vector3(0.004, 0.0, 0.0), tip]),
			PackedFloat32Array([0.0012, 0.0011, 0.0010]), 3,
			func(_t: float) -> Color: return Color(0.42, 0.52, 0.28), 0.0, 0.7, 0.2)
		_trifoliate(b, leaf_rng, tip, size, 0.66, CLOVER_LEAF * tone, 0.8, TILE_WHITE_CLOVER)
	for i in 5:
		var yaw := rng.randf() * TAU
		var root := Vector3(cos(yaw), 0.0, sin(yaw)) * rng.randf_range(0.03, 0.2)
		var height := rng.randf_range(0.07, 0.12)
		var top := root + Vector3(rng.randf_range(-0.015, 0.015), height, rng.randf_range(-0.015, 0.015))
		_tube(b, PackedVector3Array([root, root.lerp(top, 0.6), top]),
			PackedFloat32Array([0.0013, 0.0012, 0.0010]), 3,
			func(_t: float) -> Color: return Color(0.48, 0.55, 0.32), 0.0, 1.0, 0.2)
		# Florets open from the bottom up; the oldest, lowest ones wither brown
		# and hang down round the stalk.
		_floret_head(b, _child_rng(rng), top + Vector3.UP * 0.004, 0.0085, 56, 0.55,
			func(up: float, roll: float) -> Color:
				var c := CLOVER_WHITE.lerp(Color(0.96, 0.84, 0.86), 0.45 * roll)
				return c.lerp(CLOVER_FADED, smoothstep(-0.1, -0.6, up)),
			1.0)


# --- Red clover (Trifolium pratense) ----------------------------------------
# Taller, upright meadow plant: stems with alternate trifoliate leaves of
# elliptic leaflets with a pale crescent, an ovoid pink-purple head of tubular
# florets cupped by a pair of leaves.


static func _red_clover(b: Builder, rng: RandomNumberGenerator) -> void:
	var stems := rng.randi_range(4, 6)
	for i in stems:
		var yaw := TAU * float(i) / float(stems) + rng.randf_range(-0.4, 0.4)
		var out := Vector3(cos(yaw), 0.0, sin(yaw))
		var height := rng.randf_range(0.20, 0.34)
		var pts := PackedVector3Array()
		var radii := PackedFloat32Array()
		for k in 6:
			var t := float(k) / 5.0
			pts.append(out * (0.01 + 0.05 * sin(t * 1.3)) + Vector3.UP * height * t)
			radii.append(lerpf(0.0022, 0.0016, t))
		_tube(b, pts, radii, 4, func(_t: float) -> Color: return Color(0.42, 0.50, 0.28),
			0.0, 1.0, 0.2)
		for k in [1, 2, 3]:
			var leaf_rng := _child_rng(rng)
			var size := rng.randf_range(0.03, 0.042)
			var tone := rng.randf_range(0.92, 1.08)
			# The far variant keeps one stem leaf in three, a bit larger.
			if not _far or k == 2:
				_trifoliate(b, leaf_rng, pts[k], size * (1.3 if _far else 1.0), 0.44,
					RED_CLOVER_LEAF * tone, float(k) / 5.0, TILE_RED_CLOVER)
		var top := pts[5]
		var top_rng := _child_rng(rng)
		if not _far:
			_trifoliate(b, top_rng, top - Vector3.UP * 0.006, 0.024, 0.44, RED_CLOVER_LEAF, 1.0,
				TILE_RED_CLOVER)
		if rng.randf() < 0.25:
			continue
		_floret_head(b, _child_rng(rng), top + Vector3.UP * 0.012, 0.0125, 48, 0.75,
			func(up: float, roll: float) -> Color:
				var c := RED_CLOVER_HEAD.lerp(Color(0.92, 0.62, 0.78), 0.55 * roll)
				return c.darkened(0.25 * smoothstep(0.0, -0.8, up)),
			1.0)


## A globular clover head built from separate tubular florets radiating from a
## small core, so its outline is tufted instead of a smooth ball. color(up,
## roll) gets the floret's upward component (-1..1) and a random 0..1.
static func _floret_head(
	b: Builder, rng: RandomNumberGenerator, centre: Vector3, radius: float, count: int,
	upright: float, color: Callable, flex: float
) -> void:
	if _far:
		_blob(b, centre, Vector3.ONE * radius * 1.2, 3, 6,
			func(d: Vector3) -> Color: return color.call(d.y, 0.5), 0.1, flex, 0.4)
		return
	_blob(b, centre, Vector3.ONE * radius * 0.85, 3, 6,
		func(d: Vector3) -> Color: return color.call(d.y, 0.3).darkened(0.25), 0.1, flex, 0.3)
	for i in count:
		var y := 1.0 - 2.0 * (float(i) + 0.5) / float(count)
		var ring_r := sqrt(1.0 - y * y)
		var phi := float(i) * 2.39996
		var dir := Vector3(cos(phi) * ring_r, y, sin(phi) * ring_r)
		# Florets curve up toward the top of the head (they point out and up).
		var bend := (dir + Vector3.UP * upright * 0.5).normalized()
		if y < -0.2:
			bend = (dir + Vector3.DOWN * 0.6).normalized()
		var root := centre + dir * radius * 0.4
		# Short, crowded florets: a dense globe, not a spiky star.
		var tip := root + bend * radius * rng.randf_range(0.5, 0.75)
		var c: Color = color.call(y, rng.randf())
		var side := dir.cross(Vector3.UP)
		if side.length_squared() < 0.001:
			side = Vector3.RIGHT
		_ribbon(b, [root, tip], radius * 0.22, c, flex, 0.5, side.cross(bend).normalized())


## Three leaflets on a petiole tip, held nearly flat. `aspect` is leaflet width
## over length (round white clover ~0.6, elliptic red clover ~0.4).
static func _trifoliate(
	b: Builder, rng: RandomNumberGenerator, at: Vector3, length: float, aspect: float,
	color: Color, flex: float, tile: int
) -> void:
	var turn := rng.randf() * TAU
	for k in 3:
		var yaw := turn + TAU * float(k) / 3.0 + rng.randf_range(-0.15, 0.15)
		var half_w := length * aspect * 0.5
		_strip_leaf(b, {
			"base": at,
			"yaw": yaw,
			"rise": rng.randf_range(0.0, 0.35),
			"droop": rng.randf_range(0.0, 0.3),
			"length": length,
			"samples": PackedFloat32Array([0.0, 0.4, 0.75, 1.0]),
			"cols": 3,
			"fold": 0.22,
			"width": func(t: float) -> float:
				if t <= 0.75:
					return half_w * (0.12 + 0.88 * sin(PI * 0.5 * t / 0.75))
				return half_w * (1.0 - pow((t - 0.75) / 0.25, 2.0) * 0.5),
			# Notched (emarginate) tip.
			"shift": func(t: float, s: float) -> float:
				return -length * 0.12 if t > 0.99 and absf(s) < 0.01 else 0.0,
			# The pale V and the fine laterals come from the detail atlas.
			"color": func(t: float, _s: float) -> Color:
				return color.lightened(0.04 * (1.0 - t)),
			"flex": Vector2(flex, flex),
			"under": 0.25,
			"trans": 0.35,
			"tile": tile,
		})


# --- Burdock (Arctium lappa / minus) ----------------------------------------
# First year: a mound of huge heart-shaped leaves on long reddish petioles,
# wavy at the margin, dark green above and grey-woolly below. Second year: a
# branched stem a metre and more high with smaller leaves and clusters of
# hooked burrs topped by purple florets.


static func _burdock(b: Builder, rng: RandomNumberGenerator, flowering: bool) -> void:
	var basal := 4 if flowering else rng.randi_range(6, 8)
	for i in basal:
		var yaw := float(i) * 2.4 + rng.randf_range(-0.25, 0.25)
		# Older outer leaves lie wide and low, young inner ones stand up.
		var age := float(i) / float(basal - 1)
		var size := rng.randf_range(0.15, 0.21) * lerpf(1.15, 0.75, age)
		_burdock_leaf(b, rng, Vector3.ZERO, yaw, rng.randf_range(0.2, 0.32) * lerpf(1.1, 0.8, age),
			size, lerpf(0.75, 1.2, age) + rng.randf_range(-0.1, 0.1), 0.35, lerpf(0.1, 0.55, age))
	if not flowering:
		return
	# Second year: a stout furrowed stem that branches from low down into a
	# broad, rounded candelabra (wider than half its height), every branch
	# forking again near its end into clusters of burrs.
	var height := rng.randf_range(1.05, 1.3)
	var stem := PackedVector3Array()
	var radii := PackedFloat32Array()
	var sway := Vector3(rng.randf_range(-0.05, 0.05), 0.0, rng.randf_range(-0.05, 0.05))
	for k in 9:
		var t := float(k) / 8.0
		stem.append(sway * t * t + Vector3.UP * height * t)
		radii.append(lerpf(0.014, 0.004, t))
	_tube(b, stem, radii, 6, func(t: float) -> Color:
		return BURDOCK_STEM.lerp(Color(0.40, 0.46, 0.26), t), 0.0, 1.6, 0.1, 0.25)
	# Stem leaves: heart-shaped, alternate, shrinking quickly upward.
	# The lower ones nearly as large as the basal leaves, so the plant reads as
	# a leafy bush under its burrs.
	for k in [1, 2, 3, 4, 5]:
		var f := float(k - 1) / 4.0
		_burdock_leaf(b, rng, stem[k], float(k) * 2.4 + 0.6, lerpf(0.10, 0.04, f),
			lerpf(0.19, 0.08, f), 0.45, lerpf(0.5, 1.2, float(k) / 8.0), lerpf(0.15, 0.3, f), 16)
	var branches := rng.randi_range(9, 11)
	for i in branches:
		var k := 2 + i % 6
		var origin := stem[k]
		var up := float(k) / 8.0
		var yaw := float(i) * 2.4 + rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(yaw), 0.0, sin(yaw))
		# Low branches reach far and rise steeply at the end, upper ones are short:
		# together the burr clusters sit on a dome.
		var length := rng.randf_range(0.30, 0.42) * lerpf(1.15, 0.45, up)
		var rise := lerpf(0.75, 1.05, up)
		var tip := origin + out * length + Vector3.UP * length * rise
		var mid := origin + out * length * 0.62 + Vector3.UP * length * rise * 0.38
		var flex := lerpf(0.9, 1.6, up)
		_tube(b, PackedVector3Array([origin, mid, tip]), PackedFloat32Array([0.0065, 0.0045, 0.0028]),
			4, func(_t: float) -> Color: return Color(0.44, 0.38, 0.26), flex * 0.7, flex, 0.1)
		if length > 0.2:
			_burdock_leaf(b, rng, mid, yaw + 0.8, 0.03, 0.09, 0.5, 0.9, 0.2, 12)
		_burr_cluster(b, _child_rng(rng), tip, flex, rng.randi_range(5, 8))
		# A forked twig from the branch's last third carries a second cluster.
		var side := out.rotated(Vector3.UP, 0.7 if i % 2 == 0 else -0.7)
		var fork := mid.lerp(tip, 0.4)
		var twig := fork + side * length * 0.25 + Vector3.UP * length * 0.3
		_tube(b, PackedVector3Array([fork, twig]), PackedFloat32Array([0.0022, 0.0015]), 3,
			func(_t: float) -> Color: return Color(0.44, 0.38, 0.26), flex * 0.85, flex, 0.1)
		_burr_cluster(b, _child_rng(rng), twig, flex, rng.randi_range(3, 5))
	_burr_cluster(b, _child_rng(rng), stem[8], 1.6, 5)


static func _burdock_leaf(
	b: Builder, rng: RandomNumberGenerator, at: Vector3, yaw: float, petiole: float,
	size: float, pitch: float, flex: float, blade_pitch: float, spokes: int = 28
) -> void:
	var out := Vector3(cos(yaw), 0.0, sin(yaw))
	var blade_at := at + out * petiole * cos(pitch) + Vector3.UP * petiole * sin(pitch)
	# Thick channelled petiole, red at the base and green where it meets the blade.
	_tube(b, PackedVector3Array([at, at.lerp(blade_at, 0.5) + Vector3.UP * petiole * 0.08, blade_at]),
		PackedFloat32Array([size * 0.05, size * 0.042, size * 0.03]), 5,
		func(t: float) -> Color: return BURDOCK_PETIOLE.lerp(Color(0.46, 0.54, 0.30), t),
		flex * 0.3 if at.y > 0.0 else 0.0, flex * 0.6, 0.2)
	var tone := rng.randf_range(0.88, 1.1)
	var wave_phase := rng.randf() * TAU
	_polar_leaf(b, {
		"origin": blade_at,
		"yaw": yaw,
		"pitch": blade_pitch + rng.randf_range(-0.1, 0.1),
		# Heart shape with the petiole in the notch: a flattened cardioid gives
		# basal lobes that reach back past the petiole and a blunt-pointed tip.
		"radius": func(th: float) -> float:
			return size * pow(1.0 + cos(th), 0.75) * (1.0 + 0.14 * pow(maxf(cos(th), 0.0), 8.0)),
		"rings": 5 if spokes >= 20 else 3,
		"spokes": spokes,
		"droop": rng.randf_range(0.35, 0.55),
		# Veins sink into the upper surface, so the blade looks quilted.
		"relief": 0.012,
		"cup": -0.16,
		"wave": 0.035,
		"wave_phase": wave_phase,
		# The vein net comes from the detail atlas; the vertex colour only
		# darkens the blade toward its sunken centre.
		"color": func(f: float, _th: float) -> Color:
			return (BURDOCK_LEAF * tone).darkened(0.12 * (1.0 - f)),
		"tile": TILE_BURDOCK,
		"flex": Vector2(flex * 0.6, flex),
		"under": 0.85,
		"trans": 0.25,
	})


## `count` burrs round `at`: spiny green balls of hooked bracts, each with a
## purple tuft of florets on top. The far variant keeps two plain balls.
static func _burr_cluster(
	b: Builder, rng: RandomNumberGenerator, at: Vector3, flex: float, count: int
) -> void:
	if _far:
		count = mini(count, 2)
	for i in count:
		var dir := Vector3(
			rng.randf_range(-1, 1), rng.randf_range(0.0, 1.0), rng.randf_range(-1, 1)
		).normalized()
		var radius := rng.randf_range(0.010, 0.014)
		var c := at + dir * radius * 1.5
		var seed := rng.randi() % 997
		_blob(b, c, Vector3.ONE * radius, 3, 6, func(d: Vector3) -> Color:
			var spike := MeshMath.hash01(int(d.x * 30.0), int(d.z * 30.0), seed)
			return BURR_GREEN.darkened(0.1 + spike * 0.3),
			0.6, flex, 0.15)
		if not _far:
			_blob(b, c + Vector3.UP * radius * 0.85, Vector3(radius * 0.55, radius * 0.35, radius * 0.55),
				2, 4, func(_d: Vector3) -> Color: return BURR_PURPLE, 0.3, flex, 0.3)


# --- Geometry helpers -------------------------------------------------------


## Atlas coordinate of (u, v) 0..1 inside `tile`, or the neutral texel.
static func _tile_uv(tile: int, u: float, v: float) -> Vector2:
	if tile < 0:
		return NEUTRAL_UV
	u = lerpf(TILE_INSET, 1.0 - TILE_INSET, clampf(u, 0.0, 1.0))
	v = lerpf(TILE_INSET, 1.0 - TILE_INSET, clampf(v, 0.0, 1.0))
	return Vector2((float(tile % 4) + u) * 0.25, (float(tile / 4) + v) * 0.5)


## Every other entry, always keeping the first and last (far-variant grids).
static func _thin(values: PackedFloat32Array) -> PackedFloat32Array:
	if values.size() <= 3:
		return values
	var out := PackedFloat32Array()
	for i in values.size():
		if i % 2 == 0 or i == values.size() - 1:
			out.append(values[i])
	return out


## Two unit vectors perpendicular to `axis` and each other.
static func _frame(axis: Vector3) -> Array[Vector3]:
	var ref := Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT
	var u := ref.cross(axis).normalized()
	return [u, axis.cross(u).normalized()]


## A leaf as a grid along a curved midrib. Keys: base, yaw, rise (initial pitch),
## droop (pitch lost by the tip), length, samples (t rows 0..1), cols (odd),
## fold (V-fold along the midrib), width(t) half-width, optional shift(t, s)
## along-axis margin offset and ridge(t, s) lift, color(t, s), flex (root, tip),
## under, trans.
static func _strip_leaf(b: Builder, spec: Dictionary) -> void:
	var yaw: float = spec["yaw"]
	var forward_h := Vector3(cos(yaw), 0.0, sin(yaw))
	var side := Vector3(-sin(yaw), 0.0, cos(yaw))
	var samples: PackedFloat32Array = spec["samples"]
	var cols: int = spec["cols"]
	if _far:
		samples = _thin(samples)
		while samples.size() > 6:
			samples = _thin(samples)
		cols = 3
	var length: float = spec["length"]
	var rise: float = spec["rise"]
	var droop: float = spec["droop"]
	var fold: float = spec["fold"]
	var width: Callable = spec["width"]
	var color: Callable = spec["color"]
	var shift: Callable = spec.get("shift", Callable())
	var ridge: Callable = spec.get("ridge", Callable())
	var flex: Vector2 = spec["flex"]
	var under: float = spec["under"]
	var trans: float = spec["trans"]
	var tile: int = spec.get("tile", -1)
	var p: Vector3 = spec["base"]
	var prev_t := 0.0
	var grid: Array[PackedInt32Array] = []
	var ups: Array[Vector3] = []
	for r in samples.size():
		var t := samples[r]
		var pitch := rise - droop * t
		var fwd := forward_h * cos(pitch) + Vector3.UP * sin(pitch)
		# Walk the midrib in arc-length steps so the leaf curls smoothly.
		p += fwd * (t - prev_t) * length
		prev_t = t
		var up := side.cross(fwd)
		var w: float = width.call(t)
		var row := PackedInt32Array()
		for c in cols:
			var s := -1.0 + 2.0 * float(c) / float(cols - 1)
			var lift := fold * absf(s) * w
			if ridge.is_valid():
				lift += float(ridge.call(t, s))
			var along := float(shift.call(t, s)) if shift.is_valid() else 0.0
			var v := p + side * s * w + up * lift + fwd * along
			row.append(b.vertex(v, color.call(t, s), lerpf(flex.x, flex.y, t), under, trans,
				_tile_uv(tile, 0.5 + 0.5 * s, t)))
		grid.append(row)
		ups.append(up)
	for r in samples.size() - 1:
		for c in cols - 1:
			b.quad(grid[r][c], grid[r][c + 1], grid[r + 1][c + 1], grid[r + 1][c], ups[r])


## A broad leaf as rings round its attachment point. Keys: origin, yaw, pitch,
## radius(theta) outline (theta 0 points along the midrib), rings, spokes, droop
## (tip falls), cup (margins rise, negative curls them down), wave (margin
## undulation), wave_phase, color(ring_fraction, theta), flex, under, trans.
static func _polar_leaf(b: Builder, spec: Dictionary) -> void:
	var yaw: float = spec["yaw"]
	var pitch: float = spec["pitch"]
	var forward := Vector3(cos(yaw) * cos(pitch), sin(pitch), sin(yaw) * cos(pitch))
	var side := Vector3(-sin(yaw), 0.0, cos(yaw))
	var up := side.cross(forward)
	var origin: Vector3 = spec["origin"]
	var radius: Callable = spec["radius"]
	var rings: int = spec["rings"]
	var spokes: int = spec["spokes"]
	if _far:
		rings = maxi(2, rings / 2)
		spokes = maxi(8, spokes / 2)
	var color: Callable = spec["color"]
	var flex: Vector2 = spec["flex"]
	var under: float = spec["under"]
	var trans: float = spec["trans"]
	var reach := float(radius.call(0.0))
	var droop: float = spec["droop"]
	var cup: float = spec["cup"]
	var wave: float = spec["wave"]
	var phase: float = spec["wave_phase"]
	var relief: float = spec.get("relief", 0.0)
	var tile: int = spec.get("tile", -1)
	var centre := b.vertex(
		origin, color.call(0.0, 0.0), flex.x, under, trans, _tile_uv(tile, 0.5, 0.5)
	)
	var prev: Array[int] = []
	for k in range(1, rings + 1):
		var f := float(k) / float(rings)
		var ring: Array[int] = []
		for j in spokes:
			var th := -PI + TAU * (float(j) + 0.5) / float(spokes)
			var r := float(radius.call(th)) * f
			var lx := r * cos(th)
			var lz := r * sin(th)
			var h := -droop * pow(maxf(lx, 0.0) / reach, 2.0) * reach
			h += cup * pow(lz / reach, 2.0) * reach
			h += wave * reach * sin(th * 13.0 + phase) * f * f
			if j % 2 == 0:
				h -= relief * reach * f * (1.0 - f) * 4.0
			var v := origin + forward * lx + side * lz + up * h
			ring.append(b.vertex(v, color.call(f, th), lerpf(flex.x, flex.y, f), under, trans,
				_tile_uv(tile, 0.5 + 0.5 * lz / reach, 0.5 + 0.5 * lx / reach)))
		for j in spokes:
			var n := (j + 1) % spokes
			if prev.is_empty():
				b.tri(centre, ring[j], ring[n], up)
			else:
				b.quad(prev[j], prev[n], ring[n], ring[j], up)
		prev = ring


## A tapered tube along `pts` (stems, petioles, spikes). color(t) and flex run
## from root (t 0) to tip (t 1); the tip stays open (a head or blade covers it).
static func _tube(
	b: Builder, pts: PackedVector3Array, radii: PackedFloat32Array, sides: int,
	color: Callable, flex0: float, flex1: float, trans: float, bump: float = 0.0
) -> void:
	if _far:
		sides = 3
		var keep := PackedFloat32Array()
		for i in pts.size():
			keep.append(float(i))
		keep = _thin(keep)
		var thin_pts := PackedVector3Array()
		var thin_r := PackedFloat32Array()
		for i in keep:
			thin_pts.append(pts[int(i)])
			thin_r.append(radii[int(i)])
		pts = thin_pts
		radii = thin_r
	var count := pts.size()
	var prev: Array[int] = []
	var prev_dirs: Array[Vector3] = []
	for i in count:
		var t := float(i) / float(count - 1)
		var tangent := (pts[mini(i + 1, count - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var frame := _frame(tangent)
		var ring: Array[int] = []
		var dirs: Array[Vector3] = []
		var c: Color = color.call(t)
		for k in sides:
			var a := TAU * float(k) / float(sides)
			var radial: Vector3 = frame[0] * cos(a) + frame[1] * sin(a)
			var r := radii[i] * (1.0 + bump * (MeshMath.hash01(i, k, 4409) - 0.5))
			ring.append(b.vertex(pts[i] + radial * r, c, lerpf(flex0, flex1, t), 0.0, trans))
			dirs.append(radial)
		if not prev.is_empty():
			for k in sides:
				var n := (k + 1) % sides
				b.quad(prev[k], prev[n], ring[n], ring[k], prev_dirs[k] + dirs[n])
		prev = ring
		prev_dirs = dirs


## A thin strip through `pts` (florets, bracts, seed beaks). `facing` is the side
## the front face looks toward.
static func _ribbon(
	b: Builder, pts: Array, half_width: float, color: Color, flex: float, trans: float,
	facing: Vector3, under: float = 0.0
) -> void:
	var prev := PackedInt32Array()
	for i in pts.size():
		var t := float(i) / float(pts.size() - 1)
		var p: Vector3 = pts[i]
		var ahead: Vector3 = pts[mini(i + 1, pts.size() - 1)]
		var behind: Vector3 = pts[maxi(i - 1, 0)]
		var tangent := (ahead - behind).normalized()
		var side := tangent.cross(facing)
		if side.length_squared() < 0.0001:
			side = _frame(tangent)[0]
		side = side.normalized()
		# Florets and bracts narrow to a point; the last row is the tip.
		var w := half_width * (1.0 - 0.6 * t)
		var shade := color.darkened(0.12 * (1.0 - t))
		var row := PackedInt32Array([
			b.vertex(p - side * w, shade, flex, under, trans),
			b.vertex(p + side * w, shade, flex, under, trans),
		])
		if not prev.is_empty():
			b.quad(prev[0], prev[1], row[1], row[0], facing)
		prev = row


## A lumpy ellipsoid (flower heads, burrs, buds). color(dir) gets the unit
## direction from the centre in mesh space; bump roughens the surface.
static func _blob(
	b: Builder, centre: Vector3, radii: Vector3, rings: int, segs: int, color: Callable,
	bump: float, flex: float, trans: float
) -> void:
	if _far:
		rings = maxi(2, rings - 1)
		segs = maxi(4, segs - 2)
	var rows: Array[Array] = []
	for r in rings + 1:
		var lat := PI * float(r) / float(rings) - PI * 0.5
		var row: Array[int] = []
		var n := 1 if r == 0 or r == rings else segs
		for s in n:
			var lon := TAU * (float(s) + 0.5 * float(r % 2)) / float(segs)
			var d := Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon))
			var k := 1.0 + bump * (MeshMath.hash01(r * 31 + s, int(centre.x * 1000.0), 4423) - 0.5)
			row.append(b.vertex(centre + d * radii * k, color.call(d), flex, 0.0, trans))
		rows.append(row)
	for r in rings:
		var lo: Array = rows[r]
		var hi: Array = rows[r + 1]
		for s in segs:
			var n := (s + 1) % segs
			var lat := PI * (float(r) + 0.5) / float(rings) - PI * 0.5
			var lon := TAU * (float(s) + 0.5) / float(segs)
			var out := Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon))
			if lo.size() == 1:
				b.tri(lo[0], hi[s], hi[n], out)
			elif hi.size() == 1:
				b.tri(lo[s], lo[n], hi[0], out)
			else:
				b.quad(lo[s], lo[n], hi[n], hi[s], out)


## Indexed triangle accumulator with area-weighted smooth normals.
class Builder:
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var indices := PackedInt32Array()

	## `color` is sRGB. Vertices are kept a hair above the planted root so a
	## drooping leaf tip never sinks under the ground plane. `detail` is the
	## leaf-detail atlas coordinate (neutral tile unless a leaf passes one).
	func vertex(
		p: Vector3, color: Color, flex: float, under: float, trans: float,
		detail: Vector2 = NEUTRAL_UV
	) -> int:
		verts.append(Vector3(p.x, maxf(p.y, 0.002), p.z))
		var c := color.srgb_to_linear()
		c.a = trans
		colors.append(c)
		uvs.append(Vector2(maxf(flex, 0.0), under))
		uv2s.append(detail)
		return verts.size() - 1

	## Winds the triangle so its front face (Godot: clockwise) looks toward `facing`.
	func tri(a: int, b: int, c: int, facing: Vector3) -> void:
		var n := (verts[c] - verts[a]).cross(verts[b] - verts[a])
		if n.dot(facing) < 0.0:
			indices.append_array([a, c, b])
		else:
			indices.append_array([a, b, c])

	func quad(a: int, b: int, c: int, d: int, facing: Vector3) -> void:
		tri(a, b, c, facing)
		tri(a, c, d, facing)

	func commit() -> ArrayMesh:
		var normals := PackedVector3Array()
		normals.resize(verts.size())
		for i in range(0, indices.size(), 3):
			var a := indices[i]
			var b := indices[i + 1]
			var c := indices[i + 2]
			var n := (verts[c] - verts[a]).cross(verts[b] - verts[a])
			normals[a] += n
			normals[b] += n
			normals[c] += n
		for i in normals.size():
			normals[i] = normals[i].normalized() if normals[i].length_squared() > 1e-14 else Vector3.UP
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_TEX_UV2] = uv2s
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh
