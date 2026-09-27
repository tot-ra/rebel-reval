extends RefCounted

## Cached dry-terrain and blended-ground materials for the 3D map view.
##
## Terrain pattern arrays, cobble layers, and the splat shader live here so
## MapViewMaterials can remain the stable public facade for builders and tests.

const RESOLUTION := preload(
	"res://scripts/map/view3d/map_view_material_resolution_constants.gd"
)
const TEXTURE_SIZE := RESOLUTION.TEXTURE_SIZE
const COBBLE_TEXTURE_SIZE := RESOLUTION.COBBLE_TEXTURE_SIZE
const MUD_ALBEDO_PATH := "res://assets/materials/pbr/mud/mud_albedo.png"
const HAY_ALBEDO_PATH := "res://assets/materials/pbr/hay/hay_albedo.png"

const GRASS_ALBEDO_TEXTURE := preload("res://assets/materials/pbr/grass/grass_albedo.png")
const HAY_ALBEDO_TEXTURE := preload("res://assets/materials/pbr/hay/hay_albedo.png")
const TIMBER_FLOOR_ALBEDO_TEXTURE := preload(
	"res://assets/materials/pbr/timber_floor/timber_floor_albedo.png"
)
const SMITHY_FLOOR_ALBEDO_TEXTURE := preload(
	"res://assets/materials/pbr/smithy_floor/smithy_floor_albedo.png"
)

const WATER_TERRAINS := MapTypes.WATER_TERRAINS

## World units covered by one repeat of the terrain detail texture. Terrain
## meshes emit world-space UVs divided by this, so patterns run seamlessly
## across cell borders instead of restarting per cell.
const TERRAIN_TEXTURE_WORLD_SIZE := 4.0
## The authored grass plate carries broad blades that read oversized at the
## gameplay scale when left at the shared terrain repeat. Sample natural grass
## layers twice as densely so one visible repeat is about the frozen 2.0-unit
## character height, while paving and soil retain their existing world scale.
const TERRAIN_GRASS_UV_SCALE := 2.0

## The authored timber plate is broad enough to make boards read oversized at the
## gameplay camera when sampled at the shared 4.0-unit terrain repeat. Keep the
## blended-ground path aligned with the regular terrain material's 2x repeat.
const TERRAIN_TIMBER_FLOOR_UV_SCALE := 2.0

## Cobble is a seamless material family rather than authored map state: one
## high-resolution source seed serves every map, so transitions do not
## regenerate it per map seed.
const COBBLE_PLATE_SEED := 8219

const PATTERN_FAMILIES := preload(
	"res://scripts/map/view3d/map_view_material_pattern_families.gd"
)
const PATTERN_GRASS := PATTERN_FAMILIES.PATTERN_GRASS
const PATTERN_SPECKLE := PATTERN_FAMILIES.PATTERN_SPECKLE
const PATTERN_MUD := PATTERN_FAMILIES.PATTERN_MUD
const PATTERN_EARTH := PATTERN_FAMILIES.PATTERN_EARTH
const PATTERN_COBBLE := PATTERN_FAMILIES.PATTERN_COBBLE
const PATTERN_PLANK := PATTERN_FAMILIES.PATTERN_PLANK
const PATTERN_LIMESTONE := PATTERN_FAMILIES.PATTERN_LIMESTONE
const PATTERN_PLASTER := PATTERN_FAMILIES.PATTERN_PLASTER
const PATTERN_STRAW := PATTERN_FAMILIES.PATTERN_STRAW

const TERRAIN_PATTERN := {
	MapTypes.TERRAIN_GRASS: PATTERN_GRASS,
	MapTypes.TERRAIN_MEADOW: PATTERN_GRASS,
	MapTypes.TERRAIN_FOREST_FLOOR: PATTERN_GRASS,
	MapTypes.TERRAIN_BOG: PATTERN_GRASS,
	MapTypes.TERRAIN_HAY: PATTERN_STRAW,
	MapTypes.TERRAIN_STRAW: PATTERN_STRAW,
	MapTypes.TERRAIN_FARM_SOIL: PATTERN_STRAW,
	MapTypes.TERRAIN_DIRT: PATTERN_EARTH,
	MapTypes.TERRAIN_MUD: PATTERN_MUD,
	MapTypes.TERRAIN_SAND: PATTERN_SPECKLE,
	MapTypes.TERRAIN_COAST_SAND: PATTERN_SPECKLE,
	MapTypes.TERRAIN_ASH: PATTERN_SPECKLE,
	MapTypes.TERRAIN_COBBLESTONE: PATTERN_COBBLE,
	MapTypes.TERRAIN_CASTLE_PAVING: PATTERN_COBBLE,
	MapTypes.TERRAIN_STONE: PATTERN_LIMESTONE,
	MapTypes.TERRAIN_TIMBER_FLOOR: PATTERN_PLANK,
	MapTypes.TERRAIN_PLASTER: PATTERN_PLASTER,
}

