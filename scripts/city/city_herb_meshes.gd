# gdlint:disable=max-file-lines
extends RefCounted

## Detailed procedural models of the meadow herbs round Reval (R-2128):
## chamomile, yarrow, St John's wort and caraway, with their seasonal variants.
## Built and cached through CityForbMeshes.mesh_for, which sets the far flag
## (CityForbMeshes._far) and owns the vertex contract; this file holds only the
## botany, plus the feathery-leaf, strand and floret helpers the weeds in
## city_weed_meshes.gd share. Original geometry only, deterministic: every
## seasonal variant of a species reuses the flowering kind's seed, so it is the
## same plant in another season.

const MeshMath := preload("res://scripts/map/view3d/map_view_mesh_builder_math.gd")

## Growth stages a kind is built for.
const STAGE_FLOWER := 0
## Out of flower: the leafy plant without heads (young or cut back).
const STAGE_LEAVES := 1
## Ripening fruit: caraway seed umbels, thistledown.
const STAGE_SEED := 2
## Dead standing stalks in autumn (mugwort).
const STAGE_DRY := 3
## Young spring shoots (nettle).
const STAGE_SHOOTS := 4

## Kind -> [species (seed), stage].
const KINDS := {
	&"chamomile": [&"chamomile", STAGE_FLOWER],
	&"chamomile_leaves": [&"chamomile", STAGE_LEAVES],
	&"yarrow": [&"yarrow", STAGE_FLOWER],
	&"yarrow_leaves": [&"yarrow", STAGE_LEAVES],
	&"st_johns_wort": [&"st_johns_wort", STAGE_FLOWER],
	&"st_johns_wort_leaves": [&"st_johns_wort", STAGE_LEAVES],
	&"caraway": [&"caraway", STAGE_FLOWER],
	&"caraway_seed": [&"caraway", STAGE_SEED],
	&"caraway_leaves": [&"caraway", STAGE_LEAVES],
}

# Colours are sRGB, picked from field photographs of each species.
const FEATHER_GREEN := Color(0.30, 0.46, 0.18)
const CHAMOMILE_LEAF := Color(0.33, 0.50, 0.19)
const CHAMOMILE_STEM := Color(0.42, 0.52, 0.26)
const CHAMOMILE_DISC := Color(0.90, 0.70, 0.08)
const YARROW_LEAF := Color(0.27, 0.43, 0.17)
const YARROW_STEM := Color(0.42, 0.48, 0.30)
# Off-white like the daisy rays (pure white clips under the city grade), with
# the cream-grey centre of each tiny head.
const YARROW_WHITE := Color(0.90, 0.89, 0.82)
const YARROW_CENTRE := Color(0.76, 0.72, 0.56)
const HYPERICUM_LEAF := Color(0.26, 0.42, 0.17)
const HYPERICUM_STEM := Color(0.42, 0.44, 0.22)
const HYPERICUM_PETAL := Color(0.90, 0.74, 0.06)
const HYPERICUM_STAMEN := Color(0.86, 0.58, 0.06)
const HYPERICUM_BUD := Color(0.66, 0.36, 0.10)
const CARAWAY_LEAF := Color(0.30, 0.48, 0.20)
const CARAWAY_STEM := Color(0.44, 0.52, 0.30)
const CARAWAY_FLOWER := Color(0.90, 0.88, 0.80)
const CARAWAY_SEED := Color(0.46, 0.40, 0.22)


## Builds `kind` into `b` if it is one of this file's herbs (false otherwise).
static func build(kind: StringName, b: CityForbMeshes.Builder, rng: RandomNumberGenerator) -> bool:
	if not KINDS.has(kind):
		return false
	var spec: Array = KINDS[kind]
	var species: StringName = spec[0]
	var stage: int = spec[1]
	rng.seed = 1343 + hash(String(species))
	match species:
		&"chamomile":
			_chamomile(b, rng, stage)
		&"yarrow":
			_yarrow(b, rng, stage)
		&"st_johns_wort":
			_st_johns_wort(b, rng, stage)
		&"caraway":
			_caraway(b, rng, stage)
	return true


# --- Chamomile (Matricaria chamomilla) --------------------------------------
# A bushy, much-branched annual 20-40 cm high with thread-fine, two- to three-
# times divided leaves; every branch ends in a small head: 12-16 white rays
# that fold back (reflexed) under a tall, hollow, conical golden disc. Out of
# flower: a low tuft of feathery leaves.


static func _chamomile(b: CityForbMeshes.Builder, rng: RandomNumberGenerator, stage: int) -> void:
	var basal := rng.randi_range(5, 7)
	for i in basal:
		var yaw := TAU * float(i) / float(basal) + rng.randf_range(-0.3, 0.3)
		_pinnate_leaf(
			b,
			rng,
			Vector3.UP * 0.004,
			yaw,
			rng.randf_range(0.5, 0.9),
			rng.randf_range(0.5, 0.9),
			rng.randf_range(0.06, 0.09),
			5,
			0.016,
			0.0009,
			CHAMOMILE_LEAF * rng.randf_range(0.92, 1.06),
			Vector2(0.0, 0.25),
			true
		)
	# Draw the stems' numbers in every season, so the tuft is the same plant.
	var height := rng.randf_range(0.24, 0.36)
	var lean := Vector3(rng.randf_range(-0.03, 0.03), 0.0, rng.randf_range(-0.03, 0.03))
	var branches := rng.randi_range(5, 7)
	var stem_rng := CityForbMeshes._child_rng(rng)
	var head_rng := CityForbMeshes._child_rng(rng)
	if stage == STAGE_LEAVES:
		return
	var stem := _stem(b, Vector3.ZERO, lean, height, 0.0022, 0.0012, CHAMOMILE_STEM, 1.2)
	# Branches leave the main stem from a third of its height up and reach about
	# as high as it, so the heads stand in a loose, uneven dome.
	for i in branches:
		var k := 2 + i % 4
		var yaw := float(i) * 2.4 + stem_rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(yaw), 0.0, sin(yaw))
		var reach := stem_rng.randf_range(0.06, 0.12)
		var top := (
			stem[k]
			+ out * reach
			+ Vector3.UP * (height - stem[k].y) * stem_rng.randf_range(0.75, 1.05)
		)
		var mid := stem[k].lerp(top, 0.5) + out * reach * 0.15
		var flex := lerpf(0.9, 1.2, float(k) / 6.0)
		CityForbMeshes._tube(
			b,
			PackedVector3Array([stem[k], mid, top]),
			PackedFloat32Array([0.0013, 0.0011, 0.0009]),
			4,
			func(_t: float) -> Color: return CHAMOMILE_STEM,
			flex * 0.7,
			flex,
			0.25
		)
		if not CityForbMeshes._far or i % 2 == 0:
			_pinnate_leaf(
				b,
				stem_rng,
				stem[k].lerp(mid, 0.3),
				yaw + 0.9,
				0.4,
				0.4,
				0.045,
				4,
				0.012,
				0.0008,
				CHAMOMILE_LEAF,
				Vector2(flex * 0.7, flex),
				true
			)
		_chamomile_head(b, head_rng, top, (Vector3.UP * 3.0 + out).normalized(), flex)
	_chamomile_head(b, head_rng, stem[stem.size() - 1], Vector3.UP, 1.2)


static func _chamomile_head(
	b: CityForbMeshes.Builder, rng: RandomNumberGenerator, top: Vector3, axis: Vector3, flex: float
) -> void:
	var frame := CityForbMeshes._frame(axis)
	# About 1.3x life size, like the other forbs: a 2 cm head.
	var disc_r := rng.randf_range(0.0042, 0.0052)
	var cone := disc_r * rng.randf_range(1.1, 1.5)
	var rays := rng.randi_range(12, 15)
	var turn := rng.randf() * TAU
	if CityForbMeshes._far:
		CityForbMeshes._dome(
			b,
			top,
			frame,
			axis,
			disc_r * 2.2,
			-0.002,
			5,
			1,
			func(_f: float) -> Color: return CityForbMeshes.DAISY_RAY,
			flex,
			0.5
		)
		CityForbMeshes._dome(
			b,
			top,
			frame,
			axis,
			disc_r,
			cone,
			4,
			1,
			func(_f: float) -> Color: return CHAMOMILE_DISC,
			flex,
			0.2
		)
		return
	# The rays fold back: each starts level under the cone and bends down.
	for i in rays:
		var a := turn + TAU * (float(i) + rng.randf_range(-0.2, 0.2)) / float(rays)
		var radial: Vector3 = frame[0] * cos(a) + frame[1] * sin(a)
		var length := disc_r * rng.randf_range(1.5, 1.9)
		var droop := rng.randf_range(0.7, 1.3)
		var pts := PackedVector3Array()
		var p := top + radial * disc_r * 0.8
		pts.append(p)
		for k in [1, 2]:
			var pitch := -droop * float(k) / 2.0
			p += (radial * cos(pitch) + axis * sin(pitch)).normalized() * length * 0.5
			pts.append(p)
		var tone := rng.randf_range(0.92, 1.0)
		_strand(
			b,
			pts,
			length * 0.17,
			CityForbMeshes.DAISY_RAY * tone,
			Vector2(flex, flex),
			0.65,
			axis,
			0.0,
			0.15
		)
	# Conical receptacle of packed yellow florets, greener at the base.
	CityForbMeshes._dome(
		b,
		top,
		frame,
		axis,
		disc_r,
		cone,
		8,
		2,
		func(f: float) -> Color:
			return CHAMOMILE_DISC.lerp(Color(0.62, 0.62, 0.20), smoothstep(0.6, 1.0, f)),
		flex,
		0.2,
		0.2
	)


# --- Yarrow (Achillea millefolium) ------------------------------------------
# Long, narrow, very finely divided "thousand-leaf" leaves, a dense rosette
# with one to three stiff, downy stems 30-60 cm high, each topped by a flat
# corymb of many tiny off-white heads with cream centres.


static func _yarrow(b: CityForbMeshes.Builder, rng: RandomNumberGenerator, stage: int) -> void:
	var basal := rng.randi_range(5, 7)
	for i in basal:
		var yaw := TAU * float(i) / float(basal) + rng.randf_range(-0.3, 0.3)
		_pinnate_leaf(
			b,
			rng,
			Vector3.UP * 0.004,
			yaw,
			rng.randf_range(0.6, 1.0),
			rng.randf_range(0.6, 1.0),
			rng.randf_range(0.09, 0.14),
			9,
			0.011,
			0.0012,
			YARROW_LEAF * rng.randf_range(0.92, 1.06),
			Vector2(0.0, 0.25),
			true
		)
	var stems := rng.randi_range(1, 3)
	for i in stems:
		var yaw := TAU * (float(i) + rng.randf()) / float(stems)
		var out := Vector3(cos(yaw), 0.0, sin(yaw))
		var height := rng.randf_range(0.34, 0.52)
		var stem_rng := CityForbMeshes._child_rng(rng)
		var head_rng := CityForbMeshes._child_rng(rng)
		if stage == STAGE_LEAVES:
			continue
		var stem := _stem(
			b,
			out * 0.006,
			out * rng.randf_range(0.01, 0.04),
			height,
			0.0026,
			0.0016,
			YARROW_STEM,
			1.1
		)
		# Alternate stem leaves, shorter up the stem; the far variant keeps two.
		for k: int in [1, 2, 3, 4]:
			if CityForbMeshes._far and k % 2 == 0:
				continue
			var flex := float(k) / 6.0 * 1.1
			_pinnate_leaf(
				b,
				stem_rng,
				stem[k],
				yaw + float(k) * 2.4,
				0.5,
				0.3,
				lerpf(0.075, 0.04, float(k) / 4.0),
				7,
				0.009,
				0.001,
				YARROW_LEAF,
				Vector2(flex, flex + 0.2),
				true
			)
		_corymb(b, head_rng, stem, 1.1)


## A flat-topped corymb: branches leave the upper stem at different heights and
## all reach the same plane, each ending in a tuft of tiny heads.
static func _corymb(
	b: CityForbMeshes.Builder, rng: RandomNumberGenerator, stem: PackedVector3Array, flex: float
) -> void:
	var top := stem[stem.size() - 1]
	var plane := top.y + 0.005
	var spread := rng.randf_range(0.036, 0.05)
	var branches := rng.randi_range(7, 9)
	for i in branches:
		var a := float(i) * 2.39996 + rng.randf_range(-0.2, 0.2)
		var r := spread * sqrt((float(i) + 0.5) / float(branches))
		var tip := Vector3(
			top.x + cos(a) * r, plane - rng.randf_range(0.0, 0.006), top.z + sin(a) * r
		)
		var from := stem[stem.size() - 2].lerp(top, rng.randf_range(0.2, 0.9))
		if not CityForbMeshes._far:
			_strand(
				b,
				PackedVector3Array([from, from.lerp(tip, 0.5) + Vector3.UP * 0.004, tip]),
				0.0008,
				YARROW_STEM,
				Vector2(flex * 0.9, flex),
				0.2,
				Vector3.UP,
				0.0,
				0.2
			)
		var heads := rng.randi_range(7, 10)
		for k in heads:
			var off := (
				Vector2.from_angle(float(k) * 2.4 + a) * 0.0075 * sqrt(float(k) / float(heads))
			)
			var c := tip + Vector3(off.x, rng.randf_range(0.0, 0.002), off.y)
			if CityForbMeshes._far and k > 0:
				continue
			var radius := 0.004 if not CityForbMeshes._far else spread * 0.45
			_floret_dot(b, c, Vector3.UP, radius, YARROW_CENTRE, YARROW_WHITE, flex)


# --- St John's wort (Hypericum perforatum) ----------------------------------
# One to three stiff, two-ridged stems 35-60 cm high with small, oblong,
# stalkless leaves in opposite pairs (held up against the light they show the
# translucent dots that name it "perforatum"), branching at the top into a broad
# cyme of bright yellow, five-petalled star flowers with a bushy tuft of
# stamens, among rusty-red buds. In flower round Jaanipaev (24 June).


static func _st_johns_wort(
	b: CityForbMeshes.Builder, rng: RandomNumberGenerator, stage: int
) -> void:
	var stems := rng.randi_range(2, 3)
	for i in stems:
		var yaw := TAU * (float(i) + rng.randf()) / float(stems)
		var out := Vector3(cos(yaw), 0.0, sin(yaw))
		var height := rng.randf_range(0.36, 0.55)
		var stem := _stem(
			b,
			out * 0.008,
			out * rng.randf_range(0.01, 0.05),
			height,
			0.0026,
			0.0015,
			HYPERICUM_STEM,
			1.1
		)
		var leaf_rng := CityForbMeshes._child_rng(rng)
		var head_rng := CityForbMeshes._child_rng(rng)
		# Decussate pairs up the stem, each pair turned a quarter from the last.
		for k in range(1, stem.size() - 1):
			if CityForbMeshes._far and k % 2 == 0:
				continue
			var flex := float(k) / float(stem.size() - 1) * 1.1
			var size := leaf_rng.randf_range(0.025, 0.033) * lerpf(1.0, 0.7, float(k) / 6.0)
			for s: float in [0.0, PI]:
				# The far variant keeps one leaf of every other pair.
				if CityForbMeshes._far and s > 0.0:
					continue
				_small_leaf(
					b,
					leaf_rng,
					stem[k],
					yaw + s + float(k) * PI * 0.5,
					size,
					0.32,
					HYPERICUM_LEAF,
					flex,
					true
				)
		if stage == STAGE_LEAVES:
			continue
		# The cyme: opposite branches from the top three nodes, each forking into
		# a few flowers; flowers face up and out so the yellow reads from above.
		var top := stem[stem.size() - 1]
		for k: int in [stem.size() - 3, stem.size() - 2, stem.size() - 1]:
			for s: float in [0.0, PI]:
				var a := yaw + s + float(k) * PI * 0.5 + head_rng.randf_range(-0.3, 0.3)
				var dir := Vector3(cos(a), 0.0, sin(a))
				var tip := (
					stem[k]
					+ dir * head_rng.randf_range(0.025, 0.045)
					+ Vector3.UP * (top.y + 0.02 - stem[k].y)
				)
				if not CityForbMeshes._far:
					_strand(
						b,
						PackedVector3Array(
							[stem[k], stem[k].lerp(tip, 0.5) + Vector3.UP * 0.01, tip]
						),
						0.0009,
						HYPERICUM_STEM,
						Vector2(1.0, 1.15),
						0.2,
						Vector3.UP,
						0.0,
						0.2
					)
				for f in 3:
					var q := (
						tip
						+ Vector3(cos(a + float(f) * 2.1), 0.0, sin(a + float(f) * 2.1)) * 0.009
						+ Vector3.UP * head_rng.randf_range(0.0, 0.008)
					)
					var face := (Vector3.UP * 2.0 + dir).normalized()
					if head_rng.randf() < 0.3:
						_floret_dot(b, q, face, 0.0028, HYPERICUM_BUD, HYPERICUM_BUD, 1.15)
					else:
						_star_flower(b, head_rng, q, face, 1.15)


## A five-petalled yellow star (St John's wort): narrow oval petals with a
## slight twist, a bushy tuft of stamens in the middle.
static func _star_flower(
	b: CityForbMeshes.Builder,
	rng: RandomNumberGenerator,
	centre: Vector3,
	axis: Vector3,
	flex: float
) -> void:
	var frame := CityForbMeshes._frame(axis)
	var petal := rng.randf_range(0.0085, 0.011)
	if CityForbMeshes._far:
		CityForbMeshes._dome(
			b,
			centre,
			frame,
			axis,
			petal,
			0.001,
			5,
			1,
			func(_f: float) -> Color: return HYPERICUM_PETAL,
			flex,
			0.5
		)
		return
	var turn := rng.randf() * TAU
	for k in 5:
		var a := turn + TAU * float(k) / 5.0
		var radial: Vector3 = frame[0] * cos(a) + frame[1] * sin(a)
		var pts := PackedVector3Array(
			[centre, centre + radial * petal * 0.5 + axis * 0.0012, centre + radial * petal]
		)
		_strand(
			b,
			pts,
			petal * 0.32,
			HYPERICUM_PETAL * rng.randf_range(0.94, 1.02),
			Vector2(flex, flex),
			0.6,
			axis,
			0.0,
			0.35
		)
	CityForbMeshes._dome(
		b,
		centre + axis * 0.001,
		frame,
		axis,
		petal * 0.42,
		petal * 0.35,
		6,
		1,
		func(f: float) -> Color: return HYPERICUM_STAMEN.lerp(HYPERICUM_PETAL, f),
		flex,
		0.4,
		0.6
	)


# --- Caraway (Carum carvi) --------------------------------------------------
# A biennial of hay meadows: a rosette of carrot-like, two- to three-times
# pinnate leaves, then a hollow, branched stem 30-60 cm high with compound
# umbels of tiny white-pink flowers in June, turning into umbels of ribbed
# brown seeds in July-August.


static func _caraway(b: CityForbMeshes.Builder, rng: RandomNumberGenerator, stage: int) -> void:
	var basal := rng.randi_range(5, 7)
	for i in basal:
		var yaw := TAU * float(i) / float(basal) + rng.randf_range(-0.3, 0.3)
		_pinnate_leaf(
			b,
			rng,
			Vector3.UP * 0.004,
			yaw,
			rng.randf_range(0.6, 1.0),
			rng.randf_range(0.6, 0.9),
			rng.randf_range(0.10, 0.15),
			6,
			0.022,
			0.0012,
			CARAWAY_LEAF * rng.randf_range(0.92, 1.06),
			Vector2(0.0, 0.3),
			true
		)
	var height := rng.randf_range(0.36, 0.52)
	var lean := Vector3(rng.randf_range(-0.04, 0.04), 0.0, rng.randf_range(-0.04, 0.04))
	var stem_rng := CityForbMeshes._child_rng(rng)
	var head_rng := CityForbMeshes._child_rng(rng)
	if stage == STAGE_LEAVES:
		return
	var stem := _stem(b, Vector3.ZERO, lean, height, 0.003, 0.0016, CARAWAY_STEM, 1.1)
	var seeded := stage == STAGE_SEED
	_umbel(b, head_rng, stem[stem.size() - 1], Vector3.UP, 0.04, seeded, 1.1)
	# Two or three side branches from the upper nodes, each with a smaller umbel
	# a little below the main one.
	var sides := stem_rng.randi_range(2, 3)
	for i in sides:
		var k := 3 + i
		var yaw := float(i) * 2.4 + stem_rng.randf_range(-0.4, 0.4)
		var out := Vector3(cos(yaw), 0.0, sin(yaw))
		var tip := (
			stem[k]
			+ out * stem_rng.randf_range(0.06, 0.1)
			+ Vector3.UP * (height - stem[k].y) * stem_rng.randf_range(0.6, 0.9)
		)
		var flex := float(k) / 6.0 * 1.1
		CityForbMeshes._tube(
			b,
			PackedVector3Array([stem[k], stem[k].lerp(tip, 0.5), tip]),
			PackedFloat32Array([0.0016, 0.0013, 0.001]),
			4,
			func(_t: float) -> Color: return CARAWAY_STEM,
			flex * 0.8,
			flex + 0.1,
			0.2
		)
		if not CityForbMeshes._far or i == 0:
			_pinnate_leaf(
				b,
				stem_rng,
				stem[k],
				yaw + PI,
				0.5,
				0.4,
				0.05,
				4,
				0.012,
				0.001,
				CARAWAY_LEAF,
				Vector2(flex * 0.8, flex),
				true
			)
		_umbel(b, head_rng, tip, (Vector3.UP * 3.0 + out).normalized(), 0.03, seeded, flex + 0.1)


## A compound umbel: rays from one point to umbellets of tiny flowers (or seed
## pairs). `size` is the umbel radius.
static func _umbel(
	b: CityForbMeshes.Builder,
	rng: RandomNumberGenerator,
	top: Vector3,
	axis: Vector3,
	size: float,
	seeded: bool,
	flex: float
) -> void:
	var frame := CityForbMeshes._frame(axis)
	var rays := rng.randi_range(8, 11)
	for i in rays:
		var a := TAU * (float(i) + rng.randf_range(-0.25, 0.25)) / float(rays)
		var radial: Vector3 = frame[0] * cos(a) + frame[1] * sin(a)
		var reach := size * rng.randf_range(0.65, 1.0)
		# Rays of unequal length rise to a shallow dome.
		var tip := top + radial * reach + axis * size * rng.randf_range(0.45, 0.65)
		if CityForbMeshes._far:
			if i % 3 == 0:
				_floret_dot(
					b,
					tip,
					axis,
					size * 0.35,
					CARAWAY_SEED if seeded else CARAWAY_FLOWER,
					CARAWAY_SEED if seeded else CARAWAY_FLOWER,
					flex
				)
			continue
		_strand(
			b,
			PackedVector3Array([top, top.lerp(tip, 0.5) + axis * size * 0.05, tip]),
			0.0006,
			CARAWAY_STEM,
			Vector2(flex, flex),
			0.2,
			axis,
			0.0,
			0.0
		)
		var flowers := rng.randi_range(6, 9)
		for k in flowers:
			var off := (
				Vector2.from_angle(float(k) * 2.39996 + a)
				* size
				* 0.16
				* sqrt((float(k) + 0.5) / float(flowers))
			)
			var c: Vector3 = tip + frame[0] * off.x + frame[1] * off.y + axis * 0.002
			if seeded:
				# Paired, ribbed, crescent fruits: a little elongated brown ovoid.
				CityForbMeshes._blob(
					b,
					c,
					Vector3(0.0012, 0.0024, 0.0012),
					2,
					4,
					func(d: Vector3) -> Color: return CARAWAY_SEED.lightened(0.15 * d.y),
					0.1,
					flex,
					0.1
				)
			else:
				_floret_dot(b, c, axis, 0.0022, Color(0.86, 0.78, 0.74), CARAWAY_FLOWER, flex)


# --- Shared helpers (also used by city_weed_meshes.gd) ----------------------


## A stem from `base` rising `height` with a curving `lean` at the top: a
## tapered tube of 7 rings; returns its centre line for leaves and branches.
static func _stem(
	b: CityForbMeshes.Builder,
	base: Vector3,
	lean: Vector3,
	height: float,
	r0: float,
	r1: float,
	color: Color,
	flex: float,
	sides: int = 5
) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	for k in 7:
		var t := float(k) / 6.0
		pts.append(base + lean * t * t + Vector3.UP * height * t)
		radii.append(lerpf(r0, r1, t))
	CityForbMeshes._tube(
		b,
		pts,
		radii,
		sides,
		func(t: float) -> Color:
			return color.lerp(color.darkened(0.25), 1.0 - smoothstep(0.0, 0.2, t)),
		0.0,
		flex,
		0.25
	)
	return pts


## A thin strip through `pts` with flex rising root to tip (CityForbMeshes
## _ribbon has one flex per ribbon). Narrows by `taper` toward the tip.
static func _strand(
	b: CityForbMeshes.Builder,
	pts: PackedVector3Array,
	half_width: float,
	color: Color,
	flex: Vector2,
	trans: float,
	facing: Vector3,
	under: float,
	taper: float = 0.6
) -> void:
	var prev := PackedInt32Array()
	for i in pts.size():
		var t := float(i) / float(pts.size() - 1)
		var tangent := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var side := tangent.cross(facing)
		if side.length_squared() < 0.0001:
			side = CityForbMeshes._frame(tangent)[0]
		side = side.normalized()
		var w := half_width * (1.0 - taper * t)
		var f := lerpf(flex.x, flex.y, t)
		var row := PackedInt32Array(
			[
				b.vertex(pts[i] - side * w, color, f, under, trans),
				b.vertex(pts[i] + side * w, color, f, under, trans),
			]
		)
		if not prev.is_empty():
			b.quad(prev[0], prev[1], row[1], row[0], facing)
		prev = row


## A finely divided (pinnate) leaf: a thin rachis with `pairs` of narrow pinnae,
## each split into two side lobes when `split` (chamomile, yarrow, caraway).
## The far variant is a single narrow strip of the same outline.
static func _pinnate_leaf(
	b: CityForbMeshes.Builder,
	rng: RandomNumberGenerator,
	base: Vector3,
	yaw: float,
	rise: float,
	droop: float,
	length: float,
	pairs: int,
	pinna: float,
	width: float,
	color: Color,
	flex: Vector2,
	split: bool
) -> void:
	var forward_h := Vector3(cos(yaw), 0.0, sin(yaw))
	var side := Vector3(-sin(yaw), 0.0, cos(yaw))
	var tone := rng.randf_range(0.94, 1.06)
	if CityForbMeshes._far:
		CityForbMeshes._strip_leaf(
			b,
			{
				"base": base,
				"yaw": yaw,
				"rise": rise,
				"droop": droop,
				"length": length,
				"samples": PackedFloat32Array([0.0, 0.5, 1.0]),
				"cols": 3,
				"fold": 0.1,
				"width":
				func(t: float) -> float: return pinna * 0.6 * sin(PI * minf(t * 0.85 + 0.12, 1.0)),
				"color": func(_t: float, _s: float) -> Color: return color * tone,
				"flex": flex,
				"under": 0.2,
				"trans": 0.3,
			}
		)
		return
	var rachis := PackedVector3Array()
	var fwds: Array[Vector3] = []
	var p := base
	for i in pairs + 2:
		var t := float(i) / float(pairs + 1)
		var pitch := rise - droop * t
		var fwd := forward_h * cos(pitch) + Vector3.UP * sin(pitch)
		if i > 0:
			p += fwd * length / float(pairs + 1)
		rachis.append(p)
		fwds.append(fwd)
	var up := side.cross(fwds[0])
	_strand(b, rachis, width, color * tone, flex, 0.3, up, 0.2, 0.5)
	for i in pairs:
		var t := float(i + 1) / float(pairs + 1)
		var at := rachis[i + 1]
		var fwd := fwds[i + 1]
		var leaf_up := side.cross(fwd)
		# Pinnae longest at mid-leaf, pointing forward and a little up.
		var reach := pinna * (0.45 + 0.55 * sin(PI * minf(t * 0.9 + 0.1, 1.0)))
		var f := lerpf(flex.x, flex.y, t)
		for s: float in [-1.0, 1.0]:
			var dir := (fwd * 0.55 + side * s + leaf_up * 0.15).normalized()
			var tip := at + dir * reach
			_strand(
				b,
				PackedVector3Array([at, tip]),
				width * 1.3,
				color * tone,
				Vector2(f, f + 0.05),
				0.35,
				leaf_up,
				0.25,
				0.7
			)
			if split:
				var mid := at.lerp(tip, 0.5)
				for lobe: float in [-0.6, 0.6]:
					var d := (dir + fwd * lobe * s + side * s * 0.2).normalized()
					_strand(
						b,
						PackedVector3Array([mid, mid + d * reach * 0.45]),
						width,
						color * tone,
						Vector2(f + 0.02, f + 0.05),
						0.35,
						leaf_up,
						0.25,
						0.7
					)


