extends RefCounted

## R-1536: benchmark recorders mount the production scene they measure at run
## time (`--scene=res://...`) instead of instancing it as an ext_resource. A
## retired scene then fails fast with exit code 1; an ext_resource to a missing
## scene left the benchmark scene empty and Godot idling forever.

## The continuous Reval city (ADR 0031): the world the game plays in.
const CITY_SCENE := "res://scenes/world/reval_city/reval_city.tscn"
## Kalev's smithy (the forge interior), where New Game hands over to the city.
const SMITHY_SCENE := "res://scenes/reval_east/forge/forge.tscn"


static func argument(prefix: String, fallback: String) -> String:
	for value in OS.get_cmdline_user_args():
		if value.begins_with(prefix):
			return value.trim_prefix(prefix)
	return fallback


## Instances `--scene=` (default `default_scene`) under `host`, so its complete
## production `_ready` chain runs with the project autoloads. On a missing or
## unloadable scene it reports the path, quits with 1 and returns null.
static func mount(host: Node, default_scene: String = CITY_SCENE) -> Node:
	var path := argument("--scene=", default_scene)
	var packed: PackedScene = null
	if ResourceLoader.exists(path, "PackedScene"):
		packed = load(path) as PackedScene
	if packed == null:
		push_error("Benchmark scene is missing or cannot load: %s" % path)
		host.get_tree().quit(1)
		return null
	var scene := packed.instantiate()
	host.add_child(scene)
	return scene