## Denser tiling for paving so individual stones stay readable at gameplay zoom.
const TERRAIN_UV_SCALE := {
	MapTypes.TERRAIN_COBBLESTONE: 2.0,
	MapTypes.TERRAIN_CASTLE_PAVING: 2.0,
	MapTypes.TERRAIN_TIMBER_FLOOR: 2.0,
}

## Stable layer order for the blended-ground texture array. Indices must stay
## fixed so saved maps and tests do not reshuffle pattern lookups.
const BLEND_TERRAIN_ORDER: Array[StringName] = [
	MapTypes.TERRAIN_GRASS,
	MapTypes.TERRAIN_MEADOW,
	MapTypes.TERRAIN_FOREST_FLOOR,
	MapTypes.TERRAIN_BOG,
	MapTypes.TERRAIN_HAY,
	MapTypes.TERRAIN_STRAW,
	MapTypes.TERRAIN_FARM_SOIL,
	MapTypes.TERRAIN_DIRT,
	MapTypes.TERRAIN_MUD,
	MapTypes.TERRAIN_SAND,
	MapTypes.TERRAIN_COAST_SAND,
	MapTypes.TERRAIN_ASH,
	MapTypes.TERRAIN_COBBLESTONE,
	MapTypes.TERRAIN_CASTLE_PAVING,
	MapTypes.TERRAIN_STONE,
	MapTypes.TERRAIN_TIMBER_FLOOR,
	MapTypes.TERRAIN_PLASTER,
]

static var _cache: Dictionary = {}


static func reset() -> void:
	_cache.clear()


static func terrain(terrain_id: StringName, noise_seed: int) -> StandardMaterial3D:
	var key := "terrain:%s:%d" % [String(terrain_id), noise_seed]
	if _cache.has(key):
		return _cache[key]
	var base := OutdoorTerrainPalette.color(terrain_id)
	var material := _make_material(
		base, _terrain_material_pattern(terrain_id), noise_seed + int(terrain_id.hash())
	)
	var uv := float(TERRAIN_UV_SCALE.get(terrain_id, 1.0))
	material.uv1_scale = Vector3(uv, uv, 1.0)
	if WATER_TERRAINS.has(terrain_id):
		material.roughness = 0.15
	_cache[key] = material
	return material


static func _terrain_material_pattern(terrain_id: StringName) -> StringName:
	if WATER_TERRAINS.has(terrain_id):
		return PATTERN_PLASTER
	return TERRAIN_PATTERN.get(terrain_id, PATTERN_GRASS)


static func has_terrain(terrain_id: StringName, noise_seed: int) -> bool:
	return _cache.has("terrain:%s:%d" % [String(terrain_id), noise_seed])


static func has_blended_ground(noise_seed: int) -> bool:
	return _cache.has("blended_ground:%d" % noise_seed)


## WB-07d (R-1010): the pattern textures terrain(terrain_id, noise_seed) paints,
## as MapViewMaterialPatterns bake requests. Built from the same helpers as
## terrain(), so a pre-baked texture is exactly the one terrain() looks up.
static func terrain_bake_requests(terrain_id: StringName, noise_seed: int) -> Array[Dictionary]:
	var pattern := _terrain_material_pattern(terrain_id)
	return [
		MapViewMaterialPatterns.pattern_bake_request(
			pattern,
			noise_seed + int(terrain_id.hash()),
			MapViewMaterialPatterns.pattern_source_size(pattern)
		)
	]


## Authored plates terrain(terrain_id, ...) loads, for a threaded prefetch.
static func terrain_resource_paths(terrain_id: StringName) -> PackedStringArray:
	var paths := PackedStringArray()
	var path := MapViewMaterialPatterns.authored_plate_path(_terrain_material_pattern(terrain_id))
	if not path.is_empty():
		paths.append(path)
	return paths


