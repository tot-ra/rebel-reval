class_name VesselFleet
extends RefCounted

## The small working craft of the 1343 coast (CO-06, task R-953): five lofted
## clinker designs in true metres, each built to a card of
## docs/reports/baltic_vessels_1343.md (V2-V6; the V1 cog is CogModel), with
## deterministic wear, load and rig variants so no two boats on a shore match.
##
## A built vessel is a Node3D whose origin is the keel amidships (+X bow, +Z
## starboard). Named sub-nodes are the CO-07 contract: Hull, Mast, Yard, Sail,
## FurledSail, Sheet, Brace, Halyard, Shroud*, Oar*, Rudder, Tiller,
## MooringLine*, Pennant, Load. Ropes use the cog rope shader and sails the cog
## sail shader, so wind already reaches them without CPU simulation.
##
## Dimensions: see DESIGNS. Where a CO-05 card lists a field as unknown, the
## value comes from the R-953 comparanda addendum of that report (Bill 1998
## small boat ratio, Gedesby, Slavia, the lodi handbook) and is labelled there.

const WEAR_FRESH_TAR := &"fresh_tar"
const WEAR_WEATHERED := &"weathered"
const WEAR_PATCHED := &"patched"
const WEARS: Array[StringName] = [WEAR_FRESH_TAR, WEAR_WEATHERED, WEAR_PATCHED]

const LOAD_EMPTY := &"empty"
const LOAD_NETS := &"nets"
const LOAD_BASKETS := &"fish_baskets"
const LOAD_CARGO := &"cargo"

const FISHING_SMALL := &"fishing_boat_small"
const FISHING_LARGE := &"fishing_boat_large"
const ROWING_OPEN := &"rowing_boat_open"
const LIGHTER_LODJA := &"lighter_lodja"
const STRAIT_CRAFT := &"strait_craft_saaremaa"

## Sub-nodes every rigged hull exposes (CO-07 drives them).
const RIG_NODES: Array[String] = [
	"Hull", "Mast", "Yard", "Sail", "Sheet", "Brace", "Halyard", "Shroud0", "Shroud1",
	"Oar0", "Rudder", "Tiller", "MooringLine0", "Pennant",
]
## Sub-nodes of an unrigged rowing hull.
const ROW_NODES: Array[String] = ["Hull", "Oar0", "Rudder", "Tiller", "MooringLine0"]

const SAIL_COLS := 10
const SAIL_ROWS := 8
## Ropes, oars, pennants and load are invisible beyond this (cheap LOD; the hull
## and mast still read as a boat from the far shore).
const DETAIL_RANGE := 140.0

## design -> card (metres). `card` names the baltic_vessels_1343.md entry.
## length/beam/depth: hull over the stems, at the sheer amidships, keel to sheer.
## draught: still-water keel depth afloat. strakes: lapped side strakes.
## bottom: section exponent (higher = flatter floor), bilge: width exponent
## (lower = fuller bilge). rise: sheer lift at the stems. mast: height above the
## keel, 0 for unrigged. yard_half / sail_depth: square sail. oars: oar count.
## loads: allowed load dressings. tar_bias: share of hulls tarred dark.
const DESIGNS := {
	FISHING_SMALL: {
		"card": "V2", "length": 6.0, "beam": 2.07, "depth": 0.82, "draught": 0.32,
		"strakes": 6, "bottom": 1.7, "bilge": 0.7, "rise": 0.42, "mast": 4.8,
		"yard_half": 1.6, "sail_depth": 2.6, "oars": 4, "oar_length": 3.2,
		"loads": [LOAD_EMPTY, LOAD_NETS, LOAD_BASKETS],
	},
	FISHING_LARGE: {
		"card": "V3", "length": 9.0, "beam": 3.74, "depth": 1.15, "draught": 0.45,
		"strakes": 8, "bottom": 1.9, "bilge": 0.66, "rise": 0.55, "mast": 7.2,
		"yard_half": 2.4, "sail_depth": 3.9, "oars": 6, "oar_length": 4.2,
		"loads": [LOAD_EMPTY, LOAD_NETS, LOAD_BASKETS, LOAD_CARGO],
	},
	ROWING_OPEN: {
		"card": "V4", "length": 6.5, "beam": 2.26, "depth": 0.88, "draught": 0.3,
		"strakes": 5, "bottom": 1.6, "bilge": 0.74, "rise": 0.38, "mast": 0.0,
		"yard_half": 0.0, "sail_depth": 0.0, "oars": 4, "oar_length": 3.4,
		"loads": [LOAD_EMPTY, LOAD_BASKETS, LOAD_CARGO],
	},
	LIGHTER_LODJA: {
		"card": "V5", "length": 10.5, "beam": 5.4, "depth": 1.6, "draught": 0.8,
		"strakes": 7, "bottom": 2.6, "bilge": 0.5, "rise": 0.35, "mast": 11.8,
		"yard_half": 4.2, "sail_depth": 6.6, "oars": 2, "oar_length": 6.0,
		"loads": [LOAD_CARGO, LOAD_EMPTY],
	},
	STRAIT_CRAFT: {
		"card": "V6", "length": 6.8, "beam": 2.36, "depth": 0.93, "draught": 0.34,
		"strakes": 6, "bottom": 1.7, "bilge": 0.68, "rise": 0.6, "mast": 5.4,
		"yard_half": 1.8, "sail_depth": 2.9, "oars": 4, "oar_length": 3.4,
		"loads": [LOAD_EMPTY, LOAD_CARGO, LOAD_NETS],
	},
}

