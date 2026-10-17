class_name CityDwarfShrubMeshes
extends RefCounted

## Procedural dwarf shrubs and berry plants of the Estonian forest floor, heath
## and bog (R-2127): bilberry, cowberry, heather, crowberry, cloudberry,
## cranberry, bog rosemary, wild strawberry, plus the sphagnum mat the bog
## species sit on. One clump per (species, stage), built in metres and cached;
## CityDwarfShrubs scatters them with MultiMesh and swaps the stage mesh with the
## calendar.
##
## The plant's structure (stems, sprays, leaf positions) comes from one fixed
## seed per species and every random draw is taken whatever the stage, so the
## same clump keeps its shape from flower to fruit to winter; a stage only
## changes leaf colour and adds or removes flowers and berries (second seed).
##
## Vertex contract is the forb one (city_forb.gdshader, CityForbMeshes.Builder):
## COLOR.rgb albedo, COLOR.a light transmitted, UV.x flex 0 root .. 1 tip,
## UV.y underside paleness. Berries and flowers are drawn about 1.5x life size,
## like the forbs, so they register from the gameplay camera.

const ForbMeshes := preload("res://scripts/city/city_forb_meshes.gd")

const SPECIES_BILBERRY := &"bilberry"
const SPECIES_COWBERRY := &"cowberry"
const SPECIES_HEATHER := &"heather"
const SPECIES_CROWBERRY := &"crowberry"
const SPECIES_CLOUDBERRY := &"cloudberry"
const SPECIES_CRANBERRY := &"cranberry"
const SPECIES_BOG_ROSEMARY := &"bog_rosemary"
const SPECIES_WILD_STRAWBERRY := &"wild_strawberry"
## Not a shrub: the peat-moss cushion the bog berries grow on.
const SPECIES_SPHAGNUM := &"sphagnum"
const SPECIES: Array[StringName] = [
	SPECIES_BILBERRY,
	SPECIES_COWBERRY,
	SPECIES_HEATHER,
	SPECIES_CROWBERRY,
	SPECIES_CLOUDBERRY,
	SPECIES_CRANBERRY,
	SPECIES_BOG_ROSEMARY,
	SPECIES_WILD_STRAWBERRY,
	SPECIES_SPHAGNUM,
]

const STAGE_NONE := &"none"
const STAGE_BARE := &"bare"
const STAGE_LEAF := &"leaf"
const STAGE_FLOWER := &"flower"
const STAGE_FRUIT := &"fruit"
const STAGE_AUTUMN := &"autumn"
const STAGE_WINTER := &"winter"
## Stages with a model, per species (STAGE_NONE: nothing above ground).
const STAGES := {
	&"bilberry": [&"bare", &"leaf", &"flower", &"fruit", &"autumn"],
	&"cowberry": [&"leaf", &"flower", &"fruit", &"winter"],
	&"heather": [&"leaf", &"flower", &"winter"],
	&"crowberry": [&"leaf", &"fruit", &"winter"],
	&"cloudberry": [&"leaf", &"flower", &"fruit", &"autumn"],
	&"cranberry": [&"leaf", &"flower", &"fruit", &"winter"],
	&"bog_rosemary": [&"leaf", &"flower", &"winter"],
	&"wild_strawberry": [&"leaf", &"flower", &"fruit", &"autumn"],
	&"sphagnum": [&"leaf"],
}
## Triangle budget per clump (tests hold every model to it).
const MAX_TRIANGLES := 350