## Authored plates blended_ground() loads outside the preloaded constants.
static func blended_ground_resource_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	for path: String in [MUD_ALBEDO_PATH, HAY_ALBEDO_PATH]:
		if ResourceLoader.exists(path):
			paths.append(path)
	return paths


## Every procedural texture blended_ground(noise_seed) paints: the procedural
## array layers plus the seed-independent cobble plate and cobble surface.
static func blended_ground_bake_requests(noise_seed: int) -> Array[Dictionary]:
	var requests: Array[Dictionary] = []
	for terrain_id in BLEND_TERRAIN_ORDER:
		if _procedural_layer(terrain_id):
			requests.append(_procedural_layer_request(terrain_id, noise_seed))
	requests.append(_cobble_plate_request())
	requests.append(MapViewMaterialPatterns.cobble_surface_bake_request(COBBLE_PLATE_SEED))
	return requests


static func terrain_blend_index(terrain_id: StringName) -> int:
	var index := BLEND_TERRAIN_ORDER.find(terrain_id)
	return index if index >= 0 else 0


static func smithy_floor_albedo_image() -> Image:
	var image := _copied_texture_image(SMITHY_FLOOR_ALBEDO_TEXTURE)
	if image.get_width() != TEXTURE_SIZE or image.get_height() != TEXTURE_SIZE:
		image.resize(TEXTURE_SIZE, TEXTURE_SIZE, Image.INTERPOLATE_LANCZOS)
	image.generate_mipmaps()
	return image


static func terrain_pattern_array(noise_seed: int) -> Texture2DArray:
	var key := "terrain_pattern_array:%d" % noise_seed
	if _cache.has(key):
		return _cache[key]
	var images: Array[Image] = []
	for terrain_id in BLEND_TERRAIN_ORDER:
		images.append(terrain_pattern_layer_image(terrain_id, noise_seed))
	publish_terrain_pattern_array(noise_seed, images)
	return _cache[key]


## WB-07d: one layer of terrain_pattern_array(). Main thread: authored layers
## read their plate back with Texture2D.get_image() and procedural layers read
## their cached pattern texture. Staged assembly runs one layer per unit.
static func terrain_pattern_layer_image(terrain_id: StringName, noise_seed: int) -> Image:
	var image: Image
	if (
		terrain_id
		in [
			MapTypes.TERRAIN_GRASS,
			MapTypes.TERRAIN_MEADOW,
			MapTypes.TERRAIN_FOREST_FLOOR,
			MapTypes.TERRAIN_BOG
		]
	):
		# Keep a low-res family copy in the shared array for fallbacks. The
		# blend shader samples the native 512 px grass plate directly so
		# meadows stay sharp at gameplay range.
		image = _copied_texture_image(GRASS_ALBEDO_TEXTURE)
		if image.get_width() != TEXTURE_SIZE or image.get_height() != TEXTURE_SIZE:
			image.resize(TEXTURE_SIZE, TEXTURE_SIZE, Image.INTERPOLATE_LANCZOS)
		image.generate_mipmaps()
	elif terrain_id == MapTypes.TERRAIN_MUD and ResourceLoader.exists(MUD_ALBEDO_PATH):
		image = _copied_texture_image(load(MUD_ALBEDO_PATH) as Texture2D)
		if image.get_width() != TEXTURE_SIZE or image.get_height() != TEXTURE_SIZE:
			image.resize(TEXTURE_SIZE, TEXTURE_SIZE, Image.INTERPOLATE_LANCZOS)
		image.generate_mipmaps()
	elif terrain_id == MapTypes.TERRAIN_TIMBER_FLOOR:
		# Interior/pier floors use the same texture-array tier as outdoor ground;
		# a separate source avoids stretching the directional grain across cells.
		image = _copied_texture_image(TIMBER_FLOOR_ALBEDO_TEXTURE)
		if image.get_width() != TEXTURE_SIZE or image.get_height() != TEXTURE_SIZE:
			image.resize(TEXTURE_SIZE, TEXTURE_SIZE, Image.INTERPOLATE_LANCZOS)
		image.generate_mipmaps()
	elif terrain_id == MapTypes.TERRAIN_STONE:
		# The smithy floor uses irregular flagstones rather than the procedural
		# limestone ashlar pattern, which reads as a tiled brick grid at gameplay zoom.
		image = smithy_floor_albedo_image()
	elif terrain_id in [MapTypes.TERRAIN_HAY, MapTypes.TERRAIN_STRAW]:
		# Keep a 128 px family copy in the shared array. The blend shader
		# samples the native 512 px hay plate so fields stay sharp.
		image = _copied_texture_image(HAY_ALBEDO_TEXTURE)
		if image.get_width() != TEXTURE_SIZE or image.get_height() != TEXTURE_SIZE:
			image.resize(TEXTURE_SIZE, TEXTURE_SIZE, Image.INTERPOLATE_LANCZOS)
		image.generate_mipmaps()
	else:
		var request := _procedural_layer_request(terrain_id, noise_seed)
		image = (
			MapViewMaterialPatterns
			. pattern_texture_at_size(request["pattern"], request["seed"], request["size"])
			. get_image()
		)
	return image


