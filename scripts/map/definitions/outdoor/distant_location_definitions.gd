class_name DistantLocationDefinitions
extends RefCounted

## Playable mockup maps for developer traversal on the global Estonia layer.
## The source outdoor definitions remain inactive prototypes; this adapter adds
## stable arrival markers and reciprocal road/ferry doors without release scope.

const Factory := preload("res://scripts/map/definitions/outdoor/outdoor_map_factory.gd")
const Wilderness := preload("res://scripts/map/definitions/outdoor/wilderness_event_definitions.gd")
const Villages := preload("res://scripts/map/definitions/outdoor/village_monastery_definitions.gd")
const Castles := preload("res://scripts/map/definitions/outdoor/castle_definitions.gd")


static func create(scene_id: StringName) -> MapDefinition:
	match scene_id:
		&"world_sacred_grove":
			return _finalize(Wilderness.sacred_grove(), scene_id, [
				_link(&"to_reval", &"reval_south", &"from_world_sacred_grove", &"from_reval_south", Rect2i(2, 22, 4, 3), Vector2(0, -128)),
				_link(&"road_to_harju", &"world_harju", &"from_world_sacred_grove", &"from_world_harju", Rect2i(40, 20, 4, 4), Vector2(-128, 0)),
			])
		&"world_harju":
			return _finalize(Villages.harju_village(), scene_id, [
				_link(&"road_to_reval", &"viru_gate_foreland", &"from_world_harju", &"from_reval_east", Rect2i(0, 13, 4, 4), Vector2(128, 0)),
				_link(&"road_to_sacred_grove", &"world_sacred_grove", &"from_world_harju", &"from_world_sacred_grove", Rect2i(16, 26, 4, 4), Vector2(0, -128)),
				_link(&"road_to_rebel_kings", &"world_rebel_kings", &"from_world_harju", &"from_world_rebel_kings", Rect2i(48, 7, 4, 4), Vector2(-128, 0)),
				_link(&"road_to_kanavere", &"world_kanavere", &"from_world_harju", &"from_world_kanavere", Rect2i(48, 20, 4, 4), Vector2(-128, 0)),
				_link(&"road_to_sojamae", &"world_sojamae", &"from_world_harju", &"from_world_sojamae", Rect2i(27, 0, 4, 4), Vector2(0, 128)),
			])
		&"world_padise":
			return _finalize(Villages.padise_monastery(), scene_id, [
				_link(&"road_to_reval", &"reval_toompea", &"from_world_padise", &"from_reval_west", Rect2i(46, 24, 4, 3), Vector2(-128, 0)),
				_link(&"road_to_parnu", &"world_parnu", &"from_world_padise", &"from_world_parnu", Rect2i(0, 24, 4, 3), Vector2(128, 0)),
			])
		&"world_saaremaa":
			return _finalize(Wilderness.saaremaa(), scene_id, [
				_link(&"ferry_to_reval", &"reval_harbor_north", &"from_world_saaremaa", &"from_reval_harbor", Rect2i(2, 22, 4, 3), Vector2(0, 128)),
				_link(&"ferry_to_parnu", &"world_parnu", &"from_world_saaremaa", &"from_world_parnu", Rect2i(44, 22, 4, 3), Vector2(0, 128)),
				_link(&"road_to_poide", &"world_poide", &"from_world_saaremaa", &"from_world_poide", Rect2i(23, 22, 4, 3), Vector2(0, 128)),
			])
		&"world_rebel_kings":
			return _finalize(Wilderness.rebel_kings_camp(), scene_id, [
				_link(&"road_to_harju", &"world_harju", &"from_world_rebel_kings", &"from_world_harju", Rect2i(0, 22, 4, 4), Vector2(128, 0)),
				_link(&"road_to_kanavere", &"world_kanavere", &"from_world_rebel_kings", &"from_world_kanavere", Rect2i(46, 22, 4, 4), Vector2(-128, 0)),
			])
		&"world_kanavere":
			return _finalize(Wilderness.kanavere_bog(), scene_id, [
				_link(&"road_to_harju", &"world_harju", &"from_world_kanavere", &"from_world_harju", Rect2i(0, 24, 4, 4), Vector2(128, 0)),
				_link(&"road_to_rebel_kings", &"world_rebel_kings", &"from_world_kanavere", &"from_world_rebel_kings", Rect2i(0, 14, 4, 4), Vector2(128, 0)),
				_link(&"road_to_paide", &"world_paide", &"from_world_kanavere", &"from_world_paide", Rect2i(50, 24, 4, 4), Vector2(-128, 0)),
			])
		&"world_sojamae":
			return _finalize(Wilderness.sojamae_battlefield(), scene_id, [
				_link(&"road_to_harju", &"world_harju", &"from_world_sojamae", &"from_world_harju", Rect2i(0, 24, 4, 4), Vector2(128, 0)),
				_link(&"road_to_paide", &"world_paide", &"from_world_sojamae", &"from_world_paide", Rect2i(50, 24, 4, 4), Vector2(-128, 0)),
			])
		&"world_paide":
			return _finalize(Castles.paide_castle(), scene_id, [
				_link(&"road_to_kanavere", &"world_kanavere", &"from_world_paide", &"from_world_kanavere", Rect2i(0, 25, 4, 4), Vector2(128, 0)),
				_link(&"road_to_sojamae", &"world_sojamae", &"from_world_paide", &"from_world_sojamae", Rect2i(24, 25, 4, 4), Vector2(0, 128)),
				_link(&"road_to_parnu", &"world_parnu", &"from_world_paide", &"from_world_parnu", Rect2i(46, 25, 4, 4), Vector2(-128, 0)),
			])
		&"world_parnu":
			return _finalize(Wilderness.pernau(), scene_id, [
				_link(&"road_to_padise", &"world_padise", &"from_world_parnu", &"from_world_padise", Rect2i(0, 22, 4, 4), Vector2(128, 0)),
				_link(&"road_to_paide", &"world_paide", &"from_world_parnu", &"from_world_paide", Rect2i(46, 22, 4, 4), Vector2(-128, 0)),
				_link(&"ferry_to_saaremaa", &"world_saaremaa", &"from_world_parnu", &"from_world_saaremaa", Rect2i(23, 24, 4, 4), Vector2(0, -128)),
			])
		&"world_poide":
			return _finalize(Castles.poide_castle(), scene_id, [
				_link(&"road_to_saaremaa", &"world_saaremaa", &"from_world_poide", &"from_world_saaremaa", Rect2i(0, 25, 4, 4), Vector2(128, 0)),
			])
		_:
			return null