# Colours are sRGB (the Builder linearises them), kept a little below full
# saturation: the city's AgX grade bleaches bright reds and pinks.
const BILBERRY_STEM := Color(0.36, 0.50, 0.22)
const BILBERRY_FRESH := Color(0.36, 0.58, 0.20)
const BILBERRY_SUMMER := Color(0.27, 0.46, 0.16)
const BILBERRY_RED := Color(0.64, 0.14, 0.10)
const BILBERRY_ORANGE := Color(0.76, 0.34, 0.12)
const BILBERRY_BERRY := Color(0.17, 0.20, 0.34)
const BILBERRY_FLOWER := Color(0.82, 0.50, 0.48)
const COWBERRY_STEM := Color(0.40, 0.30, 0.20)
const COWBERRY_LEAF := Color(0.15, 0.31, 0.11)
const COWBERRY_WINTER := Color(0.21, 0.22, 0.11)
const COWBERRY_BRONZE := Color(0.40, 0.20, 0.13)
const COWBERRY_BERRY := Color(0.74, 0.10, 0.09)
const COWBERRY_FLOWER := Color(0.94, 0.84, 0.84)
const HEATHER_STEM := Color(0.36, 0.26, 0.18)
const HEATHER_LEAF := Color(0.30, 0.38, 0.20)
const HEATHER_FLOWER := Color(0.66, 0.40, 0.64)
const HEATHER_WINTER := Color(0.42, 0.27, 0.16)
const CROWBERRY_STEM := Color(0.32, 0.20, 0.14)
const CROWBERRY_LEAF := Color(0.13, 0.25, 0.10)
const CROWBERRY_WINTER := Color(0.22, 0.19, 0.10)
const CROWBERRY_BERRY := Color(0.05, 0.05, 0.06)
const CLOUDBERRY_STEM := Color(0.44, 0.40, 0.22)
const CLOUDBERRY_LEAF := Color(0.30, 0.48, 0.18)
const CLOUDBERRY_AUTUMN := Color(0.58, 0.28, 0.14)
const CLOUDBERRY_FLOWER := Color(0.95, 0.94, 0.90)
const CLOUDBERRY_CORE := Color(0.80, 0.74, 0.40)
const CLOUDBERRY_RED := Color(0.84, 0.32, 0.14)
const CLOUDBERRY_AMBER := Color(0.92, 0.62, 0.20)
const CRANBERRY_STEM := Color(0.40, 0.22, 0.16)
const CRANBERRY_LEAF := Color(0.22, 0.36, 0.14)
const CRANBERRY_WINTER := Color(0.42, 0.16, 0.12)
const CRANBERRY_BERRY := Color(0.70, 0.08, 0.10)
const CRANBERRY_FLOWER := Color(0.88, 0.56, 0.66)
const ROSEMARY_STEM := Color(0.44, 0.30, 0.24)
const ROSEMARY_LEAF := Color(0.38, 0.50, 0.44)
const ROSEMARY_WINTER := Color(0.42, 0.30, 0.32)
const ROSEMARY_FLOWER := Color(0.90, 0.62, 0.66)
const STRAWBERRY_STALK := Color(0.40, 0.46, 0.24)
const STRAWBERRY_LEAF := Color(0.24, 0.42, 0.15)
const STRAWBERRY_AUTUMN := Color(0.64, 0.22, 0.12)
const STRAWBERRY_FLOWER := Color(0.95, 0.95, 0.92)
const STRAWBERRY_CORE := Color(0.86, 0.72, 0.20)
const STRAWBERRY_FRUIT := Color(0.80, 0.12, 0.08)
const STRAWBERRY_CALYX := Color(0.28, 0.44, 0.16)
const SPHAGNUM_GREEN := Color(0.48, 0.56, 0.22)
const SPHAGNUM_OCHRE := Color(0.70, 0.58, 0.28)
const SPHAGNUM_RED := Color(0.60, 0.24, 0.16)

static var _cache: Dictionary = {}
## Height of the clump being built, for the flex channel (0 root .. 1 top).
static var _height := 0.3


