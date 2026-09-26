extends RefCounted

## Cached building wall and roof materials for the 3D map view.
##
## MapViewMaterials remains the public facade. Keeping construction-specific
## weathering and UV rules here isolates building visuals from terrain, water,
## and prop material concerns without changing callers.

const PATTERN_FAMILIES := preload(
	"res://scripts/map/view3d/map_view_material_pattern_families.gd"
)
const PATTERN_BRICK := PATTERN_FAMILIES.PATTERN_BRICK
const PATTERN_PLANK := PATTERN_FAMILIES.PATTERN_PLANK
const PATTERN_LIMESTONE := PATTERN_FAMILIES.PATTERN_LIMESTONE
const PATTERN_ROOF_TILE := PATTERN_FAMILIES.PATTERN_ROOF_TILE
const PATTERN_PLASTER := PATTERN_FAMILIES.PATTERN_PLASTER
const PATTERN_THATCH := PATTERN_FAMILIES.PATTERN_THATCH
const PATTERN_SHINGLE := PATTERN_FAMILIES.PATTERN_SHINGLE
const PATTERN_LOG := PATTERN_FAMILIES.PATTERN_LOG
const PATTERN_STRAW := PATTERN_FAMILIES.PATTERN_STRAW
## AR-03 shared surface library (albedo + normal + packed ORM per stem).
const SURFACE_LIBRARY := preload(
	"res://scripts/map/view3d/map_view_burgher_house_surface_variety.gd"
)

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
##
## Masonry repeats are derived from real course heights rather than from what
## looked busy: one world unit is about 0.87 m, a split limestone course is about
## 0.3 m and a hand-moulded brick course about 0.1 m. The former limestone/brick
## repeats packed roughly six times that many courses into a wall, which is why
## fortifications read as a fine printed grid instead of laid stone.
const BUILDING_UV_SCALE := {
	PATTERN_BRICK: Vector3(0.8, 1.4, 0.8),
	PATTERN_LIMESTONE: Vector3(1.0, 1.1, 1.0),
	PATTERN_PLANK: Vector3(5.0, 3.0, 5.0),
	PATTERN_PLASTER: Vector3(3.5, 2.5, 3.5),
	PATTERN_ROOF_TILE: Vector3(4.0, 2.5, 4.0),
	PATTERN_SHINGLE: Vector3(5.0, 3.0, 5.0),
	PATTERN_LOG: Vector3(4.0, 3.0, 4.0),
	PATTERN_STRAW: Vector3(3.0, 2.0, 3.0),
	PATTERN_THATCH: Vector3(4.5, 5.5, 4.5),
}
const BUILDING_UV_REFERENCE_SIZE := Vector3(4.0, 3.5, 4.0)

## City walls, towers and gates: plate repeats per world unit. The authored
## rubble plate carries about ten courses, so this gives ~0.17 m courses and
## 0.3-0.5 m stones - the hand-split Reval curtain. The former house-derived
## density left stones about a fifth of a character tall.
const FORTIFICATION_MASONRY_DENSITY := Vector3(0.42, 0.53, 0.42)
## High triplanar sharpness keeps round drums from smearing two projections
## across their 45-degree faces.
const FORTIFICATION_TRIPLANAR_SHARPNESS := 8.0

## One world unit is about 0.87 m at the frozen 32 px/cell character-height scale.
const METERS_PER_WORLD_UNIT := 0.87

## Gabled roof meshes emit UVs in world units (see gabled_roof_mesh), so cover
## density is repeats per unit, not per box face. One tile plate holds 8 x 8
## monk/nun tiles: ~0.2 m wide covers on ~0.25 m exposed courses. The per-face
## reference scale (4 x 2.5) packed roughly fifty tiles into every metre of roof.
const ROOF_TILE_WORLD_DENSITY := Vector3(0.62, 0.5, 1.0)
## Wooden shingles: ~0.12 m exposed width on ~0.2 m courses. After the 8 px
## integer wrap, one 128 px plate holds 16 x 16 shingles. The former per-face
## scale (5 x 3) packed about ninety shingles into every metre.
const ROOF_SHINGLE_WORLD_DENSITY := Vector3(0.45, 0.27, 1.0)
## Reed thatch: ~0.27 m courses and ~0.2 m along-ridge bundles. The 128 px plate
## holds 12 px courses (~10.7 per plate). Ridge and eaves dressing keep 0-1 UVs
## and the per-face plate scale; only world-UV gabled meshes use this density.
const ROOF_THATCH_WORLD_DENSITY := Vector3(0.24, 0.30, 1.0)
## Tile roofs share a few painted plates; per-building tint and weathering still
## vary. One unique 256 px plate plus normal map per tile roof was load-heavy.
const ROOF_TILE_PLATE_VARIANTS := 6

