# gdlint:disable=max-file-lines
extends RefCounted

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

const Herbs := preload("res://scripts/city/city_herb_meshes.gd")

## Kind -> [species (seed), stage].
const KINDS := {
	&"mint": [&"mint", Herbs.STAGE_FLOWER],
	&"mint_leaves": [&"mint", Herbs.STAGE_LEAVES],
	&"mugwort": [&"mugwort", Herbs.STAGE_FLOWER],
	&"mugwort_leaves": [&"mugwort", Herbs.STAGE_LEAVES],
	&"mugwort_dry": [&"mugwort", Herbs.STAGE_DRY],
	&"thistle": [&"thistle", Herbs.STAGE_FLOWER],
	&"thistle_down": [&"thistle", Herbs.STAGE_SEED],
	&"thistle_leaves": [&"thistle", Herbs.STAGE_LEAVES],
	&"nettle": [&"nettle", Herbs.STAGE_FLOWER],
	&"nettle_leaves": [&"nettle", Herbs.STAGE_LEAVES],
	&"nettle_shoots": [&"nettle", Herbs.STAGE_SHOOTS],
}

# Colours are sRGB, picked from field photographs of each species.
const MINT_LEAF := Color(0.27, 0.44, 0.20)
const MINT_STEM := Color(0.44, 0.36, 0.30)
const MINT_WHORL := Color(0.72, 0.56, 0.78)
const MUGWORT_LEAF := Color(0.22, 0.36, 0.16)
const MUGWORT_STEM := Color(0.40, 0.32, 0.26)
const MUGWORT_PLUME := Color(0.56, 0.60, 0.48)
const MUGWORT_PLUME_RED := Color(0.52, 0.42, 0.34)
const THISTLE_LEAF := Color(0.27, 0.42, 0.20)
const THISTLE_STEM := Color(0.40, 0.48, 0.26)
const THISTLE_SPINE := Color(0.76, 0.72, 0.52)
const THISTLE_BRACT := Color(0.34, 0.42, 0.22)
const THISTLE_FLOWER := Color(0.70, 0.46, 0.74)
const THISTLE_DOWN := Color(0.92, 0.91, 0.86)
const NETTLE_LEAF := Color(0.21, 0.38, 0.14)
const NETTLE_STEM := Color(0.36, 0.44, 0.22)
const NETTLE_TASSEL := Color(0.42, 0.50, 0.26)
# Young April shoots are dark and purple-flushed.
const NETTLE_SHOOT := Color(0.26, 0.32, 0.16)


## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
static func build(kind: StringName, b: CityForbMeshes.Builder, rng: RandomNumberGenerator) -> bool:
	if not KINDS.has(kind):
		return false
	var spec: Array = KINDS[kind]
	var species: StringName = spec[0]
	var stage: int = spec[1]
	rng.seed = 1343 + hash(String(species))
	match species:
		&"mint":
			_mint(b, rng, stage)
		&"mugwort":
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			CityForbMeshes._dry = stage == Herbs.STAGE_DRY
			_mugwort(b, rng, stage)
		&"thistle":
			_thistle(b, rng, stage)
		&"nettle":
			_nettle(b, rng, stage)
	return true


# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.


static func _mint(b: CityForbMeshes.Builder, rng: RandomNumberGenerator, stage: int) -> void:
	var stems := rng.randi_range(4, 5)
	for i in stems:
		var yaw := TAU * (float(i) + rng.randf()) / float(stems)
		var out := Vector3(cos(yaw), 0.0, sin(yaw))
		var height := rng.randf_range(0.2, 0.34)
		# Stems sprawl out from creeping runners before they turn up.
		var stem := Herbs._stem(
			b,
			out * rng.randf_range(0.01, 0.04),
			out * rng.randf_range(0.04, 0.09),
			height,
			0.0022,
			0.0014,
			MINT_STEM,
			1.0,
			4
		)
		var leaf_rng := CityForbMeshes._child_rng(rng)
		for k in range(1, stem.size()):
			if CityForbMeshes._far and k % 2 == 0:
				continue
			var flex := float(k) / 6.0
			var size := leaf_rng.randf_range(0.026, 0.036) * lerpf(1.0, 0.75, float(k) / 6.0)
			var turn := yaw + float(k) * PI * 0.5
			for s: float in [0.0, PI]:
				if CityForbMeshes._far and s > 0.0:
					continue
				Herbs._small_leaf(
					b, leaf_rng, stem[k], turn + s, size * 1.35, 0.35, MINT_LEAF, flex, false, 0.12
				)
			# Whorls of florets in the leaf axils of the upper half.
			if stage == Herbs.STAGE_FLOWER and k >= 3:
				var r := 0.0075 if not CityForbMeshes._far else 0.009
				var segs := 7 if not CityForbMeshes._far else 5
				CityForbMeshes._blob(
					b,
					stem[k] + Vector3.UP * 0.002,
					Vector3(r, r * 0.6, r),
					3,
					segs,
					func(d: Vector3) -> Color: return MINT_WHORL.darkened(0.2 * (1.0 - d.y)),
					0.5,
					flex,
					0.4
				)


# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.


static func _mugwort(b: CityForbMeshes.Builder, rng: RandomNumberGenerator, stage: int) -> void:
	var stems := rng.randi_range(2, 3)
	for i in stems:
		var yaw := TAU * (float(i) + rng.randf()) / float(stems)
		var out := Vector3(cos(yaw), 0.0, sin(yaw))
		# Before flowering the stems are still growing.
		var height := rng.randf_range(0.9, 1.25) * (0.75 if stage == Herbs.STAGE_LEAVES else 1.0)
		var stem := _tall_stem(
			b,
			out * 0.012,
			out * rng.randf_range(0.03, 0.08),
			height,
			0.006,
			CityForbMeshes._wither(MUGWORT_STEM),
			1.4
		)
		var leaf_rng := CityForbMeshes._child_rng(rng)
		var plume_rng := CityForbMeshes._child_rng(rng)
		# Alternate leaves up the lower two thirds.
		for k in range(1, 10):
			if CityForbMeshes._far and k % 3 != 1:
				continue
			var f := float(k) / 12.0
			var size := leaf_rng.randf_range(0.13, 0.17) * lerpf(1.1, 0.5, float(k) / 9.0)
			_lobed_leaf(
				b,
				leaf_rng,
				stem[k],
				yaw + float(k) * 2.4,
				size,
				3,
				CityForbMeshes._wither(MUGWORT_LEAF),
				f * 1.4,
				0.85,
				0.0,
				0.0
			)
		if stage == Herbs.STAGE_LEAVES:
			continue
		# The plume: short side branches on the top third, each a spray of tiny
		# ovoid heads, shorter toward the tip so the plume tapers.
		for k in range(6, 13):
			var up := float(k - 6) / 6.0
			var flex := float(k) / 12.0 * 1.4
			for j in 3:
				var a := yaw + float(k * 2 + j) * 2.4 + plume_rng.randf_range(-0.3, 0.3)
				var dir := Vector3(cos(a), 0.0, sin(a))
				var length := plume_rng.randf_range(0.08, 0.13) * lerpf(1.0, 0.35, up)
				var tip := stem[k] + dir * length * 0.6 + Vector3.UP * length
				_head_spray(
					b,
					plume_rng,
					stem[k],
					tip,
					flex,
					7 if j == 0 else 5,
					MUGWORT_PLUME,
					MUGWORT_PLUME_RED,
					0.004
				)


# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.


static func _thistle(b: CityForbMeshes.Builder, rng: RandomNumberGenerator, stage: int) -> void:
	var stems := rng.randi_range(2, 3)
	for i in stems:
		var yaw := TAU * (float(i) + rng.randf()) / float(stems)
		var out := Vector3(cos(yaw), 0.0, sin(yaw))
		var height := rng.randf_range(0.6, 0.85) * (0.7 if stage == Herbs.STAGE_LEAVES else 1.0)
		var stem := _tall_stem(
			b, out * 0.02, out * rng.randf_range(0.02, 0.06), height, 0.004, THISTLE_STEM, 1.3
		)
		var leaf_rng := CityForbMeshes._child_rng(rng)
		var head_rng := CityForbMeshes._child_rng(rng)
		for k in range(1, 10):
			if CityForbMeshes._far and k % 2 == 1:
				continue
			var size := leaf_rng.randf_range(0.08, 0.11) * lerpf(1.1, 0.45, float(k) / 9.0)
			_lobed_leaf(
				b,
				leaf_rng,
				stem[k],
				yaw + float(k) * 2.4,
				size,
				4,
				THISTLE_LEAF,
				float(k) / 12.0 * 1.3,
				0.3,
				0.012,
				0.35
			)
		if stage == Herbs.STAGE_LEAVES:
			continue
		# Branches from the top third, each with one to three heads.
		for k in range(9, 13):
			var a := yaw + float(k) * 2.4 + head_rng.randf_range(-0.3, 0.3)
			var dir := Vector3(cos(a), 0.0, sin(a))
			var tip := (
				stem[k]
				+ dir * head_rng.randf_range(0.04, 0.08)
				+ Vector3.UP * (stem[12].y - stem[k].y + head_rng.randf_range(0.02, 0.06))
			)
			var flex := 1.3
			if k < 12:
				CityForbMeshes._tube(
					b,
					PackedVector3Array([stem[k], stem[k].lerp(tip, 0.5), tip]),
					PackedFloat32Array([0.0018, 0.0014, 0.001]),
					4,
					func(_t: float) -> Color: return THISTLE_STEM,
					flex * 0.8,
					flex,
					0.2
				)
			var heads := head_rng.randi_range(1, 3) if k < 12 else 2
			for h in heads:
				var q := (
					tip
					+ (
						Vector3(cos(a + float(h) * 2.1), 0.0, sin(a + float(h) * 2.1))
						* 0.012
						* float(mini(h, 1))
					)
					+ Vector3.UP * 0.008 * float(h)
				)
				_thistle_head(b, head_rng, q, stage == Herbs.STAGE_SEED, flex)


static func _thistle_head(
	b: CityForbMeshes.Builder, rng: RandomNumberGenerator, at: Vector3, down: bool, flex: float
) -> void:
	var r := rng.randf_range(0.0065, 0.008)
	# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
	CityForbMeshes._blob(
		b,
		at,
		Vector3(r, r * 1.3, r),
		3,
		6,
		func(d: Vector3) -> Color:
			return THISTLE_BRACT.lerp(Color(0.40, 0.30, 0.34), smoothstep(0.2, 0.9, d.y)),
		0.35,
		flex,
		0.2
	)
	var top := at + Vector3.UP * r * 1.1
	if down:
		# A loose ball of silky pappus, bigger than the head that bore it.
		var puff := r * rng.randf_range(1.8, 2.4)
		CityForbMeshes._blob(
			b,
			top + Vector3.UP * puff * 0.7,
			Vector3(puff, puff * 0.85, puff),
			3,
			7,
			func(d: Vector3) -> Color: return THISTLE_DOWN.darkened(0.08 * (1.0 - d.y)),
			0.45,
			flex,
			0.7
		)
		return
	if CityForbMeshes._far:
		CityForbMeshes._blob(
			b,
			top,
			Vector3(r * 0.9, r * 0.6, r * 0.9),
			2,
			5,
			func(_d: Vector3) -> Color: return THISTLE_FLOWER,
			0.2,
			flex,
			0.4
		)
		return
	# The brush: a tuft of fine lilac florets fanning up out of the cup.
	var florets := 10
	var turn := rng.randf() * TAU
	for k in florets:
		var a := turn + TAU * float(k) / float(florets)
		var dir := (
			(Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(0.35, 0.7) + Vector3.UP).normalized()
		)
		Herbs._strand(
			b,
			PackedVector3Array([top - Vector3.UP * r * 0.2, top + dir * r * 1.1]),
			r * 0.18,
			THISTLE_FLOWER * rng.randf_range(0.9, 1.05),
			Vector2(flex, flex),
			0.5,
			Vector3(cos(a), 0.0, sin(a)),
			0.0,
			0.5
		)


# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.


static func _nettle(b: CityForbMeshes.Builder, rng: RandomNumberGenerator, stage: int) -> void:
	var stems := rng.randi_range(4, 5)
	var shoots := stage == Herbs.STAGE_SHOOTS
	for i in stems:
		var yaw := TAU * (float(i) + rng.randf()) / float(stems)
		var out := Vector3(cos(yaw), 0.0, sin(yaw))
		var base := out * rng.randf_range(0.02, 0.12)
		var height := rng.randf_range(0.75, 1.15)
		var leaf_rng := CityForbMeshes._child_rng(rng)
		var tassel_rng := CityForbMeshes._child_rng(rng)
		if shoots:
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			height = 0.12 + 0.1 * leaf_rng.randf()
		var stem := Herbs._stem(
			b,
			base,
			out * height * 0.04,
			height,
			0.0045 if not shoots else 0.003,
			0.002,
			NETTLE_STEM if not shoots else NETTLE_SHOOT,
			1.2 if not shoots else 0.6,
			4
		)
		for k in range(1 if not shoots else 3, stem.size()):
			if CityForbMeshes._far and k % 2 == 0:
				continue
			var f := float(k) / 6.0
			var size := leaf_rng.randf_range(0.075, 0.1) * lerpf(1.1, 0.6, f)
			if shoots:
				size = leaf_rng.randf_range(0.035, 0.05) * lerpf(1.2, 0.7, f)
			var turn := yaw + float(k) * PI * 0.5
			for s: float in [0.0, PI]:
				if CityForbMeshes._far and s > 0.0:
					continue
				_nettle_leaf(
					b,
					leaf_rng,
					stem[k],
					turn + s,
					size,
					f * (1.2 if not shoots else 0.6),
					NETTLE_SHOOT if shoots else NETTLE_LEAF
				)
				if stage == Herbs.STAGE_FLOWER and k >= 3 and not CityForbMeshes._far:
					_tassel(b, tassel_rng, stem[k], turn + s + 0.5, f * 1.2)


## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.
static func _nettle_leaf(
	b: CityForbMeshes.Builder,
	rng: RandomNumberGenerator,
	at: Vector3,
	yaw: float,
	size: float,
	flex: float,
	color: Color
) -> void:
	var tone := rng.randf_range(0.9, 1.08)
	var teeth := float(rng.randi_range(9, 12))
	CityForbMeshes._strip_leaf(
		b,
		{
			"base": at,
			"yaw": yaw,
			"rise": rng.randf_range(0.35, 0.65),
			"droop": rng.randf_range(0.9, 1.3),
			"length": size,
			"samples":
			PackedFloat32Array([0.0, 0.12, 0.22, 0.32, 0.42, 0.52, 0.62, 0.72, 0.82, 0.92, 1.0]),
			"cols": 3,
			"fold": 0.25,
			"width":
			## Detailed procedural models of the tall verge and wall-foot herbs round Reval
			## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
			## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
			## (far flag, vertex contract); shares the stem, strand and leaf helpers of
			## city_herb_meshes.gd. Every seasonal variant of a species reuses the
			## flowering kind's seed, so it is the same plant in another season.
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Young April shoots are dark and purple-flushed.
			## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			# --- Field mint (Mentha arvensis) -------------------------------------------
			# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
			# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
			# from the last; from July round balls of lilac flowers sit in the upper leaf
			# axils, one whorl above another.
			# Stems sprawl out from creeping runners before they turn up.
			# Whorls of florets in the leaf axils of the upper half.
			# --- Mugwort (Artemisia vulgaris) -------------------------------------------
			# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
			# dark green above and silver-white felted below, smaller and simpler up the
			# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
			# on short side branches. In autumn the whole stand dries brown and stays up.
			# Before flowering the stems are still growing.
			# Alternate leaves up the lower two thirds.
			# The plume: short side branches on the top third, each a spray of tiny
			# ovoid heads, shorter toward the tip so the plume tapers.
			# --- Creeping thistle (Cirsium arvense) -------------------------------------
			# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
			# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
			# stem branches into many small heads: a green, purple-tipped cup under a
			# lilac brush of florets, then white thistledown in August-September.
			# Branches from the top third, each with one to three heads.
			# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
			# A loose ball of silky pappus, bigger than the head that bore it.
			# The brush: a tuft of fine lilac florets fanning up out of the cup.
			# --- Stinging nettle (Urtica dioica) ----------------------------------------
			# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
			# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
			# pair a quarter turn from the last, drooping at the tip; from July, thin
			# greenish flower tassels hang from the upper leaf axils. In April and May the
			# stand is a carpet of short, dark, purple-flushed shoots.
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
			## coarse forward-pointing teeth, drooping toward its tip.
			# Stalk for the first 12 %, a cordate base, widest at a third, then a
			# long acuminate tip; saw teeth bite into the margin.
			## Detailed procedural models of the tall verge and wall-foot herbs round Reval
			## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
			## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
			## (far flag, vertex contract); shares the stem, strand and leaf helpers of
			## city_herb_meshes.gd. Every seasonal variant of a species reuses the
			## flowering kind's seed, so it is the same plant in another season.
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Young April shoots are dark and purple-flushed.
			## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			# --- Field mint (Mentha arvensis) -------------------------------------------
			# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
			# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
			# from the last; from July round balls of lilac flowers sit in the upper leaf
			# axils, one whorl above another.
			# Stems sprawl out from creeping runners before they turn up.
			# Whorls of florets in the leaf axils of the upper half.
			# --- Mugwort (Artemisia vulgaris) -------------------------------------------
			# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
			# dark green above and silver-white felted below, smaller and simpler up the
			# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
			# on short side branches. In autumn the whole stand dries brown and stays up.
			# Before flowering the stems are still growing.
			# Alternate leaves up the lower two thirds.
			# The plume: short side branches on the top third, each a spray of tiny
			# ovoid heads, shorter toward the tip so the plume tapers.
			# --- Creeping thistle (Cirsium arvense) -------------------------------------
			# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
			# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
			# stem branches into many small heads: a green, purple-tipped cup under a
			# lilac brush of florets, then white thistledown in August-September.
			# Branches from the top third, each with one to three heads.
			# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
			# A loose ball of silky pappus, bigger than the head that bore it.
			# The brush: a tuft of fine lilac florets fanning up out of the cup.
			# --- Stinging nettle (Urtica dioica) ----------------------------------------
			# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
			# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
			# pair a quarter turn from the last, drooping at the tip; from July, thin
			# greenish flower tassels hang from the upper leaf axils. In April and May the
			# stand is a carpet of short, dark, purple-flushed shoots.
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
			## coarse forward-pointing teeth, drooping toward its tip.
			# Stalk for the first 12 %, a cordate base, widest at a third, then a
			## Detailed procedural models of the tall verge and wall-foot herbs round Reval
			## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
			## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
			## (far flag, vertex contract); shares the stem, strand and leaf helpers of
			## city_herb_meshes.gd. Every seasonal variant of a species reuses the
			## flowering kind's seed, so it is the same plant in another season.
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Young April shoots are dark and purple-flushed.
			## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			# --- Field mint (Mentha arvensis) -------------------------------------------
			# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
			# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
			# from the last; from July round balls of lilac flowers sit in the upper leaf
			# axils, one whorl above another.
			# Stems sprawl out from creeping runners before they turn up.
			# Whorls of florets in the leaf axils of the upper half.
			# --- Mugwort (Artemisia vulgaris) -------------------------------------------
			# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
			# dark green above and silver-white felted below, smaller and simpler up the
			# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
			# on short side branches. In autumn the whole stand dries brown and stays up.
			# Before flowering the stems are still growing.
			# Alternate leaves up the lower two thirds.
			# The plume: short side branches on the top third, each a spray of tiny
			# ovoid heads, shorter toward the tip so the plume tapers.
			# --- Creeping thistle (Cirsium arvense) -------------------------------------
			# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
			# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
			# stem branches into many small heads: a green, purple-tipped cup under a
			# lilac brush of florets, then white thistledown in August-September.
			# Branches from the top third, each with one to three heads.
			# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
			# A loose ball of silky pappus, bigger than the head that bore it.
			# The brush: a tuft of fine lilac florets fanning up out of the cup.
			# --- Stinging nettle (Urtica dioica) ----------------------------------------
			# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
			# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
			# pair a quarter turn from the last, drooping at the tip; from July, thin
			# greenish flower tassels hang from the upper leaf axils. In April and May the
			# stand is a carpet of short, dark, purple-flushed shoots.
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
			## coarse forward-pointing teeth, drooping toward its tip.
			# Stalk for the first 12 %, a cordate base, widest at a third, then a
			# long acuminate tip; saw teeth bite into the margin.
			func(t: float) -> float:
# gdlint:disable=max-file-lines

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				## Detailed procedural models of the tall verge and wall-foot herbs round Reval
				## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
				## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
				## (far flag, vertex contract); shares the stem, strand and leaf helpers of
				## city_herb_meshes.gd. Every seasonal variant of a species reuses the
				## flowering kind's seed, so it is the same plant in another season.
				## Kind -> [species (seed), stage].
				# Colours are sRGB, picked from field photographs of each species.
				# Young April shoots are dark and purple-flushed.
				## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
				# --- Field mint (Mentha arvensis) -------------------------------------------
				# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
				# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
				# from the last; from July round balls of lilac flowers sit in the upper leaf
				# axils, one whorl above another.
				# Stems sprawl out from creeping runners before they turn up.
				# Whorls of florets in the leaf axils of the upper half.
				# --- Mugwort (Artemisia vulgaris) -------------------------------------------
				# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
				# dark green above and silver-white felted below, smaller and simpler up the
				# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
				# on short side branches. In autumn the whole stand dries brown and stays up.
				# Before flowering the stems are still growing.
				# Alternate leaves up the lower two thirds.
				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.
				# --- Creeping thistle (Cirsium arvense) -------------------------------------
				# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
				# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
				# stem branches into many small heads: a green, purple-tipped cup under a
				# lilac brush of florets, then white thistledown in August-September.
				# Branches from the top third, each with one to three heads.
				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
				# A loose ball of silky pappus, bigger than the head that bore it.
				# The brush: a tuft of fine lilac florets fanning up out of the cup.
				# --- Stinging nettle (Urtica dioica) ----------------------------------------
				# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
				# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
				# pair a quarter turn from the last, drooping at the tip; from July, thin
				# greenish flower tassels hang from the upper leaf axils. In April and May the
				# stand is a carpet of short, dark, purple-flushed shoots.
				# A short shoot: three crowded pairs of young leaves on 12-22 cm.
				## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
				## coarse forward-pointing teeth, drooping toward its tip.
				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				if t <= 0.12:
					return size * 0.03
				var u := (t - 0.12) / 0.88
				var shape := sin(PI * minf(0.25 + u * 0.95, 1.0)) * (1.0 - 0.55 * u * u)
				return size * 0.34 * shape * (1.0 - 0.16 * fposmod(u * teeth, 1.0)),
			"shift":
			## Detailed procedural models of the tall verge and wall-foot herbs round Reval
			## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
			## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
			## (far flag, vertex contract); shares the stem, strand and leaf helpers of
			## city_herb_meshes.gd. Every seasonal variant of a species reuses the
			## flowering kind's seed, so it is the same plant in another season.
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Young April shoots are dark and purple-flushed.
			## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			# --- Field mint (Mentha arvensis) -------------------------------------------
			# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
			# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
			# from the last; from July round balls of lilac flowers sit in the upper leaf
			# axils, one whorl above another.
			# Stems sprawl out from creeping runners before they turn up.
			# Whorls of florets in the leaf axils of the upper half.
			# --- Mugwort (Artemisia vulgaris) -------------------------------------------
			# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
			# dark green above and silver-white felted below, smaller and simpler up the
			# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
			# on short side branches. In autumn the whole stand dries brown and stays up.
			# Before flowering the stems are still growing.
			# Alternate leaves up the lower two thirds.
			# The plume: short side branches on the top third, each a spray of tiny
			# ovoid heads, shorter toward the tip so the plume tapers.
			# --- Creeping thistle (Cirsium arvense) -------------------------------------
			# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
			# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
			# stem branches into many small heads: a green, purple-tipped cup under a
			# lilac brush of florets, then white thistledown in August-September.
			# Branches from the top third, each with one to three heads.
			# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
			# A loose ball of silky pappus, bigger than the head that bore it.
			# The brush: a tuft of fine lilac florets fanning up out of the cup.
			# --- Stinging nettle (Urtica dioica) ----------------------------------------
			# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
			# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
			# pair a quarter turn from the last, drooping at the tip; from July, thin
			# greenish flower tassels hang from the upper leaf axils. In April and May the
			# stand is a carpet of short, dark, purple-flushed shoots.
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
			## coarse forward-pointing teeth, drooping toward its tip.
			# Stalk for the first 12 %, a cordate base, widest at a third, then a
			# long acuminate tip; saw teeth bite into the margin.
			# Teeth point forward: the outer margin runs ahead of the midrib a little.
			## Detailed procedural models of the tall verge and wall-foot herbs round Reval
			## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
			## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
			## (far flag, vertex contract); shares the stem, strand and leaf helpers of
			## city_herb_meshes.gd. Every seasonal variant of a species reuses the
			## flowering kind's seed, so it is the same plant in another season.
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Young April shoots are dark and purple-flushed.
			## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			# --- Field mint (Mentha arvensis) -------------------------------------------
			# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
			# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
			# from the last; from July round balls of lilac flowers sit in the upper leaf
			# axils, one whorl above another.
			# Stems sprawl out from creeping runners before they turn up.
			# Whorls of florets in the leaf axils of the upper half.
			# --- Mugwort (Artemisia vulgaris) -------------------------------------------
			# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
			# dark green above and silver-white felted below, smaller and simpler up the
			# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
			# on short side branches. In autumn the whole stand dries brown and stays up.
			# Before flowering the stems are still growing.
			# Alternate leaves up the lower two thirds.
			# The plume: short side branches on the top third, each a spray of tiny
			# ovoid heads, shorter toward the tip so the plume tapers.
			# --- Creeping thistle (Cirsium arvense) -------------------------------------
			# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
			# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
			# stem branches into many small heads: a green, purple-tipped cup under a
			# lilac brush of florets, then white thistledown in August-September.
			# Branches from the top third, each with one to three heads.
			# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
			# A loose ball of silky pappus, bigger than the head that bore it.
			# The brush: a tuft of fine lilac florets fanning up out of the cup.
			# --- Stinging nettle (Urtica dioica) ----------------------------------------
			# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
			# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
			# pair a quarter turn from the last, drooping at the tip; from July, thin
			# greenish flower tassels hang from the upper leaf axils. In April and May the
			# stand is a carpet of short, dark, purple-flushed shoots.
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
			## coarse forward-pointing teeth, drooping toward its tip.
			# Stalk for the first 12 %, a cordate base, widest at a third, then a
			## Detailed procedural models of the tall verge and wall-foot herbs round Reval
			## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
			## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
			## (far flag, vertex contract); shares the stem, strand and leaf helpers of
			## city_herb_meshes.gd. Every seasonal variant of a species reuses the
			## flowering kind's seed, so it is the same plant in another season.
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Young April shoots are dark and purple-flushed.
			## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			# --- Field mint (Mentha arvensis) -------------------------------------------
			# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
			# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
			# from the last; from July round balls of lilac flowers sit in the upper leaf
			# axils, one whorl above another.
			# Stems sprawl out from creeping runners before they turn up.
			# Whorls of florets in the leaf axils of the upper half.
			# --- Mugwort (Artemisia vulgaris) -------------------------------------------
			# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
			# dark green above and silver-white felted below, smaller and simpler up the
			# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
			# on short side branches. In autumn the whole stand dries brown and stays up.
			# Before flowering the stems are still growing.
			# Alternate leaves up the lower two thirds.
			# The plume: short side branches on the top third, each a spray of tiny
			# ovoid heads, shorter toward the tip so the plume tapers.
			# --- Creeping thistle (Cirsium arvense) -------------------------------------
			# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
			# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
			# stem branches into many small heads: a green, purple-tipped cup under a
			# lilac brush of florets, then white thistledown in August-September.
			# Branches from the top third, each with one to three heads.
			# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
			# A loose ball of silky pappus, bigger than the head that bore it.
			# The brush: a tuft of fine lilac florets fanning up out of the cup.
			# --- Stinging nettle (Urtica dioica) ----------------------------------------
			# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
			# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
			# pair a quarter turn from the last, drooping at the tip; from July, thin
			# greenish flower tassels hang from the upper leaf axils. In April and May the
			# stand is a carpet of short, dark, purple-flushed shoots.
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
			## coarse forward-pointing teeth, drooping toward its tip.
			# Stalk for the first 12 %, a cordate base, widest at a third, then a
			# long acuminate tip; saw teeth bite into the margin.
			## Detailed procedural models of the tall verge and wall-foot herbs round Reval
			## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
			## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
			## (far flag, vertex contract); shares the stem, strand and leaf helpers of
			## city_herb_meshes.gd. Every seasonal variant of a species reuses the
			## flowering kind's seed, so it is the same plant in another season.
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Young April shoots are dark and purple-flushed.
			## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			# --- Field mint (Mentha arvensis) -------------------------------------------
			# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
			# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
			# from the last; from July round balls of lilac flowers sit in the upper leaf
			# axils, one whorl above another.
			# Stems sprawl out from creeping runners before they turn up.
			# Whorls of florets in the leaf axils of the upper half.
			# --- Mugwort (Artemisia vulgaris) -------------------------------------------
			# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
			# dark green above and silver-white felted below, smaller and simpler up the
			# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
			# on short side branches. In autumn the whole stand dries brown and stays up.
			# Before flowering the stems are still growing.
			# Alternate leaves up the lower two thirds.
			# The plume: short side branches on the top third, each a spray of tiny
			# ovoid heads, shorter toward the tip so the plume tapers.
			# --- Creeping thistle (Cirsium arvense) -------------------------------------
			# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
			# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
			# stem branches into many small heads: a green, purple-tipped cup under a
			# lilac brush of florets, then white thistledown in August-September.
			# Branches from the top third, each with one to three heads.
			# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
			# A loose ball of silky pappus, bigger than the head that bore it.
			# The brush: a tuft of fine lilac florets fanning up out of the cup.
			# --- Stinging nettle (Urtica dioica) ----------------------------------------
			# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
			# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
			# pair a quarter turn from the last, drooping at the tip; from July, thin
			# greenish flower tassels hang from the upper leaf axils. In April and May the
			# stand is a carpet of short, dark, purple-flushed shoots.
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
			## coarse forward-pointing teeth, drooping toward its tip.
			# Stalk for the first 12 %, a cordate base, widest at a third, then a
			# long acuminate tip; saw teeth bite into the margin.
			# Teeth point forward: the outer margin runs ahead of the midrib a little.
			func(t: float, s: float) -> float:
# gdlint:disable=max-file-lines

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				## Detailed procedural models of the tall verge and wall-foot herbs round Reval
				## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
				## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
				## (far flag, vertex contract); shares the stem, strand and leaf helpers of
				## city_herb_meshes.gd. Every seasonal variant of a species reuses the
				## flowering kind's seed, so it is the same plant in another season.
				## Kind -> [species (seed), stage].
				# Colours are sRGB, picked from field photographs of each species.
				# Young April shoots are dark and purple-flushed.
				## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
				# --- Field mint (Mentha arvensis) -------------------------------------------
				# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
				# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
				# from the last; from July round balls of lilac flowers sit in the upper leaf
				# axils, one whorl above another.
				# Stems sprawl out from creeping runners before they turn up.
				# Whorls of florets in the leaf axils of the upper half.
				# --- Mugwort (Artemisia vulgaris) -------------------------------------------
				# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
				# dark green above and silver-white felted below, smaller and simpler up the
				# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
				# on short side branches. In autumn the whole stand dries brown and stays up.
				# Before flowering the stems are still growing.
				# Alternate leaves up the lower two thirds.
				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.
				# --- Creeping thistle (Cirsium arvense) -------------------------------------
				# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
				# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
				# stem branches into many small heads: a green, purple-tipped cup under a
				# lilac brush of florets, then white thistledown in August-September.
				# Branches from the top third, each with one to three heads.
				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
				# A loose ball of silky pappus, bigger than the head that bore it.
				# The brush: a tuft of fine lilac florets fanning up out of the cup.
				# --- Stinging nettle (Urtica dioica) ----------------------------------------
				# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
				# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
				# pair a quarter turn from the last, drooping at the tip; from July, thin
				# greenish flower tassels hang from the upper leaf axils. In April and May the
				# stand is a carpet of short, dark, purple-flushed shoots.
				# A short shoot: three crowded pairs of young leaves on 12-22 cm.
				## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
				## coarse forward-pointing teeth, drooping toward its tip.
				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				## Detailed procedural models of the tall verge and wall-foot herbs round Reval
				## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
				## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
				## (far flag, vertex contract); shares the stem, strand and leaf helpers of
				## city_herb_meshes.gd. Every seasonal variant of a species reuses the
				## flowering kind's seed, so it is the same plant in another season.
				## Kind -> [species (seed), stage].
				# Colours are sRGB, picked from field photographs of each species.
				# Young April shoots are dark and purple-flushed.
				## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
				# --- Field mint (Mentha arvensis) -------------------------------------------
				# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
				# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
				# from the last; from July round balls of lilac flowers sit in the upper leaf
				# axils, one whorl above another.
				# Stems sprawl out from creeping runners before they turn up.
				# Whorls of florets in the leaf axils of the upper half.
				# --- Mugwort (Artemisia vulgaris) -------------------------------------------
				# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
				# dark green above and silver-white felted below, smaller and simpler up the
				# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
				# on short side branches. In autumn the whole stand dries brown and stays up.
				# Before flowering the stems are still growing.
				# Alternate leaves up the lower two thirds.
				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.
				# --- Creeping thistle (Cirsium arvense) -------------------------------------
				# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
				# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
				# stem branches into many small heads: a green, purple-tipped cup under a
				# lilac brush of florets, then white thistledown in August-September.
				# Branches from the top third, each with one to three heads.
				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
				# A loose ball of silky pappus, bigger than the head that bore it.
				# The brush: a tuft of fine lilac florets fanning up out of the cup.
				# --- Stinging nettle (Urtica dioica) ----------------------------------------
				# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
				# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
				# pair a quarter turn from the last, drooping at the tip; from July, thin
				# greenish flower tassels hang from the upper leaf axils. In April and May the
				# stand is a carpet of short, dark, purple-flushed shoots.
				# A short shoot: three crowded pairs of young leaves on 12-22 cm.
				## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
				## coarse forward-pointing teeth, drooping toward its tip.
				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.
				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

				return absf(s) * size * 0.03 * fposmod(t * teeth, 1.0) if t > 0.12 else 0.0,
			"color":
			## Detailed procedural models of the tall verge and wall-foot herbs round Reval
			## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
			## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
			## (far flag, vertex contract); shares the stem, strand and leaf helpers of
			## city_herb_meshes.gd. Every seasonal variant of a species reuses the
			## flowering kind's seed, so it is the same plant in another season.
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Young April shoots are dark and purple-flushed.
			## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			# --- Field mint (Mentha arvensis) -------------------------------------------
			# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
			# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
			# from the last; from July round balls of lilac flowers sit in the upper leaf
			# axils, one whorl above another.
			# Stems sprawl out from creeping runners before they turn up.
			# Whorls of florets in the leaf axils of the upper half.
			# --- Mugwort (Artemisia vulgaris) -------------------------------------------
			# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
			# dark green above and silver-white felted below, smaller and simpler up the
			# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
			# on short side branches. In autumn the whole stand dries brown and stays up.
			# Before flowering the stems are still growing.
			# Alternate leaves up the lower two thirds.
			# The plume: short side branches on the top third, each a spray of tiny
			# ovoid heads, shorter toward the tip so the plume tapers.
			# --- Creeping thistle (Cirsium arvense) -------------------------------------
			# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
			# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
			# stem branches into many small heads: a green, purple-tipped cup under a
			# lilac brush of florets, then white thistledown in August-September.
			# Branches from the top third, each with one to three heads.
			# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
			# A loose ball of silky pappus, bigger than the head that bore it.
			# The brush: a tuft of fine lilac florets fanning up out of the cup.
			# --- Stinging nettle (Urtica dioica) ----------------------------------------
			# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
			# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
			# pair a quarter turn from the last, drooping at the tip; from July, thin
			# greenish flower tassels hang from the upper leaf axils. In April and May the
			# stand is a carpet of short, dark, purple-flushed shoots.
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
			## coarse forward-pointing teeth, drooping toward its tip.
			# Stalk for the first 12 %, a cordate base, widest at a third, then a
			# long acuminate tip; saw teeth bite into the margin.
			# Teeth point forward: the outer margin runs ahead of the midrib a little.
			## Detailed procedural models of the tall verge and wall-foot herbs round Reval
			## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
			## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
			## (far flag, vertex contract); shares the stem, strand and leaf helpers of
			## city_herb_meshes.gd. Every seasonal variant of a species reuses the
			## flowering kind's seed, so it is the same plant in another season.
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Young April shoots are dark and purple-flushed.
			## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			# --- Field mint (Mentha arvensis) -------------------------------------------
			# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
			# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
			# from the last; from July round balls of lilac flowers sit in the upper leaf
			# axils, one whorl above another.
			# Stems sprawl out from creeping runners before they turn up.
			# Whorls of florets in the leaf axils of the upper half.
			# --- Mugwort (Artemisia vulgaris) -------------------------------------------
			# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
			# dark green above and silver-white felted below, smaller and simpler up the
			# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
			# on short side branches. In autumn the whole stand dries brown and stays up.
			# Before flowering the stems are still growing.
			# Alternate leaves up the lower two thirds.
			# The plume: short side branches on the top third, each a spray of tiny
			# ovoid heads, shorter toward the tip so the plume tapers.
			# --- Creeping thistle (Cirsium arvense) -------------------------------------
			# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
			# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
			# stem branches into many small heads: a green, purple-tipped cup under a
			# lilac brush of florets, then white thistledown in August-September.
			# Branches from the top third, each with one to three heads.
			# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
			# A loose ball of silky pappus, bigger than the head that bore it.
			# The brush: a tuft of fine lilac florets fanning up out of the cup.
			# --- Stinging nettle (Urtica dioica) ----------------------------------------
			# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
			# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
			# pair a quarter turn from the last, drooping at the tip; from July, thin
			# greenish flower tassels hang from the upper leaf axils. In April and May the
			# stand is a carpet of short, dark, purple-flushed shoots.
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
			## coarse forward-pointing teeth, drooping toward its tip.
			# Stalk for the first 12 %, a cordate base, widest at a third, then a
			## Detailed procedural models of the tall verge and wall-foot herbs round Reval
			## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
			## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
			## (far flag, vertex contract); shares the stem, strand and leaf helpers of
			## city_herb_meshes.gd. Every seasonal variant of a species reuses the
			## flowering kind's seed, so it is the same plant in another season.
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Young April shoots are dark and purple-flushed.
			## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			# --- Field mint (Mentha arvensis) -------------------------------------------
			# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
			# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
			# from the last; from July round balls of lilac flowers sit in the upper leaf
			# axils, one whorl above another.
			# Stems sprawl out from creeping runners before they turn up.
			# Whorls of florets in the leaf axils of the upper half.
			# --- Mugwort (Artemisia vulgaris) -------------------------------------------
			# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
			# dark green above and silver-white felted below, smaller and simpler up the
			# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
			# on short side branches. In autumn the whole stand dries brown and stays up.
			# Before flowering the stems are still growing.
			# Alternate leaves up the lower two thirds.
			# The plume: short side branches on the top third, each a spray of tiny
			# ovoid heads, shorter toward the tip so the plume tapers.
			# --- Creeping thistle (Cirsium arvense) -------------------------------------
			# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
			# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
			# stem branches into many small heads: a green, purple-tipped cup under a
			# lilac brush of florets, then white thistledown in August-September.
			# Branches from the top third, each with one to three heads.
			# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
			# A loose ball of silky pappus, bigger than the head that bore it.
			# The brush: a tuft of fine lilac florets fanning up out of the cup.
			# --- Stinging nettle (Urtica dioica) ----------------------------------------
			# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
			# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
			# pair a quarter turn from the last, drooping at the tip; from July, thin
			# greenish flower tassels hang from the upper leaf axils. In April and May the
			# stand is a carpet of short, dark, purple-flushed shoots.
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
			## coarse forward-pointing teeth, drooping toward its tip.
			# Stalk for the first 12 %, a cordate base, widest at a third, then a
			# long acuminate tip; saw teeth bite into the margin.
			## Detailed procedural models of the tall verge and wall-foot herbs round Reval
			## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
			## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
			## (far flag, vertex contract); shares the stem, strand and leaf helpers of
			## city_herb_meshes.gd. Every seasonal variant of a species reuses the
			## flowering kind's seed, so it is the same plant in another season.
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Young April shoots are dark and purple-flushed.
			## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			# --- Field mint (Mentha arvensis) -------------------------------------------
			# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
			# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
			# from the last; from July round balls of lilac flowers sit in the upper leaf
			# axils, one whorl above another.
			# Stems sprawl out from creeping runners before they turn up.
			# Whorls of florets in the leaf axils of the upper half.
			# --- Mugwort (Artemisia vulgaris) -------------------------------------------
			# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
			# dark green above and silver-white felted below, smaller and simpler up the
			# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
			# on short side branches. In autumn the whole stand dries brown and stays up.
			# Before flowering the stems are still growing.
			# Alternate leaves up the lower two thirds.
			# The plume: short side branches on the top third, each a spray of tiny
			# ovoid heads, shorter toward the tip so the plume tapers.
			# --- Creeping thistle (Cirsium arvense) -------------------------------------
			# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
			# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
			# stem branches into many small heads: a green, purple-tipped cup under a
			# lilac brush of florets, then white thistledown in August-September.
			# Branches from the top third, each with one to three heads.
			# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
			# A loose ball of silky pappus, bigger than the head that bore it.
			# The brush: a tuft of fine lilac florets fanning up out of the cup.
			# --- Stinging nettle (Urtica dioica) ----------------------------------------
			# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
			# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
			# pair a quarter turn from the last, drooping at the tip; from July, thin
			# greenish flower tassels hang from the upper leaf axils. In April and May the
			# stand is a carpet of short, dark, purple-flushed shoots.
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
			## coarse forward-pointing teeth, drooping toward its tip.
			# Stalk for the first 12 %, a cordate base, widest at a third, then a
			# long acuminate tip; saw teeth bite into the margin.
			# Teeth point forward: the outer margin runs ahead of the midrib a little.
			## Detailed procedural models of the tall verge and wall-foot herbs round Reval
			## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
			## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
			## (far flag, vertex contract); shares the stem, strand and leaf helpers of
			## city_herb_meshes.gd. Every seasonal variant of a species reuses the
			## flowering kind's seed, so it is the same plant in another season.
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Young April shoots are dark and purple-flushed.
			## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			# --- Field mint (Mentha arvensis) -------------------------------------------
			# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
			# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
			# from the last; from July round balls of lilac flowers sit in the upper leaf
			# axils, one whorl above another.
			# Stems sprawl out from creeping runners before they turn up.
			# Whorls of florets in the leaf axils of the upper half.
			# --- Mugwort (Artemisia vulgaris) -------------------------------------------
			# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
			# dark green above and silver-white felted below, smaller and simpler up the
			# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
			# on short side branches. In autumn the whole stand dries brown and stays up.
			# Before flowering the stems are still growing.
			# Alternate leaves up the lower two thirds.
			# The plume: short side branches on the top third, each a spray of tiny
			# ovoid heads, shorter toward the tip so the plume tapers.
			# --- Creeping thistle (Cirsium arvense) -------------------------------------
			# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
			# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
			# stem branches into many small heads: a green, purple-tipped cup under a
			# lilac brush of florets, then white thistledown in August-September.
			# Branches from the top third, each with one to three heads.
			# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
			# A loose ball of silky pappus, bigger than the head that bore it.
			# The brush: a tuft of fine lilac florets fanning up out of the cup.
			# --- Stinging nettle (Urtica dioica) ----------------------------------------
			# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
			# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
			# pair a quarter turn from the last, drooping at the tip; from July, thin
			# greenish flower tassels hang from the upper leaf axils. In April and May the
			# stand is a carpet of short, dark, purple-flushed shoots.
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
			## coarse forward-pointing teeth, drooping toward its tip.
			# Stalk for the first 12 %, a cordate base, widest at a third, then a
			# long acuminate tip; saw teeth bite into the margin.
			# Teeth point forward: the outer margin runs ahead of the midrib a little.
			func(t: float, s: float) -> Color:
# gdlint:disable=max-file-lines

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				## Detailed procedural models of the tall verge and wall-foot herbs round Reval
				## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
				## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
				## (far flag, vertex contract); shares the stem, strand and leaf helpers of
				## city_herb_meshes.gd. Every seasonal variant of a species reuses the
				## flowering kind's seed, so it is the same plant in another season.
				## Kind -> [species (seed), stage].
				# Colours are sRGB, picked from field photographs of each species.
				# Young April shoots are dark and purple-flushed.
				## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
				# --- Field mint (Mentha arvensis) -------------------------------------------
				# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
				# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
				# from the last; from July round balls of lilac flowers sit in the upper leaf
				# axils, one whorl above another.
				# Stems sprawl out from creeping runners before they turn up.
				# Whorls of florets in the leaf axils of the upper half.
				# --- Mugwort (Artemisia vulgaris) -------------------------------------------
				# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
				# dark green above and silver-white felted below, smaller and simpler up the
				# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
				# on short side branches. In autumn the whole stand dries brown and stays up.
				# Before flowering the stems are still growing.
				# Alternate leaves up the lower two thirds.
				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.
				# --- Creeping thistle (Cirsium arvense) -------------------------------------
				# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
				# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
				# stem branches into many small heads: a green, purple-tipped cup under a
				# lilac brush of florets, then white thistledown in August-September.
				# Branches from the top third, each with one to three heads.
				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
				# A loose ball of silky pappus, bigger than the head that bore it.
				# The brush: a tuft of fine lilac florets fanning up out of the cup.
				# --- Stinging nettle (Urtica dioica) ----------------------------------------
				# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
				# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
				# pair a quarter turn from the last, drooping at the tip; from July, thin
				# greenish flower tassels hang from the upper leaf axils. In April and May the
				# stand is a carpet of short, dark, purple-flushed shoots.
				# A short shoot: three crowded pairs of young leaves on 12-22 cm.
				## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
				## coarse forward-pointing teeth, drooping toward its tip.
				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				## Detailed procedural models of the tall verge and wall-foot herbs round Reval
				## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
				## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
				## (far flag, vertex contract); shares the stem, strand and leaf helpers of
				## city_herb_meshes.gd. Every seasonal variant of a species reuses the
				## flowering kind's seed, so it is the same plant in another season.
				## Kind -> [species (seed), stage].
				# Colours are sRGB, picked from field photographs of each species.
				# Young April shoots are dark and purple-flushed.
				## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
				# --- Field mint (Mentha arvensis) -------------------------------------------
				# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
				# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
				# from the last; from July round balls of lilac flowers sit in the upper leaf
				# axils, one whorl above another.
				# Stems sprawl out from creeping runners before they turn up.
				# Whorls of florets in the leaf axils of the upper half.
				# --- Mugwort (Artemisia vulgaris) -------------------------------------------
				# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
				# dark green above and silver-white felted below, smaller and simpler up the
				# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
				# on short side branches. In autumn the whole stand dries brown and stays up.
				# Before flowering the stems are still growing.
				# Alternate leaves up the lower two thirds.
				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.
				# --- Creeping thistle (Cirsium arvense) -------------------------------------
				# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
				# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
				# stem branches into many small heads: a green, purple-tipped cup under a
				# lilac brush of florets, then white thistledown in August-September.
				# Branches from the top third, each with one to three heads.
				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
				# A loose ball of silky pappus, bigger than the head that bore it.
				# The brush: a tuft of fine lilac florets fanning up out of the cup.
				# --- Stinging nettle (Urtica dioica) ----------------------------------------
				# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
				# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
				# pair a quarter turn from the last, drooping at the tip; from July, thin
				# greenish flower tassels hang from the upper leaf axils. In April and May the
				# stand is a carpet of short, dark, purple-flushed shoots.
				# A short shoot: three crowded pairs of young leaves on 12-22 cm.
				## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
				## coarse forward-pointing teeth, drooping toward its tip.
				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.
				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

				## Detailed procedural models of the tall verge and wall-foot herbs round Reval
				## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
				## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
				## (far flag, vertex contract); shares the stem, strand and leaf helpers of
				## city_herb_meshes.gd. Every seasonal variant of a species reuses the
				## flowering kind's seed, so it is the same plant in another season.
				## Kind -> [species (seed), stage].
				# Colours are sRGB, picked from field photographs of each species.
				# Young April shoots are dark and purple-flushed.
				## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
				# --- Field mint (Mentha arvensis) -------------------------------------------
				# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
				# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
				# from the last; from July round balls of lilac flowers sit in the upper leaf
				# axils, one whorl above another.
				# Stems sprawl out from creeping runners before they turn up.
				# Whorls of florets in the leaf axils of the upper half.
				# --- Mugwort (Artemisia vulgaris) -------------------------------------------
				# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
				# dark green above and silver-white felted below, smaller and simpler up the
				# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
				# on short side branches. In autumn the whole stand dries brown and stays up.
				# Before flowering the stems are still growing.
				# Alternate leaves up the lower two thirds.
				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.
				# --- Creeping thistle (Cirsium arvense) -------------------------------------
				# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
				# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
				# stem branches into many small heads: a green, purple-tipped cup under a
				# lilac brush of florets, then white thistledown in August-September.
				# Branches from the top third, each with one to three heads.
				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
				# A loose ball of silky pappus, bigger than the head that bore it.
				# The brush: a tuft of fine lilac florets fanning up out of the cup.
				# --- Stinging nettle (Urtica dioica) ----------------------------------------
				# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
				# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
				# pair a quarter turn from the last, drooping at the tip; from July, thin
				# greenish flower tassels hang from the upper leaf axils. In April and May the
				# stand is a carpet of short, dark, purple-flushed shoots.
				# A short shoot: three crowded pairs of young leaves on 12-22 cm.
				## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
				## coarse forward-pointing teeth, drooping toward its tip.
				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.
				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

				return (color * tone).lightened(0.06 * (1.0 - t)).darkened(absf(s) * 0.06),
			"tile": CityForbMeshes.TILE_PLANTAIN,
			"flex": Vector2(flex, flex + 0.3),
			"under": 0.35,
			"trans": 0.3,
		}
	)