## A small stalkless leaf on a stem node (St John's wort, mint): an oblong
## blade held up from the stem at `pitch`; `dotted` adds the pale translucent
## speckle of Hypericum.
static func _small_leaf(
	b: CityForbMeshes.Builder,
	rng: RandomNumberGenerator,
	at: Vector3,
	yaw: float,
	size: float,
	pitch: float,
	color: Color,
	flex: float,
	dotted: bool,
	serrate: float = 0.0
) -> void:
	var tone := rng.randf_range(0.9, 1.08)
	var speck_seed := rng.randi() % 997
	CityForbMeshes._strip_leaf(
		b,
		{
			"base": at,
			"yaw": yaw,
			"rise": pitch,
			"droop": rng.randf_range(0.2, 0.5),
			"length": size,
			"samples": PackedFloat32Array([0.0, 0.15, 0.4, 0.65, 0.85, 1.0]),
			"cols": 3,
			"fold": 0.2,
			"width":
			## Detailed procedural models of the meadow herbs round Reval (R-2128):
			## chamomile, yarrow, St John's wort and caraway, with their seasonal variants.
			## Built and cached through CityForbMeshes.mesh_for, which sets the far flag
			## (CityForbMeshes._far) and owns the vertex contract; this file holds only the
			## botany, plus the feathery-leaf, strand and floret helpers the weeds in
			## city_weed_meshes.gd share. Original geometry only, deterministic: every
			## seasonal variant of a species reuses the flowering kind's seed, so it is the
			## same plant in another season.
			## Growth stages a kind is built for.
			## Out of flower: the leafy plant without heads (young or cut back).
			## Ripening fruit: caraway seed umbels, thistledown.
			## Dead standing stalks in autumn (mugwort).
			## Young spring shoots (nettle).
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Off-white like the daisy rays (pure white clips under the city grade), with
			# the cream-grey centre of each tiny head.
			## Builds `kind` into `b` if it is one of this file's herbs (false otherwise).
			# --- Chamomile (Matricaria chamomilla) --------------------------------------
			# A bushy, much-branched annual 20-40 cm high with thread-fine, two- to three-
			# times divided leaves; every branch ends in a small head: 12-16 white rays
			# that fold back (reflexed) under a tall, hollow, conical golden disc. Out of
			# flower: a low tuft of feathery leaves.
			# Draw the stems' numbers in every season, so the tuft is the same plant.
			# Branches leave the main stem from a third of its height up and reach about
			# as high as it, so the heads stand in a loose, uneven dome.
			# About 1.3x life size, like the other forbs: a 2 cm head.
			# The rays fold back: each starts level under the cone and bends down.
			# Conical receptacle of packed yellow florets, greener at the base.
			# --- Yarrow (Achillea millefolium) ------------------------------------------
			# Long, narrow, very finely divided "thousand-leaf" leaves, a dense rosette
			# with one to three stiff, downy stems 30-60 cm high, each topped by a flat
			# corymb of many tiny off-white heads with cream centres.
			# Alternate stem leaves, shorter up the stem; the far variant keeps two.
			## A flat-topped corymb: branches leave the upper stem at different heights and
			## all reach the same plane, each ending in a tuft of tiny heads.
			# --- St John's wort (Hypericum perforatum) ----------------------------------
			# One to three stiff, two-ridged stems 35-60 cm high with small, oblong,
			# stalkless leaves in opposite pairs (held up against the light they show the
			# translucent dots that name it "perforatum"), branching at the top into a broad
			# cyme of bright yellow, five-petalled star flowers with a bushy tuft of
			# stamens, among rusty-red buds. In flower round Jaanipaev (24 June).
			# Decussate pairs up the stem, each pair turned a quarter from the last.
			# The far variant keeps one leaf of every other pair.
			# The cyme: opposite branches from the top three nodes, each forking into
			# a few flowers; flowers face up and out so the yellow reads from above.
			## A five-petalled yellow star (St John's wort): narrow oval petals with a
			## slight twist, a bushy tuft of stamens in the middle.
			# --- Caraway (Carum carvi) --------------------------------------------------
			# A biennial of hay meadows: a rosette of carrot-like, two- to three-times
			# pinnate leaves, then a hollow, branched stem 30-60 cm high with compound
			# umbels of tiny white-pink flowers in June, turning into umbels of ribbed
			# brown seeds in July-August.
			# Two or three side branches from the upper nodes, each with a smaller umbel
			# a little below the main one.
			## A compound umbel: rays from one point to umbellets of tiny flowers (or seed
			## pairs). `size` is the umbel radius.
			# Rays of unequal length rise to a shallow dome.
			# Paired, ribbed, crescent fruits: a little elongated brown ovoid.
			# --- Shared helpers (also used by city_weed_meshes.gd) ----------------------
			## A stem from `base` rising `height` with a curving `lean` at the top: a
			## tapered tube of 7 rings; returns its centre line for leaves and branches.
			## A thin strip through `pts` with flex rising root to tip (CityForbMeshes
			## _ribbon has one flex per ribbon). Narrows by `taper` toward the tip.
			## A finely divided (pinnate) leaf: a thin rachis with `pairs` of narrow pinnae,
			## each split into two side lobes when `split` (chamomile, yarrow, caraway).
			## The far variant is a single narrow strip of the same outline.
			# Pinnae longest at mid-leaf, pointing forward and a little up.
			## A small stalkless leaf on a stem node (St John's wort, mint): an oblong
			## blade held up from the stem at `pitch`; `dotted` adds the pale translucent
			## speckle of Hypericum.
			## Detailed procedural models of the meadow herbs round Reval (R-2128):
			## chamomile, yarrow, St John's wort and caraway, with their seasonal variants.
			## Built and cached through CityForbMeshes.mesh_for, which sets the far flag
			## (CityForbMeshes._far) and owns the vertex contract; this file holds only the
			## botany, plus the feathery-leaf, strand and floret helpers the weeds in
			## city_weed_meshes.gd share. Original geometry only, deterministic: every
			## seasonal variant of a species reuses the flowering kind's seed, so it is the
			## same plant in another season.
			## Growth stages a kind is built for.
			## Out of flower: the leafy plant without heads (young or cut back).
			## Ripening fruit: caraway seed umbels, thistledown.
			## Dead standing stalks in autumn (mugwort).
			## Young spring shoots (nettle).
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Off-white like the daisy rays (pure white clips under the city grade), with
			# the cream-grey centre of each tiny head.
			## Builds `kind` into `b` if it is one of this file's herbs (false otherwise).
			# --- Chamomile (Matricaria chamomilla) --------------------------------------
			# A bushy, much-branched annual 20-40 cm high with thread-fine, two- to three-
			# times divided leaves; every branch ends in a small head: 12-16 white rays
			# that fold back (reflexed) under a tall, hollow, conical golden disc. Out of
			# flower: a low tuft of feathery leaves.
			# Draw the stems' numbers in every season, so the tuft is the same plant.
			# Branches leave the main stem from a third of its height up and reach about
			# as high as it, so the heads stand in a loose, uneven dome.
			# About 1.3x life size, like the other forbs: a 2 cm head.
			# The rays fold back: each starts level under the cone and bends down.
			# Conical receptacle of packed yellow florets, greener at the base.
			# --- Yarrow (Achillea millefolium) ------------------------------------------
			# Long, narrow, very finely divided "thousand-leaf" leaves, a dense rosette
			# with one to three stiff, downy stems 30-60 cm high, each topped by a flat
			# corymb of many tiny off-white heads with cream centres.
			# Alternate stem leaves, shorter up the stem; the far variant keeps two.
			## A flat-topped corymb: branches leave the upper stem at different heights and
			## all reach the same plane, each ending in a tuft of tiny heads.
			# --- St John's wort (Hypericum perforatum) ----------------------------------
			# One to three stiff, two-ridged stems 35-60 cm high with small, oblong,
			# stalkless leaves in opposite pairs (held up against the light they show the
			# translucent dots that name it "perforatum"), branching at the top into a broad
			# cyme of bright yellow, five-petalled star flowers with a bushy tuft of
			# stamens, among rusty-red buds. In flower round Jaanipaev (24 June).
			# Decussate pairs up the stem, each pair turned a quarter from the last.
			# The far variant keeps one leaf of every other pair.
			# The cyme: opposite branches from the top three nodes, each forking into
			# a few flowers; flowers face up and out so the yellow reads from above.
			## A five-petalled yellow star (St John's wort): narrow oval petals with a
			## slight twist, a bushy tuft of stamens in the middle.
			# --- Caraway (Carum carvi) --------------------------------------------------
			# A biennial of hay meadows: a rosette of carrot-like, two- to three-times
			# pinnate leaves, then a hollow, branched stem 30-60 cm high with compound
			# umbels of tiny white-pink flowers in June, turning into umbels of ribbed
			# brown seeds in July-August.
			# Two or three side branches from the upper nodes, each with a smaller umbel
			# a little below the main one.
			## A compound umbel: rays from one point to umbellets of tiny flowers (or seed
			## pairs). `size` is the umbel radius.
			# Rays of unequal length rise to a shallow dome.
			# Paired, ribbed, crescent fruits: a little elongated brown ovoid.
			# --- Shared helpers (also used by city_weed_meshes.gd) ----------------------
			## A stem from `base` rising `height` with a curving `lean` at the top: a
			## tapered tube of 7 rings; returns its centre line for leaves and branches.
			## A thin strip through `pts` with flex rising root to tip (CityForbMeshes
			## _ribbon has one flex per ribbon). Narrows by `taper` toward the tip.
			## A finely divided (pinnate) leaf: a thin rachis with `pairs` of narrow pinnae,
			## each split into two side lobes when `split` (chamomile, yarrow, caraway).
			## The far variant is a single narrow strip of the same outline.
			# Pinnae longest at mid-leaf, pointing forward and a little up.
			## A small stalkless leaf on a stem node (St John's wort, mint): an oblong
			## blade held up from the stem at `pitch`; `dotted` adds the pale translucent
			## speckle of Hypericum.
			## Detailed procedural models of the meadow herbs round Reval (R-2128):
			## chamomile, yarrow, St John's wort and caraway, with their seasonal variants.
			## Built and cached through CityForbMeshes.mesh_for, which sets the far flag
			## (CityForbMeshes._far) and owns the vertex contract; this file holds only the
			## botany, plus the feathery-leaf, strand and floret helpers the weeds in
			## city_weed_meshes.gd share. Original geometry only, deterministic: every
			## seasonal variant of a species reuses the flowering kind's seed, so it is the
			## same plant in another season.
			## Growth stages a kind is built for.
			## Out of flower: the leafy plant without heads (young or cut back).
			## Ripening fruit: caraway seed umbels, thistledown.
			## Dead standing stalks in autumn (mugwort).
			## Young spring shoots (nettle).
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Off-white like the daisy rays (pure white clips under the city grade), with
			# the cream-grey centre of each tiny head.
			## Builds `kind` into `b` if it is one of this file's herbs (false otherwise).
			# --- Chamomile (Matricaria chamomilla) --------------------------------------
			# A bushy, much-branched annual 20-40 cm high with thread-fine, two- to three-
			# times divided leaves; every branch ends in a small head: 12-16 white rays
			# that fold back (reflexed) under a tall, hollow, conical golden disc. Out of
			# flower: a low tuft of feathery leaves.
			# Draw the stems' numbers in every season, so the tuft is the same plant.
			# Branches leave the main stem from a third of its height up and reach about
			# as high as it, so the heads stand in a loose, uneven dome.
			# About 1.3x life size, like the other forbs: a 2 cm head.
			# The rays fold back: each starts level under the cone and bends down.
			# Conical receptacle of packed yellow florets, greener at the base.
			# --- Yarrow (Achillea millefolium) ------------------------------------------
			# Long, narrow, very finely divided "thousand-leaf" leaves, a dense rosette
			# with one to three stiff, downy stems 30-60 cm high, each topped by a flat
			# corymb of many tiny off-white heads with cream centres.
			# Alternate stem leaves, shorter up the stem; the far variant keeps two.
			## A flat-topped corymb: branches leave the upper stem at different heights and
			## all reach the same plane, each ending in a tuft of tiny heads.
			# --- St John's wort (Hypericum perforatum) ----------------------------------
			# One to three stiff, two-ridged stems 35-60 cm high with small, oblong,
			# stalkless leaves in opposite pairs (held up against the light they show the
			# translucent dots that name it "perforatum"), branching at the top into a broad
			# cyme of bright yellow, five-petalled star flowers with a bushy tuft of
			# stamens, among rusty-red buds. In flower round Jaanipaev (24 June).
			# Decussate pairs up the stem, each pair turned a quarter from the last.
			# The far variant keeps one leaf of every other pair.
			# The cyme: opposite branches from the top three nodes, each forking into
			# a few flowers; flowers face up and out so the yellow reads from above.
			## A five-petalled yellow star (St John's wort): narrow oval petals with a
			## slight twist, a bushy tuft of stamens in the middle.
			# --- Caraway (Carum carvi) --------------------------------------------------
			# A biennial of hay meadows: a rosette of carrot-like, two- to three-times
			# pinnate leaves, then a hollow, branched stem 30-60 cm high with compound
			# umbels of tiny white-pink flowers in June, turning into umbels of ribbed
			# brown seeds in July-August.
			# Two or three side branches from the upper nodes, each with a smaller umbel
			# a little below the main one.
			## A compound umbel: rays from one point to umbellets of tiny flowers (or seed
			## pairs). `size` is the umbel radius.
			# Rays of unequal length rise to a shallow dome.
			# Paired, ribbed, crescent fruits: a little elongated brown ovoid.
			# --- Shared helpers (also used by city_weed_meshes.gd) ----------------------
			## A stem from `base` rising `height` with a curving `lean` at the top: a
			## tapered tube of 7 rings; returns its centre line for leaves and branches.
			## A thin strip through `pts` with flex rising root to tip (CityForbMeshes
			## _ribbon has one flex per ribbon). Narrows by `taper` toward the tip.
			## A finely divided (pinnate) leaf: a thin rachis with `pairs` of narrow pinnae,
			## each split into two side lobes when `split` (chamomile, yarrow, caraway).
			## The far variant is a single narrow strip of the same outline.
			# Pinnae longest at mid-leaf, pointing forward and a little up.
			## A small stalkless leaf on a stem node (St John's wort, mint): an oblong
			## blade held up from the stem at `pitch`; `dotted` adds the pale translucent
			## speckle of Hypericum.
			func(t: float) -> float:
# gdlint:disable=max-file-lines

## Detailed procedural models of the meadow herbs round Reval (R-2128):
## chamomile, yarrow, St John's wort and caraway, with their seasonal variants.
## Built and cached through CityForbMeshes.mesh_for, which sets the far flag
## (CityForbMeshes._far) and owns the vertex contract; this file holds only the
## botany, plus the feathery-leaf, strand and floret helpers the weeds in
## city_weed_meshes.gd share. Original geometry only, deterministic: every
## seasonal variant of a species reuses the flowering kind's seed, so it is the
## same plant in another season.

## Growth stages a kind is built for.

## Out of flower: the leafy plant without heads (young or cut back).

## Ripening fruit: caraway seed umbels, thistledown.

## Dead standing stalks in autumn (mugwort).

## Young spring shoots (nettle).

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Off-white like the daisy rays (pure white clips under the city grade), with
# the cream-grey centre of each tiny head.

## Builds `kind` into `b` if it is one of this file's herbs (false otherwise).

# --- Chamomile (Matricaria chamomilla) --------------------------------------
# A bushy, much-branched annual 20-40 cm high with thread-fine, two- to three-
# times divided leaves; every branch ends in a small head: 12-16 white rays
# that fold back (reflexed) under a tall, hollow, conical golden disc. Out of
# flower: a low tuft of feathery leaves.

				# Draw the stems' numbers in every season, so the tuft is the same plant.

				# Branches leave the main stem from a third of its height up and reach about
				# as high as it, so the heads stand in a loose, uneven dome.

				# About 1.3x life size, like the other forbs: a 2 cm head.

				# The rays fold back: each starts level under the cone and bends down.

				# Conical receptacle of packed yellow florets, greener at the base.

# --- Yarrow (Achillea millefolium) ------------------------------------------
# Long, narrow, very finely divided "thousand-leaf" leaves, a dense rosette
# with one to three stiff, downy stems 30-60 cm high, each topped by a flat
# corymb of many tiny off-white heads with cream centres.

				# Alternate stem leaves, shorter up the stem; the far variant keeps two.

## A flat-topped corymb: branches leave the upper stem at different heights and
## all reach the same plane, each ending in a tuft of tiny heads.

# --- St John's wort (Hypericum perforatum) ----------------------------------
# One to three stiff, two-ridged stems 35-60 cm high with small, oblong,
# stalkless leaves in opposite pairs (held up against the light they show the
# translucent dots that name it "perforatum"), branching at the top into a broad
# cyme of bright yellow, five-petalled star flowers with a bushy tuft of
# stamens, among rusty-red buds. In flower round Jaanipaev (24 June).

				# Decussate pairs up the stem, each pair turned a quarter from the last.

				# The far variant keeps one leaf of every other pair.

				# The cyme: opposite branches from the top three nodes, each forking into
				# a few flowers; flowers face up and out so the yellow reads from above.

## A five-petalled yellow star (St John's wort): narrow oval petals with a
## slight twist, a bushy tuft of stamens in the middle.

# --- Caraway (Carum carvi) --------------------------------------------------
# A biennial of hay meadows: a rosette of carrot-like, two- to three-times
# pinnate leaves, then a hollow, branched stem 30-60 cm high with compound
# umbels of tiny white-pink flowers in June, turning into umbels of ribbed
# brown seeds in July-August.

				# Two or three side branches from the upper nodes, each with a smaller umbel
				# a little below the main one.

## A compound umbel: rays from one point to umbellets of tiny flowers (or seed
## pairs). `size` is the umbel radius.

				# Rays of unequal length rise to a shallow dome.

				# Paired, ribbed, crescent fruits: a little elongated brown ovoid.

# --- Shared helpers (also used by city_weed_meshes.gd) ----------------------

## A stem from `base` rising `height` with a curving `lean` at the top: a
## tapered tube of 7 rings; returns its centre line for leaves and branches.

## A thin strip through `pts` with flex rising root to tip (CityForbMeshes
## _ribbon has one flex per ribbon). Narrows by `taper` toward the tip.

## A finely divided (pinnate) leaf: a thin rachis with `pairs` of narrow pinnae,
## each split into two side lobes when `split` (chamomile, yarrow, caraway).
## The far variant is a single narrow strip of the same outline.

				# Pinnae longest at mid-leaf, pointing forward and a little up.

## A small stalkless leaf on a stem node (St John's wort, mint): an oblong
## blade held up from the stem at `pitch`; `dotted` adds the pale translucent
## speckle of Hypericum.

				## Detailed procedural models of the meadow herbs round Reval (R-2128):
				## chamomile, yarrow, St John's wort and caraway, with their seasonal variants.
				## Built and cached through CityForbMeshes.mesh_for, which sets the far flag
				## (CityForbMeshes._far) and owns the vertex contract; this file holds only the
				## botany, plus the feathery-leaf, strand and floret helpers the weeds in
				## city_weed_meshes.gd share. Original geometry only, deterministic: every
				## seasonal variant of a species reuses the flowering kind's seed, so it is the
				## same plant in another season.
				## Growth stages a kind is built for.
				## Out of flower: the leafy plant without heads (young or cut back).
				## Ripening fruit: caraway seed umbels, thistledown.
				## Dead standing stalks in autumn (mugwort).
				## Young spring shoots (nettle).
				## Kind -> [species (seed), stage].
				# Colours are sRGB, picked from field photographs of each species.
				# Off-white like the daisy rays (pure white clips under the city grade), with
				# the cream-grey centre of each tiny head.
				## Builds `kind` into `b` if it is one of this file's herbs (false otherwise).
				# --- Chamomile (Matricaria chamomilla) --------------------------------------
				# A bushy, much-branched annual 20-40 cm high with thread-fine, two- to three-
				# times divided leaves; every branch ends in a small head: 12-16 white rays
				# that fold back (reflexed) under a tall, hollow, conical golden disc. Out of
				# flower: a low tuft of feathery leaves.
				# Draw the stems' numbers in every season, so the tuft is the same plant.
				# Branches leave the main stem from a third of its height up and reach about
				# as high as it, so the heads stand in a loose, uneven dome.
				# About 1.3x life size, like the other forbs: a 2 cm head.
				# The rays fold back: each starts level under the cone and bends down.
				# Conical receptacle of packed yellow florets, greener at the base.
				# --- Yarrow (Achillea millefolium) ------------------------------------------
				# Long, narrow, very finely divided "thousand-leaf" leaves, a dense rosette
				# with one to three stiff, downy stems 30-60 cm high, each topped by a flat
				# corymb of many tiny off-white heads with cream centres.
				# Alternate stem leaves, shorter up the stem; the far variant keeps two.
				## A flat-topped corymb: branches leave the upper stem at different heights and
				## all reach the same plane, each ending in a tuft of tiny heads.
				# --- St John's wort (Hypericum perforatum) ----------------------------------
				# One to three stiff, two-ridged stems 35-60 cm high with small, oblong,
				# stalkless leaves in opposite pairs (held up against the light they show the
				# translucent dots that name it "perforatum"), branching at the top into a broad
				# cyme of bright yellow, five-petalled star flowers with a bushy tuft of
				# stamens, among rusty-red buds. In flower round Jaanipaev (24 June).
				# Decussate pairs up the stem, each pair turned a quarter from the last.
				# The far variant keeps one leaf of every other pair.
				# The cyme: opposite branches from the top three nodes, each forking into
				# a few flowers; flowers face up and out so the yellow reads from above.
				## A five-petalled yellow star (St John's wort): narrow oval petals with a
				## slight twist, a bushy tuft of stamens in the middle.
				# --- Caraway (Carum carvi) --------------------------------------------------
				# A biennial of hay meadows: a rosette of carrot-like, two- to three-times
				# pinnate leaves, then a hollow, branched stem 30-60 cm high with compound
				# umbels of tiny white-pink flowers in June, turning into umbels of ribbed
				# brown seeds in July-August.
				# Two or three side branches from the upper nodes, each with a smaller umbel
				# a little below the main one.
				## A compound umbel: rays from one point to umbellets of tiny flowers (or seed
				## pairs). `size` is the umbel radius.
				# Rays of unequal length rise to a shallow dome.
				# Paired, ribbed, crescent fruits: a little elongated brown ovoid.
				# --- Shared helpers (also used by city_weed_meshes.gd) ----------------------
				## A stem from `base` rising `height` with a curving `lean` at the top: a
				## tapered tube of 7 rings; returns its centre line for leaves and branches.
				## A thin strip through `pts` with flex rising root to tip (CityForbMeshes
				## _ribbon has one flex per ribbon). Narrows by `taper` toward the tip.
				## A finely divided (pinnate) leaf: a thin rachis with `pairs` of narrow pinnae,
				## each split into two side lobes when `split` (chamomile, yarrow, caraway).
				## The far variant is a single narrow strip of the same outline.
				# Pinnae longest at mid-leaf, pointing forward and a little up.
				## A small stalkless leaf on a stem node (St John's wort, mint): an oblong
				## blade held up from the stem at `pitch`; `dotted` adds the pale translucent
				## speckle of Hypericum.

## Detailed procedural models of the meadow herbs round Reval (R-2128):
## chamomile, yarrow, St John's wort and caraway, with their seasonal variants.
## Built and cached through CityForbMeshes.mesh_for, which sets the far flag
## (CityForbMeshes._far) and owns the vertex contract; this file holds only the
## botany, plus the feathery-leaf, strand and floret helpers the weeds in
## city_weed_meshes.gd share. Original geometry only, deterministic: every
## seasonal variant of a species reuses the flowering kind's seed, so it is the
## same plant in another season.

## Growth stages a kind is built for.

## Out of flower: the leafy plant without heads (young or cut back).

## Ripening fruit: caraway seed umbels, thistledown.

## Dead standing stalks in autumn (mugwort).

## Young spring shoots (nettle).

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Off-white like the daisy rays (pure white clips under the city grade), with
# the cream-grey centre of each tiny head.

## Builds `kind` into `b` if it is one of this file's herbs (false otherwise).

# --- Chamomile (Matricaria chamomilla) --------------------------------------
# A bushy, much-branched annual 20-40 cm high with thread-fine, two- to three-
# times divided leaves; every branch ends in a small head: 12-16 white rays
# that fold back (reflexed) under a tall, hollow, conical golden disc. Out of
# flower: a low tuft of feathery leaves.

				# Draw the stems' numbers in every season, so the tuft is the same plant.

				# Branches leave the main stem from a third of its height up and reach about
				# as high as it, so the heads stand in a loose, uneven dome.

				# About 1.3x life size, like the other forbs: a 2 cm head.

				# The rays fold back: each starts level under the cone and bends down.

				# Conical receptacle of packed yellow florets, greener at the base.

# --- Yarrow (Achillea millefolium) ------------------------------------------
# Long, narrow, very finely divided "thousand-leaf" leaves, a dense rosette
# with one to three stiff, downy stems 30-60 cm high, each topped by a flat
# corymb of many tiny off-white heads with cream centres.

				# Alternate stem leaves, shorter up the stem; the far variant keeps two.

## A flat-topped corymb: branches leave the upper stem at different heights and
## all reach the same plane, each ending in a tuft of tiny heads.

# --- St John's wort (Hypericum perforatum) ----------------------------------
# One to three stiff, two-ridged stems 35-60 cm high with small, oblong,
# stalkless leaves in opposite pairs (held up against the light they show the
# translucent dots that name it "perforatum"), branching at the top into a broad
# cyme of bright yellow, five-petalled star flowers with a bushy tuft of
# stamens, among rusty-red buds. In flower round Jaanipaev (24 June).

				# Decussate pairs up the stem, each pair turned a quarter from the last.

				# The far variant keeps one leaf of every other pair.

				# The cyme: opposite branches from the top three nodes, each forking into
				# a few flowers; flowers face up and out so the yellow reads from above.

## A five-petalled yellow star (St John's wort): narrow oval petals with a
## slight twist, a bushy tuft of stamens in the middle.

# --- Caraway (Carum carvi) --------------------------------------------------
# A biennial of hay meadows: a rosette of carrot-like, two- to three-times
# pinnate leaves, then a hollow, branched stem 30-60 cm high with compound
# umbels of tiny white-pink flowers in June, turning into umbels of ribbed
# brown seeds in July-August.

				# Two or three side branches from the upper nodes, each with a smaller umbel
				# a little below the main one.

## A compound umbel: rays from one point to umbellets of tiny flowers (or seed
## pairs). `size` is the umbel radius.

				# Rays of unequal length rise to a shallow dome.

				# Paired, ribbed, crescent fruits: a little elongated brown ovoid.

# --- Shared helpers (also used by city_weed_meshes.gd) ----------------------

## A stem from `base` rising `height` with a curving `lean` at the top: a
## tapered tube of 7 rings; returns its centre line for leaves and branches.

## A thin strip through `pts` with flex rising root to tip (CityForbMeshes
## _ribbon has one flex per ribbon). Narrows by `taper` toward the tip.

## A finely divided (pinnate) leaf: a thin rachis with `pairs` of narrow pinnae,
## each split into two side lobes when `split` (chamomile, yarrow, caraway).
## The far variant is a single narrow strip of the same outline.

				# Pinnae longest at mid-leaf, pointing forward and a little up.

## A small stalkless leaf on a stem node (St John's wort, mint): an oblong
## blade held up from the stem at `pitch`; `dotted` adds the pale translucent
## speckle of Hypericum.

## Detailed procedural models of the meadow herbs round Reval (R-2128):
## chamomile, yarrow, St John's wort and caraway, with their seasonal variants.
## Built and cached through CityForbMeshes.mesh_for, which sets the far flag
## (CityForbMeshes._far) and owns the vertex contract; this file holds only the
## botany, plus the feathery-leaf, strand and floret helpers the weeds in
## city_weed_meshes.gd share. Original geometry only, deterministic: every
## seasonal variant of a species reuses the flowering kind's seed, so it is the
## same plant in another season.

## Growth stages a kind is built for.

## Out of flower: the leafy plant without heads (young or cut back).

## Ripening fruit: caraway seed umbels, thistledown.

## Dead standing stalks in autumn (mugwort).

## Young spring shoots (nettle).

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Off-white like the daisy rays (pure white clips under the city grade), with
# the cream-grey centre of each tiny head.

## Builds `kind` into `b` if it is one of this file's herbs (false otherwise).

# --- Chamomile (Matricaria chamomilla) --------------------------------------
# A bushy, much-branched annual 20-40 cm high with thread-fine, two- to three-
# times divided leaves; every branch ends in a small head: 12-16 white rays
# that fold back (reflexed) under a tall, hollow, conical golden disc. Out of
# flower: a low tuft of feathery leaves.

				# Draw the stems' numbers in every season, so the tuft is the same plant.

				# Branches leave the main stem from a third of its height up and reach about
				# as high as it, so the heads stand in a loose, uneven dome.

				# About 1.3x life size, like the other forbs: a 2 cm head.

				# The rays fold back: each starts level under the cone and bends down.

				# Conical receptacle of packed yellow florets, greener at the base.

# --- Yarrow (Achillea millefolium) ------------------------------------------
# Long, narrow, very finely divided "thousand-leaf" leaves, a dense rosette
# with one to three stiff, downy stems 30-60 cm high, each topped by a flat
# corymb of many tiny off-white heads with cream centres.

				# Alternate stem leaves, shorter up the stem; the far variant keeps two.

## A flat-topped corymb: branches leave the upper stem at different heights and
## all reach the same plane, each ending in a tuft of tiny heads.

# --- St John's wort (Hypericum perforatum) ----------------------------------
# One to three stiff, two-ridged stems 35-60 cm high with small, oblong,
# stalkless leaves in opposite pairs (held up against the light they show the
# translucent dots that name it "perforatum"), branching at the top into a broad
# cyme of bright yellow, five-petalled star flowers with a bushy tuft of
# stamens, among rusty-red buds. In flower round Jaanipaev (24 June).

				# Decussate pairs up the stem, each pair turned a quarter from the last.

				# The far variant keeps one leaf of every other pair.

				# The cyme: opposite branches from the top three nodes, each forking into
				# a few flowers; flowers face up and out so the yellow reads from above.

## A five-petalled yellow star (St John's wort): narrow oval petals with a
## slight twist, a bushy tuft of stamens in the middle.

# --- Caraway (Carum carvi) --------------------------------------------------
# A biennial of hay meadows: a rosette of carrot-like, two- to three-times
# pinnate leaves, then a hollow, branched stem 30-60 cm high with compound
# umbels of tiny white-pink flowers in June, turning into umbels of ribbed
# brown seeds in July-August.

				# Two or three side branches from the upper nodes, each with a smaller umbel
				# a little below the main one.

## A compound umbel: rays from one point to umbellets of tiny flowers (or seed
## pairs). `size` is the umbel radius.

				# Rays of unequal length rise to a shallow dome.

				# Paired, ribbed, crescent fruits: a little elongated brown ovoid.

# --- Shared helpers (also used by city_weed_meshes.gd) ----------------------

## A stem from `base` rising `height` with a curving `lean` at the top: a
## tapered tube of 7 rings; returns its centre line for leaves and branches.

## A thin strip through `pts` with flex rising root to tip (CityForbMeshes
## _ribbon has one flex per ribbon). Narrows by `taper` toward the tip.

## A finely divided (pinnate) leaf: a thin rachis with `pairs` of narrow pinnae,
## each split into two side lobes when `split` (chamomile, yarrow, caraway).
## The far variant is a single narrow strip of the same outline.

				# Pinnae longest at mid-leaf, pointing forward and a little up.

## A small stalkless leaf on a stem node (St John's wort, mint): an oblong
## blade held up from the stem at `pitch`; `dotted` adds the pale translucent
## speckle of Hypericum.

				return (
					size
					* 0.24
					* sin(PI * minf(t * 0.85 + 0.1, 1.0))
					* (1.0 - serrate * absf(sin(t * PI * 6.0)))
				),
			"color":
			## Detailed procedural models of the meadow herbs round Reval (R-2128):
			## chamomile, yarrow, St John's wort and caraway, with their seasonal variants.
			## Built and cached through CityForbMeshes.mesh_for, which sets the far flag
			## (CityForbMeshes._far) and owns the vertex contract; this file holds only the
			## botany, plus the feathery-leaf, strand and floret helpers the weeds in
			## city_weed_meshes.gd share. Original geometry only, deterministic: every
			## seasonal variant of a species reuses the flowering kind's seed, so it is the
			## same plant in another season.
			## Growth stages a kind is built for.
			## Out of flower: the leafy plant without heads (young or cut back).
			## Ripening fruit: caraway seed umbels, thistledown.
			## Dead standing stalks in autumn (mugwort).
			## Young spring shoots (nettle).
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Off-white like the daisy rays (pure white clips under the city grade), with
			# the cream-grey centre of each tiny head.
			## Builds `kind` into `b` if it is one of this file's herbs (false otherwise).
			# --- Chamomile (Matricaria chamomilla) --------------------------------------
			# A bushy, much-branched annual 20-40 cm high with thread-fine, two- to three-
			# times divided leaves; every branch ends in a small head: 12-16 white rays
			# that fold back (reflexed) under a tall, hollow, conical golden disc. Out of
			# flower: a low tuft of feathery leaves.
			# Draw the stems' numbers in every season, so the tuft is the same plant.
			# Branches leave the main stem from a third of its height up and reach about
			# as high as it, so the heads stand in a loose, uneven dome.
			# About 1.3x life size, like the other forbs: a 2 cm head.
			# The rays fold back: each starts level under the cone and bends down.
			# Conical receptacle of packed yellow florets, greener at the base.
			# --- Yarrow (Achillea millefolium) ------------------------------------------
			# Long, narrow, very finely divided "thousand-leaf" leaves, a dense rosette
			# with one to three stiff, downy stems 30-60 cm high, each topped by a flat
			# corymb of many tiny off-white heads with cream centres.
			# Alternate stem leaves, shorter up the stem; the far variant keeps two.
			## A flat-topped corymb: branches leave the upper stem at different heights and
			## all reach the same plane, each ending in a tuft of tiny heads.
			# --- St John's wort (Hypericum perforatum) ----------------------------------
			# One to three stiff, two-ridged stems 35-60 cm high with small, oblong,
			# stalkless leaves in opposite pairs (held up against the light they show the
			# translucent dots that name it "perforatum"), branching at the top into a broad
			# cyme of bright yellow, five-petalled star flowers with a bushy tuft of
			# stamens, among rusty-red buds. In flower round Jaanipaev (24 June).
			# Decussate pairs up the stem, each pair turned a quarter from the last.
			# The far variant keeps one leaf of every other pair.
			# The cyme: opposite branches from the top three nodes, each forking into
			# a few flowers; flowers face up and out so the yellow reads from above.
			## A five-petalled yellow star (St John's wort): narrow oval petals with a
			## slight twist, a bushy tuft of stamens in the middle.
			# --- Caraway (Carum carvi) --------------------------------------------------
			# A biennial of hay meadows: a rosette of carrot-like, two- to three-times
			# pinnate leaves, then a hollow, branched stem 30-60 cm high with compound
			# umbels of tiny white-pink flowers in June, turning into umbels of ribbed
			# brown seeds in July-August.
			# Two or three side branches from the upper nodes, each with a smaller umbel
			# a little below the main one.
			## A compound umbel: rays from one point to umbellets of tiny flowers (or seed
			## pairs). `size` is the umbel radius.
			# Rays of unequal length rise to a shallow dome.
			# Paired, ribbed, crescent fruits: a little elongated brown ovoid.
			# --- Shared helpers (also used by city_weed_meshes.gd) ----------------------
			## A stem from `base` rising `height` with a curving `lean` at the top: a
			## tapered tube of 7 rings; returns its centre line for leaves and branches.
			## A thin strip through `pts` with flex rising root to tip (CityForbMeshes
			## _ribbon has one flex per ribbon). Narrows by `taper` toward the tip.
			## A finely divided (pinnate) leaf: a thin rachis with `pairs` of narrow pinnae,
			## each split into two side lobes when `split` (chamomile, yarrow, caraway).
			## The far variant is a single narrow strip of the same outline.
			# Pinnae longest at mid-leaf, pointing forward and a little up.
			## A small stalkless leaf on a stem node (St John's wort, mint): an oblong
			## blade held up from the stem at `pitch`; `dotted` adds the pale translucent
			## speckle of Hypericum.
			## Detailed procedural models of the meadow herbs round Reval (R-2128):
			## chamomile, yarrow, St John's wort and caraway, with their seasonal variants.
			## Built and cached through CityForbMeshes.mesh_for, which sets the far flag
			## (CityForbMeshes._far) and owns the vertex contract; this file holds only the
			## botany, plus the feathery-leaf, strand and floret helpers the weeds in
			## city_weed_meshes.gd share. Original geometry only, deterministic: every
			## seasonal variant of a species reuses the flowering kind's seed, so it is the
			## same plant in another season.
			## Growth stages a kind is built for.
			## Out of flower: the leafy plant without heads (young or cut back).
			## Ripening fruit: caraway seed umbels, thistledown.
			## Dead standing stalks in autumn (mugwort).
			## Young spring shoots (nettle).
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Off-white like the daisy rays (pure white clips under the city grade), with
			# the cream-grey centre of each tiny head.
			## Builds `kind` into `b` if it is one of this file's herbs (false otherwise).
			# --- Chamomile (Matricaria chamomilla) --------------------------------------
			# A bushy, much-branched annual 20-40 cm high with thread-fine, two- to three-
			# times divided leaves; every branch ends in a small head: 12-16 white rays
			# that fold back (reflexed) under a tall, hollow, conical golden disc. Out of
			# flower: a low tuft of feathery leaves.
			# Draw the stems' numbers in every season, so the tuft is the same plant.
			# Branches leave the main stem from a third of its height up and reach about
			# as high as it, so the heads stand in a loose, uneven dome.
			# About 1.3x life size, like the other forbs: a 2 cm head.
			# The rays fold back: each starts level under the cone and bends down.
			# Conical receptacle of packed yellow florets, greener at the base.
			# --- Yarrow (Achillea millefolium) ------------------------------------------
			# Long, narrow, very finely divided "thousand-leaf" leaves, a dense rosette
			# with one to three stiff, downy stems 30-60 cm high, each topped by a flat
			# corymb of many tiny off-white heads with cream centres.
			# Alternate stem leaves, shorter up the stem; the far variant keeps two.
			## A flat-topped corymb: branches leave the upper stem at different heights and
			## all reach the same plane, each ending in a tuft of tiny heads.
			# --- St John's wort (Hypericum perforatum) ----------------------------------
			# One to three stiff, two-ridged stems 35-60 cm high with small, oblong,
			# stalkless leaves in opposite pairs (held up against the light they show the
			# translucent dots that name it "perforatum"), branching at the top into a broad
			# cyme of bright yellow, five-petalled star flowers with a bushy tuft of
			# stamens, among rusty-red buds. In flower round Jaanipaev (24 June).
			# Decussate pairs up the stem, each pair turned a quarter from the last.
			# The far variant keeps one leaf of every other pair.
			# The cyme: opposite branches from the top three nodes, each forking into
			# a few flowers; flowers face up and out so the yellow reads from above.
			## A five-petalled yellow star (St John's wort): narrow oval petals with a
			## slight twist, a bushy tuft of stamens in the middle.
			# --- Caraway (Carum carvi) --------------------------------------------------
			# A biennial of hay meadows: a rosette of carrot-like, two- to three-times
			# pinnate leaves, then a hollow, branched stem 30-60 cm high with compound
			# umbels of tiny white-pink flowers in June, turning into umbels of ribbed
			# brown seeds in July-August.
			# Two or three side branches from the upper nodes, each with a smaller umbel
			# a little below the main one.
			## A compound umbel: rays from one point to umbellets of tiny flowers (or seed
			## pairs). `size` is the umbel radius.
			# Rays of unequal length rise to a shallow dome.
			# Paired, ribbed, crescent fruits: a little elongated brown ovoid.
			# --- Shared helpers (also used by city_weed_meshes.gd) ----------------------
			## A stem from `base` rising `height` with a curving `lean` at the top: a
			## tapered tube of 7 rings; returns its centre line for leaves and branches.
			## A thin strip through `pts` with flex rising root to tip (CityForbMeshes
			## _ribbon has one flex per ribbon). Narrows by `taper` toward the tip.
			## A finely divided (pinnate) leaf: a thin rachis with `pairs` of narrow pinnae,
			## each split into two side lobes when `split` (chamomile, yarrow, caraway).
			## The far variant is a single narrow strip of the same outline.
			# Pinnae longest at mid-leaf, pointing forward and a little up.
			## A small stalkless leaf on a stem node (St John's wort, mint): an oblong
			## blade held up from the stem at `pitch`; `dotted` adds the pale translucent
			## speckle of Hypericum.
			## Detailed procedural models of the meadow herbs round Reval (R-2128):
			## chamomile, yarrow, St John's wort and caraway, with their seasonal variants.
			## Built and cached through CityForbMeshes.mesh_for, which sets the far flag
			## (CityForbMeshes._far) and owns the vertex contract; this file holds only the
			## botany, plus the feathery-leaf, strand and floret helpers the weeds in
			## city_weed_meshes.gd share. Original geometry only, deterministic: every
			## seasonal variant of a species reuses the flowering kind's seed, so it is the
			## same plant in another season.
			## Growth stages a kind is built for.
			## Out of flower: the leafy plant without heads (young or cut back).
			## Ripening fruit: caraway seed umbels, thistledown.
			## Dead standing stalks in autumn (mugwort).
			## Young spring shoots (nettle).
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Off-white like the daisy rays (pure white clips under the city grade), with
			# the cream-grey centre of each tiny head.
			## Builds `kind` into `b` if it is one of this file's herbs (false otherwise).
			# --- Chamomile (Matricaria chamomilla) --------------------------------------
			# A bushy, much-branched annual 20-40 cm high with thread-fine, two- to three-
			# times divided leaves; every branch ends in a small head: 12-16 white rays
			# that fold back (reflexed) under a tall, hollow, conical golden disc. Out of
			# flower: a low tuft of feathery leaves.
			# Draw the stems' numbers in every season, so the tuft is the same plant.
			# Branches leave the main stem from a third of its height up and reach about
			# as high as it, so the heads stand in a loose, uneven dome.
			# About 1.3x life size, like the other forbs: a 2 cm head.
			# The rays fold back: each starts level under the cone and bends down.
			# Conical receptacle of packed yellow florets, greener at the base.
			# --- Yarrow (Achillea millefolium) ------------------------------------------
			# Long, narrow, very finely divided "thousand-leaf" leaves, a dense rosette
			# with one to three stiff, downy stems 30-60 cm high, each topped by a flat
			# corymb of many tiny off-white heads with cream centres.
			# Alternate stem leaves, shorter up the stem; the far variant keeps two.
			## A flat-topped corymb: branches leave the upper stem at different heights and
			## all reach the same plane, each ending in a tuft of tiny heads.
			# --- St John's wort (Hypericum perforatum) ----------------------------------
			# One to three stiff, two-ridged stems 35-60 cm high with small, oblong,
			# stalkless leaves in opposite pairs (held up against the light they show the
			# translucent dots that name it "perforatum"), branching at the top into a broad
			# cyme of bright yellow, five-petalled star flowers with a bushy tuft of
			# stamens, among rusty-red buds. In flower round Jaanipaev (24 June).
			# Decussate pairs up the stem, each pair turned a quarter from the last.
			# The far variant keeps one leaf of every other pair.
			# The cyme: opposite branches from the top three nodes, each forking into
			# a few flowers; flowers face up and out so the yellow reads from above.
			## A five-petalled yellow star (St John's wort): narrow oval petals with a
			## slight twist, a bushy tuft of stamens in the middle.
			# --- Caraway (Carum carvi) --------------------------------------------------
			# A biennial of hay meadows: a rosette of carrot-like, two- to three-times
			# pinnate leaves, then a hollow, branched stem 30-60 cm high with compound
			# umbels of tiny white-pink flowers in June, turning into umbels of ribbed
			# brown seeds in July-August.
			# Two or three side branches from the upper nodes, each with a smaller umbel
			# a little below the main one.
			## A compound umbel: rays from one point to umbellets of tiny flowers (or seed
			## pairs). `size` is the umbel radius.
			# Rays of unequal length rise to a shallow dome.
			# Paired, ribbed, crescent fruits: a little elongated brown ovoid.
			# --- Shared helpers (also used by city_weed_meshes.gd) ----------------------
			## A stem from `base` rising `height` with a curving `lean` at the top: a
			## tapered tube of 7 rings; returns its centre line for leaves and branches.
			## A thin strip through `pts` with flex rising root to tip (CityForbMeshes
			## _ribbon has one flex per ribbon). Narrows by `taper` toward the tip.
			## A finely divided (pinnate) leaf: a thin rachis with `pairs` of narrow pinnae,
			## each split into two side lobes when `split` (chamomile, yarrow, caraway).
			## The far variant is a single narrow strip of the same outline.
			# Pinnae longest at mid-leaf, pointing forward and a little up.
			## A small stalkless leaf on a stem node (St John's wort, mint): an oblong
			## blade held up from the stem at `pitch`; `dotted` adds the pale translucent
			## speckle of Hypericum.
			## Detailed procedural models of the meadow herbs round Reval (R-2128):
			## chamomile, yarrow, St John's wort and caraway, with their seasonal variants.
			## Built and cached through CityForbMeshes.mesh_for, which sets the far flag
			## (CityForbMeshes._far) and owns the vertex contract; this file holds only the
			## botany, plus the feathery-leaf, strand and floret helpers the weeds in
			## city_weed_meshes.gd share. Original geometry only, deterministic: every
			## seasonal variant of a species reuses the flowering kind's seed, so it is the
			## same plant in another season.
			## Growth stages a kind is built for.
			## Out of flower: the leafy plant without heads (young or cut back).
			## Ripening fruit: caraway seed umbels, thistledown.
			## Dead standing stalks in autumn (mugwort).
			## Young spring shoots (nettle).
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Off-white like the daisy rays (pure white clips under the city grade), with
			# the cream-grey centre of each tiny head.
			## Builds `kind` into `b` if it is one of this file's herbs (false otherwise).
			# --- Chamomile (Matricaria chamomilla) --------------------------------------
			# A bushy, much-branched annual 20-40 cm high with thread-fine, two- to three-
			# times divided leaves; every branch ends in a small head: 12-16 white rays
			# that fold back (reflexed) under a tall, hollow, conical golden disc. Out of
			# flower: a low tuft of feathery leaves.
			# Draw the stems' numbers in every season, so the tuft is the same plant.
			# Branches leave the main stem from a third of its height up and reach about
			# as high as it, so the heads stand in a loose, uneven dome.
			# About 1.3x life size, like the other forbs: a 2 cm head.
			# The rays fold back: each starts level under the cone and bends down.
			# Conical receptacle of packed yellow florets, greener at the base.
			# --- Yarrow (Achillea millefolium) ------------------------------------------
			# Long, narrow, very finely divided "thousand-leaf" leaves, a dense rosette
			# with one to three stiff, downy stems 30-60 cm high, each topped by a flat
			# corymb of many tiny off-white heads with cream centres.
			# Alternate stem leaves, shorter up the stem; the far variant keeps two.
			## A flat-topped corymb: branches leave the upper stem at different heights and
			## all reach the same plane, each ending in a tuft of tiny heads.
			# --- St John's wort (Hypericum perforatum) ----------------------------------
			# One to three stiff, two-ridged stems 35-60 cm high with small, oblong,
			# stalkless leaves in opposite pairs (held up against the light they show the
			# translucent dots that name it "perforatum"), branching at the top into a broad
			# cyme of bright yellow, five-petalled star flowers with a bushy tuft of
			# stamens, among rusty-red buds. In flower round Jaanipaev (24 June).
			# Decussate pairs up the stem, each pair turned a quarter from the last.
			# The far variant keeps one leaf of every other pair.
			# The cyme: opposite branches from the top three nodes, each forking into
			# a few flowers; flowers face up and out so the yellow reads from above.
			## A five-petalled yellow star (St John's wort): narrow oval petals with a
			## slight twist, a bushy tuft of stamens in the middle.
			# --- Caraway (Carum carvi) --------------------------------------------------
			# A biennial of hay meadows: a rosette of carrot-like, two- to three-times
			# pinnate leaves, then a hollow, branched stem 30-60 cm high with compound
			# umbels of tiny white-pink flowers in June, turning into umbels of ribbed
			# brown seeds in July-August.
			# Two or three side branches from the upper nodes, each with a smaller umbel
			# a little below the main one.
			## A compound umbel: rays from one point to umbellets of tiny flowers (or seed
			## pairs). `size` is the umbel radius.
			# Rays of unequal length rise to a shallow dome.
			# Paired, ribbed, crescent fruits: a little elongated brown ovoid.
			# --- Shared helpers (also used by city_weed_meshes.gd) ----------------------
			## A stem from `base` rising `height` with a curving `lean` at the top: a
			## tapered tube of 7 rings; returns its centre line for leaves and branches.
			## A thin strip through `pts` with flex rising root to tip (CityForbMeshes
			## _ribbon has one flex per ribbon). Narrows by `taper` toward the tip.
			## A finely divided (pinnate) leaf: a thin rachis with `pairs` of narrow pinnae,
			## each split into two side lobes when `split` (chamomile, yarrow, caraway).
			## The far variant is a single narrow strip of the same outline.
			# Pinnae longest at mid-leaf, pointing forward and a little up.
			## A small stalkless leaf on a stem node (St John's wort, mint): an oblong
			## blade held up from the stem at `pitch`; `dotted` adds the pale translucent
			## speckle of Hypericum.
			func(t: float, s: float) -> Color:
# gdlint:disable=max-file-lines

## Detailed procedural models of the meadow herbs round Reval (R-2128):
## chamomile, yarrow, St John's wort and caraway, with their seasonal variants.
## Built and cached through CityForbMeshes.mesh_for, which sets the far flag
## (CityForbMeshes._far) and owns the vertex contract; this file holds only the
## botany, plus the feathery-leaf, strand and floret helpers the weeds in
## city_weed_meshes.gd share. Original geometry only, deterministic: every
## seasonal variant of a species reuses the flowering kind's seed, so it is the
## same plant in another season.

## Growth stages a kind is built for.

## Out of flower: the leafy plant without heads (young or cut back).

## Ripening fruit: caraway seed umbels, thistledown.

## Dead standing stalks in autumn (mugwort).

## Young spring shoots (nettle).

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Off-white like the daisy rays (pure white clips under the city grade), with
# the cream-grey centre of each tiny head.

## Builds `kind` into `b` if it is one of this file's herbs (false otherwise).

# --- Chamomile (Matricaria chamomilla) --------------------------------------
# A bushy, much-branched annual 20-40 cm high with thread-fine, two- to three-
# times divided leaves; every branch ends in a small head: 12-16 white rays
# that fold back (reflexed) under a tall, hollow, conical golden disc. Out of
# flower: a low tuft of feathery leaves.

				# Draw the stems' numbers in every season, so the tuft is the same plant.

				# Branches leave the main stem from a third of its height up and reach about
				# as high as it, so the heads stand in a loose, uneven dome.

				# About 1.3x life size, like the other forbs: a 2 cm head.

				# The rays fold back: each starts level under the cone and bends down.

				# Conical receptacle of packed yellow florets, greener at the base.

# --- Yarrow (Achillea millefolium) ------------------------------------------
# Long, narrow, very finely divided "thousand-leaf" leaves, a dense rosette
# with one to three stiff, downy stems 30-60 cm high, each topped by a flat
# corymb of many tiny off-white heads with cream centres.

				# Alternate stem leaves, shorter up the stem; the far variant keeps two.

## A flat-topped corymb: branches leave the upper stem at different heights and
## all reach the same plane, each ending in a tuft of tiny heads.

# --- St John's wort (Hypericum perforatum) ----------------------------------
# One to three stiff, two-ridged stems 35-60 cm high with small, oblong,
# stalkless leaves in opposite pairs (held up against the light they show the
# translucent dots that name it "perforatum"), branching at the top into a broad
# cyme of bright yellow, five-petalled star flowers with a bushy tuft of
# stamens, among rusty-red buds. In flower round Jaanipaev (24 June).

				# Decussate pairs up the stem, each pair turned a quarter from the last.

				# The far variant keeps one leaf of every other pair.

				# The cyme: opposite branches from the top three nodes, each forking into
				# a few flowers; flowers face up and out so the yellow reads from above.

## A five-petalled yellow star (St John's wort): narrow oval petals with a
## slight twist, a bushy tuft of stamens in the middle.

# --- Caraway (Carum carvi) --------------------------------------------------
# A biennial of hay meadows: a rosette of carrot-like, two- to three-times
# pinnate leaves, then a hollow, branched stem 30-60 cm high with compound
# umbels of tiny white-pink flowers in June, turning into umbels of ribbed
# brown seeds in July-August.

				# Two or three side branches from the upper nodes, each with a smaller umbel
				# a little below the main one.

## A compound umbel: rays from one point to umbellets of tiny flowers (or seed
## pairs). `size` is the umbel radius.

				# Rays of unequal length rise to a shallow dome.

				# Paired, ribbed, crescent fruits: a little elongated brown ovoid.

# --- Shared helpers (also used by city_weed_meshes.gd) ----------------------

## A stem from `base` rising `height` with a curving `lean` at the top: a
## tapered tube of 7 rings; returns its centre line for leaves and branches.

## A thin strip through `pts` with flex rising root to tip (CityForbMeshes
## _ribbon has one flex per ribbon). Narrows by `taper` toward the tip.

## A finely divided (pinnate) leaf: a thin rachis with `pairs` of narrow pinnae,
## each split into two side lobes when `split` (chamomile, yarrow, caraway).
## The far variant is a single narrow strip of the same outline.

				# Pinnae longest at mid-leaf, pointing forward and a little up.

## A small stalkless leaf on a stem node (St John's wort, mint): an oblong
## blade held up from the stem at `pitch`; `dotted` adds the pale translucent
## speckle of Hypericum.

				## Detailed procedural models of the meadow herbs round Reval (R-2128):
				## chamomile, yarrow, St John's wort and caraway, with their seasonal variants.
				## Built and cached through CityForbMeshes.mesh_for, which sets the far flag
				## (CityForbMeshes._far) and owns the vertex contract; this file holds only the
				## botany, plus the feathery-leaf, strand and floret helpers the weeds in
				## city_weed_meshes.gd share. Original geometry only, deterministic: every
				## seasonal variant of a species reuses the flowering kind's seed, so it is the
				## same plant in another season.
				## Growth stages a kind is built for.
				## Out of flower: the leafy plant without heads (young or cut back).
				## Ripening fruit: caraway seed umbels, thistledown.
				## Dead standing stalks in autumn (mugwort).
				## Young spring shoots (nettle).
				## Kind -> [species (seed), stage].
				# Colours are sRGB, picked from field photographs of each species.
				# Off-white like the daisy rays (pure white clips under the city grade), with
				# the cream-grey centre of each tiny head.
				## Builds `kind` into `b` if it is one of this file's herbs (false otherwise).
				# --- Chamomile (Matricaria chamomilla) --------------------------------------
				# A bushy, much-branched annual 20-40 cm high with thread-fine, two- to three-
				# times divided leaves; every branch ends in a small head: 12-16 white rays
				# that fold back (reflexed) under a tall, hollow, conical golden disc. Out of
				# flower: a low tuft of feathery leaves.
				# Draw the stems' numbers in every season, so the tuft is the same plant.
				# Branches leave the main stem from a third of its height up and reach about
				# as high as it, so the heads stand in a loose, uneven dome.
				# About 1.3x life size, like the other forbs: a 2 cm head.
				# The rays fold back: each starts level under the cone and bends down.
				# Conical receptacle of packed yellow florets, greener at the base.
				# --- Yarrow (Achillea millefolium) ------------------------------------------
				# Long, narrow, very finely divided "thousand-leaf" leaves, a dense rosette
				# with one to three stiff, downy stems 30-60 cm high, each topped by a flat
				# corymb of many tiny off-white heads with cream centres.
				# Alternate stem leaves, shorter up the stem; the far variant keeps two.
				## A flat-topped corymb: branches leave the upper stem at different heights and
				## all reach the same plane, each ending in a tuft of tiny heads.
				# --- St John's wort (Hypericum perforatum) ----------------------------------
				# One to three stiff, two-ridged stems 35-60 cm high with small, oblong,
				# stalkless leaves in opposite pairs (held up against the light they show the
				# translucent dots that name it "perforatum"), branching at the top into a broad
				# cyme of bright yellow, five-petalled star flowers with a bushy tuft of
				# stamens, among rusty-red buds. In flower round Jaanipaev (24 June).
				# Decussate pairs up the stem, each pair turned a quarter from the last.
				# The far variant keeps one leaf of every other pair.
				# The cyme: opposite branches from the top three nodes, each forking into
				# a few flowers; flowers face up and out so the yellow reads from above.
				## A five-petalled yellow star (St John's wort): narrow oval petals with a
				## slight twist, a bushy tuft of stamens in the middle.
				# --- Caraway (Carum carvi) --------------------------------------------------
				# A biennial of hay meadows: a rosette of carrot-like, two- to three-times
				# pinnate leaves, then a hollow, branched stem 30-60 cm high with compound
				# umbels of tiny white-pink flowers in June, turning into umbels of ribbed
				# brown seeds in July-August.
				# Two or three side branches from the upper nodes, each with a smaller umbel
				# a little below the main one.
				## A compound umbel: rays from one point to umbellets of tiny flowers (or seed
				## pairs). `size` is the umbel radius.
				# Rays of unequal length rise to a shallow dome.
				# Paired, ribbed, crescent fruits: a little elongated brown ovoid.
				# --- Shared helpers (also used by city_weed_meshes.gd) ----------------------
				## A stem from `base` rising `height` with a curving `lean` at the top: a
				## tapered tube of 7 rings; returns its centre line for leaves and branches.
				## A thin strip through `pts` with flex rising root to tip (CityForbMeshes
				## _ribbon has one flex per ribbon). Narrows by `taper` toward the tip.
				## A finely divided (pinnate) leaf: a thin rachis with `pairs` of narrow pinnae,
				## each split into two side lobes when `split` (chamomile, yarrow, caraway).
				## The far variant is a single narrow strip of the same outline.
				# Pinnae longest at mid-leaf, pointing forward and a little up.
				## A small stalkless leaf on a stem node (St John's wort, mint): an oblong
				## blade held up from the stem at `pitch`; `dotted` adds the pale translucent
				## speckle of Hypericum.

## Detailed procedural models of the meadow herbs round Reval (R-2128):
## chamomile, yarrow, St John's wort and caraway, with their seasonal variants.
## Built and cached through CityForbMeshes.mesh_for, which sets the far flag
## (CityForbMeshes._far) and owns the vertex contract; this file holds only the
## botany, plus the feathery-leaf, strand and floret helpers the weeds in
## city_weed_meshes.gd share. Original geometry only, deterministic: every
## seasonal variant of a species reuses the flowering kind's seed, so it is the
## same plant in another season.

## Growth stages a kind is built for.

## Out of flower: the leafy plant without heads (young or cut back).

## Ripening fruit: caraway seed umbels, thistledown.

## Dead standing stalks in autumn (mugwort).

## Young spring shoots (nettle).

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Off-white like the daisy rays (pure white clips under the city grade), with
# the cream-grey centre of each tiny head.

## Builds `kind` into `b` if it is one of this file's herbs (false otherwise).

# --- Chamomile (Matricaria chamomilla) --------------------------------------
# A bushy, much-branched annual 20-40 cm high with thread-fine, two- to three-
# times divided leaves; every branch ends in a small head: 12-16 white rays
# that fold back (reflexed) under a tall, hollow, conical golden disc. Out of
# flower: a low tuft of feathery leaves.

				# Draw the stems' numbers in every season, so the tuft is the same plant.

				# Branches leave the main stem from a third of its height up and reach about
				# as high as it, so the heads stand in a loose, uneven dome.

				# About 1.3x life size, like the other forbs: a 2 cm head.

				# The rays fold back: each starts level under the cone and bends down.

				# Conical receptacle of packed yellow florets, greener at the base.

# --- Yarrow (Achillea millefolium) ------------------------------------------
# Long, narrow, very finely divided "thousand-leaf" leaves, a dense rosette
# with one to three stiff, downy stems 30-60 cm high, each topped by a flat
# corymb of many tiny off-white heads with cream centres.

				# Alternate stem leaves, shorter up the stem; the far variant keeps two.

## A flat-topped corymb: branches leave the upper stem at different heights and
## all reach the same plane, each ending in a tuft of tiny heads.

# --- St John's wort (Hypericum perforatum) ----------------------------------
# One to three stiff, two-ridged stems 35-60 cm high with small, oblong,
# stalkless leaves in opposite pairs (held up against the light they show the
# translucent dots that name it "perforatum"), branching at the top into a broad
# cyme of bright yellow, five-petalled star flowers with a bushy tuft of
# stamens, among rusty-red buds. In flower round Jaanipaev (24 June).

				# Decussate pairs up the stem, each pair turned a quarter from the last.

				# The far variant keeps one leaf of every other pair.

				# The cyme: opposite branches from the top three nodes, each forking into
				# a few flowers; flowers face up and out so the yellow reads from above.

## A five-petalled yellow star (St John's wort): narrow oval petals with a
## slight twist, a bushy tuft of stamens in the middle.

# --- Caraway (Carum carvi) --------------------------------------------------
# A biennial of hay meadows: a rosette of carrot-like, two- to three-times
# pinnate leaves, then a hollow, branched stem 30-60 cm high with compound
# umbels of tiny white-pink flowers in June, turning into umbels of ribbed
# brown seeds in July-August.

				# Two or three side branches from the upper nodes, each with a smaller umbel
				# a little below the main one.

## A compound umbel: rays from one point to umbellets of tiny flowers (or seed
## pairs). `size` is the umbel radius.

				# Rays of unequal length rise to a shallow dome.

				# Paired, ribbed, crescent fruits: a little elongated brown ovoid.

# --- Shared helpers (also used by city_weed_meshes.gd) ----------------------

## A stem from `base` rising `height` with a curving `lean` at the top: a
## tapered tube of 7 rings; returns its centre line for leaves and branches.

## A thin strip through `pts` with flex rising root to tip (CityForbMeshes
## _ribbon has one flex per ribbon). Narrows by `taper` toward the tip.

## A finely divided (pinnate) leaf: a thin rachis with `pairs` of narrow pinnae,
## each split into two side lobes when `split` (chamomile, yarrow, caraway).
## The far variant is a single narrow strip of the same outline.

				# Pinnae longest at mid-leaf, pointing forward and a little up.

## A small stalkless leaf on a stem node (St John's wort, mint): an oblong
## blade held up from the stem at `pitch`; `dotted` adds the pale translucent
## speckle of Hypericum.

## Detailed procedural models of the meadow herbs round Reval (R-2128):
## chamomile, yarrow, St John's wort and caraway, with their seasonal variants.
## Built and cached through CityForbMeshes.mesh_for, which sets the far flag
## (CityForbMeshes._far) and owns the vertex contract; this file holds only the
## botany, plus the feathery-leaf, strand and floret helpers the weeds in
## city_weed_meshes.gd share. Original geometry only, deterministic: every
## seasonal variant of a species reuses the flowering kind's seed, so it is the
## same plant in another season.

## Growth stages a kind is built for.

## Out of flower: the leafy plant without heads (young or cut back).

## Ripening fruit: caraway seed umbels, thistledown.

## Dead standing stalks in autumn (mugwort).

## Young spring shoots (nettle).

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Off-white like the daisy rays (pure white clips under the city grade), with
# the cream-grey centre of each tiny head.

## Builds `kind` into `b` if it is one of this file's herbs (false otherwise).

# --- Chamomile (Matricaria chamomilla) --------------------------------------
# A bushy, much-branched annual 20-40 cm high with thread-fine, two- to three-
# times divided leaves; every branch ends in a small head: 12-16 white rays
# that fold back (reflexed) under a tall, hollow, conical golden disc. Out of
# flower: a low tuft of feathery leaves.

				# Draw the stems' numbers in every season, so the tuft is the same plant.

				# Branches leave the main stem from a third of its height up and reach about
				# as high as it, so the heads stand in a loose, uneven dome.

				# About 1.3x life size, like the other forbs: a 2 cm head.

				# The rays fold back: each starts level under the cone and bends down.

				# Conical receptacle of packed yellow florets, greener at the base.

# --- Yarrow (Achillea millefolium) ------------------------------------------
# Long, narrow, very finely divided "thousand-leaf" leaves, a dense rosette
# with one to three stiff, downy stems 30-60 cm high, each topped by a flat
# corymb of many tiny off-white heads with cream centres.

				# Alternate stem leaves, shorter up the stem; the far variant keeps two.

## A flat-topped corymb: branches leave the upper stem at different heights and
## all reach the same plane, each ending in a tuft of tiny heads.

# --- St John's wort (Hypericum perforatum) ----------------------------------
# One to three stiff, two-ridged stems 35-60 cm high with small, oblong,
# stalkless leaves in opposite pairs (held up against the light they show the
# translucent dots that name it "perforatum"), branching at the top into a broad
# cyme of bright yellow, five-petalled star flowers with a bushy tuft of
# stamens, among rusty-red buds. In flower round Jaanipaev (24 June).

				# Decussate pairs up the stem, each pair turned a quarter from the last.

				# The far variant keeps one leaf of every other pair.

				# The cyme: opposite branches from the top three nodes, each forking into
				# a few flowers; flowers face up and out so the yellow reads from above.

## A five-petalled yellow star (St John's wort): narrow oval petals with a
## slight twist, a bushy tuft of stamens in the middle.

# --- Caraway (Carum carvi) --------------------------------------------------
# A biennial of hay meadows: a rosette of carrot-like, two- to three-times
# pinnate leaves, then a hollow, branched stem 30-60 cm high with compound
# umbels of tiny white-pink flowers in June, turning into umbels of ribbed
# brown seeds in July-August.

				# Two or three side branches from the upper nodes, each with a smaller umbel
				# a little below the main one.

## A compound umbel: rays from one point to umbellets of tiny flowers (or seed
## pairs). `size` is the umbel radius.

				# Rays of unequal length rise to a shallow dome.

				# Paired, ribbed, crescent fruits: a little elongated brown ovoid.

# --- Shared helpers (also used by city_weed_meshes.gd) ----------------------

## A stem from `base` rising `height` with a curving `lean` at the top: a
## tapered tube of 7 rings; returns its centre line for leaves and branches.

## A thin strip through `pts` with flex rising root to tip (CityForbMeshes
## _ribbon has one flex per ribbon). Narrows by `taper` toward the tip.

## A finely divided (pinnate) leaf: a thin rachis with `pairs` of narrow pinnae,
## each split into two side lobes when `split` (chamomile, yarrow, caraway).
## The far variant is a single narrow strip of the same outline.

				# Pinnae longest at mid-leaf, pointing forward and a little up.

## A small stalkless leaf on a stem node (St John's wort, mint): an oblong
## blade held up from the stem at `pitch`; `dotted` adds the pale translucent
## speckle of Hypericum.

				## Detailed procedural models of the meadow herbs round Reval (R-2128):
				## chamomile, yarrow, St John's wort and caraway, with their seasonal variants.
				## Built and cached through CityForbMeshes.mesh_for, which sets the far flag
				## (CityForbMeshes._far) and owns the vertex contract; this file holds only the
				## botany, plus the feathery-leaf, strand and floret helpers the weeds in
				## city_weed_meshes.gd share. Original geometry only, deterministic: every
				## seasonal variant of a species reuses the flowering kind's seed, so it is the
				## same plant in another season.
				## Growth stages a kind is built for.
				## Out of flower: the leafy plant without heads (young or cut back).
				## Ripening fruit: caraway seed umbels, thistledown.
				## Dead standing stalks in autumn (mugwort).
				## Young spring shoots (nettle).
				## Kind -> [species (seed), stage].
				# Colours are sRGB, picked from field photographs of each species.
				# Off-white like the daisy rays (pure white clips under the city grade), with
				# the cream-grey centre of each tiny head.
				## Builds `kind` into `b` if it is one of this file's herbs (false otherwise).
				# --- Chamomile (Matricaria chamomilla) --------------------------------------
				# A bushy, much-branched annual 20-40 cm high with thread-fine, two- to three-
				# times divided leaves; every branch ends in a small head: 12-16 white rays
				# that fold back (reflexed) under a tall, hollow, conical golden disc. Out of
				# flower: a low tuft of feathery leaves.
				# Draw the stems' numbers in every season, so the tuft is the same plant.
				# Branches leave the main stem from a third of its height up and reach about
				# as high as it, so the heads stand in a loose, uneven dome.
				# About 1.3x life size, like the other forbs: a 2 cm head.
				# The rays fold back: each starts level under the cone and bends down.
				# Conical receptacle of packed yellow florets, greener at the base.
				# --- Yarrow (Achillea millefolium) ------------------------------------------
				# Long, narrow, very finely divided "thousand-leaf" leaves, a dense rosette
				# with one to three stiff, downy stems 30-60 cm high, each topped by a flat
				# corymb of many tiny off-white heads with cream centres.
				# Alternate stem leaves, shorter up the stem; the far variant keeps two.
				## A flat-topped corymb: branches leave the upper stem at different heights and
				## all reach the same plane, each ending in a tuft of tiny heads.
				# --- St John's wort (Hypericum perforatum) ----------------------------------
				# One to three stiff, two-ridged stems 35-60 cm high with small, oblong,
				# stalkless leaves in opposite pairs (held up against the light they show the
				# translucent dots that name it "perforatum"), branching at the top into a broad
				# cyme of bright yellow, five-petalled star flowers with a bushy tuft of
				# stamens, among rusty-red buds. In flower round Jaanipaev (24 June).
				# Decussate pairs up the stem, each pair turned a quarter from the last.
				# The far variant keeps one leaf of every other pair.
				# The cyme: opposite branches from the top three nodes, each forking into
				# a few flowers; flowers face up and out so the yellow reads from above.
				## A five-petalled yellow star (St John's wort): narrow oval petals with a
				## slight twist, a bushy tuft of stamens in the middle.
				# --- Caraway (Carum carvi) --------------------------------------------------
				# A biennial of hay meadows: a rosette of carrot-like, two- to three-times
				# pinnate leaves, then a hollow, branched stem 30-60 cm high with compound
				# umbels of tiny white-pink flowers in June, turning into umbels of ribbed
				# brown seeds in July-August.
				# Two or three side branches from the upper nodes, each with a smaller umbel
				# a little below the main one.
				## A compound umbel: rays from one point to umbellets of tiny flowers (or seed
				## pairs). `size` is the umbel radius.
				# Rays of unequal length rise to a shallow dome.
				# Paired, ribbed, crescent fruits: a little elongated brown ovoid.
				# --- Shared helpers (also used by city_weed_meshes.gd) ----------------------
				## A stem from `base` rising `height` with a curving `lean` at the top: a
				## tapered tube of 7 rings; returns its centre line for leaves and branches.
				## A thin strip through `pts` with flex rising root to tip (CityForbMeshes
				## _ribbon has one flex per ribbon). Narrows by `taper` toward the tip.
				## A finely divided (pinnate) leaf: a thin rachis with `pairs` of narrow pinnae,
				## each split into two side lobes when `split` (chamomile, yarrow, caraway).
				## The far variant is a single narrow strip of the same outline.
				# Pinnae longest at mid-leaf, pointing forward and a little up.
				## A small stalkless leaf on a stem node (St John's wort, mint): an oblong
				## blade held up from the stem at `pitch`; `dotted` adds the pale translucent
				## speckle of Hypericum.

## Detailed procedural models of the meadow herbs round Reval (R-2128):
## chamomile, yarrow, St John's wort and caraway, with their seasonal variants.
## Built and cached through CityForbMeshes.mesh_for, which sets the far flag
## (CityForbMeshes._far) and owns the vertex contract; this file holds only the
## botany, plus the feathery-leaf, strand and floret helpers the weeds in
## city_weed_meshes.gd share. Original geometry only, deterministic: every
## seasonal variant of a species reuses the flowering kind's seed, so it is the
## same plant in another season.

## Growth stages a kind is built for.

## Out of flower: the leafy plant without heads (young or cut back).

## Ripening fruit: caraway seed umbels, thistledown.

## Dead standing stalks in autumn (mugwort).

## Young spring shoots (nettle).

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Off-white like the daisy rays (pure white clips under the city grade), with
# the cream-grey centre of each tiny head.

## Builds `kind` into `b` if it is one of this file's herbs (false otherwise).

# --- Chamomile (Matricaria chamomilla) --------------------------------------
# A bushy, much-branched annual 20-40 cm high with thread-fine, two- to three-
# times divided leaves; every branch ends in a small head: 12-16 white rays
# that fold back (reflexed) under a tall, hollow, conical golden disc. Out of
# flower: a low tuft of feathery leaves.

				# Draw the stems' numbers in every season, so the tuft is the same plant.

				# Branches leave the main stem from a third of its height up and reach about
				# as high as it, so the heads stand in a loose, uneven dome.

				# About 1.3x life size, like the other forbs: a 2 cm head.

				# The rays fold back: each starts level under the cone and bends down.

				# Conical receptacle of packed yellow florets, greener at the base.

# --- Yarrow (Achillea millefolium) ------------------------------------------
# Long, narrow, very finely divided "thousand-leaf" leaves, a dense rosette
# with one to three stiff, downy stems 30-60 cm high, each topped by a flat
# corymb of many tiny off-white heads with cream centres.

				# Alternate stem leaves, shorter up the stem; the far variant keeps two.

## A flat-topped corymb: branches leave the upper stem at different heights and
## all reach the same plane, each ending in a tuft of tiny heads.

# --- St John's wort (Hypericum perforatum) ----------------------------------
# One to three stiff, two-ridged stems 35-60 cm high with small, oblong,
# stalkless leaves in opposite pairs (held up against the light they show the
# translucent dots that name it "perforatum"), branching at the top into a broad
# cyme of bright yellow, five-petalled star flowers with a bushy tuft of
# stamens, among rusty-red buds. In flower round Jaanipaev (24 June).

				# Decussate pairs up the stem, each pair turned a quarter from the last.

				# The far variant keeps one leaf of every other pair.

				# The cyme: opposite branches from the top three nodes, each forking into
				# a few flowers; flowers face up and out so the yellow reads from above.

## A five-petalled yellow star (St John's wort): narrow oval petals with a
## slight twist, a bushy tuft of stamens in the middle.

# --- Caraway (Carum carvi) --------------------------------------------------
# A biennial of hay meadows: a rosette of carrot-like, two- to three-times
# pinnate leaves, then a hollow, branched stem 30-60 cm high with compound
# umbels of tiny white-pink flowers in June, turning into umbels of ribbed
# brown seeds in July-August.

				# Two or three side branches from the upper nodes, each with a smaller umbel
				# a little below the main one.

## A compound umbel: rays from one point to umbellets of tiny flowers (or seed
## pairs). `size` is the umbel radius.

				# Rays of unequal length rise to a shallow dome.

				# Paired, ribbed, crescent fruits: a little elongated brown ovoid.

# --- Shared helpers (also used by city_weed_meshes.gd) ----------------------

## A stem from `base` rising `height` with a curving `lean` at the top: a
## tapered tube of 7 rings; returns its centre line for leaves and branches.

## A thin strip through `pts` with flex rising root to tip (CityForbMeshes
## _ribbon has one flex per ribbon). Narrows by `taper` toward the tip.

## A finely divided (pinnate) leaf: a thin rachis with `pairs` of narrow pinnae,
## each split into two side lobes when `split` (chamomile, yarrow, caraway).
## The far variant is a single narrow strip of the same outline.

				# Pinnae longest at mid-leaf, pointing forward and a little up.

## A small stalkless leaf on a stem node (St John's wort, mint): an oblong
## blade held up from the stem at `pitch`; `dotted` adds the pale translucent
## speckle of Hypericum.

## Detailed procedural models of the meadow herbs round Reval (R-2128):
## chamomile, yarrow, St John's wort and caraway, with their seasonal variants.
## Built and cached through CityForbMeshes.mesh_for, which sets the far flag
## (CityForbMeshes._far) and owns the vertex contract; this file holds only the
## botany, plus the feathery-leaf, strand and floret helpers the weeds in
## city_weed_meshes.gd share. Original geometry only, deterministic: every
## seasonal variant of a species reuses the flowering kind's seed, so it is the
## same plant in another season.

## Growth stages a kind is built for.

## Out of flower: the leafy plant without heads (young or cut back).

## Ripening fruit: caraway seed umbels, thistledown.

## Dead standing stalks in autumn (mugwort).

## Young spring shoots (nettle).

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Off-white like the daisy rays (pure white clips under the city grade), with
# the cream-grey centre of each tiny head.

## Builds `kind` into `b` if it is one of this file's herbs (false otherwise).

# --- Chamomile (Matricaria chamomilla) --------------------------------------
# A bushy, much-branched annual 20-40 cm high with thread-fine, two- to three-
# times divided leaves; every branch ends in a small head: 12-16 white rays
# that fold back (reflexed) under a tall, hollow, conical golden disc. Out of
# flower: a low tuft of feathery leaves.

				# Draw the stems' numbers in every season, so the tuft is the same plant.

				# Branches leave the main stem from a third of its height up and reach about
				# as high as it, so the heads stand in a loose, uneven dome.

				# About 1.3x life size, like the other forbs: a 2 cm head.

				# The rays fold back: each starts level under the cone and bends down.

				# Conical receptacle of packed yellow florets, greener at the base.

# --- Yarrow (Achillea millefolium) ------------------------------------------
# Long, narrow, very finely divided "thousand-leaf" leaves, a dense rosette
# with one to three stiff, downy stems 30-60 cm high, each topped by a flat
# corymb of many tiny off-white heads with cream centres.

				# Alternate stem leaves, shorter up the stem; the far variant keeps two.

## A flat-topped corymb: branches leave the upper stem at different heights and
## all reach the same plane, each ending in a tuft of tiny heads.

# --- St John's wort (Hypericum perforatum) ----------------------------------
# One to three stiff, two-ridged stems 35-60 cm high with small, oblong,
# stalkless leaves in opposite pairs (held up against the light they show the
# translucent dots that name it "perforatum"), branching at the top into a broad
# cyme of bright yellow, five-petalled star flowers with a bushy tuft of
# stamens, among rusty-red buds. In flower round Jaanipaev (24 June).

				# Decussate pairs up the stem, each pair turned a quarter from the last.

				# The far variant keeps one leaf of every other pair.

				# The cyme: opposite branches from the top three nodes, each forking into
				# a few flowers; flowers face up and out so the yellow reads from above.

## A five-petalled yellow star (St John's wort): narrow oval petals with a
## slight twist, a bushy tuft of stamens in the middle.

# --- Caraway (Carum carvi) --------------------------------------------------
# A biennial of hay meadows: a rosette of carrot-like, two- to three-times
# pinnate leaves, then a hollow, branched stem 30-60 cm high with compound
# umbels of tiny white-pink flowers in June, turning into umbels of ribbed
# brown seeds in July-August.

				# Two or three side branches from the upper nodes, each with a smaller umbel
				# a little below the main one.

## A compound umbel: rays from one point to umbellets of tiny flowers (or seed
## pairs). `size` is the umbel radius.

				# Rays of unequal length rise to a shallow dome.

				# Paired, ribbed, crescent fruits: a little elongated brown ovoid.

# --- Shared helpers (also used by city_weed_meshes.gd) ----------------------

## A stem from `base` rising `height` with a curving `lean` at the top: a
## tapered tube of 7 rings; returns its centre line for leaves and branches.

## A thin strip through `pts` with flex rising root to tip (CityForbMeshes
## _ribbon has one flex per ribbon). Narrows by `taper` toward the tip.

## A finely divided (pinnate) leaf: a thin rachis with `pairs` of narrow pinnae,
## each split into two side lobes when `split` (chamomile, yarrow, caraway).
## The far variant is a single narrow strip of the same outline.

				# Pinnae longest at mid-leaf, pointing forward and a little up.

## A small stalkless leaf on a stem node (St John's wort, mint): an oblong
## blade held up from the stem at `pitch`; `dotted` adds the pale translucent
## speckle of Hypericum.

## Detailed procedural models of the meadow herbs round Reval (R-2128):
## chamomile, yarrow, St John's wort and caraway, with their seasonal variants.
## Built and cached through CityForbMeshes.mesh_for, which sets the far flag
## (CityForbMeshes._far) and owns the vertex contract; this file holds only the
## botany, plus the feathery-leaf, strand and floret helpers the weeds in
## city_weed_meshes.gd share. Original geometry only, deterministic: every
## seasonal variant of a species reuses the flowering kind's seed, so it is the
## same plant in another season.

## Growth stages a kind is built for.

## Out of flower: the leafy plant without heads (young or cut back).

## Ripening fruit: caraway seed umbels, thistledown.

## Dead standing stalks in autumn (mugwort).

## Young spring shoots (nettle).

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Off-white like the daisy rays (pure white clips under the city grade), with
# the cream-grey centre of each tiny head.

## Builds `kind` into `b` if it is one of this file's herbs (false otherwise).

# --- Chamomile (Matricaria chamomilla) --------------------------------------
# A bushy, much-branched annual 20-40 cm high with thread-fine, two- to three-
# times divided leaves; every branch ends in a small head: 12-16 white rays
# that fold back (reflexed) under a tall, hollow, conical golden disc. Out of
# flower: a low tuft of feathery leaves.

				# Draw the stems' numbers in every season, so the tuft is the same plant.

				# Branches leave the main stem from a third of its height up and reach about
				# as high as it, so the heads stand in a loose, uneven dome.

				# About 1.3x life size, like the other forbs: a 2 cm head.

				# The rays fold back: each starts level under the cone and bends down.

				# Conical receptacle of packed yellow florets, greener at the base.

# --- Yarrow (Achillea millefolium) ------------------------------------------
# Long, narrow, very finely divided "thousand-leaf" leaves, a dense rosette
# with one to three stiff, downy stems 30-60 cm high, each topped by a flat
# corymb of many tiny off-white heads with cream centres.

				# Alternate stem leaves, shorter up the stem; the far variant keeps two.

## A flat-topped corymb: branches leave the upper stem at different heights and
## all reach the same plane, each ending in a tuft of tiny heads.

# --- St John's wort (Hypericum perforatum) ----------------------------------
# One to three stiff, two-ridged stems 35-60 cm high with small, oblong,
# stalkless leaves in opposite pairs (held up against the light they show the
# translucent dots that name it "perforatum"), branching at the top into a broad
# cyme of bright yellow, five-petalled star flowers with a bushy tuft of
# stamens, among rusty-red buds. In flower round Jaanipaev (24 June).

				# Decussate pairs up the stem, each pair turned a quarter from the last.

				# The far variant keeps one leaf of every other pair.

				# The cyme: opposite branches from the top three nodes, each forking into
				# a few flowers; flowers face up and out so the yellow reads from above.

## A five-petalled yellow star (St John's wort): narrow oval petals with a
## slight twist, a bushy tuft of stamens in the middle.

# --- Caraway (Carum carvi) --------------------------------------------------
# A biennial of hay meadows: a rosette of carrot-like, two- to three-times
# pinnate leaves, then a hollow, branched stem 30-60 cm high with compound
# umbels of tiny white-pink flowers in June, turning into umbels of ribbed
# brown seeds in July-August.

				# Two or three side branches from the upper nodes, each with a smaller umbel
				# a little below the main one.

## A compound umbel: rays from one point to umbellets of tiny flowers (or seed
## pairs). `size` is the umbel radius.

				# Rays of unequal length rise to a shallow dome.

				# Paired, ribbed, crescent fruits: a little elongated brown ovoid.

# --- Shared helpers (also used by city_weed_meshes.gd) ----------------------

## A stem from `base` rising `height` with a curving `lean` at the top: a
## tapered tube of 7 rings; returns its centre line for leaves and branches.

## A thin strip through `pts` with flex rising root to tip (CityForbMeshes
## _ribbon has one flex per ribbon). Narrows by `taper` toward the tip.

## A finely divided (pinnate) leaf: a thin rachis with `pairs` of narrow pinnae,
## each split into two side lobes when `split` (chamomile, yarrow, caraway).
## The far variant is a single narrow strip of the same outline.

				# Pinnae longest at mid-leaf, pointing forward and a little up.

## A small stalkless leaf on a stem node (St John's wort, mint): an oblong
## blade held up from the stem at `pitch`; `dotted` adds the pale translucent
## speckle of Hypericum.

				var c := (color * tone).darkened(absf(s) * 0.05)
				if dotted and MeshMath.hash01(int(t * 10.0), int(s * 3.0) + 2, speck_seed) > 0.6:
					c = c.lightened(0.18)
				return c,
			"tile": CityForbMeshes.TILE_PLANTAIN,
			"flex": Vector2(flex, flex + 0.15),
			"under": 0.3,
			"trans": 0.45 if dotted else 0.3,
		}
	)


## A tiny flat flower head seen from above: a five-sided disc, `centre_color`
## in the middle fading to `rim_color` (yarrow heads, umbel flowers, buds).
static func _floret_dot(
	b: CityForbMeshes.Builder,
	centre: Vector3,
	axis: Vector3,
	radius: float,
	centre_color: Color,
	rim_color: Color,
	flex: float
) -> void:
	var frame := CityForbMeshes._frame(axis)
	CityForbMeshes._dome(
		b,
		centre,
		frame,
		axis,
		radius,
		radius * 0.3,
		5,
		1,
		func(f: float) -> Color: return centre_color.lerp(rim_color, f),
		flex,
		0.5
	)