const STATIONS := 22
const LAP := 0.022
const PLANK_WOOD := Color(1.0, 0.9, 0.76)
const TAR := Color(0.36, 0.3, 0.25)
## Sun-silvered oak (the hull material multiplies by its own warm albedo).
const SILVER := Color(0.9, 0.9, 0.88)
const WATER_STAIN := Color(0.62, 0.7, 0.56)
const HEMP := Color(0.66, 0.55, 0.38)
const NET := Color(0.3, 0.24, 0.17)
const WICKER := Color(0.7, 0.58, 0.36)
const SACK := Color(0.74, 0.66, 0.5)

static var _hulls: Dictionary = {}
static var _sails: Dictionary = {}
## Fitting meshes (oars, spars, ropes, rudder) shared by every boat of a design.
static var _fittings: Dictionary = {}
static var _sail_materials: Dictionary = {}
static var _plain: StandardMaterial3D
static var _canvas: StandardMaterial3D


static func designs() -> Array:
	return DESIGNS.keys()


static func spec(design: StringName) -> Dictionary:
	return DESIGNS[design]


static func is_rigged(design: StringName) -> bool:
	return float(DESIGNS[design]["mast"]) > 0.0


## Deterministic variant of a stable prop/boat id on a map seed. Same inputs,
## same boat, on every load and every machine.
static func variant_for(
	design: StringName, map_seed: int, prop_id: String, hauled := false
) -> Dictionary:
	var h := stable_hash("%d:%s" % [map_seed, prop_id])
	var loads: Array = DESIGNS[design]["loads"]
	return {
		"design": design,
		"wear": WEARS[h % WEARS.size()],
		"load": loads[(h >> 8) % loads.size()],
		"hauled": hauled,
		"phase": float(h % 6283) / 1000.0,
	}


## Which fishing design a generic `fishing_boat` slot gets: mostly the small
## boat, about one in three the larger mündrik boat.
static func fishing_design_for(map_seed: int, prop_id: String) -> StringName:
	var h := stable_hash("design:%d:%s" % [map_seed, prop_id])
	return FISHING_LARGE if h % 3 == 0 else FISHING_SMALL


## Short key of what a variant looks like; two boats with the same key are
## visually identical.
static func appearance_key(variant: Dictionary) -> String:
	return "%s/%s/%s" % [variant["design"], variant["wear"], variant["load"]]


## (half length, half beam) of the hull mesh itself, so BoatFloat3D and the
## collision capsule span the real hull of each design.
static func hull_half_extents(design: StringName) -> Vector2:
	var box := hull_mesh(design, WEAR_FRESH_TAR).get_aabb()
	return Vector2(box.size.x * 0.5, box.size.z * 0.5)


## Usable floor of an open hull: (half length, half beam, floor height above keel).
static func deck(design: StringName) -> Vector3:
	var s: Dictionary = DESIGNS[design]
	return Vector3(
		float(s["length"]) * 0.36, float(s["beam"]) * 0.36, _floor_y(s)
	)


static func draught(design: StringName) -> float:
	return float(DESIGNS[design]["draught"])


## A finished vessel. `variant` comes from variant_for(). Afloat hulls are
## lowered by their draught by the caller (origin = keel).
static func build(variant: Dictionary) -> Node3D:
	var design: StringName = variant["design"]
	var s: Dictionary = DESIGNS[design]
	var root := Node3D.new()
	root.name = "Vessel_%s" % design
	root.set_meta(&"design", design)
	root.set_meta(&"appearance", appearance_key(variant))
	var hull := MeshInstance3D.new()
	hull.name = "Hull"
	hull.mesh = hull_mesh(design, variant["wear"])
	hull.material_override = CogModel.wood_material()
	root.add_child(hull)
	_add_oars(root, s)
	_add_rudder(root, s)
	if is_rigged(design):
		_add_rig(root, design, s)
	_add_moorings(root, s, bool(variant["hauled"]))
	_add_load(root, s, variant["load"], int(float(variant["phase"]) * 1000.0))
	return root