## Main thread. The first publisher of a seed wins.
static func publish_terrain_pattern_array(noise_seed: int, images: Array[Image]) -> void:
	var key := "terrain_pattern_array:%d" % noise_seed
	if _cache.has(key):
		return
	var array := Texture2DArray.new()
	array.create_from_images(images)
	_cache[key] = array


## Layers terrain_pattern_layer_image() paints procedurally rather than reading
## an authored plate. Must mirror its branches.
static func _procedural_layer(terrain_id: StringName) -> bool:
	if terrain_id == MapTypes.TERRAIN_MUD:
		return not ResourceLoader.exists(MUD_ALBEDO_PATH)
	return (
		terrain_id
		not in [
			MapTypes.TERRAIN_GRASS,
			MapTypes.TERRAIN_MEADOW,
			MapTypes.TERRAIN_FOREST_FLOOR,
			MapTypes.TERRAIN_BOG,
			MapTypes.TERRAIN_TIMBER_FLOOR,
			MapTypes.TERRAIN_STONE,
			MapTypes.TERRAIN_HAY,
			MapTypes.TERRAIN_STRAW,
		]
	)


static func _procedural_layer_request(terrain_id: StringName, noise_seed: int) -> Dictionary:
	var pattern: StringName = TERRAIN_PATTERN.get(terrain_id, PATTERN_GRASS)
	return MapViewMaterialPatterns.pattern_bake_request(
		pattern, noise_seed + int(terrain_id.hash()), TEXTURE_SIZE
	)


static func _cobble_plate_request() -> Dictionary:
	return MapViewMaterialPatterns.pattern_bake_request(
		PATTERN_COBBLE, COBBLE_PLATE_SEED, COBBLE_TEXTURE_SIZE
	)


## High-resolution paving layers are kept in a focused array so increasing
## cobble fidelity does not multiply the memory cost of every terrain family.
static func cobble_pattern_array(_noise_seed: int) -> Texture2DArray:
	var key := "cobble_pattern_array"
	if _cache.has(key):
		return _cache[key]
	var request := _cobble_plate_request()
	var image := (
		MapViewMaterialPatterns
		. pattern_texture_at_size(request["pattern"], request["seed"], request["size"])
		. get_image()
	)
	var images: Array[Image] = [image, image]
	var array := Texture2DArray.new()
	array.create_from_images(images)
	_cache[key] = array
	return array


