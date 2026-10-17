class_name CityDwarfShrubs
extends Node3D

## Dwarf shrubs and berry ground cover of the seamless city (R-2127), next to
## the moss and fungi of CityForestFloor (R-1661). Each species follows its
## Estonian habitat:
##   closed conifer stand  - bilberry carpets under spruce, bilberry and
##                           cowberry under pine, some bilberry under birch
##   coastal pine heath    - heather, crowberry and cowberry round the heath
##                           pines (`pine_tall`) and junipers among pines
##   forest edge and bank  - wild strawberry on the sunny south side of edge
##                           trees, twice as often on a sloping bank
##   bog                   - sphagnum mats carrying cranberry, with crowberry
##                           and bog rosemary on the hummocks and cloudberry on
##                           the lawns, inside plan `bogs` polygons
## Plants grow as clonal patches of several clumps. Everything is seeded by tree
## position or bog id, so a plan always grows the same floor; nothing is saved.
##
## Seasons: set_calendar_date swaps each species' MultiMesh mesh to the stage of
## the date (STAGE_DAYS); the instances stay, so a spot keeps its plant all year.
## Species with no stage above ground (cloudberry, wild strawberry in winter)
## are hidden. Snow, frost and rain come from the shared plant material.

const Meshes := preload("res://scripts/city/city_dwarf_shrub_meshes.gd")
const SHADER := preload("res://scripts/city/city_forb.gdshader")
const LEAF_DETAIL := preload("res://assets/vegetation/forbs/forb_leaf_detail.png")

## Day the slice opens on (21 April 1343) until the runtime sets the calendar.
const DEFAULT_DAY := 111
## Stage windows by day of year: [first, last, stage], checked in order; days
## outside every window take DEFAULT_STAGE. Estonian phenology: bilberry flowers
## in May and ripens in July; heather flowers August-September; cloudberry
## flowers late May-June and ripens in July; cranberries ripen in September and
## stay on the plant through the winter.
const STAGE_DAYS := {
	&"bilberry":
	[[121, 165, &"flower"], [166, 185, &"leaf"], [186, 240, &"fruit"], [241, 300, &"autumn"]],
	&"cowberry":
	[[1, 100, &"winter"], [152, 190, &"flower"], [220, 300, &"fruit"], [320, 366, &"winter"]],
	&"heather": [[1, 110, &"winter"], [213, 273, &"flower"], [290, 366, &"winter"]],
	&"crowberry": [[1, 100, &"winter"], [200, 280, &"fruit"], [320, 366, &"winter"]],
	&"cloudberry":
	[[131, 170, &"flower"], [171, 185, &"leaf"], [186, 225, &"fruit"], [226, 279, &"autumn"]],
	&"cranberry":
	[[1, 120, &"winter"], [170, 200, &"flower"], [230, 300, &"fruit"], [301, 366, &"winter"]],
	&"bog_rosemary": [[1, 100, &"winter"], [130, 175, &"flower"], [300, 366, &"winter"]],
	&"wild_strawberry":
	[[121, 160, &"flower"], [161, 212, &"fruit"], [213, 290, &"leaf"], [291, 320, &"autumn"]],
}
## Bilberry is deciduous (bare green twigs); cloudberry and wild strawberry die
## back to the ground.
const DEFAULT_STAGE := {
	&"bilberry": &"bare",
	&"cloudberry": &"none",
	&"wild_strawberry": &"none",
}

## Closed stand: chance per wooded tree of a patch, and the bilberry share.
const WOOD_RULES := {
	&"spruce": [0.6, 0.8],
	&"pine": [0.55, 0.5],
	&"birch": [0.25, 0.85],
}
## Heath: chance per heath tree and the species mix.
const HEATH_CHANCE := 0.75
const HEATH_MIX := [[&"heather", 0.45], [&"crowberry", 0.25], [&"cowberry", 0.3]]
## Forest edge: a tree with this many forest neighbours (fewer than a closed
## stand) stands at an edge or in a clearing.
const EDGE_MIN_NEIGHBOURS := 2
const EDGE_CHANCE := 0.22
## Ground steeper than this (radians, about 8 degrees) counts as a bank.
const BANK_SLOPE := 0.14
## Edge trees by a house are yard or street trees, not woodland edge.
const EDGE_HOUSE_CLEARANCE := 6.0
## Bog grid spacing in metres and the share of grid points left as open peat.
const BOG_STEP_M := 1.8
const BOG_GAP := 0.25