static func stages(species: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for stage: StringName in STAGES.get(species, []):
		out.append(stage)
	return out


static func mesh_for(species: StringName, stage: StringName) -> ArrayMesh:
	var key := "%s:%s" % [species, stage]
	if not _cache.has(key):
		_cache[key] = _build(species, stage)
	return _cache[key]


static func triangle_count(mesh: ArrayMesh) -> int:
	var arrays := mesh.surface_get_arrays(0)
	return (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3


static func _build(species: StringName, stage: StringName) -> ArrayMesh:
	var b := ForbMeshes.Builder.new()
	match species:
		SPECIES_BILBERRY:
			_bilberry(b, stage)
		SPECIES_COWBERRY:
			_cowberry(b, stage)
		SPECIES_HEATHER:
			_heather(b, stage)
		SPECIES_CROWBERRY:
			_crowberry(b, stage)
		SPECIES_CLOUDBERRY:
			_cloudberry(b, stage)
		SPECIES_CRANBERRY:
			_cranberry(b, stage)
		SPECIES_BOG_ROSEMARY:
			_bog_rosemary(b, stage)
		SPECIES_WILD_STRAWBERRY:
			_wild_strawberry(b, stage)
		SPECIES_SPHAGNUM:
			_sphagnum(b)
	return b.commit()


static func _rng(species: StringName, salt: int = 0) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(species)) + salt * 7919
	return rng


## Bilberry: an open clump of angular green stems, 22-36 cm, with small bright
## oval leaves. Deciduous: bare green twigs from November to April, pink-red
## bells in May, blue-black frosted berries in July-August, crimson in autumn.
static func _bilberry(b: ForbMeshes.Builder, stage: StringName) -> void:
	_height = 0.36
	var rng := _rng(SPECIES_BILBERRY)
	var spots: Array[Vector3] = []  # leaf axils: where bells and berries hang
	for s in 6:
		var ang := TAU * float(s) / 6.0 + rng.randf_range(-0.4, 0.4)
		var out := Vector3(cos(ang), 0.0, sin(ang))
		var across := Vector3(-out.z, 0.0, out.x)
		var base := out * rng.randf_range(0.0, 0.09)
		var h := rng.randf_range(0.22, 0.36)
		var lean := out * rng.randf_range(0.03, 0.08)
		var pts: Array[Vector3] = [base]
		for k in 3:
			var t := float(k + 1) / 3.0
			# Bilberry stems are sharply angled: a zigzag at every node.
			var zig := across * rng.randf_range(-0.025, 0.025)
			pts.append(base + lean * t + Vector3(0.0, h * t, 0.0) + zig)
		for k in 3:
			_stem(b, pts[k], pts[k + 1], 0.0035 * (1.0 - float(k) * 0.25), BILBERRY_STEM)
		var tw_base: Vector3 = pts[2]
		var tw_dir := (
			(out * 0.6 + across * rng.randf_range(-0.6, 0.6) + Vector3.UP * 0.8).normalized()
		)
		var tw_tip := tw_base + tw_dir * h * 0.35
		_stem(b, tw_base, tw_tip, 0.0024, BILBERRY_STEM)
		for li in 8:
			var at := (
				_along(pts, 0.3 + 0.7 * float(li) / 6.0)
				if li < 6
				else tw_base.lerp(tw_tip, 0.5 + 0.5 * float(li - 6))
			)
			var la := rng.randf() * TAU
			var dir := Vector3(cos(la), rng.randf_range(0.1, 0.5), sin(la))
			var length := rng.randf_range(0.026, 0.036)
			var width := rng.randf_range(0.015, 0.021)
			var roll := rng.randf()
			spots.append(at)
			if stage == STAGE_BARE:
				continue
			var col := BILBERRY_FRESH if stage in [STAGE_LEAF, STAGE_FLOWER] else BILBERRY_SUMMER
			if stage == STAGE_AUTUMN:
				col = BILBERRY_RED.lerp(BILBERRY_ORANGE, roll * roll)
			_leaf(b, at, dir, length, width, col * (0.9 + 0.2 * roll), 0.3, 0.35)
	var adorn := _rng(SPECIES_BILBERRY, 1)
	if stage == STAGE_FLOWER:
		for _i in 8:
			var at: Vector3 = spots[adorn.randi() % spots.size()]
			_bell(
				b,
				at,
				Vector3(adorn.randf_range(-0.3, 0.3), -1.0, 0.0),
				0.009,
				0.006,
				BILBERRY_FLOWER
			)
	elif stage == STAGE_FRUIT:
		for _i in 10:
			var at: Vector3 = spots[adorn.randi() % spots.size()]
			_berry(
				b, at + Vector3(0.0, -0.008, 0.0), adorn.randf_range(0.0055, 0.0065), BILBERRY_BERRY
			)


## Cowberry (lingonberry): a low evergreen clump, 10-18 cm, of short stems
## crowded with glossy dark oval leaves; white-pink bell clusters at the shoot
## tips in June, red berry clusters from August, darker and bronzed in winter.
static func _cowberry(b: ForbMeshes.Builder, stage: StringName) -> void:
	_height = 0.18
	var rng := _rng(SPECIES_COWBERRY)
	var tips: Array[Vector3] = []
	for s in 8:
		var ang := TAU * float(s) / 8.0 + rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(ang), 0.0, sin(ang))
		var base := out * rng.randf_range(0.0, 0.1)
		var h := rng.randf_range(0.09, 0.18)
		var mid := base + out * 0.03 + Vector3(0.0, h * 0.5, 0.0)
		var tip := base + out * rng.randf_range(0.03, 0.06) + Vector3(0.0, h, 0.0)
		_stem(b, base, mid, 0.003, COWBERRY_STEM)
		_stem(b, mid, tip, 0.0024, COWBERRY_STEM)
		tips.append(tip)
		var line: Array[Vector3] = [base, mid, tip]
		for li in 8:
			var at := _along(line, 0.35 + 0.65 * float(li) / 7.0)
			var la := rng.randf() * TAU
			var dir := Vector3(cos(la), rng.randf_range(0.2, 0.7), sin(la))
			var roll := rng.randf()
			var col := COWBERRY_LEAF
			if stage == STAGE_WINTER:
				col = COWBERRY_WINTER.lerp(COWBERRY_BRONZE, roll * roll)
			_leaf(
				b,
				at,
				dir,
				rng.randf_range(0.02, 0.026),
				rng.randf_range(0.011, 0.014),
				col * (0.9 + 0.2 * roll),
				0.45,
				0.15
			)
	var adorn := _rng(SPECIES_COWBERRY, 1)
	for t: Vector3 in tips.slice(0, 4):
		for _k in 3:
			var off := Vector3(
				adorn.randf_range(-0.012, 0.012),
				adorn.randf_range(-0.01, 0.0),
				adorn.randf_range(-0.012, 0.012)
			)
			if stage == STAGE_FLOWER:
				_bell(b, t + off, Vector3(off.x, -1.0, off.z), 0.009, 0.0065, COWBERRY_FLOWER)
			elif stage == STAGE_FRUIT:
				_berry(b, t + off + Vector3(0.0, -0.004, 0.0), 0.0065, COWBERRY_BERRY)


