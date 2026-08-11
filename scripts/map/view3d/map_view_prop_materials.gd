extends RefCounted

## Cached prop, foliage, and atmospheric materials for the 3D map view.
##
## MapViewMaterials exposes this module through its stable public API. This
## keeps prop visual treatment separate from terrain, water, and building rules.

const PATTERN_GRASS := &"grass"
const PATTERN_SPECKLE := &"speckle"
const PATTERN_COBBLE := &"cobble"
const PATTERN_LIMESTONE := &"limestone"
const PATTERN_PLANK := &"plank"
const PATTERN_PLASTER := &"plaster"
const PATTERN_STRAW := &"straw"
const PATTERN_ROCK := &"rock"
const PATTERN_BARK := &"bark"
const PATTERN_BIRCH_BARK := &"birch_bark"
const PATTERN_CHERRY_BARK := &"cherry_bark"
const HAY_FIBER_TEXTURE := preload("res://assets/materials/production/hay_fibers.png")

const EMBER_COLOR := Color8(224, 108, 48)
const EMBER_ENERGY := 1.6

static var _cache: Dictionary = {}


static func reset() -> void:
	_cache.clear()


## Prop surface materials keyed by the shared visual-style roles so the
## placeholder palette carries over from the approved clean-painted profile.
static func role(role_name: StringName) -> StandardMaterial3D:
	var key := "role:%s" % String(role_name)
	if _cache.has(key):
		return _cache[key]
	var base := MapVisualStyle.role_color(
		role_name, MapVisualStyle.TARGET_CLEAN_PAINTED, MapVisualStyle.TIME_DAY
	)
	var pattern := PATTERN_PLASTER
	match role_name:
		&"wood", &"timber":
			pattern = PATTERN_PLANK
		&"stone":
			pattern = PATTERN_LIMESTONE
		&"rock":
			pattern = PATTERN_ROCK
		&"hay":
			pattern = PATTERN_STRAW
	var material := _make_material(base, pattern, int(role_name.hash()))
	match role_name:
		&"hay":
			# The production fiber tile carries actual overlapping stems. Triplanar
			# mapping keeps them continuous over irregular ricks and wagon loads.
			material.albedo_texture = HAY_FIBER_TEXTURE
			material.uv1_triplanar = true
			material.uv1_world_triplanar = false
			material.uv1_scale = Vector3(2.6, 2.6, 2.6)
			material.roughness = 0.98
		&"metal":
			material.metallic = 0.55
			material.roughness = 0.45
		&"window":
			# Glazed openings read as dark tinted glass, not bright sky panels.
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color = base.darkened(0.42)
			material.albedo_color.a = 0.52
			material.roughness = 0.1
			# Godot 4 StandardMaterial3D exposes metallic_specular, not specular.
			material.metallic_specular = 0.35
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
		&"water_highlight":
			material.roughness = 0.15
		&"ember":
			material.emission_enabled = true
			material.emission = EMBER_COLOR
			material.emission_energy_multiplier = EMBER_ENERGY
	_cache[key] = material
	return material


## Weathered door boards use a dedicated vertical-grain texture and normal map.
## A few deterministic variants keep repeated facades from cloning the same knot.
static func door_wood(noise_seed: int) -> StandardMaterial3D:
	var variant := posmod(noise_seed, 3)
	var key := "door_wood:%d" % variant
	if _cache.has(key):
		return _cache[key]
	var base := MapVisualStyle.role_color(
		&"wood", MapVisualStyle.TARGET_CLEAN_PAINTED, MapVisualStyle.TIME_DAY
	)
	var material := StandardMaterial3D.new()
	material.albedo_color = base.darkened(0.08 + float(variant) * 0.025)
	material.albedo_texture = MapViewMaterialPatterns.door_wood_texture(noise_seed)
	material.normal_enabled = true
	material.normal_texture = MapViewMaterialPatterns.door_wood_normal_texture(noise_seed)
	material.normal_scale = 0.42
	material.roughness = 0.86
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache[key] = material
	return material


