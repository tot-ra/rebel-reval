class_name CityForestFloor
extends Node3D

## Forest floor of the city woods (R-1661): moss cushions round the trees of a
## closed stand, ground mushrooms that follow the season, and tinder-fungus
## brackets on birch trunks. Only trees with enough forest neighbours count as
## woods, so park trees, orchards and lone pasture oaks keep clean grass.
##
## Species are the common Estonian forest fungi, matched to their tree partner:
## false morel (Gyromitra esculenta) under pine in April-May, chanterelle under
## spruce, pine and birch, porcini under spruce, pine and birch, fly agaric
## under birch and spruce (July-October), and the perennial tinder bracket
## (Fomes fomentarius) on birch. Everything is seeded by tree position, so a
## plan always grows the same floor; set_calendar_date only shows or hides kinds.

const KIND_MOSS := &"moss"
const KIND_GYROMITRA := &"gyromitra"
const KIND_CHANTERELLE := &"chanterelle"
const KIND_PORCINI := &"porcini"
const KIND_FLY_AGARIC := &"fly_agaric"
const KIND_BRACKET := &"bracket"
const KINDS: Array[StringName] = [
	KIND_MOSS, KIND_GYROMITRA, KIND_CHANTERELLE, KIND_PORCINI, KIND_FLY_AGARIC, KIND_BRACKET
]
## Fruiting window as day of the year (first, last); kinds absent here show all year.
const SEASON := {
	&"gyromitra": Vector2i(100, 152),
	&"chanterelle": Vector2i(182, 280),
	&"porcini": Vector2i(196, 288),
	&"fly_agaric": Vector2i(205, 295),
}
## Day the slice opens on (21 April 1343) until the runtime sets the calendar.
const DEFAULT_DAY := 111
const FOREST_TREES := [
	&"spruce", &"pine", &"pine_tall", &"birch", &"oak", &"ash", &"alder", &"linden", &"elm",
	&"maple", &"rowan", &"hazel", &"willow"
]
## A tree is in woods when this many forest trees stand within WOODS_RADIUS.
const WOODS_RADIUS := 15.0
const WOODS_NEIGHBOURS := 8
const CHUNK := 96.0
const MOSS_RANGE := 110.0
const FUNGI_RANGE := 70.0
## Mycorrhizal partners: which trees each ground mushroom grows beside, and its chance per tree.
const PARTNERS := {
	&"gyromitra": [[&"pine", &"pine_tall"], 0.16],
	&"chanterelle": [[&"spruce", &"pine", &"pine_tall", &"birch"], 0.14],
	&"porcini": [[&"spruce", &"pine", &"pine_tall", &"birch", &"oak"], 0.08],
	&"fly_agaric": [[&"birch", &"spruce"], 0.12],
}
const BRACKET_CHANCE := 0.3

static var _material: StandardMaterial3D
static var _meshes: Dictionary = {}

var day_of_year := DEFAULT_DAY
var _batches: Dictionary = {}  # kind -> Array[MultiMeshInstance3D]
## [kind, Transform3D] per instance in batch order; kept because the headless
## dummy renderer does not store MultiMesh transforms.
var _placed: Array = []


static func build(plan: CityPlan, parent: Node3D) -> CityForestFloor:
	var node := CityForestFloor.new()
	node.name = "ForestFloor"
	parent.add_child(node)
	node._populate(plan)
	node.set_day_of_year(DEFAULT_DAY)
	return node


