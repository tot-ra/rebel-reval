class_name CityForbs
extends Node3D

## Where the wild plants of the seamless city grow (R-1519). Each species
## follows its real habitat, read from the same fields as the grass height:
##   broadleaf plantain - the trampling plant: dense on worn verges and yards,
##                        pressed flat there, crowded out of tall meadow
##   white clover       - creeping patches in short, grazed or scythed turf
##   red clover         - patches in the open, uncut meadow
##   dandelion          - short grass round settlement and roads, in drifts;
##                        flowering, seed clocks and leaf-only rosettes
##   burdock            - ruderal: the unmown strip at a wall foot and road
##                        edges, rosettes and tall flowering plants with burrs
## Patches come from fixed-seed noise, so the same ground always grows the same
## plants (deterministic per chunk, nothing saved).
##
## Drawing: one MultiMesh per model and detail level for the whole streamed
## area (two per model: near detail round the player, the far variant beyond),
## refilled by concatenating per-chunk instance buffers whenever the player
## enters a new chunk. That keeps forbs at about 16 draw calls instead of one
## per model per chunk.


const Meshes := preload("res://scripts/city/city_forb_meshes.gd")
const SHADER := preload("res://scripts/city/city_forb.gdshader")
## Vein and chevron detail drawn on UV2 (tools/assets/generate_forb_leaf_atlas.py).
const LEAF_DETAIL := preload("res://assets/vegetation/forbs/forb_leaf_detail.png")

const CHUNK := 8.0
const RADIUS_CHUNKS := 6
## Small plants shrink out over this range; beyond it a 4 cm flower head is
## under a pixel. Burdock stays visible as far as the mid grass.
const SMALL_FADE := Vector2(24.0, 32.0)
const LARGE_FADE := Vector2(38.0, 46.0)
## Chunks whose centre is within this distance of the player's chunk centre
## draw the near models; the rest draw the far variants.
const NEAR_RANGE := 13.0
## Chunk centre to corner, added to the fade ends when picking chunks to draw.
const CHUNK_MARGIN := 5.7
## Floats per instance in a MultiMesh buffer (3x4 transform + colour).
const STRIDE := 16
const LARGE_KINDS: Array[StringName] = [Meshes.KIND_BURDOCK, Meshes.KIND_BURDOCK_FLOWERING]

## Candidates per square metre at full suitability.
const MAX_DENSITY := {
	&"dandelion": 0.35,
	Meshes.KIND_PLANTAIN: 0.60,
	# Each white clover mat is a dense 70-leaf patch, so fewer are needed.
	Meshes.KIND_WHITE_CLOVER: 0.32,
	Meshes.KIND_RED_CLOVER: 0.40,
	&"burdock": 0.12,
}
## The city's grass blades are drawn larger than life, so the forbs are scaled
## up by this range to sit in proportion with them.
const SIZE_RANGE := Vector2(1.05, 1.45)

## Noise frequency (1/m) of each species' patches and the threshold window that
## turns it into patch edges.
const PATCH := {
	&"dandelion": [0.045, 0.30, 0.65],
	Meshes.KIND_PLANTAIN: [0.09, 0.15, 0.55],
	Meshes.KIND_WHITE_CLOVER: [0.11, 0.52, 0.66],
	Meshes.KIND_RED_CLOVER: [0.07, 0.52, 0.70],
	&"burdock": [0.06, 0.42, 0.60],
}

static var _noise: Dictionary = {}
static var _materials: Dictionary = {}

var grass: CityGrass
var _chunks: Dictionary = {}  # Vector2i -> {kind: PackedFloat32Array}
var _near: Dictionary = {}  # kind -> MultiMeshInstance3D
var _far: Dictionary = {}
var _centre := Vector2i(0x7fffffff, 0x7fffffff)
var _dirty := false


static func material(large: bool) -> ShaderMaterial:
	var key := "large" if large else "small"
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	m.shader = SHADER
	var fade: Vector2 = LARGE_FADE if large else SMALL_FADE
	m.set_shader_parameter("fade_start", fade.x)
	m.set_shader_parameter("fade_end", fade.y)
	m.set_shader_parameter("leaf_detail", LEAF_DETAIL)
	_materials[key] = m
	return m


## 0..1 patch field for a species at `p` (smooth simplex noise, fixed seed).
static func patch_at(species: StringName, p: Vector2) -> float:
	var noise: FastNoiseLite = _noise.get(species)
	if noise == null:
		noise = FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.seed = 1343 + hash(String(species)) % 10000
		noise.frequency = float(PATCH[species][0])
		_noise[species] = noise
	var n := noise.get_noise_2dv(p) * 0.5 + 0.5
	return smoothstep(float(PATCH[species][1]), float(PATCH[species][2]), n)


