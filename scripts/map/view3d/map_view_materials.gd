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
## Authored grass/mud plates stay at their native 512 px. Downscaling them into
## the 128 px terrain array was the main reason meadows and yards read as blur.
const NATURAL_GROUND_TEXTURE_SIZE := 512
## Wall, tower and gate faces are the tallest surfaces in frame and are read from
## a few metres away, so masonry needs a denser source than secondary materials
## to keep rubble courses, joints and chipped arrises legible.
const MASONRY_TEXTURE_SIZE := 512
const EMBER_COLOR := Color8(224, 108, 48)
const EMBER_ENERGY := 1.6
const WATER_MATERIALS := preload("res://scripts/map/view3d/map_view_water_materials.gd")
const WIND_MATERIALS := preload("res://scripts/map/view3d/map_view_wind_materials.gd")
const TERRAIN_MATERIALS := preload("res://scripts/map/view3d/map_view_terrain_materials.gd")
const SKY_WEATHER := preload("res://scripts/map/view3d/sky_weather_3d.gd")
const BUILDING_MATERIALS := preload("res://scripts/map/view3d/map_view_building_materials.gd")
const PROP_MATERIALS := preload("res://scripts/map/view3d/map_view_prop_materials.gd")
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

## Dry-terrain repeat and blend tables remain on the facade for mesh builders
## and tests. Implementation and caches live in TERRAIN_MATERIALS.
const TERRAIN_TEXTURE_WORLD_SIZE := TERRAIN_MATERIALS.TERRAIN_TEXTURE_WORLD_SIZE
const TERRAIN_GRASS_UV_SCALE := TERRAIN_MATERIALS.TERRAIN_GRASS_UV_SCALE
const TERRAIN_TIMBER_FLOOR_UV_SCALE := TERRAIN_MATERIALS.TERRAIN_TIMBER_FLOOR_UV_SCALE
const TERRAIN_PATTERN := TERRAIN_MATERIALS.TERRAIN_PATTERN
const TERRAIN_UV_SCALE := TERRAIN_MATERIALS.TERRAIN_UV_SCALE
const BLEND_TERRAIN_ORDER: Array[StringName] = TERRAIN_MATERIALS.BLEND_TERRAIN_ORDER

## Pattern families for terrain and building surfaces.
const PATTERN_GRASS := &"grass"
const PATTERN_SPECKLE := &"speckle"
const PATTERN_MUD := &"mud"
## Packed-earth streets and yards. Separate from PATTERN_SPECKLE so sand and ash
## keep their fine even grain while trodden earth gains gravel, ruts and cracks.
const PATTERN_EARTH := &"earth"
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

## BoxMesh and CylinderMesh map UV 0-1 across each face. Without extra
## repeats, one procedural tile spans an entire house wall and bricks read
## billboard-sized. Values are tuned for typical 3-6 unit footprints at the
## frozen 32 px/cell scale (character height 2.0 units).
## Stretcher courses need more vertical UV repeats than horizontal ones so each
## block reads wider than tall (running bond, not soldier/stack bond).
const BUILDING_UV_SCALE := {
	PATTERN_BRICK: Vector3(0.8, 1.4, 0.8),
	PATTERN_LIMESTONE: Vector3(1.0, 1.1, 1.0),
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


static func reset() -> void:
	MapViewMaterialShaders.reset()
	MapViewMaterialPatterns.reset()
	WATER_MATERIALS.reset()
	WIND_MATERIALS.reset()
	TERRAIN_MATERIALS.reset()
	BUILDING_MATERIALS.reset()
	PROP_MATERIALS.reset()


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
	apply_sea_weather(presentation.wind_strength, presentation.rain_intensity)
	apply_mud_wetness(presentation.puddle_wetness)
	apply_world_wind(presentation.wind_direction, presentation.wind_strength)


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