## Instance batches per (species, CHUNK) square. Small chunks so visibility
## range culls close to the shader fade: a chunk centre is at most
## CHUNK_HALF_DIAGONAL from any clump in it.
const CHUNK := 32.0
const CHUNK_HALF_DIAGONAL := 22.7
## Clumps shrink into the ground between these camera distances (world units).
const FADE := Vector2(30.0, 44.0)

static var _material: ShaderMaterial
static var _bog_noise: FastNoiseLite

var day_of_year := DEFAULT_DAY
var _batches: Dictionary = {}  # species -> Array[MultiMeshInstance3D]
var _stage: Dictionary = {}  # species -> current stage
## [species, Transform3D] per instance in build order; kept because the headless
## dummy renderer does not store MultiMesh transforms.
var _placed: Array = []


static func build(plan: CityPlan, parent: Node3D) -> CityDwarfShrubs:
	var node := CityDwarfShrubs.new()
	node.name = "DwarfShrubs"
	parent.add_child(node)
	node._populate(plan)
	node.set_day_of_year(DEFAULT_DAY)
	return node


## Model stage of `species` on `day` (1..366); STAGE_NONE when nothing stands
## above ground.
static func stage_for(species: StringName, day: int) -> StringName:
	for window: Array in STAGE_DAYS.get(species, []):
		if day >= int(window[0]) and day <= int(window[1]):
			return window[2]
	return DEFAULT_STAGE.get(species, Meshes.STAGE_LEAF)


func set_calendar_date(date: Dictionary) -> void:
	set_day_of_year(GameCalendar.day_of_year(date))


func set_day_of_year(day: int) -> void:
	day_of_year = day
	for species: StringName in _batches:
		var stage := stage_for(species, day)
		_stage[species] = stage
		var show := stage != Meshes.STAGE_NONE
		var mesh: ArrayMesh = Meshes.mesh_for(species, stage) if show else null
		for mmi: MultiMeshInstance3D in _batches[species]:
			mmi.visible = show
			if show:
				mmi.multimesh.mesh = mesh


func current_stage(species: StringName) -> StringName:
	return _stage.get(species, Meshes.STAGE_NONE)


func instance_count(species: StringName) -> int:
	var n := 0
	for mmi: MultiMeshInstance3D in _batches.get(species, []):
		n += mmi.multimesh.instance_count
	return n


func visible_species() -> Array[StringName]:
	var out: Array[StringName] = []
	for species: StringName in _batches:
		var list: Array = _batches[species]
		if not list.is_empty() and (list[0] as Node3D).visible:
			out.append(species)
	return out


## Every placed clump as [species, transform], in build order (tests, captures).
func placements() -> Array:
	return _placed


## Forest trees with their forest-neighbour count within the woods radius, as
## [[x, z, species, size], neighbours] (CityForestFloor's closed-stand test).
static func tree_neighbours(plan: CityPlan) -> Array:
	var radius := CityForestFloor.WOODS_RADIUS
	var grid: Dictionary = {}
	var forest := []
	for t: Array in plan.data.get("trees", []):
		if not CityForestFloor.FOREST_TREES.has(StringName(t[2])):
			continue
		forest.append(t)
		var key := Vector2i(floori(float(t[0]) / radius), floori(float(t[1]) / radius))
		if not grid.has(key):
			grid[key] = []
		(grid[key] as Array).append(Vector2(t[0], t[1]))
	var out := []
	for t: Array in forest:
		var p := Vector2(t[0], t[1])
		var c := Vector2i(floori(p.x / radius), floori(p.y / radius))
		var n := -1  # the tree itself
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				for q: Vector2 in grid.get(c + Vector2i(dx, dz), []):
					if p.distance_squared_to(q) <= radius * radius:
						n += 1
		out.append([t, n])
	return out