## Heather (ling): a bushy mat, 20-35 cm, of wiry stems ending in sprays of
## tiny scale leaves, drawn as crossed narrow cards. Purple flower spikes along
## the spray tips in August-September; rust brown through the winter.
static func _heather(b: ForbMeshes.Builder, stage: StringName) -> void:
	_height = 0.34
	var rng := _rng(SPECIES_HEATHER)
	var leaf := HEATHER_WINTER if stage == STAGE_WINTER else HEATHER_LEAF
	for s in 10:
		var ang := TAU * float(s) / 10.0 + rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(ang), 0.0, sin(ang))
		var base := out * rng.randf_range(0.0, 0.08)
		var h := rng.randf_range(0.16, 0.32)
		var knee := base + out * rng.randf_range(0.04, 0.1) + Vector3(0.0, h * 0.35, 0.0)
		_stem(b, base, knee, 0.004, HEATHER_STEM)
		for _k in 2:
			var dir := (out * rng.randf_range(0.3, 0.8) + Vector3.UP).normalized()
			dir = dir.rotated(Vector3.UP, rng.randf_range(-0.5, 0.5))
			var tip := knee + dir * h * rng.randf_range(0.6, 0.75)
			var roll := rng.randf()
			var top := leaf
			if stage == STAGE_FLOWER and roll < 0.85:
				top = HEATHER_FLOWER * (0.9 + 0.2 * roll)
			_cross_card(b, knee, tip, 0.028, leaf * (0.85 + 0.2 * roll), top)


## Crowberry: a dense creeping mat, 8-14 cm, of needle-leaved shoots. Glossy
## black berries from late July into autumn; bronzed dark in winter.
static func _crowberry(b: ForbMeshes.Builder, stage: StringName) -> void:
	_height = 0.14
	var rng := _rng(SPECIES_CROWBERRY)
	var leaf := CROWBERRY_WINTER if stage == STAGE_WINTER else CROWBERRY_LEAF
	var tips: Array[Vector3] = []
	for s in 12:
		var ang := TAU * float(s) / 12.0 + rng.randf_range(-0.25, 0.25)
		var out := Vector3(cos(ang), 0.0, sin(ang))
		var base := out * rng.randf_range(0.0, 0.05)
		var reach := rng.randf_range(0.12, 0.22)
		# Creeping: the shoot runs along the ground and only its end rises.
		var bend := base + out * reach * 0.6 + Vector3(0.0, 0.02, 0.0)
		var tip := base + out * reach + Vector3(0.0, rng.randf_range(0.06, 0.12), 0.0)
		_stem(b, base, bend, 0.003, CROWBERRY_STEM)
		var roll := rng.randf()
		_cross_card(b, bend.lerp(base, 0.4), tip, 0.03, leaf * (0.85 + 0.25 * roll), leaf)
		tips.append(bend.lerp(tip, 0.5))
	if stage == STAGE_FRUIT:
		var adorn := _rng(SPECIES_CROWBERRY, 1)
		for i in 12:
			var t: Vector3 = tips[i]
			_berry(
				b,
				t + Vector3(adorn.randf_range(-0.01, 0.01), 0.004, adorn.randf_range(-0.01, 0.01)),
				0.006,
				CROWBERRY_BERRY
			)


## Cloudberry: a bog herb, single 8-18 cm stems with one or two broad,
## five-lobed kidney leaves. One white flower in late May-June, one berry
## ripening red to amber in July, leaves red-brown in autumn; gone in winter.
static func _cloudberry(b: ForbMeshes.Builder, stage: StringName) -> void:
	_height = 0.18
	var rng := _rng(SPECIES_CLOUDBERRY)
	var leaf := CLOUDBERRY_AUTUMN if stage == STAGE_AUTUMN else CLOUDBERRY_LEAF
	var tops: Array[Vector3] = []
	for s in 4:
		var ang := TAU * float(s) / 4.0 + rng.randf_range(-0.5, 0.5)
		var out := Vector3(cos(ang), 0.0, sin(ang))
		var base := out * rng.randf_range(0.02, 0.12)
		var h := rng.randf_range(0.08, 0.17)
		var top := base + out * 0.015 + Vector3(0.0, h, 0.0)
		_stem(b, base, top, 0.0025, CLOUDBERRY_STEM)
		tops.append(top)
		for k in 2:
			var la := ang + rng.randf_range(-1.2, 1.2)
			var at := base.lerp(top, rng.randf_range(0.55, 0.8))
			var roll := rng.randf()
			if k == 1 and roll < 0.4:
				continue
			_lobed_leaf(b, at, la, rng.randf_range(0.04, 0.055), leaf * (0.9 + 0.2 * roll))
	var adorn := _rng(SPECIES_CLOUDBERRY, 1)
	for i in 2:
		var top: Vector3 = tops[i]
		if stage == STAGE_FLOWER:
			_flower(
				b,
				top + Vector3(0.0, 0.01, 0.0),
				Vector3(0.1, 1.0, 0.0),
				0.016,
				CLOUDBERRY_FLOWER,
				CLOUDBERRY_CORE
			)
		elif stage == STAGE_FRUIT:
			var col := CLOUDBERRY_RED.lerp(CLOUDBERRY_AMBER, adorn.randf_range(0.3, 1.0))
			_berry(b, top + Vector3(0.0, 0.012, 0.0), 0.011, col)
			_berry(b, top + Vector3(0.003, 0.016, 0.002), 0.008, col * 1.05)