## Hand-forged iron is dark, uneven-looking, and rough rather than polished chrome.
static func door_iron() -> StandardMaterial3D:
	var key := "door_iron"
	if _cache.has(key):
		return _cache[key]
	var material := _make_material(Color8(43, 48, 47), PATTERN_ROCK, 4517)
	material.metallic = 0.68
	material.metallic_specular = 0.32
	material.roughness = 0.7
	material.uv1_scale = Vector3(3.0, 3.0, 3.0)
	_cache[key] = material
	return material


## Natural weathered rock for shoreline boulders and field scatter. Triplanar
## mapping keeps grain organic on stretched sphere instances.
static func natural_rock() -> StandardMaterial3D:
	var key := "natural_rock"
	if _cache.has(key):
		return _cache[key]
	var base := MapVisualStyle.role_color(
		&"stone", MapVisualStyle.TARGET_CLEAN_PAINTED, MapVisualStyle.TIME_DAY
	)
	var material := _make_material(base, PATTERN_ROCK, 9041)
	material.uv1_triplanar = true
	material.uv1_world_triplanar = false
	material.uv1_scale = Vector3(2.4, 2.4, 2.4)
	_cache[key] = material
	return material


## Charcoal lumps for forge stores and hearth beds. Uses organic rock mottling on
## near-black albedo so sphere piles never read as limestone/brick masonry.
static func charcoal() -> StandardMaterial3D:
	var key := "charcoal"
	if _cache.has(key):
		return _cache[key]
	var material := _make_material(Color8(26, 24, 22), PATTERN_ROCK, 7711)
	material.uv1_triplanar = true
	material.uv1_world_triplanar = false
	material.uv1_scale = Vector3(3.2, 3.2, 3.2)
	material.roughness = 0.96
	_cache[key] = material
	return material


## Glowing coal bed inside a working furnace mouth.
static func hot_coal() -> StandardMaterial3D:
	var key := "hot_coal_v2"
	if _cache.has(key):
		return _cache[key]
	var material := _make_material(Color8(56, 26, 16), PATTERN_ROCK, 7729)
	material.uv1_triplanar = true
	material.uv1_world_triplanar = false
	material.uv1_scale = Vector3(2.8, 2.8, 2.8)
	material.emission_enabled = true
	material.emission = Color8(255, 96, 28)
	material.emission_energy_multiplier = EMBER_ENERGY * 2.2
	material.roughness = 0.88
	_cache[key] = material
	return material


## Tanned leather for forge bellows and similar soft props.
static func leather() -> StandardMaterial3D:
	var key := "leather"
	if _cache.has(key):
		return _cache[key]
	var material := _make_material(Color8(92, 58, 34), PATTERN_PLASTER, 7741)
	material.uv1_triplanar = true
	material.uv1_world_triplanar = false
	material.uv1_scale = Vector3(2.2, 2.2, 2.2)
	material.roughness = 0.82
	_cache[key] = material
	return material


## Flat vegetation and landscape tints for the view-only scatter and treeline.
## Instance colors modulate these through vertex_color_use_as_albedo.
static func foliage_tuft() -> StandardMaterial3D:
	return _patterned("foliage_tuft", Color8(96, 122, 60), PATTERN_GRASS)


static func foliage_spruce() -> StandardMaterial3D:
	return _patterned("foliage_spruce", Color8(56, 82, 54), PATTERN_GRASS)


static func foliage_leaf() -> StandardMaterial3D:
	return _patterned("foliage_leaf", Color8(94, 116, 58), PATTERN_GRASS)


static func bark(kind: StringName = &"bark") -> StandardMaterial3D:
	if kind == &"birch":
		return _patterned("bark_birch", Color8(214, 208, 196), PATTERN_BIRCH_BARK)
	if kind == &"cherry":
		return _patterned("bark_cherry", Color8(91, 51, 43), PATTERN_CHERRY_BARK)
	return _patterned("bark", Color8(74, 56, 42), PATTERN_BARK)


## Fruit mesh carries apple/cherry color per vertex; this neutral material keeps
## both species in the same cheap material family and avoids tiny cast shadows.
static func tree_fruit() -> StandardMaterial3D:
	var material := _patterned("tree_fruit", Color.WHITE, PATTERN_SPECKLE)
	material.roughness = 0.76
	return material


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
	var material := _make_material(Color8(90, 86, 78), PATTERN_COBBLE, 8219)
	material.uv1_scale = Vector3(48.0, 48.0, 1.0)
	_cache[key] = material
	return material


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
