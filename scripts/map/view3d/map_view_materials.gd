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

const RESOLUTION := preload(
	"res://scripts/map/view3d/map_view_material_resolution_constants.gd"
)
const TEXTURE_SIZE := RESOLUTION.TEXTURE_SIZE
const COBBLE_TEXTURE_SIZE := RESOLUTION.COBBLE_TEXTURE_SIZE
const NATURAL_GROUND_TEXTURE_SIZE := RESOLUTION.NATURAL_GROUND_TEXTURE_SIZE
const MASONRY_TEXTURE_SIZE := RESOLUTION.MASONRY_TEXTURE_SIZE
const WATER_MATERIALS := preload("res://scripts/map/view3d/map_view_water_materials.gd")
const SHORE_MATERIALS := preload("res://scripts/map/view3d/map_view_shore_materials.gd")
const WIND_MATERIALS := preload("res://scripts/map/view3d/map_view_wind_materials.gd")
const TERRAIN_MATERIALS := preload("res://scripts/map/view3d/map_view_terrain_materials.gd")
const SKY_WEATHER := preload("res://scripts/map/view3d/sky_weather_3d.gd")
const BUILDING_MATERIALS := preload("res://scripts/map/view3d/map_view_building_materials.gd")
const PROP_MATERIALS := preload("res://scripts/map/view3d/map_view_prop_materials.gd")
const PATTERN_FAMILIES := preload(
	"res://scripts/map/view3d/map_view_material_pattern_families.gd"
)
## Re-exported so water contract tests and builders keep a stable facade API.
const WATER_WAVE_BASE := WATER_MATERIALS.WATER_WAVE_BASE
const WATER_TERRAINS := WATER_MATERIALS.WATER_TERRAINS

## Dry-terrain repeat and blend tables remain on the facade for mesh builders
## and tests. Implementation and caches live in TERRAIN_MATERIALS.
const TERRAIN_TEXTURE_WORLD_SIZE := TERRAIN_MATERIALS.TERRAIN_TEXTURE_WORLD_SIZE
const TERRAIN_GRASS_UV_SCALE := TERRAIN_MATERIALS.TERRAIN_GRASS_UV_SCALE
const TERRAIN_TIMBER_FLOOR_UV_SCALE := TERRAIN_MATERIALS.TERRAIN_TIMBER_FLOOR_UV_SCALE
const TERRAIN_PATTERN := TERRAIN_MATERIALS.TERRAIN_PATTERN
const TERRAIN_UV_SCALE := TERRAIN_MATERIALS.TERRAIN_UV_SCALE
const BLEND_TERRAIN_ORDER: Array[StringName] = TERRAIN_MATERIALS.BLEND_TERRAIN_ORDER

## Pattern family IDs live in PATTERN_FAMILIES; re-exported for the stable facade.
const PATTERN_GRASS := PATTERN_FAMILIES.PATTERN_GRASS
const PATTERN_SPECKLE := PATTERN_FAMILIES.PATTERN_SPECKLE
const PATTERN_MUD := PATTERN_FAMILIES.PATTERN_MUD
const PATTERN_EARTH := PATTERN_FAMILIES.PATTERN_EARTH
const PATTERN_COBBLE := PATTERN_FAMILIES.PATTERN_COBBLE
const PATTERN_BRICK := PATTERN_FAMILIES.PATTERN_BRICK
const PATTERN_PLANK := PATTERN_FAMILIES.PATTERN_PLANK
const PATTERN_LIMESTONE := PATTERN_FAMILIES.PATTERN_LIMESTONE
const PATTERN_ROCK := PATTERN_FAMILIES.PATTERN_ROCK
const PATTERN_ROOF_TILE := PATTERN_FAMILIES.PATTERN_ROOF_TILE
const PATTERN_PLASTER := PATTERN_FAMILIES.PATTERN_PLASTER
const PATTERN_STRAW := PATTERN_FAMILIES.PATTERN_STRAW
const PATTERN_THATCH := PATTERN_FAMILIES.PATTERN_THATCH
const PATTERN_SHINGLE := PATTERN_FAMILIES.PATTERN_SHINGLE
const PATTERN_LOG := PATTERN_FAMILIES.PATTERN_LOG
const PATTERN_BARK := PATTERN_FAMILIES.PATTERN_BARK
const PATTERN_BIRCH_BARK := PATTERN_FAMILIES.PATTERN_BIRCH_BARK
const PATTERN_CHERRY_BARK := PATTERN_FAMILIES.PATTERN_CHERRY_BARK