## Forest trees at a wood edge or in a clearing: some forest neighbours, but
## fewer than a closed stand, and not a yard tree beside a house.
static func edge_trees(plan: CityPlan) -> Array:
	var out := []
	for row: Array in tree_neighbours(plan):
		var n: int = row[1]
		if n < EDGE_MIN_NEIGHBOURS or n >= CityForestFloor.WOODS_NEIGHBOURS:
			continue
		var t: Array = row[0]
		if not plan.buildings_near(Vector2(t[0], t[1]), EDGE_HOUSE_CLEARANCE).is_empty():
			continue
		out.append(t)
	return out


## Heath trees: the coastal heath pines, and junipers standing among pines.
static func heath_trees(plan: CityPlan) -> Array:
	var pines: Dictionary = {}
	var cell := CityForestFloor.WOODS_RADIUS
	for t: Array in plan.data.get("trees", []):
		if StringName(t[2]) in [&"pine", &"pine_tall"]:
			pines[Vector2i(floori(float(t[0]) / cell), floori(float(t[1]) / cell))] = true
	var out := []
	for t: Array in plan.data.get("trees", []):
		var species := StringName(t[2])
		if species == &"pine_tall":
			out.append(t)
		elif species == &"juniper":
			var c := Vector2i(floori(float(t[0]) / cell), floori(float(t[1]) / cell))
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					if pines.has(c + Vector2i(dx, dz)) and not out.has(t):
						out.append(t)
	return out


## Bog cover inside `bog["polygon"]` (world units): sphagnum mats on a jittered
## grid, cranberry laid over most mats, and hummock / lawn species by a fixed
## noise field. `height_at` maps a Vector2 to ground height; `unit` is world
## units per metre. Returns [species, Transform3D] rows; pure data.
static func bog_placements(bog: Dictionary, height_at: Callable, unit: float) -> Array:
	var poly := PackedVector2Array()
	for q: Array in bog.get("polygon", []):
		poly.append(Vector2(float(q[0]), float(q[1])))
	if poly.size() < 3:
		return []
	var lo := poly[0]
	var hi := poly[0]
	for q in poly:
		lo = lo.min(q)
		hi = hi.max(q)
	if _bog_noise == null:
		_bog_noise = FastNoiseLite.new()
		_bog_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_bog_noise.seed = 2127
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(bog.get("id", "bog")))
	var step := BOG_STEP_M * unit
	_bog_noise.frequency = 0.09 / unit
	var out := []
	var y := lo.y
	while y <= hi.y:
		var x := lo.x
		while x <= hi.x:
			var at := Vector2(x, y) + Vector2(rng.randf(), rng.randf()) * step * 0.7
			var gap := rng.randf()
			var yaw := rng.randf() * TAU
			var size := rng.randf_range(0.8, 1.3)
			var pick := rng.randf()
			var off := Vector2(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2)) * unit
			x += step
			if gap < BOG_GAP or not Geometry2D.is_point_in_polygon(at, poly):
				continue
			var ground := float(height_at.call(at))
			var mat_scale := size * unit
			out.append([Meshes.SPECIES_SPHAGNUM, _clump(at, ground - 0.02, yaw, mat_scale, 1.0)])
			# Peat lies about 8 cm proud of the ground on the cushion.
			var top := ground + 0.07 * mat_scale
			if pick < 0.7:
				out.append(
					[Meshes.SPECIES_CRANBERRY, _clump(at + off, top - 0.01, yaw + 1.3, unit, 1.0)]
				)
			var hummock := _bog_noise.get_noise_2dv(at) * 0.5 + 0.5
			var other := &""
			if hummock > 0.6:
				other = Meshes.SPECIES_CROWBERRY if pick < 0.5 else Meshes.SPECIES_BOG_ROSEMARY
			elif hummock > 0.42 and pick > 0.55:
				other = Meshes.SPECIES_CLOUDBERRY
			if other != &"":
				out.append([other, _clump(at - off, top - 0.02, yaw + 2.6, size * unit, 1.0)])
		y += step
	return out


