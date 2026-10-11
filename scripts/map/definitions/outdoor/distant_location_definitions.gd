class_name DistantLocationDefinitions
extends RefCounted

## Developer-traversable campaign maps on the global Estonia layer.
## The RRMap files are shared with Map Alignment so editor geometry, scene
## assembly, stable transitions, and audits cannot drift into separate versions.

const RRMAP_PATHS: Dictionary = {
	&"world_kanavere": "res://content/maps/world_kanavere.rrmap",
	&"world_sojamae": "res://content/maps/world_sojamae.rrmap",
	&"world_parnu": "res://content/maps/world_parnu.rrmap",
	&"world_poide": "res://content/maps/world_poide.rrmap",
	&"world_rakvere": "res://content/maps/world_rakvere.rrmap",
	&"world_haapsalu": "res://content/maps/world_haapsalu.rrmap",
	&"world_lihula": "res://content/maps/world_lihula.rrmap",
	&"world_tartu": "res://content/maps/world_tartu.rrmap",
	&"world_viljandi": "res://content/maps/world_viljandi.rrmap",
	&"world_poltsamaa": "res://content/maps/world_poltsamaa.rrmap",
	&"world_narva": "res://content/maps/world_narva.rrmap",
	&"world_karksi": "res://content/maps/world_karksi.rrmap",
	&"world_helme": "res://content/maps/world_helme.rrmap",
	&"world_maasilinna": "res://content/maps/world_maasilinna.rrmap",
	&"world_karja": "res://content/maps/world_karja.rrmap",
	&"world_klint": "res://content/maps/world_klint.rrmap",
	&"world_soomaa": "res://content/maps/world_soomaa.rrmap",
	&"world_frontier_ugandi": "res://content/maps/world_frontier_ugandi.rrmap",
}

const SCENE_IDS: Array[StringName] = [
	&"world_kanavere",
	&"world_sojamae",
	&"world_parnu",
	&"world_poide",
	&"world_rakvere",
	&"world_haapsalu",
	&"world_lihula",
	&"world_tartu",
	&"world_viljandi",
	&"world_poltsamaa",
	&"world_narva",
	&"world_karksi",
	&"world_helme",
	&"world_maasilinna",
	&"world_karja",
	&"world_klint",
	&"world_soomaa",
	&"world_frontier_ugandi",
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
