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
const EMBER_COLOR := Color8(224, 108, 48)
const EMBER_ENERGY := 1.6

const WATER_TERRAINS: Array[StringName] = [
	MapTypes.TERRAIN_WATER,
	MapTypes.TERRAIN_SHALLOW_WATER,
	MapTypes.TERRAIN_DEEP_WATER,
]

## World units covered by one repeat of the terrain detail texture. Terrain
## meshes emit world-space UVs divided by this, so patterns run seamlessly
## across cell borders instead of restarting per cell.
const TERRAIN_TEXTURE_WORLD_SIZE := 4.0

## Pattern families for terrain and building surfaces.
const PATTERN_GRASS := &"grass"
const PATTERN_SPECKLE := &"speckle"
const PATTERN_MUD := &"mud"
const PATTERN_COBBLE := &"cobble"
const PATTERN_BRICK := &"brick"
const PATTERN_PLANK := &"plank"
const PATTERN_LIMESTONE := &"limestone"
const PATTERN_ROOF_TILE := &"roof_tile"
const PATTERN_PLASTER := &"plaster"
const PATTERN_STRAW := &"straw"
const PATTERN_SHINGLE := &"shingle"
const PATTERN_LOG := &"log"

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


static func terrain_pattern_array(noise_seed: int) -> Texture2DArray:
	var key := "terrain_pattern_array:%d" % noise_seed
	if _cache.has(key):
		return _cache[key]
	var images: Array[Image] = []
	for terrain_id in BLEND_TERRAIN_ORDER:
		var pattern: StringName = TERRAIN_PATTERN.get(terrain_id, PATTERN_GRASS)
		var image := MapViewMaterialPatterns.pattern_texture(pattern, noise_seed + int(terrain_id.hash())).get_image()
		images.append(image)
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
	material.shader = MapViewMaterialShaders.shader("terrain_blend", MapViewMaterialShaders.TERRAIN_BLEND_SHADER_CODE)
	material.set_shader_parameter("terrain_patterns", terrain_pattern_array(noise_seed))
	material.set_shader_parameter("pattern_layers", float(BLEND_TERRAIN_ORDER.size()))
	_cache[key] = material
	return material


static func puddle_surface() -> ShaderMaterial:
	var key := "puddle_surface"
	if _cache.has(key):
		return _cache[key]
	var material := ShaderMaterial.new()
	material.shader = MapViewMaterialShaders.shader("puddle", MapViewMaterialShaders.PUDDLE_SHADER_CODE)
	material.set_shader_parameter("wet_tint", Vector3(0.78, 0.82, 0.86))
	material.set_shader_parameter("sheen_tint", Vector3(0.94, 0.96, 0.98))
	_cache[key] = material
	return material


## Animated water surface for water-family terrain cells; colors derive from
## the same frozen palette entry the flat material uses.
static func water_surface(terrain_id: StringName) -> ShaderMaterial:
	var key := "water_surface:%s" % String(terrain_id)
	if _cache.has(key):
		return _cache[key]
	var base := OutdoorTerrainPalette.color(terrain_id)
	var material := ShaderMaterial.new()
	material.shader = MapViewMaterialShaders.shader("water", MapViewMaterialShaders.WATER_SHADER_CODE)
	material.set_shader_parameter("shallow_color", base.lightened(0.18))
	material.set_shader_parameter("deep_color", base.darkened(0.42))
	# ART_BIBLE highlight #65B1C4 blended toward the terrain palette entry.
	material.set_shader_parameter("highlight_color", base.lerp(Color8(101, 177, 196), 0.55))
	# Keep foam close to the water tint so the shoreline does not flash white.
	material.set_shader_parameter("foam_color", base.lerp(Color8(188, 208, 206), 0.48))
	match terrain_id:
		MapTypes.TERRAIN_SHALLOW_WATER:
			material.set_shader_parameter("depth_absorption", 5.0)
			material.set_shader_parameter("wave_height", 0.014)
			material.set_shader_parameter("foam_intensity", 0.18)
		MapTypes.TERRAIN_DEEP_WATER:
			material.set_shader_parameter("depth_absorption", 9.0)
			material.set_shader_parameter("wave_height", 0.026)
			material.set_shader_parameter("foam_intensity", 0.12)
		_:
			material.set_shader_parameter("depth_absorption", 7.0)
			material.set_shader_parameter("wave_height", 0.018)
			material.set_shader_parameter("foam_intensity", 0.20)
	_cache[key] = material
	return material


## Wind-swaying grass blade material; instance colors modulate the tint.
static func grass_blades() -> ShaderMaterial:
	var key := "grass_blades"
	if _cache.has(key):
		return _cache[key]
	var material := ShaderMaterial.new()
	material.shader = MapViewMaterialShaders.shader("grass", MapViewMaterialShaders.GRASS_SHADER_CODE)
	material.set_shader_parameter("base_color", Color8(104, 130, 62))
	_cache[key] = material
	return material