static func _clump(at: Vector2, h: float, yaw: float, s: float, squash: float) -> Transform3D:
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3(s, s * squash, s))
	return Transform3D(basis, Vector3(at.x, h, at.y))


func _populate(plan: CityPlan) -> void:
	var unit := 1.0 / maxf(plan.metres_per_unit, 0.01)  # world units per metre
	var roads := CityForestFloor._roads_image(plan)
	var buckets: Dictionary = {}  # [species, chunk] -> {transforms, colors}
	# 1. Closed stands: bilberry and cowberry under the conifers.
	for t: Array in CityForestFloor.wooded_trees(plan):
		var species := StringName(t[2])
		if not WOOD_RULES.has(species):
			continue
		var rng := _tree_rng(t, 0x2127)
		var rule: Array = WOOD_RULES[species]
		if rng.randf() >= float(rule[0]):
			continue
		var kind := (
			Meshes.SPECIES_BILBERRY if rng.randf() < float(rule[1]) else Meshes.SPECIES_COWBERRY
		)
		_patch(
			plan,
			roads,
			buckets,
			rng,
			t,
			kind,
			Vector2(1.0, 6.0) * unit,
			rng.randi_range(4, 10),
			2.2 * unit,
			unit,
			-1.0
		)
	# 2. Coastal pine heath: heather, crowberry and cowberry, open ground included.
	for t: Array in heath_trees(plan):
		var rng := _tree_rng(t, 0x4EA7)
		if rng.randf() >= HEATH_CHANCE:
			continue
		var kind := _pick(HEATH_MIX, rng.randf())
		var count := (
			rng.randi_range(6, 14) if kind == Meshes.SPECIES_HEATHER else rng.randi_range(4, 9)
		)
		_patch(
			plan,
			roads,
			buckets,
			rng,
			t,
			kind,
			Vector2(1.0, 7.0) * unit,
			count,
			2.8 * unit,
			unit,
			-1.0
		)
	# 3. Wood edges and banks: wild strawberry on the sunny side.
	for t: Array in edge_trees(plan):
		var rng := _tree_rng(t, 0x57AB)
		var p := Vector2(t[0], t[1])
		var chance := EDGE_CHANCE
		if plan.slope_at(p + Vector2(0.0, 4.0 * unit)) > BANK_SLOPE:
			chance *= 2.0
		if rng.randf() >= chance:
			continue
		_patch(
			plan,
			roads,
			buckets,
			rng,
			t,
			Meshes.SPECIES_WILD_STRAWBERRY,
			Vector2(2.0, 7.0) * unit,
			rng.randi_range(4, 9),
			1.6 * unit,
			unit,
			1.0
		)
	# 4. Bogs authored on the plan.
	var height_at := func(q: Vector2) -> float: return plan.ground_height(q)
	for bog: Dictionary in plan.data.get("bogs", []):
		for row: Array in bog_placements(bog, height_at, unit):
			var xf: Transform3D = row[1]
			if CityForestFloor._ground_ok(plan, roads, Vector2(xf.origin.x, xf.origin.z)):
				var tone := 0.9 + 0.2 * fposmod(xf.origin.x * 7.31 + xf.origin.z * 3.17, 1.0)
				_add(buckets, row[0], xf, Color(tone, tone, tone))
	_commit(buckets)


