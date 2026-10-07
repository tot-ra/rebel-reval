class_name CityGrass
extends Node3D

## Grass tufts and wild flowers streamed in chunks around Kalev (ADR 0031).
## Each chunk scatters wind-animated tufts (the shared grass-blade material)
## on grass and verge ground, thinning on trodden earth and leaving paving,
## floors, water and steep banks bare. Deterministic per chunk.

const CHUNK := 16.0
const RADIUS_CHUNKS := 3
const DENSITY := 2.2  # tufts per square world unit on full grass

var plan: CityPlan
var _splat: Image
var _chunks: Dictionary = {}
var _mesh: Mesh
var _material: Material


static func create(city_plan: CityPlan) -> CityGrass:
	var node := CityGrass.new()
	node.name = "Grass"
	node.plan = city_plan
	node._splat = (load(CityPlan.SPLAT_PATH) as Texture2D).get_image()
	if node._splat.is_compressed():
		node._splat.decompress()
	node._mesh = MapViewMeshBuilderPrimitives.grass_tuft_mesh()
	node._material = MapViewMaterials.grass_blades()
	return node


func update_for(world_xz: Vector2) -> void:
	var center := Vector2i(floori(world_xz.x / CHUNK), floori(world_xz.y / CHUNK))
	var wanted := {}
	for dy in range(-RADIUS_CHUNKS, RADIUS_CHUNKS + 1):
		for dx in range(-RADIUS_CHUNKS, RADIUS_CHUNKS + 1):
			var key := center + Vector2i(dx, dy)
			wanted[key] = true
			if not _chunks.has(key):
				_chunks[key] = _build_chunk(key)
				return  # at most one new chunk per frame
	for key: Vector2i in _chunks.keys():
		if not wanted.has(key):
			var node: Node = _chunks[key]
			if node != null:
				node.queue_free()
			_chunks.erase(key)


## Surface weights at a world position: (paving, earth, sand, mud), 0..1.
func surface_at(world_xz: Vector2) -> Color:
	var p := (world_xz - plan.bounds.position) / plan.bounds.size * Vector2(_splat.get_size())
	var x := clampi(int(p.x), 0, _splat.get_width() - 1)
	var y := clampi(int(p.y), 0, _splat.get_height() - 1)
	return _splat.get_pixel(x, y)


func _build_chunk(key: Vector2i) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var count := int(CHUNK * CHUNK * DENSITY)
	var origin := Vector2(key) * CHUNK
	for i in count:
		var p := origin + Vector2(rng.randf(), rng.randf()) * CHUNK
		var s := surface_at(p)
		var bare := maxf(s.r * 1.6, maxf(s.b, s.a * 0.9)) + s.g * 0.75
		if rng.randf() < bare:
			continue
		var h := plan.ground_height(p)
		if (
			h < 0.4
			or plan.slope_at(p) > 0.75
			or plan.building_at(p) >= 0
			or plan.site_at(p) != null
		):
			continue
		var scale := rng.randf_range(0.55, 1.15)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(
			Vector3(scale, scale * rng.randf_range(0.8, 1.3), scale)
		)
		transforms.append(Transform3D(basis, Vector3(p.x, h - 0.02, p.y)))
		var tone := rng.randf_range(0.82, 1.08)
		colors.append(Color(tone, tone * rng.randf_range(0.95, 1.05), tone * 0.9, 1.0))
	if transforms.is_empty():
		return null
	var inst := MapViewMeshBuilderPrimitives.multi_mesh(
		"Grass_%d_%d" % [key.x, key.y], _mesh, transforms, colors, _material, Vector3.ZERO
	)
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)
	return inst
