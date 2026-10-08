class_name CityGrass
extends Node3D

## Meadow grass and wild plants streamed in chunks around Kalev (ADR 0031,
## VEGR-4 R-1323). The ground texture is a plain green colour field; everything
## that looks like a plant is real 3D geometry:
##   near tier  - dense clumps of individual curved blades within ~12 m
##   mid tier   - sparser, larger blade clumps out to ~45 m, growing in as the
##                near tier shrinks out (scale cross-fade in the grass shader)
##   accents    - 3D plantain, dandelion, clover and yarrow scattered through the
##                mid chunks, so those plants are never baked into a texture
## Placement thins on trodden earth and leaves paving, floors, water and steep
## banks bare. Cart roads (roads.png) stay bare where wheels and feet pass: grass
## stands only on the verge, and a stray tuft on a lightly used road is tiny.
## Height follows use: kept short where people pass (near roads and houses, where
## it gets scythed) and growing to waist height in the open, which also drags on
## whoever wades through it (walk_drag_at). Deterministic per chunk (seeded from the chunk key).

const PlantMeshes := preload("res://scripts/map/view3d/map_view_plant_meshes.gd")
const PlantSpecies := preload("res://scripts/map/view3d/map_view_plant_species.gd")

const MID_CHUNK := 16.0
const MID_RADIUS_CHUNKS := 3
const MID_DENSITY := 1.0  # blade clumps per square world unit on full grass
## Mid clumps are scaled up so a sparse clump still covers its share of ground.
const MID_CLUMP_SCALE := Vector2(1.1, 1.7)

const NEAR_CHUNK := 8.0
const NEAR_RADIUS_CHUNKS := 2
const NEAR_DENSITY := 4.5
const NEAR_CLUMP_SCALE := Vector2(0.8, 1.35)

## Accent plants per square metre on full grass, by species (kept sparse so the
## meadow stays mostly grass and the plants read as individual finds).
const ACCENT_DENSITY := {
	PlantSpecies.SPECIES_PLANTAIN: 0.05,
	PlantSpecies.SPECIES_DANDELION: 0.035,
	PlantSpecies.SPECIES_CLOVER: 0.06,
	PlantSpecies.SPECIES_YARROW: 0.012,
}

## Distances (world units) over which grass grows from scythed to wild.
const ROAD_WILD_NEAR := 3.0
const ROAD_WILD_FAR := 22.0
const HOUSE_WILD_NEAR := 2.0
const HOUSE_WILD_FAR := 14.0
## Clump scale multiplier at the scythed edge and in the wild (blade clumps are
## ~0.4 m tall at 1.0, so 2.7 reaches roughly a person's waist).
const TALL_SCALE_MIN := 0.55
const TALL_SCALE_MAX := 2.7
## Walking speed multiplier in fully wild, full-density grass.
const TALL_GRASS_DRAG := 0.5
## Offsets sampled (unit ring directions x these radii) to find the nearest road.
const ROAD_PROBE_RADII := [1.5, 3.0, 5.0, 8.0, 12.0, 17.0, 22.0]
const ROAD_PROBE_DIRS := 8
const ROAD_PROBE_BODY := 0.25
const WILD_CACHE_LIMIT := 40000

var plan: CityPlan
var _wild_cache: Dictionary = {}
var _splat: Image
var _roads: Image
var _mid_chunks: Dictionary = {}
var _near_chunks: Dictionary = {}
var _blade_mesh: Mesh
var _near_material: Material
var _mid_material: Material
var _accent_material: Material


static func create(city_plan: CityPlan) -> CityGrass:
	var node := CityGrass.new()
	node.name = "Grass"
	node.plan = city_plan
	node._splat = (load(CityPlan.SPLAT_PATH) as Texture2D).get_image()
	if node._splat.is_compressed():
		node._splat.decompress()
	node._roads = (load(CityPlan.ROADS_PATH) as Texture2D).get_image()
	if node._roads.is_compressed():
		node._roads.decompress()
	node._blade_mesh = MapViewMeshBuilderPrimitives.grass_blade_clump_mesh()
	node._near_material = MapViewMaterials.grass_blade_tier(true)
	node._mid_material = MapViewMaterials.grass_blade_tier(false)
	node._accent_material = MapViewMaterials.grass_blades()
	return node


func update_for(world_xz: Vector2) -> void:
	# At most one new chunk per frame; near blades first, they are what the eye sees.
	if _stream(_near_chunks, world_xz, NEAR_CHUNK, NEAR_RADIUS_CHUNKS, _build_near_chunk):
		return
	_stream(_mid_chunks, world_xz, MID_CHUNK, MID_RADIUS_CHUNKS, _build_mid_chunk)


## Builds the nearest missing chunk (returns true if it did) and frees chunks that
## left the radius.
func _stream(
	chunks: Dictionary, world_xz: Vector2, size: float, radius: int, builder: Callable
) -> bool:
	var center := Vector2i(floori(world_xz.x / size), floori(world_xz.y / size))
	var wanted := {}
	var built := false
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var key := center + Vector2i(dx, dy)
			wanted[key] = true
			if not built and not chunks.has(key):
				chunks[key] = builder.call(key)
				built = true
	for key: Vector2i in chunks.keys():
		if not wanted.has(key):
			var node: Node = chunks[key]
			if node != null:
				node.queue_free()
			chunks.erase(key)
	return built


## Surface weights at a world position: (paving, earth, sand, mud), 0..1.
func surface_at(world_xz: Vector2) -> Color:
	var p := (world_xz - plan.bounds.position) / plan.bounds.size * Vector2(_splat.get_size())
	var x := clampi(int(p.x), 0, _splat.get_width() - 1)
	var y := clampi(int(p.y), 0, _splat.get_height() - 1)
	return _splat.get_pixel(x, y)


## Road raster at a world position: (body, lateral offset, traffic wear, verge).
func road_at(world_xz: Vector2) -> Color:
	var p := (world_xz - plan.bounds.position) / plan.bounds.size * Vector2(_roads.get_size())
	var x := clampi(int(p.x), 0, _roads.get_width() - 1)
	var y := clampi(int(p.y), 0, _roads.get_height() - 1)
	return _roads.get_pixel(x, y)


## How much of the road surface at `p` is kept clear of plants, 0..1. Wheels,
## hooves and boots keep the body of a road bare whatever the plate underneath
## says; only the unused edge of a quiet track may sprout.
func road_clearance(p: Vector2) -> float:
	var rd := road_at(p)
	return clampf(rd.r * (0.7 + 0.6 * rd.b), 0.0, 1.0)


## Share of tilled field soil at a splat texel, 0..1. The generator marks fields as
## full packed earth plus a mud-channel value of 110/255 (FIELD_MUD_LEVEL in
## build_reval_city_plan.py); the same band is read by city_ground.gdshader.
static func field_share(s: Color) -> float:
	var band := smoothstep(0.30, 0.36, s.a) * (1.0 - smoothstep(0.52, 0.60, s.a))
	return band * smoothstep(0.6, 0.85, s.g)


## Share of ground at `p` that stays bare (paving, earth, sand, mud).
func _bareness(p: Vector2) -> float:
	var s := surface_at(p)
	# Ploughed fields grow no turf; crops are drawn by CityFarmland.
	if field_share(s) > 0.0:
		return 1.0
	var base := maxf(s.r * 1.6, maxf(s.b, s.a * 0.9)) + s.g * 0.75
	# Packed earth beside a road still grows grass (verge); the road body does not.
	return maxf(base, road_clearance(p) * 1.25)


## Plants that do survive on a road are stunted: trampled, dry, never in the ruts.
func _road_shrink(p: Vector2) -> float:
	return lerpf(1.0, 0.3, clampf(road_at(p).r * 1.5, 0.0, 1.0))


## Distance from `p` to the nearest road body, capped at ROAD_WILD_FAR. The roads
## raster is 1 px per world unit, so a ring probe is enough for a growth gradient.
func road_distance(p: Vector2) -> float:
	if road_at(p).r > ROAD_PROBE_BODY:
		return 0.0
	for radius: float in ROAD_PROBE_RADII:
		for k in ROAD_PROBE_DIRS:
			var q := p + Vector2.from_angle(TAU * k / ROAD_PROBE_DIRS) * radius
			if road_at(q).r > ROAD_PROBE_BODY:
				return radius
	return ROAD_WILD_FAR


## Distance from `p` to the nearest house wall, capped at HOUSE_WILD_FAR.
func house_distance(p: Vector2) -> float:
	var best := HOUSE_WILD_FAR
	for index in plan.buildings_near(p, HOUSE_WILD_FAR):
		var ring := plan.footprint(index)
		for i in ring.size():
			var closest := Geometry2D.get_closest_point_to_segment(
				p, ring[i], ring[(i + 1) % ring.size()]
			)
			best = minf(best, p.distance_to(closest))
	return best


## How wild the ground at `p` is, 0 (scythed beside a road or wall) to 1 (open
## meadow far from both). Cached per metre; the grass height and the wading drag
## both read it, so what the eye sees is what slows the walker.
func wildness_at(p: Vector2) -> float:
	var key := Vector2i(floori(p.x), floori(p.y))
	if _wild_cache.has(key):
		return _wild_cache[key]
	if _wild_cache.size() > WILD_CACHE_LIMIT:
		_wild_cache.clear()
	var c := Vector2(key) + Vector2(0.5, 0.5)
	var w := minf(
		smoothstep(ROAD_WILD_NEAR, ROAD_WILD_FAR, road_distance(c)),
		smoothstep(HOUSE_WILD_NEAR, HOUSE_WILD_FAR, house_distance(c))
	)
	_wild_cache[key] = w
	return w


## Clump scale multiplier from use: short where people pass, tall where nobody does.
func height_factor(p: Vector2) -> float:
	return lerpf(TALL_SCALE_MIN, TALL_SCALE_MAX, wildness_at(p))


