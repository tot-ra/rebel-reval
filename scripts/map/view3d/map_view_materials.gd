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

## WS-08 shore swash strength per water family. Open sea runs up beaches; ponds and
## moats only slosh at their banks; rivers keep their own bank treatment.
const SHORE_STRENGTH_BY_TERRAIN := {
	MapTypes.TERRAIN_WATER: 0.3,
	MapTypes.TERRAIN_SHALLOW_WATER: 1.0,
	MapTypes.TERRAIN_DEEP_WATER: 1.0,
	MapTypes.TERRAIN_RIVER_WATER: 0.0,
}
## World units of retreat per unit of the water shader's shore-factor tide clip.
## High tide fills the authored contour exactly; only the ebb moves the waterline
## (seaward), so the swash origin follows the water's own tide_shore_retreat.
const SHORE_TIDE_SHIFT := 1.6
## Uniforms a swash sheet must not inherit from its source water material.
const SWASH_SHEET_OWN_UNIFORMS: Array[StringName] = [
	&"swash_sheet", &"ripple_state", &"ripple_window", &"ripple_texel_count"
]

## Beach swash sheets reuse the water shader; one material per source water family.
static var _swash_sheet_materials: Dictionary = {}
static var _shore_swash_quality_tier: StringName = SKY_WEATHER.QUALITY_RECOMMENDED

## Shader sources live in MapViewMaterialShaders; procedural textures in MapViewMaterialPatterns.


static func reset() -> void:
	MapViewMaterialShaders.reset()
	MapViewMaterialPatterns.reset()
	WATER_MATERIALS.reset()
	WIND_MATERIALS.reset()
	TERRAIN_MATERIALS.reset()
	BUILDING_MATERIALS.reset()
	PROP_MATERIALS.reset()
	_swash_sheet_materials.clear()


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
	var sea := clampf(WATER_MATERIALS.fft_sea_state_scalar(wind, rain), 0.0, 1.0)
	_set_shore_uniform(&"shore_sea_state", sea)
	_sync_swash_sheets()


static func apply_water_lighting(sun_visibility: float, day_blend: float) -> void:
	WATER_MATERIALS.apply_water_lighting(sun_visibility, day_blend, WATER_WAVE_BASE)


static func apply_coastal_tide(level: float) -> void:
	WATER_MATERIALS.apply_coastal_tide(level, WATER_WAVE_BASE)
	# The swash rides on top of the current tide line.
	var retreat := float(WATER_WAVE_BASE[MapTypes.TERRAIN_SHALLOW_WATER]["tide_shore_retreat"])
	var ebb := maxf(-clampf(level, -1.0, 1.0), 0.0)
	_set_shore_uniform(&"shore_tide_offset", -ebb * retreat * SHORE_TIDE_SHIFT)
	_sync_swash_sheets()


## WS-08: binds one map's shore distance field to every material that draws the
## shore. A null texture (no sea, interiors) turns every swash path off.
static func apply_shore_field(texture: Texture2D, origin: Vector2, size: Vector2) -> void:
	var valid := 1.0 if texture != null else 0.0
	var extent := Vector2(maxf(size.x, 0.001), maxf(size.y, 0.001))
	for material in _shore_materials():
		if texture != null:
			material.set_shader_parameter("shore_field", texture)
		material.set_shader_parameter("shore_field_origin", origin)
		material.set_shader_parameter("shore_field_size", extent)
		material.set_shader_parameter("shore_field_valid", valid)
	for terrain_id: StringName in WATER_WAVE_BASE.keys():
		water_surface(terrain_id).set_shader_parameter(
			"shore_strength", float(SHORE_STRENGTH_BY_TERRAIN.get(terrain_id, 0.0))
		)


## Minimum tier drops the sheet mesh but keeps the bore foam and wet sand. Like the
## FFT cascades, the tier applies to map views built afterwards.
static func set_shore_swash_quality_tier(requested: Variant) -> void:
	_shore_swash_quality_tier = SKY_WEATHER.resolve_quality_tier(requested)


static func shore_swash_sheet_enabled() -> bool:
	return _shore_swash_quality_tier != SKY_WEATHER.QUALITY_MINIMUM


## Water-shader material for the beach film. It mirrors its source water family's
## uniforms on every weather sync, so sun, sky, tide and sea state stay identical.
static func swash_sheet_material(terrain_id: StringName) -> ShaderMaterial:
	if _swash_sheet_materials.has(terrain_id):
		return _swash_sheet_materials[terrain_id]
	var source := water_surface(terrain_id)
	var material := source.duplicate() as ShaderMaterial
	material.set_shader_parameter("swash_sheet", true)
	material.set_shader_parameter("ripple_state", WATER_MATERIALS.ripple_off_texture())
	material.set_shader_parameter("ripple_window", Vector4(0.0, 0.0, 64.0, 0.0))
	material.render_priority = 1
	_swash_sheet_materials[terrain_id] = material
	return material


static func _sync_swash_sheets() -> void:
	for terrain_id: StringName in _swash_sheet_materials.keys():
		var source := water_surface(terrain_id)
		var sheet := _swash_sheet_materials[terrain_id] as ShaderMaterial
		for uniform: Dictionary in source.shader.get_shader_uniform_list():
			var uniform_name := StringName(uniform["name"])
			if uniform_name in SWASH_SHEET_OWN_UNIFORMS:
				continue
			var value: Variant = source.get_shader_parameter(uniform_name)
			if value != null:
				sheet.set_shader_parameter(uniform_name, value)


static func _set_shore_uniform(uniform_name: StringName, value: Variant) -> void:
	for material in _shore_materials():
		material.set_shader_parameter(uniform_name, value)


static func _shore_materials() -> Array[ShaderMaterial]:
	var materials: Array[ShaderMaterial] = TERRAIN_MATERIALS.blended_ground_materials()
	for terrain_id: StringName in WATER_WAVE_BASE.keys():
		materials.append(water_surface(terrain_id))
	for sheet: ShaderMaterial in _swash_sheet_materials.values():
		materials.append(sheet)
	return materials


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
