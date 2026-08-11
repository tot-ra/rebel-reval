extends RefCounted

## Cached building wall and roof materials for the 3D map view.
##
## MapViewMaterials remains the public facade. Keeping construction-specific
## weathering and UV rules here isolates building visuals from terrain, water,
## and prop material concerns without changing callers.

const PATTERN_BRICK := &"brick"
const PATTERN_PLANK := &"plank"
const PATTERN_LIMESTONE := &"limestone"
const PATTERN_ROOF_TILE := &"roof_tile"
const PATTERN_PLASTER := &"plaster"
const PATTERN_THATCH := &"thatch"
const PATTERN_SHINGLE := &"shingle"
const PATTERN_LOG := &"log"

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
const BUILDING_UV_SCALE := {
	PATTERN_BRICK: Vector3(5.0, 6.5, 5.0),
	PATTERN_LIMESTONE: Vector3(4.0, 6.0, 4.0),
	PATTERN_PLANK: Vector3(5.0, 3.0, 5.0),
	PATTERN_PLASTER: Vector3(3.5, 2.5, 3.5),
	PATTERN_ROOF_TILE: Vector3(4.0, 2.5, 4.0),
	PATTERN_SHINGLE: Vector3(5.0, 3.0, 5.0),
	PATTERN_LOG: Vector3(4.0, 3.0, 4.0),
	PATTERN_THATCH: Vector3(4.5, 5.5, 4.5),
}
const BUILDING_UV_REFERENCE_SIZE := Vector3(4.0, 3.5, 4.0)

static var _cache: Dictionary = {}


static func reset() -> void:
	_cache.clear()


static func wall(color: Color) -> StandardMaterial3D:
	return _building_surface("wall", color, PATTERN_PLASTER)


## Building wall surface in an explicit material family so houses read as
## built from something: plastered timber frame, brick, plank, log, or limestone.
static func wall_surface(family: StringName, color: Color) -> StandardMaterial3D:
	match family:
		&"brick":
			return _building_surface("wall_brick", color, PATTERN_BRICK)
		&"plank":
			return _building_surface("wall_plank", color, PATTERN_PLANK)
		&"log":
			return _building_surface("wall_log", color, PATTERN_LOG)
		&"limestone":
			return _building_surface("wall_limestone", color, PATTERN_LIMESTONE)
		_:
			return _building_surface("wall_plaster", color, PATTERN_PLASTER)


## Wall material with UV repeats derived from the mesh world size so BoxMesh
## faces tile instead of stretching one pattern across the full span.
static func wall_surface_for_size(
	family: StringName, color: Color, size: Vector3
) -> StandardMaterial3D:
	var material := wall_surface(family, color).duplicate()
	material.uv1_scale = building_uv_scale(_wall_pattern(family), size)
	return material


## Per-building wall material with unique pattern seed and weathering band.
static func wall_surface_for_building(
	surface_id: StringName, family: StringName, color: Color, size: Vector3
) -> StandardMaterial3D:
	var pattern := _wall_pattern(family)
	var weathering := surface_weathering_variant(surface_id)
	var material := _building_surface_weathered(
		"wall_building", surface_id, _weathered_albedo(color, weathering), pattern, weathering
	)
	material.uv1_scale = building_uv_scale(pattern, size)
	return material


## Per-building roof material with unique pattern seed and weathering band.
static func roof_surface_for_building(
	surface_id: StringName, family: StringName, color: Color
) -> StandardMaterial3D:
	var pattern := PATTERN_ROOF_TILE
	match family:
		&"shingle":
			pattern = PATTERN_SHINGLE
		&"thatch", &"straw":
			pattern = PATTERN_THATCH
	var weathering := surface_weathering_variant(surface_id)
	return _building_surface_weathered(
		"roof_building", surface_id, _weathered_albedo(color, weathering), pattern, weathering
	)


## Stable weathering band from a building or landmark ID.
static func surface_weathering_variant(surface_id: StringName) -> StringName:
	var roll := absi(String(surface_id).hash()) % 20
	if roll < 8:
		return WEATHER_WORN
	if roll < 13:
		return WEATHER_FRESH
	if roll < 17:
		return WEATHER_DAMP
	return WEATHER_REPAIRED


static func building_pattern_seed(surface_id: StringName, pattern: StringName) -> int:
	return int(StringName("%s:%s" % [surface_id, pattern]).hash())