## Families whose plates describe real relief (recessed joints, pitted faces,
## board gaps). They receive a matching normal map so light reveals the surface
## instead of treating every wall as a perfectly flat plane.
const RELIEF_PATTERNS: Array[StringName] = [
	PATTERN_BRICK,
	PATTERN_LIMESTONE,
	PATTERN_PLASTER,
	PATTERN_PLANK,
	PATTERN_LOG,
	PATTERN_ROOF_TILE,
]
const RELIEF_NORMAL_SCALE := {
	PATTERN_BRICK: 0.85,
	PATTERN_LIMESTONE: 1.15,
	PATTERN_PLASTER: 0.45,
	PATTERN_PLANK: 0.55,
	PATTERN_LOG: 0.80,
	PATTERN_ROOF_TILE: 1.1,
}

## Documented fallback roughness for the procedural pattern path (surfaces with
## no library set, such as cone tower roofs and the generic wall()/roof()
## helpers). No building family keeps the old constant 1.0 response.
const PATTERN_ROUGHNESS := {
	PATTERN_BRICK: 0.82,
	PATTERN_LIMESTONE: 0.86,
	PATTERN_PLASTER: 0.92,
	PATTERN_PLANK: 0.84,
	PATTERN_LOG: 0.8,
	PATTERN_ROOF_TILE: 0.68,
	PATTERN_SHINGLE: 0.8,
	PATTERN_THATCH: 0.94,
	PATTERN_STRAW: 0.95,
}

## AR-03 anti-tiling: a shared low-frequency tone plate multiplied over every
## library surface at a world-space scale that is not a multiple of any plate,
## so a long wall or roof no longer shows the plate grid when the camera pulls
## back. Sampled through world triplanar UV2 so it needs no mesh UV2 and no
## geometry change. ~27 world units (~23 m) per macro repeat.
const ANTI_TILING_TEXTURE_PATH := (
	"res://assets/materials/pbr/building_variants/building_macro_variation.png"
)
const ANTI_TILING_WORLD_DENSITY := 0.037
## The macro plate spans [0.86, 1.0] with mean ~0.93; lift albedo by the mean so
## switching anti-tiling on or off does not change overall exposure.
const ANTI_TILING_EXPOSURE_LIFT := 1.075
## How far the authored building colour still steers the library albedo. The
## texture carries the material; the authored colour only nudges its hue.
const LIBRARY_HUE_WEIGHT := 0.25
const LIBRARY_STEM_META := &"ar03_surface_stem"

static var _cache: Dictionary = {}
static var _map_seed := 0
static var _anti_tiling_enabled := true


static func reset() -> void:
	_cache.clear()


## Salt for library stem selection. Stems are keyed by (map_seed, surface_id);
## the default seed 0 keeps selection stable for callers that never set it.
static func set_map_seed(map_seed: int) -> void:
	if map_seed != _map_seed:
		_map_seed = map_seed
		_cache.clear()


static func map_seed() -> int:
	return _map_seed


## Toggle the anti-tiling detail blend on every cached and future building
## material (the `minimum` quality tier can switch it off).
static func set_anti_tiling_enabled(enabled: bool) -> void:
	_anti_tiling_enabled = enabled
	for material in _cache.values():
		var standard := material as StandardMaterial3D
		if standard != null and standard.has_meta(LIBRARY_STEM_META):
			_apply_anti_tiling(standard)


static func anti_tiling_enabled() -> bool:
	return _anti_tiling_enabled


