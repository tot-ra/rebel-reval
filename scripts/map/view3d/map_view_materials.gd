class_name MapViewMaterials
extends RefCounted

## Procedural placeholder materials for the P0-052 3D view layer.
## Every material derives from the frozen palette colors so the view never
## blocks on texture generation; the P0-051/P0-053 AI-generated textures
## replace only the albedo maps without changing this wiring.

const NOISE_TEXTURE_SIZE := 32
const NOISE_STRENGTH := 0.10
const EMBER_COLOR := Color8(224, 108, 48)
const EMBER_ENERGY := 1.6

const WATER_TERRAINS: Array[StringName] = [
	MapTypes.TERRAIN_WATER,
	MapTypes.TERRAIN_SHALLOW_WATER,
	MapTypes.TERRAIN_DEEP_WATER,
]

static var _cache: Dictionary = {}


static func reset() -> void:
	_cache.clear()


static func terrain(terrain_id: StringName, noise_seed: int) -> StandardMaterial3D:
	var key := "terrain:%s:%d" % [String(terrain_id), noise_seed]
	if _cache.has(key):
		return _cache[key]
	var base := OutdoorTerrainPalette.color(terrain_id)
	var material := _make_material(base, noise_seed + int(terrain_id.hash()))
	if WATER_TERRAINS.has(terrain_id):
		material.roughness = 0.15
	_cache[key] = material
	return material


static func wall(color: Color) -> StandardMaterial3D:
	return _tinted("wall", color)


static func roof(color: Color) -> StandardMaterial3D:
	return _tinted("roof", color)


## Prop surface materials keyed by the shared visual-style roles so the
## placeholder palette carries over from the approved clean-painted profile.
static func role(role_name: StringName) -> StandardMaterial3D:
	var key := "role:%s" % String(role_name)
	if _cache.has(key):
		return _cache[key]
	var base := MapVisualStyle.role_color(role_name, MapVisualStyle.TARGET_CLEAN_PAINTED, MapVisualStyle.TIME_DAY)
	var material := _make_material(base, int(role_name.hash()))
	match role_name:
		&"metal":
			material.metallic = 0.55
			material.roughness = 0.45
		&"water_highlight":
			material.roughness = 0.15
		&"ember":
			material.emission_enabled = true
			material.emission = EMBER_COLOR
			material.emission_energy_multiplier = EMBER_ENERGY
	_cache[key] = material
	return material


## Flat vegetation and landscape tints for the view-only scatter and treeline.
## Instance colors modulate these through vertex_color_use_as_albedo.
static func foliage_tuft() -> StandardMaterial3D:
	return _tinted("foliage_tuft", Color8(96, 122, 60))


static func foliage_spruce() -> StandardMaterial3D:
	return _tinted("foliage_spruce", Color8(56, 82, 54))


static func foliage_leaf() -> StandardMaterial3D:
	return _tinted("foliage_leaf", Color8(94, 116, 58))


static func bark() -> StandardMaterial3D:
	return _tinted("bark", Color8(74, 56, 42))


static func surroundings_ground() -> StandardMaterial3D:
	var key := "surroundings_ground"
	if _cache.has(key):
		return _cache[key]
	var material := _make_material(Color8(74, 88, 60), 8117)
	material.uv1_scale = Vector3(96.0, 96.0, 1.0)
	_cache[key] = material
	return material


## Soft unshaded billboard puff for chimney smoke; alpha comes from the
## particle color ramp.
static func smoke() -> StandardMaterial3D:
	var key := "smoke"
	if _cache.has(key):
		return _cache[key]
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(0.86, 0.85, 0.83, 1.0)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	_cache[key] = material
	return material


static func _tinted(prefix: String, color: Color) -> StandardMaterial3D:
	var key := "%s:%s" % [prefix, color.to_html()]
	if _cache.has(key):
		return _cache[key]
	var material := _make_material(color, int(key.hash()))
	_cache[key] = material
	return material


static func _make_material(base: Color, noise_seed: int) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = base
	material.albedo_texture = _noise_texture(noise_seed)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 1.0
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Terrain cells and scatter instances carry per-cell tone in vertex/instance
	# colors; meshes without a color attribute stay white so nothing shifts.
	material.vertex_color_use_as_albedo = true
	return material


## Deterministic grayscale detail texture; multiplies with albedo_color so the
## same texture serves every tint. Same hashing family as TerrainPalette.
static func _noise_texture(noise_seed: int) -> ImageTexture:
	var key := "noise:%d" % noise_seed
	if _cache.has(key):
		return _cache[key]
	var image := Image.create(NOISE_TEXTURE_SIZE, NOISE_TEXTURE_SIZE, false, Image.FORMAT_RGB8)
	for y in NOISE_TEXTURE_SIZE:
		for x in NOISE_TEXTURE_SIZE:
			var hash := ((x * 374761393) + (y * 668265263) + noise_seed) & 0x7fffffff
			var value := 1.0 - NOISE_STRENGTH + NOISE_STRENGTH * 2.0 * (float(hash % 1000) / 999.0)
			value = clampf(value, 0.0, 1.0)
			image.set_pixel(x, y, Color(value, value, value))
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture
