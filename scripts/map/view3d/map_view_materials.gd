class_name MapViewMaterials
extends RefCounted

## Procedural placeholder materials for the P0-052 3D view layer.
## Every material derives from the frozen palette colors so the view never
## blocks on texture generation; the P0-051/P0-053 AI-generated textures
## replace only the albedo maps without changing this wiring. Patterns are
## grayscale multipliers over the palette albedo so tinting stays palette-led.
##
## Shader sources and procedural pattern textures live in focused modules;
## this class keeps the public API stable for callers and tests.

const TEXTURE_SIZE := 128
## Cobblestone fills most of the gameplay frame at street level, so it needs a
## denser source than secondary materials to keep joints and stone grain sharp.
const COBBLE_TEXTURE_SIZE := 512
const EMBER_COLOR := Color8(224, 108, 48)
const EMBER_ENERGY := 1.6
const WATER_MATERIALS := preload("res://scripts/map/view3d/map_view_water_materials.gd")
const BUILDING_MATERIALS := preload("res://scripts/map/view3d/map_view_building_materials.gd")
const PROP_MATERIALS := preload("res://scripts/map/view3d/map_view_prop_materials.gd")
const HAY_FIBER_TEXTURE := preload("res://assets/materials/production/hay_fibers.png")
const GRASS_ALBEDO_TEXTURE := preload("res://assets/materials/pbr/grass/grass_albedo.png")
const TIMBER_FLOOR_ALBEDO_TEXTURE := preload(
	"res://assets/materials/pbr/timber_floor/timber_floor_albedo.png"
)
const SMITHY_FLOOR_ALBEDO_TEXTURE := preload(
	"res://assets/materials/pbr/smithy_floor/smithy_floor_albedo.png"
)
const FISHING_NET_HEMP_TEXTURE := preload(
	"res://assets/props/crafts/fishing_nets_TarredHempNet_albedo.png"
)
const FISHING_NET_FLOAT_TEXTURE := preload(
	"res://assets/props/crafts/fishing_nets_BarkCorkFloats_albedo.png"
)
const FISHING_NET_SINKER_TEXTURE := preload(
	"res://assets/props/crafts/fishing_nets_PiercedStoneSinkers_albedo.png"
)
const BLACK_CLOAKS_BANNER_TEXTURE := preload("res://assets/heraldry/black_cloaks_banner.png")

const WATER_WAVE_BASE := {
	MapTypes.TERRAIN_SHALLOW_WATER:
	{
		"height": 0.026,
		"chaos": 0.78,
		"foam": 0.24,
		"breakers": 0.52,
		"absorption": 5.0,
		"tide_height": 0.004,
		"tide_shore_retreat": 0.13,
		"tide_optical_depth": 0.055,
	},
	MapTypes.TERRAIN_DEEP_WATER:
	{
		"height": 0.044,
		"chaos": 1.18,
		"foam": 0.12,
		"breakers": 0.10,
		"absorption": 9.0,
		"tide_height": 0.004,
		"tide_shore_retreat": 0.0,
		"tide_optical_depth": 0.025,
	},
	MapTypes.TERRAIN_WATER:
	{
		"height": 0.030,
		"chaos": 0.96,
		"foam": 0.18,
		"breakers": 0.22,
		"absorption": 7.0,
		"bed_vegetation": 1.0,
		"tide_height": 0.0,
		"tide_shore_retreat": 0.0,
		"tide_optical_depth": 0.0,
	},
	# Fast river water uses tighter, livelier ripples than ponds or open sea and
	# drops the sheltered-water algae layer. Absorption sits higher than the old
	# clear-shallow tuning so the blue water column, not the warm bed, dominates
	# the surface colour - the Pirita should read as a river, not a green shallow.
	MapTypes.TERRAIN_RIVER_WATER:
	{
		"height": 0.024,
		"chaos": 0.72,
		"foam": 0.12,
		"breakers": 0.08,
		"absorption": 6.0,
		"bed_vegetation": 0.0,
		"tide_height": 0.0,
		"tide_shore_retreat": 0.0,
		"tide_optical_depth": 0.0,
	},
}

const WATER_TERRAINS: Array[StringName] = [
	MapTypes.TERRAIN_WATER,
	MapTypes.TERRAIN_RIVER_WATER,
	MapTypes.TERRAIN_SHALLOW_WATER,
	MapTypes.TERRAIN_DEEP_WATER,
]

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

## Pattern families for terrain and building surfaces.
const PATTERN_GRASS := &"grass"
const PATTERN_SPECKLE := &"speckle"
const PATTERN_MUD := &"mud"
const PATTERN_COBBLE := &"cobble"
const PATTERN_BRICK := &"brick"
const PATTERN_PLANK := &"plank"
const PATTERN_LIMESTONE := &"limestone"
## Weathered boulders and shoreline scatter: organic mottling without ashlar
## courses so sphere meshes do not read as brick bands at lake/sea edges.
const PATTERN_ROCK := &"rock"
const PATTERN_ROOF_TILE := &"roof_tile"
const PATTERN_PLASTER := &"plaster"
const PATTERN_STRAW := &"straw"
## Layered reed/straw thatch courses for roofs. Distinct from PATTERN_STRAW so
## hay/terrain scatter keeps its soft field look while roofs read as bundled reed.
const PATTERN_THATCH := &"thatch"
const PATTERN_SHINGLE := &"shingle"
const PATTERN_LOG := &"log"
const PATTERN_BARK := &"bark"
const PATTERN_BIRCH_BARK := &"birch_bark"
const PATTERN_CHERRY_BARK := &"cherry_bark"

## Deterministic building-surface weathering bands for P0-053. Each stable
## building ID maps to one variant so adjacent houses do not share treatment.
const WEATHER_FRESH := &"fresh"
const WEATHER_WORN := &"worn"
const WEATHER_DAMP := &"damp"
const WEATHER_REPAIRED := &"repaired"
const BUILDING_WEATHER_VARIANTS: Array[StringName] = [
	WEATHER_WORN,
	WEATHER_FRESH,
	WEATHER_DAMP,
	WEATHER_REPAIRED,
]

const TERRAIN_PATTERN := {
	MapTypes.TERRAIN_GRASS: PATTERN_GRASS,
	MapTypes.TERRAIN_MEADOW: PATTERN_GRASS,
	MapTypes.TERRAIN_FOREST_FLOOR: PATTERN_GRASS,
	MapTypes.TERRAIN_BOG: PATTERN_GRASS,
	MapTypes.TERRAIN_HAY: PATTERN_STRAW,
	MapTypes.TERRAIN_STRAW: PATTERN_STRAW,
	MapTypes.TERRAIN_FARM_SOIL: PATTERN_STRAW,
	MapTypes.TERRAIN_DIRT: PATTERN_SPECKLE,
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

## BoxMesh and CylinderMesh map UV 0-1 across each face. Without extra
## repeats, one procedural tile spans an entire house wall and bricks read
## billboard-sized. Values are tuned for typical 3-6 unit footprints at the
## frozen 32 px/cell scale (character height 2.0 units).
## Stretcher courses need more vertical UV repeats than horizontal ones so each
## block reads wider than tall (running bond, not soldier/stack bond).
const BUILDING_UV_SCALE := {
	PATTERN_BRICK: Vector3(5.0, 6.5, 5.0),
	PATTERN_LIMESTONE: Vector3(4.0, 6.0, 4.0),
	PATTERN_PLANK: Vector3(5.0, 3.0, 5.0),
	PATTERN_PLASTER: Vector3(3.5, 2.5, 3.5),
	PATTERN_ROOF_TILE: Vector3(4.0, 2.5, 4.0),
	PATTERN_SHINGLE: Vector3(5.0, 3.0, 5.0),
	PATTERN_LOG: Vector3(4.0, 3.0, 4.0),
	PATTERN_STRAW: Vector3(3.0, 2.0, 3.0),
	## Dense along-slope repeats so reed courses stay readable on fishing-hut
	## roofs at the dimetric gameplay distance.
	PATTERN_THATCH: Vector3(4.5, 5.5, 4.5),
}
## Reference box size the fixed BUILDING_UV_SCALE repeats were tuned against.
## building_uv_scale() scales repeats proportionally so long fortification
## walls keep brick and stone courses the same world size as house facades.
const BUILDING_UV_REFERENCE_SIZE := Vector3(4.0, 3.5, 4.0)

## Shader sources live in MapViewMaterialShaders; procedural textures in MapViewMaterialPatterns.
static var _cache: Dictionary = {}


static func reset() -> void:
	_cache.clear()
	MapViewMaterialShaders.reset()
	MapViewMaterialPatterns.reset()
	WATER_MATERIALS.reset()
	BUILDING_MATERIALS.reset()
	PROP_MATERIALS.reset()


static func terrain(terrain_id: StringName, noise_seed: int) -> StandardMaterial3D:
	var key := "terrain:%s:%d" % [String(terrain_id), noise_seed]
	if _cache.has(key):
		return _cache[key]
	var base := OutdoorTerrainPalette.color(terrain_id)
	var pattern: StringName = TERRAIN_PATTERN.get(terrain_id, PATTERN_GRASS)
	if WATER_TERRAINS.has(terrain_id):
		pattern = PATTERN_PLASTER
	var material := _make_material(base, pattern, noise_seed + int(terrain_id.hash()))
	var uv := float(TERRAIN_UV_SCALE.get(terrain_id, 1.0))
	material.uv1_scale = Vector3(uv, uv, 1.0)
	if WATER_TERRAINS.has(terrain_id):
		material.roughness = 0.15
	_cache[key] = material
	return material


static func terrain_blend_index(terrain_id: StringName) -> int:
	var index := BLEND_TERRAIN_ORDER.find(terrain_id)
	return index if index >= 0 else 0


static func smithy_floor_albedo_image() -> Image:
	var image := SMITHY_FLOOR_ALBEDO_TEXTURE.get_image()
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
			# Leonardo's grass albedo supplies the shared outdoor family while the
			# existing palette tint still differentiates meadow, bog, and woodland.
			image = GRASS_ALBEDO_TEXTURE.get_image()
			if image.get_width() != TEXTURE_SIZE or image.get_height() != TEXTURE_SIZE:
				image.resize(TEXTURE_SIZE, TEXTURE_SIZE, Image.INTERPOLATE_LANCZOS)
			image.generate_mipmaps()
		elif terrain_id == MapTypes.TERRAIN_TIMBER_FLOOR:
			# Interior/pier floors use the same texture-array tier as outdoor ground;
			# a separate source avoids stretching the directional grain across cells.
			image = TIMBER_FLOOR_ALBEDO_TEXTURE.get_image()
			if image.get_width() != TEXTURE_SIZE or image.get_height() != TEXTURE_SIZE:
				image.resize(TEXTURE_SIZE, TEXTURE_SIZE, Image.INTERPOLATE_LANCZOS)
			image.generate_mipmaps()
		elif terrain_id == MapTypes.TERRAIN_STONE:
			# The smithy floor uses irregular flagstones rather than the procedural
			# limestone ashlar pattern, which reads as a tiled brick grid at gameplay zoom.
			image = smithy_floor_albedo_image()
		elif terrain_id in [MapTypes.TERRAIN_HAY, MapTypes.TERRAIN_STRAW]:
			# Both harvested field layers use the same production fiber source; their
			# distinct palette tints still separate fresh hay from weathered stubble.
			image = HAY_FIBER_TEXTURE.get_image()
			if image.get_width() != TEXTURE_SIZE or image.get_height() != TEXTURE_SIZE:
				image.resize(TEXTURE_SIZE, TEXTURE_SIZE, Image.INTERPOLATE_LANCZOS)
			image.generate_mipmaps()
		else:
			var pattern: StringName = TERRAIN_PATTERN.get(terrain_id, PATTERN_GRASS)
			image = (
				MapViewMaterialPatterns
				. pattern_texture_at_size(
					pattern, noise_seed + int(terrain_id.hash()), TEXTURE_SIZE
				)
				. get_image()
			)
		images.append(image)
	var array := Texture2DArray.new()
	array.create_from_images(images)
	_cache[key] = array
	return array


## High-resolution paving layers are kept in a focused array so increasing
## cobble fidelity does not multiply the memory cost of every terrain family.
static func cobble_pattern_array(_noise_seed: int) -> Texture2DArray:
	var key := "cobble_pattern_array"
	if _cache.has(key):
		return _cache[key]
	var image := (
		MapViewMaterialPatterns
		. pattern_texture_at_size(PATTERN_COBBLE, 8219, COBBLE_TEXTURE_SIZE)
		. get_image()
	)
	# Cobble is a seamless material family rather than authored map state. Reuse
	# one high-resolution source so transitions do not regenerate it per map seed.
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
	material.shader = MapViewMaterialShaders.shader(
		"terrain_blend", MapViewMaterialShaders.TERRAIN_BLEND_SHADER_CODE
	)
	material.set_shader_parameter("terrain_patterns", terrain_pattern_array(noise_seed))
	material.set_shader_parameter("cobble_patterns", cobble_pattern_array(noise_seed))
	material.set_shader_parameter(
		"cobble_surface", MapViewMaterialPatterns.cobble_surface_texture(8219)
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
	material.set_shader_parameter("mud_wetness", 0.0)
	material.set_shader_parameter("natural_ground_uv_scale", TERRAIN_GRASS_UV_SCALE)
	material.set_shader_parameter("natural_ground_variation", 0.72)
	material.set_shader_parameter("timber_floor_uv_scale", TERRAIN_TIMBER_FLOOR_UV_SCALE)
	_cache[key] = material
	return material


static func apply_mud_wetness(wetness: float) -> void:
	var value := clampf(wetness, 0.0, 1.0)
	for key: Variant in _cache.keys():
		if String(key).begins_with("blended_ground:"):
			(_cache[key] as ShaderMaterial).set_shader_parameter("mud_wetness", value)


## Water material API remains here for existing map builders and tests. The
## implementation and its independent cache live in WATER_MATERIALS.
static func puddle_surface() -> ShaderMaterial:
	return WATER_MATERIALS.puddle_surface()


static func water_surface(terrain_id: StringName) -> ShaderMaterial:
	return WATER_MATERIALS.water_surface(terrain_id, WATER_WAVE_BASE)


static func apply_sea_weather(wind: float, rain: float) -> void:
	WATER_MATERIALS.apply_sea_weather(wind, rain, WATER_WAVE_BASE)


static func apply_water_lighting(sun_visibility: float, day_blend: float) -> void:
	WATER_MATERIALS.apply_water_lighting(sun_visibility, day_blend, WATER_WAVE_BASE)


static func apply_coastal_tide(level: float) -> void:
	WATER_MATERIALS.apply_coastal_tide(level, WATER_WAVE_BASE)


static func apply_water_sky_reflection(
	star_map: Texture2D,
	sun_direction: Vector3,
	moon_direction: Vector3,
	sun_visibility: float,
	moon_visibility: float,
	star_visibility: float,
	observer_latitude: float,
	sidereal_angle: float,
	sun_color: Color
) -> void:
	WATER_MATERIALS.apply_water_sky_reflection(
		star_map,
		sun_direction,
		moon_direction,
		sun_visibility,
		moon_visibility,
		star_visibility,
		observer_latitude,
		sidereal_angle,
		sun_color,
		WATER_WAVE_BASE
	)


## Pushes the shared world wind field into grass, canopy, sail, and flag cloth.
## Call alongside apply_sea_weather so vegetation and cloth match harbor boats.
static func apply_world_wind(direction: Vector2, strength: float) -> void:
	var dir := direction
	if dir.length_squared() < 0.0001:
		dir = Vector2(0.9285, 0.3714)
	else:
		dir = dir.normalized()
	var wind := clampf(strength, 0.0, 1.0)
	for material in _wind_materials():
		material.set_shader_parameter("wind_direction", dir)
		material.set_shader_parameter("wind_strength", wind)


static func _wind_materials() -> Array[ShaderMaterial]:
	return [
		grass_blades(),
		canopy(&"spruce"),
		canopy(&"pine"),
		canopy(&"leaf"),
		canopy(&"column"),
		canopy(&"orchard"),
		sail_cloth(),
		flag_cloth(),
		hanging_banner_cloth(),
		hanging_banner_cloth(BLACK_CLOAKS_BANNER_TEXTURE),
		fishing_net_hemp(),
		fishing_net_float(),
		fishing_net_sinker(),
	]


## Wind-swaying grass blade material; instance colors modulate the tint.
static func grass_blades() -> ShaderMaterial:
	var key := "grass_blades"
	if _cache.has(key):
		return _cache[key]
	var material := ShaderMaterial.new()
	material.shader = MapViewMaterialShaders.shader(
		"grass_character", MapViewMaterialShaders.GRASS_SHADER_CODE
	)
	material.set_shader_parameter("base_color", Color8(104, 130, 62))
	# Interaction starts off so maps without a player keep pure wind sway.
	material.set_shader_parameter("interact_strength", 0.0)
	material.set_shader_parameter("interact_radius", 0.65)
	material.set_shader_parameter("interact_center", Vector2.ZERO)
	material.set_shader_parameter("interact_push", Vector2.ZERO)
	_cache[key] = material
	return material


## Soft character parting for all grass MultiMeshes sharing grass_blades().
## center_xz / velocity_xz are world-space ground coordinates; tip displacement
## grows with speed so a walk opens a pocket and a run leaves a readable wake.
static func apply_grass_interaction(center_xz: Vector2, velocity_xz: Vector2) -> void:
	var material := grass_blades()
	var speed := velocity_xz.length()
	var push := Vector2.ZERO
	if speed > 0.02:
		push = velocity_xz / speed
	# Standing still still parts blades around the feet; motion adds wake amplitude.
	var tip_displace := clampf(0.10 + speed * 0.015, 0.10, 0.22)
	material.set_shader_parameter("interact_center", center_xz)
	material.set_shader_parameter("interact_push", push)
	material.set_shader_parameter("interact_strength", tip_displace)
	material.set_shader_parameter("interact_radius", 0.65)


## Clears character parting when no player rig is driving the view.
static func clear_grass_interaction() -> void:
	var material := grass_blades()
	material.set_shader_parameter("interact_strength", 0.0)
	material.set_shader_parameter("interact_push", Vector2.ZERO)


static func canopy(kind: StringName) -> ShaderMaterial:
	var key := "canopy:%s" % String(kind)
	if _cache.has(key):
		return _cache[key]
	var material := ShaderMaterial.new()
	material.shader = MapViewMaterialShaders.shader(
		"canopy", MapViewMaterialShaders.CANOPY_SHADER_CODE
	)
	match kind:
		&"spruce":
			material.set_shader_parameter("base_color", Color8(58, 84, 56))
			material.set_shader_parameter("sway_strength", 0.035)
		&"pine":
			material.set_shader_parameter("base_color", Color8(72, 96, 52))
			material.set_shader_parameter("sway_strength", 0.03)
		&"column":
			material.set_shader_parameter("base_color", Color8(108, 132, 62))
			material.set_shader_parameter("sway_strength", 0.07)
		&"orchard":
			material.set_shader_parameter("base_color", Color8(92, 128, 60))
			material.set_shader_parameter("sway_strength", 0.075)
		_:
			material.set_shader_parameter("base_color", Color8(96, 118, 60))
			material.set_shader_parameter("sway_strength", 0.06)
	_cache[key] = material
	return material


## Merchant square sail: hangs free along UV.y from the yard, billows with wind.
static func sail_cloth() -> ShaderMaterial:
	var key := "sail_cloth"
	if _cache.has(key):
		return _cache[key]
	var material := ShaderMaterial.new()
	material.shader = MapViewMaterialShaders.shader(
		"cloth", MapViewMaterialShaders.CLOTH_SHADER_CODE
	)
	material.set_shader_parameter("base_color", Color8(214, 208, 190))
	material.set_shader_parameter("sway_strength", 0.28)
	material.set_shader_parameter("free_edge", Vector2(0.0, 1.0))
	_cache[key] = material
	return material


## Tower pennants and other hoist-fixed cloth: free along UV.x toward the fly.
## Vertex COLOR carries faction heraldry; base stays near-white so charges read.
static func flag_cloth() -> ShaderMaterial:
	var key := "flag_cloth"
	if _cache.has(key):
		return _cache[key]
	var material := ShaderMaterial.new()
	material.shader = MapViewMaterialShaders.shader(
		"cloth", MapViewMaterialShaders.CLOTH_SHADER_CODE
	)
	material.set_shader_parameter("base_color", Color8(248, 246, 240))
	material.set_shader_parameter("sway_strength", 0.42)
	material.set_shader_parameter("free_edge", Vector2(1.0, 0.0))
	_cache[key] = material
	return material


## Vertical wall banners: pinned at the top rod, soft hem sway only.
## Pass an embroidered albedo for factions that ship a heraldry plate; otherwise
## vertex COLOR from FactionHeraldry.banner_mesh remains the charge source.
static func hanging_banner_cloth(albedo: Texture2D = null) -> ShaderMaterial:
	var keyed := "hanging_banner_cloth_textured" if albedo != null else "hanging_banner_cloth"
	if _cache.has(keyed):
		return _cache[keyed]
	var material := ShaderMaterial.new()
	material.shader = MapViewMaterialShaders.shader(
		"hanging_banner_cloth", MapViewMaterialShaders.HANGING_BANNER_CLOTH_SHADER_CODE
	)
	material.set_shader_parameter("base_color", Color8(248, 246, 240))
	material.set_shader_parameter("sway_strength", 0.035)
	material.set_shader_parameter("wind_strength", 0.08)
	material.set_shader_parameter("free_edge", Vector2(0.0, 1.0))
	if albedo != null:
		material.set_shader_parameter("albedo_texture", albedo)
		material.set_shader_parameter("use_albedo_texture", 1.0)
	else:
		# Unbound sampler2D is undefined on GLES; bind a 1x1 white plate.
		material.set_shader_parameter("albedo_texture", _white_albedo())
		material.set_shader_parameter("use_albedo_texture", 0.0)
	_cache[keyed] = material
	return material


static func faction_banner_albedo(faction_id: StringName) -> Texture2D:
	if faction_id == &"black_cloaks":
		return BLACK_CLOAKS_BANNER_TEXTURE
	return null


static func _white_albedo() -> Texture2D:
	var key := "white_albedo_1x1"
	if _cache.has(key):
		return _cache[key]
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture


## The rack stays rigid while all net-borne parts share one height-pinned wind
## shader. Separate textured materials preserve their maritime identities while
## the common deformation keeps outline rope, floats, and sinkers attached.
static func fishing_net_hemp() -> ShaderMaterial:
	return _fishing_net_wind_material(
		&"fishing_net_hemp", FISHING_NET_HEMP_TEXTURE, 0.098, 1.36, 0.17, 0.96
	)


static func fishing_net_float() -> ShaderMaterial:
	return _fishing_net_wind_material(
		&"fishing_net_float", FISHING_NET_FLOAT_TEXTURE, 0.098, 1.36, 0.17, 0.94
	)


static func fishing_net_sinker() -> ShaderMaterial:
	return _fishing_net_wind_material(
		&"fishing_net_sinker", FISHING_NET_SINKER_TEXTURE, 0.098, 1.36, 0.17, 0.98
	)


static func _fishing_net_wind_material(
	key_name: StringName,
	albedo: Texture2D,
	sway_strength: float,
	pin_height: float,
	pin_fade: float,
	roughness: float
) -> ShaderMaterial:
	var key := String(key_name)
	if _cache.has(key):
		return _cache[key]
	var material := ShaderMaterial.new()
	material.shader = MapViewMaterialShaders.shader(
		"fishing_net_wind", MapViewMaterialShaders.FISHING_NET_WIND_SHADER_CODE
	)
	material.set_shader_parameter("albedo_texture", albedo)
	material.set_shader_parameter("sway_strength", sway_strength)
	material.set_shader_parameter("pin_height", pin_height)
	material.set_shader_parameter("pin_fade", pin_fade)
	material.set_shader_parameter("surface_roughness", roughness)
	_cache[key] = material
	return material


## Building material API remains here for existing map builders and tests.
## Construction-specific caches, weathering, and UV rules live in BUILDING_MATERIALS.
static func wall(color: Color) -> StandardMaterial3D:
	return BUILDING_MATERIALS.wall(color)


static func wall_surface(family: StringName, color: Color) -> StandardMaterial3D:
	return BUILDING_MATERIALS.wall_surface(family, color)


static func wall_surface_for_size(
	family: StringName, color: Color, size: Vector3
) -> StandardMaterial3D:
	return BUILDING_MATERIALS.wall_surface_for_size(family, color, size)


static func wall_surface_for_building(
	surface_id: StringName, family: StringName, color: Color, size: Vector3
) -> StandardMaterial3D:
	return BUILDING_MATERIALS.wall_surface_for_building(surface_id, family, color, size)


static func roof_surface_for_building(
	surface_id: StringName, family: StringName, color: Color
) -> StandardMaterial3D:
	return BUILDING_MATERIALS.roof_surface_for_building(surface_id, family, color)


static func surface_weathering_variant(surface_id: StringName) -> StringName:
	return BUILDING_MATERIALS.surface_weathering_variant(surface_id)


static func building_pattern_seed(surface_id: StringName, pattern: StringName) -> int:
	return BUILDING_MATERIALS.building_pattern_seed(surface_id, pattern)


static func wall_surface_triplanar(family: StringName, color: Color) -> StandardMaterial3D:
	return BUILDING_MATERIALS.wall_surface_triplanar(family, color)


static func wall_for_size(color: Color, size: Vector3) -> StandardMaterial3D:
	return BUILDING_MATERIALS.wall_for_size(color, size)


static func roof(color: Color) -> StandardMaterial3D:
	return BUILDING_MATERIALS.roof(color)


static func roof_surface(family: StringName, color: Color) -> StandardMaterial3D:
	return BUILDING_MATERIALS.roof_surface(family, color)


static func building_uv_density(pattern: StringName) -> Vector3:
	return BUILDING_MATERIALS.building_uv_density(pattern)


static func building_uv_scale(pattern: StringName, size: Vector3) -> Vector3:
	return BUILDING_MATERIALS.building_uv_scale(pattern, size)


static func building_uv_scale_cylinder(
	pattern: StringName, radius: float, height: float
) -> Vector3:
	return BUILDING_MATERIALS.building_uv_scale_cylinder(pattern, radius, height)


## Prop, foliage, and smoke APIs remain here for existing builders and tests.
## Their independent cache lives in PROP_MATERIALS.
static func role(role_name: StringName) -> StandardMaterial3D:
	return PROP_MATERIALS.role(role_name)


static func natural_rock() -> StandardMaterial3D:
	return PROP_MATERIALS.natural_rock()


static func charcoal() -> StandardMaterial3D:
	return PROP_MATERIALS.charcoal()


static func hot_coal() -> StandardMaterial3D:
	return PROP_MATERIALS.hot_coal()


static func leather() -> StandardMaterial3D:
	return PROP_MATERIALS.leather()


static func role_for_size(role_name: StringName, size: Vector3) -> StandardMaterial3D:
	var material := role(role_name).duplicate()
	var pattern := PATTERN_PLASTER
	match role_name:
		&"wood", &"timber":
			pattern = PATTERN_PLANK
		&"stone":
			pattern = PATTERN_LIMESTONE
		_:
			return material
	material.uv1_scale = building_uv_scale(pattern, size)
	return material


static func door_wood(noise_seed: int) -> StandardMaterial3D:
	return PROP_MATERIALS.door_wood(noise_seed)


static func door_iron() -> StandardMaterial3D:
	return PROP_MATERIALS.door_iron()


static func foliage_tuft() -> StandardMaterial3D:
	return PROP_MATERIALS.foliage_tuft()


static func foliage_spruce() -> StandardMaterial3D:
	return PROP_MATERIALS.foliage_spruce()


static func foliage_leaf() -> StandardMaterial3D:
	return PROP_MATERIALS.foliage_leaf()


static func bark(kind: StringName = &"bark") -> StandardMaterial3D:
	return PROP_MATERIALS.bark(kind)


static func tree_fruit() -> StandardMaterial3D:
	return PROP_MATERIALS.tree_fruit()


static func surroundings_ground() -> StandardMaterial3D:
	return PROP_MATERIALS.surroundings_ground()


static func surroundings_town() -> StandardMaterial3D:
	return PROP_MATERIALS.surroundings_town()


static func smoke() -> StandardMaterial3D:
	return PROP_MATERIALS.smoke()


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