## Building weathering bands and UV repeat tables live in BUILDING_MATERIALS.
## Re-exported here so tests and pattern code keep the stable MapViewMaterials API.
const WEATHER_FRESH := BUILDING_MATERIALS.WEATHER_FRESH
const WEATHER_WORN := BUILDING_MATERIALS.WEATHER_WORN
const WEATHER_DAMP := BUILDING_MATERIALS.WEATHER_DAMP
const WEATHER_REPAIRED := BUILDING_MATERIALS.WEATHER_REPAIRED
const BUILDING_WEATHER_VARIANTS: Array[StringName] = BUILDING_MATERIALS.BUILDING_WEATHER_VARIANTS
const BUILDING_UV_SCALE := BUILDING_MATERIALS.BUILDING_UV_SCALE
const BUILDING_UV_REFERENCE_SIZE := BUILDING_MATERIALS.BUILDING_UV_REFERENCE_SIZE
const METERS_PER_WORLD_UNIT := BUILDING_MATERIALS.METERS_PER_WORLD_UNIT
const ROOF_TILE_WORLD_DENSITY := BUILDING_MATERIALS.ROOF_TILE_WORLD_DENSITY
const ROOF_SHINGLE_WORLD_DENSITY := BUILDING_MATERIALS.ROOF_SHINGLE_WORLD_DENSITY
const ROOF_THATCH_WORLD_DENSITY := BUILDING_MATERIALS.ROOF_THATCH_WORLD_DENSITY

## WS-08 shore tables live in SHORE_MATERIALS. Re-exported so tests and docs
## keep the stable MapViewMaterials facade.
const SHORE_STRENGTH_BY_TERRAIN := SHORE_MATERIALS.SHORE_STRENGTH_BY_TERRAIN
const SHORE_TIDE_SHIFT := SHORE_MATERIALS.SHORE_TIDE_SHIFT

## CO-02 shore debris surface families -> [albedo, normal, roughness] plates.
## The GLBs carry only named slots so a coast shares one material per family.
## Shingle reuses the CO-01 shore_shingle plate.
const SHORE_DEBRIS_DIR := "res://assets/props/environment/shore/"
const SHORE_DEBRIS_PLATES := {
	&"shore_granite":
	[
		SHORE_DEBRIS_DIR + "shore_granite_albedo.png",
		SHORE_DEBRIS_DIR + "shore_granite_normal.png",
		SHORE_DEBRIS_DIR + "shore_granite_roughness.png",
	],
	&"shore_barnacle":
	[
		SHORE_DEBRIS_DIR + "shore_barnacle_albedo.png",
		SHORE_DEBRIS_DIR + "shore_barnacle_normal.png",
		SHORE_DEBRIS_DIR + "shore_barnacle_roughness.png",
	],
	&"shore_limestone":
	[
		SHORE_DEBRIS_DIR + "shore_limestone_albedo.png",
		SHORE_DEBRIS_DIR + "shore_limestone_normal.png",
		SHORE_DEBRIS_DIR + "shore_limestone_roughness.png",
	],
	&"shore_shingle":
	[
		"res://assets/materials/pbr/shore_shingle/shore_shingle_albedo.png",
		"res://assets/materials/pbr/shore_shingle/shore_shingle_normal.png",
		"res://assets/materials/pbr/shore_shingle/shore_shingle_roughness.png",
	],
	&"shore_wrack":
	[
		SHORE_DEBRIS_DIR + "shore_wrack_albedo.png",
		SHORE_DEBRIS_DIR + "shore_wrack_normal.png",
		SHORE_DEBRIS_DIR + "shore_wrack_roughness.png",
	],
	&"shore_algae":
	[
		SHORE_DEBRIS_DIR + "shore_algae_albedo.png",
		SHORE_DEBRIS_DIR + "shore_algae_normal.png",
		SHORE_DEBRIS_DIR + "shore_algae_roughness.png",
	],
}
## Thin drift and weed are single sheets seen from both sides.
const SHORE_DEBRIS_TWO_SIDED: Array[StringName] = [&"shore_wrack", &"shore_algae"]
## Flat dressing fades its rim through vertex alpha. Blended, not hashed: the
## Compatibility renderer resolved the hash to a hard cut-out edge on the sand.
const SHORE_DEBRIS_ALPHA_RIM: Array[StringName] = [&"shore_shingle", &"shore_wrack"]
## Weed is seen through the WS-13 underwater pass, which composites from depth:
## blended surfaces write none and vanish there, so the skirt cuts its ragged lip.
const SHORE_DEBRIS_ALPHA_CUT: Array[StringName] = [&"shore_algae"]

