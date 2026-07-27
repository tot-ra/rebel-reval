extends "res://tests/godot/test_case.gd"

const OlevisteChurchDefinition := preload("res://scripts/map/definitions/prototypes/oleviste_church_definition.gd")
const MonasteryQuarterDefinition := preload("res://scripts/map/definitions/prototypes/monastery_quarter_definition.gd")
const MusicDirectorScript := preload("res://scripts/global/music_director.gd")


func before_each() -> void:
	_failures.clear()
	DoorNavigator.load_manifest(true)


func test_church_interior_is_a_valid_reachable_prototype() -> void:
	var definition: MapDefinition = OlevisteChurchDefinition.create()
	var grid := MapBuilder.build(definition)
	assert_eq(definition.map_id, &"oleviste_church")
	assert_eq(definition.size_cells, Vector2i(36, 24))
	assert_eq(definition.scope, &"prototype")
	assert_false(definition.active)
	assert_true(MapBuilder.validate(definition).is_empty())
	for anchor_id: StringName in [&"south_entry", &"nave_center", &"altar_front"]:
		assert_true(MapVerification.has_anchor(definition, anchor_id), "missing church anchor %s" % anchor_id)
		assert_true(
			MapVerification.route_exists_exact(
				definition,
				grid,
				definition.player_spawn,
				MapVerification.anchor_position(definition, anchor_id)
			),
			"church route is blocked at %s" % anchor_id
		)


func test_monastery_facade_and_church_exit_form_a_walkable_pair() -> void:
	var monastery: MapDefinition = MonasteryQuarterDefinition.create()
	var church: MapDefinition = OlevisteChurchDefinition.create()
	var monastery_grid := MapBuilder.build(monastery)
	var entry := _transition(monastery, &"to_oleviste_church")
	var exit := _transition(church, &"to_reval_monastery")
	assert_eq(entry.get("destination_scene_id"), &"oleviste_church")
	assert_eq(entry.get("destination_spawn_id"), &"from_reval_monastery")
	assert_eq(entry.get("spawn_id"), &"to_oleviste_church")
	assert_eq(entry.get("building_id"), &"st_olaf_silhouette")
	assert_eq(exit.get("destination_scene_id"), &"reval_monastery")
	assert_eq(exit.get("destination_spawn_id"), entry.get("spawn_id"))
	assert_eq(exit.get("spawn_id"), entry.get("destination_spawn_id"))
	assert_true((entry["spawn_offset"] as Vector2).y > 0.0, "return must land south of the tower mass")
	var monastery_arrival := (entry["rect"] as Rect2).get_center() + (entry["spawn_offset"] as Vector2)
	assert_true(MapVerification.is_walkable_point(monastery, monastery_grid, monastery_arrival))
	assert_true(MapVerification.spawn_clears_transition_trigger(entry))
	assert_true(MapVerification.spawn_clears_transition_trigger(exit))


func test_church_is_registered_and_uses_only_its_two_bell_tracks() -> void:
	assert_eq(
		MapCatalog.get_map("oleviste_church").get("path"),
		"res://scenes/reval_north/oleviste_church/oleviste_church.tscn"
	)
	assert_true(DoorNavigator.has_active_scene(&"oleviste_church"))
	assert_true(DoorNavigator.has_spawn(&"reval_monastery", &"to_oleviste_church"))
	assert_true(DoorNavigator.has_spawn(&"oleviste_church", &"from_reval_monastery"))
	assert_eq(LocationHud.display_name_for_scene(&"oleviste_church"), "St. Olaf's Church")
	assert_eq(
		MusicDirectorScript.theme_for_scene("res://scenes/reval_north/oleviste_church/oleviste_church.tscn"),
		&"oleviste"
	)
	assert_eq(
		MusicDirectorScript.day_track_paths_for_theme(&"oleviste"),
		PackedStringArray([
			"res://music/revel_north/oleviste/Oleviste's Bells (1).mp3",
			"res://music/revel_north/oleviste/Oleviste's Bells.mp3",
		])
	)


func _transition(definition: MapDefinition, transition_id: StringName) -> Dictionary:
	for transition in definition.transitions:
		if transition.get("id", &"") == transition_id:
			return transition
	fail("missing transition %s on %s" % [transition_id, definition.map_id])
	return {}
