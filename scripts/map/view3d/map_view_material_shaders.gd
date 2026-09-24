class_name MapViewMaterialShaders
extends RefCounted

## Inline shader sources for animated MapViewMaterials surfaces.
## Small or stable shaders may live in sibling `*.gdshader` resources; the cache
## API keeps one shared Shader instance per logical name.


const WEAR_DECAL_SHADER := preload("res://scripts/map/view3d/map_view_wear_decal.gdshader")
const CLOTH_SHADER := preload("res://scripts/map/view3d/map_view_cloth.gdshader")
const PUDDLE_SHADER := preload("res://scripts/map/view3d/map_view_puddle.gdshader")
const HANGING_BANNER_CLOTH_SHADER := preload(
	"res://scripts/map/view3d/map_view_hanging_banner_cloth.gdshader"
)
const FISHING_NET_WIND_SHADER := preload(
	"res://scripts/map/view3d/map_view_fishing_net_wind.gdshader"
)
const GRASS_SHADER := preload("res://scripts/map/view3d/map_view_grass.gdshader")
const CANOPY_SHADER := preload("res://scripts/map/view3d/map_view_canopy.gdshader")
const WATER_SHADER := preload("res://scripts/map/view3d/map_view_water.gdshader")
const TERRAIN_BLEND_SHADER := preload("res://scripts/map/view3d/map_view_terrain_blend.gdshader")

static var _cache: Dictionary = {}


static func reset() -> void:
	_cache.clear()


static func shader(name: String, code: String) -> Shader:
	var key := "shader:%s" % name
	if _cache.has(key):
		return _cache[key]
	var compiled_shader := Shader.new()
	compiled_shader.code = code
	_cache[key] = compiled_shader
	return compiled_shader


static func shader_resource(name: String, resource: Shader) -> Shader:
	var key := "shader:%s" % name
	if _cache.has(key):
		return _cache[key]
	_cache[key] = resource
	return resource