static var _shore_debris_materials: Dictionary = {}

## Shader sources live in MapViewMaterialShaders; procedural textures in MapViewMaterialPatterns.


static func reset() -> void:
	MapViewMaterialShaders.reset()
	MapViewMaterialPatterns.reset()
	WATER_MATERIALS.reset()
	SHORE_MATERIALS.reset()
	WIND_MATERIALS.reset()
	TERRAIN_MATERIALS.reset()
	BUILDING_MATERIALS.reset()
	PROP_MATERIALS.reset()
	_shore_debris_materials.clear()


## One cached PBR material per shore debris family; unknown families get null so
## a mistyped slot fails loudly in tests instead of rendering untextured.
static func shore_debris(surface: StringName) -> StandardMaterial3D:
	if _shore_debris_materials.has(surface):
		return _shore_debris_materials[surface]
	if not SHORE_DEBRIS_PLATES.has(surface):
		return null
	var plates: Array = SHORE_DEBRIS_PLATES[surface]
	var material := StandardMaterial3D.new()
	material.resource_name = String(surface)
	material.albedo_texture = load(plates[0]) as Texture2D
	material.normal_enabled = true
	material.normal_texture = load(plates[1]) as Texture2D
	material.normal_scale = 1.0
	material.roughness = 1.0
	material.roughness_texture = load(plates[2]) as Texture2D
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE
	# MultiMesh instance colours carry the per-stone tint and wetness darkening.
	material.vertex_color_use_as_albedo = true
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if surface in SHORE_DEBRIS_TWO_SIDED:
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if surface in SHORE_DEBRIS_ALPHA_RIM:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	elif surface in SHORE_DEBRIS_ALPHA_CUT:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.4
	_shore_debris_materials[surface] = material
	return material


## Dry-terrain and blended-ground APIs remain here for existing builders and
## tests. Their independent cache lives in TERRAIN_MATERIALS.
static func terrain(terrain_id: StringName, noise_seed: int) -> StandardMaterial3D:
	return TERRAIN_MATERIALS.terrain(terrain_id, noise_seed)


static func terrain_blend_index(terrain_id: StringName) -> int:
	return TERRAIN_MATERIALS.terrain_blend_index(terrain_id)


static func smithy_floor_albedo_image() -> Image:
	return TERRAIN_MATERIALS.smithy_floor_albedo_image()


static func terrain_pattern_array(noise_seed: int) -> Texture2DArray:
	return TERRAIN_MATERIALS.terrain_pattern_array(noise_seed)


static func cobble_pattern_array(noise_seed: int) -> Texture2DArray:
	return TERRAIN_MATERIALS.cobble_pattern_array(noise_seed)


static func blended_ground(noise_seed: int) -> ShaderMaterial:
	return TERRAIN_MATERIALS.blended_ground(noise_seed)