## Ground and trunk fungi that fruit on `day` (1..366); moss is always out.
static func kinds_in_season(day: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for kind in KINDS:
		if not SEASON.has(kind):
			out.append(kind)
			continue
		var w: Vector2i = SEASON[kind]
		if day >= w.x and day <= w.y:
			out.append(kind)
	return out


func set_calendar_date(date: Dictionary) -> void:
	set_day_of_year(GameCalendar.day_of_year(date))


func set_day_of_year(day: int) -> void:
	day_of_year = day
	var live := kinds_in_season(day)
	for kind: StringName in _batches:
		for mmi: MultiMeshInstance3D in _batches[kind]:
			mmi.visible = live.has(kind)


func instance_count(kind: StringName) -> int:
	var n := 0
	for mmi: MultiMeshInstance3D in _batches.get(kind, []):
		n += mmi.multimesh.instance_count
	return n


func visible_kinds() -> Array[StringName]:
	var out: Array[StringName] = []
	for kind: StringName in _batches:
		if not (_batches[kind] as Array).is_empty() and (_batches[kind][0] as Node3D).visible:
			out.append(kind)
	return out


## Every placed instance as [kind, transform], in build order (for tests).
func placements() -> Array:
	return _placed


## Forest trees that stand in a closed stand, as [x, z, species, size].
static func wooded_trees(plan: CityPlan) -> Array:
	var grid: Dictionary = {}
	var forest := []
	for t: Array in plan.data.get("trees", []):
		if not FOREST_TREES.has(StringName(t[2])):
			continue
		forest.append(t)
		var key := Vector2i(floori(float(t[0]) / WOODS_RADIUS), floori(float(t[1]) / WOODS_RADIUS))
		if not grid.has(key):
			grid[key] = []
		(grid[key] as Array).append(Vector2(t[0], t[1]))
	var out := []
	for t: Array in forest:
		var p := Vector2(t[0], t[1])
		var c := Vector2i(floori(p.x / WOODS_RADIUS), floori(p.y / WOODS_RADIUS))
		var n := -1  # the tree itself
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				for q: Vector2 in grid.get(c + Vector2i(dx, dz), []):
					if p.distance_squared_to(q) <= WOODS_RADIUS * WOODS_RADIUS:
						n += 1
		if n >= WOODS_NEIGHBOURS:
			out.append(t)
	return out


func _populate(plan: CityPlan) -> void:
	var unit := 1.0 / maxf(plan.metres_per_unit, 0.01)  # world units per metre
	var roads := _roads_image(plan)
	var buckets: Dictionary = {}  # [kind, chunk] -> {transforms, colors}
	for t: Array in wooded_trees(plan):
		var p := Vector2(t[0], t[1])
		var species := StringName(t[2])
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(Vector2i(int(p.x * 10.0), int(p.y * 10.0))) ^ 0x6D055
		var trunk_r := _trunk_radius(species, float(t[3])) * unit
		# Moss cushions: two to four round each tree, more on its shaded north side.
		for i in rng.randi_range(2, 4):
			var a := rng.randf() * TAU
			if rng.randf() < 0.5:
				a = lerpf(PI, TAU, rng.randf())  # sin < 0: north (-z) half
			var r := rng.randf_range(trunk_r + 0.3 * unit, 5.5 * unit)
			var at := p + Vector2(cos(a), sin(a)) * r
			if not _ground_ok(plan, roads, at):
				continue
			var s := rng.randf_range(0.6, 1.5) * unit
			var squash := Vector3(s, s * rng.randf_range(0.7, 1.2), s)
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(squash)
			var tone := rng.randf_range(0.8, 1.15)
			var origin := Vector3(at.x, plan.ground_height(at) - 0.06, at.y)
			_add(buckets, KIND_MOSS, Transform3D(basis, origin),
				Color(tone * rng.randf_range(0.95, 1.05), tone, tone * rng.randf_range(0.85, 1.0)))
		# Ground mushrooms by tree partner: a single fruit body or a small troop.
		for kind: StringName in PARTNERS:
			var rule: Array = PARTNERS[kind]
			if not (rule[0] as Array).has(species) or rng.randf() >= float(rule[1]):
				continue
			var a := rng.randf() * TAU
			var r := rng.randf_range(trunk_r + 0.4 * unit, 3.5 * unit)
			var centre := p + Vector2(cos(a), sin(a)) * r
			var chanterelle := kind == KIND_CHANTERELLE
			var troop := rng.randi_range(3, 7) if chanterelle else rng.randi_range(1, 3)
			for j in troop:
				var jitter := Vector2(rng.randf_range(-0.35, 0.35), rng.randf_range(-0.35, 0.35))
				var at := centre + jitter * unit
				if not _ground_ok(plan, roads, at):
					continue
				var s := rng.randf_range(0.7, 1.25) * unit
				var lean := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
				var tilt := Basis(lean, rng.randf_range(0.0, 0.18))
				var basis := (tilt * Basis(Vector3.UP, rng.randf() * TAU)).scaled(Vector3.ONE * s)
				var tone := rng.randf_range(0.85, 1.1)
				var origin := Vector3(at.x, plan.ground_height(at) - 0.02, at.y)
				_add(buckets, kind, Transform3D(basis, origin), Color(tone, tone, tone))
		# Tinder brackets: a shelf or two on the side of an old birch.
		if species == &"birch" and rng.randf() < BRACKET_CHANCE:
			var a := rng.randf() * TAU
			for j in rng.randi_range(1, 3):
				var h := rng.randf_range(0.5, 1.8) * unit
				var out := Vector3(cos(a), 0.0, sin(a))
				var r := trunk_r * lerpf(1.0, 0.8, h / (1.8 * unit))
				var s := rng.randf_range(0.7, 1.3) * unit
				var basis := Basis.looking_at(out, Vector3.UP).scaled(Vector3.ONE * s)
				var base := Vector3(p.x, plan.ground_height(p) - 0.15 + h, p.y) + out * r * 0.9
				_add(buckets, KIND_BRACKET, Transform3D(basis, base), Color.WHITE)
				a += rng.randf_range(-0.5, 0.5)
	var keys := buckets.keys()
	keys.sort_custom(func(x: Array, y: Array) -> bool: return str(x) < str(y))
	for key: Array in keys:
		var kind: StringName = key[0]
		var batch: Dictionary = buckets[key]
		var mmi := MapViewMeshBuilderPrimitives.multi_mesh(
			"%s_%d_%d" % [kind, key[1].x, key[1].y],
			mesh_for(kind),
			batch["transforms"],
			batch["colors"],
			material(),
			Vector3.ZERO
		)
		for xf: Transform3D in batch["transforms"]:
			_placed.append([kind, xf])
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = MOSS_RANGE if kind == KIND_MOSS else FUNGI_RANGE
		mmi.visibility_range_end_margin = 8.0
		add_child(mmi)
		if not _batches.has(kind):
			_batches[kind] = [] as Array[MultiMeshInstance3D]
		(_batches[kind] as Array).append(mmi)


static func _add(buckets: Dictionary, kind: StringName, xf: Transform3D, color: Color) -> void:
	var key := [kind, Vector2i(floori(xf.origin.x / CHUNK), floori(xf.origin.z / CHUNK))]
	if not buckets.has(key):
		buckets[key] = {"transforms": [] as Array[Transform3D], "colors": [] as Array[Color]}
	(buckets[key]["transforms"] as Array[Transform3D]).append(xf)
	(buckets[key]["colors"] as Array[Color]).append(color)


## Bole radius in metres at the root, matching the thinned city wood mesh.
static func _trunk_radius(species: StringName, size: float) -> float:
	var d := float(CityVegetationBuilder.TRUNK_DIAMETER_M.get(species, 0.4))
	return d * 0.5 * CityVegetationBuilder.size_factor(size) + 0.05


static func _roads_image(plan: CityPlan) -> Image:
	var tex := load(plan.roads_path()) as Texture2D
	if tex == null:
		return null
	var img := tex.get_image()
	if img != null and img.is_compressed():
		img.decompress()
	return img


## Nothing grows on cart roads or in the moat.
static func _ground_ok(plan: CityPlan, roads: Image, at: Vector2) -> bool:
	if plan.in_moat(at, 1.0):
		return false
	if roads == null:
		return true
	var uv := (at - plan.bounds.position) / plan.bounds.size
	var px := Vector2i(
		clampi(int(uv.x * roads.get_width()), 0, roads.get_width() - 1),
		clampi(int(uv.y * roads.get_height()), 0, roads.get_height() - 1)
	)
	return roads.get_pixelv(px).r < 0.15


static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		# The palette below is authored in sRGB like the rest of the art.
		_material.vertex_color_is_srgb = true
		_material.roughness = 0.85
		_material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	return _material


static func mesh_for(kind: StringName) -> ArrayMesh:
	if not _meshes.has(kind):
		_meshes[kind] = _build_mesh(kind)
	return _meshes[kind]


static func _build_mesh(kind: StringName) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	match kind:
		KIND_MOSS:
			# A low lumpy cushion, ~0.5 m across, darker at the foot.
			_lathe(st, [
				[0.28, -0.03, Color(0.14, 0.18, 0.06)], [0.27, 0.05, Color(0.2, 0.27, 0.08)],
				[0.21, 0.13, Color(0.27, 0.35, 0.1)], [0.11, 0.18, Color(0.31, 0.4, 0.12)],
				[0.0, 0.19, Color(0.33, 0.42, 0.13)]
			], 14, rng, 0.25)
		KIND_FLY_AGARIC:
			var stem := Color(0.9, 0.88, 0.8)
			var red := Color(0.72, 0.08, 0.04)
			_lathe(st, [
				[0.02, 0.0, stem], [0.016, 0.08, stem], [0.022, 0.1, stem], [0.014, 0.12, stem]
			], 8, rng, 0.0)
			# Domed cap; white warts are flecked onto the red at random vertices.
			_lathe(st, [
				[0.0, 0.105, red * 0.8], [0.075, 0.11, red * 0.9], [0.072, 0.135, red],
				[0.055, 0.16, red], [0.028, 0.175, red], [0.0, 0.18, red]
			], 14, rng, 0.05, Color(0.95, 0.93, 0.85), 0.22)
		KIND_CHANTERELLE:
			var gold := Color(0.92, 0.62, 0.12)
			# A funnel: narrow stem flaring into a wavy, in-curled rim.
			_lathe(st, [
				[0.008, 0.0, gold * 0.85], [0.01, 0.025, gold * 0.9], [0.03, 0.05, gold],
				[0.045, 0.058, gold], [0.038, 0.06, gold * 1.05], [0.0, 0.052, gold * 0.95]
			], 12, rng, 0.18)
		KIND_PORCINI:
			var stem := Color(0.86, 0.8, 0.66)
			var brown := Color(0.42, 0.25, 0.12)
			_lathe(st, [
				[0.025, 0.0, stem * 0.9], [0.038, 0.035, stem],
				[0.03, 0.08, stem], [0.022, 0.1, stem]
			], 10, rng, 0.05)
			_lathe(st, [
				[0.0, 0.09, Color(0.85, 0.8, 0.55)], [0.08, 0.095, Color(0.8, 0.74, 0.5)],
				[0.078, 0.115, brown], [0.06, 0.14, brown], [0.03, 0.152, brown * 1.08],
				[0.0, 0.155, brown * 1.1]
			], 14, rng, 0.04)
		KIND_GYROMITRA:
			var stem := Color(0.82, 0.76, 0.68)
			var cap := Color(0.36, 0.17, 0.09)
			_lathe(st, [[0.02, 0.0, stem], [0.024, 0.04, stem], [0.02, 0.055, stem]], 8, rng, 0.08)
			# Brain-like, folded cap: a strongly lumpy ball.
			_lathe(st, [
				[0.0, 0.04, cap * 0.7], [0.045, 0.05, cap * 0.8], [0.06, 0.08, cap],
				[0.055, 0.11, cap * 1.1], [0.032, 0.13, cap], [0.0, 0.135, cap * 0.9]
			], 12, rng, 0.35)
		KIND_BRACKET:
			# Hoof-shaped shelf growing outwards along -Z (Basis.looking_at the trunk normal).
			_bracket(st)
	# Merge shared vertices so the cushions and caps shade smooth, not faceted.
	st.index()
	st.generate_normals()
	return st.commit()


## Revolves a (radius, height, colour) profile round +Y. `wobble` jitters each
## vertex's radius for lumpy organic outlines; `fleck` paints a share of the
## vertices in `fleck_color` (fly agaric warts).
static func _lathe(
	st: SurfaceTool, profile: Array, segments: int, rng: RandomNumberGenerator, wobble: float,
	fleck_color := Color.BLACK, fleck := 0.0
) -> void:
	var rows: Array[PackedVector3Array] = []
	var cols: Array[PackedColorArray] = []
	for ring: Array in profile:
		var pts := PackedVector3Array()
		var cs := PackedColorArray()
		for i in segments:
			var a := TAU * float(i) / float(segments)
			var r := float(ring[0]) * (1.0 + rng.randf_range(-wobble, wobble))
			var y := float(ring[1]) + float(ring[0]) * rng.randf_range(-wobble, wobble) * 0.3
			pts.append(Vector3(cos(a) * r, y, sin(a) * r))
			var c: Color = ring[2]
			if fleck > 0.0 and float(ring[0]) > 0.0 and rng.randf() < fleck:
				c = fleck_color
			cs.append(c)
		rows.append(pts)
		cols.append(cs)
	for k in rows.size() - 1:
		for i in segments:
			var j := (i + 1) % segments
			var quad := [
				[rows[k][i], cols[k][i]],
				[rows[k + 1][j], cols[k + 1][j]],
				[rows[k + 1][i], cols[k + 1][i]],
				[rows[k][i], cols[k][i]],
				[rows[k][j], cols[k][j]],
				[rows[k + 1][j], cols[k + 1][j]]
			]
			for v: Array in quad:
				st.set_color(v[1])
				st.add_vertex(v[0])


static func _bracket(st: SurfaceTool) -> void:
	# Concentric grey bands, a pale growing rim and a brown pore surface below.
	var bands := [
		Color(0.42, 0.4, 0.37), Color(0.55, 0.53, 0.5), Color(0.36, 0.34, 0.31), Color(0.62, 0.6, 0.55)
	]
	var rim := Color(0.78, 0.72, 0.6)
	var pores := Color(0.45, 0.33, 0.22)
	var seg := 10
	var top: Array[PackedVector3Array] = []
	var steps := 5
	for k in steps + 1:
		var t := float(k) / float(steps)
		var row := PackedVector3Array()
		for i in seg + 1:
			var a := lerpf(-PI * 0.5, PI * 0.5, float(i) / float(seg))
			var reach := 0.12 * t
			var width := 0.1 * (1.0 - t * 0.35)
			# Upper surface steps down towards the rim like a hoof.
			row.append(Vector3(sin(a) * width, 0.07 * (1.0 - t * t) + 0.01, -cos(a) * reach - 0.01))
		top.append(row)
	for k in steps:
		var band: Color = rim if k == steps - 1 else bands[k % bands.size()]
		for i in seg:
			var a := top[k][i]
			var b := top[k][i + 1]
			var c := top[k + 1][i]
			var d := top[k + 1][i + 1]
			for v: Vector3 in [a, d, c, a, b, d]:
				st.set_color(band)
				st.add_vertex(v)
	# Flat pore surface underneath, from the trunk to the rim.
	var under := top[steps]
	var centre := Vector3(0.0, 0.0, -0.01)
	for i in seg:
		var a := Vector3(under[i].x, 0.0, under[i].z)
		var b := Vector3(under[i + 1].x, 0.0, under[i + 1].z)
		for v: Vector3 in [centre, a, b]:
			st.set_color(pores)
			st.add_vertex(v)
	for i in seg:
		var a := under[i]
		var b := under[i + 1]
		var a0 := Vector3(a.x, 0.0, a.z)
		var b0 := Vector3(b.x, 0.0, b.z)
		for v: Vector3 in [a, b0, a0, a, b, b0]:
			st.set_color(rim)
			st.add_vertex(v)
