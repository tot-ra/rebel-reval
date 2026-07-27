extends "res://tests/godot/test_case.gd"

const HolySpiritChurchDefinition := preload("res://scripts/map/definitions/prototypes/holy_spirit_church_definition.gd")
const MarketCivicQuarterDefinition := preload("res://scripts/map/definitions/prototypes/market_civic_quarter_definition.gd")
const MusicDirectorScript := preload("res://scripts/global/music_director.gd")


func before_each() -> void:
	_failures.clear()
	DoorNavigator.load_manifest(true)


func test_church_interior_is_a_valid_reachable_prototype() -> void:
	var definition: MapDefinition = HolySpiritChurchDefinition.create()
	var grid := MapBuilder.build(definition)
	assert_eq(definition.map_id, &"holy_spirit_church")
	assert_eq(definition.size_cells, Vector2i(30, 22))
	assert_eq(definition.scope, &"prototype")
	assert_false(definition.active)
	assert_true(MapBuilder.validate(definition).is_empty())
	for anchor_id: StringName in [&"south_entry", &"nave_center", &"altar_front", &"baptismal_font_site", &"alms_chest_site"]:
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


func test_central_facade_and_church_exit_form_a_walkable_pair() -> void:
	var center: MapDefinition = MarketCivicQuarterDefinition.create()
	var church: MapDefinition = HolySpiritChurchDefinition.create()
	var center_grid := MapBuilder.build(center)
	var entry := _transition(center, &"to_holy_spirit_church")
	var exit := _transition(church, &"to_reval_center")
	assert_eq(entry.get("destination_scene_id"), &"holy_spirit_church")
	assert_eq(entry.get("destination_spawn_id"), &"from_reval_center")
	assert_eq(entry.get("spawn_id"), &"to_holy_spirit_church")
	assert_eq(entry.get("building_id"), &"church_silhouette")
	assert_eq(exit.get("destination_scene_id"), &"reval_center")
	assert_eq(exit.get("destination_spawn_id"), entry.get("spawn_id"))
	assert_eq(exit.get("spawn_id"), entry.get("destination_spawn_id"))
	assert_true((entry["spawn_offset"] as Vector2).y > 0.0, "return must land south of the chapel mass")
	var center_arrival := (entry["rect"] as Rect2).get_center() + (entry["spawn_offset"] as Vector2)
	assert_true(MapVerification.is_walkable_point(center, center_grid, center_arrival))
	assert_true(MapVerification.spawn_clears_transition_trigger(entry))
	assert_true(MapVerification.spawn_clears_transition_trigger(exit))


func test_church_is_registered_and_uses_only_its_two_hymns() -> void:
	assert_eq(
		MapCatalog.get_map("holy_spirit_church").get("path"),
		"res://scenes/reval_center/holy_spirit_church/holy_spirit_church.tscn"
	)
	assert_true(DoorNavigator.has_active_scene(&"holy_spirit_church"))
	assert_true(DoorNavigator.has_spawn(&"reval_center", &"to_holy_spirit_church"))
	assert_true(DoorNavigator.has_spawn(&"holy_spirit_church", &"from_reval_center"))
	assert_eq(LocationHud.display_name_for_scene(&"holy_spirit_church"), "Holy Spirit Church")
	assert_eq(
		MusicDirectorScript.theme_for_scene("res://scenes/reval_center/holy_spirit_church/holy_spirit_church.tscn"),
		&"holy_spirit"
	)
	assert_eq(
		MusicDirectorScript.day_track_paths_for_theme(&"holy_spirit"),
		PackedStringArray([
			"res://music/revel_center/holy spirit church/Hymn of the Holy Spirit (1).mp3",
			"res://music/revel_center/holy spirit church/Hymn of the Holy Spirit.mp3",
		])
	)


func test_hymns_were_moved_out_of_archive() -> void:
	for filename in ["Hymn of the Holy Spirit (1).mp3", "Hymn of the Holy Spirit.mp3"]:
		assert_true(FileAccess.file_exists("res://music/revel_center/holy spirit church/%s" % filename))
		assert_false(FileAccess.file_exists("res://archive/music/revel_center/holy spirit church/%s" % filename))


func _transition(definition: MapDefinition, transition_id: StringName) -> Dictionary:
	for transition in definition.transitions:
		if transition.get("id", &"") == transition_id:
			return transition
	fail("missing transition %s on %s" % [transition_id, definition.map_id])
	return {}