static func _link(
	id: StringName,
	destination_scene_id: StringName,
	destination_spawn_id: StringName,
	spawn_id: StringName,
	cell_rect: Rect2i,
	spawn_offset: Vector2
) -> Dictionary:
	return {
		"id": id,
		"destination_scene_id": destination_scene_id,
		"destination_spawn_id": destination_spawn_id,
		"spawn_id": spawn_id,
		"cell_rect": cell_rect,
		"spawn_offset": spawn_offset,
	}


static func _finalize(
	definition: MapDefinition,
	scene_id: StringName,
	links: Array
) -> MapDefinition:
	# WHY: prototype definitions remain non-release authoring sources even though
	# DoorNavigator exposes these assembled scenes for developer traversal.
	definition.map_id = StringName("world.%s" % String(scene_id).trim_prefix("world_"))
	definition.location = StringName("loc.%s" % String(scene_id))
	definition.scope = &"prototype"
	definition.active = false
	definition.set_meta("package", &"global_placeholders")
	definition.set_meta("playable", true)
	definition.set_meta("global_map_scene_id", scene_id)
	for link in links:
		InteriorMapFactory.add_transition(
			definition,
			link["id"],
			link["cell_rect"],
			link["destination_scene_id"],
			link["destination_spawn_id"],
			link["spawn_id"],
			link["spawn_offset"],
			true
		)
	definition.fingerprint = _fingerprint(definition)
	return definition


static func _fingerprint(definition: MapDefinition) -> String:
	var payload := "%s|%s|%s|%s" % [
		definition.map_id,
		definition.size_cells,
		definition.transitions,
		definition.props,
	]
	return payload.sha256_text()