static func wall(color: Color) -> StandardMaterial3D:
	return _building_surface("wall", color, PATTERN_PLASTER)


## Building wall surface in an explicit material family so houses read as
## built from something: plastered timber frame, brick, plank, log, or limestone.
static func wall_surface(family: StringName, color: Color) -> StandardMaterial3D:
	var library := _shared_library_surface("wall_surface", family, false, color)
	if library != null:
		return library
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
	if material.has_meta(LIBRARY_STEM_META):
		material.uv1_scale = library_box_uv_scale(String(material.get_meta(LIBRARY_STEM_META)), size)
		return material
	material.uv1_scale = building_uv_scale(_wall_pattern(family), size)
	return material


## Per-building wall material. Authored families with a library set resolve to
## a shared stem chosen by (map_seed, surface_id); the per-building part is only
## tint, weathering band and UV phase, so textures are never forked.
static func wall_surface_for_building(
	surface_id: StringName, family: StringName, color: Color, size: Vector3
) -> StandardMaterial3D:
	var stem: String = SURFACE_LIBRARY.library_stem(family, false, surface_id, _map_seed)
	if not stem.is_empty():
		var library := _library_building_surface("wall_building", surface_id, stem, color)
		library.uv1_scale = library_box_uv_scale(stem, size)
		return library
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
	var stem: String = SURFACE_LIBRARY.library_stem(family, true, surface_id, _map_seed)
	if not stem.is_empty():
		var library := _library_building_surface("roof_building", surface_id, stem, color)
		# Every caller puts this on a world-unit gabled roof mesh.
		library.uv1_scale = library_world_uv_density(stem)
		return library
	var pattern := PATTERN_ROOF_TILE
	match family:
		&"shingle":
			pattern = PATTERN_SHINGLE
		&"thatch", &"straw":
			pattern = PATTERN_THATCH
	var weathering := surface_weathering_variant(surface_id)
	var material := _building_surface_weathered(
		"roof_building", surface_id, _weathered_albedo(color, weathering), pattern, weathering
	)
	# Every caller puts this on a world-unit gabled roof mesh.
	material.uv1_scale = roof_cover_world_density(pattern)
	return material


## City wall, tower and gate masonry. World-space triplanar projection is what
## stops seam flicker: wall segments, seals, jambs and arch bands deliberately
## overlap, and object-space mapping gave each overlapping box a different
## texture phase on the same plane, so depth ties flickered between them. In
## world space coplanar overlaps shade identically and courses run continuously
## across segment joints and around drums.
static func fortification_masonry(color: Color) -> StandardMaterial3D:
	var key := "fortification_masonry:%s" % color.to_html()
	if _cache.has(key):
		return _cache[key]
	var material := wall_surface(&"limestone", color).duplicate() as StandardMaterial3D
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_triplanar_sharpness = FORTIFICATION_TRIPLANAR_SHARPNESS
	material.uv1_scale = FORTIFICATION_MASONRY_DENSITY
	if material.has_meta(LIBRARY_STEM_META):
		# The rubble plate is sized in metres, so the curtain keeps ~0.2 m courses.
		material.uv1_scale = library_world_uv_density(String(material.get_meta(LIBRARY_STEM_META)))
	_cache[key] = material
	return material


## Tile cover for world-unit gabled meshes such as the wall-walk gallery roofs.
static func roof_tile_world(color: Color) -> StandardMaterial3D:
	var key := "roof_tile_world:%s" % color.to_html()
	if _cache.has(key):
		return _cache[key]
	var material := roof_surface(&"tile", color).duplicate() as StandardMaterial3D
	if not material.has_meta(LIBRARY_STEM_META):
		material.uv1_scale = ROOF_TILE_WORLD_DENSITY
	_cache[key] = material
	return material


