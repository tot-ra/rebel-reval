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

## CO-01 (R-948): authored PBR ground families, in ground-array layer order. The
## blend shader indexes these layers by position (0 grass .. 4 shore_shingle), so
## the order is a stable contract. shore_shingle is a material family, not a
## MapTypes terrain: it is mixed into coast_sand and serves CO-02 scatter.
const GROUND_FAMILIES: Array[StringName] = [
	&"grass", &"mud", &"sand", &"coast_sand", &"shore_shingle"
]
const GROUND_MAP_TYPES: Array[StringName] = [&"albedo", &"normal", &"roughness"]
## Albedo ships at 2048 px; normal and roughness at 1024 px (storage decision in
## docs/reports/co01_coastal_ground_materials.md).
const GROUND_ALBEDO_TEXTURE_SIZE := 2048
const GROUND_SURFACE_TEXTURE_SIZE := 1024
## Terrains whose per-terrain StandardMaterial binds the authored PBR set instead
## of a procedural pattern (the retired sand speckle).
const AUTHORED_STANDARD_TERRAINS := {
	MapTypes.TERRAIN_SAND: &"sand",
	MapTypes.TERRAIN_COAST_SAND: &"coast_sand",
}
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

## The authored mud plate shows straw tufts, boot scuffs and cracks at roughly a
## one-metre ground patch. At the old 1.35 repeat one tile spread over ~3 units,
## so tufts read waist-high next to the 2.0-unit actor on the Town Hall square.
## 3.2 puts one tile at ~1.25 units; the shader's stochastic tile offsets keep
## the denser repeat from showing a grid when the camera zooms out.
const TERRAIN_MUD_UV_SCALE := 3.2

## Per-family repeat for the CO-01 ground arrays (grass, mud, sand, coast_sand),
## pushed to the blend shader so the regular terrain material cannot drift.
const GROUND_FAMILY_UV_SCALE := Vector4(1.0, TERRAIN_MUD_UV_SCALE, 1.5, 1.5)