## Object-space triplanar mapping keeps masonry density independent of whether a
## BoxMesh wall runs along X or Z. Regular BoxMesh UVs only use uv1_scale.x/y,
## which makes Z-aligned walls derive their visible repeat count from thickness.
static func wall_surface_triplanar(family: StringName, color: Color) -> StandardMaterial3D:
	var pattern := _wall_pattern(family)
	var material := wall_surface(family, color).duplicate()
	material.uv1_triplanar = true
	material.uv1_world_triplanar = false
	material.uv1_scale = building_uv_density(pattern)
	return material


static func wall_for_size(color: Color, size: Vector3) -> StandardMaterial3D:
	var material := wall(color).duplicate()
	material.uv1_scale = building_uv_scale(PATTERN_PLASTER, size)
	return material


static func roof(color: Color) -> StandardMaterial3D:
	return _building_surface("roof", color, PATTERN_ROOF_TILE)


## Roof cover in an explicit material family. 1343 Reval roofs were mostly
## wooden shingle and reed/straw thatch; ceramic tile marked churches and the
## few rich stone houses, so tile stays the explicit (not default-everywhere) choice.
static func roof_surface(family: StringName, color: Color) -> StandardMaterial3D:
	match family:
		&"shingle":
			return _building_surface("roof_shingle", color, PATTERN_SHINGLE)
		&"thatch", &"straw":
			return _building_surface("roof_thatch", color, PATTERN_THATCH)
		_:
			return _building_surface("roof_tile", color, PATTERN_ROOF_TILE)


## UV repeat density per world unit. Triplanar materials use this directly so
## X- and Z-facing walls receive the same masonry scale.
static func building_uv_density(pattern: StringName) -> Vector3:
	var repeats: Vector3 = BUILDING_UV_SCALE.get(pattern, Vector3.ONE)
	return repeats / BUILDING_UV_REFERENCE_SIZE


## UV repeat counts for a box face whose width, height, and depth are size.
static func building_uv_scale(pattern: StringName, size: Vector3) -> Vector3:
	return size * building_uv_density(pattern)


## CylinderMesh wraps U around the circumference; pass radius and height.
static func building_uv_scale_cylinder(
	pattern: StringName, radius: float, height: float
) -> Vector3:
	return building_uv_scale(pattern, Vector3(TAU * radius, height, TAU * radius))


static func _building_surface(
	prefix: String, color: Color, pattern: StringName
) -> StandardMaterial3D:
	var material := _patterned(prefix, color, pattern)
	material.uv1_scale = building_uv_scale(pattern, BUILDING_UV_REFERENCE_SIZE)
	return material


static func _building_surface_weathered(
	prefix: String,
	surface_id: StringName,
	color: Color,
	pattern: StringName,
	weathering: StringName
) -> StandardMaterial3D:
	var key := (
		"%s:%s:%s:%s:%s"
		% [
			prefix,
			String(surface_id),
			color.to_html(),
			String(pattern),
			String(weathering),
		]
	)
	if _cache.has(key):
		return _cache[key]
	var seed := building_pattern_seed(surface_id, pattern)
	var material := _make_weathered_material(color, pattern, seed, weathering)
	material.uv1_scale = building_uv_scale(pattern, BUILDING_UV_REFERENCE_SIZE)
	_cache[key] = material
	return material


static func _weathered_albedo(base: Color, weathering: StringName) -> Color:
	match weathering:
		WEATHER_WORN:
			return base.lightened(0.04).lerp(Color(0.76, 0.74, 0.69), 0.08)
		WEATHER_DAMP:
			return base.darkened(0.08)
		_:
			return base


static func _make_weathered_material(
	base: Color, pattern: StringName, noise_seed: int, weathering: StringName
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = base
	material.albedo_texture = MapViewMaterialPatterns.pattern_texture_weathered(
		pattern, noise_seed, weathering
	)
	material.roughness = 1.0
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	return material


static func _wall_pattern(family: StringName) -> StringName:
	match family:
		&"brick":
			return PATTERN_BRICK
		&"plank":
			return PATTERN_PLANK
		&"log":
			# Keep log as a real construction family in the per-building path;
			# falling through to plaster would erase the rural/timber distinction.
			return PATTERN_LOG
		&"limestone":
			return PATTERN_LIMESTONE
		_:
			return PATTERN_PLASTER


static func _patterned(prefix: String, color: Color, pattern: StringName) -> StandardMaterial3D:
	var key := "%s:%s:%s" % [prefix, color.to_html(), String(pattern)]
	if _cache.has(key):
		return _cache[key]
	var material := _make_material(color, pattern, int(key.hash()))
	_cache[key] = material
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
