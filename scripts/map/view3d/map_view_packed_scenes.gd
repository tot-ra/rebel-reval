class_name MapViewPackedScenes
extends RefCounted

## WB-07c (R-1006): keeps the authored GLB scenes (and kit surface textures) a
## view loaded alive for as long as the view lives.
##
## WHY: ResourceLoader caches a resource only while something references it. A
## model builder does `load(path).instantiate()` and drops the PackedScene, so
## the next building or prop of the same kit read the whole .scn again: 40-60 ms
## for one service-building GLB, 5-11 ms for every household-clutter prop. The
## instances keep only meshes and materials alive, never the scene.
##
## A pin set is a plain Dictionary (path -> PackedScene) owned by one view's
## assembly queue. MapViewAssembly pushes it while a unit runs, so every
## load_scene() inside the unit pins into it. Freeing the view frees the set, so
## no GLB outlives every view that used it. Outside an assembly unit (tests,
## tools, streaming after assembly) load_scene() is a plain load().
##
## Building GLBs are known before their build (production_scene_paths()); prop,
## landmark and animal kits are not. For those the set an assembly pinned is
## remembered per map, as path strings only, and the next assembly of the same
## map prefetches it. A map's first assembly still loads its prop kits inline.

static var _pin_stack: Array[Dictionary] = []
## Map key -> sorted PackedStringArray of the paths its last assembly pinned.
static var _learned_paths: Dictionary = {}


## Same result as `load(path) as PackedScene`; also pins it in the active set.
static func load_scene(path: String) -> PackedScene:
	return load_pinned(path) as PackedScene


## Same result as `load(path)`; also pins it in the active set. Used for the kit
## house surface-variant textures too (2-3 ms per uncached plate).
static func load_pinned(path: String) -> Resource:
	var resource := load(path)
	if resource != null and not _pin_stack.is_empty():
		_pin_stack.back()[path] = resource
	return resource


static func push_pins(pins: Dictionary) -> void:
	_pin_stack.append(pins)


static func pop_pins() -> void:
	if not _pin_stack.is_empty():
		_pin_stack.pop_back()


## Paths from `paths` that are not already in the resource cache, deduplicated
## and sorted so the request order is deterministic.
static func uncached(paths: PackedStringArray) -> PackedStringArray:
	var wanted := {}
	for path in paths:
		if not path.is_empty() and not ResourceLoader.has_cached(path):
			wanted[path] = true
	var result := PackedStringArray(wanted.keys())
	result.sort()
	return result


static func map_key(definition: MapDefinition) -> String:
	return "%s:%s" % [String(definition.map_id), definition.fingerprint]


static func learned_paths(key: String) -> PackedStringArray:
	return _learned_paths.get(key, PackedStringArray())


## Remembers the active pin set as the scenes `key`'s assembly needs. Runs as the
## last unit of an assembly, while that queue's set is pushed.
static func remember_active(key: String) -> void:
	if _pin_stack.is_empty():
		return
	var paths := PackedStringArray(_pin_stack.back().keys())
	paths.sort()
	_learned_paths[key] = paths