## Show the set sail instead of the furled bundle (a boat under way; plates).
static func set_sail(vessel: Node3D, sail_set: bool) -> void:
	var yard := vessel.get_node_or_null("Mast/Yard")
	if yard == null:
		return
	(yard.get_node("Sail") as Node3D).visible = sail_set
	(yard.get_node("FurledSail") as Node3D).visible = not sail_set


## Hull flipped keel-up on two trestles (boatwright ground, net yards).
static func overturned(design: StringName, wear: StringName) -> Node3D:
	var s: Dictionary = DESIGNS[design]
	var root := Node3D.new()
	root.name = "OverturnedBoat"
	var hull := MeshInstance3D.new()
	hull.name = "Hull"
	hull.mesh = hull_mesh(design, wear)
	hull.material_override = CogModel.wood_material()
	var depth := float(s["depth"])
	hull.rotation.z = PI
	hull.position.y = depth + float(s["rise"]) * 0.3 + 0.55
	root.add_child(hull)
	var parts := CogParts.new()
	for x: float in [-float(s["length"]) * 0.25, float(s["length"]) * 0.25]:
		parts.box(Vector3(x, 0.3, 0.0), Vector3(0.18, 0.6, float(s["beam"]) * 0.8), TAR * 1.4)
	_add_mesh(root, "Trestles", parts, CogModel.wood_material(), false, "trestles:%s" % s["card"])
	return root


# --- hull loft ---------------------------------------------------------------


static func _floor_y(s: Dictionary) -> float:
	return float(s["depth"]) * 0.22


static func _half_beam(s: Dictionary, u: float) -> float:
	# u: 0 amidships .. 1 at the stems. Fine ends, full working middle.
	return float(s["beam"]) * 0.5 * pow(maxf(1.0 - pow(u, 2.4), 0.0), 0.6)


static func _sheer(s: Dictionary, u: float) -> float:
	return float(s["depth"]) + float(s["rise"]) * pow(u, 2.2)


static func _keel(s: Dictionary, u: float) -> float:
	# A little rocker so the ends lift off the beach.
	return float(s["rise"]) * 0.35 * pow(u, 3.0)


## Point on the starboard skin. t: 0 stern .. 1 bow; a: 0 keel .. 1 sheer.
static func _point(s: Dictionary, t: float, a: float) -> Vector3:
	var u := absf(t * 2.0 - 1.0)
	var x := (t - 0.5) * float(s["length"])
	var w := _half_beam(s, u) * pow(sin(a * PI * 0.5), float(s["bilge"]))
	var keel := _keel(s, u)
	var y := keel + (_sheer(s, u) - keel) * pow(a, float(s["bottom"]))
	return Vector3(x, y, w)


static func _normal(s: Dictionary, t: float, a: float) -> Vector3:
	var e := 0.002
	var dt := _point(s, minf(t + e, 1.0), a) - _point(s, maxf(t - e, 0.0), a)
	var da := _point(s, t, minf(a + e, 1.0)) - _point(s, t, maxf(a - e, 0.0))
	var n := dt.cross(da)
	if n.length() < 0.000001:
		return Vector3(0, -1, 0) if a < 0.5 else Vector3(0, 0, 1)
	return n.normalized()


static func _station(i: int) -> float:
	return 0.5 - 0.5 * cos(PI * float(i) / STATIONS)


static func _plank_tone(
	wear: StringName, strake: int, plank: int, y: float, s: Dictionary
) -> Color:
	var jitter := 0.9 + 0.16 * _hash01(strake * 31 + plank * 7, 3)
	var c := PLANK_WOOD * jitter
	var waterline := float(s["draught"])
	match wear:
		WEAR_FRESH_TAR:
			# Freshly tarred all over: dark, a little glossy-looking.
			c = TAR * (0.9 + 0.2 * _hash01(strake, plank))
		WEAR_WEATHERED:
			# Tar kept below the wale, sun-silvered planks above.
			c = TAR.lerp(c.lerp(SILVER, 0.65), smoothstep(waterline, waterline + 0.35, y))
		WEAR_PATCHED:
			c = TAR.lerp(c.lerp(SILVER, 0.45), smoothstep(waterline + 0.15, waterline + 0.5, y))
			# Replaced planks: raw new wood, one or two runs per side.
			if _hash01(strake * 13 + plank, 11) > 0.86:
				c = Color(1.0, 0.86, 0.62)
	# Wet weed stain just under the waterline.
	var wet := 1.0 - smoothstep(waterline - 0.25, waterline + 0.05, y)
	c = c.lerp(c * WATER_STAIN, wet * 0.6)
	c.a = 1.0
	return c