static func apply_mud_wetness(wetness: float) -> void:
	TERRAIN_MATERIALS.apply_mud_wetness(wetness)


## Applies every weather-facing material input from one typed frame snapshot. This
## adapter is intentionally the only path that fans a weather transition out to
## water, wet ground, and world wind, preventing per-system sampling drift.
static func apply_weather_presentation(
	presentation: SKY_WEATHER.WeatherPresentation
) -> void:
	if presentation == null:
		return
	apply_sea_weather(
		presentation.wind_strength, presentation.rain_intensity, presentation.wind_direction
	)
	apply_mud_wetness(presentation.puddle_wetness)
	apply_world_wind(presentation.wind_direction, presentation.wind_strength)


## Water material API remains here for existing map builders and tests. The
## implementation and its independent cache live in WATER_MATERIALS.
static func puddle_surface() -> ShaderMaterial:
	return WATER_MATERIALS.puddle_surface()


static func water_surface(terrain_id: StringName) -> ShaderMaterial:
	return WATER_MATERIALS.water_surface(terrain_id, WATER_WAVE_BASE)


static func apply_sea_weather(
	wind: float, rain: float, wind_direction: Vector2 = Vector2(1.0, 0.28)
) -> void:
	WATER_MATERIALS.apply_sea_weather(wind, rain, WATER_WAVE_BASE, wind_direction)
	# WS-08: the shore wave sets read the same scalar sea state as the FFT table,
	# so a storm lengthens run-up on the water and the wet band on the sand together.
	SHORE_MATERIALS.apply_sea_state(wind, rain)


static func apply_water_lighting(sun_visibility: float, day_blend: float) -> void:
	WATER_MATERIALS.apply_water_lighting(sun_visibility, day_blend, WATER_WAVE_BASE)


static func apply_coastal_tide(level: float) -> void:
	WATER_MATERIALS.apply_coastal_tide(level, WATER_WAVE_BASE)
	SHORE_MATERIALS.apply_tide(level)


## WS-08: binds one map's shore distance field to every material that draws the
## shore. A null texture (no sea, interiors) turns every swash path off.
static func apply_shore_field(texture: Texture2D, origin: Vector2, size: Vector2) -> void:
	SHORE_MATERIALS.apply_shore_field(texture, origin, size)


## R-1160: binds one map's river channel centreline, so the current follows the
## meander and slows at the banks. An empty path restores the single heading.
static func apply_river_flow(path: PackedVector3Array) -> void:
	WATER_MATERIALS.apply_river_flow(path)


## Minimum tier drops the sheet mesh but keeps the bore foam and wet sand. Like the
## FFT cascades, the tier applies to map views built afterwards.
static func set_shore_swash_quality_tier(requested: Variant) -> void:
	SHORE_MATERIALS.set_shore_swash_quality_tier(requested)


static func shore_swash_sheet_enabled() -> bool:
	return SHORE_MATERIALS.shore_swash_sheet_enabled()


## Stable per-map salt for building library stems. Hash the map ID so two maps
## never share seed 0 just because their authored terrain seed is the default.
## Never hash node paths or instance IDs.
static func building_map_seed_for(map_id: StringName) -> int:
	return String(map_id).hash()


static func apply_building_map_seed(map_id: StringName) -> void:
	BUILDING_MATERIALS.set_map_seed(building_map_seed_for(map_id))


## Minimum quality drops the anti-tiling detail blend, matching shore swash.
static func set_building_quality_tier(requested: Variant) -> void:
	var tier := SKY_WEATHER.resolve_quality_tier(requested)
	BUILDING_MATERIALS.set_anti_tiling_enabled(tier != SKY_WEATHER.QUALITY_MINIMUM)


## Water-shader material for the beach film. It mirrors its source water family's
## uniforms on every weather sync, so sun, sky, tide and sea state stay identical.
static func swash_sheet_material(terrain_id: StringName) -> ShaderMaterial:
	return SHORE_MATERIALS.swash_sheet_material(terrain_id)