## Weathered tile cover for conical tower roofs. The cone mesh maps one tile
## course per ring band and a whole number of tiles per ring, so the material
## keeps unit UV scale.
static func tower_roof_tiles(surface_id: StringName, color: Color) -> StandardMaterial3D:
	var weathering := surface_weathering_variant(surface_id)
	var material := _building_surface_weathered(
		"tower_roof", surface_id, _weathered_albedo(color, weathering), PATTERN_ROOF_TILE, weathering
	)
	material.uv1_scale = Vector3.ONE
	return material


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
	if material.has_meta(LIBRARY_STEM_META):
		material.uv1_scale = library_world_uv_density(String(material.get_meta(LIBRARY_STEM_META)))
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
	var library := _shared_library_surface("roof_surface", family, true, color)
	if library != null:
		# World-UV gabled meshes are the only roof_surface callers.
		library.uv1_scale = library_world_uv_density(String(library.get_meta(LIBRARY_STEM_META)))
		return library
	var pattern := PATTERN_ROOF_TILE
	var prefix := "roof_tile"
	match family:
		&"shingle":
			pattern = PATTERN_SHINGLE
			prefix = "roof_shingle"
		&"thatch", &"straw":
			pattern = PATTERN_THATCH
			prefix = "roof_thatch"
	var material := _building_surface(prefix, color, pattern)
	# World-UV gabled meshes are the only roof_surface callers.
	material.uv1_scale = roof_cover_world_density(pattern)
	return material


## Repeats per world unit for gabled roof covers. BoxMesh walls still use
## building_uv_scale(); CylinderMesh and BoxMesh tile helpers keep roof().
static func roof_cover_world_density(pattern: StringName) -> Vector3:
	match pattern:
		PATTERN_SHINGLE:
			return ROOF_SHINGLE_WORLD_DENSITY
		PATTERN_THATCH:
			return ROOF_THATCH_WORLD_DENSITY
		_:
			return ROOF_TILE_WORLD_DENSITY


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


## Repeats per world unit for a library stem (triplanar and world-UV meshes).
static func library_world_uv_density(stem: String) -> Vector3:
	var plate: Vector2 = SURFACE_LIBRARY.stem_plate_metres(stem)
	return Vector3(
		METERS_PER_WORLD_UNIT / plate.x,
		METERS_PER_WORLD_UNIT / plate.y,
		METERS_PER_WORLD_UNIT / plate.x
	)


## uv1_scale for a BoxMesh of `size` world units. Godot's BoxMesh packs its six
## faces into a 3 x 2 UV atlas, so one face spans 1/3 of U and 1/2 of V; the
## scale is multiplied back up so one plate covers its real size in metres.
## U uses the mean of width and depth because one scale serves all four faces.
static func library_box_uv_scale(stem: String, size: Vector3) -> Vector3:
	var density := library_world_uv_density(stem)
	var run := (size.x + size.z) * 0.5
	var u := 3.0 * run * density.x
	return Vector3(u, 2.0 * size.y * density.y, u)


## Library material shared by every caller of wall_surface()/roof_surface()
## with the same family and colour; the stem is chosen from the colour so the
## few helper surfaces without a building ID stay deterministic.
static func _shared_library_surface(
	prefix: String, family: StringName, is_roof: bool, color: Color
) -> StandardMaterial3D:
	var stem: String = SURFACE_LIBRARY.library_stem(
		family, is_roof, StringName("%s:%s" % [prefix, color.to_html()]), _map_seed
	)
	if stem.is_empty():
		return null
	var key := "%s:%s:%s" % [prefix, stem, color.to_html()]
	if _cache.has(key):
		return _cache[key]
	var material := _make_library_material(stem, _library_tint(color, WEATHER_FRESH))
	material.uv1_scale = library_box_uv_scale(stem, BUILDING_UV_REFERENCE_SIZE)
	_cache[key] = material
	return material


## Per-building library material: one cache entry per building surface (the
## same material count as the former per-building procedural plates), sharing
## the stem's textures. Weathering re-tones the tint; the UV phase is a stable
## per-building offset so neighbours using the same stem do not line up.
static func _library_building_surface(
	prefix: String, surface_id: StringName, stem: String, color: Color
) -> StandardMaterial3D:
	var weathering := surface_weathering_variant(surface_id)
	var key := "%s:%s:%s:%s" % [prefix, String(surface_id), stem, color.to_html()]
	if _cache.has(key):
		return _cache[key]
	var material := _make_library_material(stem, _library_tint(color, weathering))
	material.uv1_offset = library_uv_offset(surface_id)
	_cache[key] = material
	return material