## How well `species` grows at `p`, 0..1, before the bare-ground test.
static func suitability(grass: CityGrass, species: StringName, p: Vector2) -> float:
	var patch := patch_at(species, p)
	if patch <= 0.0:
		return 0.0
	var wild := grass.wildness_at(p)
	match species:
		&"dandelion":
			return patch * (1.0 - 0.8 * smoothstep(0.3, 0.9, wild))
		Meshes.KIND_PLANTAIN:
			var verge := 1.0 - smoothstep(2.0, 9.0, grass.road_distance_at(p))
			var yard := 1.0 - smoothstep(1.5, 6.0, grass.house_distance_at(p))
			var worn := maxf(verge, yard * 0.8)
			return maxf(worn, 0.12) * maxf(patch, worn * 0.6) \
				* (1.0 - 0.9 * smoothstep(0.35, 0.85, wild))
		Meshes.KIND_WHITE_CLOVER:
			return patch * (1.0 - smoothstep(0.35, 0.8, wild))
		Meshes.KIND_RED_CLOVER:
			return patch * smoothstep(0.35, 0.85, wild)
		&"burdock":
			var wall := 1.0 - smoothstep(0.8, 4.5, grass.house_distance_at(p))
			var rd := grass.road_distance_at(p)
			var edge := smoothstep(1.2, 2.5, rd) * (1.0 - smoothstep(4.0, 8.0, rd))
			return patch * maxf(wall, edge * 0.6)
	return 0.0


static func create(city_grass: CityGrass) -> CityForbs:
	var node := CityForbs.new()
	node.name = "Forbs"
	node.grass = city_grass
	for kind: StringName in Meshes.ALL_KINDS:
		node._near[kind] = node._layer(kind, false)
		node._far[kind] = node._layer(kind, true)
	return node


func _layer(kind: StringName, far: bool) -> MultiMeshInstance3D:
	var inst := MultiMeshInstance3D.new()
	inst.name = "%s_%s" % [String(kind).to_pascal_case(), "Far" if far else "Near"]
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = Meshes.mesh_for(kind, far)
	inst.multimesh = multi
	inst.material_override = material(kind in LARGE_KINDS)
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)
	return inst


## Streams forb chunks round `world_xz` until `deadline_us` (at least one chunk
## unless `built_any`), then refills the layers if the chunk set or the
## player's chunk changed. Returns true while chunks are still missing.
func update_for(world_xz: Vector2, deadline_us: int, built_any: bool) -> bool:
	var centre := Vector2i(floori(world_xz.x / CHUNK), floori(world_xz.y / CHUNK))
	if centre != _centre:
		_centre = centre
		_dirty = true
		for key: Vector2i in _chunks.keys():
			if absi(key.x - centre.x) > RADIUS_CHUNKS + 1 or absi(key.y - centre.y) > RADIUS_CHUNKS + 1:
				_chunks.erase(key)
	var missing: Array[Vector2i] = []
	for dy in range(-RADIUS_CHUNKS, RADIUS_CHUNKS + 1):
		for dx in range(-RADIUS_CHUNKS, RADIUS_CHUNKS + 1):
			var key := centre + Vector2i(dx, dy)
			if not _chunks.has(key):
				missing.append(key)
	missing.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - centre).length_squared() < (b - centre).length_squared())
	var pending := false
	for key in missing:
		if built_any and Time.get_ticks_usec() >= deadline_us:
			pending = true
			break
		_chunks[key] = chunk_buffers(grass, key)
		built_any = true
		_dirty = true
	if _dirty:
		_refill()
		_dirty = false
	return pending


## Rebuilds every layer's instance buffer from the cached chunks (native array
## concatenation, no per-plant work).
func _refill() -> void:
	var centre_pos := (Vector2(_centre) + Vector2(0.5, 0.5)) * CHUNK
	var near_buf: Dictionary = {}
	var far_buf: Dictionary = {}
	for kind: StringName in Meshes.ALL_KINDS:
		near_buf[kind] = PackedFloat32Array()
		far_buf[kind] = PackedFloat32Array()
	for key: Vector2i in _chunks:
		var chunk: Dictionary = _chunks[key]
		if chunk.is_empty():
			continue
		var dist := ((Vector2(key) + Vector2(0.5, 0.5)) * CHUNK).distance_to(centre_pos)
		for kind: StringName in chunk:
			var reach := (LARGE_FADE.y if kind in LARGE_KINDS else SMALL_FADE.y) + CHUNK_MARGIN
			if dist > reach:
				continue
			var target: Dictionary = near_buf if dist <= NEAR_RANGE else far_buf
			# Packed arrays are values: append to the local copy and store it back.
			var merged: PackedFloat32Array = target[kind]
			merged.append_array(chunk[kind])
			target[kind] = merged
	for kind: StringName in Meshes.ALL_KINDS:
		_fill(_near[kind], near_buf[kind])
		_fill(_far[kind], far_buf[kind])