## Lofted clinker hull with lapped strakes, inner skin, gunwale, keel, posts,
## thwarts and floorboards. Cached per (design, wear): every boat of a variant
## shares one mesh resource.
static func hull_mesh(design: StringName, wear: StringName) -> ArrayMesh:
	var key := "%s/%s" % [design, wear]
	if _hulls.has(key):
		return _hulls[key]
	var s: Dictionary = DESIGNS[design]
	var parts := CogParts.new()
	var strakes := int(s["strakes"])
	var plank_len := 5
	for side: float in [1.0, -1.0]:
		for i in STATIONS:
			var t0 := _station(i)
			var t1 := _station(i + 1)
			for b in strakes:
				var a0 := float(b) / strakes
				var a1 := float(b + 1) / strakes
				var plank := (i + b * 2) / plank_len
				var c: Array[Vector3] = []
				var n: Array[Vector3] = []
				var uv: Array[Vector2] = []
				for k: Array in [[t0, a0, 0.0], [t1, a0, 0.0], [t1, a1, 1.0], [t0, a1, 1.0]]:
					var p := _point(s, k[0], k[1])
					var nn := _normal(s, k[0], k[1])
					# Lower edge of each strake proud by LAP, flush at its upper edge.
					p += nn * LAP * (1.0 - float(k[2])) * (1.0 if b > 0 else 0.0)
					c.append(Vector3(p.x, p.y, p.z * side))
					n.append(Vector3(nn.x, nn.y, nn.z * side))
					uv.append(Vector2(p.x / 2.2 + 0.37 * b, float(k[2])))
				if side < 0.0:
					c.reverse()
					n.reverse()
					uv.reverse()
				var mid_y := (c[0].y + c[2].y) * 0.5
				var tone := _plank_tone(wear, b, plank + (0 if side > 0.0 else 17), mid_y, s)
				parts.smooth_quad(c, n, uv, tone)
				# Inner skin: same loft, pushed in, faces reversed, darker.
				var ci: Array[Vector3] = []
				var ni: Array[Vector3] = []
				for idx in 4:
					ci.append(c[idx] - n[idx] * 0.03)
					ni.append(-n[idx])
				ci.reverse()
				ni.reverse()
				var uvi := uv.duplicate()
				uvi.reverse()
				parts.smooth_quad(ci, ni, uvi, tone.darkened(0.25))
			# Gunwale cap closing the two skins.
			var g0 := _point(s, t0, 1.0)
			var g1 := _point(s, t1, 1.0)
			parts.beam(
				Vector3(g0.x, g0.y + 0.02, g0.z * side),
				Vector3(g1.x, g1.y + 0.02, g1.z * side),
				0.07,
				0.05,
				TAR * 1.6 if wear != WEAR_FRESH_TAR else TAR
			)
	_add_backbone(parts, s, wear)
	_add_interior(parts, s, wear)
	var mesh := parts.commit()
	_hulls[key] = mesh
	return mesh


static func _add_backbone(parts: CogParts, s: Dictionary, wear: StringName) -> void:
	var tone := TAR if wear == WEAR_FRESH_TAR else TAR * 1.25
	var steps := 12
	for i in steps:
		var t0 := float(i) / steps
		var t1 := float(i + 1) / steps
		parts.beam(
			_point(s, t0, 0.0) + Vector3(0, -0.05, 0),
			_point(s, t1, 0.0) + Vector3(0, -0.05, 0),
			0.11,
			0.12,
			tone
		)
	# Stem and sternpost: the ends rise a hand above the sheer.
	for t: float in [0.0, 1.0]:
		var foot := _point(s, t, 0.0)
		var head := _point(s, t, 1.0) + Vector3(signf(t - 0.5) * 0.12, 0.22, 0.0)
		parts.beam(foot, head, 0.1, 0.12, tone)