static func canopy(kind: StringName) -> ShaderMaterial:
	var key := "canopy:%s" % String(kind)
	if _cache.has(key):
		return _cache[key]
	var material := ShaderMaterial.new()
	material.shader = MapViewMaterialShaders.shader("canopy", MapViewMaterialShaders.CANOPY_SHADER_CODE)
	match kind:
		&"spruce":
			material.set_shader_parameter("base_color", Color8(58, 84, 56))
			material.set_shader_parameter("sway_strength", 0.035)
		_:
			material.set_shader_parameter("base_color", Color8(96, 118, 60))
			material.set_shader_parameter("sway_strength", 0.06)
	_cache[key] = material
	return material


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
static func wall_surface_for_size(family: StringName, color: Color, size: Vector3) -> StandardMaterial3D:
	var material := wall_surface(family, color).duplicate()
	material.uv1_scale = building_uv_scale(_wall_pattern(family), size)
	return material


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
			return _building_surface("roof_thatch", color, PATTERN_STRAW)
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
static func building_uv_scale_cylinder(pattern: StringName, radius: float, height: float) -> Vector3:
	return building_uv_scale(pattern, Vector3(TAU * radius, height, TAU * radius))


## Prop surface materials keyed by the shared visual-style roles so the
## placeholder palette carries over from the approved clean-painted profile.
static func role(role_name: StringName) -> StandardMaterial3D:
	var key := "role:%s" % String(role_name)
	if _cache.has(key):
		return _cache[key]
	var base := MapVisualStyle.role_color(role_name, MapVisualStyle.TARGET_CLEAN_PAINTED, MapVisualStyle.TIME_DAY)
	var pattern := PATTERN_PLASTER
	match role_name:
		&"wood", &"timber":
			pattern = PATTERN_PLANK
		&"stone":
			pattern = PATTERN_LIMESTONE
		&"hay":
			pattern = PATTERN_STRAW
	var material := _make_material(base, pattern, int(role_name.hash()))
	match role_name:
		&"metal":
			material.metallic = 0.55
			material.roughness = 0.45
		&"window":
			# Glazed openings read as dark tinted glass, not bright sky panels.
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color = base.darkened(0.42)
			material.albedo_color.a = 0.52
			material.roughness = 0.1
			material.specular = 0.35
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
		&"water_highlight":
			material.roughness = 0.15
		&"ember":
			material.emission_enabled = true
			material.emission = EMBER_COLOR
			material.emission_energy_multiplier = EMBER_ENERGY
	_cache[key] = material
	return material


## Size-aware role material so gate leaves, jambs, and thresholds keep plank or
## ashlar courses at house scale instead of stretching one tile across a 6-10 m span.
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


## Flat vegetation and landscape tints for the view-only scatter and treeline.
## Instance colors modulate these through vertex_color_use_as_albedo.
static func foliage_tuft() -> StandardMaterial3D:
	return _patterned("foliage_tuft", Color8(96, 122, 60), PATTERN_GRASS)


static func foliage_spruce() -> StandardMaterial3D:
	return _patterned("foliage_spruce", Color8(56, 82, 54), PATTERN_GRASS)


static func foliage_leaf() -> StandardMaterial3D:
	return _patterned("foliage_leaf", Color8(94, 116, 58), PATTERN_GRASS)


static func bark() -> StandardMaterial3D:
	return _patterned("bark", Color8(74, 56, 42), PATTERN_PLANK)


static func surroundings_ground() -> StandardMaterial3D:
	var key := "surroundings_ground"
	if _cache.has(key):
		return _cache[key]
	var material := _make_material(Color8(74, 88, 60), PATTERN_GRASS, 8117)
	material.uv1_scale = Vector3(96.0, 96.0, 1.0)
	_cache[key] = material
	return material


static func surroundings_town() -> StandardMaterial3D:
	var key := "surroundings_town"
	if _cache.has(key):
		return _cache[key]
	var material := _make_material(Color8(118, 112, 102), PATTERN_COBBLE, 8219)
	material.uv1_scale = Vector3(48.0, 48.0, 1.0)
	_cache[key] = material
	return material


## Untextured, unshaded billboard for chimney smoke. Radial vertex alpha on the
## puff mesh and the particle color ramp provide tint and lifetime fade.
## Untextured, unshaded billboard for chimney smoke. Tint and lifetime fade come
## from the particle color ramp only.
static func smoke() -> StandardMaterial3D:
	var key := "smoke"
	if _cache.has(key):
		return _cache[key]
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Particle COLOR carries the lifetime ramp, including the alpha fade.
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	_cache[key] = material
	return material




static func _patterned(prefix: String, color: Color, pattern: StringName) -> StandardMaterial3D:
	var key := "%s:%s:%s" % [prefix, color.to_html(), String(pattern)]
	if _cache.has(key):
		return _cache[key]
	var material := _make_material(color, pattern, int(key.hash()))
	_cache[key] = material
	return material


static func _building_surface(prefix: String, color: Color, pattern: StringName) -> StandardMaterial3D:
	var material := _patterned(prefix, color, pattern)
	material.uv1_scale = building_uv_scale(pattern, BUILDING_UV_REFERENCE_SIZE)
	return material


static func _wall_pattern(family: StringName) -> StringName:
	match family:
		&"brick":
			return PATTERN_BRICK
		&"plank":
			return PATTERN_PLANK
		&"limestone":
			return PATTERN_LIMESTONE
		_:
			return PATTERN_PLASTER


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