## Single blended ground material for all dry terrain. Per-vertex CUSTOM0 and
## COLOR carry splat indices, blend weight, tone, and palette tint.
static func blended_ground(noise_seed: int) -> ShaderMaterial:
	var key := "blended_ground:%d" % noise_seed
	if _cache.has(key):
		return _cache[key]
	var material := ShaderMaterial.new()
	material.shader = MapViewMaterialShaders.shader_resource(
		"terrain_blend", MapViewMaterialShaders.TERRAIN_BLEND_SHADER
	)
	material.set_shader_parameter("terrain_patterns", terrain_pattern_array(noise_seed))
	material.set_shader_parameter("cobble_patterns", cobble_pattern_array(noise_seed))
	material.set_shader_parameter(
		"cobble_surface", MapViewMaterialPatterns.cobble_surface_texture(COBBLE_PLATE_SEED)
	)
	material.set_shader_parameter("pattern_layers", float(BLEND_TERRAIN_ORDER.size()))
	material.set_shader_parameter(
		"cobblestone_layer", terrain_blend_index(MapTypes.TERRAIN_COBBLESTONE)
	)
	material.set_shader_parameter(
		"castle_paving_layer", terrain_blend_index(MapTypes.TERRAIN_CASTLE_PAVING)
	)
	material.set_shader_parameter(
		"timber_floor_layer", terrain_blend_index(MapTypes.TERRAIN_TIMBER_FLOOR)
	)
	material.set_shader_parameter("mud_layer", terrain_blend_index(MapTypes.TERRAIN_MUD))
	# Trodden-ground relief band is derived from the stable blend order rather than
	# hard-coded in the shader, so reordering layers cannot silently unflatten grass
	# or flatten the street again.
	material.set_shader_parameter(
		"earth_layer_min", terrain_blend_index(MapTypes.TERRAIN_FARM_SOIL)
	)
	material.set_shader_parameter("earth_layer_max", terrain_blend_index(MapTypes.TERRAIN_ASH))
	material.set_shader_parameter("mud_wetness", 0.0)
	# WS-08 wet sand: only the two beach layers darken behind the swash.
	material.set_shader_parameter("sand_layer", terrain_blend_index(MapTypes.TERRAIN_SAND))
	material.set_shader_parameter(
		"coast_sand_layer", terrain_blend_index(MapTypes.TERRAIN_COAST_SAND)
	)
	material.set_shader_parameter("shore_field_valid", 0.0)
	material.set_shader_parameter("natural_ground_uv_scale", TERRAIN_GRASS_UV_SCALE)
	material.set_shader_parameter("natural_ground_variation", 0.72)
	material.set_shader_parameter("timber_floor_uv_scale", TERRAIN_TIMBER_FLOOR_UV_SCALE)
	# Sample authored plates at native resolution. The shared terrain array stays
	# at 128 px so procedural families do not pay a 16x paint cost.
	material.set_shader_parameter("grass_albedo", GRASS_ALBEDO_TEXTURE)
	material.set_shader_parameter("timber_floor_albedo", TIMBER_FLOOR_ALBEDO_TEXTURE)
	if ResourceLoader.exists(MUD_ALBEDO_PATH):
		material.set_shader_parameter("mud_albedo", load(MUD_ALBEDO_PATH))
		material.set_shader_parameter("use_authored_mud", 1.0)
	else:
		material.set_shader_parameter("use_authored_mud", 0.0)
	if ResourceLoader.exists(HAY_ALBEDO_PATH):
		material.set_shader_parameter("hay_albedo", load(HAY_ALBEDO_PATH))
		material.set_shader_parameter("use_authored_hay", 1.0)
		material.set_shader_parameter("hay_layer", terrain_blend_index(MapTypes.TERRAIN_HAY))
		material.set_shader_parameter("straw_layer", terrain_blend_index(MapTypes.TERRAIN_STRAW))
	else:
		material.set_shader_parameter("use_authored_hay", 0.0)
	_cache[key] = material
	return material


## Every cached blended-ground material, for per-map uniforms such as the WS-08
## shore field that must reach all ground materials at once.
static func blended_ground_materials() -> Array[ShaderMaterial]:
	var materials: Array[ShaderMaterial] = []
	for key: Variant in _cache.keys():
		if String(key).begins_with("blended_ground:"):
			materials.append(_cache[key] as ShaderMaterial)
	return materials


static func apply_mud_wetness(wetness: float) -> void:
	var value := clampf(wetness, 0.0, 1.0)
	for key: Variant in _cache.keys():
		if String(key).begins_with("blended_ground:"):
			(_cache[key] as ShaderMaterial).set_shader_parameter("mud_wetness", value)


## Headless Texture2D.get_image() aliases the stored Image. Resize/mipmap
## that object and the source plate itself shrinks for later readbacks.
static func _copied_texture_image(texture: Texture2D) -> Image:
	if texture == null:
		return Image.new()
	var image := texture.get_image()
	if image == null:
		return Image.new()
	return image.duplicate()


static func _make_material(base: Color, pattern: StringName, noise_seed: int) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = base
	material.albedo_texture = MapViewMaterialPatterns.pattern_texture(pattern, noise_seed)
	material.roughness = 1.0
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Terrain cells and scatter instances carry per-cell tone in vertex/instance
	# colors; meshes without a color attribute stay white so nothing shifts.
	material.vertex_color_use_as_albedo = true
	return material