## Walking speed multiplier at `p` for wading through grass: 1 on bare ground and
## short turf, down to TALL_GRASS_DRAG in dense waist-high meadow.
func walk_drag_at(p: Vector2) -> float:
	var standing := 1.0 - clampf(_bareness(p), 0.0, 1.0)
	if standing <= 0.0 or is_nan(_grass_height(p)):
		return 1.0
	var tall := smoothstep(0.35, 0.9, wildness_at(p)) * standing
	return lerpf(1.0, TALL_GRASS_DRAG, tall)


## Ground height where grass may stand at `p`, or NAN where it must stay bare.
func _grass_height(p: Vector2) -> float:
	var h := plan.ground_height(p)
	if (
		h < 0.4
		or plan.slope_at(p) > 0.75
		or plan.building_at(p) >= 0
		or plan.site_at(p) != null
	):
		return NAN
	return h


func _scatter_clumps(
	key: Vector2i, size: float, density: float, scale_range: Vector2, seed_salt: int
) -> MultiMeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) + seed_salt
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var count := int(size * size * density)
	var origin := Vector2(key) * size
	for i in count:
		var p := origin + Vector2(rng.randf(), rng.randf()) * size
		if rng.randf() < _bareness(p):
			continue
		var h := _grass_height(p)
		if is_nan(h):
			continue
		# Tall grass grows up much more than out, so the wild meadow stays a field of
		# blades rather than a field of fat bushes.
		var tall := height_factor(p)
		var scale := rng.randf_range(scale_range.x, scale_range.y) * _road_shrink(p)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(
			Vector3(scale * sqrt(tall), scale * tall * rng.randf_range(0.75, 1.3), scale * sqrt(tall))
		)
		transforms.append(Transform3D(basis, Vector3(p.x, h - 0.02, p.y)))
		var tone := rng.randf_range(0.82, 1.08)
		colors.append(Color(tone, tone * rng.randf_range(0.95, 1.05), tone * 0.9, 1.0))
	if transforms.is_empty():
		return null
	return transforms_to_instance(key, transforms, colors, _blade_mesh, _near_material)


func transforms_to_instance(
	key: Vector2i, transforms: Array[Transform3D], colors: Array[Color], mesh: Mesh,
	material: Material, label: String = "Grass"
) -> MultiMeshInstance3D:
	var inst := MapViewMeshBuilderPrimitives.multi_mesh(
		"%s_%d_%d" % [label, key.x, key.y], mesh, transforms, colors, material, Vector3.ZERO
	)
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return inst


func _build_near_chunk(key: Vector2i) -> Node3D:
	var inst := _scatter_clumps(key, NEAR_CHUNK, NEAR_DENSITY, NEAR_CLUMP_SCALE, 0)
	if inst == null:
		return null
	inst.name = "NearBlades_%d_%d" % [key.x, key.y]
	add_child(inst)
	return inst


func _build_mid_chunk(key: Vector2i) -> Node3D:
	var root := Node3D.new()
	root.name = "MidGrass_%d_%d" % [key.x, key.y]
	var blades := _scatter_clumps(key, MID_CHUNK, MID_DENSITY, MID_CLUMP_SCALE, 7919)
	if blades != null:
		blades.material_override = _mid_material
		blades.name = "Blades"
		root.add_child(blades)
	_add_accent_plants(root, key)
	if root.get_child_count() == 0:
		root.free()
		return null
	add_child(root)
	return root


## One MultiMesh per accent species: real plantain rosettes, dandelions, clover
## and yarrow standing in the grass, drawn with the plant material (a distance
## fade only, they do not shrink next to the player like mid-tier clumps).
func _add_accent_plants(root: Node3D, key: Vector2i) -> void:
	var origin := Vector2(key) * MID_CHUNK
	for species: StringName in ACCENT_DENSITY:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(key) + hash(String(species))
		var transforms: Array[Transform3D] = []
		var colors: Array[Color] = []
		var scale_range := PlantSpecies.scale_range(species)
		var count := int(MID_CHUNK * MID_CHUNK * float(ACCENT_DENSITY[species]))
		for i in count:
			var p := origin + Vector2(rng.randf(), rng.randf()) * MID_CHUNK
			if rng.randf() < _bareness(p) * 1.4:
				continue
			var h := _grass_height(p)
			if is_nan(h):
				continue
			var scale := (
				rng.randf_range(scale_range.x, scale_range.y) * rng.randf_range(0.8, 1.25)
				* _road_shrink(p)
			)
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * scale)
			transforms.append(Transform3D(basis, Vector3(p.x, h - 0.02, p.y)))
			colors.append(PlantSpecies.instance_tint(species, rng.randf()))
		if transforms.is_empty():
			continue
		var inst := transforms_to_instance(
			key, transforms, colors, PlantMeshes.mesh_for(species), _accent_material,
			"Plants_%s" % String(species).to_pascal_case()
		)
		root.add_child(inst)