func _fill(inst: MultiMeshInstance3D, buffer: PackedFloat32Array) -> void:
	var multi := inst.multimesh
	multi.instance_count = buffer.size() / STRIDE
	if multi.instance_count > 0:
		multi.buffer = buffer
	inst.visible = multi.instance_count > 0


## Plants drawn by the near / far layer of `kind` (tests, benchmarks).
func instance_count(kind: StringName, far: bool) -> int:
	return ((_far if far else _near)[kind] as MultiMeshInstance3D).multimesh.instance_count


## Instance buffers of the forb chunk at `key`, by model: deterministic, pure
## data (MultiMesh buffer layout: 3x4 transform rows, then colour).
static func chunk_buffers(grass: CityGrass, key: Vector2i) -> Dictionary:
	var origin := Vector2(key) * CHUNK
	var out: Dictionary = {}
	for species: StringName in MAX_DENSITY:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(key) + hash(String(species)) * 31
		var count := int(CHUNK * CHUNK * float(MAX_DENSITY[species]))
		for i in count:
			var p := origin + Vector2(rng.randf(), rng.randf()) * CHUNK
			var roll := rng.randf()
			var pick := rng.randf()
			var yaw := rng.randf() * TAU
			var size := rng.randf_range(SIZE_RANGE.x, SIZE_RANGE.y)
			var tone := rng.randf_range(0.88, 1.08)
			# Cheap noise test first; road and wall probes only for survivors.
			var suit := suitability(grass, species, p)
			if suit <= 0.0 or roll >= suit:
				continue
			var bare := grass.bareness_at(p)
			# Plantain and dandelion take trodden ground, burdock the loose soil at a
			# wall foot; clover needs turf.
			var tolerance := 0.45
			if species in [Meshes.KIND_PLANTAIN, &"dandelion"]:
				tolerance = 0.85
			elif species == &"burdock" and grass.house_distance_at(p) < 2.5:
				tolerance = 0.8
			if bare > tolerance:
				continue
			var h := grass.plant_ground_height(p)
			if is_nan(h):
				continue
			var wild := grass.wildness_at(p)
			var kind := _kind_for(species, pick, wild)
			var flat := 1.0
			if species == Meshes.KIND_PLANTAIN:
				# Trodden plantain hugs the ground.
				flat = lerpf(0.55, 1.0, wild)
			elif species in [Meshes.KIND_RED_CLOVER, &"dandelion"]:
				# In tall grass they grow up to the light (red clover reaches 60 cm).
				# Scaled evenly: a vertical stretch turns round heads into thistles.
				size *= lerpf(1.0, 1.35 if species == Meshes.KIND_RED_CLOVER else 1.15, wild)
			var basis := Basis(Vector3.UP, yaw).scaled(Vector3(size, size * flat, size))
			var dust := clampf(bare * 1.4, 0.0, 1.0)
			var tint := Color(tone, tone, tone).lerp(Color(tone * 1.02, tone * 0.98, tone * 0.86), dust)
			var buf: PackedFloat32Array = out.get(kind, PackedFloat32Array())
			buf.append_array(_pack(Transform3D(basis, Vector3(p.x, h - 0.01, p.y)), tint))
			out[kind] = buf
	return out


## One instance in MultiMesh buffer layout (TRANSFORM_3D with colours).
static func _pack(t: Transform3D, c: Color) -> PackedFloat32Array:
	var b := t.basis
	return PackedFloat32Array([
		b.x.x, b.y.x, b.z.x, t.origin.x,
		b.x.y, b.y.y, b.z.y, t.origin.y,
		b.x.z, b.y.z, b.z.z, t.origin.z,
		c.r, c.g, c.b, c.a,
	])


## Which model of a species grows here. Dandelions: mostly in flower, some gone
## to seed, the rest leaf rosettes (mown before they flowered). Burdock flowers
## in its second year, and only where nobody cuts it.
static func _kind_for(species: StringName, pick: float, wild: float) -> StringName:
	match species:
		&"dandelion":
			if pick < 0.5:
				return Meshes.KIND_DANDELION_FLOWER
			return Meshes.KIND_DANDELION_CLOCK if pick < 0.72 else Meshes.KIND_DANDELION_LEAVES
		&"burdock":
			return Meshes.KIND_BURDOCK_FLOWERING if pick < 0.2 + 0.4 * wild else Meshes.KIND_BURDOCK
	return species