static func library_uv_offset(surface_id: StringName) -> Vector3:
	var roll := absi(String(surface_id).hash())
	return Vector3(float(roll % 997) / 997.0, float(int(roll / 997) % 991) / 991.0, 0.0)


static func _library_tint(color: Color, weathering: StringName) -> Color:
	var peak := maxf(maxf(color.r, color.g), maxf(color.b, 0.001))
	var hue := Color(color.r / peak, color.g / peak, color.b / peak)
	var tint := _weathered_albedo(Color.WHITE.lerp(hue, LIBRARY_HUE_WEIGHT), weathering)
	tint.a = 1.0
	return tint


static func _make_library_material(stem: String, tint: Color) -> StandardMaterial3D:
	var paths: Dictionary = SURFACE_LIBRARY.stem_paths(stem)
	var material := StandardMaterial3D.new()
	material.set_meta(LIBRARY_STEM_META, stem)
	material.set_meta(&"ar03_base_tint", tint)
	material.albedo_color = tint
	material.albedo_texture = load(paths["albedo"])
	material.normal_enabled = true
	material.normal_texture = load(paths["normal"])
	material.normal_scale = SURFACE_LIBRARY.stem_normal_scale(stem)
	var orm: Texture2D = load(paths["orm"])
	# Packed ORM: G carries roughness, R carries cavity occlusion.
	material.roughness = 1.0
	material.roughness_texture = orm
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	material.ao_enabled = true
	material.ao_texture = orm
	material.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Meshes without a colour attribute stay white, so this is a no-op for the
	# library albedo and keeps baked wear tones on meshes that carry them.
	material.vertex_color_use_as_albedo = true
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_apply_anti_tiling(material)
	return material


static func _apply_anti_tiling(material: StandardMaterial3D) -> void:
	var base_tint: Color = material.get_meta(&"ar03_base_tint", material.albedo_color)
	material.detail_enabled = _anti_tiling_enabled
	if not _anti_tiling_enabled:
		material.albedo_color = base_tint
		return
	material.detail_albedo = load(ANTI_TILING_TEXTURE_PATH)
	material.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	material.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
	material.uv2_triplanar = true
	material.uv2_world_triplanar = true
	material.uv2_scale = Vector3.ONE * ANTI_TILING_WORLD_DENSITY
	var lifted := base_tint * ANTI_TILING_EXPOSURE_LIFT
	lifted.a = 1.0
	material.albedo_color = lifted


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
	if pattern == PATTERN_ROOF_TILE:
		seed = posmod(seed, ROOF_TILE_PLATE_VARIANTS)
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


static func _apply_relief(
	material: StandardMaterial3D, pattern: StringName, noise_seed: int
) -> void:
	if pattern not in RELIEF_PATTERNS:
		return
	material.normal_enabled = true
	material.normal_texture = MapViewMaterialPatterns.pattern_normal_texture(pattern, noise_seed)
	material.normal_scale = float(RELIEF_NORMAL_SCALE.get(pattern, 0.8))


static func _make_weathered_material(
	base: Color, pattern: StringName, noise_seed: int, weathering: StringName
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = base
	material.albedo_texture = MapViewMaterialPatterns.pattern_texture_weathered(
		pattern, noise_seed, weathering, MapViewMaterialPatterns.pattern_source_size(pattern)
	)
	material.roughness = float(PATTERN_ROUGHNESS.get(pattern, 1.0))
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	# Distant wall faces otherwise smear 512 px masonry into a printed grid.
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	# Weathering only re-tones the plate, so the relief is shared with the base
	# pattern seed and does not multiply normal-map memory per weathering band.
	_apply_relief(material, pattern, noise_seed)
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
	material.roughness = float(PATTERN_ROUGHNESS.get(pattern, 1.0))
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Terrain cells and scatter instances carry per-cell tone in vertex/instance
	# colors; meshes without a color attribute stay white so nothing shifts.
	material.vertex_color_use_as_albedo = true
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_apply_relief(material, pattern, noise_seed)
	return material