static func _add_interior(parts: CogParts, s: Dictionary, wear: StringName) -> void:
	var length := float(s["length"])
	var floor_y := _floor_y(s)
	var board := PLANK_WOOD * (0.62 if wear == WEAR_FRESH_TAR else 0.8)
	parts.box(
		Vector3(0.0, floor_y, 0.0),
		Vector3(length * 0.66, 0.035, _half_beam(s, 0.0) * 0.95),
		board
	)
	# Thwarts at the oar stations; the forward one carries the mast partner.
	for k in _thwart_stations(s):
		var x := float(k) * length
		var t := 0.5 + float(k)
		var half := _point(s, t, 0.86).z
		var y := _point(s, t, 0.86).y - 0.05
		parts.box(Vector3(x, y, 0.0), Vector3(0.22, 0.05, half * 2.0), board * 0.95)
	# Frames (ribs) seen from above, every ~0.9 m.
	var ribs := int(length / 0.9)
	for r in ribs:
		var t := 0.12 + 0.76 * float(r) / maxf(ribs - 1, 1)
		var prev := _point(s, t, 0.08) - Vector3(0, 0, 0.04)
		for k in range(1, 6):
			var a := 0.08 + 0.92 * float(k) / 5.0
			var p := _point(s, t, a) - _normal(s, t, a) * 0.05
			for side: float in [1.0, -1.0]:
				parts.beam(
					Vector3(prev.x, prev.y, prev.z * side),
					Vector3(p.x, p.y, p.z * side),
					0.05,
					0.05,
					board * 0.7
				)
			prev = p


## Thwart positions as fractions of length from amidships.
static func _thwart_stations(s: Dictionary) -> Array[float]:
	if float(s["length"]) >= 9.0:
		return [-0.28, -0.1, 0.08, 0.24]
	return [-0.22, 0.0, 0.2]


# --- fittings ----------------------------------------------------------------


static func _plain_material() -> StandardMaterial3D:
	if _plain == null:
		_plain = StandardMaterial3D.new()
		_plain.vertex_color_use_as_albedo = true
		_plain.roughness = 0.92
	return _plain


static func _canvas_material() -> StandardMaterial3D:
	if _canvas == null:
		_canvas = StandardMaterial3D.new()
		_canvas.vertex_color_use_as_albedo = true
		_canvas.roughness = 0.95
		_canvas.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _canvas