## A hanging nettle flower tassel: a thin, knotted, greenish catkin.
static func _tassel(
	b: CityForbMeshes.Builder, rng: RandomNumberGenerator, at: Vector3, yaw: float, flex: float
) -> void:
	var out := Vector3(cos(yaw), 0.0, sin(yaw))
	var length := rng.randf_range(0.04, 0.07)
	var pts := PackedVector3Array(
		[
			at,
			at + out * length * 0.45 + Vector3.UP * 0.006,
			at + out * length * 0.8 - Vector3.UP * length * 0.25,
			at + out * length - Vector3.UP * length * 0.6,
		]
	)
	Herbs._strand(
		b,
		pts,
		0.0022,
		NETTLE_TASSEL * rng.randf_range(0.9, 1.08),
		Vector2(flex, flex + 0.4),
		0.3,
		Vector3.UP,
		0.2,
		0.4
	)


# --- Helpers -----------------------------------------------------------------


## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
## nodes; returns the centre line.
static func _tall_stem(
	b: CityForbMeshes.Builder,
	base: Vector3,
	lean: Vector3,
	height: float,
	r0: float,
	color: Color,
	flex: float
) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	for k in 13:
		var t := float(k) / 12.0
		pts.append(base + lean * t * t + Vector3.UP * height * t)
		radii.append(lerpf(r0, r0 * 0.3, t))
	CityForbMeshes._tube(
		b,
		pts,
		radii,
		5,
		func(t: float) -> Color: return color.lerp(color.lightened(0.15), t),
		0.0,
		flex,
		0.2,
		0.15
	)
	return pts


## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
## narrow midrib. `under` is the paleness of the back face (mugwort's silver
## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
## `wave` how far alternate lobes twist up and down.
static func _lobed_leaf(
	b: CityForbMeshes.Builder,
	rng: RandomNumberGenerator,
	at: Vector3,
	yaw: float,
	size: float,
	lobes: int,
	color: Color,
	flex: float,
	under: float,
	spine: float,
	wave: float
) -> void:
	var tone := rng.randf_range(0.9, 1.08)
	var rise := rng.randf_range(0.3, 0.7)
	var droop := rng.randf_range(0.5, 0.9)
	var count := float(lobes) + 0.5
	CityForbMeshes._strip_leaf(
		b,
		{
			"base": at,
			"yaw": yaw,
			"rise": rise,
			"droop": droop,
			"length": size,
			"samples":
			PackedFloat32Array(
				[0.0, 0.1, 0.18, 0.26, 0.34, 0.42, 0.5, 0.58, 0.66, 0.74, 0.82, 0.9, 1.0]
			),
			"cols": 3,
			"fold": 0.2,
			"width":
			## Detailed procedural models of the tall verge and wall-foot herbs round Reval
			## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
			## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
			## (far flag, vertex contract); shares the stem, strand and leaf helpers of
			## city_herb_meshes.gd. Every seasonal variant of a species reuses the
			## flowering kind's seed, so it is the same plant in another season.
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Young April shoots are dark and purple-flushed.
			## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			# --- Field mint (Mentha arvensis) -------------------------------------------
			# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
			# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
			# from the last; from July round balls of lilac flowers sit in the upper leaf
			# axils, one whorl above another.
			# Stems sprawl out from creeping runners before they turn up.
			# Whorls of florets in the leaf axils of the upper half.
			# --- Mugwort (Artemisia vulgaris) -------------------------------------------
			# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
			# dark green above and silver-white felted below, smaller and simpler up the
			# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
			# on short side branches. In autumn the whole stand dries brown and stays up.
			# Before flowering the stems are still growing.
			# Alternate leaves up the lower two thirds.
			# The plume: short side branches on the top third, each a spray of tiny
			# ovoid heads, shorter toward the tip so the plume tapers.
			# --- Creeping thistle (Cirsium arvense) -------------------------------------
			# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
			# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
			# stem branches into many small heads: a green, purple-tipped cup under a
			# lilac brush of florets, then white thistledown in August-September.
			# Branches from the top third, each with one to three heads.
			# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
			# A loose ball of silky pappus, bigger than the head that bore it.
			# The brush: a tuft of fine lilac florets fanning up out of the cup.
			# --- Stinging nettle (Urtica dioica) ----------------------------------------
			# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
			# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
			# pair a quarter turn from the last, drooping at the tip; from July, thin
			# greenish flower tassels hang from the upper leaf axils. In April and May the
			# stand is a carpet of short, dark, purple-flushed shoots.
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
			## coarse forward-pointing teeth, drooping toward its tip.
			# Stalk for the first 12 %, a cordate base, widest at a third, then a
			# long acuminate tip; saw teeth bite into the margin.
			# Teeth point forward: the outer margin runs ahead of the midrib a little.
			## A hanging nettle flower tassel: a thin, knotted, greenish catkin.
			# --- Helpers -----------------------------------------------------------------
			## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
			## nodes; returns the centre line.
			## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
			## narrow midrib. `under` is the paleness of the back face (mugwort's silver
			## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
			## `wave` how far alternate lobes twist up and down.
			# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.
			## Detailed procedural models of the tall verge and wall-foot herbs round Reval
			## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
			## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
			## (far flag, vertex contract); shares the stem, strand and leaf helpers of
			## city_herb_meshes.gd. Every seasonal variant of a species reuses the
			## flowering kind's seed, so it is the same plant in another season.
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Young April shoots are dark and purple-flushed.
			## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			# --- Field mint (Mentha arvensis) -------------------------------------------
			# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
			# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
			# from the last; from July round balls of lilac flowers sit in the upper leaf
			# axils, one whorl above another.
			# Stems sprawl out from creeping runners before they turn up.
			# Whorls of florets in the leaf axils of the upper half.
			# --- Mugwort (Artemisia vulgaris) -------------------------------------------
			# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
			# dark green above and silver-white felted below, smaller and simpler up the
			# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
			# on short side branches. In autumn the whole stand dries brown and stays up.
			# Before flowering the stems are still growing.
			# Alternate leaves up the lower two thirds.
			# The plume: short side branches on the top third, each a spray of tiny
			# ovoid heads, shorter toward the tip so the plume tapers.
			# --- Creeping thistle (Cirsium arvense) -------------------------------------
			# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
			# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
			# stem branches into many small heads: a green, purple-tipped cup under a
			# lilac brush of florets, then white thistledown in August-September.
			# Branches from the top third, each with one to three heads.
			# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
			# A loose ball of silky pappus, bigger than the head that bore it.
			# The brush: a tuft of fine lilac florets fanning up out of the cup.
			# --- Stinging nettle (Urtica dioica) ----------------------------------------
			# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
			# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
			# pair a quarter turn from the last, drooping at the tip; from July, thin
			# greenish flower tassels hang from the upper leaf axils. In April and May the
			# stand is a carpet of short, dark, purple-flushed shoots.
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
			## coarse forward-pointing teeth, drooping toward its tip.
			# Stalk for the first 12 %, a cordate base, widest at a third, then a
			## Detailed procedural models of the tall verge and wall-foot herbs round Reval
			## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
			## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
			## (far flag, vertex contract); shares the stem, strand and leaf helpers of
			## city_herb_meshes.gd. Every seasonal variant of a species reuses the
			## flowering kind's seed, so it is the same plant in another season.
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Young April shoots are dark and purple-flushed.
			## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			# --- Field mint (Mentha arvensis) -------------------------------------------
			# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
			# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
			# from the last; from July round balls of lilac flowers sit in the upper leaf
			# axils, one whorl above another.
			# Stems sprawl out from creeping runners before they turn up.
			# Whorls of florets in the leaf axils of the upper half.
			# --- Mugwort (Artemisia vulgaris) -------------------------------------------
			# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
			# dark green above and silver-white felted below, smaller and simpler up the
			# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
			# on short side branches. In autumn the whole stand dries brown and stays up.
			# Before flowering the stems are still growing.
			# Alternate leaves up the lower two thirds.
			# The plume: short side branches on the top third, each a spray of tiny
			# ovoid heads, shorter toward the tip so the plume tapers.
			# --- Creeping thistle (Cirsium arvense) -------------------------------------
			# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
			# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
			# stem branches into many small heads: a green, purple-tipped cup under a
			# lilac brush of florets, then white thistledown in August-September.
			# Branches from the top third, each with one to three heads.
			# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
			# A loose ball of silky pappus, bigger than the head that bore it.
			# The brush: a tuft of fine lilac florets fanning up out of the cup.
			# --- Stinging nettle (Urtica dioica) ----------------------------------------
			# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
			# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
			# pair a quarter turn from the last, drooping at the tip; from July, thin
			# greenish flower tassels hang from the upper leaf axils. In April and May the
			# stand is a carpet of short, dark, purple-flushed shoots.
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
			## coarse forward-pointing teeth, drooping toward its tip.
			# Stalk for the first 12 %, a cordate base, widest at a third, then a
			# long acuminate tip; saw teeth bite into the margin.
			## Detailed procedural models of the tall verge and wall-foot herbs round Reval
			## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
			## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
			## (far flag, vertex contract); shares the stem, strand and leaf helpers of
			## city_herb_meshes.gd. Every seasonal variant of a species reuses the
			## flowering kind's seed, so it is the same plant in another season.
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Young April shoots are dark and purple-flushed.
			## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			# --- Field mint (Mentha arvensis) -------------------------------------------
			# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
			# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
			# from the last; from July round balls of lilac flowers sit in the upper leaf
			# axils, one whorl above another.
			# Stems sprawl out from creeping runners before they turn up.
			# Whorls of florets in the leaf axils of the upper half.
			# --- Mugwort (Artemisia vulgaris) -------------------------------------------
			# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
			# dark green above and silver-white felted below, smaller and simpler up the
			# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
			# on short side branches. In autumn the whole stand dries brown and stays up.
			# Before flowering the stems are still growing.
			# Alternate leaves up the lower two thirds.
			# The plume: short side branches on the top third, each a spray of tiny
			# ovoid heads, shorter toward the tip so the plume tapers.
			# --- Creeping thistle (Cirsium arvense) -------------------------------------
			# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
			# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
			# stem branches into many small heads: a green, purple-tipped cup under a
			# lilac brush of florets, then white thistledown in August-September.
			# Branches from the top third, each with one to three heads.
			# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
			# A loose ball of silky pappus, bigger than the head that bore it.
			# The brush: a tuft of fine lilac florets fanning up out of the cup.
			# --- Stinging nettle (Urtica dioica) ----------------------------------------
			# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
			# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
			# pair a quarter turn from the last, drooping at the tip; from July, thin
			# greenish flower tassels hang from the upper leaf axils. In April and May the
			# stand is a carpet of short, dark, purple-flushed shoots.
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
			## coarse forward-pointing teeth, drooping toward its tip.
			# Stalk for the first 12 %, a cordate base, widest at a third, then a
			# long acuminate tip; saw teeth bite into the margin.
			# Teeth point forward: the outer margin runs ahead of the midrib a little.
			## Detailed procedural models of the tall verge and wall-foot herbs round Reval
			## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
			## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
			## (far flag, vertex contract); shares the stem, strand and leaf helpers of
			## city_herb_meshes.gd. Every seasonal variant of a species reuses the
			## flowering kind's seed, so it is the same plant in another season.
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Young April shoots are dark and purple-flushed.
			## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			# --- Field mint (Mentha arvensis) -------------------------------------------
			# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
			# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
			# from the last; from July round balls of lilac flowers sit in the upper leaf
			# axils, one whorl above another.
			# Stems sprawl out from creeping runners before they turn up.
			# Whorls of florets in the leaf axils of the upper half.
			# --- Mugwort (Artemisia vulgaris) -------------------------------------------
			# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
			# dark green above and silver-white felted below, smaller and simpler up the
			# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
			# on short side branches. In autumn the whole stand dries brown and stays up.
			# Before flowering the stems are still growing.
			# Alternate leaves up the lower two thirds.
			# The plume: short side branches on the top third, each a spray of tiny
			# ovoid heads, shorter toward the tip so the plume tapers.
			# --- Creeping thistle (Cirsium arvense) -------------------------------------
			# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
			# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
			# stem branches into many small heads: a green, purple-tipped cup under a
			# lilac brush of florets, then white thistledown in August-September.
			# Branches from the top third, each with one to three heads.
			# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
			# A loose ball of silky pappus, bigger than the head that bore it.
			# The brush: a tuft of fine lilac florets fanning up out of the cup.
			# --- Stinging nettle (Urtica dioica) ----------------------------------------
			# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
			# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
			# pair a quarter turn from the last, drooping at the tip; from July, thin
			# greenish flower tassels hang from the upper leaf axils. In April and May the
			# stand is a carpet of short, dark, purple-flushed shoots.
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
			## coarse forward-pointing teeth, drooping toward its tip.
			# Stalk for the first 12 %, a cordate base, widest at a third, then a
			# long acuminate tip; saw teeth bite into the margin.
			# Teeth point forward: the outer margin runs ahead of the midrib a little.
			## A hanging nettle flower tassel: a thin, knotted, greenish catkin.
			# --- Helpers -----------------------------------------------------------------
			## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
			## nodes; returns the centre line.
			## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
			## narrow midrib. `under` is the paleness of the back face (mugwort's silver
			## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
			## `wave` how far alternate lobes twist up and down.
			## Detailed procedural models of the tall verge and wall-foot herbs round Reval
			## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
			## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
			## (far flag, vertex contract); shares the stem, strand and leaf helpers of
			## city_herb_meshes.gd. Every seasonal variant of a species reuses the
			## flowering kind's seed, so it is the same plant in another season.
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Young April shoots are dark and purple-flushed.
			## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			# --- Field mint (Mentha arvensis) -------------------------------------------
			# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
			# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
			# from the last; from July round balls of lilac flowers sit in the upper leaf
			# axils, one whorl above another.
			# Stems sprawl out from creeping runners before they turn up.
			# Whorls of florets in the leaf axils of the upper half.
			# --- Mugwort (Artemisia vulgaris) -------------------------------------------
			# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
			# dark green above and silver-white felted below, smaller and simpler up the
			# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
			# on short side branches. In autumn the whole stand dries brown and stays up.
			# Before flowering the stems are still growing.
			# Alternate leaves up the lower two thirds.
			# The plume: short side branches on the top third, each a spray of tiny
			# ovoid heads, shorter toward the tip so the plume tapers.
			# --- Creeping thistle (Cirsium arvense) -------------------------------------
			# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
			# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
			# stem branches into many small heads: a green, purple-tipped cup under a
			# lilac brush of florets, then white thistledown in August-September.
			# Branches from the top third, each with one to three heads.
			# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
			# A loose ball of silky pappus, bigger than the head that bore it.
			# The brush: a tuft of fine lilac florets fanning up out of the cup.
			# --- Stinging nettle (Urtica dioica) ----------------------------------------
			# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
			# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
			# pair a quarter turn from the last, drooping at the tip; from July, thin
			# greenish flower tassels hang from the upper leaf axils. In April and May the
			# stand is a carpet of short, dark, purple-flushed shoots.
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
			## coarse forward-pointing teeth, drooping toward its tip.
			# Stalk for the first 12 %, a cordate base, widest at a third, then a
			# long acuminate tip; saw teeth bite into the margin.
			# Teeth point forward: the outer margin runs ahead of the midrib a little.
			## A hanging nettle flower tassel: a thin, knotted, greenish catkin.
			# --- Helpers -----------------------------------------------------------------
			## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
			## nodes; returns the centre line.
			## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
			## narrow midrib. `under` is the paleness of the back face (mugwort's silver
			## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
			## `wave` how far alternate lobes twist up and down.
			# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.
			func(t: float) -> float:
# gdlint:disable=max-file-lines

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				## Detailed procedural models of the tall verge and wall-foot herbs round Reval
				## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
				## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
				## (far flag, vertex contract); shares the stem, strand and leaf helpers of
				## city_herb_meshes.gd. Every seasonal variant of a species reuses the
				## flowering kind's seed, so it is the same plant in another season.
				## Kind -> [species (seed), stage].
				# Colours are sRGB, picked from field photographs of each species.
				# Young April shoots are dark and purple-flushed.
				## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
				# --- Field mint (Mentha arvensis) -------------------------------------------
				# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
				# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
				# from the last; from July round balls of lilac flowers sit in the upper leaf
				# axils, one whorl above another.
				# Stems sprawl out from creeping runners before they turn up.
				# Whorls of florets in the leaf axils of the upper half.
				# --- Mugwort (Artemisia vulgaris) -------------------------------------------
				# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
				# dark green above and silver-white felted below, smaller and simpler up the
				# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
				# on short side branches. In autumn the whole stand dries brown and stays up.
				# Before flowering the stems are still growing.
				# Alternate leaves up the lower two thirds.
				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.
				# --- Creeping thistle (Cirsium arvense) -------------------------------------
				# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
				# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
				# stem branches into many small heads: a green, purple-tipped cup under a
				# lilac brush of florets, then white thistledown in August-September.
				# Branches from the top third, each with one to three heads.
				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
				# A loose ball of silky pappus, bigger than the head that bore it.
				# The brush: a tuft of fine lilac florets fanning up out of the cup.
				# --- Stinging nettle (Urtica dioica) ----------------------------------------
				# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
				# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
				# pair a quarter turn from the last, drooping at the tip; from July, thin
				# greenish flower tassels hang from the upper leaf axils. In April and May the
				# stand is a carpet of short, dark, purple-flushed shoots.
				# A short shoot: three crowded pairs of young leaves on 12-22 cm.
				## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
				## coarse forward-pointing teeth, drooping toward its tip.
				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				## Detailed procedural models of the tall verge and wall-foot herbs round Reval
				## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
				## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
				## (far flag, vertex contract); shares the stem, strand and leaf helpers of
				## city_herb_meshes.gd. Every seasonal variant of a species reuses the
				## flowering kind's seed, so it is the same plant in another season.
				## Kind -> [species (seed), stage].
				# Colours are sRGB, picked from field photographs of each species.
				# Young April shoots are dark and purple-flushed.
				## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
				# --- Field mint (Mentha arvensis) -------------------------------------------
				# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
				# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
				# from the last; from July round balls of lilac flowers sit in the upper leaf
				# axils, one whorl above another.
				# Stems sprawl out from creeping runners before they turn up.
				# Whorls of florets in the leaf axils of the upper half.
				# --- Mugwort (Artemisia vulgaris) -------------------------------------------
				# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
				# dark green above and silver-white felted below, smaller and simpler up the
				# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
				# on short side branches. In autumn the whole stand dries brown and stays up.
				# Before flowering the stems are still growing.
				# Alternate leaves up the lower two thirds.
				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.
				# --- Creeping thistle (Cirsium arvense) -------------------------------------
				# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
				# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
				# stem branches into many small heads: a green, purple-tipped cup under a
				# lilac brush of florets, then white thistledown in August-September.
				# Branches from the top third, each with one to three heads.
				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
				# A loose ball of silky pappus, bigger than the head that bore it.
				# The brush: a tuft of fine lilac florets fanning up out of the cup.
				# --- Stinging nettle (Urtica dioica) ----------------------------------------
				# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
				# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
				# pair a quarter turn from the last, drooping at the tip; from July, thin
				# greenish flower tassels hang from the upper leaf axils. In April and May the
				# stand is a carpet of short, dark, purple-flushed shoots.
				# A short shoot: three crowded pairs of young leaves on 12-22 cm.
				## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
				## coarse forward-pointing teeth, drooping toward its tip.
				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.
				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

				## Detailed procedural models of the tall verge and wall-foot herbs round Reval
				## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
				## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
				## (far flag, vertex contract); shares the stem, strand and leaf helpers of
				## city_herb_meshes.gd. Every seasonal variant of a species reuses the
				## flowering kind's seed, so it is the same plant in another season.
				## Kind -> [species (seed), stage].
				# Colours are sRGB, picked from field photographs of each species.
				# Young April shoots are dark and purple-flushed.
				## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
				# --- Field mint (Mentha arvensis) -------------------------------------------
				# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
				# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
				# from the last; from July round balls of lilac flowers sit in the upper leaf
				# axils, one whorl above another.
				# Stems sprawl out from creeping runners before they turn up.
				# Whorls of florets in the leaf axils of the upper half.
				# --- Mugwort (Artemisia vulgaris) -------------------------------------------
				# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
				# dark green above and silver-white felted below, smaller and simpler up the
				# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
				# on short side branches. In autumn the whole stand dries brown and stays up.
				# Before flowering the stems are still growing.
				# Alternate leaves up the lower two thirds.
				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.
				# --- Creeping thistle (Cirsium arvense) -------------------------------------
				# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
				# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
				# stem branches into many small heads: a green, purple-tipped cup under a
				# lilac brush of florets, then white thistledown in August-September.
				# Branches from the top third, each with one to three heads.
				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
				# A loose ball of silky pappus, bigger than the head that bore it.
				# The brush: a tuft of fine lilac florets fanning up out of the cup.
				# --- Stinging nettle (Urtica dioica) ----------------------------------------
				# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
				# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
				# pair a quarter turn from the last, drooping at the tip; from July, thin
				# greenish flower tassels hang from the upper leaf axils. In April and May the
				# stand is a carpet of short, dark, purple-flushed shoots.
				# A short shoot: three crowded pairs of young leaves on 12-22 cm.
				## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
				## coarse forward-pointing teeth, drooping toward its tip.
				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.
				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## A hanging nettle flower tassel: a thin, knotted, greenish catkin.

# --- Helpers -----------------------------------------------------------------

## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
## nodes; returns the centre line.

## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
## narrow midrib. `under` is the paleness of the back face (mugwort's silver
## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
## `wave` how far alternate lobes twist up and down.

				## Detailed procedural models of the tall verge and wall-foot herbs round Reval
				## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
				## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
				## (far flag, vertex contract); shares the stem, strand and leaf helpers of
				## city_herb_meshes.gd. Every seasonal variant of a species reuses the
				## flowering kind's seed, so it is the same plant in another season.
				## Kind -> [species (seed), stage].
				# Colours are sRGB, picked from field photographs of each species.
				# Young April shoots are dark and purple-flushed.
				## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
				# --- Field mint (Mentha arvensis) -------------------------------------------
				# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
				# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
				# from the last; from July round balls of lilac flowers sit in the upper leaf
				# axils, one whorl above another.
				# Stems sprawl out from creeping runners before they turn up.
				# Whorls of florets in the leaf axils of the upper half.
				# --- Mugwort (Artemisia vulgaris) -------------------------------------------
				# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
				# dark green above and silver-white felted below, smaller and simpler up the
				# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
				# on short side branches. In autumn the whole stand dries brown and stays up.
				# Before flowering the stems are still growing.
				# Alternate leaves up the lower two thirds.
				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.
				# --- Creeping thistle (Cirsium arvense) -------------------------------------
				# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
				# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
				# stem branches into many small heads: a green, purple-tipped cup under a
				# lilac brush of florets, then white thistledown in August-September.
				# Branches from the top third, each with one to three heads.
				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
				# A loose ball of silky pappus, bigger than the head that bore it.
				# The brush: a tuft of fine lilac florets fanning up out of the cup.
				# --- Stinging nettle (Urtica dioica) ----------------------------------------
				# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
				# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
				# pair a quarter turn from the last, drooping at the tip; from July, thin
				# greenish flower tassels hang from the upper leaf axils. In April and May the
				# stand is a carpet of short, dark, purple-flushed shoots.
				# A short shoot: three crowded pairs of young leaves on 12-22 cm.
				## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
				## coarse forward-pointing teeth, drooping toward its tip.
				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.
				# Teeth point forward: the outer margin runs ahead of the midrib a little.
				## A hanging nettle flower tassel: a thin, knotted, greenish catkin.
				# --- Helpers -----------------------------------------------------------------
				## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
				## nodes; returns the centre line.
				## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
				## narrow midrib. `under` is the paleness of the back face (mugwort's silver
				## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
				## `wave` how far alternate lobes twist up and down.
				# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## A hanging nettle flower tassel: a thin, knotted, greenish catkin.

# --- Helpers -----------------------------------------------------------------

## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
## nodes; returns the centre line.

## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
## narrow midrib. `under` is the paleness of the back face (mugwort's silver
## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
## `wave` how far alternate lobes twist up and down.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## A hanging nettle flower tassel: a thin, knotted, greenish catkin.

# --- Helpers -----------------------------------------------------------------

## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
## nodes; returns the centre line.

## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
## narrow midrib. `under` is the paleness of the back face (mugwort's silver
## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
## `wave` how far alternate lobes twist up and down.

				# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.

				var env := size * 0.3 * sin(PI * minf(t * 0.9 + 0.08, 1.0))
				var lobe := absf(sin(t * PI * count))
				return env * (0.22 + 0.78 * pow(lobe, 1.6)),
			"shift":
			## Detailed procedural models of the tall verge and wall-foot herbs round Reval
			## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
			## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
			## (far flag, vertex contract); shares the stem, strand and leaf helpers of
			## city_herb_meshes.gd. Every seasonal variant of a species reuses the
			## flowering kind's seed, so it is the same plant in another season.
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Young April shoots are dark and purple-flushed.
			## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			# --- Field mint (Mentha arvensis) -------------------------------------------
			# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
			# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
			# from the last; from July round balls of lilac flowers sit in the upper leaf
			# axils, one whorl above another.
			# Stems sprawl out from creeping runners before they turn up.
			# Whorls of florets in the leaf axils of the upper half.
			# --- Mugwort (Artemisia vulgaris) -------------------------------------------
			# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
			# dark green above and silver-white felted below, smaller and simpler up the
			# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
			# on short side branches. In autumn the whole stand dries brown and stays up.
			# Before flowering the stems are still growing.
			# Alternate leaves up the lower two thirds.
			# The plume: short side branches on the top third, each a spray of tiny
			# ovoid heads, shorter toward the tip so the plume tapers.
			# --- Creeping thistle (Cirsium arvense) -------------------------------------
			# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
			# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
			# stem branches into many small heads: a green, purple-tipped cup under a
			# lilac brush of florets, then white thistledown in August-September.
			# Branches from the top third, each with one to three heads.
			# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
			# A loose ball of silky pappus, bigger than the head that bore it.
			# The brush: a tuft of fine lilac florets fanning up out of the cup.
			# --- Stinging nettle (Urtica dioica) ----------------------------------------
			# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
			# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
			# pair a quarter turn from the last, drooping at the tip; from July, thin
			# greenish flower tassels hang from the upper leaf axils. In April and May the
			# stand is a carpet of short, dark, purple-flushed shoots.
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
			## coarse forward-pointing teeth, drooping toward its tip.
			# Stalk for the first 12 %, a cordate base, widest at a third, then a
			# long acuminate tip; saw teeth bite into the margin.
			# Teeth point forward: the outer margin runs ahead of the midrib a little.
			## A hanging nettle flower tassel: a thin, knotted, greenish catkin.
			# --- Helpers -----------------------------------------------------------------
			## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
			## nodes; returns the centre line.
			## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
			## narrow midrib. `under` is the paleness of the back face (mugwort's silver
			## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
			## `wave` how far alternate lobes twist up and down.
			# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.
			## Detailed procedural models of the tall verge and wall-foot herbs round Reval
			## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
			## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
			## (far flag, vertex contract); shares the stem, strand and leaf helpers of
			## city_herb_meshes.gd. Every seasonal variant of a species reuses the
			## flowering kind's seed, so it is the same plant in another season.
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Young April shoots are dark and purple-flushed.
			## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			# --- Field mint (Mentha arvensis) -------------------------------------------
			# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
			# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
			# from the last; from July round balls of lilac flowers sit in the upper leaf
			# axils, one whorl above another.
			# Stems sprawl out from creeping runners before they turn up.
			# Whorls of florets in the leaf axils of the upper half.
			# --- Mugwort (Artemisia vulgaris) -------------------------------------------
			# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
			# dark green above and silver-white felted below, smaller and simpler up the
			# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
			# on short side branches. In autumn the whole stand dries brown and stays up.
			# Before flowering the stems are still growing.
			# Alternate leaves up the lower two thirds.
			# The plume: short side branches on the top third, each a spray of tiny
			# ovoid heads, shorter toward the tip so the plume tapers.
			# --- Creeping thistle (Cirsium arvense) -------------------------------------
			# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
			# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
			# stem branches into many small heads: a green, purple-tipped cup under a
			# lilac brush of florets, then white thistledown in August-September.
			# Branches from the top third, each with one to three heads.
			# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
			# A loose ball of silky pappus, bigger than the head that bore it.
			# The brush: a tuft of fine lilac florets fanning up out of the cup.
			# --- Stinging nettle (Urtica dioica) ----------------------------------------
			# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
			# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
			# pair a quarter turn from the last, drooping at the tip; from July, thin
			# greenish flower tassels hang from the upper leaf axils. In April and May the
			# stand is a carpet of short, dark, purple-flushed shoots.
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
			## coarse forward-pointing teeth, drooping toward its tip.
			# Stalk for the first 12 %, a cordate base, widest at a third, then a
			## Detailed procedural models of the tall verge and wall-foot herbs round Reval
			## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
			## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
			## (far flag, vertex contract); shares the stem, strand and leaf helpers of
			## city_herb_meshes.gd. Every seasonal variant of a species reuses the
			## flowering kind's seed, so it is the same plant in another season.
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Young April shoots are dark and purple-flushed.
			## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			# --- Field mint (Mentha arvensis) -------------------------------------------
			# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
			# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
			# from the last; from July round balls of lilac flowers sit in the upper leaf
			# axils, one whorl above another.
			# Stems sprawl out from creeping runners before they turn up.
			# Whorls of florets in the leaf axils of the upper half.
			# --- Mugwort (Artemisia vulgaris) -------------------------------------------
			# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
			# dark green above and silver-white felted below, smaller and simpler up the
			# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
			# on short side branches. In autumn the whole stand dries brown and stays up.
			# Before flowering the stems are still growing.
			# Alternate leaves up the lower two thirds.
			# The plume: short side branches on the top third, each a spray of tiny
			# ovoid heads, shorter toward the tip so the plume tapers.
			# --- Creeping thistle (Cirsium arvense) -------------------------------------
			# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
			# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
			# stem branches into many small heads: a green, purple-tipped cup under a
			# lilac brush of florets, then white thistledown in August-September.
			# Branches from the top third, each with one to three heads.
			# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
			# A loose ball of silky pappus, bigger than the head that bore it.
			# The brush: a tuft of fine lilac florets fanning up out of the cup.
			# --- Stinging nettle (Urtica dioica) ----------------------------------------
			# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
			# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
			# pair a quarter turn from the last, drooping at the tip; from July, thin
			# greenish flower tassels hang from the upper leaf axils. In April and May the
			# stand is a carpet of short, dark, purple-flushed shoots.
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
			## coarse forward-pointing teeth, drooping toward its tip.
			# Stalk for the first 12 %, a cordate base, widest at a third, then a
			# long acuminate tip; saw teeth bite into the margin.
			## Detailed procedural models of the tall verge and wall-foot herbs round Reval
			## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
			## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
			## (far flag, vertex contract); shares the stem, strand and leaf helpers of
			## city_herb_meshes.gd. Every seasonal variant of a species reuses the
			## flowering kind's seed, so it is the same plant in another season.
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Young April shoots are dark and purple-flushed.
			## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			# --- Field mint (Mentha arvensis) -------------------------------------------
			# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
			# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
			# from the last; from July round balls of lilac flowers sit in the upper leaf
			# axils, one whorl above another.
			# Stems sprawl out from creeping runners before they turn up.
			# Whorls of florets in the leaf axils of the upper half.
			# --- Mugwort (Artemisia vulgaris) -------------------------------------------
			# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
			# dark green above and silver-white felted below, smaller and simpler up the
			# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
			# on short side branches. In autumn the whole stand dries brown and stays up.
			# Before flowering the stems are still growing.
			# Alternate leaves up the lower two thirds.
			# The plume: short side branches on the top third, each a spray of tiny
			# ovoid heads, shorter toward the tip so the plume tapers.
			# --- Creeping thistle (Cirsium arvense) -------------------------------------
			# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
			# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
			# stem branches into many small heads: a green, purple-tipped cup under a
			# lilac brush of florets, then white thistledown in August-September.
			# Branches from the top third, each with one to three heads.
			# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
			# A loose ball of silky pappus, bigger than the head that bore it.
			# The brush: a tuft of fine lilac florets fanning up out of the cup.
			# --- Stinging nettle (Urtica dioica) ----------------------------------------
			# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
			# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
			# pair a quarter turn from the last, drooping at the tip; from July, thin
			# greenish flower tassels hang from the upper leaf axils. In April and May the
			# stand is a carpet of short, dark, purple-flushed shoots.
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
			## coarse forward-pointing teeth, drooping toward its tip.
			# Stalk for the first 12 %, a cordate base, widest at a third, then a
			# long acuminate tip; saw teeth bite into the margin.
			# Teeth point forward: the outer margin runs ahead of the midrib a little.
			## Detailed procedural models of the tall verge and wall-foot herbs round Reval
			## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
			## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
			## (far flag, vertex contract); shares the stem, strand and leaf helpers of
			## city_herb_meshes.gd. Every seasonal variant of a species reuses the
			## flowering kind's seed, so it is the same plant in another season.
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Young April shoots are dark and purple-flushed.
			## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			# --- Field mint (Mentha arvensis) -------------------------------------------
			# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
			# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
			# from the last; from July round balls of lilac flowers sit in the upper leaf
			# axils, one whorl above another.
			# Stems sprawl out from creeping runners before they turn up.
			# Whorls of florets in the leaf axils of the upper half.
			# --- Mugwort (Artemisia vulgaris) -------------------------------------------
			# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
			# dark green above and silver-white felted below, smaller and simpler up the
			# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
			# on short side branches. In autumn the whole stand dries brown and stays up.
			# Before flowering the stems are still growing.
			# Alternate leaves up the lower two thirds.
			# The plume: short side branches on the top third, each a spray of tiny
			# ovoid heads, shorter toward the tip so the plume tapers.
			# --- Creeping thistle (Cirsium arvense) -------------------------------------
			# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
			# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
			# stem branches into many small heads: a green, purple-tipped cup under a
			# lilac brush of florets, then white thistledown in August-September.
			# Branches from the top third, each with one to three heads.
			# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
			# A loose ball of silky pappus, bigger than the head that bore it.
			# The brush: a tuft of fine lilac florets fanning up out of the cup.
			# --- Stinging nettle (Urtica dioica) ----------------------------------------
			# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
			# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
			# pair a quarter turn from the last, drooping at the tip; from July, thin
			# greenish flower tassels hang from the upper leaf axils. In April and May the
			# stand is a carpet of short, dark, purple-flushed shoots.
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
			## coarse forward-pointing teeth, drooping toward its tip.
			# Stalk for the first 12 %, a cordate base, widest at a third, then a
			# long acuminate tip; saw teeth bite into the margin.
			# Teeth point forward: the outer margin runs ahead of the midrib a little.
			## A hanging nettle flower tassel: a thin, knotted, greenish catkin.
			# --- Helpers -----------------------------------------------------------------
			## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
			## nodes; returns the centre line.
			## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
			## narrow midrib. `under` is the paleness of the back face (mugwort's silver
			## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
			## `wave` how far alternate lobes twist up and down.
			## Detailed procedural models of the tall verge and wall-foot herbs round Reval
			## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
			## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
			## (far flag, vertex contract); shares the stem, strand and leaf helpers of
			## city_herb_meshes.gd. Every seasonal variant of a species reuses the
			## flowering kind's seed, so it is the same plant in another season.
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Young April shoots are dark and purple-flushed.
			## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			# --- Field mint (Mentha arvensis) -------------------------------------------
			# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
			# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
			# from the last; from July round balls of lilac flowers sit in the upper leaf
			# axils, one whorl above another.
			# Stems sprawl out from creeping runners before they turn up.
			# Whorls of florets in the leaf axils of the upper half.
			# --- Mugwort (Artemisia vulgaris) -------------------------------------------
			# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
			# dark green above and silver-white felted below, smaller and simpler up the
			# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
			# on short side branches. In autumn the whole stand dries brown and stays up.
			# Before flowering the stems are still growing.
			# Alternate leaves up the lower two thirds.
			# The plume: short side branches on the top third, each a spray of tiny
			# ovoid heads, shorter toward the tip so the plume tapers.
			# --- Creeping thistle (Cirsium arvense) -------------------------------------
			# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
			# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
			# stem branches into many small heads: a green, purple-tipped cup under a
			# lilac brush of florets, then white thistledown in August-September.
			# Branches from the top third, each with one to three heads.
			# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
			# A loose ball of silky pappus, bigger than the head that bore it.
			# The brush: a tuft of fine lilac florets fanning up out of the cup.
			# --- Stinging nettle (Urtica dioica) ----------------------------------------
			# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
			# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
			# pair a quarter turn from the last, drooping at the tip; from July, thin
			# greenish flower tassels hang from the upper leaf axils. In April and May the
			# stand is a carpet of short, dark, purple-flushed shoots.
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
			## coarse forward-pointing teeth, drooping toward its tip.
			# Stalk for the first 12 %, a cordate base, widest at a third, then a
			# long acuminate tip; saw teeth bite into the margin.
			# Teeth point forward: the outer margin runs ahead of the midrib a little.
			## A hanging nettle flower tassel: a thin, knotted, greenish catkin.
			# --- Helpers -----------------------------------------------------------------
			## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
			## nodes; returns the centre line.
			## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
			## narrow midrib. `under` is the paleness of the back face (mugwort's silver
			## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
			## `wave` how far alternate lobes twist up and down.
			# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.
			## Detailed procedural models of the tall verge and wall-foot herbs round Reval
			## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
			## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
			## (far flag, vertex contract); shares the stem, strand and leaf helpers of
			## city_herb_meshes.gd. Every seasonal variant of a species reuses the
			## flowering kind's seed, so it is the same plant in another season.
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Young April shoots are dark and purple-flushed.
			## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			# --- Field mint (Mentha arvensis) -------------------------------------------
			# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
			# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
			# from the last; from July round balls of lilac flowers sit in the upper leaf
			# axils, one whorl above another.
			# Stems sprawl out from creeping runners before they turn up.
			# Whorls of florets in the leaf axils of the upper half.
			# --- Mugwort (Artemisia vulgaris) -------------------------------------------
			# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
			# dark green above and silver-white felted below, smaller and simpler up the
			# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
			# on short side branches. In autumn the whole stand dries brown and stays up.
			# Before flowering the stems are still growing.
			# Alternate leaves up the lower two thirds.
			# The plume: short side branches on the top third, each a spray of tiny
			# ovoid heads, shorter toward the tip so the plume tapers.
			# --- Creeping thistle (Cirsium arvense) -------------------------------------
			# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
			# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
			# stem branches into many small heads: a green, purple-tipped cup under a
			# lilac brush of florets, then white thistledown in August-September.
			# Branches from the top third, each with one to three heads.
			# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
			# A loose ball of silky pappus, bigger than the head that bore it.
			# The brush: a tuft of fine lilac florets fanning up out of the cup.
			# --- Stinging nettle (Urtica dioica) ----------------------------------------
			# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
			# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
			# pair a quarter turn from the last, drooping at the tip; from July, thin
			# greenish flower tassels hang from the upper leaf axils. In April and May the
			# stand is a carpet of short, dark, purple-flushed shoots.
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
			## coarse forward-pointing teeth, drooping toward its tip.
			# Stalk for the first 12 %, a cordate base, widest at a third, then a
			# long acuminate tip; saw teeth bite into the margin.
			# Teeth point forward: the outer margin runs ahead of the midrib a little.
			## A hanging nettle flower tassel: a thin, knotted, greenish catkin.
			# --- Helpers -----------------------------------------------------------------
			## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
			## nodes; returns the centre line.
			## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
			## narrow midrib. `under` is the paleness of the back face (mugwort's silver
			## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
			## `wave` how far alternate lobes twist up and down.
			# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.
			func(t: float, s: float) -> float:
# gdlint:disable=max-file-lines

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				## Detailed procedural models of the tall verge and wall-foot herbs round Reval
				## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
				## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
				## (far flag, vertex contract); shares the stem, strand and leaf helpers of
				## city_herb_meshes.gd. Every seasonal variant of a species reuses the
				## flowering kind's seed, so it is the same plant in another season.
				## Kind -> [species (seed), stage].
				# Colours are sRGB, picked from field photographs of each species.
				# Young April shoots are dark and purple-flushed.
				## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
				# --- Field mint (Mentha arvensis) -------------------------------------------
				# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
				# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
				# from the last; from July round balls of lilac flowers sit in the upper leaf
				# axils, one whorl above another.
				# Stems sprawl out from creeping runners before they turn up.
				# Whorls of florets in the leaf axils of the upper half.
				# --- Mugwort (Artemisia vulgaris) -------------------------------------------
				# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
				# dark green above and silver-white felted below, smaller and simpler up the
				# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
				# on short side branches. In autumn the whole stand dries brown and stays up.
				# Before flowering the stems are still growing.
				# Alternate leaves up the lower two thirds.
				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.
				# --- Creeping thistle (Cirsium arvense) -------------------------------------
				# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
				# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
				# stem branches into many small heads: a green, purple-tipped cup under a
				# lilac brush of florets, then white thistledown in August-September.
				# Branches from the top third, each with one to three heads.
				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
				# A loose ball of silky pappus, bigger than the head that bore it.
				# The brush: a tuft of fine lilac florets fanning up out of the cup.
				# --- Stinging nettle (Urtica dioica) ----------------------------------------
				# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
				# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
				# pair a quarter turn from the last, drooping at the tip; from July, thin
				# greenish flower tassels hang from the upper leaf axils. In April and May the
				# stand is a carpet of short, dark, purple-flushed shoots.
				# A short shoot: three crowded pairs of young leaves on 12-22 cm.
				## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
				## coarse forward-pointing teeth, drooping toward its tip.
				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				## Detailed procedural models of the tall verge and wall-foot herbs round Reval
				## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
				## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
				## (far flag, vertex contract); shares the stem, strand and leaf helpers of
				## city_herb_meshes.gd. Every seasonal variant of a species reuses the
				## flowering kind's seed, so it is the same plant in another season.
				## Kind -> [species (seed), stage].
				# Colours are sRGB, picked from field photographs of each species.
				# Young April shoots are dark and purple-flushed.
				## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
				# --- Field mint (Mentha arvensis) -------------------------------------------
				# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
				# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
				# from the last; from July round balls of lilac flowers sit in the upper leaf
				# axils, one whorl above another.
				# Stems sprawl out from creeping runners before they turn up.
				# Whorls of florets in the leaf axils of the upper half.
				# --- Mugwort (Artemisia vulgaris) -------------------------------------------
				# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
				# dark green above and silver-white felted below, smaller and simpler up the
				# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
				# on short side branches. In autumn the whole stand dries brown and stays up.
				# Before flowering the stems are still growing.
				# Alternate leaves up the lower two thirds.
				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.
				# --- Creeping thistle (Cirsium arvense) -------------------------------------
				# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
				# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
				# stem branches into many small heads: a green, purple-tipped cup under a
				# lilac brush of florets, then white thistledown in August-September.
				# Branches from the top third, each with one to three heads.
				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
				# A loose ball of silky pappus, bigger than the head that bore it.
				# The brush: a tuft of fine lilac florets fanning up out of the cup.
				# --- Stinging nettle (Urtica dioica) ----------------------------------------
				# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
				# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
				# pair a quarter turn from the last, drooping at the tip; from July, thin
				# greenish flower tassels hang from the upper leaf axils. In April and May the
				# stand is a carpet of short, dark, purple-flushed shoots.
				# A short shoot: three crowded pairs of young leaves on 12-22 cm.
				## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
				## coarse forward-pointing teeth, drooping toward its tip.
				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.
				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

				## Detailed procedural models of the tall verge and wall-foot herbs round Reval
				## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
				## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
				## (far flag, vertex contract); shares the stem, strand and leaf helpers of
				## city_herb_meshes.gd. Every seasonal variant of a species reuses the
				## flowering kind's seed, so it is the same plant in another season.
				## Kind -> [species (seed), stage].
				# Colours are sRGB, picked from field photographs of each species.
				# Young April shoots are dark and purple-flushed.
				## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
				# --- Field mint (Mentha arvensis) -------------------------------------------
				# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
				# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
				# from the last; from July round balls of lilac flowers sit in the upper leaf
				# axils, one whorl above another.
				# Stems sprawl out from creeping runners before they turn up.
				# Whorls of florets in the leaf axils of the upper half.
				# --- Mugwort (Artemisia vulgaris) -------------------------------------------
				# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
				# dark green above and silver-white felted below, smaller and simpler up the
				# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
				# on short side branches. In autumn the whole stand dries brown and stays up.
				# Before flowering the stems are still growing.
				# Alternate leaves up the lower two thirds.
				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.
				# --- Creeping thistle (Cirsium arvense) -------------------------------------
				# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
				# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
				# stem branches into many small heads: a green, purple-tipped cup under a
				# lilac brush of florets, then white thistledown in August-September.
				# Branches from the top third, each with one to three heads.
				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
				# A loose ball of silky pappus, bigger than the head that bore it.
				# The brush: a tuft of fine lilac florets fanning up out of the cup.
				# --- Stinging nettle (Urtica dioica) ----------------------------------------
				# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
				# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
				# pair a quarter turn from the last, drooping at the tip; from July, thin
				# greenish flower tassels hang from the upper leaf axils. In April and May the
				# stand is a carpet of short, dark, purple-flushed shoots.
				# A short shoot: three crowded pairs of young leaves on 12-22 cm.
				## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
				## coarse forward-pointing teeth, drooping toward its tip.
				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.
				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## A hanging nettle flower tassel: a thin, knotted, greenish catkin.

# --- Helpers -----------------------------------------------------------------

## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
## nodes; returns the centre line.

## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
## narrow midrib. `under` is the paleness of the back face (mugwort's silver
## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
## `wave` how far alternate lobes twist up and down.

				## Detailed procedural models of the tall verge and wall-foot herbs round Reval
				## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
				## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
				## (far flag, vertex contract); shares the stem, strand and leaf helpers of
				## city_herb_meshes.gd. Every seasonal variant of a species reuses the
				## flowering kind's seed, so it is the same plant in another season.
				## Kind -> [species (seed), stage].
				# Colours are sRGB, picked from field photographs of each species.
				# Young April shoots are dark and purple-flushed.
				## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
				# --- Field mint (Mentha arvensis) -------------------------------------------
				# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
				# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
				# from the last; from July round balls of lilac flowers sit in the upper leaf
				# axils, one whorl above another.
				# Stems sprawl out from creeping runners before they turn up.
				# Whorls of florets in the leaf axils of the upper half.
				# --- Mugwort (Artemisia vulgaris) -------------------------------------------
				# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
				# dark green above and silver-white felted below, smaller and simpler up the
				# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
				# on short side branches. In autumn the whole stand dries brown and stays up.
				# Before flowering the stems are still growing.
				# Alternate leaves up the lower two thirds.
				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.
				# --- Creeping thistle (Cirsium arvense) -------------------------------------
				# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
				# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
				# stem branches into many small heads: a green, purple-tipped cup under a
				# lilac brush of florets, then white thistledown in August-September.
				# Branches from the top third, each with one to three heads.
				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
				# A loose ball of silky pappus, bigger than the head that bore it.
				# The brush: a tuft of fine lilac florets fanning up out of the cup.
				# --- Stinging nettle (Urtica dioica) ----------------------------------------
				# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
				# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
				# pair a quarter turn from the last, drooping at the tip; from July, thin
				# greenish flower tassels hang from the upper leaf axils. In April and May the
				# stand is a carpet of short, dark, purple-flushed shoots.
				# A short shoot: three crowded pairs of young leaves on 12-22 cm.
				## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
				## coarse forward-pointing teeth, drooping toward its tip.
				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.
				# Teeth point forward: the outer margin runs ahead of the midrib a little.
				## A hanging nettle flower tassel: a thin, knotted, greenish catkin.
				# --- Helpers -----------------------------------------------------------------
				## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
				## nodes; returns the centre line.
				## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
				## narrow midrib. `under` is the paleness of the back face (mugwort's silver
				## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
				## `wave` how far alternate lobes twist up and down.
				# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## A hanging nettle flower tassel: a thin, knotted, greenish catkin.

# --- Helpers -----------------------------------------------------------------

## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
## nodes; returns the centre line.

## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
## narrow midrib. `under` is the paleness of the back face (mugwort's silver
## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
## `wave` how far alternate lobes twist up and down.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## A hanging nettle flower tassel: a thin, knotted, greenish catkin.

# --- Helpers -----------------------------------------------------------------

## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
## nodes; returns the centre line.

## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
## narrow midrib. `under` is the paleness of the back face (mugwort's silver
## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
## `wave` how far alternate lobes twist up and down.

				# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.

				## Detailed procedural models of the tall verge and wall-foot herbs round Reval
				## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
				## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
				## (far flag, vertex contract); shares the stem, strand and leaf helpers of
				## city_herb_meshes.gd. Every seasonal variant of a species reuses the
				## flowering kind's seed, so it is the same plant in another season.
				## Kind -> [species (seed), stage].
				# Colours are sRGB, picked from field photographs of each species.
				# Young April shoots are dark and purple-flushed.
				## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
				# --- Field mint (Mentha arvensis) -------------------------------------------
				# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
				# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
				# from the last; from July round balls of lilac flowers sit in the upper leaf
				# axils, one whorl above another.
				# Stems sprawl out from creeping runners before they turn up.
				# Whorls of florets in the leaf axils of the upper half.
				# --- Mugwort (Artemisia vulgaris) -------------------------------------------
				# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
				# dark green above and silver-white felted below, smaller and simpler up the
				# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
				# on short side branches. In autumn the whole stand dries brown and stays up.
				# Before flowering the stems are still growing.
				# Alternate leaves up the lower two thirds.
				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.
				# --- Creeping thistle (Cirsium arvense) -------------------------------------
				# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
				# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
				# stem branches into many small heads: a green, purple-tipped cup under a
				# lilac brush of florets, then white thistledown in August-September.
				# Branches from the top third, each with one to three heads.
				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
				# A loose ball of silky pappus, bigger than the head that bore it.
				# The brush: a tuft of fine lilac florets fanning up out of the cup.
				# --- Stinging nettle (Urtica dioica) ----------------------------------------
				# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
				# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
				# pair a quarter turn from the last, drooping at the tip; from July, thin
				# greenish flower tassels hang from the upper leaf axils. In April and May the
				# stand is a carpet of short, dark, purple-flushed shoots.
				# A short shoot: three crowded pairs of young leaves on 12-22 cm.
				## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
				## coarse forward-pointing teeth, drooping toward its tip.
				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.
				# Teeth point forward: the outer margin runs ahead of the midrib a little.
				## A hanging nettle flower tassel: a thin, knotted, greenish catkin.
				# --- Helpers -----------------------------------------------------------------
				## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
				## nodes; returns the centre line.
				## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
				## narrow midrib. `under` is the paleness of the back face (mugwort's silver
				## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
				## `wave` how far alternate lobes twist up and down.
				# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## A hanging nettle flower tassel: a thin, knotted, greenish catkin.

# --- Helpers -----------------------------------------------------------------

## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
## nodes; returns the centre line.

## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
## narrow midrib. `under` is the paleness of the back face (mugwort's silver
## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
## `wave` how far alternate lobes twist up and down.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## A hanging nettle flower tassel: a thin, knotted, greenish catkin.

# --- Helpers -----------------------------------------------------------------

## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
## nodes; returns the centre line.

## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
## narrow midrib. `under` is the paleness of the back face (mugwort's silver
## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
## `wave` how far alternate lobes twist up and down.

				# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## A hanging nettle flower tassel: a thin, knotted, greenish catkin.

# --- Helpers -----------------------------------------------------------------

## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
## nodes; returns the centre line.

## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
## narrow midrib. `under` is the paleness of the back face (mugwort's silver
## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
## `wave` how far alternate lobes twist up and down.

				# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.

				return absf(s) * size * 0.05 * absf(sin(t * PI * count)),
			"ridge":
			## Detailed procedural models of the tall verge and wall-foot herbs round Reval
			## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
			## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
			## (far flag, vertex contract); shares the stem, strand and leaf helpers of
			## city_herb_meshes.gd. Every seasonal variant of a species reuses the
			## flowering kind's seed, so it is the same plant in another season.
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Young April shoots are dark and purple-flushed.
			## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			# --- Field mint (Mentha arvensis) -------------------------------------------
			# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
			# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
			# from the last; from July round balls of lilac flowers sit in the upper leaf
			# axils, one whorl above another.
			# Stems sprawl out from creeping runners before they turn up.
			# Whorls of florets in the leaf axils of the upper half.
			# --- Mugwort (Artemisia vulgaris) -------------------------------------------
			# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
			# dark green above and silver-white felted below, smaller and simpler up the
			# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
			# on short side branches. In autumn the whole stand dries brown and stays up.
			# Before flowering the stems are still growing.
			# Alternate leaves up the lower two thirds.
			# The plume: short side branches on the top third, each a spray of tiny
			# ovoid heads, shorter toward the tip so the plume tapers.
			# --- Creeping thistle (Cirsium arvense) -------------------------------------
			# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
			# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
			# stem branches into many small heads: a green, purple-tipped cup under a
			# lilac brush of florets, then white thistledown in August-September.
			# Branches from the top third, each with one to three heads.
			# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
			# A loose ball of silky pappus, bigger than the head that bore it.
			# The brush: a tuft of fine lilac florets fanning up out of the cup.
			# --- Stinging nettle (Urtica dioica) ----------------------------------------
			# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
			# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
			# pair a quarter turn from the last, drooping at the tip; from July, thin
			# greenish flower tassels hang from the upper leaf axils. In April and May the
			# stand is a carpet of short, dark, purple-flushed shoots.
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
			## coarse forward-pointing teeth, drooping toward its tip.
			# Stalk for the first 12 %, a cordate base, widest at a third, then a
			# long acuminate tip; saw teeth bite into the margin.
			# Teeth point forward: the outer margin runs ahead of the midrib a little.
			## A hanging nettle flower tassel: a thin, knotted, greenish catkin.
			# --- Helpers -----------------------------------------------------------------
			## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
			## nodes; returns the centre line.
			## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
			## narrow midrib. `under` is the paleness of the back face (mugwort's silver
			## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
			## `wave` how far alternate lobes twist up and down.
			# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.
			## Detailed procedural models of the tall verge and wall-foot herbs round Reval
			## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
			## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
			## (far flag, vertex contract); shares the stem, strand and leaf helpers of
			## city_herb_meshes.gd. Every seasonal variant of a species reuses the
			## flowering kind's seed, so it is the same plant in another season.
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Young April shoots are dark and purple-flushed.
			## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			# --- Field mint (Mentha arvensis) -------------------------------------------
			# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
			# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
			# from the last; from July round balls of lilac flowers sit in the upper leaf
			# axils, one whorl above another.
			# Stems sprawl out from creeping runners before they turn up.
			# Whorls of florets in the leaf axils of the upper half.
			# --- Mugwort (Artemisia vulgaris) -------------------------------------------
			# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
			# dark green above and silver-white felted below, smaller and simpler up the
			# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
			# on short side branches. In autumn the whole stand dries brown and stays up.
			# Before flowering the stems are still growing.
			# Alternate leaves up the lower two thirds.
			# The plume: short side branches on the top third, each a spray of tiny
			# ovoid heads, shorter toward the tip so the plume tapers.
			# --- Creeping thistle (Cirsium arvense) -------------------------------------
			# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
			# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
			# stem branches into many small heads: a green, purple-tipped cup under a
			# lilac brush of florets, then white thistledown in August-September.
			# Branches from the top third, each with one to three heads.
			# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
			# A loose ball of silky pappus, bigger than the head that bore it.
			# The brush: a tuft of fine lilac florets fanning up out of the cup.
			# --- Stinging nettle (Urtica dioica) ----------------------------------------
			# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
			# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
			# pair a quarter turn from the last, drooping at the tip; from July, thin
			# greenish flower tassels hang from the upper leaf axils. In April and May the
			# stand is a carpet of short, dark, purple-flushed shoots.
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
			## coarse forward-pointing teeth, drooping toward its tip.
			# Stalk for the first 12 %, a cordate base, widest at a third, then a
			## Detailed procedural models of the tall verge and wall-foot herbs round Reval
			## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
			## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
			## (far flag, vertex contract); shares the stem, strand and leaf helpers of
			## city_herb_meshes.gd. Every seasonal variant of a species reuses the
			## flowering kind's seed, so it is the same plant in another season.
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Young April shoots are dark and purple-flushed.
			## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			# --- Field mint (Mentha arvensis) -------------------------------------------
			# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
			# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
			# from the last; from July round balls of lilac flowers sit in the upper leaf
			# axils, one whorl above another.
			# Stems sprawl out from creeping runners before they turn up.
			# Whorls of florets in the leaf axils of the upper half.
			# --- Mugwort (Artemisia vulgaris) -------------------------------------------
			# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
			# dark green above and silver-white felted below, smaller and simpler up the
			# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
			# on short side branches. In autumn the whole stand dries brown and stays up.
			# Before flowering the stems are still growing.
			# Alternate leaves up the lower two thirds.
			# The plume: short side branches on the top third, each a spray of tiny
			# ovoid heads, shorter toward the tip so the plume tapers.
			# --- Creeping thistle (Cirsium arvense) -------------------------------------
			# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
			# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
			# stem branches into many small heads: a green, purple-tipped cup under a
			# lilac brush of florets, then white thistledown in August-September.
			# Branches from the top third, each with one to three heads.
			# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
			# A loose ball of silky pappus, bigger than the head that bore it.
			# The brush: a tuft of fine lilac florets fanning up out of the cup.
			# --- Stinging nettle (Urtica dioica) ----------------------------------------
			# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
			# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
			# pair a quarter turn from the last, drooping at the tip; from July, thin
			# greenish flower tassels hang from the upper leaf axils. In April and May the
			# stand is a carpet of short, dark, purple-flushed shoots.
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
			## coarse forward-pointing teeth, drooping toward its tip.
			# Stalk for the first 12 %, a cordate base, widest at a third, then a
			# long acuminate tip; saw teeth bite into the margin.
			## Detailed procedural models of the tall verge and wall-foot herbs round Reval
			## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
			## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
			## (far flag, vertex contract); shares the stem, strand and leaf helpers of
			## city_herb_meshes.gd. Every seasonal variant of a species reuses the
			## flowering kind's seed, so it is the same plant in another season.
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Young April shoots are dark and purple-flushed.
			## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			# --- Field mint (Mentha arvensis) -------------------------------------------
			# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
			# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
			# from the last; from July round balls of lilac flowers sit in the upper leaf
			# axils, one whorl above another.
			# Stems sprawl out from creeping runners before they turn up.
			# Whorls of florets in the leaf axils of the upper half.
			# --- Mugwort (Artemisia vulgaris) -------------------------------------------
			# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
			# dark green above and silver-white felted below, smaller and simpler up the
			# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
			# on short side branches. In autumn the whole stand dries brown and stays up.
			# Before flowering the stems are still growing.
			# Alternate leaves up the lower two thirds.
			# The plume: short side branches on the top third, each a spray of tiny
			# ovoid heads, shorter toward the tip so the plume tapers.
			# --- Creeping thistle (Cirsium arvense) -------------------------------------
			# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
			# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
			# stem branches into many small heads: a green, purple-tipped cup under a
			# lilac brush of florets, then white thistledown in August-September.
			# Branches from the top third, each with one to three heads.
			# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
			# A loose ball of silky pappus, bigger than the head that bore it.
			# The brush: a tuft of fine lilac florets fanning up out of the cup.
			# --- Stinging nettle (Urtica dioica) ----------------------------------------
			# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
			# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
			# pair a quarter turn from the last, drooping at the tip; from July, thin
			# greenish flower tassels hang from the upper leaf axils. In April and May the
			# stand is a carpet of short, dark, purple-flushed shoots.
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
			## coarse forward-pointing teeth, drooping toward its tip.
			# Stalk for the first 12 %, a cordate base, widest at a third, then a
			# long acuminate tip; saw teeth bite into the margin.
			# Teeth point forward: the outer margin runs ahead of the midrib a little.
			## Detailed procedural models of the tall verge and wall-foot herbs round Reval
			## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
			## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
			## (far flag, vertex contract); shares the stem, strand and leaf helpers of
			## city_herb_meshes.gd. Every seasonal variant of a species reuses the
			## flowering kind's seed, so it is the same plant in another season.
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Young April shoots are dark and purple-flushed.
			## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			# --- Field mint (Mentha arvensis) -------------------------------------------
			# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
			# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
			# from the last; from July round balls of lilac flowers sit in the upper leaf
			# axils, one whorl above another.
			# Stems sprawl out from creeping runners before they turn up.
			# Whorls of florets in the leaf axils of the upper half.
			# --- Mugwort (Artemisia vulgaris) -------------------------------------------
			# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
			# dark green above and silver-white felted below, smaller and simpler up the
			# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
			# on short side branches. In autumn the whole stand dries brown and stays up.
			# Before flowering the stems are still growing.
			# Alternate leaves up the lower two thirds.
			# The plume: short side branches on the top third, each a spray of tiny
			# ovoid heads, shorter toward the tip so the plume tapers.
			# --- Creeping thistle (Cirsium arvense) -------------------------------------
			# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
			# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
			# stem branches into many small heads: a green, purple-tipped cup under a
			# lilac brush of florets, then white thistledown in August-September.
			# Branches from the top third, each with one to three heads.
			# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
			# A loose ball of silky pappus, bigger than the head that bore it.
			# The brush: a tuft of fine lilac florets fanning up out of the cup.
			# --- Stinging nettle (Urtica dioica) ----------------------------------------
			# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
			# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
			# pair a quarter turn from the last, drooping at the tip; from July, thin
			# greenish flower tassels hang from the upper leaf axils. In April and May the
			# stand is a carpet of short, dark, purple-flushed shoots.
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
			## coarse forward-pointing teeth, drooping toward its tip.
			# Stalk for the first 12 %, a cordate base, widest at a third, then a
			# long acuminate tip; saw teeth bite into the margin.
			# Teeth point forward: the outer margin runs ahead of the midrib a little.
			## A hanging nettle flower tassel: a thin, knotted, greenish catkin.
			# --- Helpers -----------------------------------------------------------------
			## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
			## nodes; returns the centre line.
			## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
			## narrow midrib. `under` is the paleness of the back face (mugwort's silver
			## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
			## `wave` how far alternate lobes twist up and down.
			## Detailed procedural models of the tall verge and wall-foot herbs round Reval
			## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
			## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
			## (far flag, vertex contract); shares the stem, strand and leaf helpers of
			## city_herb_meshes.gd. Every seasonal variant of a species reuses the
			## flowering kind's seed, so it is the same plant in another season.
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Young April shoots are dark and purple-flushed.
			## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			# --- Field mint (Mentha arvensis) -------------------------------------------
			# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
			# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
			# from the last; from July round balls of lilac flowers sit in the upper leaf
			# axils, one whorl above another.
			# Stems sprawl out from creeping runners before they turn up.
			# Whorls of florets in the leaf axils of the upper half.
			# --- Mugwort (Artemisia vulgaris) -------------------------------------------
			# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
			# dark green above and silver-white felted below, smaller and simpler up the
			# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
			# on short side branches. In autumn the whole stand dries brown and stays up.
			# Before flowering the stems are still growing.
			# Alternate leaves up the lower two thirds.
			# The plume: short side branches on the top third, each a spray of tiny
			# ovoid heads, shorter toward the tip so the plume tapers.
			# --- Creeping thistle (Cirsium arvense) -------------------------------------
			# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
			# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
			# stem branches into many small heads: a green, purple-tipped cup under a
			# lilac brush of florets, then white thistledown in August-September.
			# Branches from the top third, each with one to three heads.
			# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
			# A loose ball of silky pappus, bigger than the head that bore it.
			# The brush: a tuft of fine lilac florets fanning up out of the cup.
			# --- Stinging nettle (Urtica dioica) ----------------------------------------
			# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
			# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
			# pair a quarter turn from the last, drooping at the tip; from July, thin
			# greenish flower tassels hang from the upper leaf axils. In April and May the
			# stand is a carpet of short, dark, purple-flushed shoots.
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
			## coarse forward-pointing teeth, drooping toward its tip.
			# Stalk for the first 12 %, a cordate base, widest at a third, then a
			# long acuminate tip; saw teeth bite into the margin.
			# Teeth point forward: the outer margin runs ahead of the midrib a little.
			## A hanging nettle flower tassel: a thin, knotted, greenish catkin.
			# --- Helpers -----------------------------------------------------------------
			## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
			## nodes; returns the centre line.
			## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
			## narrow midrib. `under` is the paleness of the back face (mugwort's silver
			## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
			## `wave` how far alternate lobes twist up and down.
			# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.
			## Detailed procedural models of the tall verge and wall-foot herbs round Reval
			## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
			## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
			## (far flag, vertex contract); shares the stem, strand and leaf helpers of
			## city_herb_meshes.gd. Every seasonal variant of a species reuses the
			## flowering kind's seed, so it is the same plant in another season.
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Young April shoots are dark and purple-flushed.
			## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			# --- Field mint (Mentha arvensis) -------------------------------------------
			# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
			# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
			# from the last; from July round balls of lilac flowers sit in the upper leaf
			# axils, one whorl above another.
			# Stems sprawl out from creeping runners before they turn up.
			# Whorls of florets in the leaf axils of the upper half.
			# --- Mugwort (Artemisia vulgaris) -------------------------------------------
			# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
			# dark green above and silver-white felted below, smaller and simpler up the
			# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
			# on short side branches. In autumn the whole stand dries brown and stays up.
			# Before flowering the stems are still growing.
			# Alternate leaves up the lower two thirds.
			# The plume: short side branches on the top third, each a spray of tiny
			# ovoid heads, shorter toward the tip so the plume tapers.
			# --- Creeping thistle (Cirsium arvense) -------------------------------------
			# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
			# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
			# stem branches into many small heads: a green, purple-tipped cup under a
			# lilac brush of florets, then white thistledown in August-September.
			# Branches from the top third, each with one to three heads.
			# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
			# A loose ball of silky pappus, bigger than the head that bore it.
			# The brush: a tuft of fine lilac florets fanning up out of the cup.
			# --- Stinging nettle (Urtica dioica) ----------------------------------------
			# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
			# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
			# pair a quarter turn from the last, drooping at the tip; from July, thin
			# greenish flower tassels hang from the upper leaf axils. In April and May the
			# stand is a carpet of short, dark, purple-flushed shoots.
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
			## coarse forward-pointing teeth, drooping toward its tip.
			# Stalk for the first 12 %, a cordate base, widest at a third, then a
			# long acuminate tip; saw teeth bite into the margin.
			# Teeth point forward: the outer margin runs ahead of the midrib a little.
			## A hanging nettle flower tassel: a thin, knotted, greenish catkin.
			# --- Helpers -----------------------------------------------------------------
			## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
			## nodes; returns the centre line.
			## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
			## narrow midrib. `under` is the paleness of the back face (mugwort's silver
			## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
			## `wave` how far alternate lobes twist up and down.
			# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.
			## Detailed procedural models of the tall verge and wall-foot herbs round Reval
			## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
			## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
			## (far flag, vertex contract); shares the stem, strand and leaf helpers of
			## city_herb_meshes.gd. Every seasonal variant of a species reuses the
			## flowering kind's seed, so it is the same plant in another season.
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Young April shoots are dark and purple-flushed.
			## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			# --- Field mint (Mentha arvensis) -------------------------------------------
			# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
			# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
			# from the last; from July round balls of lilac flowers sit in the upper leaf
			# axils, one whorl above another.
			# Stems sprawl out from creeping runners before they turn up.
			# Whorls of florets in the leaf axils of the upper half.
			# --- Mugwort (Artemisia vulgaris) -------------------------------------------
			# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
			# dark green above and silver-white felted below, smaller and simpler up the
			# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
			# on short side branches. In autumn the whole stand dries brown and stays up.
			# Before flowering the stems are still growing.
			# Alternate leaves up the lower two thirds.
			# The plume: short side branches on the top third, each a spray of tiny
			# ovoid heads, shorter toward the tip so the plume tapers.
			# --- Creeping thistle (Cirsium arvense) -------------------------------------
			# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
			# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
			# stem branches into many small heads: a green, purple-tipped cup under a
			# lilac brush of florets, then white thistledown in August-September.
			# Branches from the top third, each with one to three heads.
			# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
			# A loose ball of silky pappus, bigger than the head that bore it.
			# The brush: a tuft of fine lilac florets fanning up out of the cup.
			# --- Stinging nettle (Urtica dioica) ----------------------------------------
			# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
			# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
			# pair a quarter turn from the last, drooping at the tip; from July, thin
			# greenish flower tassels hang from the upper leaf axils. In April and May the
			# stand is a carpet of short, dark, purple-flushed shoots.
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
			## coarse forward-pointing teeth, drooping toward its tip.
			# Stalk for the first 12 %, a cordate base, widest at a third, then a
			# long acuminate tip; saw teeth bite into the margin.
			# Teeth point forward: the outer margin runs ahead of the midrib a little.
			## A hanging nettle flower tassel: a thin, knotted, greenish catkin.
			# --- Helpers -----------------------------------------------------------------
			## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
			## nodes; returns the centre line.
			## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
			## narrow midrib. `under` is the paleness of the back face (mugwort's silver
			## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
			## `wave` how far alternate lobes twist up and down.
			# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.
			func(t: float, s: float) -> float:
# gdlint:disable=max-file-lines

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				## Detailed procedural models of the tall verge and wall-foot herbs round Reval
				## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
				## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
				## (far flag, vertex contract); shares the stem, strand and leaf helpers of
				## city_herb_meshes.gd. Every seasonal variant of a species reuses the
				## flowering kind's seed, so it is the same plant in another season.
				## Kind -> [species (seed), stage].
				# Colours are sRGB, picked from field photographs of each species.
				# Young April shoots are dark and purple-flushed.
				## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
				# --- Field mint (Mentha arvensis) -------------------------------------------
				# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
				# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
				# from the last; from July round balls of lilac flowers sit in the upper leaf
				# axils, one whorl above another.
				# Stems sprawl out from creeping runners before they turn up.
				# Whorls of florets in the leaf axils of the upper half.
				# --- Mugwort (Artemisia vulgaris) -------------------------------------------
				# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
				# dark green above and silver-white felted below, smaller and simpler up the
				# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
				# on short side branches. In autumn the whole stand dries brown and stays up.
				# Before flowering the stems are still growing.
				# Alternate leaves up the lower two thirds.
				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.
				# --- Creeping thistle (Cirsium arvense) -------------------------------------
				# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
				# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
				# stem branches into many small heads: a green, purple-tipped cup under a
				# lilac brush of florets, then white thistledown in August-September.
				# Branches from the top third, each with one to three heads.
				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
				# A loose ball of silky pappus, bigger than the head that bore it.
				# The brush: a tuft of fine lilac florets fanning up out of the cup.
				# --- Stinging nettle (Urtica dioica) ----------------------------------------
				# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
				# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
				# pair a quarter turn from the last, drooping at the tip; from July, thin
				# greenish flower tassels hang from the upper leaf axils. In April and May the
				# stand is a carpet of short, dark, purple-flushed shoots.
				# A short shoot: three crowded pairs of young leaves on 12-22 cm.
				## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
				## coarse forward-pointing teeth, drooping toward its tip.
				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				## Detailed procedural models of the tall verge and wall-foot herbs round Reval
				## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
				## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
				## (far flag, vertex contract); shares the stem, strand and leaf helpers of
				## city_herb_meshes.gd. Every seasonal variant of a species reuses the
				## flowering kind's seed, so it is the same plant in another season.
				## Kind -> [species (seed), stage].
				# Colours are sRGB, picked from field photographs of each species.
				# Young April shoots are dark and purple-flushed.
				## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
				# --- Field mint (Mentha arvensis) -------------------------------------------
				# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
				# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
				# from the last; from July round balls of lilac flowers sit in the upper leaf
				# axils, one whorl above another.
				# Stems sprawl out from creeping runners before they turn up.
				# Whorls of florets in the leaf axils of the upper half.
				# --- Mugwort (Artemisia vulgaris) -------------------------------------------
				# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
				# dark green above and silver-white felted below, smaller and simpler up the
				# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
				# on short side branches. In autumn the whole stand dries brown and stays up.
				# Before flowering the stems are still growing.
				# Alternate leaves up the lower two thirds.
				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.
				# --- Creeping thistle (Cirsium arvense) -------------------------------------
				# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
				# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
				# stem branches into many small heads: a green, purple-tipped cup under a
				# lilac brush of florets, then white thistledown in August-September.
				# Branches from the top third, each with one to three heads.
				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
				# A loose ball of silky pappus, bigger than the head that bore it.
				# The brush: a tuft of fine lilac florets fanning up out of the cup.
				# --- Stinging nettle (Urtica dioica) ----------------------------------------
				# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
				# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
				# pair a quarter turn from the last, drooping at the tip; from July, thin
				# greenish flower tassels hang from the upper leaf axils. In April and May the
				# stand is a carpet of short, dark, purple-flushed shoots.
				# A short shoot: three crowded pairs of young leaves on 12-22 cm.
				## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
				## coarse forward-pointing teeth, drooping toward its tip.
				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.
				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

				## Detailed procedural models of the tall verge and wall-foot herbs round Reval
				## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
				## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
				## (far flag, vertex contract); shares the stem, strand and leaf helpers of
				## city_herb_meshes.gd. Every seasonal variant of a species reuses the
				## flowering kind's seed, so it is the same plant in another season.
				## Kind -> [species (seed), stage].
				# Colours are sRGB, picked from field photographs of each species.
				# Young April shoots are dark and purple-flushed.
				## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
				# --- Field mint (Mentha arvensis) -------------------------------------------
				# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
				# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
				# from the last; from July round balls of lilac flowers sit in the upper leaf
				# axils, one whorl above another.
				# Stems sprawl out from creeping runners before they turn up.
				# Whorls of florets in the leaf axils of the upper half.
				# --- Mugwort (Artemisia vulgaris) -------------------------------------------
				# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
				# dark green above and silver-white felted below, smaller and simpler up the
				# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
				# on short side branches. In autumn the whole stand dries brown and stays up.
				# Before flowering the stems are still growing.
				# Alternate leaves up the lower two thirds.
				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.
				# --- Creeping thistle (Cirsium arvense) -------------------------------------
				# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
				# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
				# stem branches into many small heads: a green, purple-tipped cup under a
				# lilac brush of florets, then white thistledown in August-September.
				# Branches from the top third, each with one to three heads.
				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
				# A loose ball of silky pappus, bigger than the head that bore it.
				# The brush: a tuft of fine lilac florets fanning up out of the cup.
				# --- Stinging nettle (Urtica dioica) ----------------------------------------
				# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
				# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
				# pair a quarter turn from the last, drooping at the tip; from July, thin
				# greenish flower tassels hang from the upper leaf axils. In April and May the
				# stand is a carpet of short, dark, purple-flushed shoots.
				# A short shoot: three crowded pairs of young leaves on 12-22 cm.
				## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
				## coarse forward-pointing teeth, drooping toward its tip.
				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.
				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## A hanging nettle flower tassel: a thin, knotted, greenish catkin.

# --- Helpers -----------------------------------------------------------------

## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
## nodes; returns the centre line.

## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
## narrow midrib. `under` is the paleness of the back face (mugwort's silver
## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
## `wave` how far alternate lobes twist up and down.

				## Detailed procedural models of the tall verge and wall-foot herbs round Reval
				## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
				## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
				## (far flag, vertex contract); shares the stem, strand and leaf helpers of
				## city_herb_meshes.gd. Every seasonal variant of a species reuses the
				## flowering kind's seed, so it is the same plant in another season.
				## Kind -> [species (seed), stage].
				# Colours are sRGB, picked from field photographs of each species.
				# Young April shoots are dark and purple-flushed.
				## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
				# --- Field mint (Mentha arvensis) -------------------------------------------
				# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
				# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
				# from the last; from July round balls of lilac flowers sit in the upper leaf
				# axils, one whorl above another.
				# Stems sprawl out from creeping runners before they turn up.
				# Whorls of florets in the leaf axils of the upper half.
				# --- Mugwort (Artemisia vulgaris) -------------------------------------------
				# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
				# dark green above and silver-white felted below, smaller and simpler up the
				# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
				# on short side branches. In autumn the whole stand dries brown and stays up.
				# Before flowering the stems are still growing.
				# Alternate leaves up the lower two thirds.
				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.
				# --- Creeping thistle (Cirsium arvense) -------------------------------------
				# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
				# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
				# stem branches into many small heads: a green, purple-tipped cup under a
				# lilac brush of florets, then white thistledown in August-September.
				# Branches from the top third, each with one to three heads.
				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
				# A loose ball of silky pappus, bigger than the head that bore it.
				# The brush: a tuft of fine lilac florets fanning up out of the cup.
				# --- Stinging nettle (Urtica dioica) ----------------------------------------
				# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
				# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
				# pair a quarter turn from the last, drooping at the tip; from July, thin
				# greenish flower tassels hang from the upper leaf axils. In April and May the
				# stand is a carpet of short, dark, purple-flushed shoots.
				# A short shoot: three crowded pairs of young leaves on 12-22 cm.
				## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
				## coarse forward-pointing teeth, drooping toward its tip.
				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.
				# Teeth point forward: the outer margin runs ahead of the midrib a little.
				## A hanging nettle flower tassel: a thin, knotted, greenish catkin.
				# --- Helpers -----------------------------------------------------------------
				## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
				## nodes; returns the centre line.
				## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
				## narrow midrib. `under` is the paleness of the back face (mugwort's silver
				## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
				## `wave` how far alternate lobes twist up and down.
				# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## A hanging nettle flower tassel: a thin, knotted, greenish catkin.

# --- Helpers -----------------------------------------------------------------

## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
## nodes; returns the centre line.

## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
## narrow midrib. `under` is the paleness of the back face (mugwort's silver
## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
## `wave` how far alternate lobes twist up and down.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## A hanging nettle flower tassel: a thin, knotted, greenish catkin.

# --- Helpers -----------------------------------------------------------------

## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
## nodes; returns the centre line.

## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
## narrow midrib. `under` is the paleness of the back face (mugwort's silver
## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
## `wave` how far alternate lobes twist up and down.

				# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.

				## Detailed procedural models of the tall verge and wall-foot herbs round Reval
				## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
				## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
				## (far flag, vertex contract); shares the stem, strand and leaf helpers of
				## city_herb_meshes.gd. Every seasonal variant of a species reuses the
				## flowering kind's seed, so it is the same plant in another season.
				## Kind -> [species (seed), stage].
				# Colours are sRGB, picked from field photographs of each species.
				# Young April shoots are dark and purple-flushed.
				## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
				# --- Field mint (Mentha arvensis) -------------------------------------------
				# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
				# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
				# from the last; from July round balls of lilac flowers sit in the upper leaf
				# axils, one whorl above another.
				# Stems sprawl out from creeping runners before they turn up.
				# Whorls of florets in the leaf axils of the upper half.
				# --- Mugwort (Artemisia vulgaris) -------------------------------------------
				# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
				# dark green above and silver-white felted below, smaller and simpler up the
				# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
				# on short side branches. In autumn the whole stand dries brown and stays up.
				# Before flowering the stems are still growing.
				# Alternate leaves up the lower two thirds.
				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.
				# --- Creeping thistle (Cirsium arvense) -------------------------------------
				# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
				# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
				# stem branches into many small heads: a green, purple-tipped cup under a
				# lilac brush of florets, then white thistledown in August-September.
				# Branches from the top third, each with one to three heads.
				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
				# A loose ball of silky pappus, bigger than the head that bore it.
				# The brush: a tuft of fine lilac florets fanning up out of the cup.
				# --- Stinging nettle (Urtica dioica) ----------------------------------------
				# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
				# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
				# pair a quarter turn from the last, drooping at the tip; from July, thin
				# greenish flower tassels hang from the upper leaf axils. In April and May the
				# stand is a carpet of short, dark, purple-flushed shoots.
				# A short shoot: three crowded pairs of young leaves on 12-22 cm.
				## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
				## coarse forward-pointing teeth, drooping toward its tip.
				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.
				# Teeth point forward: the outer margin runs ahead of the midrib a little.
				## A hanging nettle flower tassel: a thin, knotted, greenish catkin.
				# --- Helpers -----------------------------------------------------------------
				## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
				## nodes; returns the centre line.
				## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
				## narrow midrib. `under` is the paleness of the back face (mugwort's silver
				## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
				## `wave` how far alternate lobes twist up and down.
				# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## A hanging nettle flower tassel: a thin, knotted, greenish catkin.

# --- Helpers -----------------------------------------------------------------

## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
## nodes; returns the centre line.

## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
## narrow midrib. `under` is the paleness of the back face (mugwort's silver
## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
## `wave` how far alternate lobes twist up and down.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## A hanging nettle flower tassel: a thin, knotted, greenish catkin.

# --- Helpers -----------------------------------------------------------------

## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
## nodes; returns the centre line.

## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
## narrow midrib. `under` is the paleness of the back face (mugwort's silver
## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
## `wave` how far alternate lobes twist up and down.

				# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## A hanging nettle flower tassel: a thin, knotted, greenish catkin.

# --- Helpers -----------------------------------------------------------------

## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
## nodes; returns the centre line.

## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
## narrow midrib. `under` is the paleness of the back face (mugwort's silver
## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
## `wave` how far alternate lobes twist up and down.

				# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.

				## Detailed procedural models of the tall verge and wall-foot herbs round Reval
				## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
				## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
				## (far flag, vertex contract); shares the stem, strand and leaf helpers of
				## city_herb_meshes.gd. Every seasonal variant of a species reuses the
				## flowering kind's seed, so it is the same plant in another season.
				## Kind -> [species (seed), stage].
				# Colours are sRGB, picked from field photographs of each species.
				# Young April shoots are dark and purple-flushed.
				## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
				# --- Field mint (Mentha arvensis) -------------------------------------------
				# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
				# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
				# from the last; from July round balls of lilac flowers sit in the upper leaf
				# axils, one whorl above another.
				# Stems sprawl out from creeping runners before they turn up.
				# Whorls of florets in the leaf axils of the upper half.
				# --- Mugwort (Artemisia vulgaris) -------------------------------------------
				# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
				# dark green above and silver-white felted below, smaller and simpler up the
				# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
				# on short side branches. In autumn the whole stand dries brown and stays up.
				# Before flowering the stems are still growing.
				# Alternate leaves up the lower two thirds.
				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.
				# --- Creeping thistle (Cirsium arvense) -------------------------------------
				# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
				# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
				# stem branches into many small heads: a green, purple-tipped cup under a
				# lilac brush of florets, then white thistledown in August-September.
				# Branches from the top third, each with one to three heads.
				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
				# A loose ball of silky pappus, bigger than the head that bore it.
				# The brush: a tuft of fine lilac florets fanning up out of the cup.
				# --- Stinging nettle (Urtica dioica) ----------------------------------------
				# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
				# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
				# pair a quarter turn from the last, drooping at the tip; from July, thin
				# greenish flower tassels hang from the upper leaf axils. In April and May the
				# stand is a carpet of short, dark, purple-flushed shoots.
				# A short shoot: three crowded pairs of young leaves on 12-22 cm.
				## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
				## coarse forward-pointing teeth, drooping toward its tip.
				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.
				# Teeth point forward: the outer margin runs ahead of the midrib a little.
				## A hanging nettle flower tassel: a thin, knotted, greenish catkin.
				# --- Helpers -----------------------------------------------------------------
				## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
				## nodes; returns the centre line.
				## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
				## narrow midrib. `under` is the paleness of the back face (mugwort's silver
				## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
				## `wave` how far alternate lobes twist up and down.
				# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## A hanging nettle flower tassel: a thin, knotted, greenish catkin.

# --- Helpers -----------------------------------------------------------------

## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
## nodes; returns the centre line.

## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
## narrow midrib. `under` is the paleness of the back face (mugwort's silver
## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
## `wave` how far alternate lobes twist up and down.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## A hanging nettle flower tassel: a thin, knotted, greenish catkin.

# --- Helpers -----------------------------------------------------------------

## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
## nodes; returns the centre line.

## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
## narrow midrib. `under` is the paleness of the back face (mugwort's silver
## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
## `wave` how far alternate lobes twist up and down.

				# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## A hanging nettle flower tassel: a thin, knotted, greenish catkin.

# --- Helpers -----------------------------------------------------------------

## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
## nodes; returns the centre line.

## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
## narrow midrib. `under` is the paleness of the back face (mugwort's silver
## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
## `wave` how far alternate lobes twist up and down.

				# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## A hanging nettle flower tassel: a thin, knotted, greenish catkin.

# --- Helpers -----------------------------------------------------------------

## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
## nodes; returns the centre line.

## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
## narrow midrib. `under` is the paleness of the back face (mugwort's silver
## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
## `wave` how far alternate lobes twist up and down.

				# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.

				return s * size * wave * 0.15 * sin(t * PI * count * 2.0),
			"color":
			## Detailed procedural models of the tall verge and wall-foot herbs round Reval
			## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
			## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
			## (far flag, vertex contract); shares the stem, strand and leaf helpers of
			## city_herb_meshes.gd. Every seasonal variant of a species reuses the
			## flowering kind's seed, so it is the same plant in another season.
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Young April shoots are dark and purple-flushed.
			## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			# --- Field mint (Mentha arvensis) -------------------------------------------
			# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
			# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
			# from the last; from July round balls of lilac flowers sit in the upper leaf
			# axils, one whorl above another.
			# Stems sprawl out from creeping runners before they turn up.
			# Whorls of florets in the leaf axils of the upper half.
			# --- Mugwort (Artemisia vulgaris) -------------------------------------------
			# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
			# dark green above and silver-white felted below, smaller and simpler up the
			# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
			# on short side branches. In autumn the whole stand dries brown and stays up.
			# Before flowering the stems are still growing.
			# Alternate leaves up the lower two thirds.
			# The plume: short side branches on the top third, each a spray of tiny
			# ovoid heads, shorter toward the tip so the plume tapers.
			# --- Creeping thistle (Cirsium arvense) -------------------------------------
			# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
			# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
			# stem branches into many small heads: a green, purple-tipped cup under a
			# lilac brush of florets, then white thistledown in August-September.
			# Branches from the top third, each with one to three heads.
			# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
			# A loose ball of silky pappus, bigger than the head that bore it.
			# The brush: a tuft of fine lilac florets fanning up out of the cup.
			# --- Stinging nettle (Urtica dioica) ----------------------------------------
			# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
			# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
			# pair a quarter turn from the last, drooping at the tip; from July, thin
			# greenish flower tassels hang from the upper leaf axils. In April and May the
			# stand is a carpet of short, dark, purple-flushed shoots.
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
			## coarse forward-pointing teeth, drooping toward its tip.
			# Stalk for the first 12 %, a cordate base, widest at a third, then a
			# long acuminate tip; saw teeth bite into the margin.
			# Teeth point forward: the outer margin runs ahead of the midrib a little.
			## A hanging nettle flower tassel: a thin, knotted, greenish catkin.
			# --- Helpers -----------------------------------------------------------------
			## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
			## nodes; returns the centre line.
			## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
			## narrow midrib. `under` is the paleness of the back face (mugwort's silver
			## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
			## `wave` how far alternate lobes twist up and down.
			# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.
			## Detailed procedural models of the tall verge and wall-foot herbs round Reval
			## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
			## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
			## (far flag, vertex contract); shares the stem, strand and leaf helpers of
			## city_herb_meshes.gd. Every seasonal variant of a species reuses the
			## flowering kind's seed, so it is the same plant in another season.
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Young April shoots are dark and purple-flushed.
			## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			# --- Field mint (Mentha arvensis) -------------------------------------------
			# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
			# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
			# from the last; from July round balls of lilac flowers sit in the upper leaf
			# axils, one whorl above another.
			# Stems sprawl out from creeping runners before they turn up.
			# Whorls of florets in the leaf axils of the upper half.
			# --- Mugwort (Artemisia vulgaris) -------------------------------------------
			# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
			# dark green above and silver-white felted below, smaller and simpler up the
			# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
			# on short side branches. In autumn the whole stand dries brown and stays up.
			# Before flowering the stems are still growing.
			# Alternate leaves up the lower two thirds.
			# The plume: short side branches on the top third, each a spray of tiny
			# ovoid heads, shorter toward the tip so the plume tapers.
			# --- Creeping thistle (Cirsium arvense) -------------------------------------
			# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
			# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
			# stem branches into many small heads: a green, purple-tipped cup under a
			# lilac brush of florets, then white thistledown in August-September.
			# Branches from the top third, each with one to three heads.
			# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
			# A loose ball of silky pappus, bigger than the head that bore it.
			# The brush: a tuft of fine lilac florets fanning up out of the cup.
			# --- Stinging nettle (Urtica dioica) ----------------------------------------
			# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
			# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
			# pair a quarter turn from the last, drooping at the tip; from July, thin
			# greenish flower tassels hang from the upper leaf axils. In April and May the
			# stand is a carpet of short, dark, purple-flushed shoots.
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
			## coarse forward-pointing teeth, drooping toward its tip.
			# Stalk for the first 12 %, a cordate base, widest at a third, then a
			## Detailed procedural models of the tall verge and wall-foot herbs round Reval
			## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
			## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
			## (far flag, vertex contract); shares the stem, strand and leaf helpers of
			## city_herb_meshes.gd. Every seasonal variant of a species reuses the
			## flowering kind's seed, so it is the same plant in another season.
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Young April shoots are dark and purple-flushed.
			## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			# --- Field mint (Mentha arvensis) -------------------------------------------
			# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
			# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
			# from the last; from July round balls of lilac flowers sit in the upper leaf
			# axils, one whorl above another.
			# Stems sprawl out from creeping runners before they turn up.
			# Whorls of florets in the leaf axils of the upper half.
			# --- Mugwort (Artemisia vulgaris) -------------------------------------------
			# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
			# dark green above and silver-white felted below, smaller and simpler up the
			# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
			# on short side branches. In autumn the whole stand dries brown and stays up.
			# Before flowering the stems are still growing.
			# Alternate leaves up the lower two thirds.
			# The plume: short side branches on the top third, each a spray of tiny
			# ovoid heads, shorter toward the tip so the plume tapers.
			# --- Creeping thistle (Cirsium arvense) -------------------------------------
			# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
			# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
			# stem branches into many small heads: a green, purple-tipped cup under a
			# lilac brush of florets, then white thistledown in August-September.
			# Branches from the top third, each with one to three heads.
			# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
			# A loose ball of silky pappus, bigger than the head that bore it.
			# The brush: a tuft of fine lilac florets fanning up out of the cup.
			# --- Stinging nettle (Urtica dioica) ----------------------------------------
			# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
			# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
			# pair a quarter turn from the last, drooping at the tip; from July, thin
			# greenish flower tassels hang from the upper leaf axils. In April and May the
			# stand is a carpet of short, dark, purple-flushed shoots.
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
			## coarse forward-pointing teeth, drooping toward its tip.
			# Stalk for the first 12 %, a cordate base, widest at a third, then a
			# long acuminate tip; saw teeth bite into the margin.
			## Detailed procedural models of the tall verge and wall-foot herbs round Reval
			## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
			## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
			## (far flag, vertex contract); shares the stem, strand and leaf helpers of
			## city_herb_meshes.gd. Every seasonal variant of a species reuses the
			## flowering kind's seed, so it is the same plant in another season.
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Young April shoots are dark and purple-flushed.
			## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			# --- Field mint (Mentha arvensis) -------------------------------------------
			# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
			# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
			# from the last; from July round balls of lilac flowers sit in the upper leaf
			# axils, one whorl above another.
			# Stems sprawl out from creeping runners before they turn up.
			# Whorls of florets in the leaf axils of the upper half.
			# --- Mugwort (Artemisia vulgaris) -------------------------------------------
			# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
			# dark green above and silver-white felted below, smaller and simpler up the
			# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
			# on short side branches. In autumn the whole stand dries brown and stays up.
			# Before flowering the stems are still growing.
			# Alternate leaves up the lower two thirds.
			# The plume: short side branches on the top third, each a spray of tiny
			# ovoid heads, shorter toward the tip so the plume tapers.
			# --- Creeping thistle (Cirsium arvense) -------------------------------------
			# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
			# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
			# stem branches into many small heads: a green, purple-tipped cup under a
			# lilac brush of florets, then white thistledown in August-September.
			# Branches from the top third, each with one to three heads.
			# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
			# A loose ball of silky pappus, bigger than the head that bore it.
			# The brush: a tuft of fine lilac florets fanning up out of the cup.
			# --- Stinging nettle (Urtica dioica) ----------------------------------------
			# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
			# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
			# pair a quarter turn from the last, drooping at the tip; from July, thin
			# greenish flower tassels hang from the upper leaf axils. In April and May the
			# stand is a carpet of short, dark, purple-flushed shoots.
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
			## coarse forward-pointing teeth, drooping toward its tip.
			# Stalk for the first 12 %, a cordate base, widest at a third, then a
			# long acuminate tip; saw teeth bite into the margin.
			# Teeth point forward: the outer margin runs ahead of the midrib a little.
			## Detailed procedural models of the tall verge and wall-foot herbs round Reval
			## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
			## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
			## (far flag, vertex contract); shares the stem, strand and leaf helpers of
			## city_herb_meshes.gd. Every seasonal variant of a species reuses the
			## flowering kind's seed, so it is the same plant in another season.
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Young April shoots are dark and purple-flushed.
			## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			# --- Field mint (Mentha arvensis) -------------------------------------------
			# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
			# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
			# from the last; from July round balls of lilac flowers sit in the upper leaf
			# axils, one whorl above another.
			# Stems sprawl out from creeping runners before they turn up.
			# Whorls of florets in the leaf axils of the upper half.
			# --- Mugwort (Artemisia vulgaris) -------------------------------------------
			# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
			# dark green above and silver-white felted below, smaller and simpler up the
			# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
			# on short side branches. In autumn the whole stand dries brown and stays up.
			# Before flowering the stems are still growing.
			# Alternate leaves up the lower two thirds.
			# The plume: short side branches on the top third, each a spray of tiny
			# ovoid heads, shorter toward the tip so the plume tapers.
			# --- Creeping thistle (Cirsium arvense) -------------------------------------
			# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
			# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
			# stem branches into many small heads: a green, purple-tipped cup under a
			# lilac brush of florets, then white thistledown in August-September.
			# Branches from the top third, each with one to three heads.
			# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
			# A loose ball of silky pappus, bigger than the head that bore it.
			# The brush: a tuft of fine lilac florets fanning up out of the cup.
			# --- Stinging nettle (Urtica dioica) ----------------------------------------
			# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
			# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
			# pair a quarter turn from the last, drooping at the tip; from July, thin
			# greenish flower tassels hang from the upper leaf axils. In April and May the
			# stand is a carpet of short, dark, purple-flushed shoots.
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
			## coarse forward-pointing teeth, drooping toward its tip.
			# Stalk for the first 12 %, a cordate base, widest at a third, then a
			# long acuminate tip; saw teeth bite into the margin.
			# Teeth point forward: the outer margin runs ahead of the midrib a little.
			## A hanging nettle flower tassel: a thin, knotted, greenish catkin.
			# --- Helpers -----------------------------------------------------------------
			## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
			## nodes; returns the centre line.
			## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
			## narrow midrib. `under` is the paleness of the back face (mugwort's silver
			## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
			## `wave` how far alternate lobes twist up and down.
			## Detailed procedural models of the tall verge and wall-foot herbs round Reval
			## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
			## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
			## (far flag, vertex contract); shares the stem, strand and leaf helpers of
			## city_herb_meshes.gd. Every seasonal variant of a species reuses the
			## flowering kind's seed, so it is the same plant in another season.
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Young April shoots are dark and purple-flushed.
			## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			# --- Field mint (Mentha arvensis) -------------------------------------------
			# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
			# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
			# from the last; from July round balls of lilac flowers sit in the upper leaf
			# axils, one whorl above another.
			# Stems sprawl out from creeping runners before they turn up.
			# Whorls of florets in the leaf axils of the upper half.
			# --- Mugwort (Artemisia vulgaris) -------------------------------------------
			# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
			# dark green above and silver-white felted below, smaller and simpler up the
			# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
			# on short side branches. In autumn the whole stand dries brown and stays up.
			# Before flowering the stems are still growing.
			# Alternate leaves up the lower two thirds.
			# The plume: short side branches on the top third, each a spray of tiny
			# ovoid heads, shorter toward the tip so the plume tapers.
			# --- Creeping thistle (Cirsium arvense) -------------------------------------
			# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
			# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
			# stem branches into many small heads: a green, purple-tipped cup under a
			# lilac brush of florets, then white thistledown in August-September.
			# Branches from the top third, each with one to three heads.
			# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
			# A loose ball of silky pappus, bigger than the head that bore it.
			# The brush: a tuft of fine lilac florets fanning up out of the cup.
			# --- Stinging nettle (Urtica dioica) ----------------------------------------
			# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
			# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
			# pair a quarter turn from the last, drooping at the tip; from July, thin
			# greenish flower tassels hang from the upper leaf axils. In April and May the
			# stand is a carpet of short, dark, purple-flushed shoots.
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
			## coarse forward-pointing teeth, drooping toward its tip.
			# Stalk for the first 12 %, a cordate base, widest at a third, then a
			# long acuminate tip; saw teeth bite into the margin.
			# Teeth point forward: the outer margin runs ahead of the midrib a little.
			## A hanging nettle flower tassel: a thin, knotted, greenish catkin.
			# --- Helpers -----------------------------------------------------------------
			## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
			## nodes; returns the centre line.
			## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
			## narrow midrib. `under` is the paleness of the back face (mugwort's silver
			## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
			## `wave` how far alternate lobes twist up and down.
			# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.
			## Detailed procedural models of the tall verge and wall-foot herbs round Reval
			## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
			## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
			## (far flag, vertex contract); shares the stem, strand and leaf helpers of
			## city_herb_meshes.gd. Every seasonal variant of a species reuses the
			## flowering kind's seed, so it is the same plant in another season.
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Young April shoots are dark and purple-flushed.
			## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			# --- Field mint (Mentha arvensis) -------------------------------------------
			# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
			# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
			# from the last; from July round balls of lilac flowers sit in the upper leaf
			# axils, one whorl above another.
			# Stems sprawl out from creeping runners before they turn up.
			# Whorls of florets in the leaf axils of the upper half.
			# --- Mugwort (Artemisia vulgaris) -------------------------------------------
			# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
			# dark green above and silver-white felted below, smaller and simpler up the
			# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
			# on short side branches. In autumn the whole stand dries brown and stays up.
			# Before flowering the stems are still growing.
			# Alternate leaves up the lower two thirds.
			# The plume: short side branches on the top third, each a spray of tiny
			# ovoid heads, shorter toward the tip so the plume tapers.
			# --- Creeping thistle (Cirsium arvense) -------------------------------------
			# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
			# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
			# stem branches into many small heads: a green, purple-tipped cup under a
			# lilac brush of florets, then white thistledown in August-September.
			# Branches from the top third, each with one to three heads.
			# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
			# A loose ball of silky pappus, bigger than the head that bore it.
			# The brush: a tuft of fine lilac florets fanning up out of the cup.
			# --- Stinging nettle (Urtica dioica) ----------------------------------------
			# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
			# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
			# pair a quarter turn from the last, drooping at the tip; from July, thin
			# greenish flower tassels hang from the upper leaf axils. In April and May the
			# stand is a carpet of short, dark, purple-flushed shoots.
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
			## coarse forward-pointing teeth, drooping toward its tip.
			# Stalk for the first 12 %, a cordate base, widest at a third, then a
			# long acuminate tip; saw teeth bite into the margin.
			# Teeth point forward: the outer margin runs ahead of the midrib a little.
			## A hanging nettle flower tassel: a thin, knotted, greenish catkin.
			# --- Helpers -----------------------------------------------------------------
			## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
			## nodes; returns the centre line.
			## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
			## narrow midrib. `under` is the paleness of the back face (mugwort's silver
			## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
			## `wave` how far alternate lobes twist up and down.
			# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.
			## Detailed procedural models of the tall verge and wall-foot herbs round Reval
			## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
			## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
			## (far flag, vertex contract); shares the stem, strand and leaf helpers of
			## city_herb_meshes.gd. Every seasonal variant of a species reuses the
			## flowering kind's seed, so it is the same plant in another season.
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Young April shoots are dark and purple-flushed.
			## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			# --- Field mint (Mentha arvensis) -------------------------------------------
			# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
			# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
			# from the last; from July round balls of lilac flowers sit in the upper leaf
			# axils, one whorl above another.
			# Stems sprawl out from creeping runners before they turn up.
			# Whorls of florets in the leaf axils of the upper half.
			# --- Mugwort (Artemisia vulgaris) -------------------------------------------
			# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
			# dark green above and silver-white felted below, smaller and simpler up the
			# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
			# on short side branches. In autumn the whole stand dries brown and stays up.
			# Before flowering the stems are still growing.
			# Alternate leaves up the lower two thirds.
			# The plume: short side branches on the top third, each a spray of tiny
			# ovoid heads, shorter toward the tip so the plume tapers.
			# --- Creeping thistle (Cirsium arvense) -------------------------------------
			# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
			# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
			# stem branches into many small heads: a green, purple-tipped cup under a
			# lilac brush of florets, then white thistledown in August-September.
			# Branches from the top third, each with one to three heads.
			# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
			# A loose ball of silky pappus, bigger than the head that bore it.
			# The brush: a tuft of fine lilac florets fanning up out of the cup.
			# --- Stinging nettle (Urtica dioica) ----------------------------------------
			# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
			# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
			# pair a quarter turn from the last, drooping at the tip; from July, thin
			# greenish flower tassels hang from the upper leaf axils. In April and May the
			# stand is a carpet of short, dark, purple-flushed shoots.
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
			## coarse forward-pointing teeth, drooping toward its tip.
			# Stalk for the first 12 %, a cordate base, widest at a third, then a
			# long acuminate tip; saw teeth bite into the margin.
			# Teeth point forward: the outer margin runs ahead of the midrib a little.
			## A hanging nettle flower tassel: a thin, knotted, greenish catkin.
			# --- Helpers -----------------------------------------------------------------
			## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
			## nodes; returns the centre line.
			## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
			## narrow midrib. `under` is the paleness of the back face (mugwort's silver
			## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
			## `wave` how far alternate lobes twist up and down.
			# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.
			## Detailed procedural models of the tall verge and wall-foot herbs round Reval
			## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
			## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
			## (far flag, vertex contract); shares the stem, strand and leaf helpers of
			## city_herb_meshes.gd. Every seasonal variant of a species reuses the
			## flowering kind's seed, so it is the same plant in another season.
			## Kind -> [species (seed), stage].
			# Colours are sRGB, picked from field photographs of each species.
			# Young April shoots are dark and purple-flushed.
			## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
			# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
			# --- Field mint (Mentha arvensis) -------------------------------------------
			# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
			# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
			# from the last; from July round balls of lilac flowers sit in the upper leaf
			# axils, one whorl above another.
			# Stems sprawl out from creeping runners before they turn up.
			# Whorls of florets in the leaf axils of the upper half.
			# --- Mugwort (Artemisia vulgaris) -------------------------------------------
			# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
			# dark green above and silver-white felted below, smaller and simpler up the
			# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
			# on short side branches. In autumn the whole stand dries brown and stays up.
			# Before flowering the stems are still growing.
			# Alternate leaves up the lower two thirds.
			# The plume: short side branches on the top third, each a spray of tiny
			# ovoid heads, shorter toward the tip so the plume tapers.
			# --- Creeping thistle (Cirsium arvense) -------------------------------------
			# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
			# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
			# stem branches into many small heads: a green, purple-tipped cup under a
			# lilac brush of florets, then white thistledown in August-September.
			# Branches from the top third, each with one to three heads.
			# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
			# A loose ball of silky pappus, bigger than the head that bore it.
			# The brush: a tuft of fine lilac florets fanning up out of the cup.
			# --- Stinging nettle (Urtica dioica) ----------------------------------------
			# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
			# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
			# pair a quarter turn from the last, drooping at the tip; from July, thin
			# greenish flower tassels hang from the upper leaf axils. In April and May the
			# stand is a carpet of short, dark, purple-flushed shoots.
			# A short shoot: three crowded pairs of young leaves on 12-22 cm.
			## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
			## coarse forward-pointing teeth, drooping toward its tip.
			# Stalk for the first 12 %, a cordate base, widest at a third, then a
			# long acuminate tip; saw teeth bite into the margin.
			# Teeth point forward: the outer margin runs ahead of the midrib a little.
			## A hanging nettle flower tassel: a thin, knotted, greenish catkin.
			# --- Helpers -----------------------------------------------------------------
			## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
			## nodes; returns the centre line.
			## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
			## narrow midrib. `under` is the paleness of the back face (mugwort's silver
			## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
			## `wave` how far alternate lobes twist up and down.
			# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.
			func(t: float, s: float) -> Color:
# gdlint:disable=max-file-lines

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				## Detailed procedural models of the tall verge and wall-foot herbs round Reval
				## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
				## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
				## (far flag, vertex contract); shares the stem, strand and leaf helpers of
				## city_herb_meshes.gd. Every seasonal variant of a species reuses the
				## flowering kind's seed, so it is the same plant in another season.
				## Kind -> [species (seed), stage].
				# Colours are sRGB, picked from field photographs of each species.
				# Young April shoots are dark and purple-flushed.
				## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
				# --- Field mint (Mentha arvensis) -------------------------------------------
				# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
				# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
				# from the last; from July round balls of lilac flowers sit in the upper leaf
				# axils, one whorl above another.
				# Stems sprawl out from creeping runners before they turn up.
				# Whorls of florets in the leaf axils of the upper half.
				# --- Mugwort (Artemisia vulgaris) -------------------------------------------
				# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
				# dark green above and silver-white felted below, smaller and simpler up the
				# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
				# on short side branches. In autumn the whole stand dries brown and stays up.
				# Before flowering the stems are still growing.
				# Alternate leaves up the lower two thirds.
				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.
				# --- Creeping thistle (Cirsium arvense) -------------------------------------
				# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
				# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
				# stem branches into many small heads: a green, purple-tipped cup under a
				# lilac brush of florets, then white thistledown in August-September.
				# Branches from the top third, each with one to three heads.
				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
				# A loose ball of silky pappus, bigger than the head that bore it.
				# The brush: a tuft of fine lilac florets fanning up out of the cup.
				# --- Stinging nettle (Urtica dioica) ----------------------------------------
				# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
				# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
				# pair a quarter turn from the last, drooping at the tip; from July, thin
				# greenish flower tassels hang from the upper leaf axils. In April and May the
				# stand is a carpet of short, dark, purple-flushed shoots.
				# A short shoot: three crowded pairs of young leaves on 12-22 cm.
				## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
				## coarse forward-pointing teeth, drooping toward its tip.
				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				## Detailed procedural models of the tall verge and wall-foot herbs round Reval
				## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
				## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
				## (far flag, vertex contract); shares the stem, strand and leaf helpers of
				## city_herb_meshes.gd. Every seasonal variant of a species reuses the
				## flowering kind's seed, so it is the same plant in another season.
				## Kind -> [species (seed), stage].
				# Colours are sRGB, picked from field photographs of each species.
				# Young April shoots are dark and purple-flushed.
				## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
				# --- Field mint (Mentha arvensis) -------------------------------------------
				# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
				# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
				# from the last; from July round balls of lilac flowers sit in the upper leaf
				# axils, one whorl above another.
				# Stems sprawl out from creeping runners before they turn up.
				# Whorls of florets in the leaf axils of the upper half.
				# --- Mugwort (Artemisia vulgaris) -------------------------------------------
				# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
				# dark green above and silver-white felted below, smaller and simpler up the
				# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
				# on short side branches. In autumn the whole stand dries brown and stays up.
				# Before flowering the stems are still growing.
				# Alternate leaves up the lower two thirds.
				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.
				# --- Creeping thistle (Cirsium arvense) -------------------------------------
				# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
				# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
				# stem branches into many small heads: a green, purple-tipped cup under a
				# lilac brush of florets, then white thistledown in August-September.
				# Branches from the top third, each with one to three heads.
				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
				# A loose ball of silky pappus, bigger than the head that bore it.
				# The brush: a tuft of fine lilac florets fanning up out of the cup.
				# --- Stinging nettle (Urtica dioica) ----------------------------------------
				# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
				# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
				# pair a quarter turn from the last, drooping at the tip; from July, thin
				# greenish flower tassels hang from the upper leaf axils. In April and May the
				# stand is a carpet of short, dark, purple-flushed shoots.
				# A short shoot: three crowded pairs of young leaves on 12-22 cm.
				## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
				## coarse forward-pointing teeth, drooping toward its tip.
				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.
				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

				## Detailed procedural models of the tall verge and wall-foot herbs round Reval
				## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
				## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
				## (far flag, vertex contract); shares the stem, strand and leaf helpers of
				## city_herb_meshes.gd. Every seasonal variant of a species reuses the
				## flowering kind's seed, so it is the same plant in another season.
				## Kind -> [species (seed), stage].
				# Colours are sRGB, picked from field photographs of each species.
				# Young April shoots are dark and purple-flushed.
				## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
				# --- Field mint (Mentha arvensis) -------------------------------------------
				# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
				# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
				# from the last; from July round balls of lilac flowers sit in the upper leaf
				# axils, one whorl above another.
				# Stems sprawl out from creeping runners before they turn up.
				# Whorls of florets in the leaf axils of the upper half.
				# --- Mugwort (Artemisia vulgaris) -------------------------------------------
				# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
				# dark green above and silver-white felted below, smaller and simpler up the
				# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
				# on short side branches. In autumn the whole stand dries brown and stays up.
				# Before flowering the stems are still growing.
				# Alternate leaves up the lower two thirds.
				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.
				# --- Creeping thistle (Cirsium arvense) -------------------------------------
				# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
				# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
				# stem branches into many small heads: a green, purple-tipped cup under a
				# lilac brush of florets, then white thistledown in August-September.
				# Branches from the top third, each with one to three heads.
				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
				# A loose ball of silky pappus, bigger than the head that bore it.
				# The brush: a tuft of fine lilac florets fanning up out of the cup.
				# --- Stinging nettle (Urtica dioica) ----------------------------------------
				# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
				# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
				# pair a quarter turn from the last, drooping at the tip; from July, thin
				# greenish flower tassels hang from the upper leaf axils. In April and May the
				# stand is a carpet of short, dark, purple-flushed shoots.
				# A short shoot: three crowded pairs of young leaves on 12-22 cm.
				## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
				## coarse forward-pointing teeth, drooping toward its tip.
				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.
				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## A hanging nettle flower tassel: a thin, knotted, greenish catkin.

# --- Helpers -----------------------------------------------------------------

## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
## nodes; returns the centre line.

## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
## narrow midrib. `under` is the paleness of the back face (mugwort's silver
## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
## `wave` how far alternate lobes twist up and down.

				## Detailed procedural models of the tall verge and wall-foot herbs round Reval
				## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
				## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
				## (far flag, vertex contract); shares the stem, strand and leaf helpers of
				## city_herb_meshes.gd. Every seasonal variant of a species reuses the
				## flowering kind's seed, so it is the same plant in another season.
				## Kind -> [species (seed), stage].
				# Colours are sRGB, picked from field photographs of each species.
				# Young April shoots are dark and purple-flushed.
				## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
				# --- Field mint (Mentha arvensis) -------------------------------------------
				# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
				# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
				# from the last; from July round balls of lilac flowers sit in the upper leaf
				# axils, one whorl above another.
				# Stems sprawl out from creeping runners before they turn up.
				# Whorls of florets in the leaf axils of the upper half.
				# --- Mugwort (Artemisia vulgaris) -------------------------------------------
				# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
				# dark green above and silver-white felted below, smaller and simpler up the
				# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
				# on short side branches. In autumn the whole stand dries brown and stays up.
				# Before flowering the stems are still growing.
				# Alternate leaves up the lower two thirds.
				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.
				# --- Creeping thistle (Cirsium arvense) -------------------------------------
				# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
				# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
				# stem branches into many small heads: a green, purple-tipped cup under a
				# lilac brush of florets, then white thistledown in August-September.
				# Branches from the top third, each with one to three heads.
				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
				# A loose ball of silky pappus, bigger than the head that bore it.
				# The brush: a tuft of fine lilac florets fanning up out of the cup.
				# --- Stinging nettle (Urtica dioica) ----------------------------------------
				# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
				# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
				# pair a quarter turn from the last, drooping at the tip; from July, thin
				# greenish flower tassels hang from the upper leaf axils. In April and May the
				# stand is a carpet of short, dark, purple-flushed shoots.
				# A short shoot: three crowded pairs of young leaves on 12-22 cm.
				## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
				## coarse forward-pointing teeth, drooping toward its tip.
				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.
				# Teeth point forward: the outer margin runs ahead of the midrib a little.
				## A hanging nettle flower tassel: a thin, knotted, greenish catkin.
				# --- Helpers -----------------------------------------------------------------
				## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
				## nodes; returns the centre line.
				## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
				## narrow midrib. `under` is the paleness of the back face (mugwort's silver
				## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
				## `wave` how far alternate lobes twist up and down.
				# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## A hanging nettle flower tassel: a thin, knotted, greenish catkin.

# --- Helpers -----------------------------------------------------------------

## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
## nodes; returns the centre line.

## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
## narrow midrib. `under` is the paleness of the back face (mugwort's silver
## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
## `wave` how far alternate lobes twist up and down.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## A hanging nettle flower tassel: a thin, knotted, greenish catkin.

# --- Helpers -----------------------------------------------------------------

## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
## nodes; returns the centre line.

## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
## narrow midrib. `under` is the paleness of the back face (mugwort's silver
## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
## `wave` how far alternate lobes twist up and down.

				# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.

				## Detailed procedural models of the tall verge and wall-foot herbs round Reval
				## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
				## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
				## (far flag, vertex contract); shares the stem, strand and leaf helpers of
				## city_herb_meshes.gd. Every seasonal variant of a species reuses the
				## flowering kind's seed, so it is the same plant in another season.
				## Kind -> [species (seed), stage].
				# Colours are sRGB, picked from field photographs of each species.
				# Young April shoots are dark and purple-flushed.
				## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
				# --- Field mint (Mentha arvensis) -------------------------------------------
				# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
				# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
				# from the last; from July round balls of lilac flowers sit in the upper leaf
				# axils, one whorl above another.
				# Stems sprawl out from creeping runners before they turn up.
				# Whorls of florets in the leaf axils of the upper half.
				# --- Mugwort (Artemisia vulgaris) -------------------------------------------
				# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
				# dark green above and silver-white felted below, smaller and simpler up the
				# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
				# on short side branches. In autumn the whole stand dries brown and stays up.
				# Before flowering the stems are still growing.
				# Alternate leaves up the lower two thirds.
				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.
				# --- Creeping thistle (Cirsium arvense) -------------------------------------
				# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
				# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
				# stem branches into many small heads: a green, purple-tipped cup under a
				# lilac brush of florets, then white thistledown in August-September.
				# Branches from the top third, each with one to three heads.
				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
				# A loose ball of silky pappus, bigger than the head that bore it.
				# The brush: a tuft of fine lilac florets fanning up out of the cup.
				# --- Stinging nettle (Urtica dioica) ----------------------------------------
				# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
				# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
				# pair a quarter turn from the last, drooping at the tip; from July, thin
				# greenish flower tassels hang from the upper leaf axils. In April and May the
				# stand is a carpet of short, dark, purple-flushed shoots.
				# A short shoot: three crowded pairs of young leaves on 12-22 cm.
				## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
				## coarse forward-pointing teeth, drooping toward its tip.
				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.
				# Teeth point forward: the outer margin runs ahead of the midrib a little.
				## A hanging nettle flower tassel: a thin, knotted, greenish catkin.
				# --- Helpers -----------------------------------------------------------------
				## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
				## nodes; returns the centre line.
				## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
				## narrow midrib. `under` is the paleness of the back face (mugwort's silver
				## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
				## `wave` how far alternate lobes twist up and down.
				# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## A hanging nettle flower tassel: a thin, knotted, greenish catkin.

# --- Helpers -----------------------------------------------------------------

## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
## nodes; returns the centre line.

## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
## narrow midrib. `under` is the paleness of the back face (mugwort's silver
## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
## `wave` how far alternate lobes twist up and down.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## A hanging nettle flower tassel: a thin, knotted, greenish catkin.

# --- Helpers -----------------------------------------------------------------

## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
## nodes; returns the centre line.

## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
## narrow midrib. `under` is the paleness of the back face (mugwort's silver
## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
## `wave` how far alternate lobes twist up and down.

				# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## A hanging nettle flower tassel: a thin, knotted, greenish catkin.

# --- Helpers -----------------------------------------------------------------

## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
## nodes; returns the centre line.

## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
## narrow midrib. `under` is the paleness of the back face (mugwort's silver
## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
## `wave` how far alternate lobes twist up and down.

				# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.

				## Detailed procedural models of the tall verge and wall-foot herbs round Reval
				## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
				## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
				## (far flag, vertex contract); shares the stem, strand and leaf helpers of
				## city_herb_meshes.gd. Every seasonal variant of a species reuses the
				## flowering kind's seed, so it is the same plant in another season.
				## Kind -> [species (seed), stage].
				# Colours are sRGB, picked from field photographs of each species.
				# Young April shoots are dark and purple-flushed.
				## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
				# --- Field mint (Mentha arvensis) -------------------------------------------
				# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
				# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
				# from the last; from July round balls of lilac flowers sit in the upper leaf
				# axils, one whorl above another.
				# Stems sprawl out from creeping runners before they turn up.
				# Whorls of florets in the leaf axils of the upper half.
				# --- Mugwort (Artemisia vulgaris) -------------------------------------------
				# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
				# dark green above and silver-white felted below, smaller and simpler up the
				# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
				# on short side branches. In autumn the whole stand dries brown and stays up.
				# Before flowering the stems are still growing.
				# Alternate leaves up the lower two thirds.
				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.
				# --- Creeping thistle (Cirsium arvense) -------------------------------------
				# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
				# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
				# stem branches into many small heads: a green, purple-tipped cup under a
				# lilac brush of florets, then white thistledown in August-September.
				# Branches from the top third, each with one to three heads.
				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
				# A loose ball of silky pappus, bigger than the head that bore it.
				# The brush: a tuft of fine lilac florets fanning up out of the cup.
				# --- Stinging nettle (Urtica dioica) ----------------------------------------
				# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
				# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
				# pair a quarter turn from the last, drooping at the tip; from July, thin
				# greenish flower tassels hang from the upper leaf axils. In April and May the
				# stand is a carpet of short, dark, purple-flushed shoots.
				# A short shoot: three crowded pairs of young leaves on 12-22 cm.
				## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
				## coarse forward-pointing teeth, drooping toward its tip.
				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.
				# Teeth point forward: the outer margin runs ahead of the midrib a little.
				## A hanging nettle flower tassel: a thin, knotted, greenish catkin.
				# --- Helpers -----------------------------------------------------------------
				## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
				## nodes; returns the centre line.
				## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
				## narrow midrib. `under` is the paleness of the back face (mugwort's silver
				## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
				## `wave` how far alternate lobes twist up and down.
				# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## A hanging nettle flower tassel: a thin, knotted, greenish catkin.

# --- Helpers -----------------------------------------------------------------

## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
## nodes; returns the centre line.

## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
## narrow midrib. `under` is the paleness of the back face (mugwort's silver
## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
## `wave` how far alternate lobes twist up and down.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## A hanging nettle flower tassel: a thin, knotted, greenish catkin.

# --- Helpers -----------------------------------------------------------------

## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
## nodes; returns the centre line.

## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
## narrow midrib. `under` is the paleness of the back face (mugwort's silver
## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
## `wave` how far alternate lobes twist up and down.

				# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## A hanging nettle flower tassel: a thin, knotted, greenish catkin.

# --- Helpers -----------------------------------------------------------------

## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
## nodes; returns the centre line.

## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
## narrow midrib. `under` is the paleness of the back face (mugwort's silver
## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
## `wave` how far alternate lobes twist up and down.

				# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## A hanging nettle flower tassel: a thin, knotted, greenish catkin.

# --- Helpers -----------------------------------------------------------------

## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
## nodes; returns the centre line.

## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
## narrow midrib. `under` is the paleness of the back face (mugwort's silver
## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
## `wave` how far alternate lobes twist up and down.

				# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.

				## Detailed procedural models of the tall verge and wall-foot herbs round Reval
				## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
				## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
				## (far flag, vertex contract); shares the stem, strand and leaf helpers of
				## city_herb_meshes.gd. Every seasonal variant of a species reuses the
				## flowering kind's seed, so it is the same plant in another season.
				## Kind -> [species (seed), stage].
				# Colours are sRGB, picked from field photographs of each species.
				# Young April shoots are dark and purple-flushed.
				## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).
				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).
				# --- Field mint (Mentha arvensis) -------------------------------------------
				# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
				# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
				# from the last; from July round balls of lilac flowers sit in the upper leaf
				# axils, one whorl above another.
				# Stems sprawl out from creeping runners before they turn up.
				# Whorls of florets in the leaf axils of the upper half.
				# --- Mugwort (Artemisia vulgaris) -------------------------------------------
				# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
				# dark green above and silver-white felted below, smaller and simpler up the
				# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
				# on short side branches. In autumn the whole stand dries brown and stays up.
				# Before flowering the stems are still growing.
				# Alternate leaves up the lower two thirds.
				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.
				# --- Creeping thistle (Cirsium arvense) -------------------------------------
				# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
				# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
				# stem branches into many small heads: a green, purple-tipped cup under a
				# lilac brush of florets, then white thistledown in August-September.
				# Branches from the top third, each with one to three heads.
				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.
				# A loose ball of silky pappus, bigger than the head that bore it.
				# The brush: a tuft of fine lilac florets fanning up out of the cup.
				# --- Stinging nettle (Urtica dioica) ----------------------------------------
				# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
				# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
				# pair a quarter turn from the last, drooping at the tip; from July, thin
				# greenish flower tassels hang from the upper leaf axils. In April and May the
				# stand is a carpet of short, dark, purple-flushed shoots.
				# A short shoot: three crowded pairs of young leaves on 12-22 cm.
				## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
				## coarse forward-pointing teeth, drooping toward its tip.
				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.
				# Teeth point forward: the outer margin runs ahead of the midrib a little.
				## A hanging nettle flower tassel: a thin, knotted, greenish catkin.
				# --- Helpers -----------------------------------------------------------------
				## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
				## nodes; returns the centre line.
				## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
				## narrow midrib. `under` is the paleness of the back face (mugwort's silver
				## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
				## `wave` how far alternate lobes twist up and down.
				# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## A hanging nettle flower tassel: a thin, knotted, greenish catkin.

# --- Helpers -----------------------------------------------------------------

## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
## nodes; returns the centre line.

## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
## narrow midrib. `under` is the paleness of the back face (mugwort's silver
## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
## `wave` how far alternate lobes twist up and down.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## A hanging nettle flower tassel: a thin, knotted, greenish catkin.

# --- Helpers -----------------------------------------------------------------

## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
## nodes; returns the centre line.

## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
## narrow midrib. `under` is the paleness of the back face (mugwort's silver
## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
## `wave` how far alternate lobes twist up and down.

				# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## A hanging nettle flower tassel: a thin, knotted, greenish catkin.

# --- Helpers -----------------------------------------------------------------

## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
## nodes; returns the centre line.

## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
## narrow midrib. `under` is the paleness of the back face (mugwort's silver
## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
## `wave` how far alternate lobes twist up and down.

				# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## A hanging nettle flower tassel: a thin, knotted, greenish catkin.

# --- Helpers -----------------------------------------------------------------

## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
## nodes; returns the centre line.

## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
## narrow midrib. `under` is the paleness of the back face (mugwort's silver
## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
## `wave` how far alternate lobes twist up and down.

				# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.

## Detailed procedural models of the tall verge and wall-foot herbs round Reval
## (R-2128): field mint, mugwort, creeping thistle and stinging nettle, with
## their seasonal variants. Built and cached through CityForbMeshes.mesh_for
## (far flag, vertex contract); shares the stem, strand and leaf helpers of
## city_herb_meshes.gd. Every seasonal variant of a species reuses the
## flowering kind's seed, so it is the same plant in another season.

## Kind -> [species (seed), stage].

# Colours are sRGB, picked from field photographs of each species.

# Young April shoots are dark and purple-flushed.

## Builds `kind` into `b` if it is one of this file's weeds (false otherwise).

				# The dry autumn stalks reuse burdock's withering (CityForbMeshes._wither).

# --- Field mint (Mentha arvensis) -------------------------------------------
# A loose patch of square, purplish, ascending stems 20-40 cm high with oval,
# toothed, short-stalked leaves in opposite pairs, each pair turned a quarter
# from the last; from July round balls of lilac flowers sit in the upper leaf
# axils, one whorl above another.

				# Stems sprawl out from creeping runners before they turn up.

				# Whorls of florets in the leaf axils of the upper half.

# --- Mugwort (Artemisia vulgaris) -------------------------------------------
# Tall, ridged, reddish-purple stems a metre and more high; deeply cut leaves,
# dark green above and silver-white felted below, smaller and simpler up the
# stem; from mid July a long grey-green plume of tiny reddish-brown flower heads
# on short side branches. In autumn the whole stand dries brown and stays up.

				# Before flowering the stems are still growing.

				# Alternate leaves up the lower two thirds.

				# The plume: short side branches on the top third, each a spray of tiny
				# ovoid heads, shorter toward the tip so the plume tapers.

# --- Creeping thistle (Cirsium arvense) -------------------------------------
# Patches of upright stems 60-100 cm high from creeping roots; wavy, lobed,
# stalkless leaves whose every lobe ends in a stiff yellowish spine; the upper
# stem branches into many small heads: a green, purple-tipped cup under a
# lilac brush of florets, then white thistledown in August-September.

				# Branches from the top third, each with one to three heads.

				# Involucre: an egg-shaped cup of overlapping bracts, purple-tipped.

				# A loose ball of silky pappus, bigger than the head that bore it.

				# The brush: a tuft of fine lilac florets fanning up out of the cup.

# --- Stinging nettle (Urtica dioica) ----------------------------------------
# A dense clonal stand of square, bristly stems 60-130 cm high; heart-shaped,
# long-pointed, coarsely saw-toothed leaves on stalks in opposite pairs, each
# pair a quarter turn from the last, drooping at the tip; from July, thin
# greenish flower tassels hang from the upper leaf axils. In April and May the
# stand is a carpet of short, dark, purple-flushed shoots.

				# A short shoot: three crowded pairs of young leaves on 12-22 cm.

## A nettle leaf: a short stalk, then a heart-based, long-pointed blade with
## coarse forward-pointing teeth, drooping toward its tip.

				# Stalk for the first 12 %, a cordate base, widest at a third, then a
				# long acuminate tip; saw teeth bite into the margin.

				# Teeth point forward: the outer margin runs ahead of the midrib a little.

## A hanging nettle flower tassel: a thin, knotted, greenish catkin.

# --- Helpers -----------------------------------------------------------------

## A tall stem of 13 rings (mugwort, thistle) so leaves and branches have many
## nodes; returns the centre line.

## A deeply lobed leaf (mugwort, thistle): `lobes` pointed lobes a side along a
## narrow midrib. `under` is the paleness of the back face (mugwort's silver
## felt), `spine` the length of the stiff spine at each lobe tip (thistle) and
## `wave` how far alternate lobes twist up and down.

				# Lobes: the margin swings between a narrow sinus and a pointed lobe tip.

				return (color * tone).lightened(0.05 * (1.0 - t)).darkened(absf(s) * 0.05),
			"tile": CityForbMeshes.TILE_DANDELION,
			"flex": Vector2(flex, flex + 0.3),
			"under": under,
			"trans": 0.25,
		}
	)
	if spine <= 0.0 or CityForbMeshes._far:
		return
	# Spines at the lobe tips, along the margin outward.
	var forward_h := Vector3(cos(yaw), 0.0, sin(yaw))
	var side := Vector3(-sin(yaw), 0.0, cos(yaw))
	for k in lobes:
		var t := (float(k) + 0.5) / count
		var pitch := rise - droop * t * 0.5
		var c := at + (forward_h * cos(pitch) + Vector3.UP * sin(pitch)) * size * t
		var w := size * 0.3 * sin(PI * minf(t * 0.9 + 0.08, 1.0))
		for s: float in [-1.0, 1.0]:
			var tip := c + side * s * w
			Herbs._strand(
				b,
				PackedVector3Array([tip, tip + (side * s + forward_h * 0.4).normalized() * spine]),
				0.0007,
				THISTLE_SPINE,
				Vector2(flex + 0.2, flex + 0.25),
				0.2,
				Vector3.UP,
				0.0,
				0.8
			)