## Cranberry: thread-thin creeping stems laid over the moss with tiny leaves.
## Pink reflexed flowers on thread stalks in July, red berries lying on the moss
## from late August that overwinter; leaves red-brown from November to April.
static func _cranberry(b: ForbMeshes.Builder, stage: StringName) -> void:
	_height = 0.06
	var rng := _rng(SPECIES_CRANBERRY)
	var leaf := CRANBERRY_WINTER if stage == STAGE_WINTER else CRANBERRY_LEAF
	var nodes: Array[Vector3] = []
	for s in 6:
		var ang := TAU * float(s) / 6.0 + rng.randf_range(-0.4, 0.4)
		var p := Vector3.ZERO
		for k in 3:
			ang += rng.randf_range(-0.5, 0.5)
			var q := p + Vector3(cos(ang), 0.0, sin(ang)) * rng.randf_range(0.06, 0.1)
			q.y = rng.randf_range(0.008, 0.02)
			_strip(b, p, q, 0.0035, CRANBERRY_STEM)
			var la := ang + (PI * 0.5 if k % 2 == 0 else -PI * 0.5)
			var roll := rng.randf()
			_leaf(
				b,
				p.lerp(q, 0.5),
				Vector3(cos(la), 0.25, sin(la)),
				0.014,
				0.007,
				leaf * (0.9 + 0.2 * roll),
				0.5,
				0.15
			)
			_leaf(b, q, Vector3(cos(-la), 0.25, sin(-la)), 0.012, 0.006, leaf, 0.5, 0.15)
			nodes.append(q)
			p = q
	var adorn := _rng(SPECIES_CRANBERRY, 1)
	if stage == STAGE_FLOWER:
		for i in 5:
			var at: Vector3 = nodes[(i * 3 + 1) % nodes.size()]
			var head := (
				at + Vector3(adorn.randf_range(-0.01, 0.01), 0.05, adorn.randf_range(-0.01, 0.01))
			)
			_stem(b, at, head, 0.0012, CRANBERRY_STEM)
			_flower(b, head, Vector3(0.3, -1.0, 0.0), 0.009, CRANBERRY_FLOWER, CRANBERRY_STEM)
	elif stage in [STAGE_FRUIT, STAGE_WINTER]:
		for i in 6:
			var at: Vector3 = nodes[(i * 3 + 2) % nodes.size()]
			_berry(
				b,
				at + Vector3(adorn.randf_range(-0.015, 0.015), 0.006, 0.0),
				0.0075,
				CRANBERRY_BERRY * adorn.randf_range(0.85, 1.05)
			)


## Bog rosemary: sparse upright stems, 12-25 cm, with narrow grey-blue leaves
## (pale beneath, rolled edges); pink bell clusters at the tips in May-June,
## leaves purplish-bronze in winter.
static func _bog_rosemary(b: ForbMeshes.Builder, stage: StringName) -> void:
	_height = 0.25
	var rng := _rng(SPECIES_BOG_ROSEMARY)
	var leaf := ROSEMARY_WINTER if stage == STAGE_WINTER else ROSEMARY_LEAF
	var tips: Array[Vector3] = []
	for s in 5:
		var ang := TAU * float(s) / 5.0 + rng.randf_range(-0.4, 0.4)
		var out := Vector3(cos(ang), 0.0, sin(ang))
		var base := out * rng.randf_range(0.0, 0.08)
		var h := rng.randf_range(0.12, 0.25)
		# The stem creeps a little through the moss, then turns up.
		var knee := base + out * 0.04 + Vector3(0.0, h * 0.3, 0.0)
		var tip := knee + (out * 0.2 + Vector3.UP).normalized() * h * 0.7
		_stem(b, base, knee, 0.0025, ROSEMARY_STEM)
		_stem(b, knee, tip, 0.002, ROSEMARY_STEM)
		tips.append(tip)
		for li in 7:
			var at := knee.lerp(tip, 0.1 + 0.85 * float(li) / 6.0)
			var la := rng.randf() * TAU
			var roll := rng.randf()
			_leaf(
				b,
				at,
				Vector3(cos(la), rng.randf_range(0.3, 0.9), sin(la)),
				rng.randf_range(0.026, 0.034),
				0.0055,
				leaf * (0.9 + 0.2 * roll),
				0.8,
				0.15
			)
	if stage == STAGE_FLOWER:
		var adorn := _rng(SPECIES_BOG_ROSEMARY, 1)
		for t: Vector3 in tips:
			for k in 3:
				var a := TAU * float(k) / 3.0 + adorn.randf_range(-0.3, 0.3)
				var off := Vector3(cos(a), 0.0, sin(a)) * 0.012
				_stem(b, t, t + off + Vector3(0.0, 0.004, 0.0), 0.001, ROSEMARY_FLOWER * 0.8)
				_bell(
					b,
					t + off,
					Vector3(off.x * 20.0, -1.0, off.z * 20.0),
					0.009,
					0.006,
					ROSEMARY_FLOWER
				)