## A clonal patch of `count` clumps round a point `reach` (min, max) from the
## tree, `spread` across. `side` > 0 keeps the patch on the south (+z) half.
# gdlint:ignore=function-arguments-number
func _patch(
	plan: CityPlan,
	roads: Image,
	buckets: Dictionary,
	rng: RandomNumberGenerator,
	t: Array,
	kind: StringName,
	reach: Vector2,
	count: int,
	spread: float,
	unit: float,
	side: float
) -> void:
	var p := Vector2(t[0], t[1])
	var trunk_r := CityForestFloor._trunk_radius(StringName(t[2]), float(t[3])) * unit
	var a := rng.randf() * TAU
	if side > 0.0:
		a = rng.randf_range(0.15 * PI, 0.85 * PI)  # sin > 0: south (+z) half
	var centre := (
		p + Vector2(cos(a), sin(a)) * rng.randf_range(maxf(reach.x, trunk_r + 0.4 * unit), reach.y)
	)
	for _i in count:
		var at := (
			centre + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * spread * 0.5
		)
		var yaw := rng.randf() * TAU
		var s := rng.randf_range(0.75, 1.3) * unit
		var tone := rng.randf_range(0.86, 1.1)
		var warm := rng.randf_range(0.94, 1.04)
		if (
			at.distance_to(p) < trunk_r + 0.2 * unit
			or not CityForestFloor._ground_ok(plan, roads, at)
		):
			continue
		var xf := _clump(at, plan.ground_height(at) - 0.02, yaw, s, rng.randf_range(0.85, 1.15))
		_add(buckets, kind, xf, Color(tone * warm, tone, tone / warm))


static func _tree_rng(t: Array, salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(int(float(t[0]) * 10.0), int(float(t[1]) * 10.0))) ^ salt
	return rng


static func _pick(mix: Array, roll: float) -> StringName:
	var cursor := roll
	for entry: Array in mix:
		cursor -= float(entry[1])
		if cursor < 0.0:
			return entry[0]
	return mix[-1][0]


static func _add(buckets: Dictionary, species: StringName, xf: Transform3D, color: Color) -> void:
	var key := [species, Vector2i(floori(xf.origin.x / CHUNK), floori(xf.origin.z / CHUNK))]
	if not buckets.has(key):
		buckets[key] = {"transforms": [] as Array[Transform3D], "colors": [] as Array[Color]}
	(buckets[key]["transforms"] as Array[Transform3D]).append(xf)
	(buckets[key]["colors"] as Array[Color]).append(color)


func _commit(buckets: Dictionary) -> void:
	var keys := buckets.keys()
	keys.sort_custom(func(x: Array, y: Array) -> bool: return str(x) < str(y))
	for key: Array in keys:
		var species: StringName = key[0]
		var batch: Dictionary = buckets[key]
		var stage := stage_for(species, day_of_year)
		var mesh := Meshes.mesh_for(
			species, stage if stage != Meshes.STAGE_NONE else Meshes.STAGE_LEAF
		)
		var mmi := MapViewMeshBuilderPrimitives.multi_mesh(
			"%s_%d_%d" % [species, key[1].x, key[1].y],
			mesh,
			batch["transforms"],
			batch["colors"],
			material(),
			Vector3.ZERO
		)
		for xf: Transform3D in batch["transforms"]:
			_placed.append([species, xf])
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Culled once the shader has shrunk every clump of the chunk away.
		mmi.visibility_range_end = FADE.y + CHUNK_HALF_DIAGONAL
		mmi.visibility_range_end_margin = 4.0
		add_child(mmi)
		if not _batches.has(species):
			_batches[species] = [] as Array[MultiMeshInstance3D]
		(_batches[species] as Array).append(mmi)


## The forb shader (wind, snow, frost, wetness from PlantMaterial) with its own
## fade. The generic autumn yellowing is switched off: each stage mesh carries
## its own autumn and winter colours.
static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		_material.set_shader_parameter("leaf_detail", LEAF_DETAIL)
		_material.set_shader_parameter("fade_start", FADE.x)
		_material.set_shader_parameter("fade_end", FADE.y)
		_material.set_shader_parameter("sway_strength", 0.03)
		_material.set_shader_parameter("autumn_offset", -2.0)
	return _material
