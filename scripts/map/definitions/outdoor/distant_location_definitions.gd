class_name DistantLocationDefinitions
extends RefCounted

## Developer-traversable campaign maps on the global Estonia layer.
## The RRMap files are shared with Map Alignment so editor geometry, scene
## assembly, stable transitions, and audits cannot drift into separate versions.

const RRMAP_PATHS: Dictionary = {
	&"world_sacred_grove": "res://content/maps/world_sacred_grove.rrmap",
	&"world_harju": "res://content/maps/world_harju.rrmap",
	&"world_padise": "res://content/maps/world_padise.rrmap",
	&"world_saaremaa": "res://content/maps/world_saaremaa.rrmap",
	&"world_rebel_kings": "res://content/maps/world_rebel_kings.rrmap",
	&"world_kanavere": "res://content/maps/world_kanavere.rrmap",
	&"world_sojamae": "res://content/maps/world_sojamae.rrmap",
	&"world_paide": "res://content/maps/world_paide.rrmap",
	&"world_parnu": "res://content/maps/world_parnu.rrmap",
	&"world_poide": "res://content/maps/world_poide.rrmap",
}

const SCENE_IDS: Array[StringName] = [
	&"world_sacred_grove",
	&"world_harju",
	&"world_padise",
	&"world_saaremaa",
	&"world_rebel_kings",
	&"world_kanavere",
	&"world_sojamae",
	&"world_paide",
	&"world_parnu",
	&"world_poide",
]


static func all() -> Array[MapDefinition]:
	var definitions: Array[MapDefinition] = []
	for scene_id in SCENE_IDS:
		var definition := create(scene_id)
		if definition != null:
			definitions.append(definition)
	return definitions


static func create(scene_id: StringName) -> MapDefinition:
	var path := String(RRMAP_PATHS.get(scene_id, ""))
	if path.is_empty():
		return null
	var parsed := MapRrmapParser.parse_file(path)
	if not parsed.is_ok():
		for diagnostic in parsed.formatted_diagnostics():
			push_error(diagnostic)
		return null
	var definition: MapDefinition = parsed.definition
	# These maps are reachable only through the developer manifest. Metadata keeps
	# that intent explicit without making prototype sources release-active.
	definition.set_meta("package", &"global_placeholders")
	definition.set_meta("inspection_spawn_id", &"prototype_inspection")
	definition.set_meta("playable", true)
	definition.set_meta("global_map_scene_id", scene_id)
	return definition
