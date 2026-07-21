class_name DistantLocationDefinitions
extends RefCounted

## Playable placeholder maps for global Estonia travel. Composition reuses the
## outdoor prototype factories; each location adds a single return road to its
## linked Reval gate so DoorNavigator and the global map stay aligned.

const Factory := preload("res://scripts/map/definitions/outdoor/outdoor_map_factory.gd")
const Wilderness := preload("res://scripts/map/definitions/outdoor/wilderness_event_definitions.gd")
const Villages := preload("res://scripts/map/definitions/outdoor/village_monastery_definitions.gd")


static func create(scene_id: StringName) -> MapDefinition:
	match scene_id:
		&"world_sacred_grove":
			return _finalize(
				Wilderness.sacred_grove(),
				scene_id,
				&"reval_south",
				&"from_world_sacred_grove",
				&"from_reval_south",
				Vector2i(2, 22),
				Vector2i(4, 2),
				Vector2(0, -96)
			)
		&"world_harju":
			return _finalize(
				Villages.harju_village(),
				scene_id,
				&"viru_gate_foreland",
				&"from_world_harju",
				&"from_reval_east",
				Vector2i(0, 13),
				Vector2i(3, 4),
				Vector2(-96, 0)
			)
		&"world_padise":
			return _finalize(
				Villages.padise_monastery(),
				scene_id,
				&"reval_toompea",
				&"from_world_padise",
				&"from_reval_west",
				Vector2i(46, 24),
				Vector2i(4, 3),
				Vector2(96, 0)
			)
		&"world_saaremaa":
			return _finalize(
				_saaremaa_base(),
				scene_id,
				&"reval_harbor_north",
				&"from_world_saaremaa",
				&"from_reval_harbor",
				Vector2i(2, 22),
				Vector2i(4, 3),
				Vector2(0, 96)
			)
		_:
			return null


static func _saaremaa_base() -> MapDefinition:
	for definition in Wilderness.all():
		if definition.map_id == &"prototype.saaremaa":
			return definition
	return Wilderness.sacred_grove()


static func _finalize(
	definition: MapDefinition,
	scene_id: StringName,
	gate_scene_id: StringName,
	gate_spawn_id: StringName,
	arrival_spawn_id: StringName,
	return_cell: Vector2i,
	return_size: Vector2i,
	return_spawn_offset: Vector2
) -> MapDefinition:
	# WHY: outdoor prototypes stay audit-only; global placeholders must be
	# traversable developer destinations without renaming archived scene files.
	definition.map_id = StringName("world.%s" % String(scene_id).trim_prefix("world_"))
	definition.location = StringName("loc.%s" % String(scene_id))
	definition.scope = &"prototype"
	definition.active = true
	definition.set_meta("package", &"global_placeholders")
	definition.set_meta("playable", true)
	definition.set_meta("global_map_scene_id", scene_id)
	definition.player_spawn = Factory.cell_center(definition, return_cell + Vector2i(2, 1))
	InteriorMapFactory.add_transition(
		definition,
		&"to_reval_gate",
		Rect2i(return_cell, return_size),
		gate_scene_id,
		gate_spawn_id,
		arrival_spawn_id,
		return_spawn_offset,
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