## `cache_key` shares the committed mesh between boats whose fitting is identical
## (same design and pose); `parts` may then be null.
static func _add_mesh(
	parent: Node3D,
	node_name: String,
	parts: CogParts,
	material: Material,
	detail := false,
	cache_key := ""
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	if cache_key.is_empty():
		instance.mesh = parts.commit()
	else:
		if not _fittings.has(cache_key):
			_fittings[cache_key] = parts.commit()
		instance.mesh = _fittings[cache_key]
	instance.material_override = material
	if detail:
		instance.visibility_range_end = DETAIL_RANGE
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


## Oars lie shipped along the thwarts (beached or moored). Each is its own node
## pivoting at its thole so CO-07 can swing it out to row.
static func _add_oars(root: Node3D, s: Dictionary) -> void:
	var count := int(s["oars"])
	var length := float(s["oar_length"])
	var gun_y := float(s["depth"]) * 0.92
	for i in count:
		var side := 1.0 if i % 2 == 0 else -1.0
		var pair := i / 2
		var x := (float(pair) - (count / 2 - 1) * 0.5) * 1.1 - 0.4
		var half := _half_beam(s, absf(x) / (float(s["length"]) * 0.5))
		var pivot := Node3D.new()
		pivot.name = "Oar%d" % i
		pivot.position = Vector3(x, gun_y, side * (half - 0.12))
		root.add_child(pivot)
		var parts := CogParts.new()
		# Loom along the pivot's +X: shipped fore-and-aft, blade forward.
		parts.tube(
			Vector3(-length * 0.32, 0, 0), Vector3(length * 0.5, 0, 0), 0.035, 0.03, 6,
			PLANK_WOOD * 0.8
		)
		parts.box(
			Vector3(length * 0.58, 0, 0), Vector3(length * 0.22, 0.02, 0.13), PLANK_WOOD * 0.75
		)
		_add_mesh(pivot, "Shaft", parts, CogModel.wood_material(), true, "oar:%s" % s["card"])


## Side rudder (steering oar) on the starboard quarter: the conservative small-boat
## default of the CO-05 cards. "Rudder" yaws about its stock; "Tiller" sits on it.
static func _add_rudder(root: Node3D, s: Dictionary) -> void:
	var length := float(s["length"])
	var depth := float(s["depth"])
	var t := 0.1
	var at := _point(s, t, 1.0)
	var rudder := Node3D.new()
	rudder.name = "Rudder"
	rudder.position = Vector3(at.x, at.y, at.z + 0.1)
	root.add_child(rudder)
	var blade := CogParts.new()
	var blade_len := depth + 0.6 + length * 0.04
	blade.tube(Vector3(0, 0.25, 0), Vector3(-0.15, -blade_len * 0.45, 0), 0.05, 0.05, 6, TAR * 1.5)
	blade.box(
		Vector3(-0.22, -blade_len * 0.62, 0),
		Vector3(0.38 + length * 0.02, blade_len * 0.55, 0.05),
		TAR * 1.4
	)
	_add_mesh(rudder, "Blade", blade, CogModel.wood_material(), false, "blade:%s" % s["card"])
	var tiller := Node3D.new()
	tiller.name = "Tiller"
	tiller.position = Vector3(0, 0.22, 0)
	tiller.rotation.y = 1.25
	rudder.add_child(tiller)
	var bar := CogParts.new()
	bar.tube(Vector3.ZERO, Vector3(0.6 + length * 0.05, 0.04, 0), 0.025, 0.02, 5, PLANK_WOOD * 0.8)
	_add_mesh(tiller, "Bar", bar, CogModel.wood_material(), true, "tiller:%s" % s["card"])


## Single mast and square sail on one yard (the cards' Baltic default), with
## sheet, brace, halyard and a shroud a side. The sail is a SAIL_COLS x SAIL_ROWS
## sheet on the cog sail shader; moored and beached it is furled on the yard.
static func _add_rig(root: Node3D, design: StringName, s: Dictionary) -> void:
	var length := float(s["length"])
	var mast_h := float(s["mast"])
	var yard_half := float(s["yard_half"])
	var mast_x := length * 0.12
	var floor_y := _floor_y(s)
	var mast := Node3D.new()
	mast.name = "Mast"
	mast.position = Vector3(mast_x, floor_y, 0.0)
	root.add_child(mast)
	var spar := CogParts.new()
	spar.tube(
		Vector3.ZERO, Vector3(0, mast_h - floor_y, 0), 0.05 + length * 0.006, 0.035, 7,
		PLANK_WOOD * 0.85
	)
	_add_mesh(mast, "Spar", spar, CogModel.wood_material(), false, "mast:%s" % s["card"])
	var yard_y := mast_h - floor_y - 0.35
	var yard := Node3D.new()
	yard.name = "Yard"
	yard.position = Vector3(0.12, yard_y, 0.0)
	mast.add_child(yard)
	var yard_parts := CogParts.new()
	yard_parts.tube(
		Vector3(0, 0, -yard_half), Vector3(0, 0, yard_half), 0.035, 0.035, 6, PLANK_WOOD * 0.8
	)
	_add_mesh(yard, "Spar", yard_parts, CogModel.wood_material(), false, "yard:%s" % s["card"])
	var sail := MeshInstance3D.new()
	sail.name = "Sail"
	sail.mesh = sail_mesh(design)
	sail.material_override = _sail_material(design)
	sail.extra_cull_margin = 2.0
	sail.visible = false
	yard.add_child(sail)
	var furled := CogParts.new()
	for i in 6:
		var z0 := lerpf(-yard_half * 0.92, yard_half * 0.92, float(i) / 6.0)
		var z1 := lerpf(-yard_half * 0.92, yard_half * 0.92, float(i + 1) / 6.0)
		var r := 0.09 + 0.03 * _hash01(i, 5) + yard_half * 0.012
		furled.tube(
			Vector3(0.03, -0.12, z0), Vector3(0.03, -0.13, z1), r, r * 0.9, 6,
			Color(0.7, 0.66, 0.56)
		)
	_add_mesh(yard, "FurledSail", furled, _canvas_material(), false, "furled:%s" % s["card"])
	# Pennant: a plain streamer at the masthead (no heraldry on working craft).
	var pennant := CogParts.new()
	var top := mast_h - floor_y
	pennant.quad(
		Vector3(0, top + 0.05, 0), Vector3(-0.7, top - 0.02, 0),
		Vector3(-0.7, top - 0.06, 0), Vector3(0, top - 0.17, 0),
		Vector3(0, 0, 1), Color(0.62, 0.2, 0.16)
	)
	_add_mesh(mast, "Pennant", pennant, _canvas_material(), true, "pennant:%s" % s["card"])
	# Running and standing rigging, one node each (hull frame).
	var head := Vector3(mast_x + 0.06, mast_h - 0.1, 0.0)
	var yard_end_port := Vector3(mast_x + 0.12, mast_h - 0.35, -yard_half)
	var yard_end_star := Vector3(mast_x + 0.12, mast_h - 0.35, yard_half)
	var gun_y := float(s["depth"])
	var aft := _point(s, 0.18, 1.0)
	var mid := _point(s, 0.5 + mast_x / length, 1.0)
	var foot_star := Vector3(mast_x + 0.1, mast_h - 0.35 - float(s["sail_depth"]), yard_half * 0.9)
	_rope(root, "Halyard", head, Vector3(mast_x - 0.15, floor_y + 0.6, 0.15), 0.02)
	_rope(root, "Sheet", foot_star, Vector3(aft.x, gun_y, aft.z * 0.9), 0.12)
	_rope(root, "Brace", yard_end_port, Vector3(aft.x - 0.3, gun_y, -aft.z * 0.9), 0.25)
	_rope(root, "Shroud0", head, Vector3(mid.x - 0.25, mid.y, mid.z), 0.04)
	_rope(root, "Shroud1", head, Vector3(mid.x - 0.25, mid.y, -mid.z), 0.04)
	_rope(root, "Lift", head, yard_end_star, 0.05)


static func _rope(root: Node3D, node_name: String, a: Vector3, b: Vector3, slack: float) -> void:
	# Same design and pose give the same end points, so the key is the geometry.
	var key := "rope:%s:%s:%s" % [a, b, slack]
	var parts: CogParts = null
	if not _fittings.has(key):
		parts = CogParts.new()
		parts.rope(a, b, 0.012, slack, HEMP)
	var line := _add_mesh(root, node_name, parts, CogRig.rope_material(), true, key)
	line.extra_cull_margin = 1.5


## Square sail of `design`: SAIL_COLS x SAIL_ROWS cloth in the yard's frame
## (plane x = 0, head at y = 0, hanging to -sail_depth). UV contract matches
## CogRig.sail_mesh() so the cog sail shader fills it.
static func sail_mesh(design: StringName) -> ArrayMesh:
	if _sails.has(design):
		return _sails[design]
	var s: Dictionary = DESIGNS[design]
	var head_half := float(s["yard_half"]) * 0.94
	var foot_half := head_half * 0.9
	var depth := float(s["sail_depth"])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in SAIL_ROWS:
		for c in SAIL_COLS:
			var corners: Array[Vector2] = [
				Vector2(c, r), Vector2(c + 1, r), Vector2(c + 1, r + 1), Vector2(c, r + 1)
			]
			var pts: Array[Vector3] = []
			var uvs: Array[Vector2] = []
			var tones: Array[Color] = []
			for k in corners:
				var u := k.x / SAIL_COLS
				var v := k.y / SAIL_ROWS
				var half := lerpf(head_half, foot_half, v)
				pts.append(Vector3(0.04, -0.08 - depth * v + 0.06 * sin(PI * u) * v, (u * 2.0 - 1.0) * half))
				uvs.append(Vector2(u, v))
				var cloth := 0.93 + 0.04 * float(int(k.x) % 2)
				tones.append(Color(cloth, cloth * 0.97, cloth * 0.88))
			for idx: int in [0, 2, 1, 0, 3, 2]:
				st.set_color(tones[idx])
				st.set_uv(uvs[idx])
				st.set_normal(Vector3.RIGHT)
				st.add_vertex(pts[idx])
	var mesh := st.commit()
	_sails[design] = mesh
	return mesh


static func _sail_material(design: StringName) -> ShaderMaterial:
	if _sail_materials.has(design):
		return _sail_materials[design]
	var s: Dictionary = DESIGNS[design]
	var material := ShaderMaterial.new()
	material.shader = CogRig.SAIL_SHADER
	material.set_shader_parameter("sail_half", float(s["yard_half"]))
	material.set_shader_parameter("sail_depth", float(s["sail_depth"]))
	# Pocket scales with the cloth: ~0.23 of the cog's yard-to-pocket ratio.
	material.set_shader_parameter("pocket", float(s["yard_half"]) * 0.25)
	_sail_materials[design] = material
	return material


## Bow line (and a stern line afloat). Beached: the bow line runs up the sand to
## a stake. Afloat: both run down to grapnel and stone in the water.
static func _add_moorings(root: Node3D, s: Dictionary, hauled: bool) -> void:
	var length := float(s["length"])
	var stem := _point(s, 1.0, 1.0) + Vector3(0.05, 0.15, 0.0)
	var stern := _point(s, 0.0, 1.0) + Vector3(-0.05, 0.1, 0.0)
	if hauled:
		var stake := stem + Vector3(length * 0.45, -stem.y + 0.4, 0.4)
		_rope(root, "MooringLine0", stem, stake, 0.15)
		var post := CogParts.new()
		post.tube(stake + Vector3(0, -0.5, 0), stake + Vector3(0, 0.15, 0), 0.06, 0.05, 6, TAR * 1.6)
		_add_mesh(root, "MooringStake", post, CogModel.wood_material(), true, "stake:%s" % s["card"])
		return
	var draught := float(s["draught"])
	_rope(root, "MooringLine0", stem, stem + Vector3(length * 0.7, -stem.y + draught - 0.4, 0.0), 0.3)
	var stern_stone := stern + Vector3(-length * 0.6, -stern.y + draught - 0.4, 0.5)
	_rope(root, "MooringLine1", stern, stern_stone, 0.3)


## Nets, fish baskets or cargo on the floorboards. `seed` turns the heap so
## boats with the same load still lie differently.
static func _add_load(root: Node3D, s: Dictionary, load: StringName, seed: int) -> void:
	var load_node := Node3D.new()
	load_node.name = "Load"
	load_node.set_meta(&"load", load)
	root.add_child(load_node)
	if load == LOAD_EMPTY:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var floor_y := _floor_y(s) + 0.02
	var length := float(s["length"])
	var half := _half_beam(s, 0.0)
	var parts := CogParts.new()
	match load:
		LOAD_NETS:
			# A dark tarred net heap aft with a few birch-bark floats on top.
			for i in 7:
				var c := Vector3(
					-length * 0.18 + rng.randf_range(-0.4, 0.4),
					floor_y + 0.12,
					rng.randf_range(-half * 0.4, half * 0.4)
				)
				parts.box(
					c, Vector3(rng.randf_range(0.5, 0.9), rng.randf_range(0.14, 0.26), rng.randf_range(0.4, 0.7)),
					NET * rng.randf_range(0.85, 1.1), Basis(Vector3.UP, rng.randf() * TAU)
				)
			for i in 5:
				parts.box(
					Vector3(
						-length * 0.18 + rng.randf_range(-0.5, 0.5),
						floor_y + 0.3,
						rng.randf_range(-0.4, 0.4)
					),
					Vector3(0.14, 0.05, 0.08), Color(0.9, 0.86, 0.74)
				)
		LOAD_BASKETS:
			var profile: Array[Vector2] = [
				Vector2(0.18, 0.0), Vector2(0.24, 0.12), Vector2(0.26, 0.34), Vector2(0.27, 0.36)
			]
			for i in 4:
				var at := Vector3(
					-length * 0.12 + i * 0.55, floor_y, rng.randf_range(-half * 0.35, half * 0.35)
				)
				parts.lathe(at, profile, 9, WICKER * rng.randf_range(0.85, 1.05))
				# Silver herring heaped in the basket.
				parts.box(at + Vector3(0, 0.33, 0), Vector3(0.3, 0.06, 0.3), Color(0.5, 0.54, 0.56))
		LOAD_CARGO:
			# Sacks forward, barrels handled by the shared barrel mesh.
			for i in 4:
				parts.box(
					Vector3(
						length * 0.16 + rng.randf_range(-0.2, 0.2),
						floor_y + 0.16,
						(float(i % 2) - 0.5) * half * 0.6
					),
					Vector3(0.7, 0.3, 0.42), SACK * rng.randf_range(0.85, 1.05),
					Basis(Vector3.UP, rng.randf_range(-0.3, 0.3))
				)
			var barrels := 2 if length < 9.0 else 5
			for i in barrels:
				MapViewBarrelMeshes.add_barrel(
					load_node,
					"Barrel%d" % i,
					Vector3(-length * 0.1 - (i / 2) * 0.85, floor_y, (float(i % 2) - 0.5) * half * 0.7),
					rng.randf() * TAU
				)
	if parts.vertex_count() > 0:
		_add_mesh(load_node, "Dressing", parts, _plain_material(), true)


# --- helpers -----------------------------------------------------------------


## djb2 over UTF-8 plus an avalanche finaliser: String.hash() is not documented
## as stable across engine versions, and plates must not reshuffle boats on an
## upgrade. Without the finaliser ids that differ in the last digit ("boat.3",
## "boat.4") share their high bits and every boat got the same load.
static func stable_hash(text: String) -> int:
	var h := 5381
	for byte in text.to_utf8_buffer():
		h = ((h * 33) ^ byte) & 0xffffffff
	# Multiplier < 2^27 keeps every product inside a signed 64-bit int.
	h = (((h >> 16) ^ h) * 0x45d9f3b) & 0xffffffff
	h = (((h >> 16) ^ h) * 0x45d9f3b) & 0xffffffff
	h = (h >> 16) ^ h
	return h & 0x7fffffff


static func _hash01(a: int, b: int) -> float:
	return fposmod(sin(float(a) * 127.1 + float(b) * 311.7) * 43758.5453, 1.0)