## The authored timber plate is broad enough to make boards read oversized at the
## gameplay camera when sampled at the shared 4.0-unit terrain repeat. Keep the
## blended-ground path aligned with the regular terrain material's 2x repeat.
## The board-seamless plate holds 4 whole boards instead of ~6 (gap-to-gap crop
## in tools/process_leonardo_terrain_textures.py), so the repeat rises 2.0 -> 3.0
## to keep the same board width on the ground.
const TERRAIN_TIMBER_FLOOR_UV_SCALE := 3.0

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
	# Sand families render from their authored PBR plates. PATTERN_EARTH is only
	# the 128 px texture-array fallback layer, never the visible surface.
	MapTypes.TERRAIN_SAND: PATTERN_EARTH,
	MapTypes.TERRAIN_COAST_SAND: PATTERN_EARTH,
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
	var material: StandardMaterial3D
	var authored_family := _authored_standard_family(terrain_id)
	if authored_family != &"":
		material = _make_authored_ground_material(base, authored_family)
	else:
		material = _make_material(
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
	if _authored_standard_family(terrain_id) != &"":
		return []
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
	if _authored_standard_family(terrain_id) != &"":
		# CO-01 plates load synchronously; see blended_ground_resource_paths().
		return paths
	var path := MapViewMaterialPatterns.authored_plate_path(_terrain_material_pattern(terrain_id))
	if not path.is_empty():
		paths.append(path)
	return paths


## Authored plates blended_ground() loads outside the preloaded constants.
static func blended_ground_resource_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	# CO-01 ground plates are deliberately not prefetched on worker threads. A
	# threaded CompressedTexture2D load queues its RenderingServer initialize; when
	# a staged assembly is cancelled and the 2048 px plate is dropped before that
	# command runs, the server reports 'texture_2d_initialize: "t" is null'. The
	# arrays load them once on the main thread and stay cached until reset().
	for path: String in [HAY_ALBEDO_PATH]:
		if ResourceLoader.exists(path):
			paths.append(path)
	return paths


static func ground_plate_path(family: StringName, map_type: StringName) -> String:
	return "res://assets/materials/pbr/%s/%s_%s.png" % [family, family, map_type]


## True when every map of `family` is imported, so the shader may sample it.
static func has_ground_family(family: StringName) -> bool:
	for map_type in GROUND_MAP_TYPES:
		if not ResourceLoader.exists(ground_plate_path(family, map_type)):
			return false
	return true


## One Texture2DArray per map type, layers in GROUND_FAMILIES order. A missing
## family borrows layer 0 so the array keeps its shape; its use_authored_* flag
## stays off and the shader never samples that layer.
static func ground_texture_array(map_type: StringName) -> Texture2DArray:
	var key := "ground_array:%s" % map_type
	if _cache.has(key):
		return _cache[key]
	var images: Array[Image] = []
	for family in GROUND_FAMILIES:
		var path := ground_plate_path(family, map_type)
		if not has_ground_family(family):
			path = ground_plate_path(GROUND_FAMILIES[0], map_type)
		var texture := load(path) as Texture2D
		var image := texture.get_image() if texture != null else null
		if image == null or image.is_empty():
			push_error("CO-01 ground plate unreadable: %s" % path)
			return null
		images.append(image)
	images = _uniform_layer_images(images)
	var array := Texture2DArray.new()
	array.create_from_images(images)
	_cache[key] = array
	return array


## Texture2DArray needs one size, format and mip layout for every layer. The
## committed imports agree (see test_terrain_material_channels); a hand-edited
## sidecar that disagrees is repaired here, slowly, instead of failing the map.
static func _uniform_layer_images(images: Array[Image]) -> Array[Image]:
	var first := images[0]
	var uniform := true
	for image in images:
		if (
			image.get_format() != first.get_format()
			or image.get_size() != first.get_size()
			or image.has_mipmaps() != first.has_mipmaps()
		):
			uniform = false
	if uniform:
		return images
	push_warning("CO-01 ground plates disagree in import format; converting to RGBA8")
	var converted: Array[Image] = []
	for image in images:
		var copy := image.duplicate() as Image
		if copy.is_compressed():
			copy.decompress()
		copy.convert(Image.FORMAT_RGBA8)
		if copy.get_size() != first.get_size():
			copy.resize(first.get_width(), first.get_height(), Image.INTERPOLATE_LANCZOS)
		copy.generate_mipmaps()
		converted.append(copy)
	return converted


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
	if _ground_array_layer(terrain_id):
		# Grass, mud and sand families render per fragment from the CO-01 ground
		# arrays, so the shader never samples this layer. A shared neutral image
		# keeps the array shape without reading back a 2048 px VRAM-compressed
		# plate or creating a procedural texture per map seed.
		image = _neutral_layer_image()
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
	if _ground_array_layer(terrain_id):
		return false
	return (
		terrain_id
		not in [
			MapTypes.TERRAIN_TIMBER_FLOOR,
			MapTypes.TERRAIN_STONE,
			MapTypes.TERRAIN_HAY,
			MapTypes.TERRAIN_STRAW,
		]
	)


## Terrain layers the blend shader always reads from the CO-01 ground arrays.
## Must mirror accumulate_layer() in map_view_terrain_blend.gdshader.
static func _ground_array_layer(terrain_id: StringName) -> bool:
	match terrain_id:
		MapTypes.TERRAIN_GRASS, MapTypes.TERRAIN_MEADOW:
			return true
		MapTypes.TERRAIN_FOREST_FLOOR, MapTypes.TERRAIN_BOG:
			return true
		MapTypes.TERRAIN_MUD:
			return has_ground_family(&"mud")
		MapTypes.TERRAIN_SAND:
			return has_ground_family(&"sand")
		MapTypes.TERRAIN_COAST_SAND:
			return has_ground_family(&"coast_sand")
	return false


static func _neutral_layer_image() -> Image:
	var key := "neutral_layer_image"
	if not _cache.has(key):
		var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGB8)
		image.fill(Color(0.9, 0.9, 0.9))
		image.generate_mipmaps()
		_cache[key] = image
	return (_cache[key] as Image).duplicate()


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
	material.set_shader_parameter("dirt_layer", terrain_blend_index(MapTypes.TERRAIN_DIRT))
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
	material.set_shader_parameter("ground_uv_scale", GROUND_FAMILY_UV_SCALE)
	material.set_shader_parameter("natural_ground_variation", 0.72)
	material.set_shader_parameter("timber_floor_uv_scale", TERRAIN_TIMBER_FLOOR_UV_SCALE)
	# Sample authored plates at native resolution. The shared terrain array stays
	# at 128 px so procedural families do not pay a 16x paint cost.
	material.set_shader_parameter("timber_floor_albedo", TIMBER_FLOOR_ALBEDO_TEXTURE)
	# CO-01: five PBR ground families in three arrays, sampled per fragment.
	material.set_shader_parameter("ground_albedo", ground_texture_array(&"albedo"))
	material.set_shader_parameter("ground_normal", ground_texture_array(&"normal"))
	material.set_shader_parameter("ground_roughness", ground_texture_array(&"roughness"))
	material.set_shader_parameter("use_authored_mud", _flag(has_ground_family(&"mud")))
	material.set_shader_parameter("use_authored_sand", _flag(has_ground_family(&"sand")))
	material.set_shader_parameter(
		"use_authored_coast_sand", _flag(has_ground_family(&"coast_sand"))
	)
	material.set_shader_parameter(
		"use_authored_shingle", _flag(has_ground_family(&"shore_shingle"))
	)
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
static func _flag(value: bool) -> float:
	return 1.0 if value else 0.0


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


static func _authored_standard_family(terrain_id: StringName) -> StringName:
	var family: StringName = AUTHORED_STANDARD_TERRAINS.get(terrain_id, &"")
	if family == &"" or not has_ground_family(family):
		return &""
	return family


## Per-terrain PBR material for the sand families (backdrop and single-terrain
## meshes). The plate carries its own colour, so the palette only nudges it, as
## the blend shader does for its realistic layers.
static func _make_authored_ground_material(base: Color, family: StringName) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE.lerp(base, 0.35)
	material.albedo_texture = load(ground_plate_path(family, &"albedo"))
	material.normal_enabled = true
	material.normal_texture = load(ground_plate_path(family, &"normal"))
	material.normal_scale = 0.6
	material.roughness = 1.0
	material.roughness_texture = load(ground_plate_path(family, &"roughness"))
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material


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