## A spray of tiny ovoid flower heads along a short branch (mugwort plume).
static func _head_spray(
	b: CityForbMeshes.Builder,
	rng: RandomNumberGenerator,
	from: Vector3,
	tip: Vector3,
	flex: float,
	heads: int,
	color: Color,
	ripe: Color,
	r: float
) -> void:
	var stalk := CityForbMeshes._wither(MUGWORT_STEM)
	if not CityForbMeshes._far:
		Herbs._strand(
			b,
			PackedVector3Array([from, from.lerp(tip, 0.5), tip]),
			0.0012,
			stalk,
			Vector2(flex * 0.9, flex + 0.2),
			0.2,
			Vector3.UP,
			0.0,
			0.5
		)
	for h in heads:
		if CityForbMeshes._far and h % 3 != 0:
			continue
		var c := (
			from.lerp(tip, (float(h) + 1.0) / float(heads))
			+ Vector3(rng.randf_range(-1, 1), 0.0, rng.randf_range(-1, 1)) * r
		)
		var tint := CityForbMeshes._wither(color.lerp(ripe, rng.randf()))
		var size := r * (2.0 if CityForbMeshes._far else 1.0)
		CityForbMeshes._blob(
			b,
			c,
			Vector3(size, size * 1.3, size),
			2,
			4,
			func(_d: Vector3) -> Color: return tint,
			0.2,
			flex + 0.2,
			0.25
		)