static func apply_water_sky_reflection(
	star_map: Texture2D,
	sun_direction: Vector3,
	moon_direction: Vector3,
	sun_visibility: float,
	moon_visibility: float,
	star_visibility: float,
	observer_latitude: float,
	sidereal_angle: float,
	sun_color: Color,
	sunset_factor: float = 0.0,
	cloud_darken: float = 0.0,
	sky_lut: Texture2D = null,
	sky_lut_size: Vector2 = Vector2(192.0, 108.0),
	sky_exposure: float = 0.7,
	sky_tint: Color = Color.WHITE
) -> void:
	# WHY: optional weather scalars used to stay at the water-material defaults
	# (0) because this facade never forwarded them. WS-11a pushes the live
	# sunset and preset darken so haze, sky reflection and caustic gates track
	# weather instead of a permanent clear day.
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
		WATER_WAVE_BASE,
		sunset_factor,
		cloud_darken,
		sky_lut,
		sky_lut_size,
		sky_exposure,
		sky_tint
	)


## Wind-driven vegetation and cloth APIs remain here for existing builders and
## tests. Their independent cache lives in WIND_MATERIALS.
static func apply_world_wind(direction: Vector2, strength: float) -> void:
	WIND_MATERIALS.apply_world_wind(direction, strength)


static func grass_blades() -> ShaderMaterial:
	return WIND_MATERIALS.grass_blades()


static func apply_grass_interaction(center_xz: Vector2, velocity_xz: Vector2) -> void:
	WIND_MATERIALS.apply_grass_interaction(center_xz, velocity_xz)


static func clear_grass_interaction() -> void:
	WIND_MATERIALS.clear_grass_interaction()


static func canopy(kind: StringName) -> ShaderMaterial:
	return WIND_MATERIALS.canopy(kind)


static func sail_cloth() -> ShaderMaterial:
	return WIND_MATERIALS.sail_cloth()


static func flag_cloth() -> ShaderMaterial:
	return WIND_MATERIALS.flag_cloth()


static func hanging_banner_cloth(albedo: Texture2D = null) -> ShaderMaterial:
	return WIND_MATERIALS.hanging_banner_cloth(albedo)


static func faction_banner_albedo(faction_id: StringName) -> Texture2D:
	return WIND_MATERIALS.faction_banner_albedo(faction_id)


static func fishing_net_hemp() -> ShaderMaterial:
	return WIND_MATERIALS.fishing_net_hemp()


static func fishing_net_float() -> ShaderMaterial:
	return WIND_MATERIALS.fishing_net_float()


static func fishing_net_sinker() -> ShaderMaterial:
	return WIND_MATERIALS.fishing_net_sinker()


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


static func roof_cover_world_density(pattern: StringName) -> Vector3:
	return BUILDING_MATERIALS.roof_cover_world_density(pattern)


static func fortification_masonry(color: Color) -> StandardMaterial3D:
	return BUILDING_MATERIALS.fortification_masonry(color)


static func roof_tile_world(color: Color) -> StandardMaterial3D:
	return BUILDING_MATERIALS.roof_tile_world(color)


static func tower_roof_tiles(surface_id: StringName, color: Color) -> StandardMaterial3D:
	return BUILDING_MATERIALS.tower_roof_tiles(surface_id, color)


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
	return PROP_MATERIALS.role_for_size(role_name, size)


static func door_wood(noise_seed: int) -> StandardMaterial3D:
	return PROP_MATERIALS.door_wood(noise_seed)


static func door_iron() -> StandardMaterial3D:
	return PROP_MATERIALS.door_iron()


static func hewn_timber(grain_along_u: bool, noise_seed: int = 0) -> StandardMaterial3D:
	return PROP_MATERIALS.hewn_timber(grain_along_u, noise_seed)


static func hewn_timber_for_size(size: Vector3, noise_seed: int = 0) -> StandardMaterial3D:
	return PROP_MATERIALS.hewn_timber_for_size(size, noise_seed)


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