## Wild strawberry: a rosette, 8-15 cm, of long-stalked trifoliate leaves with
## silky pale undersides. White five-petal flowers in May, small red fruits
## hanging on thin stalks in June-July, leaves partly red in autumn.
static func _wild_strawberry(b: ForbMeshes.Builder, stage: StringName) -> void:
	_height = 0.15
	var rng := _rng(SPECIES_WILD_STRAWBERRY)
	for s in 6:
		var ang := TAU * float(s) / 6.0 + rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(ang), 0.0, sin(ang))
		var h := rng.randf_range(0.07, 0.13)
		var mid := out * 0.03 + Vector3(0.0, h * 0.7, 0.0)
		var top := out * rng.randf_range(0.06, 0.09) + Vector3(0.0, h, 0.0)
		_stem(b, Vector3.ZERO, mid, 0.0018, STRAWBERRY_STALK)
		_stem(b, mid, top, 0.0015, STRAWBERRY_STALK)
		var roll := rng.randf()
		var col := STRAWBERRY_LEAF
		if stage == STAGE_AUTUMN and roll < 0.6:
			col = STRAWBERRY_LEAF.lerp(STRAWBERRY_AUTUMN, 0.5 + roll * 0.8)
		# Three leaflets fanned out from the stalk tip, the middle one longest.
		for k in 3:
			var la := ang + float(k - 1) * 0.75
			var dir := Vector3(cos(la), 0.15, sin(la))
			var length := 0.04 if k == 1 else 0.034
			_leaf(b, top, dir, length, 0.026, col * (0.9 + 0.2 * roll), 0.6, 0.3)
	var adorn := _rng(SPECIES_WILD_STRAWBERRY, 1)
	if stage in [STAGE_FLOWER, STAGE_FRUIT]:
		for i in 3:
			var a := TAU * float(i) / 3.0 + adorn.randf_range(0.0, 1.0)
			var out := Vector3(cos(a), 0.0, sin(a))
			var head := out * 0.05 + Vector3(0.0, adorn.randf_range(0.07, 0.11), 0.0)
			if stage == STAGE_FLOWER:
				_stem(b, Vector3.ZERO, head, 0.0014, STRAWBERRY_STALK)
				_flower(
					b,
					head,
					Vector3(out.x * 0.3, 1.0, out.z * 0.3),
					0.012,
					STRAWBERRY_FLOWER,
					STRAWBERRY_CORE
				)
			else:
				# The stalk bends over under the fruit.
				var hang := head + out * 0.03 + Vector3(0.0, -0.035, 0.0)
				_stem(b, Vector3.ZERO, head, 0.0014, STRAWBERRY_STALK)
				_stem(b, head, hang, 0.0012, STRAWBERRY_STALK)
				_fruit_cone(b, hang, 0.009, 0.014)


## Sphagnum: a low lumpy cushion of peat moss, green with ochre and red-brown
## patches (the hummock colours of a raised bog).
static func _sphagnum(b: ForbMeshes.Builder) -> void:
	_height = 0.1
	var rng := _rng(SPECIES_SPHAGNUM)
	var segs := 14
	var profile := [[0.42, -0.02], [0.38, 0.03], [0.28, 0.07], [0.14, 0.09], [0.0, 0.1]]
	var rows: Array = []
	for ring: Array in profile:
		var row: Array[int] = []
		for i in segs:
			var a := TAU * float(i) / float(segs)
			var r := float(ring[0]) * (1.0 + rng.randf_range(-0.2, 0.2))
			var y := float(ring[1]) + rng.randf_range(-0.012, 0.012)
			var roll := rng.randf()
			var col := SPHAGNUM_GREEN
			if roll < 0.3:
				col = SPHAGNUM_OCHRE
			elif roll < 0.45:
				col = SPHAGNUM_RED
			row.append(
				b.vertex(
					Vector3(cos(a) * r, y, sin(a) * r),
					col * (0.9 + 0.2 * rng.randf()),
					0.0,
					0.0,
					0.05
				)
			)
			if float(ring[0]) == 0.0:
				break
		rows.append(row)
	for k in rows.size() - 1:
		var lo: Array[int] = rows[k]
		var hi: Array[int] = rows[k + 1]
		for i in segs:
			var j := (i + 1) % segs
			if hi.size() == 1:
				b.tri(lo[i], lo[j], hi[0], Vector3.UP)
			else:
				b.quad(lo[i], lo[j], hi[j], hi[i], Vector3.UP)


# --- geometry helpers -------------------------------------------------------


static func _flex(p: Vector3) -> float:
	return clampf(p.y / _height, 0.0, 1.2)


## Point at fraction `t` along a polyline.
static func _along(pts: Array[Vector3], t: float) -> Vector3:
	var f := clampf(t, 0.0, 1.0) * float(pts.size() - 1)
	var i := mini(floori(f), pts.size() - 2)
	return pts[i].lerp(pts[i + 1], f - float(i))


## Three-sided twig from `a` to `c` (6 triangles), tapering a little.
static func _stem(b: ForbMeshes.Builder, a: Vector3, c: Vector3, r: float, col: Color) -> void:
	var axis := (c - a).normalized()
	var ref := Vector3.RIGHT if absf(axis.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var u := axis.cross(ref).normalized()
	var v := axis.cross(u)
	var lo: Array[int] = []
	var hi: Array[int] = []
	for i in 3:
		var ang := TAU * float(i) / 3.0
		var off := u * cos(ang) + v * sin(ang)
		lo.append(b.vertex(a + off * r, col * 0.9, _flex(a), 0.0, 0.1))
		hi.append(b.vertex(c + off * r * 0.7, col, _flex(c), 0.0, 0.1))
	for i in 3:
		var j := (i + 1) % 3
		var ang := TAU * (float(i) + 0.5) / 3.0
		b.quad(lo[i], lo[j], hi[j], hi[i], u * cos(ang) + v * sin(ang))


## Flat strip lying on the ground (creeping cranberry runner), 2 triangles.
static func _strip(b: ForbMeshes.Builder, a: Vector3, c: Vector3, w: float, col: Color) -> void:
	var side := (c - a).cross(Vector3.UP).normalized() * w * 0.5
	var i0 := b.vertex(a - side, col, _flex(a), 0.0, 0.1)
	var i1 := b.vertex(a + side, col, _flex(a), 0.0, 0.1)
	var i2 := b.vertex(c + side, col, _flex(c), 0.0, 0.1)
	var i3 := b.vertex(c - side, col, _flex(c), 0.0, 0.1)
	b.quad(i0, i1, i2, i3, Vector3.UP)


## A simple leaf from `base` along `dir`: a diamond folded on its midrib with the
## tip drooping, upper side facing up (2 triangles).
static func _leaf(
	b: ForbMeshes.Builder,
	base: Vector3,
	dir: Vector3,
	length: float,
	width: float,
	col: Color,
	under: float,
	trans: float
) -> void:
	var d := dir.normalized()
	var ref := Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT
	var side := d.cross(ref).normalized()
	var n := side.cross(d).normalized()
	if n.y < 0.0:
		n = -n
	var mid := base + d * length * 0.45
	var i0 := b.vertex(base, col * 0.92, _flex(base), under, trans)
	var i1 := b.vertex(mid + side * width * 0.5 - n * width * 0.18, col, _flex(mid), under, trans)
	var tip := base + d * length - n * length * 0.12
	var i2 := b.vertex(tip, col * 1.04, _flex(tip), under, trans)
	var i3 := b.vertex(mid - side * width * 0.5 - n * width * 0.18, col, _flex(mid), under, trans)
	b.tri(i0, i1, i2, n)
	b.tri(i0, i2, i3, n)


## Cloudberry leaf: a broad, cupped, five-lobed kidney fan round the petiole
## top, opening toward `ang` (9 triangles).
static func _lobed_leaf(
	b: ForbMeshes.Builder, at: Vector3, ang: float, r: float, col: Color
) -> void:
	var centre := b.vertex(at, col * 0.85, _flex(at), 0.3, 0.3)
	var rim: Array[int] = []
	for i in 10:
		var a := ang - 1.9 + 3.8 * float(i) / 9.0
		# Lobe tips on even vertices, sinuses between them.
		var rr := r * (1.0 if i % 2 == 0 else 0.78)
		var p := at + Vector3(cos(a) * rr, 0.012 + rr * 0.12, sin(a) * rr)
		rim.append(b.vertex(p, col, _flex(p), 0.3, 0.3))
	for i in 9:
		b.tri(centre, rim[i], rim[i + 1], Vector3.UP)


## Crossed narrow cards from `a` to `c` (heather and crowberry sprays): two
## perpendicular tapering strips so the spray holds its mass from any side.
static func _cross_card(
	b: ForbMeshes.Builder, a: Vector3, c: Vector3, w: float, col_a: Color, col_c: Color
) -> void:
	var axis := (c - a).normalized()
	var ref := Vector3.UP if absf(axis.y) < 0.95 else Vector3.RIGHT
	var s1 := axis.cross(ref).normalized()
	var s2 := axis.cross(s1).normalized()
	for side: Vector3 in [s1, s2]:
		var mid := a.lerp(c, 0.55)
		var i0 := b.vertex(a, col_a * 0.8, _flex(a), 0.2, 0.25)
		var i1 := b.vertex(mid + side * w * 0.5, col_a.lerp(col_c, 0.5), _flex(mid), 0.2, 0.25)
		var i2 := b.vertex(c, col_c, _flex(c), 0.2, 0.25)
		var i3 := b.vertex(mid - side * w * 0.5, col_a.lerp(col_c, 0.5), _flex(mid), 0.2, 0.25)
		var facing := side.cross(axis)
		b.tri(i0, i1, i2, facing)
		b.tri(i0, i2, i3, facing)


## Octahedral berry (8 triangles).
static func _berry(b: ForbMeshes.Builder, c: Vector3, r: float, col: Color) -> void:
	var axes := [
		Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD
	]
	var ids: Array[int] = []
	for ax: Vector3 in axes:
		var shade := 1.12 if ax == Vector3.UP else (0.8 if ax == Vector3.DOWN else 1.0)
		ids.append(b.vertex(c + ax * r, col * shade, _flex(c), 0.0, 0.05))
	for x in [0, 1]:
		for y in [2, 3]:
			for z in [4, 5]:
				var facing: Vector3 = axes[x] + axes[y] + axes[z]
				b.tri(ids[x], ids[y], ids[z], facing)


## Open five-sided bell hanging from `attach` along `axis` (5 triangles).
static func _bell(
	b: ForbMeshes.Builder, attach: Vector3, axis: Vector3, length: float, radius: float, col: Color
) -> void:
	var d := axis.normalized()
	var ref := Vector3.RIGHT if absf(d.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var u := d.cross(ref).normalized()
	var v := d.cross(u)
	var apex := b.vertex(attach, col * 0.85, _flex(attach), 0.0, 0.4)
	var rim: Array[int] = []
	for i in 5:
		var a := TAU * float(i) / 5.0
		var p := attach + d * length + (u * cos(a) + v * sin(a)) * radius
		rim.append(b.vertex(p, col, _flex(p), 0.0, 0.4))
	for i in 5:
		var a := TAU * (float(i) + 0.5) / 5.0
		b.tri(apex, rim[i], rim[(i + 1) % 5], u * cos(a) + v * sin(a))


## Five-petal open flower facing `normal` (10 triangles).
static func _flower(
	b: ForbMeshes.Builder, centre: Vector3, normal: Vector3, r: float, petal: Color, core: Color
) -> void:
	var n := normal.normalized()
	var ref := Vector3.RIGHT if absf(n.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var u := n.cross(ref).normalized()
	var v := n.cross(u)
	var mid := b.vertex(centre + n * r * 0.1, core, _flex(centre), 0.0, 0.45)
	var tips: Array[int] = []
	var notches: Array[int] = []
	for i in 5:
		var a := TAU * float(i) / 5.0
		var t := centre + (u * cos(a) + v * sin(a)) * r
		var na := a + PI / 5.0
		var q := centre + (u * cos(na) + v * sin(na)) * r * 0.45
		tips.append(b.vertex(t, petal, _flex(t), 0.0, 0.45))
		notches.append(b.vertex(q, petal * 0.95, _flex(q), 0.0, 0.45))
	for i in 5:
		b.tri(mid, notches[(i + 4) % 5], tips[i], n)
		b.tri(mid, tips[i], notches[i], n)


## Hanging strawberry: a red cone under a green calyx star (10 triangles).
static func _fruit_cone(b: ForbMeshes.Builder, top: Vector3, r: float, length: float) -> void:
	var tip := b.vertex(
		top + Vector3(0.0, -length, 0.0), STRAWBERRY_FRUIT * 0.85, _flex(top), 0.0, 0.1
	)
	var ring: Array[int] = []
	var calyx: Array[int] = []
	for i in 5:
		var a := TAU * float(i) / 5.0
		var off := Vector3(cos(a), 0.0, sin(a))
		ring.append(
			b.vertex(
				top + off * r + Vector3(0.0, -length * 0.25, 0.0),
				STRAWBERRY_FRUIT,
				_flex(top),
				0.0,
				0.1
			)
		)
		calyx.append(
			b.vertex(
				top + off.rotated(Vector3.UP, PI / 5.0) * r * 1.4,
				STRAWBERRY_CALYX,
				_flex(top),
				0.0,
				0.2
			)
		)
	var hub := b.vertex(top, STRAWBERRY_CALYX, _flex(top), 0.0, 0.2)
	for i in 5:
		var j := (i + 1) % 5
		var a := TAU * (float(i) + 0.5) / 5.0
		b.tri(ring[i], ring[j], tip, Vector3(cos(a), -0.3, sin(a)))
		b.tri(hub, calyx[i], ring[j], Vector3.UP)
